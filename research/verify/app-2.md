# app-2: verification of the bottom half (2026-10-31)

VERDICT: no mismatches that break the build or the rulings. One checklist defect (item 3). Nothing compiled; all by reading plus fetched sources.

## 1 LlamaEngine vs llama.h b12020 (CLEAN)
Header fetched from raw.githubusercontent.com b12020 (1751 lines). The ios-arm64 llama.h inside the release zip is byte-identical (SHA-256 f07ffbab...). Symbols used, with header line:
llama_backend_init (490, void); llama_model_default_params (483); llama_model_load_from_file(const char*, params) (526); llama_context_default_params (484); llama_init_from_model(model, params) (553); llama_model_free (551); llama_free (563); llama_model_get_vocab (597) const llama_vocab*; llama_model_chat_template(model, const char* name) (656); llama_model_size uint64 (652); llama_n_ctx uint32 (579); llama_get_memory (594) -> llama_memory_t; llama_memory_clear(mem, bool) (756); llama_vocab_bos (1218); llama_vocab_is_eog (1212); llama_sampler_chain_init (1454); llama_sampler_chain_default_params (485); llama_sampler_chain_add (1457); llama_sampler_free (1449); llama_sampler_init_greedy (1474); init_top_k(int32) (1481); init_temp(float) (1493); init_dist(uint32) (1477); llama_batch_get_one(llama_token*, int32) (966); llama_decode; llama_sampler_sample(smpl, ctx, int32 idx) (1651); llama_tokenize(vocab, text, text_len, tokens, n_max, add_special, parse_special) (1279); llama_token_to_piece(vocab, token, buf, length, lstrip, special) (1293); llama_model_meta_val_str(model, key, buf, size_t) (631).
All argument counts and orders match. model_params.n_gpu_layers (int32) and .load_mode (enum llama_load_mode, LLAMA_LOAD_MODE_MMAP = 1, header 208-214, 328-330) exist; context_params n_ctx/n_batch uint32, n_threads/n_threads_batch int32 exist. llama_token is int32_t (69). Incomplete types (model, context, vocab, memory) import as OpaquePointer; llama_sampler is a complete struct (1429) so UnsafeMutablePointer<llama_sampler>, as the file assumes. No ggml_* symbols used. No DEPRECATED function used (llama_free_model, llama_load_model_from_file, llama_new_context_with_model are not called).

## 2 Package.swift (CLEAN)
URL .../releases/download/b12020/llama-b12020-xcframework.zip is an asset of release b12020 (API: 70314998 bytes). API digest sha256:78fdf6ec...81ae5 equals Package.swift:28. I also downloaded the zip and hashed it: same. Zip holds llama.xcframework/ios-arm64/llama.framework/{llama,Headers,Modules/module.modulemap}; module name "llama" matches `import llama` and the binaryTarget name.

## 3 NileChatPrompt (CLEAN; checklist defect)
Checklist defect: the named meta.json (Nile-Chat-4B-GGUF-Q4_K_M-promptC-ollama-rp1.0) has no rendered-first-prompt field (keys: model_id, backend, system_prompt, ollama_template, options...). The field first_prompt_rendered exists in runs/Nile-Chat-4B-promptC-rp1.15/meta.json; I used that. Its text equals "<bos><start_of_turn>user\n" + system_prompt + "\n\nEnglish: \"Hello.\"<end_of_turn>\n<start_of_turn>model\n". The rp1.0 run's ollama_template renders the same layout (system, blank line, content).
Swift (NileChatPrompt.swift:66-69): "<start_of_turn>user\n" + instruction + "\n\nEnglish: \"" + sentence + "\"<end_of_turn>\n<start_of_turn>model\n". Only differences: no leading <bos> (LlamaEngine.swift:154-158 prepends it as a token), and the two D24 rules inserted at lines 49-51 (masculine speaker; arabizi Latin only). A line diff of the instruction text against the bench system_prompt shows exactly those 4 added lines and nothing else.

