# Apple APIs ledger (read 2026-10-31)

Reading method note: WebFetch returns a small-model summary of each page, not raw HTML. Quotes below are as returned by that tool; treat quote fidelity as tool-mediated.

## E1 Apple "iOS and iPadOS 27 - Feature Availability" (facts 1, 5, current OS)
- Source: Apple, apple.com marketing page, title "iOS and iPadOS 27 - Feature Availability - Apple", footer "Copyright (c) 2026 Apple Inc.", no update date shown.
- URL: https://www.apple.com/ios/feature-availability/  Read: 2026-10-31. Reached: guessed canonical URL after web search (query "Apple iOS and iPadOS feature availability dictation languages Arabic on-device") returned no Apple page.
- Class: vendor-doc
- Current major version: page is for iOS and iPadOS 27 ("The page doesn't mention iOS 26"); footnote: "Siri AI is available in beta in iOS 27, iPadOS 27, macOS 27, watchOS 27, and visionOS 27."
- Dictation main list: "Arabic (Saudi Arabia)" and "Arabic (United Arab Emirates)".
- "On-Device and Modeless Dictation": list begins "Arabic, Cantonese (Hong Kong), Cantonese (Simplified, China mainland), Danish (Denmark), Dutch (Belgium)" (plain "Arabic", no regional variant). "Dictate Emoji": "Arabic".
- Live Translation with AirPods (verbatim list, no Arabic): "Chinese (Mandarin, Simplified) - not available in China mainland"; "Chinese (Mandarin, Traditional)"; "English (United Kingdom)"; "English (United States)"; "French (France)"; "German (Germany)"; "Italian"; "Japanese"; "Korean"; "Portuguese (Brazil)"; "Spanish (Spain)". No Arabic in Live Translation in Messages, Phone and FaceTime, or AirPods.
- Translate App: "Arabic, Dutch, English (United Kingdom), English (United States), French (France), German (Germany), Hindi" / "Indonesian, Italian (Italy), Japanese, Korean, Mandarin Chinese (China mainland), Mandarin Chinese (Taiwan), Polish" / "Portuguese (Brazil), Russian, Spanish (Spain), Thai, Turkish, Ukrainian, Vietnamese".
- System-Wide Translation: "Arabic, Danish, Dutch, English (United Kingdom), English (United States), Finnish, French (France), German (Germany)," / "Hebrew, Hindi, Indonesian, Italian (Italy), Japanese, Korean, Malay, Mandarin Chinese (China mainland)," / "Mandarin Chinese (Taiwan), Norwegian Bokmal, Polish, Portuguese (Brazil), Russian, Spanish (Spain)," / "Swedish, Thai, Turkish, Ukrainian, Vietnamese".
- Siri: Translations: "Arabic"; Siri On-Device Speech Processing and Offline Requests: "Arabic"; Siri country list: "Saudi Arabia (Arabic)", "United Arab Emirates (Arabic)". Apple Intelligence: no Arabic entry in the footnote language list.
- Caveat: this is the iOS 27 page; the iOS 26 version of the page was not fetched.
- FACT 5 result: Arabic ABSENT from AirPods Live Translation on this (iOS 27) page; PRESENT in Translate app.

## E2 Secondary search summary (facts 5)
- Source: WebSearch result summary (not a primary page), query "Live Translation AirPods supported languages iOS 26 list". Class: third-party (press, 9to5mac / igeeksblog) - closest class: forum-anecdote; not relied on.
- Says: launch set English (US/UK), French, German, Portuguese (Brazil), Spanish (Spain); iOS 26.1 added Mandarin simplified/traditional, Italian, Japanese, Korean. Hindi not supported. Titles in results hint at "Apple Live Translation Gets More Useful for Travellers With iOS 27" (livefromalounge.com), not read.

## E3 SpeechTranscriber class doc (fact 2)
- Source: Apple developer documentation, markdown rendering, copyright 2026. URL: https://developer.apple.com/documentation/speech/speechtranscriber.md  Read 2026-10-31. Reached: link in search result for "SpeechTranscriber supportedLocales Arabic ar-SA SpeechAnalyzer locales list iOS 26" (the HTML page URL returned only a title; the .md form returned content). Class: vendor-doc
- Availability: "iOS: 26.0.0 -".
- Verbatim: "Use the `isAvailable` or `supportedLocales` properties to see if the current device supports the speech-to-text models used by `SpeechTranscriber`. If it does not, consider disabling the feature or using `DictationTranscriber` instead."
- "static var supportedLocales: [Locale]" : "The locales that the transcriber can transcribe into, including locales that may not be installed but are downloadable."
- "static var installedLocales: [Locale]": "The locales that the transcriber can transcribe into, considering only locales that are installed on the device."
- "static func supportedLocale(equivalentTo: Locale) async -> Locale?": "A locale from the module's supported locales equivalent to the given locale."
- Page itself contains no locale list.

