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

# Variant C: the app computes the respelling and drops the gloss, so the model is asked only for what it is good at.
# Two worked examples chosen to resemble none of the 40 test sentences (A's single example was copied verbatim by Qwen on #9).
PROMPT_C = """You translate what an English-speaking visitor says to his Egyptian family into Egyptian Arabic.
Use Egyptian Cairo colloquial Arabic (Masri) as spoken at home in Cairo. Never use Modern Standard Arabic (Fusha); never use Levantine or Gulf forms.

For the English sentence you are given, reply with ONLY one JSON object, no other text, with exactly these two string fields:
- "arabic": the Egyptian colloquial sentence in Arabic script.
- "arabizi": the same Egyptian sentence in Arabizi (Franco-Arabic), the way Egyptians text: 2 for the glottal stop (hamza, and qaf as Cairenes say it), 3 for ayn, 7 for the emphatic h, 5 for kh, 9 for emphatic s where used, gh for ghayn. Latin letters and digits only, never Arabic script.

Examples.
English: "The car is outside."
{"arabic": "العربية برة", "arabizi": "el 3arabeyya barra"}
English: "My phone is dead."
{"arabic": "موبايلي فاصل شحن", "arabizi": "mobayli fasel sha7n"}"""

PROMPTS = {"A": PROMPT_A, "B": PROMPT_B, "C": PROMPT_C}
FIELDS = ("arabic", "arabizi", "latin", "gloss")
FIELDS_BY_VARIANT = {"A": FIELDS, "B": FIELDS, "C": ("arabic", "arabizi")}
OLLAMA = "http://localhost:11434"
REPEAT_PENALTY_DEFAULT = 1.15  # used whenever --rp is given without a value; Ollama runs always pass it
ARABIC_RE = re.compile(r"[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]")


def parse_output(text: str, fields: tuple[str, ...] = FIELDS) -> tuple[dict | None, str | None]:
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
    missing = [f for f in fields if not isinstance(obj.get(f), str) or not obj.get(f).strip()]
    if missing:
        return None, f"missing or empty fields: {missing}"
    return {f: obj[f].strip() for f in fields}, None


def build_messages(tokenizer, system: str, sentence: str) -> list[dict]:
    user = f'English: "{sentence}"'
    # Some chat templates (older Gemma) reject a system role; fold it into the user turn there.
    try:
        tokenizer.apply_chat_template([{"role": "system", "content": "x"}, {"role": "user", "content": "y"}], tokenize=False)
        return [{"role": "system", "content": system}, {"role": "user", "content": user}]
    except Exception as e:  # template raised on system role: record why and fold
        print(f"[note] system role rejected by template ({type(e).__name__}); folding into user turn", flush=True)
        return [{"role": "user", "content": system + "\n\n" + user}]


