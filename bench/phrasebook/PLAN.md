# Phrasebook plan (D22)
1. Scripts first: respell.py (D20 digit map, the only source of the respelling field), build.py (entries.py -> app/EgyptTalk/Resources/phrasebook.json), check.py (mechanical checks).
2. Author ~200 Egyptian (Cairo) entries in entries.py by scene; arabizi uses 2 3 5 7 8 9 6, Cairene qaf as 2; addressee-gendered lines carry "masc / fem" in one entry.
3. Commit in steps: scripts, first 100 entries, the rest.
4. crosscheck.py: qwen3:8b via Ollama back-translates each arabic field blind; disagreements go to crosscheck.md; fix my errors, flag the rest.
5. account.md holds the overflow: conventions, fixes, the ten least-certain entries.
