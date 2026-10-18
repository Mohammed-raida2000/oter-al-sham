<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Support\Audit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function login(Request $r)
    {
        $d = $r->validate(['username' => 'required|string', 'password' => 'required|string']);
        $user = User::where('username', $d['username'])->first();
        if (! $user || ! Hash::check($d['password'], $user->password_hash) || ! $user->is_active) {
            Audit::log($user, 'login_failed', 'user', $user?->id, ['username' => $d['username']]);
            return response()->json(['message' => 'invalid_credentials'], 401);
        }
        $token = $user->createToken('mobile', ['*'], now()->addHours(12))->plainTextToken;
        Audit::log($user, 'login', 'user', $user->id);
        return ['token' => $token, 'user' => $this->shape($user)];
    }

    public function me(Request $r)
    {
        return $this->shape($r->user());
    }

    public function logout(Request $r)
    {
        $r->user()->currentAccessToken()->delete();
        Audit::log($r->user(), 'logout', 'user', $r->user()->id);
        return response()->noContent();
    }

    public function preferences(Request $r)
    {
        $d = $r->validate(['locale' => 'sometimes|in:ar,en', 'theme' => 'sometimes|in:light,dark']);
        $r->user()->update($d);
        return $this->shape($r->user()->fresh());
    }

    private function shape(User $u): array
    {
        return [
            'id' => $u->id, 'username' => $u->username, 'full_name' => $u->full_name,
            'role' => $u->role->code, 'permissions' => $u->permissionCodes(),
            'locale' => $u->locale, 'theme' => $u->theme,
        ];
    }
}
