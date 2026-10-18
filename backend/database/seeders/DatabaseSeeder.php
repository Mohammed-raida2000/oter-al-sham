<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $roles = [
            'admin' => ['أدمن', 'Admin'], 'field_researcher' => ['باحث ميداني', 'Field Researcher'],
            'supervisor' => ['مشرف', 'Supervisor'], 'distribution_officer' => ['مسؤول توزيع', 'Distribution Officer'],
        ];
        foreach ($roles as $code => [$ar, $en]) {
            DB::table('roles')->insertOrIgnore(['code' => $code, 'name_ar' => $ar, 'name_en' => $en]);
        }
        $perms = ['user.manage', 'camp.view', 'camp.manage', 'family.view', 'family.create', 'family.update', 'family.review', 'family.sensitive',
            'project.view', 'project.manage', 'distribution.view', 'distribution.manage', 'distribution.receive', 'report.view', 'report.export', 'audit.view'];
        foreach ($perms as $p) {
            DB::table('permissions')->insertOrIgnore(['code' => $p]);
        }
        $grant = [
            'admin' => $perms,
            'field_researcher' => ['camp.view', 'family.view', 'family.create', 'family.update'],
            'supervisor' => ['camp.view', 'family.view', 'family.review', 'family.sensitive', 'project.view', 'distribution.view', 'report.view'],
            'distribution_officer' => ['camp.view', 'family.view', 'project.view', 'distribution.view', 'distribution.manage', 'distribution.receive'],
        ];
        foreach ($grant as $role => $codes) {
            $rid = DB::table('roles')->where('code', $role)->value('id');
            foreach ($codes as $c) {
                DB::table('role_permissions')->insertOrIgnore(['role_id' => $rid, 'permission_id' => DB::table('permissions')->where('code', $c)->value('id')]);
            }
        }
        // Catalogues: replace with the organisation's approved lists.
        if (DB::table('need_types')->count() === 0) {
            foreach (['غذاء', 'مياه', 'مأوى', 'ملابس', 'رعاية صحية', 'تعليم'] as $n) {
                DB::table('need_types')->insert(['name_ar' => $n]);
            }
        }
        if (DB::table('assistance_types')->count() === 0) {
            foreach (['سلة غذائية', 'مياه', 'ملابس', 'مستلزمات نظافة', 'نقدية'] as $n) {
                DB::table('assistance_types')->insert(['name_ar' => $n]);
            }
        }
        // First admin: credentials come from .env, never hard-coded.
        $pw = env('ADMIN_INITIAL_PASSWORD');
        if ($pw && DB::table('users')->where('username', env('ADMIN_USERNAME', 'admin'))->doesntExist()) {
            DB::table('users')->insert([
                'username' => env('ADMIN_USERNAME', 'admin'), 'full_name' => 'System Admin', 'password_hash' => Hash::make($pw),
                'role_id' => DB::table('roles')->where('code', 'admin')->value('id'),
            ]);
        }
    }
}
