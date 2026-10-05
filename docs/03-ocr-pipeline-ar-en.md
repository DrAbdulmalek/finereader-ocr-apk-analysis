# 03 — خط أنابيب OCR للعربية والإنجليزية خطوة بخطوة

هذا الملف يجيب على السؤال الجوهري: *كيف يتعرف التطبيق على العربية والإنجليزية؟* الوصف أدناه مبني على قراءة ساكنة لأصناف `com.abbyy.mobile.ocr4` (غلاف المحرك)، `com.abbyy.mobile.finescanner.imaging` (المعالجة)، `com.abbyy.mobile.finescanner.interactor.ocr` (المنطق)، و`com.abbyy.mobile.finescanner.ui.presentation.ocr` (آلة الحالات).

## 1. نظرة عامة: مساران للتعرف

التطبيق يعرّف تعدادًا صريحًا `OcrMode { ONLINE, OFFLINE }`، وكل مستند يمر بأحد المسارين بحسب: اللغات المختارة، توفر الشبكة، حالة الاشتراك/الحصة:

```
صفحة صورة (JPEG من الكاميرا أو الاستيراد)
   │
   ├─ مسار OFFLINE (محلي): المعالجة → Engine/Ocr4 → MocrDocument → تنسيق آمن + نطاقات عدم ثقة → عرض/تصدير نصي
   │
   └─ مسار ONLINE (سحابي): رفع صفحات → مهام webapi.finereaderonline.com → استطلاع → تنزيل ملف النتيجة (12 صيغة)
```

## 2. إعداد اللغات: طبقة ثلاثية

1. **طبقة المحرك** (`RecognitionLanguage` في ocr4): كل لغة تحمل أربعة خصائص: `fileName` (ملف الأنماط)، `internalName`، `hasDictionary` (هل يوجد قاموس .edc)، و`isAvailableInFastMode`/`isAvailableInAccurateMode`. الحالات الممكنة:
   - `English("English", true)` — أنماط مضمّنة + قاموس: متاحة محليًا فورًا.
   - `Arabic(false, false)` — **غير متاحة** في الوضعين السريع والدقيق محليًا (لا أنماط مضمنة ولا قاموس).
   - `WestEuropean("WestEuropean", true)` — مجموعة لغات جاهزة تغطي الأوروبية الغربية دفعة واحدة.
   - `Digits`, `Mixed`, `MRZ` — لغات خاصة (أرقام فقط، مختلط، آلي تعريف جوازات روسية).
2. **طبقة العرض** (`OfflineLanguage` / `OnlineLanguage` كيانات Kotlin): تُحوَّل لغات المحرك إلى عناصر واجهة مع أيقونة وإشارة تفعيل. `OnlineLanguage` يضيف `LanguageType { FORMAL, NATURAL, FRAKTUR, CONSTRUCTED }` — تصنيف ABBYY السحابي للغات (رسمية/طبيعية/غوتية Fraktur/مصطنعة كالإسبرانتو).
3. **طبقة التفاعل** (`LanguagesInteractor` + `Offline/Online LanguagesInteractor/Repository`): تدير اختيار المستخدم، والتخزين في تفضيلات، وتُعلم آلة حالات OCR بالوضع المطلوب.

**النتيجة العملية للعربية**: في هذا البناء، اختيار العربية يعمل بالوضع ONLINE حصرًا؛ الإنجليزية تعمل بالوضين معًا. (التعرف الحي RTR يعلد `Arabic` في `com.abbyy.mobile.rtr.Language` — لكن جلسة OCR الكاملة محليًا لا تحتوي أنماط عربية في الأصول.)

## 3. المعالجة المسبقة (imaging) — قبل أي تعرف

سلسلة عمليات على الصورة عبر `ImageProcessor` و`ImageOperationBuilder` و`ChainImageOperation`:

1. **قص/استكشاف حدود**: `AutoCropImageOperation` و`RecognizeEdgesOperation` يكشفان حدود الورقة، ثم `TransformPerspectiveOperation` يستقيمها تصحيحًا رباعي الأضلاع (حذف المنظور). `FastCrop.imodel` يعمل في المعاينة الحية، و`CropClassifierPhoto.imodel` يفرق بين ورقة وصورة. `CropDownsampler` يقلص الحجم قبل القص حفاظًا على الذاكرة (مع صنف `OutOfMemoryException` مخصص).
2. **تحسينات أساسية** (داخل `libMobile.Imaging.so`): ثنائية (binarization) تكيفية، إزالة ميل (deskew)، كشف اتجاه الصفحة، تنظيف الخلفية — تُفعَّل عبر أعلام `ImageProcessingOptions` في التكوين (انظر §5).
3. **فلاتر عرض للمستخدم** (`imaging/filter/`): `ToGrayscaleOperation`، `ToBlackAndWhiteOperation`، `ToColorOperation` عبر GPU (android-gpuimage) — الفلتر يغير الصورة المخزنة وليس مجرد عرض.

## 4. التعرف المحلي (OFFLINE) — كيف يعمل بالضبط

1. يُبنى `RecognitionConfiguration` (تفصيل §5) بلغات المستخدم (مثال: `EnumSet.of(English)`).
2. `Engine.getRecognitionManager(config)` ينشئ `RecognitionManagerImpl` ويمرر التكوين إلى النواة الأصلية.
3. الصورة تُحمّل عبر `ImageLoadingOptions`/`NV21Image` (صيغة خام من الكاميرا مدعومة مباشرة).
4. النواة في `libMobile.Ocr4.so` تنفذ: تحليل تخطيط → تجزئة كتل (نص/جدول/صورة) عبر مصنفات CNN → خطوط → أحرف → فك ترميز مرتب بالسياق والقاموس (لهذا توجد قواميس .edc) → بنية `MocrDocument`.
5. **بنية النتيجة** (دليل إدراك العربية في التصميم):
   - `MocrTextAreaOnPhoto` — منطقة نص مع موقعها على الصورة.
   - `MocrTextLine` — سطر يحمل: النص، قائمة `MocrCharacter` (حرف-بحرف مع إحداثيات)، `MocrWordInfo` (معلومات كلمات)، `Rect` + `Point[] quadrangle` (شبه منحرف السطر)، `_baseLine`، و**`_isRTL`** — العلم الذي يجعل عرض السطور العربية بأتيحتها الصحيحة ممكنًا دون تخمين.
   - `FrameMerger`/`FrameMergerResult` — دمج إطارات كاميرا متعددة لرفع الدقة قبل التعرف.
6. **تحويل النتيجة الآمنة**: `RawToSafeOcrResultConverter` + `SafeOcrResultFormatter`/`ParagraphSafeOcrResultFormatter` يعيدان تشكيل النتيجة الخام إلى فقرات جاهزة للعرض، مع `UncertainCharRange` (بداية+طول) لكل نطاق أحرف منخفض الثقة — فيظهر في الواجهة خط منقط/تظليل تحت الأحرف المشكوك فيها (الرسم `res/drawable` يعرض أنماط حالة فشل/معالجة OCR لكل نوع مستند).
7. **تقييم الجودة**: `RecognitionQualityInteractor` يقيّم نتيجة التعرف (استنادًا لمستويات الثقة) ويغذي تحذيرات "صورة منخفضة الجودة" — مربوط بمخرجات مصنفات DIQ (doc 02 §3).
8. `ImageRotation` يعالج دوران الصفحة/السطر عند العرض، و`ShowRecognition` يدير التدفق التفاعلي أثناء التعرف الحي.

## 5. خيارات التكوين التي تكشف عمق المحرك (`RecognitionConfiguration`)

