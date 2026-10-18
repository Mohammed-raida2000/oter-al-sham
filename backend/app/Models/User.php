<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens;

    protected $table = 'users';
    protected $fillable = ['username', 'full_name', 'phone', 'password_hash', 'role_id', 'is_active', 'locale', 'theme', 'created_by'];
    protected $hidden = ['password_hash'];
    protected $casts = ['is_active' => 'boolean'];

    public function getAuthPassword()
    {
        return $this->password_hash;
    }

    public function role(): BelongsTo
    {
        return $this->belongsTo(Role::class);
    }

    public function permissionCodes(): array
    {
        return \DB::table('role_permissions')
            ->join('permissions', 'permissions.id', '=', 'role_permissions.permission_id')
            ->where('role_permissions.role_id', $this->role_id)
            ->pluck('permissions.code')->all();
    }

    public function can($abilities, $arguments = []): bool
    {
        return in_array($abilities, $this->permissionCodes(), true);
    }
}