## E4 Apple Developer Forums thread 797835 (fact 2, Arabic)
- Source: Apple Developer Forums, posts by developers cvasselli (OP, Aug 2025), vilimas, nasirdfd, vincent123, eddiewangyw, and account "Apple_Agent" (page does not state the account's role; it is the only account giving Apple-side answers). URL: https://developer.apple.com/forums/thread/797835  Read 2026-10-31. Reached: search result for the SpeechTranscriber/Arabic query above. Class: forum-anecdote (the Apple_Agent posts are an Apple-side statement in a forum; role unverified)
- OP: "Error Domain=SFSpeechErrorDomain Code=1 "transcription.ar asset not found after attempted download.""
- vilimas Sep '25: "the Arabic language is listed as a supported language, but the model is not downloadable."
- nasirdfd Sep '25: "I have also been testing on beta releases and on public release as well but not working for Arabic locale."
- vincent123 Dec '25: "Arabic used to work, at least it definitely did in iOS 26.0. Has the support been removed?"
- Apple_Agent Jan '26 (verbatim, full reply): "`SpeechTranscriber` erroneously listed Arabic as "supported". It actually wasn't."
- eddiewangyw Apr '26: "I've been doing a quick validation transcription per locale before shipping rather than trusting the supportedLocale API - it's been unreliable across betas for several languages, not just Arabic."
- Apple_Agent Aug '25 on download: "You can try another `downloadAndInstall()` call ... that isn't an error and won't result in duplicated downloads." Models download on device via AssetInventory / AssetInstallationRequest.
- Note: contradictory claims inside thread (vincent123 says it worked in 26.0; Apple_Agent says it never was supported). Both recorded.

## E5 Anton Gubarenko, "iOS 26: SpeechAnalyzer Guide" (fact 2)
- Source: individual developer Substack, Jul 28 2025, updated Sep 15. URL: https://antongubarenko.substack.com/p/ios-26-speechanalyzer-guide  Read 2026-10-31. Reached: search result. Class: third-party-measurement (author-reported supportedLocales output; method not stated)
- Verbatim list returned by SpeechTranscriber.supportedLocales: "ar_SA, da_DK, de_AT, de_CH, de_DE, en_AU, en_CA, en_GB, en_IE, en_IN, en_NZ, en_SG, en_US, en_ZA, es_CL, es_ES, es_MX, es_US, fi_FI, fr_BE, fr_CA, fr_CH, fr_FR, he_IL, it_CH, it_IT, ja_JP, ko_KR, ms_MY, nb_NO, nl_BE, nl_NL, pt_BR, ru_RU, sv_SE, th_TH, tr_TR, vi_VN, yue_CN, zh_CN, zh_HK, zh_TW."
- Dated before the Apple_Agent Jan 2026 statement in E4 that ar was erroneously listed.
- "New class in the space. Handles language models and downloadable assets." (AssetInventory); "you can programmatically check and preload language packs (offline!)".

## E6 DictationTranscriber class doc (facts 1, 2)
- Source: Apple developer documentation (.md rendering), (c) 2026. URL: https://developer.apple.com/documentation/speech/dictationtranscriber.md  Read 2026-10-31. Reached: URL pattern from E3. Class: vendor-doc. Availability "iOS: 26.0.0 -".
- Verbatim: "This transcriber uses the same speech-to-text machine learning models as system dictation features do, or as `SFSpeechRecognizer` does when it is configured for on-device operation. This transcriber does not support languages or locales that `SFSpeechRecognizer` only supports via network access."
- Also has static supportedLocales / installedLocales / supportedLocale(equivalentTo:); no locale list on page.

## E7 SFSpeechRecognizer.supportsOnDeviceRecognition doc (fact 1)
- Source: Apple developer documentation (.md). URL: https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition.md  Read 2026-10-31. Reached: URL pattern. Class: vendor-doc. Availability iOS 13.0.
- Verbatim: "A Boolean value that indicates whether the speech recognizer can operate without network access." / "If `supportsOnDeviceRecognition` is `false`, the `SFSpeechRecognizer` requires a network in order to recognize speech."
- The page lists no locales.

## E8 Search for iOS 27 / WWDC26 Speech changes (fact 2)
- Query "WWDC26 Speech framework SpeechAnalyzer new languages iOS 27 SpeechTranscriber": results only WWDC25 session 277 pages and a dev.to summary. No WWDC26 Speech content surfaced.

## E9 SFSpeechRecognizer.supportedLocales() doc (fact 1)
- Source: Apple developer documentation (.md). URL: https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportedlocales().md  Read 2026-10-31. Reached: URL pattern. Class: vendor-doc. Availability iOS 10.0.
- Verbatim: "Speech recognition supports the same locales that are supported by the keyboard's dictation feature. For a list of these locales, see QuickType Keyboard: Dictation [https://www.apple.com/ios/feature-availability/#quicktype-keyboard-dictation]."
- Verbatim: "Support for a locale does not guarantee that speech recognition is currently possible for that locale. For some locales, the speech recognizer requires an active Internet connection to communicate with Apple's servers."
- Per E1 the Dictation list names "Arabic (Saudi Arabia)" and "Arabic (United Arab Emirates)"; ar-EG not named in that list; "On-Device and Modeless Dictation" names "Arabic" (E1).

## E10 mbsplugins.eu locale dump (fact 1) - from search snippet only, page not fetched
- Source: MBS plugins (third party), page "SpeechRecognitionSupportedLocales", ~2019 per search summary. URL: https://mbsplugins.eu/SpeechRecognitionSupportedLocales.shtml  Reached: search "SFSpeechRecognizer.supportedLocales() list ar-SA ar-AE ...". Class: third-party-measurement (old). Search summary says it includes ar-SA and not ar-AE. Not verified by me.

## E11 TranslationSession class doc (fact 3)
- Source: Apple developer documentation (.md). URL: https://developer.apple.com/documentation/translation/translationsession.md  Read 2026-10-31. Reached: URL pattern. Class: vendor-doc. Availability: iOS 18.0, macOS 15.0, macCatalyst 26.0.
- Verbatim: "Another way for contexts where there's no UI, you can directly initialize the TranslationSession using init(installedSource:target:) to translate between languages. This initializer requires that you specify which source language you use and throws an error if the languages aren't already installed on the person's device."
- Verbatim: "Note: All translations using the `TranslationSession` class are processed on the user's device. Apple may collect API usage and performance metrics including the app bundle ID and the original and translated language, but this data does not include the original or translated content."
- "func prepareTranslation() async throws: Asks for permission to download translation languages without doing any translations."
- "var canRequestDownloads: Bool: A boolean value that indicates whether a translation session can request language downloads."
- "struct Strategy: The preferred model to handle translations in your app." (init(installedSource:target:preferredStrategy:) exists.)
- No length or rate limit stated on this page.

## E12 TranslationSession.Strategy doc (fact 3)
- URL: https://developer.apple.com/documentation/translation/translationsession/strategy.md  Read 2026-10-31. Reached: URL pattern. Class: vendor-doc. Availability iOS 26.4.0 -.
- Verbatim: "highFidelity: A translation strategy that provides more fluent translations using Apple Intelligence." "lowLatency: A translation strategy that provides fast translations using traditional models." "The framework uses this strategy when available, or automatically selects an appropriate alternative based on device capabilities and language availability."

## E13 LanguageAvailability doc (fact 3)
- URL: https://developer.apple.com/documentation/translation/languageavailability.md  Read 2026-10-31. Class: vendor-doc. iOS 18.0.
- "var supportedLanguages: [Locale.Language]: A list of translation languages the framework supports." Status enum cases used in sample: .installed, .supported, .unsupported. "status(for: String, to:)": "Checks to see if the framework supports the language pairing based off a string of sample text."
- Page contains no language list. (Per E1, Translate app list includes Arabic; the framework list was not directly retrieved.)

## E14 SystemLanguageModel doc (fact 4)
- URL: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel.md  Read 2026-10-31. Class: vendor-doc. iOS 26.0.
- Verbatim: "The `SystemLanguageModel` refers to the on-device text foundation model that powers Apple Intelligence." "Currently, there are 3 model versions that align with: iOS, iPadOS, macOS, and visionOS 26.0 - 26.3; 26.4; 27.0".
- "var supportedLanguages: Set<Locale.Language>: Languages that the model supports." "func supportsLocale(Locale) -> Bool". "var contextSize: Int: The maximum context size in tokens that the model supports." "Model availability depends on whether the device and region supports Apple Intelligence."
- No language list, parameter count, or context value on this page.

## E15 Foundation Models adapter training toolkit page (fact 4)
- Source: Apple Developer, marketing/doc page for developers. URL: https://developer.apple.com/apple-intelligence/foundation-models-adapter/  Read 2026-10-31. Reached: guessed URL. Class: vendor-doc
- Verbatim: "Version 26.0.0 is the last release of this toolkit and is not compatible with macOS, iOS, iPadOS, or visionOS 27 and later."
- "Replace the "content" values above with your prompt and response, which can be text written in any language supported by Apple Intelligence."
- "Mac with Apple silicon and at least 32GB memory, or Linux GPU machines"; "Python 3.11 or later".
- "Each adapter is compatible with a single specific system model version ... you will need to train a different adapter for every version of the system model."
- "Each adapter will take approximately 160 MB of storage space in your app."
- Entitlement: "the Account Holder of a membership in the Apple Developer Program will need to request the Foundation Models Framework Adapter Entitlement." "You don't need this entitlement to train or locally test adapters."
- Language limit: only "any language supported by Apple Intelligence"; no explicit list on page.

## E16 Apple ML Research, "Updates to Apple's On-Device and Server Foundation Language Models" (fact 4)
- Source: Apple Machine Learning Research blog, published June 9, 2025. URL: https://machinelearning.apple.com/research/apple-foundation-models-2025-updates  Read 2026-10-31. Reached: search "Apple Foundation Models 2025 tech report ... 3 billion parameters". Class: vendor-doc
- Verbatim (as relayed): "approximately 3-billion-parameter model"; "are designed to support 15 languages" (not listed); "extended our multilingual support to new languages that will be available later this year" (not named). Context length of on-device model not stated.
- Tech report (not fetched): arXiv 2507.13575, https://arxiv.org/pdf/2507.13575v2 ; a secondary summary said 16 languages (unverified).

## E17 Apple "Foundation Models updates" (fact 4, iOS 27)
- URL: https://developer.apple.com/documentation/updates/foundationmodels.md  Read 2026-10-31. Reached: search result. Class: release-note
- June 2026: "Use the latest on-device SystemLanguageModel that follows instructions more accurately and produces better results ... Because the model changes when a person updates to iOS 27 ... test your prompts with the new model". Also: "Use PrivateCloudComputeLanguageModel to access more reasoning capabilities and a larger context size." "Adopt the LanguageModel protocol to use any large language model - server or on-device".
- Feb 2026: new on-device model for iOS 26.4; "contextSize" property added; "#Playground ... estimate of the usage of 4,096 tokens in the available context window."
- No language additions mentioned in either entry.
- 404 for https://developer.apple.com/documentation/foundationmodels/supported-languages-and-locales.md (guessed URL).

## E18 Apple Intelligence languages (fact 4)
- Source: Apple Support page (id 121115, guessed URL; page content identified as Apple Intelligence "Supported languages and regions"; page title/date not captured). URL: https://support.apple.com/en-us/121115  Read 2026-10-31. Class: vendor-doc
- Verbatim: "English, Danish, Dutch, French, German, Italian, Norwegian, Portuguese, Spanish, Swedish, Turkish, Vietnamese, Chinese (simplified), Chinese (traditional), Japanese, and Korean." Arabic does not appear. (16 entries counting English as one.)
- Relevance: E15 ties adapter training data to "any language supported by Apple Intelligence". Which OS version this page tracks was not verified.

## E19 iPhone 17 Pro Tech Specs (fact 6)
- Source: Apple Support. URL: https://support.apple.com/en-us/125090  Read 2026-10-31. Reached: search "iPhone 17 Pro tech specs Apple support A19 Pro 16-core Neural Engine Neural Accelerators" (apple.com/iphone-17-pro/specs/ fetched but contained no spec text; its page also linked an iPhone 18 Pro page). Class: vendor-doc
- Verbatim: "A19 Pro chip / 6-core CPU with 2 performance and 4 efficiency cores / 6-core GPU with Neural Accelerators / 16-core Neural Engine / Hardware-accelerated ray tracing". Capacity: "256GB", "512GB", "1TB". The page makes no statement about RAM.

## E20 GSMArena, iPhone 17 series early Geekbench (fact 6, RAM)
- Source: GSMArena news, author "Michail", 10 Sep 2025. URL: https://www.gsmarena.com/iphone_17_series_early_geekbench_scores_show_minor_gains_-news-69431.php  Read 2026-10-31. Reached: search "iPhone 17 Pro A19 Pro 12GB RAM teardown OR Geekbench memory". Class: third-party-measurement (Geekbench-listing derived; article cites two Geekbench Browser searches, method not stated explicitly)
- Verbatim: "Like the Air, the 17 Pro brings 12GB LPDDR5x RAM."
- Search summary also noted, not fetched: Android Headlines (2025-09) "both the iPhone 17 Pro and Pro Max feature 12GB RAM"; gori.me, consomac.fr headlines say 17 Pro/Air 12GB, A19 8GB; no teardown found in that search.

## E21 iFixit "iPhone 17 Pro Chip ID" (fact 6, RAM)
- Source: iFixit guide, Shahram Mokhtari + contributor, published Nov 5, 2025. URL: https://www.ifixit.com/Guide/iPhone+17+Pro+Chip+ID/196117  Read 2026-10-31. Reached: search "iFixit iPhone 17 Pro teardown RAM SK hynix A19 Pro 12GB". Class: third-party-measurement (physical chip ID from a teardown)
- Verbatim: "Samsung K3KLMLM0FM-HGGV 12 GB LPDDR5X SDRAM"; "Apple APL1V12/339S01837 A19 Pro hexa-core applications processor w/ GPU & Neural Engine"; "Kioxia K5A4CG1685 ? 256 GB NAND flash memory".
- Pre-release supplier reports (Samsung main DRAM supplier) were in search results, not fetched.

## E22 os_proc_available_memory doc (fact 7)
- Source: Apple developer documentation (.md). URL: https://developer.apple.com/documentation/os/os_proc_available_memory.md  Read 2026-10-31. Reached: search "iOS jetsam memory limit per app iPhone 12GB RAM measured os_proc_available_memory ...". Class: vendor-doc. iOS 13.0.
- Verbatim: "Memory limits can change during the app life cycle and don't necessarily correspond to the amount of physical memory available on the device." "The returned value corresponds to the current memory limit minus the memory footprint of your app at the time of the function call." "Use the returned value as advisory information only and don't cache it."
- Apple publishes no numeric per-app ceiling on this page.

## E23 Apple Developer Forums thread 834805, "iPhone app memory limit seems capped to 6GB" (fact 7)
- Source: forum post by lemon123 (OP), Core ML forum, created Jun 2026; 0 replies, no Apple response; iOS version not stated; Radar FB23183521. URL: https://developer.apple.com/forums/thread/834805  Read 2026-10-31. Reached: search result. Class: third-party-measurement (single developer, self-reported, measured with os_proc_available_memory() + task_vm_info.phys_footprint) / forum-anecdote
- Verbatim: "I'm seeing a flat per-app memory ceiling of about 6 GB on iPhone, even on devices with more physical RAM and with com.apple.developer.kernel.increased-memory-limit."
- "the total process budget stays around 6144 MB on both: iPhone 16 Pro Max, 8 GB RAM; iPhone 17 Pro Max, 12 GB RAM"
- "`increased-memory-limit` only: ~6144 MB; `increased-memory-limit` + `extended-virtual-addressing`: ~6144 MB, no change; `increased-memory-limit` + `increased-debugging-memory-limit`: ~6656 MB"
- "The model loads at about 4.4 GB resident, leaving roughly 1.7 GB for inference/prefill." (Gemma 4 multimodal in mlx-swift-lm.)
- "I have also observed that 12 GB iPad devices expose more memory to an app than 12 GB iPhone devices but I didn't measure specifically".
- Search summary only (not fetched): forum report of WebContent killed at "ActiveHard 2048 MB" on iPhone 17 Pro; 2020 thread (688973) ActiveHard 2098 MB on 4 GB iPhone 12.

## E24 "Translating text within your app" (fact 3)
- Source: Apple developer documentation sample-code article, associated with WWDC24 session 10117. URL: https://developer.apple.com/documentation/translation/translating-text-within-your-app.md  Read 2026-10-31. Reached: URL pattern. Class: vendor-doc. iOS 18.0.
- Verbatim: "With the customizable translation APIs, the framework asks a person for permission to download the language translation models, if necessary."
- "This sample code project runs only in macOS and on physical iOS devices. It doesn't translate text in iOS or iPadOS simulators."
- "If the languages aren't already downloaded, a view appears that requests permission to download them." (prepareTranslation())
- "In iOS, you can manage your downloaded languages by choosing Settings > Apps > Translate > Downloaded Languages if you have the system Translate app installed locally on your device."
- "The framework doesn't support translation between the same language, such as British English (en-GB) and U.S. English (en-US)."
- Batch: "it's most efficient to use one of the batch translation functions"; no length or rate limit stated.
- Together with E11: the SwiftUI path (.translationTask) can present a download-permission sheet; the no-UI path is init(installedSource:target:) which "throws an error if the languages aren't already installed". E11 shows no iOS-version annotation on that initializer; a Flutter plugin (pub.dev local_translation, search snippet only, class forum-anecdote/repo-readme, not fetched) claims headless sessions need iOS 26 / macOS 26. Unverified.

## E25 Speech updates (fact 2, iOS 27)
- URL: https://developer.apple.com/documentation/updates/speech.md  Read 2026-10-31. Class: release-note
- Only June 2026 entries: AssetInputSequenceProvider / CaptureInputSequenceProvider for audio input; "AnalyzerInputConverter to convert AVAudioBuffer data into formats that AnalyzerInput supports." No locale additions listed.
- https://developer-mdn.apple.com/ios/whats-new/ ("What's new in iOS 27"): no mention of Speech, Translation or Arabic; mentions "Siri's language understanding evolves or expands to new languages and regional dialects" (no list).
- https://developer.apple.com/documentation/updates/translation.md returned 404.

## E26 Translate-app Arabic variants (fact 3, search only)
- Query "Translation framework iOS 18 TranslationSession supportedLanguages Arabic ar-EG Egyptian dialect Modern Standard Arabic": no source found naming ar-EG or Egyptian Arabic in the Translation framework. Search summary: Translate app has offered Arabic since 2020; WWDC24 summary (wwdcnotes.com/documentation/wwdc24-10117-meet-the-translation-api/) lists Arabic. Not fetched.

## NOT FOUND
- NOT FOUND: Apple's verbatim list of SpeechTranscriber.supportedLocales on iOS 26.x/27 after the Jan 2026 correction. Searched: developer.apple.com SpeechTranscriber (.md and html), supportedLocales() pages, WWDC26 Speech search; only a Jul-Sep 2025 third-party dump (E5) and the forum statement (E4) exist.
- NOT FOUND: whether ar-EG appears in any Apple speech locale list. Dictation list on E1 names only ar-SA and ar-AE; On-device dictation names plain "Arabic". A full SFSpeechRecognizer.supportedLocales() output and per-locale supportsOnDeviceRecognition for Arabic were not retrieved (Apple page defers to the feature-availability Dictation list, E9). The full On-Device Dictation list beyond its first five entries was not read.
- NOT FOUND: any documented length or rate limit for TranslationSession. Searched: TranslationSession.md, translating-text-within-your-app.md, LanguageAvailability.md.
- NOT FOUND: the actual LanguageAvailability.supportedLanguages contents including Arabic variants (needs a device).
- NOT FOUND: Foundation Models supportedLanguages list, and any Arabic in it; context size value; iOS 27 model parameter count. Searched: SystemLanguageModel.md, updates/foundationmodels.md, supported-languages-and-locales.md (404), Apple ML 2025 updates. Only Apple Intelligence languages page (E18) with no Arabic, and the "approximately 3-billion-parameter" 2025 statement (E16).
- NOT FOUND: iOS 26 (as opposed to 27) version of the AirPods Live Translation list from Apple; E1 is the iOS 27 page. Press (E2) says the 26.1 list had the same 11 entries, no Arabic.
- NOT FOUND: any Apple-documented numeric per-app jetsam ceiling for a 12 GB iPhone; only E22 (no numbers) and E23 (single measurement). Apple "increased memory limit" entitlement doc page was not fetched.
- NOT FOUND: Apple-published iPhone 17 Pro RAM figure (E19 silent).
