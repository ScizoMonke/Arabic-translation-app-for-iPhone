import Foundation
import llama

/// Every llama.cpp C symbol used here was read from include/llama.h at release
/// b12020 (commit 0ec4027a), the same header that ships inside the pinned
/// llama.xcframework (byte-identical, checked 2026-10-31). Swift import shapes
/// follow upstream's own examples/llama.swiftui/llama.cpp.swift/LibLlama.swift:
/// llama_model, llama_context and llama_vocab are incomplete C types and arrive
/// as OpaquePointer; llama_sampler is a complete struct and arrives as
/// UnsafeMutablePointer<llama_sampler>.

enum LlamaError: LocalizedError {
    case notLoaded
    case modelLoadFailed(String)
    case contextFailed
    case tokenizeFailed
    case promptTooLong(Int)
    case decodeFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .notLoaded: return "The Egyptian model is not loaded."
        case .modelLoadFailed(let path): return "llama.cpp could not load the model at \(path)."
        case .contextFailed: return "llama.cpp could not create a context (memory?)."
        case .tokenizeFailed: return "The prompt could not be tokenized."
        case .promptTooLong(let n): return "The prompt is too long (\(n) tokens)."
        case .decodeFailed(let code): return "llama_decode failed with code \(code)."
        }
    }
}

/// How the next token is picked. D23: greedy first; one retry with mild sampling.
enum Sampling: Sendable {
    case greedy
    case mild   // top_k 20, temperature 0.3

    var label: String { self == .greedy ? "greedy" : "mild" }
}

/// Why generation ended. Only `.jsonClosed` and `.endOfTurn` are normal.
enum StopReason: String, Sendable {
    case jsonClosed = "json closed"
    case endOfTurn = "end of turn"
    case tokenCap = "token cap"
    case loop = "loop guard"
}

/// D37: what priming the fixed prompt prefix cost, for the session log.
struct PrimeResult: Sendable {
    let tokens: Int
    let seconds: Double
}

struct Generation: Sendable {
    let text: String
    let promptTokens: Int
    /// D37: prompt tokens whose KV entries were already in the cache and were
    /// not processed again for this request.
    let reusedTokens: Int
    let newTokens: Int
    let stop: StopReason
    let seconds: Double
}

/// Owns one llama.cpp model + context. All C calls run on one private serial
/// queue: llama_context is not thread-safe, and a multi-second generation must
/// not block a thread of Swift's cooperative pool (Whisper needs those).
/// @unchecked Sendable is honest here because every stored pointer is touched
/// only on `queue`.
final class LlamaEngine: @unchecked Sendable {
    static let contextLength: UInt32 = 2048
    /// D23 loop guard: one character repeated more than eight times in a row.
    static let maxCharacterRun = 8

    private let queue = DispatchQueue(label: "com.a2e.egypttalk.llama", qos: .userInitiated)
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private var vocab: OpaquePointer?
    private var endOfTurn: llama_token?
    /// D37: exactly the tokens whose keys and values sit in the KV cache of
    /// sequence 0, in order (positions 0..<count). Empty means the cache must be
    /// treated as empty.
    private var cachedTokens: [llama_token] = []

    deinit {
        if let context { llama_free(context) }
        if let model { llama_model_free(model) }
    }

    /// Loads the GGUF memory-mapped (R10, R13): the 2.5 GB of weights stay
    /// file-backed pages the OS can drop and re-read, instead of 2.5 GB of
    /// dirty anonymous memory counted against the app. Returns a one-line
    /// description for the session log.
    func load(path: String) async throws -> String {
        try await onQueue { try self.loadOnQueue(path: path) }
    }

    /// D37: processes the fixed part of every prompt once, so each request
    /// decodes only what follows it. Returns the token count and seconds for the
    /// session log.
    func prime(prefix: String) async throws -> PrimeResult {
        try await onQueue { try self.primeOnQueue(prefix: prefix) }
    }

    func generate(prompt: String, maxNewTokens: Int, sampling: Sampling) async throws -> Generation {
        try await onQueue {
            try self.generateOnQueue(prompt: prompt, maxNewTokens: maxNewTokens, sampling: sampling)
        }
    }

