# Decision record

Numbering D1, D2 ... is dealt by the orchestrator only. Entries are appended, never edited; a reversal is a new entry naming the one it reverses. Status: decided | open | inferred (veto open) | superseded-by Dn.

D1 (2026-10-31, decided, user) Audience and device: one user, one phone, an iPhone 17 Pro. Nothing is built for a wider user base.
D2 (2026-10-31, decided, user) Dialect: Egyptian Arabic in both directions. Confirmed by the user's father; the family being visited is in Egypt.
D3 (2026-10-31, decided, user) Top half of the screen: Arabic speech heard around the user becomes English text. Quality bar in the user's words: "speak very few word still understand". Broken English is acceptable if it is comprehensible.
D4 (2026-10-31, decided, user) Bottom half: English the user speaks becomes the Egyptian Arabic way to say the same thing, written in Latin letters as pronunciation. Not a translation into Arabic script. User: "They just need to be able to understand me."
D5 (2026-10-31, decided, user) No Arabic script is shown anywhere in the app.
D6 (2026-10-31, decided, user) Battery drain is accepted. The app is used only when needed.
D7 (2026-10-31, decided, user) Grounding rule: a research result counts as a fact only when it cites a primary source or a measurement made on this PC or on the phone. Subagent claims without either are recorded as claims and verified before anything is built on them.
D8 (2026-10-31, open, needs user) Build and install path. This PC runs Windows; iOS apps compile only on macOS and the iOS Simulator exists only on macOS. Candidate paths: (a) paid Apple Developer account + cloud macOS build runner + TestFlight; (b) free Apple ID + cloud build + AltStore/SideStore sideload from Windows with a 7-day re-sign cycle; (c) a borrowed Mac. Waiting on: whether the user has access to any Mac, and whether the yearly Apple developer fee is acceptable.
D9 (2026-10-31, open, needs user) Connectivity policy in Egypt. Fully offline, on-device, is the baseline. Whether mobile data will be available decides whether the bottom half may use a larger model over the network when connected.
D10 (2026-10-31, inferred, veto open) Pronunciation convention: phonetic respelling for an English reader with the stressed syllable in capitals, e.g. "ez-ZAY-yak". Not Arabizi (the 3/7/2 digit style Egyptians use when texting), because the user reads it to speak, not to text.
D11 (2026-10-31, inferred, veto open) Who is speaking: the app detects the language of each utterance and routes it to the matching half automatically. A manual "them / me" switch exists as a fallback for when detection is wrong.
D12 (2026-10-31, open, needs user) Trip date. Decides how much model work (fine-tuning, conversion to run on the phone) fits before departure.
