# Register

Open flags, risks and surprises. Numbered R1, R2 ... dealt by the orchestrator. Each has an owner or is explicitly declined in decisions.md. Closed entries stay, marked closed with the date and what closed them.

R1 (2026-10-31, open) The PC cannot run the app: no iOS Simulator on Windows. UI verification happens on the user's phone with the user reporting, or on a cloud Mac. Owner: orchestrator; resolves with D8.
R2 (2026-10-31, open) Egyptian dialect is under-served by off-the-shelf speech and translation models, which are mostly trained on Modern Standard Arabic. Real quality on Egyptian speech is unknown until the bench runs real Egyptian audio on this PC. Owner: bench wave.
R3 (2026-10-31, open) No large public corpus of English paired with romanized Egyptian Arabic is known yet. Likely route: generate with a large model, validate a sample with the user's father, distill into something that runs on the phone. Owner: data ledger, then user.

R4 (2026-10-31, open) The web-fetch tool used by ledger agents summarizes pages before quoting; ledger quotes and numbers are not byte-checked against raw pages. Any number a build leans on is re-read from the raw source or measured here first. Owner: orchestrator, applied at every brief.
R5 (2026-10-31, open) No openly licensed Egyptian conversational test audio was found. The bench will measure on the Hugging Face mirror of MGB-3 (MightyStudent/Egyptian-ASR-MGB-3, no license tag) and the ArzEn wav mirror, as private research use for one user. Not redistributed. Owner: bench wave; closes when a licensed source appears or the user accepts the research-use reading.
R6 (2026-10-31, open) Leads for the bottom half from research/ledger/data.md, unverified by download: UBC-NLP/nilechat-arabizi-egy (romanized Egyptian, gated, CC-BY-NC-4.0); MBZUAI-Paris/Egyptian-SFT-Mixture; HeshamHaroon/ArzEn-MultiGenre (25,557 human Egyptian-English pairs, CC-BY-4.0, Arabic script); Mo-Abdalkader Egyptian-English 1M-sentence corpus (origin unstated, probably machine-made); arbml/Arabizi_Transliteration. Owner: next data wave after the on-device model ledger lands.
