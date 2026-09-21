# 🌐 دليل ربط الدومين (vegtablity.cc) بـ Cloudflare والـ VPS مع إخفاء الـ IP وتوفير HTTPS

---

## 📌 الهدف العام:
1. ربط الدومين الجديد **`vegtablity.cc`** من Hostinger إلى **Cloudflare**.
2. **إخفاء عنوان الـ IP الحقيقي للـ VPS (`185.216.203.50`)** تماماً لحماية السيرفر من هجمات DDoS والاختراق.
3. تفعيل شهادة الأمان والتشفير **HTTPS / SSL المجانية والتلقائية بنسبة 100%**.
4. تجهيز الدومين لاستضافة:
   - **تطبيق الويب للمديرين (Flutter Web App / PWA):** على `https://vegtablity.cc` أو `https://app.vegtablity.cc` (يعمل كـ App كامل وسلس على الآيفون والكمبيوتر).
   - **خادم الـ API (FastAPI):** على `https://api.vegtablity.cc` أو `https://vegtablity.cc/api`.

---

## 🚀 الخطوة 1: إنشاء حساب وإضافة الدومين في Cloudflare (مجاناً)

1. توجه إلى موقع: **[https://dash.cloudflare.com/sign-up](https://dash.cloudflare.com/sign-up)** وقم بإنشاء حساب مجاني (إن لم يكن لديك حساب).
2. بعد تسجيل الدخول، انقر على زر **"+ Add a domain"** (إضافة موقع).
3. اكتب اسم الدومين الخاص بك:
   ```text
   vegtablity.cc
   ```
4. اختر الخطة المجانية: **Free Plan ($0)** ثم انقر **Continue**.
5. سيقوم Cloudflare بفحص سجلات الـ DNS الحالية للدومين تلقائياً.

---

## 🚀 الخطوة 2: إضافة سجلات الـ DNS وتفعيل البروكسي (إخفاء الـ IP)

في صفحة مراجعة سجلات الـ DNS (أو من قائمة **DNS > Records** في Cloudflare):
تأكد من إضافة السجلات التالية بدقة (مع التأكد من تفعيل السحابة البرتقالية **Proxied ☁️** لإخفاء الـ IP):

| Type | Name (الاسم) | IPv4 Address (القيمة) | Proxy Status (الحالة) | TTL | الشرح |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **A** | `@` (أو `vegtablity.cc`) | `185.216.203.50` | 🟠 **Proxied** (سحابة برتقالية) | Auto | الدومين الرئيسي (تطبيق الإدارة Web) |
| **A** | `app` | `185.216.203.50` | 🟠 **Proxied** (سحابة برتقالية) | Auto | رابط تطبيق الويب `app.vegtablity.cc` |
| **A** | `api` | `185.216.203.50` | 🟠 **Proxied** (سحابة برتقالية) | Auto | رابط سيرفر الـ API `api.vegtablity.cc` |
| **A** | `admin` | `185.216.203.50` | 🟠 **Proxied** (سحابة برتقالية) | Auto | رابط فرعي اختياري للمشرفين |
| **CNAME** | `www` | `vegtablity.cc` | 🟠 **Proxied** (سحابة برتقالية) | Auto | تحويل www إلى الدومين الرئيسي |

> ⚠️ **ملاحظة أمنية هامة جداً:**
> عندما تكون السحابة برتقالية **Proxied ☁️**، فإن أي شخص يبحث عن الدومين `vegtablity.cc` سيرى فقط خوادم Cloudflare، ولن يظهر الـ IP الحقيقي لسيرفرك (`185.216.203.50`) على الإطلاق!

انقر **Continue** للمتابعة.

---

## 🚀 الخطوة 3: نسخ خوادم الأسماء (Nameservers) من Cloudflare

سيعطيك Cloudflare خادمي أسماء (Nameservers) خاصين بحسابك، على سبيل المثال:
```text
ns1.cloudflare.com
ns2.cloudflare.com
```
*(احفظ الاسمين اللذين يظهران لك في الشاشة)*.

---

## 🚀 الخطوة 4: تغيير الـ Nameservers في Hostinger

1. افتح لوحة تحكم Hostinger على الرابط:
   **[https://hpanel.hostinger.com/domain/vegtablity.cc/dns](https://hpanel.hostinger.com/domain/vegtablity.cc/dns)**
2. في القائمة الجانبية أو التبويبات العلوية، انقر على **"Nameservers"** (أو خوادم الأسماء).
3. اختر **"Change Nameservers"** (تغيير خوادم الأسماء).
4. اختر خيار **"Change Hostinger nameservers"** أو **"Custom nameservers"**.
5. احذف الخوادم القديمة لـ Hostinger، وأدخل خوادم Cloudflare:
   - **Nameserver 1:** `(الاسم الأول من Cloudflare)`
   - **Nameserver 2:** `(الاسم الثاني من Cloudflare)`
6. انقر على **"Save" (حفظ)**.

> ⏳ **ملاحظة الانتشار (Propagation):**
> يستغرق تحديث الـ Nameservers عالمياً من 10 دقائق إلى ساعتين كحد أقصى.

---

## 🚀 الخطوة 5: إعدادات الأمان والتشفير (SSL / HTTPS) في Cloudflare

داخل لوحة Cloudflare لموقع `vegtablity.cc`:

1. **إعداد وضع التشفير (SSL/TLS Encryption Mode):**
   - توجه إلى: **SSL/TLS > Overview**.
   - اضبط الوضع على: **`Flexible`** (مرن) - **هذا الخيار إلزامي عند تشغيل FastAPI على المنفذ 80 مباشرة**.
   - *(يقوم Cloudflare بتشفير الاتصال مع الزائر عبر HTTPS Port 443، ويمرر الطلب لسيرفرك على Port 80 HTTP بسلاسة وسرعة).*
2. **فرض استخدام HTTPS دائماً:**
   - توجه إلى: **SSL/TLS > Edge Certificates**.
   - قم بتفعيل: **Always Use HTTPS** ⬅️ (يحول أي زائر من `http://` إلى `https://` تلقائياً).
   - قم بتفعيل: **Automatic HTTPS Rewrites**.
   - قم بتفعيل: **Minimum TLS Version** ⬅️ اختر `TLS 1.2` أو `TLS 1.3`.
3. **تحسين سرعة وأداء تطبيق الويب للآيفون (Speed & Optimization):**
   - توجه إلى: **Speed > Optimization > Content Optimization**.
   - قم بتفعيل: **Brotli Compression** (يقلل حجم تحميل تطبيق Flutter Web بنسبة 70%).
   - توجه إلى: **Network** وتأكد من تفعيل: **HTTP/2** و **HTTP/3 (with QUIC)** و **0-RTT Connection Resumption** لضمان فتح التطبيق على سفاري الآيفون بسرعة البرق.

---

## 🚀 الخطوة 6: التحقق من نجاح الربط (Verification)

1. في لوحة Cloudflare، انقر على **"Check nameservers now"**.
2. عندما يكتمل الربط، ستظهر لك رسالة:
   ```text
   Great news! Cloudflare is now protecting your site.
   ```
3. عند فتح `https://vegtablity.cc` أو `https://api.vegtablity.cc` ستظهر لك شهادة SSL آمنة 🔒 وتعمل بكفاءة تامة.
