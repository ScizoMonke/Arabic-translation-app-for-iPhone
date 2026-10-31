# LLM bench account (2026-10-31)

Overflow from the executor return. Tables live in runs/compare.md; raw rows in runs/<model>/results.jsonl; rendered first prompt per run in runs/<model>/meta.json.

## Decoding
Greedy (do_sample=False, temperature/top_p/top_k unset), max_new_tokens=200, bf16 weights, batch 1, transformers 5.5.0, torch 2.11.0+cu128, RTX 5070 Ti. Seconds are wall clock of model.generate incl. the first-call CUDA warmup (sentence 1 is about 17-21 s for every run; the mean includes it).

## Chat formatting
User turn is always: English: "<sentence>". System prompt goes in a system turn; the Gemma 3 template (Nile-Chat) folds a system turn into the first user turn itself (see meta.json first_prompt_rendered). Qwen3 rendered with enable_thinking=False (template inserts an empty think block).

## Prompt A (verbatim)
```
You translate what an English-speaking visitor says to his Egyptian family into Egyptian Arabic.
Use Egyptian Cairo colloquial Arabic (Masri) as spoken at home in Cairo. Never use Modern Standard Arabic (Fusha); never use Levantine or Gulf forms.

For the English sentence you are given, reply with ONLY one JSON object, no other text, with exactly these four string fields:
- "arabic": the Egyptian colloquial sentence in Arabic script.
- "arabizi": the same sentence in Arabizi (Franco-Arabic), the way Egyptians text: 2 for the glottal stop (hamza, and qaf as Cairenes say it), 3 for ayn, 7 for the emphatic h, 5 for kh, 9 for emphatic s where used, gh for ghayn. Latin letters and digits only.
- "latin": a respelling for an English reader who knows no Arabic: plain English letters only, no digits, syllables separated by hyphens, the stressed syllable in CAPITALS, words separated by spaces. Example of the style: "ez-ZAY-yak".
- "gloss": a literal word-by-word English rendering of the Egyptian sentence, so the speaker knows exactly what he is saying.

Example. English: "I love Egypt."
{"arabic": "أنا بحب مصر", "arabizi": "ana ba7ebb masr", "latin": "A-na ba-HIBB MASR", "gloss": "I I-love Egypt"}
```

## Prompt B (verbatim), designed after A misbehaved (Qwen3-4B copied the worked example on sentence 9; both models wrote Arabizi digits and/or plain ALL CAPS into latin)
```
Translate the English sentence into Egyptian Cairo colloquial Arabic (Masri, NOT Modern Standard Arabic).
Output exactly one JSON object and nothing else:
{"arabic": "<Egyptian Arabic in Arabic script>", "arabizi": "<same in Egyptian Franco-Arabic texting: 2=hamza, 3=ayn, 7=emphatic h, 5=kh>", "latin": "<same respelled for an English reader: English letters only, hyphenated syllables, stressed syllable in CAPITALS, e.g. ez-ZAY-yak>", "gloss": "<literal word-by-word English of the Egyptian>"}
```

