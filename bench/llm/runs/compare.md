# LLM bench: English -> Egyptian Arabic (4 fields)

Every cell is real model output from runs/<model>/results.jsonl. Decoding: greedy, max 200 new tokens, bf16, batch 1, RTX 5070 Ti.
Leak = count of Arabic-script characters inside the arabizi + latin fields (parsed rows only). Digits-in-latin = parsed rows whose latin field contains any digit (Arabizi leaking into the English-reader respelling).

| model | prompt | params | parse failures | Arabic chars leaked (arabizi+latin) | rows with digits in latin | mean output tokens | s/sentence | MLX Swift arch support |
|---|---|---|---|---|---|---|---|---|
| Nile-Chat-4B | A | 3.88B | 1/40 | 0 | 17 | 47.2 | 5.30 | yes: mlx-swift-lm@128f49f1 Libraries/MLXLLM/LLMModelFactory.swift:61 `"gemma3_text": create(Gemma3TextConfiguration.self, Gemma3TextModel.init),` (model_type gemma3_text) |
| Nile-Chat-4B-promptB | B | 3.88B | 0/40 | 262 | 15 | 42.3 | 5.08 | yes: mlx-swift-lm@128f49f1 Libraries/MLXLLM/LLMModelFactory.swift:61 `"gemma3_text": create(Gemma3TextConfiguration.self, Gemma3TextModel.init),` (model_type gemma3_text) |
| Qwen3-4B | A | 4.02B | 0/40 | 0 | 11 | 50.8 | 4.29 | yes: mlx-swift-lm@128f49f1 Libraries/MLXLLM/LLMModelFactory.swift:67 `"qwen3": createQwen3CompatibleModel,` (model_type qwen3) |
| Qwen3-4B-promptB | B | 4.02B | 0/40 | 11 | 13 | 55.0 | 4.78 | yes: mlx-swift-lm@128f49f1 Libraries/MLXLLM/LLMModelFactory.swift:67 `"qwen3": createQwen3CompatibleModel,` (model_type qwen3) |

## 1. Hello.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | السلام عليكم | el salam 3aleikom | E-L SALAM 3ALEIKOM | Hi there! |
| Nile-Chat-4B-promptB | أهلوا | اهلوا | ahlo | اهلا |
| Qwen3-4B | مرحبا | marhaba | MAR-hba | HELLO |
| Qwen3-4B-promptB | سَلَامٌ | salam | SALAM | hello |

## 2. Good morning.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | صباح الخير | sabah el kheir | SABAH EL KHEIR | GOOD MORNING |
| Nile-Chat-4B-promptB | مساء الخير | مساء الخيـــــر | masaa el kheir | مساء الخير |
| Qwen3-4B | صباح الخير | sabah al-khayr | SABAH AL-KHAYR | GOOD MORNING |
| Qwen3-4B-promptB | سَمْرَة | samarat | SAM-rah | Good morning. |

## 3. Good morning to you too.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | صباح الخير | sabah el kheir | SABAH EL KHEIR | GOOD MORNING TO YOU TOO |
| Nile-Chat-4B-promptB | مساء الخير | مساء الخيـر | masaa el kheir | مساء الخير |
| Qwen3-4B | صباح الخير لك أيضًا | sabah al-khier lik 7idam | SABAH AL-KHIER LIK 7IDAM | GOOD MORNING TO YOU ALSO |
| Qwen3-4B-promptB | سَمْوَعْلَيْكْ | samo7alik | SAM-7AL-ik | Good morning to you too. |

## 4. How are you?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | PARSE FAIL (no JSON object found); raw: {"arabic": "إزيك؟", "arabizi": "ezayk?", "latin": "EZZIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII | | | |
| Nile-Chat-4B-promptB | إزيكو؟ | ezikoo? | ezayak? | howa/heya/homma eh? howa/heya/homma 3amel/3amla eh? |
| Qwen3-4B | كيف أنت؟ | KIF ANT? | KIF ANT | HOW ARE YOU |
| Qwen3-4B-promptB | كيف حالك؟ | kif halak? | KIF HALAK? | HOW ARE YOU? |

