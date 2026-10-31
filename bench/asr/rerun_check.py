# Compares a run's current results.jsonl against the committed version (HEAD) and prints mismatching clip ids.
# Usage: python rerun_check.py <dataset> <run-dir-name>
import json, subprocess, sys
sys.stdout.reconfigure(encoding="utf-8")
rel = f"bench/asr/runs/{sys.argv[1]}/{sys.argv[2]}/results.jsonl"
now = [json.loads(l) for l in open(rel.removeprefix("bench/asr/"), encoding="utf-8")]
head = [json.loads(l) for l in subprocess.run(["git", "show", f"HEAD:{rel}"], capture_output=True, check=True).stdout.decode("utf-8").splitlines()]
bad = [x["clip_id"] for x, y in zip(now, head) if x["hypothesis"] != y["hypothesis"]]
print(sys.argv[2], "identical", len(now) - len(bad), "of", len(now), "mismatch:", bad)
