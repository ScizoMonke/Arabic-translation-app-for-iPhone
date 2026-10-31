# Lists repo files for candidate datasets (metadata only, nothing downloaded).
from huggingface_hub import HfApi
api = HfApi()
for rid in ["MightyStudent/Egyptian-ASR-MGB-3", "ahmedsamirtarjama/MBZUAI_ArzEn_wav", "NightPrince/MasriSpeech-Test"]:
    try:
        info = api.dataset_info(rid, files_metadata=True)
        print("==", rid, "license:", (info.card_data or {}).get("license") if info.card_data else None, "gated:", info.gated)
        for s in info.siblings[:40]:
            print("   ", s.rfilename, s.size)
        print("   total files", len(info.siblings))
    except Exception as e:
        print("==", rid, "ERROR", type(e).__name__, e)
