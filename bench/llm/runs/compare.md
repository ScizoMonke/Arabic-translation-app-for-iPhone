# LLM bench: English -> Egyptian Arabic (4 fields)

Every cell is real model output from runs/<model>/results.jsonl. Decoding: greedy, max 200 new tokens, bf16, batch 1, RTX 5070 Ti.
Leak = count of Arabic-script characters inside the arabizi + latin fields (parsed rows only). Digits-in-latin = parsed rows whose latin field contains any digit (Arabizi leaking into the English-reader respelling).

| model | prompt | params | parse failures | Arabic chars leaked (arabizi+latin) | rows with digits in latin | mean output tokens | s/sentence | MLX Swift arch support |
|---|---|---|---|---|---|---|---|---|
| Nile-Chat-4B | A | 3.88B | 1/40 | 0 | 17 | 47.2 | 5.30 | yes: mlx-swift-lm@128f49f1 Libraries/MLXLLM/LLMModelFactory.swift:61 `"gemma3_text": create(Gemma3TextConfiguration.self, Gemma3TextModel.init),` (model_type gemma3_text) |
| Qwen3-4B | A | 4.02B | 0/40 | 0 | 11 | 50.8 | 4.29 | yes: mlx-swift-lm@128f49f1 Libraries/MLXLLM/LLMModelFactory.swift:67 `"qwen3": createQwen3CompatibleModel,` (model_type qwen3) |

## 1. Hello.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | السلام عليكم | el salam 3aleikom | E-L SALAM 3ALEIKOM | Hi there! |
| Qwen3-4B | مرحبا | marhaba | MAR-hba | HELLO |

## 2. Good morning.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | صباح الخير | sabah el kheir | SABAH EL KHEIR | GOOD MORNING |
| Qwen3-4B | صباح الخير | sabah al-khayr | SABAH AL-KHAYR | GOOD MORNING |

## 3. Good morning to you too.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | صباح الخير | sabah el kheir | SABAH EL KHEIR | GOOD MORNING TO YOU TOO |
| Qwen3-4B | صباح الخير لك أيضًا | sabah al-khier lik 7idam | SABAH AL-KHIER LIK 7IDAM | GOOD MORNING TO YOU ALSO |

## 4. How are you?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | PARSE FAIL (no JSON object found); raw: {"arabic": "إزيك؟", "arabizi": "ezayk?", "latin": "EZZIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII | | | |
| Qwen3-4B | كيف أنت؟ | KIF ANT? | KIF ANT | HOW ARE YOU |

## 5. I'm fine, thank God.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | انا كويس الحمد لله | ana kowayyes el7amdullah | A-NA KUWAYYES EL7AMDOLLAH | I am good, thanks be Allah |
| Qwen3-4B | أنا بخير شكر الله | ana bkhayr shakr allah | A-NA B-KHAYR SHAKR ALLAH | I I-am fine thank God |

## 6. Nice to meet you.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | اهلا وسهلا | ahla w sahla | AHLA W SAHLA | HIHLO WEL SALAM |
| Qwen3-4B | سأي بيك | sai bi7 | SAY BI7 | SAY BI7 |

## 7. Goodbye, see you tomorrow.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | مع السلامة، نشوفك بكره. | ma3 el salama, neshoofak bokra. | Ma3 el SALAMA, neshufak bOKRA. | Bye, see you tomorrow |
| Qwen3-4B | بسماعك مالا بس نلاقي اليوم بس | besma3k ma3a bas nala3i alayyab bas | B-SEE-mahk MAH-lah BES NEE-ah-ee ALAY-yah BAH-s | GOOD-BYE SEE YOU TOMORROW BES |

## 8. Thank you very much.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | شكرا جزيلا | shokran gazilan | SHOKRAN GAZILAN | THANK YOU VERY MUCH |
| Qwen3-4B | شكرك بكثير | shukrak b3khir | SHUKR AK B3KHIR | THANK YOU VERY MUCH |

## 9. You're welcome.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | العفو | el 3afo | El 3aFOO | The 3aFOO |
| Qwen3-4B | أنا بتحب مصري | ana batheb masri | A-NA BA-THIBB MAS-REE | I I-love Egyptians |

