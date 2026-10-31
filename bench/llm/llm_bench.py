"""LLM bench: English -> Egyptian Arabic (Arabic script, Arabizi, English-reader respelling, literal gloss).

Usage (one model per call; compare.md is rebuilt from every runs/*/results.jsonl afterwards):
    python -I bench/llm/llm_bench.py MBZUAI-Paris/Nile-Chat-4B
    python -I bench/llm/llm_bench.py Qwen/Qwen3-4B --variant B
    python -I bench/llm/llm_bench.py --compare-only

Same 40 sentences, same prompt, greedy decoding, max 200 new tokens, bf16 on CUDA for every model.
Model repos are untrusted data: trust_remote_code stays False and the script runs with -I.
"""
from __future__ import annotations

import json
import re
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
RUNS = HERE / "runs"
# Saved copy of ml-explore/mlx-swift-lm Libraries/MLXLLM/LLMModelFactory.swift at commit 128f49f1 (fetched 2026-10-31).
MLX_REGISTRY = Path(r"C:\VScode\Arabic to English to Arabic IOS\data\mlx-swift-lm\LLMModelFactory@128f49f1.swift")
MAX_NEW_TOKENS = 200

SENTENCES: list[str] = [
    # greetings and replies
    "Hello.",
    "Good morning.",
    "Good morning to you too.",
    "How are you?",
    "I'm fine, thank God.",
    "Nice to meet you.",
    "Goodbye, see you tomorrow.",
    # thanks
    "Thank you very much.",
    "You're welcome.",
    # food
    "This is delicious.",
    "I'm full.",
    "A little more, please.",
    "No sugar, please.",
    # asking for things
    "Can I have some water?",
    "Where is the bathroom?",
    "Please say it slower.",
    "Can you say it again?",
    "I don't understand.",
    "What does that mean?",
    # family
    "This is my uncle.",
    "Where is my aunt?",
    "How is Grandma doing?",
    "How is everyone?",
    "I missed you all.",
    # short answers
    "Yes.",
    "No.",
    "Maybe.",
    "Later.",
    "Tomorrow.",
    "Let's go.",
    # money
    "How much is this?",
    "That's too expensive.",
    # getting around
    "Where is the hotel?",
    "Turn left.",
    "Turn right.",
    "Stop here, please.",
    # health
    "I'm tired.",
    "I have a headache.",
    "I need to rest a little.",
    "I'm happy to be here with you.",
]
assert len(SENTENCES) == 40, len(SENTENCES)

PROMPT_A = """You translate what an English-speaking visitor says to his Egyptian family into Egyptian Arabic.
Use Egyptian Cairo colloquial Arabic (Masri) as spoken at home in Cairo. Never use Modern Standard Arabic (Fusha); never use Levantine or Gulf forms.

For the English sentence you are given, reply with ONLY one JSON object, no other text, with exactly these four string fields:
- "arabic": the Egyptian colloquial sentence in Arabic script.
- "arabizi": the same sentence in Arabizi (Franco-Arabic), the way Egyptians text: 2 for the glottal stop (hamza, and qaf as Cairenes say it), 3 for ayn, 7 for the emphatic h, 5 for kh, 9 for emphatic s where used, gh for ghayn. Latin letters and digits only.
- "latin": a respelling for an English reader who knows no Arabic: plain English letters only, no digits, syllables separated by hyphens, the stressed syllable in CAPITALS, words separated by spaces. Example of the style: "ez-ZAY-yak".
- "gloss": a literal word-by-word English rendering of the Egyptian sentence, so the speaker knows exactly what he is saying.

Example. English: "I love Egypt."
{"arabic": "أنا بحب مصر", "arabizi": "ana ba7ebb masr", "latin": "A-na ba-HIBB MASR", "gloss": "I I-love Egypt"}"""

# Variant B: kept terser and without a worked example, in case variant A's example is copied verbatim
# or the model echoes prose. Used only if variant A misbehaves; recorded in DECISIONS either way.
PROMPT_B = """Translate the English sentence into Egyptian Cairo colloquial Arabic (Masri, NOT Modern Standard Arabic).
Output exactly one JSON object and nothing else:
{"arabic": "<Egyptian Arabic in Arabic script>", "arabizi": "<same in Egyptian Franco-Arabic texting: 2=hamza, 3=ayn, 7=emphatic h, 5=kh>", "latin": "<same respelled for an English reader: English letters only, hyphenated syllables, stressed syllable in CAPITALS, e.g. ez-ZAY-yak>", "gloss": "<literal word-by-word English of the Egyptian>"}"""

PROMPTS = {"A": PROMPT_A, "B": PROMPT_B}
FIELDS = ("arabic", "arabizi", "latin", "gloss")
ARABIC_RE = re.compile(r"[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]")


