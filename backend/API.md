# API v1 — الأساس `/api/v1` (التوثيق: Bearer token)
| الطريقة | المسار | الصلاحية |
|---|---|---|
| POST | auth/login (محدود 10/دقيقة) | — |
| GET/POST/PATCH | auth/me · auth/logout · auth/preferences | مسجّل |
| GET | dashboard | مسجّل |
| GET/POST | users · roles · PATCH users/{id}/active · POST users/{id}/password | user.manage |
| GET | camps · camps/{id} | camp.view |
| POST/PATCH | camps · camps/{id} (409 عند تشابه الاسم ما لم يُرسل confirm_similar) | camp.manage |
| GET | families · families/{id} · need-types | family.view |
| GET/POST | families/check · families | family.create |
| PATCH/POST | families/{id} · /submit · /members · /needs | family.update |
| GET/POST | reviews/pending · families/{id}/review | family.review |
| GET/POST/PATCH | projects | project.view / project.manage |
| GET | distributions · assistance-types | distribution.view |
| POST/PATCH/DELETE | distributions · /status · /beneficiaries | distribution.manage |
| POST | distributions/{d}/beneficiaries/{family}/receive (يتطلب id_number مطابقًا) | distribution.receive |
| GET | reports/families-by-camp(?format=csv) · families-by-status · incomplete · researchers · projects | report.view |
| GET | audit-logs | audit.view |
أكواد الأخطاء: 401 غير مسجل · 403 ممنوع · 409 تكرار · 422 قاعدة عمل (id_mismatch, family_not_approved, members_required…).
