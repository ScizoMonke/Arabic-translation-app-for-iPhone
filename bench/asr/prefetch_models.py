# Prefetches inference files only (no optimizer states, no intermediate checkpoints) into the HF cache.
from huggingface_hub import snapshot_download
SKIP = ["global_step*", "checkpoint-*", "*optim*", "runs/*", "samples/*", "*.png", "rng_state*", "zero_to_fp32.py", "training_args.bin"]
for rid in ["oddadmix/whisper-large-v3-arabic-dialectal-v2", "Dr-AliGomaa/whisper-large-v3-ar-eg",
            "tawreck-hasaballah/whisper-small-eg", "MightyStudent/whisper-large-v3-arabic"]:
    print(rid, snapshot_download(rid, ignore_patterns=SKIP), flush=True)
