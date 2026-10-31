from huggingface_hub import HfApi
api = HfApi()
for mid in ["MBZUAI-Paris/Nile-Chat-4B", "UBC-NLP/NileChat-3B", "Qwen/Qwen3-4B"]:
    try:
        info = api.model_info(mid, files_metadata=True)
        size = sum((s.size or 0) for s in info.siblings) / 1e9
        print(mid, "gated=", info.gated, "license=", (info.card_data or {}).get("license"), f"{size:.1f}GB",
              "arch=", (info.config or {}).get("architectures"))
    except Exception as e:
        print(mid, "ERROR", type(e).__name__, e)
