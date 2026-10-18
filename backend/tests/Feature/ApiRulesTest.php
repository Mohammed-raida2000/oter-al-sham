<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ApiRulesTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
        DB::table('camps')->insert(['code' => 'C1', 'name' => 'Test Camp', 'governorate' => 'G', 'area' => 'A']);
    }

    private function user(string $role): User
    {
        return User::create(['username' => $role.uniqid(), 'full_name' => 'T '.$role, 'password_hash' => Hash::make('Password-12345'),
            'role_id' => DB::table('roles')->where('code', $role)->value('id')]);
    }

    private function family(array $o = []): array
    {
        return $o + ['head_name' => 'Test Head', 'id_number' => '123456789', 'phone' => '0591234567', 'current_camp_id' => 1];
    }

    public function test_login_rejects_bad_password(): void
    {
        $u = $this->user('admin');
        $this->postJson('/api/v1/auth/login', ['username' => $u->username, 'password' => 'wrong'])->assertStatus(401);
    }

    public function test_only_admin_creates_users(): void
    {
        Sanctum::actingAs($this->user('field_researcher'));
        $this->postJson('/api/v1/users', ['username' => 'x', 'full_name' => 'x', 'password' => 'Password-12345', 'role_id' => 1])->assertStatus(403);
        Sanctum::actingAs($this->user('admin'));
        $this->postJson('/api/v1/users', ['username' => 'newuser', 'full_name' => 'N', 'password' => 'Password-12345', 'role_id' => 2])->assertStatus(201);
    }

    public function test_family_requires_id_and_phone(): void
    {
        Sanctum::actingAs($this->user('field_researcher'));
        $this->postJson('/api/v1/families', $this->family(['id_number' => null]))->assertStatus(422);
        $this->postJson('/api/v1/families', $this->family(['phone' => null]))->assertStatus(422);
        $this->postJson('/api/v1/families', $this->family())->assertStatus(201);
    }

    public function test_duplicate_id_returns_409(): void
    {
        Sanctum::actingAs($this->user('field_researcher'));
        $this->postJson('/api/v1/families', $this->family())->assertStatus(201);
        $this->postJson('/api/v1/families', $this->family(['phone' => '0599999999']))->assertStatus(409);
    }

    public function test_researcher_cannot_review_and_supervisor_can(): void
    {
        $res = $this->user('field_researcher');
        Sanctum::actingAs($res);
        $id = $this->postJson('/api/v1/families', $this->family())->json('id');
        $this->postJson("/api/v1/families/$id/members", ['full_name' => 'M', 'relation' => 'son'])->assertStatus(201);
        $this->postJson("/api/v1/families/$id/submit")->assertNoContent();
        $this->postJson("/api/v1/families/$id/review", ['decision' => 'approved'])->assertStatus(403);
        Sanctum::actingAs($this->user('supervisor'));
        $this->postJson("/api/v1/families/$id/review", ['decision' => 'approved'])->assertNoContent();
    }

    public function test_receipt_needs_matching_id(): void
    {
        $this->seedApprovedFamilyInDistribution();
        Sanctum::actingAs($this->user('distribution_officer'));
        $this->postJson('/api/v1/distributions/1/beneficiaries/1/receive', ['id_number' => '000000000'])->assertStatus(422);
        $this->postJson('/api/v1/distributions/1/beneficiaries/1/receive', ['id_number' => '123456789'])->assertNoContent();
        $this->postJson('/api/v1/distributions/1/beneficiaries/1/receive', ['id_number' => '123456789'])->assertStatus(409);
    }

    private function seedApprovedFamilyInDistribution(): void
    {
        $admin = $this->user('admin');
        DB::table('families')->insert($this->family() + ['created_by' => $admin->id, 'status' => 'approved']);
        DB::table('projects')->insert(['code' => 'P1', 'name' => 'P', 'project_type' => 'relief']);
        DB::table('distributions')->insert(['title' => 'D', 'project_id' => 1, 'camp_id' => 1, 'assistance_type_id' => 1, 'planned_on' => now()->toDateString(), 'created_by' => $admin->id]);
        DB::table('distribution_beneficiaries')->insert(['distribution_id' => 1, 'family_id' => 1]);
    }
}
