# 01 — هوية التطبيق وبنية حزمة APK

## 1. بطاقة الهوية

استُخرجت كل القيم أدناه من فك `AndroidManifest.xml` الثنائي عبر androguard (البرنامج النصي `scripts/extract_manifest.py` في أرشيف العمل):

- **الاسم المعروض**: FineReader Pro — الاسم الداخلي للأصول يكشف أن التطبيق هو التطور المباشر لـ FineScanner (أصناف `com.abbyy.mobile.finescanner.*` وأصناف معرض الصور `FSAGalleryActivity` تحمل الاسم القديم).
- **الحزمة**: `com.abbyy.mobile.finescanner`.
- **نشاط الإطلاق**: `com.abbyy.mobile.finescanner.ui.SplashActivity` ثم `CustomMainActivity` (نسخة مخصصة مع توابع `Custom*` تعني تعديلات بناء فوق هيكل مشترك).
- **الإصدار**: 15.2.0.7 / versionCode 2394.
- **حدود SDK**: الأدنى 23 (أندرويد 6.0 مارشميلو)، المستهدف 29 (أندرويد 10). استهداف 29 يعني تخزينًا محدودًا عبر Scoped Storage — ولهذا يوجد `SharingFileProvider` من نوع FileProvider لمشاركة الملفات مع التطبيقات الأخرى.

## 2. بنية الحزمة (2,112 عنصرًا)

التوزيع الحجمي للمجلدات كما فحصناه عبر `zipfile`:

| المجلد | العدد | الدور |
|---|---|---|
| `res/` | 1,459 | موارد الواجهة (رسوم، تخطيطات، نصوص مترجمة) |
| `kotlin/`, `androidx/`, `moxy/`, `toothpick/` | 300+ | مكتبات منصات: Kotlin stdlib، AndroidX، Moxy (MVP)، Toothpick (DI) |
| `org/` | 131 | threetenbp (تواريخ) وأخرى |
| `lib/` | 73 | المكتبات الأصلية لـ 4 معمارات (تفصيل في doc 02) |
| `assets/` | 41 | تراخيص ABBYY + نماذج + قواميس (تفصيل في doc 02) |
| `META-INF/` | 58 | توقيعات وبصمات |
| ملفات `.properties` | ~30 | إعلانات اعتماديات Firebase/Play Services |

ملفّا كود `classes.dex` (8.2 MB) و`classes2.dex` (3.3 MB) — 11.5 MB من البايتكود، أي تطبيق كبير الحجم تفسيرًا لدمج محرك OCR الكامل محليًا.

## 3. الصلاحيات (31 صلاحية)

الصلاحيات تنقسم إلى خمس مجموعات وظيفية:

1. **كاميرا وتصوير** (جوهر المسح): `CAMERA`، `FLASHLIGHT`.
2. **شبكة** (للوضع السحابي): `INTERNET`، `ACCESS_NETWORK_STATE`، `ACCESS_WIFI_STATE`.
3. **تخزين** (استيراد/تصدير): `READ_EXTERNAL_STORAGE`، `WRITE_EXTERNAL_STORAGE`.
4. **خدمات خلفية وإشعارات**: `FOREGROUND_SERVICE`، `WAKE_LOCK`، `RECEIVE_BOOT_COMPLETED`، `VIBRATE` + صلاحيات C2D الخاصة بـ Firebase Cloud Messaging.
5. **شارات الإشعارات لأشركاء التصنيع** (11 صلاحية): صلاحيات `UPDATE_BADGE`/`READ_SETTINGS` لأنظمة هواتف HTC وSony وOppo وHuawei وSamsung — من مكتبة Badgeount، لا وظيفة OCR لها.
6. **فوترة**: `com.android.vending.BILLING` (اشتراكات Play Billing — يوجد `ProxyBillingActivity`).

ملاحظة أمان: لا صلاحيات موقع جغرافي ولا جهات اتصال — التطبيق مقيد بالحد الأدنى الوظيفي في هذا الجانب.

## 4. المكونات المعلنة (Activities / Services / Providers / Receivers)

### الأنشطة الوظيفية (25 نشاطًا، منها 15 نشاطًا للمنتج)

