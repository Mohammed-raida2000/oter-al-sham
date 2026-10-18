# Backend (Laravel + PostgreSQL) — جمعية عطر الشام

هذه ملفات **طبقة التطبيق** فقط. تُنسخ فوق مشروع Laravel جديد (لا يحتوي المجلد على vendor).

## التشغيل
```bash
composer create-project laravel/laravel oter-api && cd oter-api
composer require laravel/sanctum
php artisan install:api                      # ينشئ جدول التوكنات
rm database/migrations/0001_01_01_000000_create_users_table.php   # جدول users عندنا في schema.sql
cp -r <هذا المجلد>/* .                       # يستبدل bootstrap/app.php وroutes/api.php
```
ملف `.env`:
```
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=oter
DB_USERNAME=...
DB_PASSWORD=...
SESSION_DRIVER=file
CACHE_STORE=file
ADMIN_USERNAME=admin
ADMIN_INITIAL_PASSWORD=<كلمة سر قوية، 10 أحرف فأكثر>
```
```bash
php artisan migrate --seed
php artisan test        # 6 اختبارات
php artisan serve
```
## حالة الاختبار
- فُحصت صياغة كل ملفات PHP (php -l): سليمة.
- فُحصت قاعدة البيانات على PostgreSQL 16 (12 حالة نجحت).
- **لم تُشغَّل** ملفات Laravel ولا الاختبارات الستة، لأن بيئتي لا تصل إلى Packagist. أول تشغيل عندك هو أول اختبار فعلي، وأتوقع أخطاء صغيرة قد تحتاج إصلاحًا.

## افتراضات تنتظر قرارك
الهوية 9 أرقام والهاتف 10 أرقام يبدأ بصفر؛ الباحث يرى السجلات التي أنشأها فقط؛ المراجع لا يراجع سجلًا أنشأه بنفسه؛ التصدير مجاميع فقط بلا أسماء أو هويات؛ مدة التوكن 12 ساعة.