## 5. I'm fine, thank God.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | انا كويس الحمد لله | ana kowayyes el7amdullah | A-NA KUWAYYES EL7AMDOLLAH | I am good, thanks be Allah |
| Nile-Chat-4B-promptB | أنا كويس الحمد لله | ana kwayyes el7amdullah | ana kways el7amdulellah | ana tamam el7amdullah |
| Qwen3-4B | أنا بخير شكر الله | ana bkhayr shakr allah | A-NA B-KHAYR SHAKR ALLAH | I I-am fine thank God |
| Qwen3-4B-promptB | أنا بخير شكر الله | anA bkhayr shakr allah | AN A BKHAYR SHAKR ALLAH | I am fine thank God |

## 6. Nice to meet you.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | اهلا وسهلا | ahla w sahla | AHLA W SAHLA | HIHLO WEL SALAM |
| Nile-Chat-4B-promptB | اهلا وسهلا | اھلا وسهلا | ahla wosola | اهلا وسهلا |
| Qwen3-4B | سأي بيك | sai bi7 | SAY BI7 | SAY BI7 |
| Qwen3-4B-promptB | سَمْعَانِ لَكَ | sma2an lik | SMA-2AN LIK | Nice to meet you. |

## 7. Goodbye, see you tomorrow.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | مع السلامة، نشوفك بكره. | ma3 el salama, neshoofak bokra. | Ma3 el SALAMA, neshufak bOKRA. | Bye, see you tomorrow |
| Nile-Chat-4B-promptB | باي باي، نشوفك بكره | باى باى ، نـشوفك بكرة | bye bye, see you tomorrow. | باي باي، نشوفك بكره |
| Qwen3-4B | بسماعك مالا بس نلاقي اليوم بس | besma3k ma3a bas nala3i alayyab bas | B-SEE-mahk MAH-lah BES NEE-ah-ee ALAY-yah BAH-s | GOOD-BYE SEE YOU TOMORROW BES |
| Qwen3-4B-promptB | بسم الله وعلىكم السلام ورحمة الله وبركاته | basmallah wa3lakum salam wa rahmatullah wa barakah | BASMALLAH WA3LAKUM SALAM WA RAHMAHULLAH WA BARAKAH | In the name of God, peace be upon you, and the mercy of God and His blessings. |

## 8. Thank you very much.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | شكرا جزيلا | shokran gazilan | SHOKRAN GAZILAN | THANK YOU VERY MUCH |
| Nile-Chat-4B-promptB | شكرًا جزيلاً | شكرا جزيل | shokran gazilan | shokran gazzilan |
| Qwen3-4B | شكرك بكثير | shukrak b3khir | SHUKR AK B3KHIR | THANK YOU VERY MUCH |
| Qwen3-4B-promptB | شَكْرًا كَثِيرًا | shakr an kathiir | SHAKR AN KATHIIR | THANK YOU VERY MUCH |

## 9. You're welcome.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | العفو | el 3afo | El 3aFOO | The 3aFOO |
| Nile-Chat-4B-promptB | عفوا | 3afwa | 3afw | عفوك |
| Qwen3-4B | أنا بتحب مصري | ana batheb masri | A-NA BA-THIBB MAS-REE | I I-love Egyptians |
| Qwen3-4B-promptB | سَمْعَانِ | sman | SMAN | you are welcome |

## 10. This is delicious.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | ده طعمه حلو | da ta3mo 7elw | DA ta3MO 7ELW | Da ta3mo 7elw |
| Nile-Chat-4B-promptB | ده طعمه حلو | ده طعمو حلو | da ta3mo helw | da ta3mo helw |
| Qwen3-4B | هذا مغذى | hatha maghda | HA-THA MA-GHDA | THIS IS DELICIOUS |
| Qwen3-4B-promptB | هذا مالح | h3s m3l3h | H3S M3L3H | THIS IS DELICIOUS |

## 11. I'm full.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | انا شبعان | ana shabaan | A-NA sha-BAH-han | I am full |
| Nile-Chat-4B-promptB | انا شبعت | ana shaba3t | ana shab3at | ana shab3et |
| Qwen3-4B | أنا مكتمل | ana makhtml | A-NA MAKHTML | I AM FULL |
| Qwen3-4B-promptB | أنا مُش كَلِم | ana msh klem | ANA MSH KLEM | I am full. |

