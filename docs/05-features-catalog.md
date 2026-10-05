# 05 — كتالوج الميزات الكامل

جرد شامل لميزات التطبيق كما ظهرت من المكونات المعلنة، وأصناف الواجهة، وموارد الرسوم (`res/drawable`)، وهياكل البيانات. قسمناها إلى مرئية للمستخدم وبنية تحتية.

## 1. الميزات المرئية للمستخدم

### 1.1 الالتقاط والاستيراد
- **كاميرا مسح مخصصة** (`CustomTakePictureActivity` + `videoautocapture`): كشف حدود مستند حي في المعاينة (`FastCrop.imodel`) مع التقاط تلقائي عند الاستقرار — حزمة `com.abbyy.mobile.videoautocapture` تشير لالتقاط متعدد الإطارات.
- **دمج إطارات**: `FrameMerger` يدمج عدة إطارات من لحظة الالتقاط لرفع الدقة الفعلية وتقليل الضوضاء (ميزة خفية غير معلنة).
- **الوميض**: صلاحية `FLASHLIGHT` — التقاط في الإضاءة المنخفضة.
- **استيراد صور** (`ImportImagesActivity` + معاينة متعددة `BucketImagePreviewActivity`): من المعرض، متعدد الاختيار.

### 1.2 تحرير الصور والصفحات
- قص يدوي وتصحيح منظور (`CropImageActivity`، `TransformPerspectiveOperation`).
- محرر صور (`CustomImageEditorActivity`) بفلاتر: تدرج رمادي، أبيض وأسود، لون (`imaging/filter/`) عبر GPU.
- إدارة صفحات المستند (`PagesActivity`): إعادة ترتيب، حذف، تدوير (نمط `ImageRotation`).
- معرض مستندات (`FSAGalleryActivity`) بخصائص مستند (`DocumentPropertiesActivity`) ووسوم ألوان (`TagsActivity` + `ContentService.ACTION_ADD_TAGS`).

### 1.3 التعرف (OCR) — انظر doc 03 للتفاصيل
- OCR كامل للمستندات بالوضعين المحلي/السحابي (`OcrActivity` + آلة حالات كاملة).
- شاشة حالة لكل مستند: لم يعالج / قيد المعالجة (12 إطار أنيميشن `list_item_document_ocr_status_processing_00..13`) / فشل / نوع النتيجة (أيقونات لكل صيغة: `ic_ocr_result_type_{doc,epub,fb2,odt,pdf,pptx,rtf,txt,xls}`).
- مؤشرا `ic_offline_ocr` / `ic_online_ocr` يوضحان وضع المعالجة، و`ic_ocr_status_downloading` للتنزيلات.
- عرض النتائج مع تظليل الأحرف غير المؤكدة (`UncertainCharRange`) وربط النص بموقع الصورة (`MocrTextAreaOnPhoto`).

### 1.4 التعرف الحي (RTR) والمسح الذكي
- التقاط نص حي من الكاميرا (`TextCaptureService`) — عرض النص أثناء توجيه الكاميرا.
- التقاط بيانات وفق مخططات (`DataCaptureService` + `DataSchemesListings`): قراءة حقول منظمة (بطاقات عمل BCR — المحرك يفصل `getLanguagesAvailableForBcr()`).
- باركودات: 22 نوعًا مدمجة في نفس المحرك (`BarcodeType`).

### 1.5 التصدير والمشاركة
- 12 صيغة سحابية (doc 04 §3) + PDF-صور محلي (`PdfOperation`).
- مشاركة عبر `SharingFileProvider` (content:// آمن) وكشف المستندات لخارج التطبيق (`CustomFineScannerContentProvider`).
- تصدير تلقائي إلى Google Drive (`autoexport/Cloud`, `GoogleDriveStorageRepository`, `CloudUploadBroadcastReceiver`) بعد تسجيل دخول Google.

### 1.6 الحساب والاشتراك والخصوصية
- اشتراكات Play Billing (`ProxyBillingActivity`، حزمة `purchase/`).
- تدفقات GDPR كاملة (`GdprActivity`, `GdprNewUserActivity`) — حذف بيانات/موافقات.
- إشعارات فورية (OneSignal + FCM، حتى دعم HMS للهواتف هواوي `NotificationOpenedActivityHMS`).

### 1.7 تهيئة وتعريف
- Onboarding (`OnboardingActivity`) برسوم تعريفية لكل ميزة (`intro_ocr.png`, `intro_ocr_with_scan.png`...).
- شاشة "حول" (`AboutActivity`) وإعدادات مطور مخفية (`DeveloperPrefsActivity`).

## 2. البنية التحتية غير المرئية

| المجال | التفاصيل |
|---|---|
| **تخزين مشفر** | SQLCipher (`libsqlcipher.so`) فوق Room — المستندات والبيانات الوصفية مشفرة على القرص |
| **خلفيات موثوقة** | WorkManager (قيود شبكة/بطارية)، خدمة أمامية `FOREGROUND_SERVICE` للعمليات الطويلة، `LiveLongAndProsperIntentService` (صنف أساس خاص بهم للخدمات الطويلة) |
| **معمارية العرض** | Moxy MVP + Toothpick DI + RxJava 2 + Cicerone navigation — طبقات MVP/Presentation/Interactor/Repository/Data منضبطة |
| **تحليلات وقياس** | Firebase Analytics + Crashlytics + Google Analytics (قديم) + AppsFlyer (إسناد تثبيت) + Branch (روابط عميقة `deeplinking/`) + Marketo (تسويق بريدي) |
| **إشعارات شارات** | 11 صلاحية شارات لأشركاء الأجهزة (Samsung/Sony/HTC/Oppo/Huawei) عبر مكتبة BadgeCount |
| **تجربة بدون شبكة** | محرك OCR محلي كامل + رخص محلية موقعة RSA = الميزات الأساسية تعمل أوفلاين تمامًا |
| **إدارة ذاكرة** | `CropDownsampler` + `OutOfMemoryException` + `StatefulBitmapLruCache` — إدارة ذاكرة صور صريحة على أجهزة ضعيفة |
| **تعدد المعمارات** | 4 ABI كاملة (arm64-v8a, armeabi-v7a, x86, x86_64) — حتى المحاكيات مدعومة |
| **تعدد اللغات الواجهة** | موارد مترجمة قياسية (res/values-*) |

## 3. ما الذي لا يوجد؟ (سلبيات مفيدة)

- **لا تحويل كلام إلى نص ولا ترجمة داخلية**: لا مكتبات صوت/ترجمة في البصمة (رغم امتداد "قواميس ترجمة" في `DataFilesExtensions` — مخصص لمحرك ترجمة في نسخ SDK أخرى، غير مُستخدم هنا بواجهة).
- **لا توقيع/حماية PDF**: لا صنوف تعديل PDF سوى الإنشاء من صور.
- **لا OCR نباتي بالكامل داخل الجهاز للغات النادرة**: لا آلية تنزيل باقات لغات في هذا البناء (doc 03 §2).
- **لا مزامنة مستندات عبر أجهزة**: السحابة للتصدير فقط، لا مزامنة حالة.

هذه السلبيات مهمة لمن يخطط لمنافس أو استنساخ: نطاق المنتج محكوم بأسباب تجارية وليس تقنية.
