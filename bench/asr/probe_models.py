# Lists repo files for the Egyptian fine-tunes in asr.md section 4 (metadata only).
from huggingface_hub import HfApi
api = HfApi()
for rid in ["MAdel121/whisper-medium-egy", "AbdelrahmanHassan/whisper-large-v3-egyptian-arabic",
            "tawreck-hasaballah/whisper-small-eg", "MightyStudent/whisper-large-v3-arabic",
            "oddadmix/whisper-large-v3-arabic-dialectal-v2", "Dr-AliGomaa/whisper-large-v3-ar-eg"]:
    try:
        info = api.model_info(rid, files_metadata=True)
        print("==", rid, "gated:", info.gated, "|", ", ".join(f"{s.rfilename}:{(s.size or 0)//1_000_000}MB" for s in info.siblings))
    except Exception as e:
        print("==", rid, "ERROR", type(e).__name__, str(e)[:120])