## 12. A little more, please.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | من فضلك شوية كمان | men fadlak shwaya kaman | Men Fadla Shwaya Kaman | From Please A Little More |
| Nile-Chat-4B-promptB | شوية كمان لو سمحت | شوية كاااامن لو سمح | shwaya kaman law sama7 | شوية زيادة لو سمحت |
| Qwen3-4B | أنا بسأكمل قليلاً | ana basa7il ma3ila | A-NA BA7IBIL MA3ILA | I I-will finish a-little |
| Qwen3-4B-promptB | بزايدي قليلاً | bzaydi qaliyaa | B-ZAY-di qaliyaa | ADD A LITTLE PLEASE |

## 13. No sugar, please.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | لا سكر لو سمحت | la sokkar law sama7 | La sokkar law sama7 | No sugar, please |
| Nile-Chat-4B-promptB | لا سكر لو سمحت | لا سكر لوسمحت | la sokkar law samaht | لا سكر لو سمحت |
| Qwen3-4B | لا سكر يالله | la saker yal3al | LA SAKER YAL3AL | NO SUGAR PLEASE |
| Qwen3-4B-promptB | لا سكر يالله | la sugur yalhool | LA SU-gur YAL-hool | NO SUGAR please |

## 14. Can I have some water?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | ممكن مية؟ | momken mayya? | moo2kan mayya? | maynfa3sh maya? |
| Nile-Chat-4B-promptB | ممكن مية؟ | ميكن مييه؟ | momken mayya? | momken maya? |
| Qwen3-4B | أنا بسأله ماء | ana basal ma | A-NA BA-SAL MA | I CAN HAVE WATER |
| Qwen3-4B-promptB | أنا بسأك ماء؟ | an a sA k mAW? | AN a SAW k MAH? | I am going to drink water? |

## 15. Where is the bathroom?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | فين الحمام؟ | feen el 7ammam? | feen el 7ammam? | where is the bathroom? |
| Nile-Chat-4B-promptB | فين الحمام؟ | فين الحام؟ | fein el hammam? | فين الحمام؟ |
| Qwen3-4B | متي بانوو مسجى؟ | mee ba7oo masjee | MEE BA7OO MASJEE | WHERE IS THE BATHROOM |
| Qwen3-4B-promptB | مَنْزِلِي بَيْتِي؟ | manzili biiti? | MAN-ZIL-I BI-IT-I? | WHERE IS THE HOUSE? |

## 16. Please say it slower.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | من فضلك قولها ببطء | men fadlak oolha bebot2 | Men Fadlaa Oola Bebotoo2 | From please say it slowly |
| Nile-Chat-4B-promptB | من فضلك قولها ببطء | من فضلك قولها بطبıع | men fadlak oolha bebot2 | from please say it slowly |
| Qwen3-4B | اِنْتَنْ بِسْكِرْ | intan biskr | IN-TAN BI-SKIR | YOU SAY IT SLOWER |
| Qwen3-4B-promptB | اِنْتَهِمْ بِالْكَلَامْ بِسَرَعَةْ | intam bi-alkalam bisar3at | INTAHAM BI-ALKALAM BISAR3AT | please say the speech with slow |

## 17. Can you say it again?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | ممكن تقولها تاني؟ | momken te2olha tany? | Momken te2olha tany? | Momken te2olha tany? |
| Nile-Chat-4B-promptB | ممكن تقولها تاني؟ | makan te2olha tany? | momken te2olha tany? | momken te2olha tany? |
| Qwen3-4B | يمكنك قولها مجددًا | yamkunak qoolha ma3d3an | YAM-KUNAK QOOL-HA MA3-D3AN | YOU CAN SAY IT AGAIN |
| Qwen3-4B-promptB | أكيد بس أقوله مره أخري | akid bes a3aluh mara akhri | AKID BES A3ALUH MARA AKHRI | SURE BUT SAY IT AGAIN |

