# 02 — معمارية محرك OCR الأصلي والترخيص والنماذج

## 1. الطبقات الأربع للمكتبات الأصلية

كل المنطق التعريفي يعيش في مكتبات أصلية (C++/NDC) لكل معمارة من المعمارات الأربع. لاحظ أن أسماء المكتبات تكشف تقسيمًا معماريًا دقيقًا:

| المكتبة (حجمها على arm64) | الطبقة |
|---|---|
| `libMobile.SDK.so` (0.40 MB) | واجهة SDK العليا — إنشاء المحرك وإدارة الرخصة للطبقة الجافية |
| `libabbyy-rtr-sdk.so` + `libabbyy-mi-sdk.so` (0.13+0.08 MB) | غلاف RTR (Real-Time Recognition) — التعرف الحي فوق معاينة الكاميرا |
| `libMobile.Ocr4.so` (13.39 MB) | **قلب OCR** — نماذج التعرف، التقسيم، فك الترميز، بنية المستند |
| `libMobile.Imaging.so` (4.58 MB) | معالجة الصور: ثنائية (binarization)، إزالة الميل، تصحيح المنظور، قص |
| `libMobile.Vision.so` (0.26 MB) | رؤية حية خفيفة (كشف الحواف/المستند في المعاينة) |
| `libFineMachineLearning.so` (2.34 MB) + `libFineMachineLearningExt.so` (0.67 MB) | تعلم آلي خاص بـ FineReader (تصنيفات كتل، جودة صورة) |
| `libNeoML.so` (2.07 MB) + `libNeoMathEngine.so` (1.84 MB) + `libExtraNeoML.Dnn.so` (0.28 MB) | إطار NeoML (مفتوح المصدر من ABBYY على GitHub) للشبكات العصبية — يشغل مصنفات `.cnnmodel` |
| `libFineObj.so` (0.73 MB) | مكتبة كائنات أساسية مشتركة (FineObj) |
| `libAbbyyZLib.so` (0.33 MB) | ضغط بيانات خاص بـ ABBYY (نسخة معدلة من zlib) |
| `libPortLayer.so` (0.47 MB) | طبقة توافق منصات (ملفات/خيوط/ذاكرة) |
| `libclassification-lib.so` (0.07 MB) | مساعد التصنيفات |
| `libc++_shared.so` (0.94 MB) | وقت تشغيل C++ المشترك |
| `libsqlcipher.so` (3.48 MB) | قاعدة بيانات مشفرة (SQLCipher) للمستندات والبيانات الوصفية |
| `libAppIds.so` (0.21 MB) | معرّفات تتبع التطبيقات (تحليلات) |

الاستنتاج المعماري: ABBYY تفصل بين **التعرف** (Ocr4) و**الصورة** (Imaging) و**التعلم الآلي** (NeoML) و**الرؤية الحية** (Vision) — وهذا تقسيم نستطيع محاكاته في مشاريعنا (doc 06).

## 2. واجهة المحرك من الجافا: حزمة `com.abbyy.mobile.ocr4`

غلاف جافا رفيع يكشف دورة الحياة الكاملة:

- `Engine.createInstance(context, dataSources, license, dataFilesExtensions)` — إنشاء وحيد (Singleton عبر `getInstance()`)، ثم `initialize(context)` أصلي.
- **مصادر البيانات**: `DataSource` بنمطين `AssetDataSource` (من أصول APK) و`DirectoryDataSource` (من مجلد — وهو المسار الذي تُستخدم به أي ملفات بيانات إضافية). كل لغة تحتاج ملفات بثلاث امتدادات عبر `DataFilesExtensions`: **نماذج أنماط (patterns)** و**قواميس (dictionaries)** و**كلمات مفتاحية (keywords)** — إضافة إلى قواميس ترجمة اختيارية (تظهر امتداد رابع للقواميس الترجمانية).
- `getRecognitionManager(RecognitionConfiguration)` — يبني مدير تعرف لكل تكوين (لغة، وضع، خيارات).
- `getFrameMerger()` — دمج الإطارات: يأخذ عدة إطارات من الكاميرا ويدمجها في صورة أفضل دقة قبل التعرف (خوارزمية تثبيت/تجميع).
- `isLanguageAvailableForOcr()` / `isLanguageAvailableForBcr()` — تفرق بين توفر لغة للـ OCR الكامل مقابل التعرف على بطاقات العمل (BCR).
- `RsaSignatureValidator` + `RtrContainer`/`RtrToken` — تحقق توقيع RSA على حاويات الترخيص قبل السماح بأي عملية تعرف؛ فشل الترخيص يرمي `Engine.LicenseException`.
- `openDataFile(name)` — قراءة ملفات النماذج عبر المصادر المكونة (يعمل مع أصول مشفرة/مضغوطة بصيغة ABBYY الخاصة).

## 3. ملفات الترخيص والنماذج داخل الأصول (41 أصلًا)

### تراخيص (3 ملفات)
`assets/MCRD-0100-0006-*.ABBYY.License` — ثلاث حاويات ترخيص بأرقام تسلسلية، تُقرأ كـ `License` ويُتحقق توقيعها RSA محليًا (التحقق لا يتصل بالإنترنت — لذا تعمل الميزات المحلية دون شبكة).

