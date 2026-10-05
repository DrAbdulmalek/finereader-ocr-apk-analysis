# 07 — جدول الأدلة

مبدأ Harness: كل إدعاء يستهدف دليلًا قابلًا للتحقق. الأدلة أدناه كلها من فحص ساكن للـ APK المحدد بالبصمة أدناه. المسارات نسبية إما إلى داخل حزمة APK أو إلى شجرة فك الترجمة (`jadx_out/sources/`) المحفوظة في أرشيف العمل (غير منشورة لأسباب ملكية).

**APK**: `b4587c0e-111a-4a02-815f-d031a9ec5d25.apk`
**SHA-256**: `ef915243c0dbe5e33cd293e35c0a021b5d555e296782d7c08aa5b7030804f9b1`
**الحجم**: 84,048,171 بايت — **الإدخالات**: 2,112
**أدوات التحليل**: androguard 4.1.4 (manifest)، jadx 1.5.1 (dex، 5,193 صنفًا)، Python zipfile (أصول/مكتبات)

| # | الإدعاء | الدليل |
|---|---|---|
| E01 | الهوية: FineReader Pro 15.2.0.7 (2394)، حزمة `com.abbyy.mobile.finescanner`، minSdk 23/target 29، نشاط إطلاق `SplashActivity` | فك manifest عبر androguard (`scripts/apk_manifest_analysis.py` في أرشيف العمل، ومخرجه `manifest_analysis.json`) |
| E02 | 31 صلاحية، 25 نشاطًا، 24 خدمة، 5 مزودات، 20 مستقبِلًا | نفس مخرجات manifest (§ صلاحيات/أنشطة/خدمات) |
| E03 | محرك OCR أصلي `libMobile.Ocr4.so` 13.39 MB (arm64) + عائلة ABBYY (`FineMachineLearning`, `NeoML`, `NeoMathEngine`, `Mobile.Imaging`, `Mobile.SDK`, `Mobile.Vision`, `FineObj`, `AbbyyZLib`, `PortLayer`, `abbyy-rtr-sdk`, `abbyy-mi-sdk`, `classification-lib`) + `sqlcipher` | سرد `lib/` عبر zipfile — 73 ملفًا عبر 4 ABI |
| E04 | 3 تراخيص ABBYY في الأصول | `assets/MCRD-0100-0006-*.ABBYY.License` (3 ملفات) |
| E05 | نماذج التعرف: `European.rom` (1,684 KB)، `ChineseJapanese.rom` (12,047 KB)، `KoreanSpecific.rom` (5,364 KB)، `FindText.rom` (196 KB) | `assets/patterns/` |
| E06 | مصنفات CNN/ML: `ImageTypeClassifierMobile(Mnv3).cnnmodel`، `TextNotTextClassifier(Mnv3).cnnmodel`، `CropClassifierPhoto.imodel`، `DIQClassifier.imodel`، `DIQBlockClassifier.imodel`، `FastCrop.imodel` | `assets/patterns/` |
| E07 | 24 قاموسًا إملائيًا (.edc) بينها `English.edc`، **ولا قاموس عربي** | `assets/dictionaries/` (قائمة كاملة في doc 02 §3) |
| E08 | الإنجليزية محلية كاملة: أنماط + قاموس | `RecognitionLanguage.java`: `English("English", true)` |
| E09 | العربية غير متاحة محليًا في هذا البناء | `RecognitionLanguage.java`: `Arabic(false, false)` — علمتا `isAvailableInFastMode/InAccurateMode` = false؛ ولا API تنزيل باقات (بحث `download.*[Ll]anguage` فارغ) |
| E10 | دعم العربية في واجهة RTR الحية + صفحات ترميز عربية في النواة | `com/abbyy/mobile/rtr/Language.java` يعلد `Arabic`؛ `RecognitionConfiguration.CodePage`: `ARABIC(1256)`, `ARABIC_ISO(28596)` |
| E11 | بنية النتيجة تدعم RTL وإحداثيات أحرف | `ocr4/layout/MocrTextLine.java`: حقول `_isRTL`, `_characters`, `_wordsInfo`, `_rect`, `_quadrangle`, `_baseLine` |
| E12 | نطاقات عدم الثقة بالأحرف | `interactor/ocr/offline/UncertainCharRange.java` (بداية/طول) + `RawToSafeOcrResultConverter` + `SafeOcrResultFormatter` |
| E13 | خيارات التكوين: FAST/FULL، FMA_*، أعلام ImageProcessingOptions، مستويات ثقة 0-4، TextType (Normal/Matrix/OCR_A/OCR_B/MICR/Receipt)، 22 نوع باركود، `unknownLetter='^'`، أنماط مستخدم | `ocr4/RecognitionConfiguration.java` |
| E14 | دورة المحرك: `createInstance(context, dataSources, license, dataFilesExtensions)`، `getRecognitionManager(config)`، `getFrameMerger()`، توفر OCR/BCR، تحقق RSA | `ocr4/Engine.java` + `RsaSignatureValidator.java` + `RtrContainer/RtrToken` |
| E15 | الخادم السحابي الإنتاج: `https://webapi.finereaderonline.com`؛ التجربة: `webapi-stage.frol-stage.abbyy.com` | `frol/rest/EndPointProvider.java`، `frol/rest/RecognitionServiceEnv.java` |
| E16 | نقاط النهايات الست (Tasks/TaskSources) والمعاملات (`ResultFileType`, `IsFreeQueue`, `ResultName`, `UserId`, `User-Agent`) | `frol/rest/RecognitionServiceApi.java` |
| E17 | 12 صيغة نتيجة: Rtf/Doc/Docx/Xls/Xlsx/Text/Pptx/Odt/Pdf/Pdfa/Fb2/Epub | `frol/domain/ResultFileType.java` |
| E18 | وضعا OCR صريحان | `ui/presentation/ocr/OcrMode.java`: `ONLINE, OFFLINE` |
| E19 | تصنيف اللغات السحابية: FORMAL/NATURAL/FRAKTUR/CONSTRUCTED | `data/entity/languages/OnlineLanguage.java` (`LanguageType`) |
| E20 | طبقات إدارة اللغات: LanguagesInteractor + Offline/Online Interactors/Repositories | `interactor/languages/*`, `data/repository/languages/*` |
| E21 | PDF-صور محلي | `imaging/PdfOperation.java` |
| E22 | معالجة مسبقة: كشف حواف + تصحيح منظور + قص + فلاتر | `imaging/crop/` (`AutoCropImageOperation`, `RecognizeEdgesOperation`, `TransformPerspectiveOperation`, `CropDownsampler`)، `imaging/filter/` (Grayscale/BlackAndWhite/Color) |
| E23 | RTR الحي: TextCapture/DataCapture/ImageCapture + مخططات بيانات | حزمة `com/abbyy/mobile/rtr/` (Engine, CaptureService, CoreAPI interfaces) |
| E24 | قاعدة بيانات مشفرة | `libsqlcipher.so` + مرجع `sqlcipher` في الكود (رابط zetetic.net للرخصة) |
| E25 | مكدس العرض: Moxy + Toothpick + RxJava2 + Retrofit 1.x + Room + WorkManager | حزم `moxy/`, `toothpick/`, مصانع `__Factory`, `throws RetrofitError` في واجهات REST، `androidx.room.MultiInstanceInvalidationService` |
| E26 | تسويق/قياس: AppsFlyer + Branch + OneSignal (+HMS) + Firebase/Crashlytics + Google Analytics + Marketo | manifest (مستقبِلات/خدمات) + `marketo/` + نهايات `requestsender2.abbyy.com/marketo/` |
| E27 | تصدير سحابي إلى Drive | حزمة `com/abbyy/mobile/cloud/` (`CloudSignInInteractor`, `GoogleDriveStorageRepository`, `CloudProvider`, `CloudUploadBroadcastReceiver`) |
| E28 | سكوب التخزين 29: مشاركة عبر FileProvider | `utils/sharing/SharingFileProvider` + `CustomFineScannerContentProvider` |
| E29 | إدارة ذاكرة صور صريحة | `imaging/OutOfMemoryException.java`, `imaging/filter/StatefulBitmapLruCache.java`, `CropDownsampler.java` |
| E30 | 5,193 صنفًا مفكوكًا، 5 أخطاء فك | سجل jadx 1.5.1 (أرشيف العمل) |

