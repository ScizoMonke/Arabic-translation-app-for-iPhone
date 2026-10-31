# Phrasebook account (D22)

## Outcome
272 entries, 1094 English aliases (3 to 6 each, unique across the book), in app/EgyptTalk/Resources/phrasebook.json, schema exactly as dealt.
Scenes (tag: count): greeting 13, intro 25, family 21, smalltalk 26, hospitality 27, religious 14, polite 18, meta 19, directions 22, shopping 16, health 20, time 19, practical 15, goodbye 17.
272 is over the "about 200" the brief asked for. Three speculative entries (my wife / son / daughter) were removed; the rest stayed because each is a plausible sentence of the visit. Trim if the matcher's fuzzy tier misfires with this many.

## Conventions set
- Cairo Egyptian throughout. Qaf is the glottal stop and written 2 (2ahwa, 2ader); jim is g (gameel, geddo).
- Arabizi digits per the ledger: 2 hamza and Cairene qaf, 3 ayn, 5 kh, 7 h, 8 gh, 9 sad, 6 ta. Dad is d, za is z, tha is s or t as Cairenes say it (sanya). Sun-letter assimilation written as heard: essalama, ennaharda, e99ob7.
- The speaker is a man: every first-person form is masculine (ana ta3ban, mesh fahem, me7tag, asef). This also answers the coordinator's addendum.
- Listener gender: a line whose form changes with the listener carries both halves in one entry, man first, separated by " / " in arabic (only where the spelling differs), arabizi and respelling; the gloss ends "(to a man / to a woman)". Reason: he will talk mostly to aunts and his grandmother, and the masculine-only form to a woman is the kind of slip that makes him sound foolish. check.py enforces that a slashed arabizi has "woman" in its gloss. Taxi and shop lines address a man only and say "(to the driver)" where it matters. This changes what he sees, so it is the reading most worth a veto.
- Gloss: literal English in Arabic word order, omitted copula and articles in [brackets], the use in (parentheses) when the literal hides it: "praise [be] to God", "may your hand stay safe (thanks to the cook)".
- "..." marks a slot he fills himself (esmi ..., ana ebn ...).
- Addendum sentences covered with generous aliases: greet-morning (5), greet-morning-reply (6), greet-evening (5), bye-goodnight (5, separate from good evening), meta-what-mean (6), dir-stop-here (6), dir-left (6), dir-right (6), hl-rest (6, masculine me7tag), hl-headache (6).

## Scripts
- respell.py: the D20 map plus 4 -> th, apostrophe collapse, and an apostrophe dropped when not preceded by a letter (word start, after "/" or "("). The only source of the respelling field.
- build.py: entries.py -> phrasebook.json. check.py: mechanical checks. crosscheck.py: blind back-translation.

## Cross-check
qwen3:8b via Ollama, temperature 0, thinking off, sees only the arabic field. First pass: 67 of 272 disagree in meaning. 9 fixed as my error or ambiguity (5 now agree, 4 rephrased still misread). After: 62 flagged, each with the reason I judge it a model misreading, in crosscheck.md. The check's power is low; see crosscheck.md.

Fixes made from the check:
1. intro-from-abroad: "men barra" can mean "from outside (the house)" -> "ana gay men barra ma9r" (from outside Egypt).
2. meta-speak-into-phone: "etkallem fel mobile" also means "talk on the phone (make a call)" -> "etkallem wel mobile hayetargem" (speak and the mobile will translate).
3. meta-one-second: bare "sanya" read as "again" -> "sanya wa7da, hatargem".
4. dir-how-much-to: "bekam le7add hnak" -> "tewa99alni le7add hnak bekam?", the usual taxi form.
5. dir-take-me: "waddeeni" reads in script as "and my religion" -> "wa99alni el 3enwan da".
6. shop-expensive: bare "8ali awi" also means "very dear" -> "da 8ali awi".
7. tm-week, 8. tm-two-weeks: "ana 2a3ed esboo3" read as past -> future "ana ha23od esboo3 / esbo3ein".
9. pr-sim: "5a6" alone -> "5a6 mobile".
Self-review fix (not from the check): 10. tm-wake-when: "han9a7a" put the vowel in the wrong place (respelling "hansaha"); replaced with "han2oom essa3a kam?" (what time do we get up).

## Ten least certain as natural Cairo speech
1. hosp-dont-trouble: the verb form and its arabizi (matet3ebsh vs matta3absh) are my least sure.
2. st-good-one: "7elwa di" fits "good one" after a joke; the aliases "that's funny" stretch it.
3. st-traffic: "el za7ma 9a3ba awi" is fine but bland; a Cairene more likely says "el za7ma fazee3a".
4. intro-thanks-welcome: "el este2bal el gameel" leans formal; family talk might be "ta3abtoko ma3aya".
5. intro-dad-misses: "meshta2elkom" spelling and whether "baba wa7ashtooh" is the more natural form.
6. fam-cousin and fam-cousin-f: "cousin" defaults to the father's brother's child; wrong lineage if the cousin comes from an aunt.
7. fam-look-like-dad: vowel of "shabah" (shabah vs shebh).
8. hl-sick: "7asses enni ta3ban" vs the plainer "ana 3ayyan".
9. pr-atm: "makanet 9arf"; Cairenes may simply say "ATM" or "makanet floos".
10. intro-from-abroad: even after the fix the model misreads it; "ana gay men el 5areg" is the alternative.

## Not done / outside scope
- No native grader (D15). The orchestrator audit is the only Arabic reading besides mine.
- Matching behaviour of 1094 aliases against the app's fuzzy tier is untested here; short aliases ("left", "right", "here", "what", "when", "how much to", "son of") are the ones most likely to capture sentences they should not.