| النشاط | الدور |
|---|---|
| `ui/view/activity/OcrActivity` | شاشة OCR (آلة الحالات في `ui/presentation/ocr/state/`) |
| `ui/view/activity/export/ExportActivity` | شاشة التصدير (12 صيغة) |
| `ui/imaging/CustomTakePictureActivity` | التصوير بكاميرا ABBYY المخصصة |
| `ui/imaging/CropImageActivity` | القص اليدوي |
| `ui/imaging/CustomImageEditorActivity` | محرر الصورة (فلاتر/تدوير) |
| `ui/imaging/ImportImagesActivity` | استيراد صور من المعرض |
| `ui/documents/DocumentPropertiesActivity` | خصائص المستند |
| `ui/pages/PagesActivity` | إدارة صفحات المستند |
| `ui/gallery/FSAGalleryActivity` | معرض المستندات |
| `ui/tags/TagsActivity` | الوسوم |
| `ui/settings/SettingsActivity` | الإعدادات |
| `ui/promo/AboutActivity` + `OnboardingActivity` | التعريف والتهيئة الأولى |
| `ui/gdpr/GdprActivity` / `GdprNewUserActivity` | موافقات الخصوصية (GDPR) |
| `ui/developer/DeveloperPrefsActivity` | إعدادات مطور (مخفية) |
| معرض صور النظام: `BucketImagePreviewActivity` | معاينة متعددة الصور |

### الخدمات (24 خدمة، منها 3 لمنتج ABBYY)

- `frol.RecognitionServerSyncService` — التزامن مع خادم التعرف السحابي (frol = FineReader Online تاريخيًا).
- `service.ContentService` — إدارة محتوى المستندات والوسوم محليًا (حفظ/حذف/وسوم).
- `service.FilesService` — عمليات الملفات الخلفية.
- بقية الخدمات من المنصات: WorkManager (4)، Firebase/FCM (6)، OneSignal (6)، Google Analytics (4)، Datatransport (2).

### المزودات والمستقبِلات

- `CustomFineScannerContentProvider` — كشف المستندات لتطبيقات أخرى.
- `utils.sharing.SharingFileProvider` — مشاركة آمنة عبر content:// (مطلب targetSdk 29).
- `com.abbyy.mobile.cloud.content.CloudProvider` — مزود ملفات حزمة السحابة.
- `CloudUploadBroadcastReceiver` — رد فعل لأحداث رفع تلقائي.
- مستقبِلات تسويقية/قياس: AppsFlyer (`MultipleInstallBroadcastReceiver`)، Branch (`InstallListener` — الروابط العميقة)، Google Analytics/CampaignTracking.

## 5. البصمة التقنية للمكتبات الخارجية

كشف فك الترجمة هذه الاعتماديات (بترتيب أهميتها):

- **Moxy** (MVP لـ أندرويد، من Arello-Mobile) — نمط العرض في كل الشاشات.
- **Toothpick** — حقن الاعتماديات (كل صنف مصنع `__Factory`).
- **RxJava 2 + RxAndroid** — تدفقات غير متزامنة (كل Interactor يعيد `Observable`).
- **Retrofit 1.x** (لاحظ `throws RetrofitError` — إصدار قديم) + OkHttp — لطبقة REST السحابية.
- **Room** — قاعدة بيانات المستندات/الصفحات، لكن مع **SQLCipher** (`libsqlcipher.so`) أي قاعدة مشفرة بالكامل على القرص.
- **Glide** + **android-gpuimage** — تحميل الصور وفلاتر GPU.
- **GestureViews** (alexvasilkov) — عرض الصور بالتكبير/السحب في العارض (نفس المكتبة المستخدمة في عارضات المستندات الشهيرة).
- **threetenbp** — تواريخ JSR-310 للأنظمة القديمة.
- **Cicerone** — ملاحة بين الشاشات.
- **android-advancedrecyclerview** (h6ah4i) — قوائم متقدمة (سحب/تمييز).
- **تتبع وتسويق**: Firebase Analytics + Crashlytics، Google Analytics (الإصدار القديم gms.analytics)، AppsFlyer، Branch، OneSignal (إشعارات)، Marketo (تسويق بريدي — وُجدت نهايات `marketo` و`requestsender2.abbyy.com`).
- **Play Billing** — اشتراكات.

هذه البصمة مهمة لفهم حدود أي استنساخ: نصف تعقيد التطبيق ليس OCR بل إدارة مستندات + تسويق + فوترة + خصوصية.