## 10. This is delicious.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | ده طعمه حلو | da ta3mo 7elw | DA ta3MO 7ELW | Da ta3mo 7elw |
| Qwen3-4B | هذا مغذى | hatha maghda | HA-THA MA-GHDA | THIS IS DELICIOUS |

## 11. I'm full.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | انا شبعان | ana shabaan | A-NA sha-BAH-han | I am full |
| Qwen3-4B | أنا مكتمل | ana makhtml | A-NA MAKHTML | I AM FULL |

## 12. A little more, please.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | من فضلك شوية كمان | men fadlak shwaya kaman | Men Fadla Shwaya Kaman | From Please A Little More |
| Qwen3-4B | أنا بسأكمل قليلاً | ana basa7il ma3ila | A-NA BA7IBIL MA3ILA | I I-will finish a-little |

## 13. No sugar, please.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | لا سكر لو سمحت | la sokkar law sama7 | La sokkar law sama7 | No sugar, please |
| Qwen3-4B | لا سكر يالله | la saker yal3al | LA SAKER YAL3AL | NO SUGAR PLEASE |

## 14. Can I have some water?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | ممكن مية؟ | momken mayya? | moo2kan mayya? | maynfa3sh maya? |
| Qwen3-4B | أنا بسأله ماء | ana basal ma | A-NA BA-SAL MA | I CAN HAVE WATER |

## 15. Where is the bathroom?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | فين الحمام؟ | feen el 7ammam? | feen el 7ammam? | where is the bathroom? |
| Qwen3-4B | متي بانوو مسجى؟ | mee ba7oo masjee | MEE BA7OO MASJEE | WHERE IS THE BATHROOM |

## 16. Please say it slower.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | من فضلك قولها ببطء | men fadlak oolha bebot2 | Men Fadlaa Oola Bebotoo2 | From please say it slowly |
| Qwen3-4B | اِنْتَنْ بِسْكِرْ | intan biskr | IN-TAN BI-SKIR | YOU SAY IT SLOWER |

## 17. Can you say it again?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | ممكن تقولها تاني؟ | momken te2olha tany? | Momken te2olha tany? | Momken te2olha tany? |
| Qwen3-4B | يمكنك قولها مجددًا | yamkunak qoolha ma3d3an | YAM-KUNAK QOOL-HA MA3-D3AN | YOU CAN SAY IT AGAIN |

## 18. I don't understand.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | مش فاهم | mesh fahem | MASH FAHEM | I do not understand |
| Qwen3-4B | أنا بسأدي | ana basa7id | A-NA BA-SAH-DI | I I-don't understand |

## 19. What does that mean?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | يعني إيه ده؟ | ya3ni eh da? | Ya3ni eh da? | What does that mean? |
| Qwen3-4B | ما ده بيعني؟ | ma deh bi7inay? | MA DEH BI7INAY | WHAT DOES THAT MEAN |

## 20. This is my uncle.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | ده عمي | da omi | DA OMI | THIS IS MY UNCLE |
| Qwen3-4B | هذا أخوي | hatha akhwi | HA-THA AKH-WEE | THIS MY UNCLE |

## 21. Where is my aunt?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | فين خالتي؟ | feen khalaty? | feen kha-la-ty? | where is my aunt? |
| Qwen3-4B | متي بنتي؟ | mati binti | MATI BINTI | WHERE MY AUNT |

## 22. How is Grandma doing?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | إزيك يا تيتة؟ | ezik ya teta? | E-ZIK YA TETA? | HIW IZ GRANDMA DOING? |
| Qwen3-4B | كيف هي أمّي؟ | kif hi ammee | KIF HI AMEE | HOW IS MOMMY |

## 23. How is everyone?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | إزيكو؟ | eziko? | EZZIKOO? | HOW IS EVERYONE? |
| Qwen3-4B | كيف هوا كلهم؟ | KIF HA wa KALAM | KIF HA WA KALAM | HOW IS EVERYONE |