| المجموعة | القيم | الدلالة |
|---|---|---|
| `RecognitionMode` | `FAST`, `FULL` | سرعة مقابل دقة (نماذج أخف/أثقل) |
| `FindMultipleAreasMode` | `FMA_All`, `FMA_Central`, `FMA_OneZone` | تعرف كل المناطق / الوسطى فقط / منطقة واحدة |
| `ImageProcessingOptions` | `DISABLE_DESKEW`, `DETECT_PAGE_ORIENTATION`, `FIND_ALL_TEXT`, `HAS_CJK`, `IS_EUROPEAN_WITH_SOME_CJK`, `PROHIBIT_VERTICAL_CJK_TEXT`, `DETECT_TEXT_COLOR`, `USE_OLD_BINARIZATION`, `BUILD_WORDS_INFO`, `PREBUILD_WORDS_INFO`, `MICR_MODE` | أعلام بتية تعادل خيارات FineReader المكتبية الكاملة |
| `RecognitionConfidenceLevel` | `LEVEL0..LEVEL4` | عتبات الثقة الخمس |
| `TextType` | `Normal`, `Matrix` (طابعة مصفوفية), `OCR_A`, `OCR_B`, `MICR_E13B`, `MICR_CMC7`, `Receipt` | أنواع خطوط خاصة: شيكات (MICR)، استمارات، إيصالات |
| `CodePage` | UTF8 الافتراضي + **`ARABIC(1256)`** + **`ARABIC_ISO(28596)`** + أخريات | جدول ترميز لفك البايتات — تضمين صفحتين عربيتين يؤكد دعم العربية في النواة |
| `BarcodeType` | 22 نوعًا (QR، PDF417، DATA MATRIX، EAN…، حتى `ANY1D`) | المحرك نفسه يتعرف على الباركودات |
| أخرى | `_unknownLetter='^'`، `_barcodeTypes=1048575` (الكل)، `_detectBarcodeOrientation=true`، مستخدم-نماذج `_userPatternsDataFileName` | الحرف البديل للمجهول، ودعم أنماط مستخدم مدرَّبة (تدريب محدود محليًا!) |

نقطة مهمة لمشاريعنا: `_userPatternsDataFileName` + `UserRecognitionLanguagesSet` تعنيان أن المحرك يقبل **ملفات أنماط مستخدم مخصصة** — أي آلية تدريب رسمية على الخطوط الخاصة، وإن كان واجهة التطبيق لا تعرضها.

## 6. التعرف السحابي (ONLINE) — أين تدخل العربية

1. يختار المستخدم صيغة التصدير (`ResultFileType`) واللغات، وتخزن `DocumentOcrParams` (معرف المستند، اللغات، الصيغة).
2. `OnlinePreSendState` في آلة الحالات يفحص الشبكة (`NetworkStatusImpl`) والاشتراك/الحصة (`RecognitionAccessRepository` + `OnlineOcrSharedPreferences`) ثم يرفع.
3. التدفق: إنشاء مهمة → رفع مصادر (صفحات) → استطلاع دوري (`RecognitionServerSyncService` في خلفية) → تنزيل النتيجة → فتح `ExportActivity`. التفاصيل الكاملة للبروتوكول في doc 04.
4. العربية تُرسل اسم لغتها إلى الخادم الذي يملك نماذجها (الخادم هو محرك FineReader الكامل)، فتعود النتيجة بصيغة مكتملة (DOCX/PDF قابل للبحث…).

## 7. لماذا تفصل ABBYY بين المحلي والسحابي؟ (قراءة استراتيجية)

- **الحجم**: نماذج كل لغة بمئات الكيلوبايتات إلى ميغابايتات؛ تضمين 193 لغة سيمدد APK لأضعاف. الأوروبية الشائعة محلية (سرعة وخصوصية)، والنادرة/الثقيلة سحابية.
- **القيمة التجارية**: OCR السحابي محدود الحصة ومرتبط بالاشتراك (`com.android.vending.BILLING`) — المحرك المحلي "مجاني" بعد الرخصة المدفوعة مسبقًا من ABBYY للمطورين/نفسهم.
- **الجودة**: الخادم يشغل نسخة FineReader الكاملة (جداول، أعمدة، صيغ إخراج احترافية) لا يمكن حشرها في هاتف.