## 4 Respelling vs respell.py (CLEAN)
Same map (2,3 -> apostrophe, 5 kh, 7 h, 8 gh, 9 s, 6 t, 4 th), lowercase, collapse apostrophe runs, drop word-initial apostrophes (start, after whitespace - ( "). Python uses two regex passes, Swift one pass with a word-start flag; same output on all inputs:
ma3 el salama -> ma' el salama | 3andi soda3 -> andi soda' | te2olha tany -> te'olha tany | el7amdulellah -> elhamdulellah | 5alas -> khalas | ba3den -> ba'den | 9aba7 el 5eir -> sabah el kheir | 2ahwa -> ahwa | sa7ee7 -> saheeh.
Dictionary literals have no duplicate keys (a duplicate would trap at runtime).

## 5 Phrasebook (CLEAN)
Schema: phrasebook.json = {version:1, entries:[273 x {id str, english [str], arabic str, arabizi str, respelling str, gloss str, tags [str]}]}; PhrasebookEntry (Phrasebook.swift:13-21) matches (tags optional); version check == 1 at line 79; resource loaded as phrasebook.json from Bundle.main (project.yml sources include EgyptTalk/, so Resources/phrasebook.json lands at the .app root, which the workflow also tests).
- "where is the bathroom": exact alias of hl-bathroom, similarity 1.0.
- "Where's the toilet?": apostrophe dropped, "?" becomes space, "wheres the toilet" equals normalized alias "where's the toilet": exact, hl-bathroom.
- "i don't want tea" vs alias "i want tea": Jaccard 3/4 = 0.75 passes threshold, but the symmetric difference {dont} is in meaningFlippers (line 53); guard at line 134 skips it, result nil (goes to model). D29 satisfied.
- "turn left": exact alias in dir-left; dir-right has no such alias.
- Sentence with no overlap: Jaccard below 0.75, nil.

## 6 Gloss sources (CLEAN)
Every Rendering(gloss:) in Romanizer.swift: line 61 phrasebook entry.gloss; line 71 fixed string; line 96 glossLine (Apple only); line 115 glossLine; line 124 fixed string. glossLine (131-142) returns only "Means: " + AppleTranslator output, or fixed unavailable/failed text. AppModel.swift:317 is a fixed string. Model text reaches only Respelling (latin) and the Arabic input to Apple. No path from model text to gloss (D13, D20).

## 7 Display (CLEAN)
AppModel.swift:342-347 BottomLine(heard: ScriptGuard.clean(rendering.heardEnglish), latin: ScriptGuard.clean(rendering.latin), gloss: ScriptGuard.clean(rendering.gloss), source: ScriptGuard.clean(rendering.source)). ContentView.swift:121 "You: heard" (.subheadline), :124-125 latin system size 34 newest / 22 older bold (largest), :127-128 gloss .callout, :131-133 source tag .caption2.

## 8 ModelDownloader (CLEAN)
URL .../resolve/3e4cf41e8a0cd6292831f09afef27644125c26fa/Nile-Chat-4B.Q4_K_M.gguf (line 32): HF API model sha equals that commit; resolve returns 302 then 200, X-Linked-Size 2489894752 (line 34), X-Linked-ETag 9ab2de4f...61d2 (line 35). Tree API: Nile-Chat-4B.Q4_K_M.gguf size 2489894752, lfs oid 9ab2de4f11195f5cb0e106403cf20a39785728aa12d9418b7a939b6df27e61d2. Wi-Fi: allowsCellularAccess = false (line 126). Range resume: header lines 133-135, 206 start==written check at 166-177, 200 restarts file at 178-183. Note: allowsCellularAccess=false does not block a Wi-Fi link that is a phone hotspot; not a mismatch with D9.

## 9 stripLeadingJunk (CLEAN)
Transcriber.swift:152-160. text.split(separator: " ", omittingEmptySubsequences: true) on String is valid (Character separator); .map(String.init) gives [String]; trimmingCharacters(in: .punctuationCharacters) is Foundation (imported line 1) on String. `while let first = words.first, cond` valid. "*" is Unicode punctuation (Po), trimmed only at the ends, so "f**k" survives to match. Order: line 141 stripLeadingJunk, then line 143 isKnownHallucination. Empty result returns nil via text.isEmpty.

## 10 ios-build.yml (CLEAN)
Lines 98-100 (Package step, after cd "$BUILD_DIR"): test -f Payload/EgyptTalk.app/Frameworks/llama.framework/llama, exit 1 otherwise. iOS frameworks are flat and the zip's ios-arm64 slice has llama.framework/llama, so the path is right. Upload .ipa step (build/EgyptTalk.ipa, if-no-files-found: error) is consistent with the zip location; there is no earlier copy to diff, so "unchanged" is judged by consistency only. actionlint is not installed here: NOT RUN. YAML parses with PyYAML and lists the 9 expected steps.

## 11 Swift hard errors (CLEAN)
No missing await/try, label mismatch, missing import or MainActor-from-nonisolated call found. Checked: LlamaEngine onQueue/continuation; Romanizer actor calls (engine.load/generate, translator.toEnglish/status all awaited); AppModel calls to Transcriber.download/load/process (awaited), mic.start (try), romanizer methods (awaited); ModelDownloader delegate signatures, autoreleasepool, CryptoKit import, continuation; Phrasebook tuple conversions; ContentView translationTask closure (MainActor) calling model.refreshTranslationStatus; MemoryProbe.line exists. Set and Dictionary literals have no duplicate keys.