    private func onQueue<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try work() })
            }
        }
    }

    // MARK: On the queue only

    private func loadOnQueue(path: String) throws -> String {
        if model != nil { return "already loaded" }
        llama_backend_init()

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = -1                 // every layer on the GPU (Metal)
        modelParams.load_mode = LLAMA_LOAD_MODE_MMAP  // explicit, not AUTO
        guard let loadedModel = llama_model_load_from_file(path, modelParams) else {
            throw LlamaError.modelLoadFailed(path)
        }

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = Self.contextLength
        contextParams.n_batch = Self.contextLength
        let threads = Int32(max(1, min(8, ProcessInfo.processInfo.processorCount - 2)))
        contextParams.n_threads = threads
        contextParams.n_threads_batch = threads
        guard let loadedContext = llama_init_from_model(loadedModel, contextParams) else {
            llama_model_free(loadedModel)
            throw LlamaError.contextFailed
        }

        model = loadedModel
        context = loadedContext
        let loadedVocab: OpaquePointer = llama_model_get_vocab(loadedModel)
        vocab = loadedVocab

        // <end_of_turn> is already an end-of-generation token in llama.cpp's
        // vocab (llama-vocab.cpp), but stopping on its id explicitly costs nothing.
        let eot = try tokenize("<end_of_turn>", vocab: loadedVocab)
        endOfTurn = eot.count == 1 ? eot[0] : nil

        let arch = metaString(loadedModel, key: "general.architecture") ?? "?"
        let template = llama_model_chat_template(loadedModel, nil).map { String(cString: $0) } ?? ""
        let templateNote = template.contains("<start_of_turn>")
            ? "gemma turns confirmed"
            : "WARNING: GGUF template has no <start_of_turn>"
        let sizeMB = llama_model_size(loadedModel) / 1_048_576
        let eotText = endOfTurn.map { String($0) } ?? "not found"
        return "arch \(arch), \(sizeMB) MB weights, n_ctx \(llama_n_ctx(loadedContext)), \(templateNote), end_of_turn id \(eotText)"
    }

    /// <bos> + text, tokenized the one way every prompt is (see generateOnQueue).
    private func tokenizePrompt(_ text: String, vocab: OpaquePointer) throws -> [llama_token] {
        // The Gemma template begins with <bos>, and this GGUF says
        // tokenizer.ggml.add_bos_token = False, so the tokenizer will not add it:
        // tokenize without specials added, parse the <start_of_turn> markers as
        // control tokens, and prepend <bos> by hand.
        var tokens = try tokenize(text, vocab: vocab)
        let bos = llama_vocab_bos(vocab)
        if tokens.first != bos {
            tokens.insert(bos, at: 0)
        }
        return tokens
    }

    /// Decodes `tokens` at the next free positions of sequence 0 (llama_batch_get_one
    /// continues from llama_memory_seq_pos_max + 1, llama-batch.cpp at b12020).
    private func decodeTokens(_ tokens: [llama_token], context: OpaquePointer) throws {
        var batch = tokens
        let result = batch.withUnsafeMutableBufferPointer { buffer in
            llama_decode(context, llama_batch_get_one(buffer.baseAddress, Int32(buffer.count)))
        }
        guard result == 0 else { throw LlamaError.decodeFailed(result) }
    }

    /// Empties the KV cache and the record of it, together, so they can never
    /// disagree.
    private func forgetCache(_ memory: OpaquePointer?) {
        llama_memory_clear(memory, true)
        cachedTokens = []
    }

    private func primeOnQueue(prefix: String) throws -> PrimeResult {
        guard let context, let vocab else { throw LlamaError.notLoaded }
        let started = Date()
        let memory = llama_get_memory(context)
        forgetCache(memory)
        let tokens = try tokenizePrompt(prefix, vocab: vocab)
        do {
            try decodeTokens(tokens, context: context)
        } catch {
            forgetCache(memory)
            throw error
        }
        cachedTokens = tokens
        return PrimeResult(tokens: tokens.count, seconds: Date().timeIntervalSince(started))
    }

    private func generateOnQueue(prompt: String, maxNewTokens: Int, sampling: Sampling) throws -> Generation {
        guard let context, let vocab else { throw LlamaError.notLoaded }
        let started = Date()

        // The full prompt is tokenized exactly as before D37, so the token
        // sequence the model sees is the uncached one, always.
        let tokens = try tokenizePrompt(prompt, vocab: vocab)
        let promptTokens = tokens.count
        guard promptTokens + maxNewTokens <= Int(llama_n_ctx(context)) else {
            throw LlamaError.promptTooLong(promptTokens)
        }

        // D37 reuse: keep the longest run of leading tokens this prompt shares
        // with what the cache holds (the fixed prefix, primed at load; also the
        // whole prompt on the retry), drop everything after it, decode the rest.
        // At least one token is always decoded, because sampling needs the
        // logits of the prompt's last token.
        let memory = llama_get_memory(context)
        var keep = 0
        let limit = min(cachedTokens.count, tokens.count - 1)
        while keep < limit && cachedTokens[keep] == tokens[keep] {
            keep += 1
        }
        if keep > 0 {
            let removed = llama_memory_seq_rm(memory, 0, llama_pos(keep), -1)
            // Positions 0..<keep must all still be present; pos_min > 0 would
            // mean a sliding-window cache dropped early tokens (cannot happen with
            // swa_full, the default, but checked rather than assumed).
            let consistent = removed
                && llama_memory_seq_pos_min(memory, 0) == 0
                && llama_memory_seq_pos_max(memory, 0) == llama_pos(keep - 1)
            if consistent {
                cachedTokens.removeSubrange(keep...)
            } else {
                keep = 0
            }
        }
        if keep == 0 {
            forgetCache(memory)
        }
        let reusedTokens = keep

        do {
            try decodeTokens(Array(tokens[keep...]), context: context)
        } catch {
            forgetCache(memory)
            throw error
        }
        cachedTokens = tokens

        guard let sampler = llama_sampler_chain_init(llama_sampler_chain_default_params()) else {
            throw LlamaError.contextFailed
        }
        defer { llama_sampler_free(sampler) }  // frees the samplers added to the chain too
        switch sampling {
        case .greedy:
            llama_sampler_chain_add(sampler, llama_sampler_init_greedy())
        case .mild:
            llama_sampler_chain_add(sampler, llama_sampler_init_top_k(20))
            llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.3))
            // Fixed seed: a retry is reproducible from the log.
            llama_sampler_chain_add(sampler, llama_sampler_init_dist(1234))
        }

        var output: [UInt8] = []
        var newTokens = 0
        var stop = StopReason.tokenCap
        while newTokens < maxNewTokens {
            // Samples from the last output and accepts the token into the chain.
            let token = llama_sampler_sample(sampler, context, -1)
            if llama_vocab_is_eog(vocab, token) || token == endOfTurn {
                stop = .endOfTurn
                break
            }
            output.append(contentsOf: piece(token, vocab: vocab))
            newTokens += 1
            if Self.jsonObjectClosed(output) {
                stop = .jsonClosed
                break
            }
            if Self.hasCharacterRun(output, longerThan: Self.maxCharacterRun) {
                stop = .loop
                break
            }
            do {
                try decodeTokens([token], context: context)
            } catch {
                forgetCache(memory)
                throw error
            }
            cachedTokens.append(token)
        }

        return Generation(
            text: String(decoding: output, as: UTF8.self),
            promptTokens: promptTokens,
            reusedTokens: reusedTokens,
            newTokens: newTokens,
            stop: stop,
            seconds: Date().timeIntervalSince(started)
        )
    }

    private func tokenize(_ text: String, vocab: OpaquePointer) throws -> [llama_token] {
        let byteCount = Int32(text.utf8.count)
        var capacity = Int(byteCount) + 8
        for _ in 0..<2 {
            var tokens = [llama_token](repeating: 0, count: capacity)
            // add_special false (BOS is handled by the caller), parse_special true
            // (so "<start_of_turn>" becomes the control token, not literal text).
            let n = tokens.withUnsafeMutableBufferPointer { buffer in
                llama_tokenize(vocab, text, byteCount, buffer.baseAddress, Int32(capacity), false, true)
            }
            if n >= 0 {
                return Array(tokens.prefix(Int(n)))
            }
            if n == Int32.min { break }
            capacity = Int(-n)  // negative = the count that would have been written
        }
        throw LlamaError.tokenizeFailed
    }

    /// Raw bytes of one token. A token can end mid UTF-8 sequence (Arabic letters
    /// are two bytes), so bytes are collected and decoded once at the end.
    private func piece(_ token: llama_token, vocab: OpaquePointer) -> [UInt8] {
        var buffer = [CChar](repeating: 0, count: 64)
        var n = buffer.withUnsafeMutableBufferPointer { b in
            llama_token_to_piece(vocab, token, b.baseAddress, Int32(b.count), 0, false)
        }
        if n < 0 {
            buffer = [CChar](repeating: 0, count: Int(-n))
            n = buffer.withUnsafeMutableBufferPointer { b in
                llama_token_to_piece(vocab, token, b.baseAddress, Int32(b.count), 0, false)
            }
        }
        guard n > 0 else { return [] }
        return buffer.prefix(Int(n)).map { UInt8(bitPattern: $0) }
    }

    private func metaString(_ model: OpaquePointer, key: String) -> String? {
        var buffer = [CChar](repeating: 0, count: 256)
        let n = buffer.withUnsafeMutableBufferPointer { b in
            llama_model_meta_val_str(model, key, b.baseAddress, b.count)
        }
        guard n >= 0 else { return nil }
        let bytes = buffer.prefix(min(Int(n), buffer.count - 1)).map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    // MARK: Stop checks (pure)

    /// True once the first top-level JSON object in `bytes` has closed. Scans
    /// bytes: braces, quotes and backslashes are ASCII and never occur inside a
    /// multi-byte UTF-8 sequence, so Arabic text cannot confuse the scan.
    static func jsonObjectClosed(_ bytes: [UInt8]) -> Bool {
        var depth = 0
        var opened = false
        var inString = false
        var escaped = false
        for b in bytes {
            if inString {
                if escaped { escaped = false }
                else if b == 0x5C { escaped = true }      // backslash
                else if b == 0x22 { inString = false }    // quote
                continue
            }
            switch b {
            case 0x22: if opened { inString = true }
            case 0x7B: depth += 1; opened = true          // {
            case 0x7D:                                    // }
                if opened {
                    depth -= 1
                    if depth == 0 { return true }
                }
            default: break
            }
        }
        return false
    }

    /// D23 loop guard on the decoded text so far: the trailing run of one
    /// character (Arabic letters included) longer than `limit`.
    static func hasCharacterRun(_ bytes: [UInt8], longerThan limit: Int) -> Bool {
        let text = String(decoding: bytes, as: UTF8.self)
        guard let last = text.last else { return false }
        var run = 0
        for ch in text.reversed() {
            if ch == last { run += 1 } else { break }
            if run > limit { return true }
        }
        return false
    }
}