## 18. I don't understand.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | مش فاهم | mesh fahem | MASH FAHEM | I do not understand |
| Nile-Chat-4B-promptB | مش فاهم | مش فاهم | mesh fahem | ana mesh fahma |
| Qwen3-4B | أنا بسأدي | ana basa7id | A-NA BA-SAH-DI | I I-don't understand |
| Qwen3-4B-promptB | أنا لازم أفهم | na laazm a fahm | NA LAZM A FAHM | I MUST UNDERSTAND |

## 19. What does that mean?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | يعني إيه ده؟ | ya3ni eh da? | Ya3ni eh da? | What does that mean? |
| Nile-Chat-4B-promptB | يعني إيه؟ | یعنى ايه؟ | ya3ni eh? | يعني ايه؟ |
| Qwen3-4B | ما ده بيعني؟ | ma deh bi7inay? | MA DEH BI7INAY | WHAT DOES THAT MEAN |
| Qwen3-4B-promptB | ما ده بس؟ | ما ده بس؟ | MA DHA BAS? | WHAT DOES THAT MEAN? |

## 20. This is my uncle.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | ده عمي | da omi | DA OMI | THIS IS MY UNCLE |
| Nile-Chat-4B-promptB | ده عمي | ديه عـمي | dehe omi | da 3ami |
| Qwen3-4B | هذا أخوي | hatha akhwi | HA-THA AKH-WEE | THIS MY UNCLE |
| Qwen3-4B-promptB | هذا أخوي | h3s 7akhwi | H3S ZAY-YAK | THIS IS MY UNCLE |

## 21. Where is my aunt?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | فين خالتي؟ | feen khalaty? | feen kha-la-ty? | where is my aunt? |
| Nile-Chat-4B-promptB | فين خالتي؟ | فِين خَالِتِي؟ | feen khalti? | فين خالتي؟ |
| Qwen3-4B | متي بنتي؟ | mati binti | MATI BINTI | WHERE MY AUNT |
| Qwen3-4B-promptB | مَنْ هِيَ أُنْثَانِي؟ | man hii auntani? | MAN HII AUNTANI? | WHO IS MY AUNT? |

## 22. How is Grandma doing?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | إزيك يا تيتة؟ | ezik ya teta? | E-ZIK YA TETA? | HIW IZ GRANDMA DOING? |
| Nile-Chat-4B-promptB | إزيكو يا طنط؟ | eziko ya tant? | ezikoo ya tant? | ازيكو يا طنط؟ |
| Qwen3-4B | كيف هي أمّي؟ | kif hi ammee | KIF HI AMEE | HOW IS MOMMY |
| Qwen3-4B-promptB | كيف تيييي نااا نااا؟ | kif tiiii naaah naaah? | KIF TIIII NAAAH NAAAH? | HOW IS GRANDMA DOING? |

## 23. How is everyone?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | إزيكو؟ | eziko? | EZZIKOO? | HOW IS EVERYONE? |
| Nile-Chat-4B-promptB | إزيكو؟ | ئزيكو؟ | ezayko? | ازيكوا؟ |
| Qwen3-4B | كيف هوا كلهم؟ | KIF HA wa KALAM | KIF HA WA KALAM | HOW IS EVERYONE |
| Qwen3-4B-promptB | كيف هم كلهم؟ | kif hem khalhum? | KIF HEM KHALHUM? | HOW ARE EVERYONE? |

## 24. I missed you all.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | وحشتوني كلكم | wa7ashtooni kolkom | Wa7a-shtoonee koLkoM | I miss you all |
| Nile-Chat-4B-promptB | نورتوا يا جماعة | نوروتو ياجماعه | nawarto ya gama3a | نورتوا يا جماعة |
| Qwen3-4B | أنا بخسرك كلهم | ana baksirka khalhum | A-NA BAKSIRKAA KHALHUM | I I-missed you all |
| Qwen3-4B-promptB | أنا بسأرّيكيك كايل | ana basariyikal kail | ANA BASARIYIKAL KAIL | I [BE] missed you all. |

## 25. Yes.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | أيوه | aywa | Ay-WAH | Yeeees |
| Nile-Chat-4B-promptB | ايوة | ايهوه | aywa | ايوة |
| Qwen3-4B | نعم | nem | NEM | YES |
| Qwen3-4B-promptB | بلا | bLa | BLA | no |

