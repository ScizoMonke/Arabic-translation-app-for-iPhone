# Arabic to English to Arabic iOS

One iPhone app, for one phone (an iPhone 17 Pro), for one trip to Egypt.

The screen is split in the middle.
- Top: Arabic spoken around you comes out as English words you can read. Broken English is fine as long as it is understandable.
- Bottom: English you speak comes out as how to say the same thing in Egyptian Arabic, written in English letters so you can pronounce it. No Arabic script anywhere.

Folders:
- record/    the decision record, the open-flags register, and the standing traps. A decision lives here, never only in chat.
- research/  facts gathered from primary sources, one ledger file per topic, plus verify/ for independent checks of built work. Nothing here is a recommendation.
- app/       the iOS app (SwiftUI, WhisperKit). FIRST_RUN.md is the install guide. Compiled by .github/workflows/ios-build.yml on a GitHub macOS runner into an unsigned .ipa; AltStore on the PC puts it on the phone.
- data/      downloaded corpora and models, and the user's own material. Not in git.

- bench/      scripts that ran on this PC against real material, with their outputs kept: asr/ (Whisper on Egyptian broadcast speech), llm/ (small language models turning English into Egyptian), phrasebook/ (the vetted phrase list and its cross-check).
