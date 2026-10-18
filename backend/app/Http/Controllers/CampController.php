<?php

namespace App\Http\Controllers;

use App\Support\Audit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CampController extends Controller
{
    public function index(Request $r)
    {
        $q = DB::table('camps')
            ->leftJoin('v_camp_stats as s', 's.camp_id', '=', 'camps.id')
            ->select('camps.id', 'camps.code', 'camps.name', 'camps.governorate', 'camps.area', 'camps.status', 's.families_count');
        if ($r->filled('q')) {
            $q->where(fn ($w) => $w->where('camps.name', 'ilike', '%'.$r->q.'%')->orWhere('camps.code', 'ilike', '%'.$r->q.'%'));
        }
        if ($r->filled('status')) {
            $q->where('camps.status', $r->status);
        }
        return $q->orderBy('camps.name')->paginate(30);
    }

    public function show(int $id)
    {
        $camp = DB::table('camps')->find($id);
        abort_if(! $camp, 404);
        return [
            'camp' => $camp,
            'stats' => DB::table('v_camp_stats')->where('camp_id', $id)->first(),
            'projects' => DB::table('project_camps')->join('projects', 'projects.id', '=', 'project_camps.project_id')
                ->where('camp_id', $id)->select('projects.id', 'projects.code', 'projects.name')->get(),
            'distributions' => DB::table('distributions')->where('camp_id', $id)->select('id', 'title', 'planned_on', 'status')->get(),
        ];
    }

    public function store(Request $r)
    {
        $d = $r->validate([
            'code' => 'required|string|max:30|unique:camps,code',
            'name' => 'required|string|max:150',
            'governorate' => 'required|string|max:100',
            'area' => 'required|string|max:100',
            'address_detail' => 'nullable|string',
            'latitude' => 'nullable|numeric|between:-90,90',
            'longitude' => 'nullable|numeric|between:-180,180',
            'representative_name' => 'nullable|string|max:150',
            'representative_phone' => 'nullable|string|max:20',
            'confirm_similar' => 'sometimes|boolean',
        ]);
        $similar = DB::select('select id, code, name from camps where similarity(name, ?) > 0.5 limit 5', [$d['name']]);
        if ($similar && empty($d['confirm_similar'])) {
            return response()->json(['message' => 'similar_names_exist', 'similar' => $similar], 409);
        }
        unset($d['confirm_similar']);
        $id = DB::table('camps')->insertGetId($d + ['created_by' => $r->user()->id, 'created_at' => now(), 'updated_at' => now()]);
        Audit::log($r->user(), 'create', 'camp', $id, ['code' => $d['code']]);
        return response()->json(['id' => $id], 201);
    }

    public function update(Request $r, int $id)
    {
        $d = $r->validate([
            'name' => 'sometimes|string|max:150', 'governorate' => 'sometimes|string|max:100',
            'area' => 'sometimes|string|max:100', 'address_detail' => 'nullable|string',
            'representative_name' => 'nullable|string|max:150', 'representative_phone' => 'nullable|string|max:20',
            'status' => 'sometimes|in:active,inactive,archived',
        ]);
        abort_if(DB::table('camps')->where('id', $id)->update($d + ['updated_at' => now()]) === 0, 404);
        Audit::log($r->user(), 'update', 'camp', $id, array_keys($d));
        return response()->noContent();
    }
}
