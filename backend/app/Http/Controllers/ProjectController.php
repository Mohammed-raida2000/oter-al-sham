<?php

namespace App\Http\Controllers;

use App\Support\Audit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ProjectController extends Controller
{
    public function index(Request $r)
    {
        $q = DB::table('projects')->leftJoin('v_project_stats as s', 's.project_id', '=', 'projects.id')
            ->select('projects.id', 'projects.code', 'projects.name', 'projects.project_type', 'projects.status', 'projects.starts_on', 'projects.ends_on', 's.families_served', 's.distributions_count');
        if ($r->filled('status')) {
            $q->where('projects.status', $r->status);
        }
        if ($r->filled('q')) {
            $q->where('projects.name', 'ilike', '%'.$r->q.'%');
        }
        return $q->orderByDesc('projects.id')->paginate(30);
    }

    public function show(int $id)
    {
        $p = DB::table('projects')->find($id);
        abort_if(! $p, 404);
        return [
            'project' => $p,
            'camps' => DB::table('project_camps')->join('camps', 'camps.id', '=', 'project_camps.camp_id')->where('project_id', $id)->select('camps.id', 'camps.code', 'camps.name')->get(),
            'stats' => DB::table('v_project_stats')->where('project_id', $id)->first(),
            'distributions' => DB::table('distributions')->where('project_id', $id)->select('id', 'title', 'planned_on', 'status')->get(),
        ];
    }

    public function store(Request $r)
    {
        $d = $r->validate([
            'code' => 'required|string|max:30|unique:projects,code', 'name' => 'required|string|max:150',
            'project_type' => 'required|string|max:80', 'description' => 'nullable|string',
            'starts_on' => 'nullable|date', 'ends_on' => 'nullable|date|after_or_equal:starts_on',
            'target_groups' => 'nullable|string', 'target_family_count' => 'nullable|integer|min:0',
            'camp_ids' => 'sometimes|array', 'camp_ids.*' => 'exists:camps,id',
        ]);
        $camps = $d['camp_ids'] ?? [];
        unset($d['camp_ids']);
        $id = DB::transaction(function () use ($r, $d, $camps) {
            $id = DB::table('projects')->insertGetId($d + ['created_by' => $r->user()->id, 'created_at' => now(), 'updated_at' => now()]);
            foreach (array_unique($camps) as $c) {
                DB::table('project_camps')->insert(['project_id' => $id, 'camp_id' => $c]);
            }
            return $id;
        });
        Audit::log($r->user(), 'create', 'project', $id, ['code' => $d['code']]);
        return response()->json(['id' => $id], 201);
    }

    public function update(Request $r, int $id)
    {
        $d = $r->validate([
            'name' => 'sometimes|string|max:150', 'description' => 'nullable|string',
            'status' => 'sometimes|in:planned,active,completed,suspended,archived',
            'starts_on' => 'nullable|date', 'ends_on' => 'nullable|date|after_or_equal:starts_on',
            'camp_ids' => 'sometimes|array', 'camp_ids.*' => 'exists:camps,id',
        ]);
        $camps = $d['camp_ids'] ?? null;
        unset($d['camp_ids']);
        DB::transaction(function () use ($id, $d, $camps) {
            if ($d) {
                abort_if(DB::table('projects')->where('id', $id)->update($d + ['updated_at' => now()]) === 0, 404);
            }
            if ($camps !== null) {
                DB::table('project_camps')->where('project_id', $id)->delete();
                foreach (array_unique($camps) as $c) {
                    DB::table('project_camps')->insert(['project_id' => $id, 'camp_id' => $c]);
                }
            }
        });
        Audit::log($r->user(), 'update', 'project', $id, array_keys($d));
        return response()->noContent();
    }
}
