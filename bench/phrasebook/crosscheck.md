# Cross-check: blind back-translation by qwen3:8b (Ollama, temperature 0, think off)

Command: `python bench/phrasebook/crosscheck.py` (from the worktree root). The model saw only the arabic field. Full output: crosscheck_raw_before.tsv (first pass) and crosscheck_raw.tsv (after fixes).

Disagreements in meaning on the first pass: 67 of 272. Fixed as my error or ambiguity: 9. After the fixes, 5 now agree; 62 still disagree (58 untouched, 4 rephrased) and are judged model misreadings, left flagged for the orchestrator.

Power of this check: low. qwen3:8b misreads common Egyptian words and unvoweled homographs (mayya water read as meyya hundred, fakka change as cake, 3eish bread as living, bel laban as Lebanon, 3ammi my uncle as blind). A second pass on the arabizi field of the 62 rows (crosscheck_arabizi.py, crosscheck_arabizi.tsv) was worse: the model hallucinated on nearly every row, so it gives no signal either way. Nile-Chat-4B, already on disk, was probed as a second back-translator and answered in Arabic paraphrase instead of English, so it was not used. The orchestrator's Arabic audit should start from the table below.

Not counted: rows where the model's English matches in meaning with small loss (plural dropped, 'what a blessing' for mashallah, 'along' for straight ahead).

## Still disagreeing (flagged)

