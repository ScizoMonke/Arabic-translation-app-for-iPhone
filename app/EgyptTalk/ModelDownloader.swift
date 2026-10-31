import CryptoKit
import Foundation

enum ModelDownloadError: LocalizedError {
    case http(Int)
    case sizeMismatch(expected: Int64, got: Int64)
    case hashMismatch
    case interrupted

    var errorDescription: String? {
        switch self {
        case .http(let code): return "The server answered HTTP \(code)."
        case .sizeMismatch(let expected, let got): return "The file is \(got) bytes, expected \(expected)."
        case .hashMismatch: return "The file arrived corrupted (checksum mismatch) and was deleted. Download it again."
        case .interrupted: return "The download stopped before the end."
        }
    }
}

/// The one-time download of the Egyptian model (D9, D21), at home on Wi-Fi.
/// Resumable across stops and app restarts: bytes land in a .part file and a
/// retry asks the server only for the rest (HTTP Range). The finished file is
/// checked for exact size and SHA-256 before it is renamed into place, so a
/// half-written or corrupted file can never be loaded.
///
/// URLSession delegate callbacks arrive on `delegateQueue` (serial), the only
/// place the mutable state below is touched; hence @unchecked Sendable.
final class ModelDownloader: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    /// mradermacher/Nile-Chat-4B-GGUF, pinned to repo commit 3e4cf41e (2025-07-11).
    /// Size and SHA-256 read from the Hugging Face API (?blobs=true) on 2026-10-31;
    /// the resolve URL's X-Linked-Size header agrees.
    static let url = URL(string: "https://huggingface.co/mradermacher/Nile-Chat-4B-GGUF/resolve/3e4cf41e8a0cd6292831f09afef27644125c26fa/Nile-Chat-4B.Q4_K_M.gguf")!
    static let fileName = "Nile-Chat-4B.Q4_K_M.gguf"
    static let expectedBytes: Int64 = 2_489_894_752
    static let sha256 = "9ab2de4f11195f5cb0e106403cf20a39785728aa12d9418b7a939b6df27e61d2"

    private let delegateQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        return q
    }()
    private var handle: FileHandle?
    private var written: Int64 = 0
    private var lastReported: Double = -1
    private var responseChecked = false
    private var httpError: Error?
    private var progress: (@Sendable (Double) -> Void)?
    private var continuation: CheckedContinuation<Void, Error>?

    /// Same parent as Whisper's models: Application Support, excluded from backup.
    static func folder() throws -> URL {
        let folder = try Transcriber.modelsBase().appendingPathComponent("nile-chat", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// The finished, verified model file, or nil. A file only exists under this
    /// name after it passed the size and checksum test; the size is re-checked
    /// here as a cheap guard on every launch.
    static func localModelFile() -> URL? {
        guard let file = try? folder().appendingPathComponent(fileName) else { return nil }
        return fileSize(file) == expectedBytes ? file : nil
    }

    private static func fileSize(_ url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else { return nil }
        return size.int64Value
    }

    /// Downloads (or finishes downloading) the model. `progress` gets 0...1.
    func download(progress: @escaping @Sendable (Double) -> Void) async throws {
        let folder = try Self.folder()
        let final = folder.appendingPathComponent(Self.fileName)
        if Self.fileSize(final) == Self.expectedBytes { return }
        let part = folder.appendingPathComponent(Self.fileName + ".part")

        var already = Self.fileSize(part) ?? 0
        if already > Self.expectedBytes {
            try FileManager.default.removeItem(at: part)
            already = 0
        }
        if already < Self.expectedBytes {
            try await fetch(into: part, from: already, progress: progress)
        }

        let got = Self.fileSize(part) ?? 0
        guard got == Self.expectedBytes else {
            if got > Self.expectedBytes { try? FileManager.default.removeItem(at: part) }
            throw got < Self.expectedBytes
                ? ModelDownloadError.interrupted
                : ModelDownloadError.sizeMismatch(expected: Self.expectedBytes, got: got)
        }
        guard try Self.sha256Hex(of: part) == Self.sha256 else {
            try? FileManager.default.removeItem(at: part)
            throw ModelDownloadError.hashMismatch
        }
        if FileManager.default.fileExists(atPath: final.path) {
            try FileManager.default.removeItem(at: final)
        }
        try FileManager.default.moveItem(at: part, to: final)
    }

    /// Streams the file in 8 MB pieces so memory stays flat while 2.5 GB is hashed.
    private static func sha256Hex(of url: URL) throws -> String {
        let reader = try FileHandle(forReadingFrom: url)
        defer { try? reader.close() }
        var hasher = SHA256()
        while true {
            let chunk: Data? = try autoreleasepool { try reader.read(upToCount: 8 * 1_048_576) }
            guard let chunk, !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func fetch(into part: URL, from offset: Int64, progress: @escaping @Sendable (Double) -> Void) async throws {
        if !FileManager.default.fileExists(atPath: part.path) {
            FileManager.default.createFile(atPath: part.path, contents: nil)
        }
        let fileHandle = try FileHandle(forWritingTo: part)
        try fileHandle.seekToEnd()

        let configuration = URLSessionConfiguration.default
        // D9: he does not want to spend mobile data on this; Wi-Fi only.
        configuration.allowsCellularAccess = false
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 6 * 60 * 60
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
        defer { session.finishTasksAndInvalidate() }

        var request = URLRequest(url: Self.url)
        if offset > 0 {
            request.setValue("bytes=\(offset)-", forHTTPHeaderField: "Range")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            delegateQueue.addOperation {
                self.handle = fileHandle
                self.written = offset
                self.lastReported = -1
                self.responseChecked = false
                self.httpError = nil
                self.progress = progress
                self.continuation = continuation
                session.dataTask(with: request).resume()
            }
        }
    }

    // MARK: URLSessionDataDelegate (on delegateQueue)

    // Only the two delegate methods without completion handlers are implemented,
    // so no witness signature can drift from the SDK's @Sendable annotations.
    // Redirects (Hugging Face sends the file from its CDN) use URLSession's default
    // handling. If the Range header did not survive the redirect, the server
    // answers 200 with the whole file and the .part file simply starts over.

    /// Looks at the HTTP status once, before the first byte is written.
    /// Returns false (and records the error) when the download must stop.
    private func acceptResponse(of task: URLSessionTask) -> Bool {
        if responseChecked { return httpError == nil }
        responseChecked = true
        let status = (task.response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 206:
            // "bytes <start>-<end>/<total>": the piece must start where the
            // .part file ends, or appending it would corrupt the file. On a
            // mismatch, empty the .part file so the next try starts clean.
            let contentRange = (task.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Range") ?? ""
            let start = contentRange.split(separator: " ").last?.split(separator: "-").first.flatMap { Int64($0) }
            if start == written {
                return true
            }
            try? handle?.truncate(atOffset: 0)
            httpError = ModelDownloadError.interrupted
            return false
        case 200:
            do {
                try handle?.truncate(atOffset: 0)
                try handle?.seek(toOffset: 0)
                written = 0
                return true
            } catch {
                httpError = error
                return false
            }
        default:
            httpError = ModelDownloadError.http(status)
            return false
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard acceptResponse(of: dataTask) else {
            dataTask.cancel()
            return
        }
        do {
            try handle?.write(contentsOf: data)
        } catch {
            httpError = error
            dataTask.cancel()
            return
        }
        written += Int64(data.count)
        let fraction = Double(written) / Double(Self.expectedBytes)
        if fraction - lastReported >= 0.002 {
            lastReported = fraction
            progress?(min(fraction, 1))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error == nil, task.response != nil {
            _ = acceptResponse(of: task)   // an error status with an empty body
        }
        try? handle?.synchronize()
        try? handle?.close()
        handle = nil
        let outcome = httpError ?? error
        let waiting = continuation
        continuation = nil
        progress = nil
        if let outcome {
            waiting?.resume(throwing: outcome)
        } else {
            waiting?.resume()
        }
    }
}
