# 04 — بروتوكول خدمة التعرف السحابية (webapi.finereaderonline.com)

## 1. البنية العامة

طبقة REST مبنية على Retrofit 1.x في `com.abbyy.mobile.finescanner.frol` (اسم الحزمة فروال = FineReader Online تاريخيًا). نقطتا وصول معروفتان في الكود:

- الإنتاج: `https://webapi.finereaderonline.com` (عبر `EndPointProvider`)
- التجربة: `http://webapi-stage.frol-stage.abbyy.com` (مرجع متبقٍ في `RecognitionServiceEnv`)

المصادقة عبر `FineReaderAuthenticator` + `RecognitionServiceAccountApi` + `AccessToken`/`TokenFormatter` — نمط رمز وصول يُجدد عند الانتهاء. كل الطلبات تحمل `UserId` كمعامل استعلام، و`User-Agent` يُمرر يدويًا في إنشاء المهمة.

## 2. دورة حياة المهمة (نمط Tasks)

الواجهة `RecognitionServiceApi` تعلن ست نقاط نهاية تكمل بعضها:

| # | الطلب | الغرض |
|---|---|---|
| 1 | `POST /Tasks` (FormUrlEncoded) | إنشاء مهمة تعرف: يُرسل `ResultFileType` (الصيغة)، `ResultName`، `IsFreeQueue` (طابور مجاني أم مدفوع)، و`FieldMap`ان (خريطتا حقول حرة — من المحتمل: اللغات المختارة وخيارات الإخراج/الصفحات) |
| 2 | `POST /TaskSources` (Multipart) | رفع صفحة/ملف مصدر إلى المهمة: `Filename` + `FileContent` (رفع Streaming عبر TypedFile) |
| 3 | `GET /TaskSources` | سرد مصادر المهمة (للتحقق من الرفع ومزامنة الحالة) |
| 4 | `DELETE /TaskSources/{TaskSourceId}` | حذف مصدر (سماح المستخدم باستبعاد صفحة قبل المعالجة) |
| 5 | `GET /Tasks` | استطلاع حالة المهام (قائمة `RecognitionTasks`) |
| 6 | `GET /Tasks/{TaskId}/Result` (Streaming) | تنزيل ملف النتيجة النهائي بالصيغة المطلوبة |

خطوات التشغيل كما تظهر في `RecognitionServerSyncService` (خدمة خلفية) وآلة حالات شاشة OCR (`OnlinePreSendState` وما بعدها):

```
اختيار الصيغة واللغات → فحص شبكة/حصة/اشتراك → POST /Tasks
  → رفع كل صفحة POST /TaskSources (صفحة-صفحة)
  → الاستطلاع الدوري GET /Tasks (WorkManager/خدمة مزامنة)
  → عند الجاهزية: GET /Tasks/{id}/Result (تنزيل تدفقي)
  → حفظ في مستند التطبيق → فتح ExportActivity
```

نقاط التصميم الجديرة بالتقدير:

- **`IsFreeQueue`**: خادم يفرق بين طابور مجاني (بطيء) ومدفوع (أولوية) — نفس الفكرة القابلة للتطبيق في أي خدمة معالجة لدينا.
- **رفع صفحة-صفحة مع حذف فردي**: يسمح بإلغاء صفحات فاشلة دون إعادة رفع المستند كاملًا.
- **استطلاع وليس push**: لا ويبهوك؛ الخدمة الخلفية تستطلع دوريًا (متوافق مع قيود أندرويد على البطاريات عبر WorkManager).
- **تنزيل Streaming**: الملفات الكبيرة (PDF/EPUB) لا تمر بالذاكرة كاملة.

## 3. صيغ النتائج الاثنتا عشرة (`ResultFileType`)

كل صيغة تحمل الامتداد المرافق في نفس التعداد:

| الصيغة | الامتداد | استخدامها النموذجي |
|---|---|---|
| Rtf | .rtf | مستند منسق قابل للتحرير عالميًا |
| Doc / Docx | .doc / .docx | Microsoft Word (قديم/حديث) |
| Xls / Xlsx | .xls / .xlsx | جداول (التعرف يحافظ على بنية الجدول) |
| Text | .txt | نص خام |
| Pptx | .pptx | PowerPoint (صفحة-شريحة) |
| Odt | .odt | OpenDocument (LibreOffice) |
| Pdf | .pdf | PDF — مع طبقة نص قابلة للبحث |
| Pdfa | .pdfa | PDF الأرشيفي (ISO 19005) |
| Fb2 | .fb2 | كتب إلكترونية XML |
| Epub | .epub | كتب إلكترونية إعادة التدفق |

ملاحظتان: (أ) كل هذه الصيغ تُنتج **سحابيًا** — الجهاز لا يملك محولات DOCX/EPUB. (ب) PDF البسيط من صور فقط (بدون طبقة نص) يُبنى **محليًا** عبر `PdfOperation` في حزمة imaging — أي أن PDF-صور لا يحتاج شبكة، بينما PDF-قابل-للبحث سحابي.

## 4. ما لا نعرفه (حدود التحليل الساكن)

أمانة التوثيق تتطلب الفصل بين المُثبت والمفترض:

- **مُثبت ساكنًا**: أسماء النقاط، المعاملات المرسلة، وجود الطابور المجاني، الصيغ الاثنتا عشرة، عنوان الإنتاج والتجربة.
- **غير مُثبت** (يتطلب اعتراض حركة فعلية): استجابات الخادم الفعلية، تنسيق حقول `FieldMap` بالضبط (اللغات تُرسل بأي معرفات؟)، آلية تجديد الرمز، حدود الحصة اليومية بالأرقام، سلوك الطابور.
- أي تجربة إرسال طلبات حقيقية إلى نهايات ABBYY من خارج التطبيق **خارج نطاق هذا التحليل** ولا يُوصى بها (شروط الخدمة).

## 5. عناصر سحابية مساندة أخرى

- **تصدير تخزين سحابي**: حزمة `com.abbyy.mobile.cloud` — تسجيل دخول Google (`CloudSignInInteractor`, `GoogleSignInDataRepository`) ورفع الملفات (`CloudStorageInteractor`, `GoogleDriveStorageRepository`, `FileConverter`)، مع `CloudProvider` (FileProvider) و`CloudUploadBroadcastReceiver` لرفع تلقائي (إعدادات "Auto-export → Cloud" في `ui/presentation/settings/autoexport/Cloud`).
- **خدمات المحتوى المحدودة**: `ContentService` (حفظ/حذف مستندات ووسوم محليًا) — ليست سحابية رغم اسمها.
- **التشفير**: قاعدة بيانات المستندات عبر SQLCipher — أي أن الصفحات والمعلومات الوصفية مشفرة على القرص، وهو إجراء مناسب لمستندات قد تكون حساسة.