## أدلة عامة (ويب) — مضافة مع doc 09 (تحقق 2026-10-05)

هذه الأدلة خارج فحص الـ APK الساكن: مصادر عامة منشورة، تحقق منها البحث الآلي + قراءة مباشرة بتاريخ 2026-10-05. تخدم doc/09 (دراسة الخوارزميات القانونية).

| # | الإدعاء | الدليل |
|---|---|---|
| E31 | ADRT (Adaptive Document Recognition Technology): معالجة المستند متعدد الصفحات **ككيان واحد** لا صفحات منفصلة — توحيد الرؤوس/التذييلات وتسلسل القراءة | help.abbyy.com — مسرد ABBYY الرسمي (مدخل ADRT) |
| E32 | براءات ABBYY Development Inc. في فئة تقطيع الحروف/الكلمات — من المخترعين الموثقين Mikhail Lanin وStanislav Semenov؛ السجل يعرض أرقامًا من الفئة منها 12,160,639 | patents.justia.com — صفحة المسند abbyy-development-inc |
| E33 | عائلة براءة «Method and system for machine-based extraction and interpretation of textual information» — Applicant: ABBYY INFOPOISK LLC / Assignee: ABBYY PRODUCTION LLC | paperdigest.org — سجل البراءة |
| E34 | إعلان ABBYY (فبراير 2026): 22 براءة جديدة خلال سنتين في توثيق الذكاء الاصطناعي، منها «Extracting Multiple Documents from a Single Image» و«Detecting Fields in Document Images» | itbrief.news + industryanalysts.com (إعلانات منشورة) |
| E35 | فوز ABBYY في دعوى انتهاك براءات ضد Nuance (محلفون: لا انتهاك لبراءات التقنية) — دليل محفظة براءات فعلية | prnewswire.com — بيان صحفي |
| E36 | FineReader Engine 12 SDK متاح لـ Windows/Linux/OS X — بوابة ترخيص المطورين/OEM الرسمية (المحرك + بيانات اللغات) | static3.abbyy.com (بيان المنتج الرسمي) + abbyy.com/ocr-sdk |

## حدود الأدلة

- كل الأدلة **ساكنة**؛ لم يُنفذ التطبيق ولم تُعترض أي حركة شبكة.
- سلوك الخادم السحابي من الجهة الأخرى خارج نطاق الإثبات (doc 04 §4).
- الأحجام هي أحجام الملفات غير المضغوطة داخل الحزمة كما يبلغها `zipinfo`.
- شجرة فك الترجمة والسكربتات محفوظة محليًا في أرشيف العمل ولا تُنشر في هذا المستودع (احترام حقوق الملكية — انظر NOTICE.md).
