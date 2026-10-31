# LLM bench plan (2026-10-31)
1. One driver, bench/llm/llm_bench.py MODEL_ID: 40 fixed English sentences, one JSON system prompt (arabic, arabizi, latin, gloss), greedy, max 200 new tokens, bf16 on the 5070 Ti.
2. Candidates: MBZUAI-Paris/Nile-Chat-4B, UBC-NLP/NileChat-3B, Qwen/Qwen3-4B (thinking off); confirm ids/gating on HF first, weights cache under data/hf.
3. Instrument check: one sentence through one model with raw text shown, parser rejects a broken string.
4. Outputs: runs/<model>/results.jsonl per model; runs/compare.md header table (parse fails, Arabic-script leak, tokens, s/sentence, MLX Swift arch support quoted from mlx-swift-lm registry) + per-sentence tables.
5. Commit after each model; account.md holds overflow; no grading of Arabic beyond parse/leak, striking outputs flagged.
