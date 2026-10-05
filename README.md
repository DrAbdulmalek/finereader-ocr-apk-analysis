# تحليل هندسي عكسي لمحرك OCR في ABBYY FineReader Pro (أندرويد)

> توثيق تقني أصلي — تحليل كيفية عمل التعرف الضوئي على الحروف (OCR) للغتين العربية والإنجليزية في تطبيق ABBYY FineReader Pro للاندرويد، مع كتالوج كامل للميزات والدروس القابلة للتطبيق في مشاريعنا.

| البند | القيمة |
|---|---|
| التطبيق | ABBYY FineReader Pro (FineScanner سابقًا) |
| الحزمة | `com.abbyy.mobile.finescanner` |
| الإصدار المُحلَّل | 15.2.0.7 (versionCode 2394) |
| بصمة SHA-256 للـ APK | `ef915243c0dbe5e33cd293e35c0a021b5d555e296782d7c08aa5b7030804f9b1` |
| minSdk / targetSdk | 23 (أندرويد 6.0) / 29 (أندرويد 10) |
| معمارات المعالج | arm64-v8a، armeabi-v7a، x86، x86_64 |
| حجم الـ APK | 84,048,171 بايت (~80.2 MiB) |
| عدد أصناف الكود المفكوكة | 5,193 صنفًا (jadx 1.5.1، 5 أخطاء فك فقط) |

## منهجية التحليل

اعتمدنا منهجية Harness الهندسية المتبعة في كل مشاريعنا: كل إدعاء في هذا التوثيق مُسند إلى دليل قابل للتحقق (اسم صنف، ثابت، مسار API، أو ملف ضمن حزمة الـ APK)، ومجموعة الأدلة مجمّعة في [docs/07-evidence.md](docs/07-evidence.md). لم نعدّل أي ملف في التطبيق، ولم ننفذ الـ APK على أي جهاز — التحليل كله **ساكن (static)** عبر ثلاث أدوات: `androguard 4.1.4` لفك `AndroidManifest.xml`، و`jadx 1.5.1` لفك ترجمة `classes.dex` و`classes2.dex`، و`zipfile` القياسي لفحص الأصول والمكتبات الأصلية. أي شيء لم نتمكن من إثباته ساكنًا (مثل سلوك الخادم السحابي من الجهة الأخرى) أُشير إليه صراحة كافتراض غير مُثبت.

## أهم النتائج (خلاصة تنفيذية)

1. **المحرك أبأي proprietary بالكامل**: قلب التعرف هو مكتبة أصلية `libMobile.Ocr4.so` (13.4 MB على arm64) تعمل فوق عائلة مكتبات ABBYY (`FineMachineLearning`, `NeoML`, `NeoMathEngine`, `Mobile.Imaging`)، وتُرخص عبر حاويات `RtrContainer/RtrToken` موقّعة RSA.
2. **العربية تعمل عبر الوضع السحابي حصرًا في هذا الإصدار**: لا يوجد API تنزيل باقات لغات في الكود، واللغة `Arabic` معرّفة محليًا بعلمَي `false,false` (غير متاحة في الوضعين السريع والدقيق محليًا)، بينما الوضع ONLINE يمر عبر `webapi.finereaderonline.com`.
3. **الإنجليزية تعمل محليًا من العلبة**: نماذج `European.rom` (1.6 MB) + قاموس `English.edc` مضمّنة في أصول التطبيق.
4. **بنية النتيجة تدعم RTL أصليًا**: `MocrTextLine` يحمل علم `_isRTL` مع مستطيل/شبه-منحرف السطر وإحداثيات كل حرف — وهذا بالضبط ما يحتاجه أي محرر تحقق عربي.
5. **الثقة موثقة لكل حرف**: نطاقات `UncertainCharRange` تحدد الأحرف منخفضة الثقة لعرضها على المستخدم للتحقق — نفس فلسفة علامات التحقق الخضراء/الكهرمانية في محرر `edit-ocr` لدينا.
6. **12 صيغة تصدير سحابية** عبر نمط "مهام" (Tasks): RTF، DOC، DOCX، XLS، XLSX، TXT، PPTX، ODT، PDF، PDFA، FB2، EPUB.

## خريطة التوثيق

| الملف | المحتوى |
|---|---|
| [docs/01-hawiya-al-tabaq.md](docs/01-hawiya-al-tabaq.md) | هوية التطبيق وبنية الـ APK والصلاحيات والمكونات |
| [docs/02-engine-architecture.md](docs/02-engine-architecture.md) | معمارية محرك OCR الأصلي والترخيص والنماذج |
| [docs/03-ocr-pipeline-ar-en.md](docs/03-ocr-pipeline-ar-en.md) | خط أنابيب OCR للعربية والإنجليزية خطوة بخطوة |
| [docs/04-online-recognition-service.md](docs/04-online-recognition-service.md) | بروتوكول خدمة التعرف السحابية |
| [docs/05-features-catalog.md](docs/05-features-catalog.md) | كتالوج الميزات الكامل (مرئية وغير مرئية) |
| [docs/06-lessons-for-our-projects.md](docs/06-lessons-for-our-projects.md) | دروس قابلة للتطبيق في مشاريعنا (ocr-core، edit-ocr، mtp) |
| [docs/07-evidence.md](docs/07-evidence.md) | جدول الأدلة لكل إدعاء (E01–E30 APK + E31–E36 ويب) |
| [docs/08-applied-lessons-and-pack-policy.md](docs/08-applied-lessons-and-pack-policy.md) | سجل التطبيق الفعلي + سياسة الحزمة العربية (الرفض الموثق) |
| [docs/09-ocr-algorithms-legal-study.md](docs/09-ocr-algorithms-legal-study.md) | خوارزميات OCR عربي/إنجليزي من مصادر قانونية: البراءات + الكود المفتوح |

## إشعار قانوني وأخلاقي

- هذا المستودع يحتوي **تحليلًا توثيقيًا فقط**: أوصاف معمارية، ملاحظات سلوكية، وأسماء أصناف/ثوابت مُقتبسة كأدلة تقنية. لا يتضمن أي كود مفكوك بحجمه، ولا أي ملف ثنائي من التطبيق، ولا النماذج المملوكة لـ ABBYY.
- ABBYY وFineReader علامتان تجاريتان لشركة ABBYY؛ هذا التحليل غير رسمي ولأغراض بحثية/تعليمية (قابلية التشغيل البيني والفهم التقني).
- الترخيص: MIT للتوثيق المكتوب هنا (انظر [LICENSE](LICENSE) و[NOTICE.md](NOTICE.md)).
