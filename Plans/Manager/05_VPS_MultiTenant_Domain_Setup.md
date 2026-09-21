# 🏢 دليل تشغيل السيرفر وتوجيه كل شركة/قاعدة بيانات على رابط خاص بها

---

## 📌 الهدف والمفهوم (Multi-Tenant Subdomain & Database Isolation):

يعتمد النظام معمارية **العزل التام والخصوصية الكاملة (Complete Multi-Tenant Isolation)**، حيث يكون لكل منشأة/شركة دومين فرعي خاص بها يتصل ببيانات الشركة وقاعدة بياناتها دون أي اختلاط أو إمكانية للتنقل بين الشركات:

| الشركة / المنشأة | الدومين الفرعي (Subdomain) | قاعدة البيانات المستهدفة | حالة العزل والخصوصية |
| :--- | :--- | :--- | :--- |
| **مغسلة وشا** | `https://washa.vegtablity.cc` | `WashaDB` | 🔒 معزول ومقفل على المنشأة 100% |
| **شركة الجوهرة** | `https://jawhara.vegtablity.cc` | `JawharaDB` | 🔒 معزول ومقفل على المنشأة 100% |
| **نظام الخضار والفواكه** | `https://veg.vegtablity.cc` | `VegtablityDB` | 🔒 معزول ومقفل على المنشأة 100% |
| **مطاعم زعتر** | `https://zatter.vegtablity.cc` | `zatterDB` | 🔒 معزول ومقفل على المنشأة 100% |
| **فرع سلطنة عمان** | `https://oman.vegtablity.cc` | `OmanCustmerDB` | 🔒 معزول ومقفل على المنشأة 100% |

---

## ❓ هل يلزم تثبيت Nginx؟

### 🟢 **الإجابة: لا، لا يلزم تثبيت Nginx نهائياً!**
يمكنك تشغيل النظام بأكمله **بواسطة FastAPI و Cloudflare فقط**، وإليك الطريقتين بالتفصيل:

---

## 🥇 الطريقة الأولى (الموصى بها بشدة - FastAPI فقط بدون Nginx):

تتميز هذه الطريقة بأنها **أسهل بنسبة 100%**، وتعتمد على **تطبيق واحد فقط يعمل في الخلفية** ويخدم كافة الشركات.

### 1. كيف تعمل؟
1. **Cloudflare:** يستقبل كافة الروابط `*.vegtablity.cc` ويوفر شهادة الـ HTTPS مجاناً ويوجه الطلبات إلى الـ VPS على المنفذ `80`.
2. **FastAPI:** يستقبل الطلبات ويقوم بـ:
   - خدمة ملفات تطبيق Flutter Web على المسار الرئيسي `/static/web/`.
   - التعرف التلقائي على الشركة من الرابط (عبر دالة `extract_database` التي تقرأ اسم الدومين مثل `washa` أو `jawhara`) وتوجيه الاستعلامات فوراً إلى قاعدة البيانات المعنية `WashaDB` أو `JawharaDB`.

### 2. ملف الخدمة الموحد على السيرفر (`/etc/systemd/system/vegtablity-api.service`):
```ini
[Unit]
Description=Vegtablity Multi-Tenant FastAPI Service
After=network.target

[Service]
User=root
WorkingDirectory=/var/www/VegtablityApi
ExecStart=/usr/local/bin/uvicorn app.main:app --host 0.0.0.0 --port 80 --workers 4
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
```

### 3. تشغيل الخدمة بأمر واحد:
```bash
sudo systemctl daemon-reload
sudo systemctl enable vegtablity-api
sudo systemctl restart vegtablity-api
sudo systemctl status vegtablity-api
```

---

## 🥈 الطريقة الثانية (اختيارية - في حال رغبت بتشغيل Nginx ومنافذ منفصلة لكل شركة):

إذا كنت تفضل أن يكون لكل شركة عملية بايثون منفصلة على منفذ خاص بها (`Port 8000, 8001, 8002...`):

### 1. تكوين Nginx (`/etc/nginx/sites-available/vegtablity.conf`):
```nginx
# 1. مغسلة وشا (Port 8000)
server {
    listen 80;
    server_name washa.vegtablity.cc;
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# 2. شركة الجوهرة (Port 8001)
server {
    listen 80;
    server_name jawhara.vegtablity.cc;
    location / {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# 3. نظام الخضار والفواكه (Port 8002)
server {
    listen 80;
    server_name veg.vegtablity.cc vegtablity.cc;
    location / {
        proxy_pass http://127.0.0.1:8002;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## 🌐 إعدادات Cloudflare (مطلوبة للطريقتين):

في لوحة Cloudflare لدومين `vegtablity.cc` (قائمة **DNS > Records**):

| Type | Name (الاسم) | Target / IP (القيمة) | Proxy Status | الشرح |
| :--- | :--- | :--- | :--- | :--- |
| **A** | `*` (علامة النجمة) | `185.216.203.50` | 🟠 **Proxied** (سحابة برتقالية) | يوجه أي رابط فرعي تلقائياً للسيرفر مع إخفاء الـ IP وتشفير SSL |
| **A** | `@` | `185.216.203.50` | 🟠 **Proxied** | الدومين الرئيسي `vegtablity.cc` |
| **A** | `api` | `185.216.203.50` | 🟠 **Proxied** | سيرفر الـ API المركزي |
