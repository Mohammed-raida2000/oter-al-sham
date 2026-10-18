<?php

namespace App\Http\Controllers;

use App\Support\Audit;
use Illuminate\Database\QueryException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DistributionController extends Controller
{
    public function index(Request $r)
    {
        $q = DB::table('distributions')->join('projects', 'projects.id', '=', 'distributions.project_id')
            ->join('camps', 'camps.id', '=', 'distributions.camp_id')
            ->join('assistance_types', 'assistance_types.id', '=', 'distributions.assistance_type_id')
            ->select('distributions.id', 'distributions.title', 'distributions.planned_on', 'distributions.status', 'distributions.mode',
                'projects.name as project', 'camps.name as camp', 'assistance_types.name_ar as assistance');
        foreach (['project_id' => 'distributions.project_id', 'camp_id' => 'distributions.camp_id', 'status' => 'distributions.status'] as $in => $col) {
            if ($r->filled($in)) {
                $q->where($col, $r->$in);
            }
        }
        return $q->orderByDesc('distributions.planned_on')->paginate(30);
    }

    public function show(int $id)
    {
        $d = DB::table('distributions')->find($id);
        abort_if(! $d, 404);
        return [
            'distribution' => $d,
            'items' => DB::table('distribution_items')->where('distribution_id', $id)->get(),
            'beneficiaries' => DB::table('distribution_beneficiaries as b')->join('families as f', 'f.id', '=', 'b.family_id')
                ->where('b.distribution_id', $id)->select('b.id', 'b.family_id', 'f.family_no', 'f.head_name', 'b.received', 'b.received_at', 'b.id_verified')->get(),
            'counts' => [
                'total' => DB::table('distribution_beneficiaries')->where('distribution_id', $id)->count(),
                'received' => DB::table('distribution_beneficiaries')->where('distribution_id', $id)->where('received', true)->count(),
            ],
        ];
    }

    public function store(Request $r)
    {
        $d = $r->validate([
            'title' => 'required|string|max:200', 'project_id' => 'required|exists:projects,id', 'camp_id' => 'required|exists:camps,id',
            'assistance_type_id' => 'required|exists:assistance_types,id', 'mode' => 'required|in:names_only,full_documentation',
            'planned_on' => 'required|date', 'responsible_team' => 'nullable|string|max:150', 'notes' => 'nullable|string',
            'items' => 'required_if:mode,full_documentation|array', 'items.*.item_name' => 'required|string|max:150',
            'items.*.quantity_per_family' => 'required|numeric|gt:0', 'items.*.unit' => 'nullable|string|max:30',
        ]);
        $items = $d['items'] ?? [];
        unset($d['items']);
        $id = DB::transaction(function () use ($r, $d, $items) {
            $id = DB::table('distributions')->insertGetId($d + ['created_by' => $r->user()->id, 'created_at' => now(), 'updated_at' => now()]);
            foreach ($items as $it) {
                DB::table('distribution_items')->insert($it + ['distribution_id' => $id]);
            }
            return $id;
        });
        Audit::log($r->user(), 'create', 'distribution', $id);
        return response()->json(['id' => $id], 201);
    }

    public function setStatus(Request $r, int $id)
    {
        $d = $r->validate(['status' => 'required|in:scheduled,in_progress,completed,cancelled']);
        abort_if(DB::table('distributions')->where('id', $id)->update($d + ['updated_at' => now()]) === 0, 404);
        Audit::log($r->user(), 'status', 'distribution', $id, $d);
        return response()->noContent();
    }

    public function addBeneficiary(Request $r, int $id)
    {
        $d = $r->validate(['family_id' => 'required_without:family_no|exists:families,id', 'family_no' => 'required_without:family_id|string']);
        $familyId = $d['family_id'] ?? DB::table('families')->where('family_no', $d['family_no'])->value('id');
        abort_if(! $familyId, 404);
        abort_if(! DB::table('distributions')->where('id', $id)->exists(), 404);
        try {
            $bid = DB::table('distribution_beneficiaries')->insertGetId(['distribution_id' => $id, 'family_id' => $familyId]);
        } catch (QueryException $e) {
            if ($e->getCode() === '23505') {
                return response()->json(['message' => 'family_already_in_activity'], 409);
            }
            if ($e->getCode() === '23514') {
                return response()->json(['message' => 'family_not_approved'], 422);
            }
            throw $e;
        }
        Audit::log($r->user(), 'add_beneficiary', 'distribution', $id, ['family_id' => $familyId]);
        return response()->json(['id' => $bid], 201);
    }

    public function removeBeneficiary(Request $r, int $id, int $family)
    {
        $n = DB::table('distribution_beneficiaries')->where(['distribution_id' => $id, 'family_id' => $family, 'received' => false])->delete();
        abort_if($n === 0, 404);
        Audit::log($r->user(), 'remove_beneficiary', 'distribution', $id, ['family_id' => $family]);
        return response()->noContent();
    }

    /** Receipt is confirmed only if the entered ID matches the family's ID. */
    public function receive(Request $r, int $id, int $family)
    {
        $d = $r->validate(['id_number' => 'required|string']);
        $b = DB::table('distribution_beneficiaries')->where(['distribution_id' => $id, 'family_id' => $family])->first();
        abort_if(! $b, 404);
        if ($b->received) {
            return response()->json(['message' => 'already_received'], 409);
        }
        $real = DB::table('families')->where('id', $family)->value('id_number');
        if (! hash_equals((string) $real, $d['id_number'])) {
            Audit::log($r->user(), 'receipt_id_mismatch', 'distribution', $id, ['family_id' => $family]);
            return response()->json(['message' => 'id_mismatch'], 422);
        }
        DB::table('distribution_beneficiaries')->where('id', $b->id)->update([
            'received' => true, 'id_verified' => true, 'received_at' => now(), 'received_by_user' => $r->user()->id,
        ]);
        Audit::log($r->user(), 'receipt_confirmed', 'distribution', $id, ['family_id' => $family]);
        return response()->noContent();
    }

    public function assistanceTypes()
    {
        return DB::table('assistance_types')->where('is_active', true)->orderBy('id')->get();
    }
}
