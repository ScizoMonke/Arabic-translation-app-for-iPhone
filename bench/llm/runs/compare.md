# LLM bench: English -> Egyptian Arabic (4 fields)

Every cell is real model output from runs/<model>/results.jsonl. Decoding: greedy, max 200 new tokens, bf16, batch 1, RTX 5070 Ti.
Leak = count of Arabic-script characters inside the arabizi + latin fields (parsed rows only). Digits-in-latin = parsed rows whose latin field contains any digit (Arabizi leaking into the English-reader respelling).

| model | prompt | params | parse failures | Arabic chars leaked (arabizi+latin) | rows with digits in latin | mean output tokens | s/sentence | MLX Swift arch support |
|---|---|---|---|---|---|---|---|---|
| Nile-Chat-4B | A | 3.88B | 1/40 | 0 | 17 | 47.2 | 5.30 | yes: mlx-swift-lm@128f49f1 Libraries/MLXLLM/LLMModelFactory.swift:61 `"gemma3_text": create(Gemma3TextConfiguration.self, Gemma3TextModel.init),` (model_type gemma3_text) |

## 1. Hello.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | السلام عليكم | el salam 3aleikom | E-L SALAM 3ALEIKOM | Hi there! |

## 2. Good morning.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | صباح الخير | sabah el kheir | SABAH EL KHEIR | GOOD MORNING |

## 3. Good morning to you too.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | صباح الخير | sabah el kheir | SABAH EL KHEIR | GOOD MORNING TO YOU TOO |

## 4. How are you?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | PARSE FAIL (no JSON object found); raw: {"arabic": "إزيك؟", "arabizi": "ezayk?", "latin": "EZZIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII | | | |

## 5. I'm fine, thank God.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | انا كويس الحمد لله | ana kowayyes el7amdullah | A-NA KUWAYYES EL7AMDOLLAH | I am good, thanks be Allah |

## 6. Nice to meet you.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | اهلا وسهلا | ahla w sahla | AHLA W SAHLA | HIHLO WEL SALAM |

## 7. Goodbye, see you tomorrow.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | مع السلامة، نشوفك بكره. | ma3 el salama, neshoofak bokra. | Ma3 el SALAMA, neshufak bOKRA. | Bye, see you tomorrow |

## 8. Thank you very much.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | شكرا جزيلا | shokran gazilan | SHOKRAN GAZILAN | THANK YOU VERY MUCH |

## 9. You're welcome.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | العفو | el 3afo | El 3aFOO | The 3aFOO |

## 10. This is delicious.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | ده طعمه حلو | da ta3mo 7elw | DA ta3MO 7ELW | Da ta3mo 7elw |

## 11. I'm full.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | انا شبعان | ana shabaan | A-NA sha-BAH-han | I am full |

## 12. A little more, please.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | من فضلك شوية كمان | men fadlak shwaya kaman | Men Fadla Shwaya Kaman | From Please A Little More |

## 13. No sugar, please.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | لا سكر لو سمحت | la sokkar law sama7 | La sokkar law sama7 | No sugar, please |

## 14. Can I have some water?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | ممكن مية؟ | momken mayya? | moo2kan mayya? | maynfa3sh maya? |

## 15. Where is the bathroom?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | فين الحمام؟ | feen el 7ammam? | feen el 7ammam? | where is the bathroom? |

## 16. Please say it slower.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | من فضلك قولها ببطء | men fadlak oolha bebot2 | Men Fadlaa Oola Bebotoo2 | From please say it slowly |

## 17. Can you say it again?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | ممكن تقولها تاني؟ | momken te2olha tany? | Momken te2olha tany? | Momken te2olha tany? |

## 18. I don't understand.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | مش فاهم | mesh fahem | MASH FAHEM | I do not understand |

## 19. What does that mean?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | يعني إيه ده؟ | ya3ni eh da? | Ya3ni eh da? | What does that mean? |

## 20. This is my uncle.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | ده عمي | da omi | DA OMI | THIS IS MY UNCLE |

## 21. Where is my aunt?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | فين خالتي؟ | feen khalaty? | feen kha-la-ty? | where is my aunt? |

## 22. How is Grandma doing?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | إزيك يا تيتة؟ | ezik ya teta? | E-ZIK YA TETA? | HIW IZ GRANDMA DOING? |

## 23. How is everyone?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | إزيكو؟ | eziko? | EZZIKOO? | HOW IS EVERYONE? |

## 24. I missed you all.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | وحشتوني كلكم | wa7ashtooni kolkom | Wa7a-shtoonee koLkoM | I miss you all |

## 25. Yes.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | أيوه | aywa | Ay-WAH | Yeeees |

## 26. No.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | لا | la | LA | NO |

## 27. Maybe.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | ممكن | momken | MOMKEN | MAYBE |

## 28. Later.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | بعدين | ba3den | Ba3d-een | After |

## 29. Tomorrow.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | بكرة | bokra | Bo-KRA | To-mor-row |

## 30. Let's go.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | يلا بينا | yalla bina | YALLA BINA | LET'S GO |

## 31. How much is this?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | كام ده؟ | kam dah? | KAAM DAH? | HOW MUCH IS THIS? |

## 32. That's too expensive.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | ده غالي أوي | da ghalii awi | Da GHALII AWI | This is very expensive |

## 33. Where is the hotel?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | فين الفندق؟ | feen el fondok? | Feen el fonduq? | Where is the hotel? |

## 34. Turn left.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | لف يمين. | lef yemeen. | Lef YEMIN. | Turn right. |

## 35. Turn right.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | لف يمين | lef yemeen | Lef YEMIN | Turn right |

## 36. Stop here, please.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | ماتمشيش هنا، لو سمحت. | matmashish hena, law sama7t. | MATMASHISH HENA, LAW SAMAHAT. | MATMASHISH HENA, LAW SAMAHAT |

## 37. I'm tired.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | انا تعبان | ana ta3ban | A-NA TA3BAN | I am TIRED |

## 38. I have a headache.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | عندي صداع | 3ando sada3 | 3ANDO SODA3 | I have a headache |

## 39. I need to rest a little.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | محتاج أريح شوية | me7tag ara7 shwaya | Me7TAG ARAYE7 SHWAYA | ME7TAG ARYEE7 SHWEYA |

## 40. I'm happy to be here with you.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | انا مبسوط اني هنا معاك | ana mabsoot eni hena ma3ak | A-NA MABSOOT ENI HEENA MA3AK | I am happy to be here with you |