def parse_output(text: str) -> tuple[dict | None, str | None]:
    """Return (fields, None) or (None, reason). Tolerates a ```json fence and surrounding prose; nothing else."""
    s = text.strip()
    s = re.sub(r"^<think>.*?</think>", "", s, flags=re.S).strip()
    fence = re.search(r"```(?:json)?\s*(.*?)```", s, flags=re.S)
    if fence:
        s = fence.group(1).strip()
    start, end = s.find("{"), s.rfind("}")
    if start == -1 or end <= start:
        return None, "no JSON object found"
    try:
        obj = json.loads(s[start : end + 1])
    except json.JSONDecodeError as e:
        return None, f"JSONDecodeError: {e}"
    if not isinstance(obj, dict):
        return None, "JSON is not an object"
    missing = [f for f in FIELDS if not isinstance(obj.get(f), str) or not obj.get(f).strip()]
    if missing:
        return None, f"missing or empty fields: {missing}"
    return {f: obj[f].strip() for f in FIELDS}, None


def build_messages(tokenizer, system: str, sentence: str) -> list[dict]:
    user = f'English: "{sentence}"'
    # Some chat templates (older Gemma) reject a system role; fold it into the user turn there.
    try:
        tokenizer.apply_chat_template([{"role": "system", "content": "x"}, {"role": "user", "content": "y"}], tokenize=False)
        return [{"role": "system", "content": system}, {"role": "user", "content": user}]
    except Exception as e:  # template raised on system role: record why and fold
        print(f"[note] system role rejected by template ({type(e).__name__}); folding into user turn", flush=True)
        return [{"role": "user", "content": system + "\n\n" + user}]


