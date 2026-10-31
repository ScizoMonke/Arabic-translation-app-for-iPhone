# Ledger: Egyptian Arabic data sources (harvest)
Read date for all entries unless noted: 2026-10-31. Caveat: WebFetch/WebSearch pass pages through a summarizing model; quotes below are what that tool returned as quoted text, not byte-checked against raw pages. Nothing downloaded.

## 1. ArzEn / ArzEn-ST / ArzEn-MultiGenre
### 1a. ArzEn (speech, code-switched)
- Source: Hamed et al., LREC 2020 paper, ACL Anthology. Evidence: paper. Reached: web search "ArzEn-ST Egyptian Arabic English code-switched speech translation dataset hours", then fetch https://aclanthology.org/2020.lrec-1.523
- Quotes: "The corpus is collected through informal interviews with 38 Egyptian bilingual university students and employees"; "The corpus is mainly designed to be used in Automatic Speech Recognition (ASR) systems"
- Contents: speech + transcripts, Egyptian-English code-switching. Size: 12 hours (per search summary of paper/thesis; not seen verbatim). Dialect: Egyptian. English parallel: no (code-switched within utterance).
- License: page gives none for corpus (Anthology footer: materials since 2016 "licensed under CC BY 4.0" covers hosted paper only). Obtain: NOT STATED; no download link on the Anthology page.
- HF: "MBZUAI/ArzEn" exists (api listing, last modified 2025-06-11, no tags); raw README fetch returned 404 (https://huggingface.co/datasets/MBZUAI/ArzEn/raw/main/README.md). "ahmedsamirtarjama/MBZUAI_ArzEn_wav" exists (audio+text parquet, 1K-10K rows, 2025-11-23, no license tag; third party, unverified).
### 1b. ArzEn-ST (speech translation, three-way)
- Source: Hamed, Habash, Abdennadher, Vu, WANLP 2022. Evidence: paper. URL https://arxiv.org/abs/2211.12000 (fetched). Reached: search then fetch.
- Quote: "We make the translation guidelines and corpus publicly available." Abstract: extends ArzEn; translations into monolingual Egyptian Arabic and monolingual English.
- Contents: speech (from ArzEn) + code-switched transcripts + Egyptian Arabic text translation + English text translation. Size: ~12 h audio (search summary of thesis, unverified for ST); arXiv page states no size. License: arXiv page CC BY 4.0 applies to the article only; corpus license not stated. Obtain: no URL on arXiv abstract page. https://github.com/gtrg/ArzEn-ST returned 404 (guessed URL). Official download URL: NOT FOUND.
- HF mirrors in listing (third party): Mennatu/ARZEN-ST (apache-2.0, 2025-03-26, no content tags); taha-alnasser/ArzEn-CodeMixed (afl-3.0, 1K-10K, csv, 2025-05-09).
### 1c. ArzEn-MultiGenre (text)
- Source: HF card HeshamHaroon/ArzEn-MultiGenre (third-party re-upload of Mendeley Data). Evidence: dataset-page. URL https://huggingface.co/datasets/HeshamHaroon/ArzEn-MultiGenre ; fetched raw README. Reached: HF API search "arz".
- Card (as summarized): "a parallel dataset of Egyptian Arabic and English text, drawn from song lyrics, novels, and TV show subtitles"; human experts translated and aligned. 25,557 segment pairs (metadata says 1K<n<10K, inconsistent). License CC-BY-4.0. Original: Rania Al-Sabbagh, Univ. of Sharjah, Mendeley Data v3, 2023-12-28, DOI 10.17632/6k97jty9xg.3. HF last modified 2023-12-31. Text; Arabic script; English parallel yes; Egyptian yes. Obtain: HF direct (fetch succeeded, not gated) or Mendeley DOI.
- Also HF: arbml/ArzEn_MultiGenre_songs, _novels, _subtitles (1K<n<10K each, 2024-04-06, no license tag).

## 2. MADAR (Cairo)
- Source: CAMeL Lab NYUAD page. Evidence: dataset-page. URL https://camel.abudhabi.nyu.edu/madar-parallel-corpus/ . Reached: direct fetch.
- Quotes: "a collection of parallel sentences covering the dialects of 25 cities from the Arab World"; "solely for your internal research and evaluation purposes"; "We do not provide the English or the French versions of the corpus because of copyright restrictions."
- Contents: text, Arabic script (no romanization mentioned), built from BTEC travel expressions. Corpus-26: 2,000 sentences x 25 cities + MSA. Corpus-6: 12,000 sentences x 5 cities (Cairo, Doha, Beirut, Tunis, Rabat) + MSA. Cairo in both. English side NOT distributed; contact u-star-sec@ustarconsortium.com. License: CMU/NYUAD 2019, internal research and evaluation only, no redistribution; commercial via CMU CTTEC. Obtain: Google Form linked on page. Last update: not stated (license 2019, LREC 2018).

## 3. MGB-3
- Source: paper arXiv 1709.07276 (via search summaries only; https://arabicspeech.org/resources/mgb-3/ returned 404). Evidence: paper (secondhand summary). Reached: search "MGB-3 Egyptian Arabic broadcast YouTube dataset hours arabicspeech.org".
- Per search summary: 16 hours Egyptian Arabic speech, 80 YouTube videos, 7 genres, first 12 min of each; adaptation/dev/eval split. Speech + transcripts (Arabic script). English parallel: no. License/obtain: NOT STATED in what I read.
- HF third party: MightyStudent/Egyptian-ASR-MGB-3 (ASR, 1K<n<10K, 25 likes, 2024-09-03, no license tag, arxiv:1709.07276). QCRI/DACS on HF reportedly includes 2 h Egyptian from ADI-5 dev (search summary, unverified).

## 4. CALLHOME Egyptian Arabic
- LDC97S45 speech. Evidence: dataset-page. https://catalog.ldc.upenn.edu/LDC97S45 . Quote: "consists of 120 unscripted telephone conversations between native speakers of Egyptian Colloquial Arabic (ECA)." Calls "lasted up to 30 minutes". Fee: "Login for the applicable fee." (no price visible); license "LDC User Agreement for Non-Members". Year 1997. Size in hours not stated on page.
- LDC97T19 transcripts. https://catalog.ldc.upenn.edu/LDC97T19 . Quote: "The transcripts cover a contiguous five or ten minute segment taken from 120 unscripted telephone conversations." Page says "provided in standard orthography" (does NOT say romanized). CONFLICT: a search summary attributed to LDC documentation (https://catalog.ldc.upenn.edu/docs/LDC97T19/ar-trans.txt) said romanized orthography with both romanized and Arabic-script versions; that docs file was not fetched, so unverified.
- Related (search summary only, unfetched, all LDC fee-based): LDC99L22 lexicon; LDC2002T38 transcripts supplement; LDC2025T14 "BOLT CTS CALLFRIEND CALLHOME Egyptian Arabic Transcripts and Translations" (116 hours, English translations); LDC2017T07 BOLT Egyptian Arabic SMS/Chat and Transliteration (1,856 Arabizi conversations transliterated to Arabic script).
- Free derived subsets: NOT FOUND. Searched: "LDC CALLHOME Egyptian Arabic Speech LDC97S45 transcripts". Lhotse has a recipe (lhotse.readthedocs.io callhome_egyptian) that requires the LDC data.

## 5. Egyptian Arabic Wikipedia (arz)
- https://dumps.wikimedia.org/arzwiki/latest/ . Evidence: dataset-page. Fetched directly.
- Listing dated 01-Oct-2026: arzwiki-latest-pages-articles.xml.bz2 = 299,281,321 bytes; pages-articles-multistream.xml.bz2 = 354,092,424; pages-meta-current 320,792,319; langlinks.sql.gz 153,454,988 (inter-language links, titles only). Text, Arabic script, Egyptian; no English parallel beyond langlinks titles. License: not stated on index page. Obtain: direct download, no registration.

## 6. Tatoeba arz
- https://tatoeba.org/en/stats/sentences_by_language . Evidence: dataset-page. Fetched.
- Rows: "Egyptian Arabic (arz): 1,593" sentences (rank 136); "Arabic (ara): 68,832". Quote: "Our data is released under various Creative Commons licenses." English-link count: NOT FOUND (not on stats page). Download page not fetched.

## 8. Lisaan Masry
- https://lisaanmasry.org fetch failed: certificate error (host not in cert; cert names eu.lisaanmasry.org, m.eu.lisaanmasry.org). https://eu.lisaanmasry.org/ returned near-empty page: titled "Egyptian Arabic Dictionary" with a refresh notice. Evidence: dataset-page (empty). A search hit https://eu.lisaanmasry.org/grammar/numbers.html titled "Egyptian Arabic Grammar" exists (not fetched).
- Downloadable data, phonetic/romanized transcription, license, size: NOT FOUND. Searched: "Lisaan Masry Egyptian Arabic phonetic transcription dataset"; fetch of lisaanmasry.org and eu.lisaanmasry.org.

## 9/10/12. Hugging Face and Arabizi findings (HF API listing via https://huggingface.co/api/datasets?search=<term>&limit=100, read 2026-10-31; evidence dataset-page metadata; tags are uploader-supplied, unverified)
- Search "egyptian" (first 30 of many; sorted by downloads): ehabnegm/100-hour-Egyptian-dataset-single-speaker (cc-by-nc-4.0, TTS/ASR audio, 2026-08-07); ismaeeelxd/Egyptian-Arabic-Lectures (mit, ASR, code-switching, 2026-06-21); Rabe3/egyptian-arabic-tts-diacritized (license other, 2026-08-19); ammarthabet/egyptian-arabic-speech (n<1K audio, 2026-05-19); MightyStudent/Egyptian-ASR-MGB-3; ismailelsayedeltanja/Egyptian-dialect-8k (c-uda, audio+text, language ar+en, 2026-07-24); Mo-Abdalkader/Egyptian-Arabic-English-Parallel-Corpus (cc-by-4.0, 100K-1M, 2026-09-18); fr3on/egyptian-dialogue (cc-by-4.0, ar+en, translation, "subtitles", 1K-10K, 2025-12-22); MBZUAI-Paris/Egyptian-SFT-Mixture (arz, 1M-10M, 2025-06-17); Omartificial-Intelligence-Space/FineWeb2-Egyptian-Arabic (odc-by, 10M-100M, 2024-12-12); miscovery/General_Facts_in_English_Arabic_Egyptian_Arabic (mit, 10K-100K, csv, 2025-04-06); IbrahimAmin/egyptian-arabic-fake-reviews (mit, ar/arz/en); ISLAM-PO/documents-Egyptian-Arabic (apache-2.0, n<1K); masterofaudio2077/egyptian-emotion-tts (apache-2.0, tagged "synthetic"). Result truncated; 111k characters unread.
- Mo-Abdalkader/Egyptian-Arabic-English-Parallel-Corpus: card (raw README fetched) quote: "A comprehensive **Egyptian Arabic -> English** parallel corpus covering **1,800 topics** from daily Egyptian life". 404,010 samples / 1,051,924 sentences (SFT train 264,065; test 17,993; DPO 121,952). License "CC BY 4.0". Card does not say whether LLM- or human-generated and names no source. Arabic script, English parallel yes.
- IbrahimAmin/arz-en-parallel-corpus (card fetched): "cleaned and filtered merge of multiple Egyptian Arabic - English parallel corpora"; 25,000 train + 1,851 test; MIT; sources named: ArzEn-MultiGenre, Egyptian_English_parallel (Hesham Haroon), arbml ArzEn_MultiGenre_subtitles, ArzEn-ST. Arabic script + English.
- ehabnegm/masri-podcast-300h-egyptian-tts (card fetched): audio "sourced from public YouTube podcasts"; "released for research use"; cc-by-nc-4.0; transcripts ASR-generated (Soniox stt-async-v5), "not human-verified"; hours not stated (clip count 100K-1M). Relevant to item 13 only as an anecdote of scraped YouTube podcasts, rights of the podcasters not stated.
- Search "arz": HeshamHaroon/ArzEn-MultiGenre; IbrahimAmin/arz-en-parallel-corpus; ymoslem/news-commentary-eng-arz (eng+arz, 10K-100K, arxiv:2510.22763, 2026-02-15, no license tag; likely machine-translated, unverified); ptrdvn/kakugo-arz (apache-2.0, arz, 10K-100K, conversation, "data-distillation", arxiv:2601.14051, 2026-01-27; LLM-generated by its tags); amanuelbyte/en-arz-translated-dataset (10K-100K, 2025-10-01); amanuelbyte/african_speech_dataset_arz (2026-03-31).
- Search "masri" (Egyptian-relevant): NightPrince/MasriSpeech-Test (apache-2.0, audiofolder); MohamedGomaa30/Masri-Elders (mit, ASR); MohamedGomaa30/MasriAudio-Mega (100K-1M); DavidSameh/Masri_* series (many, no licenses); T0KII/MASRISET (1M-10M text); Tarek737/MasriSwitch-Bench (cc-by-4.0, en+ar code-switching, 1K-10K, 2026-09-25); ehabnegm/masri-100h-egyptian-tts-enhanced (cc-by-nc-4.0, 2026-08-10). MLRS/masri_synthetic is Maltese, not Egyptian. A search result also listed NightPrince/MasriSpeech-ASR-Finetuning: per search snippet "5,500 ... over 100 hours" (unfetched).
- Search "arabizi": arbml/Arabizi_Transliteration (10K-100K, 2022-11-03, no license tag; raw README 404, content unseen); UBC-NLP/nilechat-arabizi-egy (arz, cc-by-nc-4.0, 100K-1M, 2025-11-11; raw README 401 so likely gated or private, content unseen); arbml/comparable_arabizi (10K-100K, 2024-03-23); akhanafer/arabic-to-arabizi (cc-by-4.0, n<1K, tagged levantine/lebanese, so not Egyptian); Darija sets (Moroccan, not Egyptian): ychen/english-darija-arabizi-translation, elkababi2/Darija-Text-Ar-Arabizi, ilias-brh/..., UBC-NLP/nilechat-arabizi-mor.
- rabeeeehh/arabizi-kit-corpus (card fetched): "LLM-annotated sentences of real social-media Arabizi"; 355 annotated, 323 usable (train 226/dev 48/test 49); MIT; Egyptian share not stated on page; 10% double-annotated sample reached 0.171 exact-match agreement. Tags: arz, ary, apc, afb.
- Search "EGY", "dialectal arabic", "franco arabic", "romanized arabic": NOT RUN as separate HF API queries (budget). 

## 10/11. Tools
- ArabiziKit (search summary, https://pypi.org/project/arabizikit/ not fetched): converts Arabizi to Arabic script and tags dialect.
- ISLRN 986-364-744-303-9 "Training and test data for Arabizi detection and transliteration": search summary says ~3,452 manually transliterated Arabizi tokens + 127 tweets; dialect unspecified; unfetched.
- camel_tools GitHub README (https://github.com/CAMeL-Lab/camel_tools, fetched, evidence repo-readme): Egyptian/EGY not mentioned; CALIMA not mentioned. Quotes: "CAMeL Tools is available under the MIT license."; "The Dialect Identification component is not available on Windows at this time." Data packages: camel_data -i all / light / defaults; "light" covers morphology and MLE disambiguation only. Releases section empty on page.
- CALIMA-EGY: WANLP 2022 paper https://aclanthology.org/2022.wanlp-1.14 appeared in search ("Developing a Tag-Set and Extracting the Morphological Lexicons to Build a Morphological Analyzer for Egyptian Arabic"); not fetched. No source found on pronunciation/phonology layer or calima-egy-r13. MADAMIRA Egyptian: NOT FOUND (not searched).

## NOT FOUND (so far)
- 7 Common Voice Arabic dialect share: NOT FOUND. Not searched yet.
- ArzEn/ArzEn-ST official download: NOT FOUND. Searched: "ArzEn-ST corpus download github Injy Hamed ArzEn Corpus Resources"; fetches of arxiv abs 2211.12000, aclanthology 2020.lrec-1.523, github.com/gtrg/ArzEn-ST (404).

## 7. Mozilla Common Voice Arabic
- Evidence: forum/search summaries (secondhand). Page https://datacollective.mozillafoundation.org/datasets/cmflnuzw47jng4x81tavetpul redirects to https://mozilladatacollective.com/datasets/cmflnuzw47jng4x81tavetpul, which rendered only "Loading dataset..." (JS page; no data read).
- Search summary (query "Mozilla Common Voice Arabic dataset dialect Egyptian accent share hours"): Scripted Speech 23.0 Arabic lists 158 hours recorded, 92 validated, 1654 speakers; read MSA sentences. Forum thread https://discourse.mozilla.org/t/arabic-dataset-and-variants/50602 discusses variants (not fetched). Published Egyptian share: NOT FOUND. Same summary says FLEURS Arabic is MSA read by Egyptian speakers (4.39 h) (unverified).

## 10 (continued). Corpora named in brief
- Habibi: https://www.lancaster.ac.uk/staff/elhaj/corpora.html (fetched, dataset-page). Quote: "Habibi the first Arabic Song Lyrics corpus." More than 30,000 lyrics, 6 dialects, 18 countries, >500,000 sentences, >3.5M words; CSV/TXT/JSON/XML; download http://ucrel-web.lancaster.ac.uk/habibi/ . License: not stated on page (paper says free for research purposes, via search summary). Egyptian share: not stated. Arabic script, no English.
- Same page lists "Arabic Dialects Dataset" covering Gulf, Egyptian, Levantine, Tunisian plus MSA; no size or license given.
- MPCA, AOC, PADIC (search summaries only, query "PADIC MPCA Egyptian Arabic parallel corpus AOC ..."; evidence paper-survey, unfetched): MPCA 2,000 parallel sentences, 5 dialects incl. Egyptian, "publicly available upon request"; AOC monolingual, newspaper comments incl. Egyptian (AlYoum AlSabe'), 63,555 sentences MSA, rest Egyptian/Gulf/Levantine; PADIC: sources list Algerian, Palestinian, Syrian, Tunisian, Moroccan plus MSA, no Egyptian. Zbib et al. Egyptian-English parallel ~380K words, availability unconfirmed.
- NADI shared tasks: NOT FOUND (not searched).
- LDC2017T07 BOLT Egyptian Arabic SMS/Chat and Transliteration: https://catalog.ldc.upenn.edu/LDC2017T07 (fetched, dataset-page). Quote: "consists of naturally-occurring Short Message Service (SMS) and Chat (CHT) data." 5,691 conversations, 1,029,248 words; 1,856 Arabizi conversations (287,022 words) transliterated to Arabic script following CODA. Released April 17, 2017. "Login for the applicable fee" (no price shown); LDC User Agreement for Non-Members. Egyptian (per title). Romanized+Arabic-script yes; English no. This is the only Egyptian Arabizi-to-Arabic-script gold source seen.
- ArzEn-MultiGenre paper PMC11220861: fetch blocked (cookie wall), content not read.

## 11. Pronunciation lexicons
- LDC99L22 (CALLHOME Egyptian Arabic Lexicon): named in a search summary only; page not fetched; pronunciation content unverified. Egyptian phonetic/pronunciation layer in CALIMA-EGY or camel_tools: NOT FOUND. Searched: "CALIMA-EGY Egyptian Arabic morphological analyzer phonology pronunciation camel_tools calima-egy-r13"; fetch of github.com/CAMeL-Lab/camel_tools. MADAMIRA Egyptian: NOT FOUND (not searched).

## 13. Legal Egyptian conversational test audio
- NOT FOUND: no Creative Commons / openly licensed Egyptian conversational podcast or channel established. Searched: "Egyptian Arabic podcast Creative Commons license audio transcripts openly licensed conversational". Hits (Salis Learn Egyptian Arabic directory page; Ehky Ya Masr; book "Egyptian Arabic Voices") carried no open license statement. Public radio and CC YouTube channels: not searched.
- Only rights-bearing path seen: HF card ehabnegm/masri-podcast-300h-egyptian-tts, "released for research use", cc-by-nc-4.0, scraped YouTube podcasts (rights of originals not stated).

## Updated NOT FOUND list
7 Egyptian share of Common Voice; 8 Lisaan Masry data/phonetics/license; 11 pronunciation layer, MADAMIRA Egyptian; 13 CC podcasts/radio/YouTube; ArzEn(-ST) official download URL; Tatoeba arz-English link count; MGB-3 license and obtain route; HF searches "EGY", "dialectal arabic", "franco arabic", "romanized arabic" not run; NADI not searched; English side of MADAR Cairo (withheld by license).