## 26. No.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | لا | la | LA | NO |
| Nile-Chat-4B-promptB | لا | لـ | la | no |
| Qwen3-4B | لا | la | LA | NO |
| Qwen3-4B-promptB | لا | la | LA | no |

## 27. Maybe.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | ممكن | momken | MOMKEN | MAYBE |
| Nile-Chat-4B-promptB | ممكن | ماكن | ma'kan | momken |
| Qwen3-4B | قد | qad | QAD | MAY-be |
| Qwen3-4B-promptB | مابش | مابش | MABSH | maybe |

## 28. Later.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | بعدين | ba3den | Ba3d-een | After |
| Nile-Chat-4B-promptB | بعدين | ba3den | ba3den | after that |
| Qwen3-4B | بدي لاتر | badi la7er | B-DE LA-TER | I WILL LATER |
| Qwen3-4B-promptB | بَعْدَ ذَلِكَ | ba3d zalyk | BA3D ZALYK | after that |

## 29. Tomorrow.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | بكرة | bokra | Bo-KRA | To-mor-row |
| Nile-Chat-4B-promptB | بكرة | بـكـرآ | bakra | borkara |
| Qwen3-4B | أمسية | amsiya | A-MES-ee-ah | TOMORROW |
| Qwen3-4B-promptB | أَمْسِيَّة | am7iyya | AM-SI-YA | Tomorrow. |

## 30. Let's go.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | يلا بينا | yalla bina | YALLA BINA | LET'S GO |
| Nile-Chat-4B-promptB | يلا | يالا | yalla | yalla ya3ni yalla |
| Qwen3-4B | ايه ناول | a7 nayl | A-HE NAYL | LET'S GO |
| Qwen3-4B-promptB | اِنْتَهَيْنَا | intahina | INTAH-NA | LET'S GO |

## 31. How much is this?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | كام ده؟ | kam dah? | KAAM DAH? | HOW MUCH IS THIS? |
| Nile-Chat-4B-promptB | كام ده ؟ | كـام ده؟ | kam da? | كم ده؟ |
| Qwen3-4B | كم هذة؟ | kam huzza? | KAM HUZZA | HOW MUCH THIS |
| Qwen3-4B-promptB | مَتَى هَذَا؟ | m3t3 h3z? | M3T3 H3Z? | HOW MUCH IS THIS? |

## 32. That's too expensive.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | ده غالي أوي | da ghalii awi | Da GHALII AWI | This is very expensive |
| Nile-Chat-4B-promptB | ده غالي اوي | ديه غاليه اوى | da ghaly awi | dah ghaley awi |
| Qwen3-4B | هذا مال كثيير | hatha mal kathiir | HAH-THA MAAL KATH-IIR | THIS MONEY TOO MUCH |
| Qwen3-4B-promptB | هذا مال كثيير | hatha mal kathiir | HATHA MAL KATHIIR | THIS MONEY IS MUCH |

## 33. Where is the hotel?

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | فين الفندق؟ | feen el fondok? | Feen el fonduq? | Where is the hotel? |
| Nile-Chat-4B-promptB | فين الفندق؟ | فـين الفنـدق ؟ | feen el fondok? | feen el fondok? |
| Qwen3-4B | ما مكان المبيت؟ | ma maqan al-mabiat | MA MA-QUAN AL-MA-BIAT | WHERE PLACE HOTEL |
| Qwen3-4B-promptB | مَنْ هَيْ لَيْسَ الْمَسْكَوْنَ؟ | m3n h3y l3s al-maskwn? | M3N H3Y L3S AL-MASKUN? | Who is not the hotel? |

## 34. Turn left.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | لف يمين. | lef yemeen. | Lef YEMIN. | Turn right. |
| Nile-Chat-4B-promptB | لف يمين | لڤ يمين | lef yemeen | left turn |
| Qwen3-4B | اكتب يسار | akhtib yasir | A-KHTIB YASIR | WRITE LEFT |
| Qwen3-4B-promptB | اِنْتِبِهِ فَوْقَ يُوْمِكَ | intihil fawq yumik | INTIHIL FAWQ YUMIK | TURN LEFT. |