def run_model(model_id: str, variant: str, limit: int | None) -> Path:
    import torch
    from transformers import AutoModelForCausalLM, AutoTokenizer

    short = model_id.split("/")[-1] + ("" if variant == "A" else f"-prompt{variant}")
    out_dir = RUNS / short
    out_dir.mkdir(parents=True, exist_ok=True)
    tok = AutoTokenizer.from_pretrained(model_id, trust_remote_code=False)
    model = AutoModelForCausalLM.from_pretrained(model_id, dtype=torch.bfloat16, trust_remote_code=False).to("cuda").eval()
    n_params = sum(p.numel() for p in model.parameters())
    model_type = model.config.model_type
    system = PROMPTS[variant]
    msgs_probe = build_messages(tok, system, "probe")
    template_kwargs = {"enable_thinking": False} if "qwen3" in model_type.lower() else {}

    sentences = SENTENCES[:limit] if limit else SENTENCES
    rows = []
    for i, sent in enumerate(sentences, 1):
        msgs = build_messages(tok, system, sent) if len(msgs_probe) == 2 else [{"role": "user", "content": system + "\n\n" + f'English: "{sent}"'}]
        prompt = tok.apply_chat_template(msgs, tokenize=False, add_generation_prompt=True, **template_kwargs)
        enc = tok(prompt, return_tensors="pt", add_special_tokens=False).to("cuda")
        torch.cuda.synchronize()
        t0 = time.perf_counter()
        with torch.no_grad():
            gen = model.generate(**enc, do_sample=False, max_new_tokens=MAX_NEW_TOKENS,
                                 temperature=None, top_p=None, top_k=None, pad_token_id=tok.pad_token_id or tok.eos_token_id)
        torch.cuda.synchronize()
        secs = time.perf_counter() - t0
        new = gen[0, enc["input_ids"].shape[1]:]
        raw = tok.decode(new, skip_special_tokens=True)
        fields, err = parse_output(raw)
        row = {"n": i, "sentence": sent, "raw": raw, "parsed": fields, "parse_error": err,
               "seconds": round(secs, 3), "output_tokens": int(new.shape[0])}
        rows.append(row)
        print(f"[{i:02d}] {secs:5.2f}s {new.shape[0]:3d}tok {'OK ' if fields else 'ERR'} {sent} -> {raw[:160]!r}", flush=True)

    with open(out_dir / "results.jsonl", "w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    meta = {"model_id": model_id, "model_type": model_type, "params": n_params, "variant": variant,
            "system_prompt": system, "first_prompt_rendered": tok.apply_chat_template(
                build_messages(tok, system, sentences[0]) if len(msgs_probe) == 2 else [{"role": "user", "content": system + "\n\n" + f'English: "{sentences[0]}"'}],
                tokenize=False, add_generation_prompt=True, **template_kwargs),
            "decoding": f"greedy (do_sample=False), max_new_tokens={MAX_NEW_TOKENS}, bf16, batch 1, torch {torch.__version__}",
            "gpu": torch.cuda.get_device_name(0), "n_sentences": len(rows)}
    (out_dir / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    return out_dir


def mlx_support(model_type: str) -> str:
    if not MLX_REGISTRY.exists():
        return "unknown (registry copy missing)"
    for ln, line in enumerate(MLX_REGISTRY.read_text(encoding="utf-8").splitlines(), 1):
        if line.strip().startswith(f'"{model_type}":'):
            return f'yes: mlx-swift-lm@128f49f1 Libraries/MLXLLM/LLMModelFactory.swift:{ln} `{line.strip()}`'
    return f"no: model_type \"{model_type}\" absent from mlx-swift-lm@128f49f1 LLMModelFactory.swift registry"


def cell(s: str | None) -> str:
    return (s or "").replace("|", "\\|").replace("\n", " ").strip()


def write_compare() -> Path:
    runs = []
    for d in sorted(p for p in RUNS.iterdir() if (p / "results.jsonl").exists()):
        rows = [json.loads(l) for l in (d / "results.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()]
        meta = json.loads((d / "meta.json").read_text(encoding="utf-8"))
        runs.append((d.name, meta, rows))
    lines = ["# LLM bench: English -> Egyptian Arabic (4 fields)", "",
             "Every cell is real model output from runs/<model>/results.jsonl. Decoding: greedy, max 200 new tokens, bf16, batch 1, RTX 5070 Ti.",
             "Leak = count of Arabic-script characters inside the arabizi + latin fields (parsed rows only). Digits-in-latin = parsed rows whose latin field contains any digit (Arabizi leaking into the English-reader respelling).", "",
             "| model | prompt | params | parse failures | Arabic chars leaked (arabizi+latin) | rows with digits in latin | mean output tokens | s/sentence | MLX Swift arch support |",
             "|---|---|---|---|---|---|---|---|---|"]
    for name, meta, rows in runs:
        fails = sum(1 for r in rows if not r["parsed"])
        leak = sum(len(ARABIC_RE.findall(r["parsed"]["arabizi"] + r["parsed"]["latin"])) for r in rows if r["parsed"])
        # Extra column, not in the brief: the latin field is for an English reader, so Arabizi digits there are a miss the Arabic-script count cannot see.
        digit_rows = sum(1 for r in rows if r["parsed"] and re.search(r"\d", r["parsed"]["latin"]))
        mtok = sum(r["output_tokens"] for r in rows) / len(rows)
        spd = sum(r["seconds"] for r in rows) / len(rows)
        lines.append(f"| {name} | {meta['variant']} | {meta['params']/1e9:.2f}B | {fails}/{len(rows)} | {leak} | {digit_rows} | {mtok:.1f} | {spd:.2f} | "
                     f"{cell(mlx_support(meta['model_type']))} (model_type {meta['model_type']}) |")
    lines.append("")
    n_max = max((len(r) for _, _, r in runs), default=0)
    for i in range(n_max):
        sent = next(rows[i]["sentence"] for _, _, rows in runs if len(rows) > i)
        lines += [f"## {i+1}. {sent}", "", "| model | arabic | arabizi | latin | gloss |", "|---|---|---|---|---|"]
        for name, _, rows in runs:
            if len(rows) <= i:
                continue
            r = rows[i]
            if r["parsed"]:
                p = r["parsed"]
                lines.append(f"| {name} | {cell(p['arabic'])} | {cell(p['arabizi'])} | {cell(p['latin'])} | {cell(p['gloss'])} |")
            else:
                lines.append(f"| {name} | PARSE FAIL ({cell(r['parse_error'])[:80]}); raw: {cell(r['raw'])[:200]} | | | |")
        lines.append("")
    out = RUNS / "compare.md"
    out.write_text("\n".join(lines), encoding="utf-8")
    return out


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")  # Windows console defaults to cp1252 and dies on Arabic
    args = sys.argv[1:]
    if args and args[0] == "--selftest":
        good = '{"arabic": "x", "arabizi": "y", "latin": "z", "gloss": "w"}'
        broken = '{"arabic": "x", "arabizi": "y", "latin": "z", "gloss": "w"'
        missing = '{"arabic": "x", "arabizi": "y"}'
        for name, s in [("good", good), ("broken", broken), ("missing", missing), ("prose", "Sure! Here it is.")]:
            print(name, parse_output(s))
        sys.exit(0)
    if args and args[0] == "--compare-only":
        print(write_compare())
        sys.exit(0)
    model_id = args[0]
    variant = args[args.index("--variant") + 1] if "--variant" in args else "A"
    limit = int(args[args.index("--limit") + 1]) if "--limit" in args else None
    d = run_model(model_id, variant, limit)
    if limit is None:
        print(write_compare())
