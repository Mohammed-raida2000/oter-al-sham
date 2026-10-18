<?php

namespace App\Http\Controllers;

use App\Support\Audit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class FamilyDetailController extends Controller
{
    private function editable(Request $r, int $familyId): void
    {
        $f = DB::table('families')->find($familyId);
        abort_if(! $f, 404);
        if ($r->user()->role->code !== 'admin') {
            abort_unless($f->created_by === $r->user()->id && in_array($f->status, ['draft', 'needs_correction'], true), 403);
        }
    }

    public function addMember(Request $r, int $family)
    {
        $this->editable($r, $family);
        $d = $r->validate([
            'full_name' => 'required|string|max:150', 'relation' => 'required|string|max:50',
            'birth_date' => 'nullable|date|before_or_equal:today', 'gender' => 'nullable|in:male,female',
        ]);
        $id = DB::table('family_members')->insertGetId($d + ['family_id' => $family, 'created_at' => now(), 'updated_at' => now()]);
        Audit::log($r->user(), 'create', 'family_member', $id, ['family_id' => $family]);
        return response()->json(['id' => $id], 201);
    }

    public function updateMember(Request $r, int $family, int $member)
    {
        $this->editable($r, $family);
        $d = $r->validate([
            'full_name' => 'sometimes|string|max:150', 'relation' => 'sometimes|string|max:50',
            'birth_date' => 'nullable|date|before_or_equal:today', 'gender' => 'nullable|in:male,female',
        ]);
        abort_if(DB::table('family_members')->where(['id' => $member, 'family_id' => $family])->update($d + ['updated_at' => now()]) === 0, 404);
        Audit::log($r->user(), 'update', 'family_member', $member);
        return response()->noContent();
    }

    public function deleteMember(Request $r, int $family, int $member)
    {
        $this->editable($r, $family);
        abort_if(DB::table('family_members')->where(['id' => $member, 'family_id' => $family])->delete() === 0, 404);
        Audit::log($r->user(), 'delete', 'family_member', $member, ['family_id' => $family]);
        return response()->noContent();
    }

    public function addNeed(Request $r, int $family)
    {
        $this->editable($r, $family);
        $d = $r->validate(['need_type_id' => 'required|exists:need_types,id', 'notes' => 'nullable|string|max:500']);
        $id = DB::table('family_needs')->insertGetId($d + ['family_id' => $family, 'recorded_by' => $r->user()->id, 'recorded_at' => now(), 'updated_at' => now()]);
        Audit::log($r->user(), 'create', 'family_need', $id, ['family_id' => $family]);
        return response()->json(['id' => $id], 201);
    }

    public function updateNeed(Request $r, int $family, int $need)
    {
        abort_unless(in_array($r->user()->role->code, ['admin', 'supervisor', 'field_researcher'], true), 403);
        $d = $r->validate(['status' => 'required|in:open,in_progress,met,closed', 'notes' => 'nullable|string|max:500']);
        abort_if(DB::table('family_needs')->where(['id' => $need, 'family_id' => $family])->update($d + ['updated_at' => now()]) === 0, 404);
        Audit::log($r->user(), 'update', 'family_need', $need);
        return response()->noContent();
    }

    public function needTypes()
    {
        return DB::table('need_types')->where('is_active', true)->orderBy('id')->get();
    }
}