## 24. I missed you all.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | وحشتوني كلكم | wa7ashtooni kolkom | Wa7a-shtoonee koLkoM | I miss you all |
| Qwen3-4B | أنا بخسرك كلهم | ana baksirka khalhum | A-NA BAKSIRKAA KHALHUM | I I-missed you all |

## 25. Yes.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | أيوه | aywa | Ay-WAH | Yeeees |
| Qwen3-4B | نعم | nem | NEM | YES |

## 26. No.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | لا | la | LA | NO |
| Qwen3-4B | لا | la | LA | NO |

## 27. Maybe.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | ممكن | momken | MOMKEN | MAYBE |
| Qwen3-4B | قد | qad | QAD | MAY-be |

## 28. Later.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | بعدين | ba3den | Ba3d-een | After |
| Qwen3-4B | بدي لاتر | badi la7er | B-DE LA-TER | I WILL LATER |

## 29. Tomorrow.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | بكرة | bokra | Bo-KRA | To-mor-row |
| Qwen3-4B | أمسية | amsiya | A-MES-ee-ah | TOMORROW |

## 30. Let's go.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | يلا بينا | yalla bina | YALLA BINA | LET'S GO |
| Qwen3-4B | ايه ناول | a7 nayl | A-HE NAYL | LET'S GO |

## 31. How much is this?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | كام ده؟ | kam dah? | KAAM DAH? | HOW MUCH IS THIS? |
| Qwen3-4B | كم هذة؟ | kam huzza? | KAM HUZZA | HOW MUCH THIS |

## 32. That's too expensive.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | ده غالي أوي | da ghalii awi | Da GHALII AWI | This is very expensive |
| Qwen3-4B | هذا مال كثيير | hatha mal kathiir | HAH-THA MAAL KATH-IIR | THIS MONEY TOO MUCH |

## 33. Where is the hotel?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | فين الفندق؟ | feen el fondok? | Feen el fonduq? | Where is the hotel? |
| Qwen3-4B | ما مكان المبيت؟ | ma maqan al-mabiat | MA MA-QUAN AL-MA-BIAT | WHERE PLACE HOTEL |

## 34. Turn left.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | لف يمين. | lef yemeen. | Lef YEMIN. | Turn right. |
| Qwen3-4B | اكتب يسار | akhtib yasir | A-KHTIB YASIR | WRITE LEFT |

## 35. Turn right.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | لف يمين | lef yemeen | Lef YEMIN | Turn right |
| Qwen3-4B | اكتب يومن | akhtib yumin | A-KHTIB YU-MIN | TURN RIGHT |

## 36. Stop here, please.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | ماتمشيش هنا، لو سمحت. | matmashish hena, law sama7t. | MATMASHISH HENA, LAW SAMAHAT. | MATMASHISH HENA, LAW SAMAHAT |
| Qwen3-4B | صُدّق هنا | sud3k hana | S-TOP H-E-RE | STOP HERE |

## 37. I'm tired.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | انا تعبان | ana ta3ban | A-NA TA3BAN | I am TIRED |
| Qwen3-4B | أنا متعب | ana matib | A-NA MA-TIB | I I-AM TIRED |

## 38. I have a headache.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | عندي صداع | 3ando sada3 | 3ANDO SODA3 | I have a headache |
| Qwen3-4B | أنا بآلام في الرأس | ana ba7alim fi al-ras | A-na BA7ALIM FI AL-RAS | I I-have pain in the head |

## 39. I need to rest a little.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | محتاج أريح شوية | me7tag ara7 shwaya | Me7TAG ARAYE7 SHWAYA | ME7TAG ARYEE7 SHWEYA |
| Qwen3-4B | أنا بحاجة راحة بليت | ana ba7abat ra7a bleyt | A-na BA7ABAT RA7A BLEYT | I I-need REST A LITTLE |

## 40. I'm happy to be here with you.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | انا مبسوط اني هنا معاك | ana mabsoot eni hena ma3ak | A-NA MABSOOT ENI HEENA MA3AK | I am happy to be here with you |
| Qwen3-4B | أنا سعيد بوجودي هنا معك | ana saeed biwajoodi hana ma3ik | A-NA SAEE-DAY BIWAJOODI HANA MA3IK | I I-AM HAPPY TO BE HERE WITH YOU |
