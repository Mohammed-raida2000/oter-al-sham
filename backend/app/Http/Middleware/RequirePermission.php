<?php

namespace App\Http\Middleware;

use App\Support\Audit;
use Closure;
use Illuminate\Http\Request;

class RequirePermission
{
    public function handle(Request $request, Closure $next, string ...$codes)
    {
        $user = $request->user();
        if (! $user || ! $user->is_active) {
            return response()->json(['message' => 'unauthenticated'], 401);
        }
        $have = $user->permissionCodes();
        foreach ($codes as $code) {
            if (in_array($code, $have, true)) {
                return $next($request);
            }
        }
        Audit::log($user, 'denied', 'route', null, ['path' => $request->path(), 'needs' => $codes]);
        return response()->json(['message' => 'forbidden'], 403);
    }
}
