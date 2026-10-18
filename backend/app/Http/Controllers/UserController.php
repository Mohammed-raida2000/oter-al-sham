<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Support\Audit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class UserController extends Controller
{
    public function index()
    {
        return User::with('role')->orderBy('id')->get()->map(fn ($u) => [
            'id' => $u->id, 'username' => $u->username, 'full_name' => $u->full_name,
            'role' => $u->role->code, 'is_active' => $u->is_active,
        ]);
    }

    public function store(Request $r)
    {
        $d = $r->validate([
            'username' => 'required|string|max:50|unique:users,username',
            'full_name' => 'required|string|max:150',
            'phone' => 'nullable|string|max:20',
            'password' => 'required|string|min:10',
            'role_id' => 'required|exists:roles,id',
        ]);
        $u = User::create([
            'username' => $d['username'], 'full_name' => $d['full_name'], 'phone' => $d['phone'] ?? null,
            'password_hash' => Hash::make($d['password']), 'role_id' => $d['role_id'], 'created_by' => $r->user()->id,
        ]);
        Audit::log($r->user(), 'create', 'user', $u->id, ['username' => $u->username, 'role_id' => $u->role_id]);
        return response()->json(['id' => $u->id], 201);
    }

    public function setActive(Request $r, User $user)
    {
        $d = $r->validate(['is_active' => 'required|boolean']);
        if ($user->id === $r->user()->id) {
            return response()->json(['message' => 'cannot_change_self'], 422);
        }
        $user->update(['is_active' => $d['is_active'], 'deactivated_at' => $d['is_active'] ? null : now()]);
        if (! $d['is_active']) {
            $user->tokens()->delete(); // revoke access immediately
        }
        Audit::log($r->user(), $d['is_active'] ? 'activate' : 'deactivate', 'user', $user->id);
        return response()->noContent();
    }

    public function resetPassword(Request $r, User $user)
    {
        $d = $r->validate(['password' => 'required|string|min:10']);
        $user->update(['password_hash' => Hash::make($d['password'])]);
        $user->tokens()->delete();
        Audit::log($r->user(), 'reset_password', 'user', $user->id);
        return response()->noContent();
    }

    public function roles()
    {
        return \DB::table('roles')->orderBy('id')->get();
    }
}