### نماذج التعرف (.rom — مجلد `assets/patterns/`)
| الملف | الحجم | الغرض |
|---|---|---|
| `European.rom` | 1,684 KB | نماذج الأبجديات اللاتينية والسيريلية (تشمل الإنجليزية والروسية و24 لغة أوروبية) |
| `ChineseJapanese.rom` | 12,047 KB | الصينية المبسطة/التقليدية واليابانية |
| `KoreanSpecific.rom` | 5,364 KB | الكورية (هانغل/هانجا) |
| `FindText.rom` | 196 KB | نموذج العثور على النص في الصورة (للبحث عن مناطق النص قبل التعرف، وميزة "العثور على النص" الحية) |

### مصنفات تعلم آلي (تشغّلها NeoML)
| الملف | الحجم | الغرض المستنتج |
|---|---|---|
| `ImageTypeClassifierMobile.cnnmodel` | 1,058 KB | تصنيف نوع الصورة (مستند ماسوح/صورة عادية/لقطة شاشة…) — نسخة CNN |
| `ImageTypeClassifierMobileMnv3.cnnmodel` | 933 KB | النسخة الأحدث بعمود MobileNetV3 (أخف وأدق) |
| `TextNotTextClassifier.cnnmodel` + نسخة Mnv3 | 2,161 + 1,957 KB | ثنائي "نص/غير نص" لكتلة ما — يقرر هل تستحق الكتلة التعرف |
| `CropClassifierPhoto.imodel` | 63 KB | تصنيف حواف القص: هل الحافة المستكشفة مستند أم صورة |
| `DIQClassifier.imodel` + `DIQBlockClassifier.imodel` | 317 + 309 KB | **DIQ = Document Image Quality**: تقييم جودة صورة المستند (إضاءة، ضبابية، ظل) قبل/بعد المعالجة |
| `FastCrop.imodel` | 150 KB | كشف سريع لحدود المستند في المعاينة الحية |

### قواميس إملائية (.edc — مجلد `assets/dictionaries/`)
24 قاموسًا لغويًا لتصحيح ما بعد التعرف (استبدال كلمات غير موجودة بقريب إملائي): `English.edc` (231 KB)، `Russian.edc` (832 KB)، `German.edc` + `GermanNS.edc` (تخليط قديم/جديد)، `French`، `Spanish`، `Italian`، `Turkish`، `Polish`، `Dutch` + `Flemmish`، `Swedish`، `NorwBok` + `NorwNyn`، `Danish`، `Finnish`، `Czech`، `Bulgar`، `Greek`، `Eston`، `Ukrain`، `Portug`، `Brazil`، `Indones`.

**اللافت: لا يوجد قاموس عربي `Arabic.edc`** — متسق مع أن العربية غير متاحة في وضع التعرف المحلي لهذا البناء (doc 03).

### أصول أخرى
`typeface/helios_cond_black.ttf` — خط خاص لواجهات العرض، و`org/threeten/bp/TZDB.dat` — قاعدة مناطق زمنية.

## 4. غلاف RTR الحي: حزمة `com.abbyy.mobile.rtr`

واجهة منفصلة تمامًا عن OCR الدفعي، تعمل فوق بث الكاميرا:

- `Engine/EngineImpl` — نسخة RTR من المحرك، مع `FileLicense` و`Protection`.
- ثلاث خدمات التقاط: `TextCaptureService` (نص حي فوق المعاينة)، `DataCaptureService` + `DataSchemesListings` (التقاط حقول وفق مخططات: أرقام هواتف، IBAN، بطاقات عمل…)، `ImageCaptureService` (التقاط صورة مستند مع كشف الحواف الحي).
- كل خدمة تُبنى عبر نمط Builder (`DataCaptureProfileBuilder`) وتقبل `Language` (تعداد من ~78 لغة يضم `Arabic` — أي أن **التعرف الحي على العربية مدعوم بواجهة SDK** حتى لو كانت الجلسة الكاملة تتطلب بيانات إضافية).
- واجهات النواة: `IRecognitionCoreAPI`، `IImagingCoreAPI`، `IDataCaptureCoreAPI` — الطبقة الأصلية تُستدعى من الجافا عبر JNI بنفس أسماء الحقول (`_isRTL` في النتائج مثال).

## 5. لماذا هذا التصميم مهم؟

- **التعريف عند التحميل**: `Engine` يتحقق من الرخصة قبل أي استخدام؛ الرخص موقعة محليًا — لا اتصال — لكن الوضع السحابي يتحقق من حصص الخادم (doc 04).
- **البيانات على الطلب**: امتداد `DirectoryDataSource` يعني أن النماذج يمكن أن تضاف لاحقًا إلى مجلد — لكن هذا البناء لا يتضمن كود تنزيل باقات (بحث `download.*language` فاضي) — إذن قائمة اللغات المحلية ثابتة ما عدا ما يوفره الخادم عبر مسار المهام (نتائج سحابية).
- **الملكية الفكرية محمية بطبقتين**: توقيع RSA على الرخصة، وصيغ ملفات خاصة (.rom/.edc/.imodel غير موثقة علنًا).