def save_run(out_dir: Path, rows: list[dict], meta: dict) -> None:
    with open(out_dir / "results.jsonl", "w", encoding="utf-8") as f:
        for r in rows:
            line = json.dumps(r, ensure_ascii=False)
            # A model that emits JSON escapes for lone surrogates (seen on Q4_K_M + prompt C) yields text UTF-8 cannot
            # encode; such rows are stored ASCII-escaped instead, which round-trips through json.loads unchanged.
            try:
                line.encode("utf-8")
            except UnicodeEncodeError:
                line = json.dumps(r, ensure_ascii=True)
            f.write(line + "\n")
    (out_dir / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")


def run_ollama(tag: str, variant: str, limit: int | None, bf16_twin: str | None, repeat_penalty: float = REPEAT_PENALTY_DEFAULT) -> Path:
    """Same sentences and prompt through a local Ollama model (llama.cpp). The system prompt is folded into the
    user turn exactly as the Gemma 3 HF template does, so bf16 and GGUF see the same text."""
    import urllib.request

    def post(path: str, body: dict) -> dict:
        req = urllib.request.Request(OLLAMA + path, data=json.dumps(body).encode("utf-8"), headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=600) as resp:
            return json.loads(resp.read().decode("utf-8"))

    short = tag.split("/")[-1].replace(":", "-") + f"-prompt{variant}-ollama" + ("" if repeat_penalty == REPEAT_PENALTY_DEFAULT else f"-rp{repeat_penalty}")
    out_dir = RUNS / short
    out_dir.mkdir(parents=True, exist_ok=True)
    show = post("/api/show", {"model": tag})
    info = show.get("model_info", {})
    options = {"temperature": 0, "top_k": 1, "seed": 0, "num_predict": MAX_NEW_TOKENS,
               "repeat_penalty": repeat_penalty, "num_ctx": 2048}
    system = PROMPTS[variant]
    fields_req = FIELDS_BY_VARIANT[variant]
    sentences = SENTENCES[:limit] if limit else SENTENCES
    rows = []
    for i, sent in enumerate(sentences, 1):
        user = system + "\n\n" + f'English: "{sent}"'
        t0 = time.perf_counter()
        res = post("/api/chat", {"model": tag, "messages": [{"role": "user", "content": user}], "stream": False, "options": options})
        secs = time.perf_counter() - t0
        raw = res["message"]["content"]
        fields, err = parse_output(raw, fields_req)
        row = {"n": i, "sentence": sent, "raw": raw, "parsed": fields, "parse_error": err,
               "seconds": round(secs, 3), "output_tokens": int(res.get("eval_count", 0)),
               "ollama_eval_seconds": round(res.get("eval_duration", 0) / 1e9, 3)}
        rows.append(row)
        print(f"[{i:02d}] {secs:5.2f}s {row['output_tokens']:3d}tok {'OK ' if fields else 'ERR'} {sent} -> {raw[:160]!r}", flush=True)
    meta = {"model_id": tag, "backend": "ollama", "model_type": info.get("general.architecture", "unknown"),
            "params": info.get("general.parameter_count", 0), "variant": variant, "system_prompt": system,
            "ollama_template": show.get("template"), "ollama_details": show.get("details"), "options": options,
            "decoding": f"ollama /api/chat, options {options}", "bf16_twin": bf16_twin, "n_sentences": len(rows)}
    save_run(out_dir, rows, meta)
    return out_dir


def run_model(model_id: str, variant: str, limit: int | None, rep_penalty: float | None = None) -> Path:
    import torch
    from transformers import AutoModelForCausalLM, AutoTokenizer

    short = model_id.split("/")[-1] + ("" if variant == "A" else f"-prompt{variant}") + (f"-rp{rep_penalty}" if rep_penalty else "")
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
            gen = model.generate(**enc, do_sample=False, max_new_tokens=MAX_NEW_TOKENS, repetition_penalty=rep_penalty,
                                 temperature=None, top_p=None, top_k=None, pad_token_id=tok.pad_token_id or tok.eos_token_id)
        torch.cuda.synchronize()
        secs = time.perf_counter() - t0
        new = gen[0, enc["input_ids"].shape[1]:]
        raw = tok.decode(new, skip_special_tokens=True)
        fields, err = parse_output(raw, FIELDS_BY_VARIANT[variant])
        row = {"n": i, "sentence": sent, "raw": raw, "parsed": fields, "parse_error": err,
               "seconds": round(secs, 3), "output_tokens": int(new.shape[0])}
        rows.append(row)
        print(f"[{i:02d}] {secs:5.2f}s {new.shape[0]:3d}tok {'OK ' if fields else 'ERR'} {sent} -> {raw[:160]!r}", flush=True)

    meta = {"model_id": model_id, "backend": "transformers", "model_type": model_type, "params": n_params, "variant": variant,
            "repetition_penalty": rep_penalty,
            "system_prompt": system, "first_prompt_rendered": tok.apply_chat_template(
                build_messages(tok, system, sentences[0]) if len(msgs_probe) == 2 else [{"role": "user", "content": system + "\n\n" + f'English: "{sentences[0]}"'}],
                tokenize=False, add_generation_prompt=True, **template_kwargs),
            "decoding": f"greedy (do_sample=False), max_new_tokens={MAX_NEW_TOKENS}, repetition_penalty={rep_penalty}, bf16, batch 1, torch {torch.__version__}",
            "gpu": torch.cuda.get_device_name(0), "n_sentences": len(rows)}
    save_run(out_dir, rows, meta)
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
    by_name = {name: rows for name, _, rows in runs}
    lines = ["# LLM bench: English -> Egyptian Arabic", "",
             "Every cell is real model output from runs/<run>/results.jsonl. Transformers runs: bf16, greedy, max 200 new tokens, batch 1, RTX 5070 Ti; "
             "'-rp1.15' runs add repetition_penalty 1.15. '-ollama' runs: Q4_K_M GGUF via Ollama (llama.cpp), temperature 0, top_k 1, num_predict 200, "
             "repeat_penalty 1.15, num_ctx 2048, same GPU. Prompt C asks for arabic and arabizi only (latin/gloss shown as '-').",
             "Leak = count of Arabic-script characters inside the arabizi + latin fields (parsed rows only). Digits-in-latin = parsed rows whose latin field contains any digit. "
             "Arabic differs = rows (of 40) where the Q4_K_M arabic string is not identical (after strip) to its bf16 twin run with the same prompt and repetition penalty; a parse failure on either side counts as differing.", "",
             "| run | prompt | params | parse failures | Arabic chars leaked (arabizi+latin) | rows with digits in latin | mean output tokens | s/sentence | rows where arabic differs between bf16 and Q4_K_M | MLX Swift arch support |",
             "|---|---|---|---|---|---|---|---|---|---|"]
    for name, meta, rows in runs:
        ok = [r for r in rows if r["parsed"]]
        fails = len(rows) - len(ok)
        leak = sum(len(ARABIC_RE.findall(r["parsed"]["arabizi"] + r["parsed"].get("latin", ""))) for r in ok)
        # Extra column, not in the first brief: the latin field is for an English reader, so Arabizi digits there are a miss the Arabic-script count cannot see.
        digit_rows = "-" if meta["variant"] == "C" else sum(1 for r in ok if re.search(r"\d", r["parsed"]["latin"]))
        mtok = sum(r["output_tokens"] for r in rows) / len(rows)
        spd = sum(r["seconds"] for r in rows) / len(rows)
        twin = meta.get("bf16_twin")
        if twin and twin in by_name:
            tw = by_name[twin]
            diff = sum(1 for a, b in zip(rows, tw) if not (a["parsed"] and b["parsed"] and a["parsed"]["arabic"].strip() == b["parsed"]["arabic"].strip()))
            diff_cell = f"{diff}/{len(rows)} vs {twin}"
        else:
            diff_cell = "-"
        params = meta["params"] / 1e9 if meta["params"] else 0
        lines.append(f"| {name} | {meta['variant']} | {params:.2f}B | {fails}/{len(rows)} | {leak} | {digit_rows} | {mtok:.1f} | {spd:.2f} | {diff_cell} | "
                     f"{cell(mlx_support(meta['model_type']))} (model_type {meta['model_type']}) |")
    lines.append("")
    n_max = max((len(r) for _, _, r in runs), default=0)
    for i in range(n_max):
        sent = next(rows[i]["sentence"] for _, _, rows in runs if len(rows) > i)
        lines += [f"## {i+1}. {sent}", "", "| run | arabic | arabizi | latin | gloss |", "|---|---|---|---|---|"]
        for name, _, rows in runs:
            if len(rows) <= i:
                continue
            r = rows[i]
            if r["parsed"]:
                p = r["parsed"]
                lines.append(f"| {name} | {cell(p['arabic'])} | {cell(p['arabizi'])} | {cell(p.get('latin')) or '-'} | {cell(p.get('gloss')) or '-'} |")
            else:
                lines.append(f"| {name} | PARSE FAIL ({cell(r['parse_error'])[:80]}); raw: {cell(r['raw'])[:200]} | | | |")
        lines.append("")
    # Respelling prototype over every prompt-C arabizi field; computed here, not by a model.
    sys.path.insert(0, str(HERE))  # -I drops the script dir from sys.path; respell.py is our own code beside this file
    try:
        from respell import respell
    except ImportError:
        respell = None
    c_runs = [(name, rows) for name, meta, rows in runs if meta["variant"] == "C"]
    if respell and c_runs:
        lines += ["# Respelling prototype (respell.py) over prompt C arabizi", "",
                  "Deterministic rule from bench/llm/respell.py applied to the model's arabizi field; the respelling column is code output, not model output.", ""]
        for name, rows in c_runs:
            lines += [f"## {name}", "", "| # | english | arabizi | respelling |", "|---|---|---|---|"]
            for r in rows:
                if r["parsed"]:
                    lines.append(f"| {r['n']} | {cell(r['sentence'])} | {cell(r['parsed']['arabizi'])} | {cell(respell(r['parsed']['arabizi']))} |")
                else:
                    lines.append(f"| {r['n']} | {cell(r['sentence'])} | PARSE FAIL | - |")
            lines.append("")
    out = RUNS / "compare.md"
    out.write_text("\n".join(lines), encoding="utf-8", errors="backslashreplace")  # lone surrogates from model output
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
        print("missing, variant C fields", parse_output(missing, FIELDS_BY_VARIANT["C"]))
        sys.exit(0)
    if args and args[0] == "--compare-only":
        print(write_compare())
        sys.exit(0)
    # python -I llm_bench.py <hf id | ollama tag> [--variant A|B|C] [--rp] [--ollama] [--twin <bf16 run dir>] [--limit N]
    model_id = args[0]
    variant = args[args.index("--variant") + 1] if "--variant" in args else "A"
    limit = int(args[args.index("--limit") + 1]) if "--limit" in args else None
    if "--ollama" in args:
        twin = args[args.index("--twin") + 1] if "--twin" in args else None
        rp = float(args[args.index("--repeat-penalty") + 1]) if "--repeat-penalty" in args else REPEAT_PENALTY_DEFAULT
        d = run_ollama(model_id, variant, limit, twin, rp)
    else:
        d = run_model(model_id, variant, limit, REPEAT_PENALTY_DEFAULT if "--rp" in args else None)
    if limit is None:
        print(write_compare())