## 35. Turn right.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | لف يمين | lef yemeen | Lef YEMIN | Turn right |
| Nile-Chat-4B-promptB | لف يمين | لڤ يمين | lef yemeen | left turn |
| Qwen3-4B | اكتب يومن | akhtib yumin | A-KHTIB YU-MIN | TURN RIGHT |
| Qwen3-4B-promptB | اِنْتِصَلْ يُرَيْضَ | intisal yurayd | INT-SAL YURAYD | TURN RIGHT |

## 36. Stop here, please.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | ماتمشيش هنا، لو سمحت. | matmashish hena, law sama7t. | MATMASHISH HENA, LAW SAMAHAT. | MATMASHISH HENA, LAW SAMAHAT |
| Nile-Chat-4B-promptB | وقفة هنا لو سمحت | وقتة هانا لوسمحت | wa2fa hena law samaht | وقفة هنا لو سمحت |
| Qwen3-4B | صُدّق هنا | sud3k hana | S-TOP H-E-RE | STOP HERE |
| Qwen3-4B-promptB | صُدّق هَرِيْ | sud3 hiri | SUD3 HIRI | STOP HERE, PLEASE. |

## 37. I'm tired.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | انا تعبان | ana ta3ban | A-NA TA3BAN | I am TIRED |
| Nile-Chat-4B-promptB | انا تعبان | ana ta3ban | ana ta3ban | ana ta3ban |
| Qwen3-4B | أنا متعب | ana matib | A-NA MA-TIB | I I-AM TIRED |
| Qwen3-4B-promptB | أنا متعب | ana matab | ANA MATAB | I AM TIRED |

## 38. I have a headache.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | عندي صداع | 3ando sada3 | 3ANDO SODA3 | I have a headache |
| Nile-Chat-4B-promptB | عندي صداع | 3andey soda3 | 3andy soda3 | ana 3andy soda3 |
| Qwen3-4B | أنا بآلام في الرأس | ana ba7alim fi al-ras | A-na BA7ALIM FI AL-RAS | I I-have pain in the head |
| Qwen3-4B-promptB | أنا بسأرٗي | na basari | NA BA SARI | I HAVE A HEADACHE |

## 39. I need to rest a little.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | محتاج أريح شوية | me7tag ara7 shwaya | Me7TAG ARAYE7 SHWAYA | ME7TAG ARYEE7 SHWEYA |
| Nile-Chat-4B-promptB | انا محتاج ارتاح شوية | ana me7tag arta7 shwaya | ana me7tag arta7 shwaya | ana me7tag arta7 shwaya |
| Qwen3-4B | أنا بحاجة راحة بليت | ana ba7abat ra7a bleyt | A-na BA7ABAT RA7A BLEYT | I I-need REST A LITTLE |
| Qwen3-4B-promptB | أنا بحاجة إلزوم ريس تليت | ana bha3a 3lzoom rees tli7 | ANA BHA3A 3LZOOM REES TLI7 | I NEED TO REST A LITTLE |

## 40. I'm happy to be here with you.

| model | arabic | arabizi | latin | gloss |
|---|---|---|---|---|
| Nile-Chat-4B | انا مبسوط اني هنا معاك | ana mabsoot eni hena ma3ak | A-NA MABSOOT ENI HEENA MA3AK | I am happy to be here with you |
| Nile-Chat-4B-promptB | أنا مبسوط إني هنا معاك | ana mabsoot eni hena ma3ak | ana mabsout eni hena ma3ak | ana mabsoot eny hena ma3ak |
| Qwen3-4B | أنا سعيد بوجودي هنا معك | ana saeed biwajoodi hana ma3ik | A-NA SAEE-DAY BIWAJOODI HANA MA3IK | I I-AM HAPPY TO BE HERE WITH YOU |
| Qwen3-4B-promptB | أنا سعيد بوجودي هنا معك | ana saeed biwajoodi hana ma3k | ANA SAEEED BIWAJOODI HANA MA3K | I am happy with my presence here with you. |
