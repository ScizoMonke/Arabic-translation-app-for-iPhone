# Downloads model weights into the default HF cache. Weights are data; nothing here executes repo code.
import sys
from huggingface_hub import snapshot_download, get_token
print("token present:", get_token() is not None, flush=True)
for mid in sys.argv[1:]:
    try:
        p = snapshot_download(mid, allow_patterns=["*.json", "*.safetensors", "*.model", "*.txt", "*.jinja", "tokenizer*"])
        print("OK", mid, p, flush=True)
    except Exception as e:
        print("FAIL", mid, type(e).__name__, str(e)[:300], flush=True)