id | english | arabic | back-translation (after) | why I judge it
--- | --- | --- | --- | ---
intro-brothers-son | i'm your brother's son | أنا ابن أخوك / أخوكي | I'm your uncle's son / your uncle's son | model read akhook as uncle; akhook is 'your brother'
intro-dad-says-hi | my father says hello | بابا بيسلم عليكم | May your father greet you / May your father greet you | model read beysallem (greets, habitual) as a wish
intro-what-work | what do you do | بتشتغل إيه؟ / بتشتغلي إيه؟ | What are you doing? | beteshta8al = you work; model gave 'doing'
fam-uncle-paternal | uncle | عمي | I'm blind / I'm blind | homograph in unvoweled script; spoken form is unambiguous (3ammi my uncle / 3ama blindness)
fam-grandma | grandma | تيتة | You're a girl / You're a woman | teta is the standard Cairo word for grandma; model missed it
fam-cousin | cousin | ابن عمي | My son is blind | homograph in unvoweled script; spoken form is unambiguous (3ammi)
fam-cousin-f | my female cousin | بنت عمي | My daughter is blind / My son is blind | homograph in unvoweled script; spoken form is unambiguous (3ammi)
fam-cousin-aunt | my aunt's son | ابن عمتي | My cousin's son / My cousin's daughter | model scrambled the kinship
fam-cousin-maternal-uncle | my mother's brother's son | ابن خالي | My father's son / My mother's son | model read 5ali as 'empty'/scrambled kinship
fam-how-related | how are we related | إحنا قرايب إزاي؟ | We're almost there, how? | model read 2arayeb (relatives) as 2orayyeb (near)
fam-look-like-dad | you look like my father | انت شبه بابا / انتي شبه بابا | You're almost like a father / You're almost like a father | model read shabah (likeness) as 'almost' (MSA shibh)
st-no-sleep-plane | i didn't sleep on the plane | منمتش في الطيارة | I didn't get on the plane / I didn't get on the plane | manemtesh = I didn't sleep; model misparsed the negation
st-i-like-it | i like it | عاجبني أوي | I'm so tired | 3agebni = it pleases me; model missed the Egyptian verb
st-me-too | me too | وأنا كمان | I'm here too /I'm here too | w ana kaman = and me too; model gave 'I'm here too'
st-good-one | that's funny | حلوة دي | You're sweet / You're sweet | literal 'this one is sweet'; idiom for a good joke. Also on the least-certain list
st-missed-all | i missed you all | وحشتوني | I'm scared of you / I'm scared of you | wa7ashtoni = I missed you all; model read wa7sh (monster) -> 'scared'
st-ahly-zamalek | ahly or zamalek | أهلي ولا زمالك؟ | How are you, my dear and my friend? | proper nouns (football clubs) not recognized
hosp-bless-hands | god bless your hands | تسلم إيدك | Peace be upon you | teslam eedak is the fixed thanks-to-the-cook; model gave a greeting
hosp-with-milk | with milk | بلبن | Go to Lebanon / Go to Lebanon | homograph in unvoweled script; spoken form is unambiguous (bel laban 'with milk' / Lebnan 'Lebanon')
hosp-coffee-medium | coffee with medium sugar | قهوة مظبوط | strong coffee | mazboot = medium sugar in coffee orders; model gave 'strong'
hosp-no-thanks | no thank you | لأ، شكرا | You're welcome /no translation needed | la2, shokran = no, thanks; model gave 'you're welcome'
hosp-want-taste | i want to try it | عايز أدوق | I want to go | adoo2 = I taste (Egyptian of dhaq); model gave 'go'
hosp-bread | can you pass the bread | ممكن العيش؟ | Can I live? | homograph in unvoweled script; spoken form is unambiguous (3eish = bread in Egypt / 'living')
rel-god-generous | god is generous | ربنا كريم | May God be kind to you /no translation needed | statement 'our Lord is generous' read as a wish; sense close
pol-welcome | you're welcome | العفو | Forgive me / no offense | el 3afw = you're welcome in Egypt; model took the MSA 'pardon' sense
pol-never-mind | never mind | معلش | You're welcome / You're welcome | ma3lesh = never mind / sorry; model gave 'you're welcome'
pol-okay | okay | ماشي | Let's go / Let's go (to the car) | mashi = okay; model took the literal 'walking/going'
pol-up-to-you | whatever you think | اللي تشوفه / اللي تشوفيه | Whoever sees him / whoever sees her | elli tshoofo = whatever you see fit; model misparsed
pol-kind | you are very kind | ده من ذوقك | That's your taste / That's your style | model gave the literal ('that's your taste'), which is the gloss; idiom = that's kind of you
meta-speak-slowly | please speak slowly | اتكلم بالراحة شوية / اتكلمي بالراحة شوية | Talk comfortably for a bit / Talk comfortably for a bit | bel ra7a = slowly in Cairo (the brief's own example); model took MSA 'comfort'
meta-dad-taught | my father taught me a little | بابا علمني شوية | Dad, I told you some stuff /no translation needed | 3allemni = taught me; model gave 'told you'
dir-slow-down | slow down | بالراحة لو سمحت | If it's okay with you, I'll take the comfort / If it's okay with you, I'll take the comfort | bel ra7a = slowly (as above)
dir-how-much-to | how much to | توصلني لحد هناك بكام؟ | How long will it take to get me there? | FIXED phrasing (bekam le7add hnak -> tewa99alni le7add hnak bekam, the usual taxi form); model still reads bekam as duration
dir-take-me | take me to this address | وصلني العنوان ده | I got this address. | FIXED phrasing (waddeeni read as 'and my religion'); new wa99alni read as 'reached me', a script homograph
dir-lost | i'm lost | أنا تايه | I'm tired / I'm exhausted | tayeh = lost; model gave 'tired'
dir-there | there | هناك | Here /no translation | hnak = there; model gave 'here'
shop-take-it | i'll take it | هاخده | Take it | ha5do = I'll take it (ha- future); model gave imperative
shop-change | do you have change | معاك فكة؟ | Do you have a cake? | homograph in unvoweled script; spoken form is unambiguous (fakka small change / ka3ka cake misread)
shop-no-change | i don't have change | معييش فكة | I don't have a tooth / I don't have a tooth (for a man or a woman) | homograph in unvoweled script; spoken form is unambiguous (fakka)
shop-just-looking | just looking | بتفرج بس | Just look / Just look (at me) | batfarrag = I'm looking around; model gave imperative
hl-need-water | i need water | عايز مية | I want a hundred | homograph in unvoweled script; spoken form is unambiguous (mayya water / meyya hundred)
hl-cold | i'm cold | أنا بردان | I'm tired / I'm exhausted | bardan = cold (person); model gave 'tired'
hl-hot | i'm hot | أنا حران | I'm fine /I'm okay | 7arran = hot (person); model gave 'fine'
hl-painkiller | do you have painkillers | عندك مسكن؟ | Do you have a place to stay? | homograph in unvoweled script; spoken form is unambiguous (mosakken painkiller / maskan dwelling)
tm-day-after | the day after tomorrow | بعد بكرة | Tomorrow | ba3d bokra = day after tomorrow; model dropped 'after'
tm-morning | in the morning | الصبح | Good morning | e99ob7 = the morning / in the morning; model gave the greeting
tm-leave-when | what time do we leave | هنمشي الساعة كام؟ | What time is it? | model dropped 'we will leave'
tm-wake-when | what time do we wake up | هنقوم الساعة كام؟ | What time is it? | model dropped the verb. Self-review (not the check) replaced han9a7a, whose respelling 'hansaha' misplaces the vowel, with han2oom 'we get up'
tm-coming | i'm coming | جاي حالا | Come on now / Come on now | gay 7alan = coming right now; model gave 'come on'
pr-battery-dead | my phone died | الموبايل فصل شحن | The phone is charging /no translation needed | fa9al sha7n = the battery died (Egyptian idiom); model gave 'charging'
pr-sim | where can i buy a sim | أشتري خط موبايل منين؟ | Where do you want to buy a mobile phone? | FIXED: added 'mobile' to 5a6 (line = SIM); model still says 'buy a mobile phone'
pr-outlet | where can i plug this in | فين الفيشة؟ | Where's the fish? | homograph in unvoweled script; spoken form is unambiguous (feesha socket, from French fiche)
pr-exchange | where can i exchange money | أغير فلوس فين؟ | Where did I lose my money? | a8ayyar floos = I change money; model gave 'lose'
pr-wake-me | can you wake me up | ممكن تصحيني؟ | Can you check my work? | te9a77eeni = wake me; model read it as t9a77a7 (to correct, grade)
bye-goodnight | good night | تصبح على خير / تصبحي على خير | You're well / You're well too... | te9ba7 3ala 5eir is the fixed good night; model failed on it
bye-goodnight-all | good night everyone | تصبحوا على خير | You are all well / You are all fine | as bye-goodnight
bye-miss-you | i'll miss you | هتوحشني / هتوحشيني | You're scolding me / You're scolding her / | hatew7ashni = I'll miss you; model read 'scold'
bye-miss-you-all | i'll miss you all | هتوحشوني | Don't scold me / Don't scold me | as bye-miss-you
bye-great-time | i had a great time | انبسطت أوي | I'm fine / I'm okay | enbasa6t awi = I enjoyed myself a lot; model gave 'I'm fine'
bye-come-back | i will come back | هرجع تاني إن شاء الله | He'll come back again if God wills | harga3 = I will return (Egyptian ha- + 1sg); model gave 3rd person
bye-say-hi | say hi to everyone for me | سلملي على الكل / سلميلي على الكل | Peace be upon all of you / Peace be upon all of you | sallemli 3ala el koll = greet everyone for me; model gave the greeting itself
intro-from-abroad | i came from abroad | أنا جاي من بره مصر | I'm coming from the border of Egypt /no translation needed | FIXED: men barra read as 'from the village'; now 'men barra ma9r' (from outside Egypt); model now says 'border of Egypt'

## Fixed and now agreeing

id | english | arabic (new) | back-translation before -> after | fix
--- | --- | --- | --- | ---
meta-speak-into-phone | speak into the phone | اتكلم والموبايل هيترجم / اتكلمي والموبايل هيترجم | Talk on the phone / talk on the phone -> Speak and the mobile translates / speak and the mobile translates | FIXED: 'speak in the mobile' also means 'talk on the phone'; now 'speak and the mobile will translate'
meta-one-second | one second let me translate | ثانية واحدة، هترجم | Translate again -> In one second, I'll translate | FIXED: sanya alone read as 'again'; now "sanya wa7da, hatargem"
shop-expensive | too expensive | ده غالي أوي | Oh my dear / Oh my love -> That's expensive, yeah /no translation needed | FIXED: bare 8ali also means 'dear'; now 'da 8ali awi'
tm-week | i'm staying for a week | أنا هقعد أسبوع | I've been sitting for a week -> I'm going to stay for a week | FIXED: 2a3ed esboo3 read as past ('been sitting'); now future ha23od
tm-two-weeks | i'm staying for two weeks | أنا هقعد أسبوعين | I've been here for two weeks -> I'll stay for two weeks | FIXED: as tm-week