## Parser
parse_output: strips a leading <think> block and a ```json fence if present, takes the outermost {...} span, json.loads, requires the four fields as non-empty strings. Self-test (`python -I llm_bench.py --selftest`): good -> parsed; truncated object (missing closing brace) -> "no JSON object found"; missing fields -> rejected; prose -> rejected.

## MLX Swift architecture support
mlx-swift-examples no longer holds Libraries/MLXLLM (raw.githubusercontent .../mlx-swift-examples/main/Libraries/MLXLLM/LLMModelFactory.swift and README.md both 404); the LLM code moved to ml-explore/mlx-swift-lm. Registry read from mlx-swift-lm main at commit 128f49f1db38ea7b949f2ebb60967def8b76f58e, file Libraries/MLXLLM/LLMModelFactory.swift; saved copy at C:\VScode\Arabic to English to Arabic IOS\data\mlx-swift-lm\LLMModelFactory@128f49f1.swift.
- line 60: "gemma3": create(Gemma3TextConfiguration.self, Gemma3TextModel.init),
- line 61: "gemma3_text": create(Gemma3TextConfiguration.self, Gemma3TextModel.init),   <- Nile-Chat-4B config model_type gemma3_text
- line 66: "qwen2": create(Qwen2Configuration.self, Qwen2Model.init),   <- NileChat-3B (Qwen2ForCausalLM per HF config; not run)
- line 67: "qwen3": createQwen3CompatibleModel,   <- Qwen3-4B
Registry presence means the architecture code exists; it does not prove a given checkpoint converts or runs in iPhone memory.

## Model ids (HfApi.model_info, 2026-10-31)
- MBZUAI-Paris/Nile-Chat-4B: not gated, license gemma, 7.8 GB, Gemma3ForCausalLM. Revision 2a365667.
- Qwen/Qwen3-4B: not gated, apache-2.0, 8.1 GB, Qwen3ForCausalLM. Revision 1cfa9a72.
- UBC-NLP/NileChat-3B: gated=auto, license other (qwen-research per ledger), 6.8 GB, Qwen2ForCausalLM. Download: GatedRepoError 401, no HF token on this machine. Not run. To add once a token with accepted terms exists: python -I bench/llm/llm_bench.py UBC-NLP/NileChat-3B

## Header table (from runs/compare.md)
| run | parse fail | Arabic chars in arabizi+latin | rows with digits in latin | mean out tok | s/sentence |
|---|---|---|---|---|---|
| Nile-Chat-4B, A | 1/40 (#4) | 0 | 17 | 47.2 | 5.30 |
| Nile-Chat-4B, B | 0/40 | 262 | 15 | 42.3 | 5.08 |
| Qwen3-4B, A | 0/40 | 0 | 11 | 50.8 | 4.29 |
| Qwen3-4B, B | 0/40 | 11 | 13 | 55.0 | 4.78 |
Throughput is about 10 tok/s in HF transformers eager bf16, which is slow for this GPU; not tuned (not crucial per brief).

## Flags by sentence (executor notes, not grading)
Nile-Chat-4B prompt A:
- #4 "How are you?": latin degenerates into "EZZIIII..." to the 200-token cap, the only parse failure.
- #34 "Turn left." -> "lef yemeen" (yemeen = right); gloss also says "Turn right." Dangerous for directions.
- #36 "Stop here, please." -> "matmashish hena" (do not walk here).
- #38 "I have a headache." arabizi "3ando" vs arabic "عندي": the Arabizi says "he has".
- #20 arabizi "da omi" for "ده عمي" (ayn dropped; reads as "my mother" to a texter).
- #1 gives "el salam 3aleikom" for "Hello" (fine socially, register is a choice).
- latin field: often just the Arabizi in caps with digits (17/40 rows contain digits), hyphenated syllables appear in a minority of rows; gloss is usually a free English translation, sometimes the Arabizi again (#10, #17, #36, #39), not literal.
Nile-Chat-4B prompt B: arabizi field frequently Arabic script (262 chars); #2/#3 "masaa el kheir" (good evening) for good morning; #24 "nawarto ya gama3a" (you lit up the place) for "I missed you all"; #34 and #35 both "lef yemeen"; gloss often Arabic script or Arabizi.
Qwen3-4B prompt A: mostly MSA or Levantine forms (#1 marhaba, #4 kif ant, #8, #10 hatha, #25 na3am, #27 qad), many nonsense strings (#6, #7, #15, #16, #18, #34 "akhtib" = write). #9 "You're welcome" copied the worked example from prompt A ("ana batheb masri", gloss "I I-love Egyptians").
Qwen3-4B prompt B: same picture, plus #25 "Yes" -> "bla"/gloss "no", #20 latin "H3S ZAY-YAK" (copied the style example), #7 basmala plus salam formula for "Goodbye, see you tomorrow".

## Gated / licenses
- UBC-NLP/NileChat-3B: gated (auto-approve after login); no HF token here -> not run. License qwen-research (ledger) / "other" (HF API).
- Nile-Chat-4B: Gemma terms. Qwen3-4B: Apache-2.0.
