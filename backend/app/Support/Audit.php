<?php

namespace App\Support;

use Illuminate\Support\Facades\DB;

class Audit
{
    public static function log($user, string $action, string $entity, ?int $entityId = null, array $details = []): void
    {
        DB::table('audit_logs')->insert([
            'user_id' => $user?->id,
            'action' => $action,
            'entity' => $entity,
            'entity_id' => $entityId,
            'details' => json_encode($details, JSON_UNESCAPED_UNICODE),
            'ip' => request()->ip(),
            'created_at' => now(),
        ]);
    }

    /** Show only the last 3 digits of an ID to roles without family.sensitive. */
    public static function maskId(?string $id): ?string
    {
        return $id === null ? null : str_repeat('•', max(strlen($id) - 3, 0)).substr($id, -3);
    }
}
