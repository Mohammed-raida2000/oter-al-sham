<?php

namespace App\Http\Controllers;

use App\Support\Audit;
use Illuminate\Database\QueryException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class FamilyController extends Controller
{
    private const ID_RULE = ['required', 'regex:/^[0-9]{9}$/'];   // ASSUMPTION: 9 digits, pending confirmation
    private const PHONE_RULE = ['required', 'regex:/^0[0-9]{9}$/'];

    private function present(object $f, $user): array
    {
        $a = (array) $f;
        if (! $user->can('family.sensitive')) {
            $a['id_number'] = Audit::maskId($a['id_number'] ?? null);
        }
        return $a;
    }

    private function scoped($user)
    {
        $q = DB::table('families')->join('camps', 'camps.id', '=', 'families.current_camp_id')
            ->select('families.*', 'camps.name as camp_name');
        // A researcher sees only the records they created.
        if ($user->role->code === 'field_researcher') {
            $q->where('families.created_by', $user->id);
        }
        return $q;
    }

    public function index(Request $r)
    {
        $q = $this->scoped($r->user());
        if ($r->filled('q')) {
            $s = $r->q;
            $q->where(fn ($w) => $w->where('families.head_name', 'ilike', "%$s%")
                ->orWhere('families.phone', $s)->orWhere('families.id_number', $s)->orWhere('families.family_no', $s));
        }
        foreach (['status' => 'families.status', 'camp_id' => 'families.current_camp_id'] as $in => $col) {
            if ($r->filled($in)) {
                $q->where($col, $r->$in);
            }
        }
        $page = $q->orderByDesc('families.id')->paginate(30);
        $page->getCollection()->transform(fn ($f) => $this->present($f, $r->user()));
        return $page;
    }

    /** Duplicate check before registering. Returns no personal data, only existence and the family number. */
    public function check(Request $r)
    {
        $r->validate(['id_number' => 'nullable|string', 'phone' => 'nullable|string']);
        $byId = $r->filled('id_number') ? DB::table('families')->where('id_number', $r->id_number)->value('family_no') : null;
        $byPhone = $r->filled('phone') ? DB::table('families')->where('phone', $r->phone)->count() : 0;
        return ['id_exists' => (bool) $byId, 'family_no' => $byId, 'phone_matches' => $byPhone];
    }

    public function show(Request $r, int $id)
    {
        $f = $this->scoped($r->user())->where('families.id', $id)->first();
        abort_if(! $f, 404);
        return [
            'family' => $this->present($f, $r->user()),
            'members' => DB::table('family_members')->where('family_id', $id)->orderBy('id')->get(),
            'needs' => DB::table('family_needs')->join('need_types', 'need_types.id', '=', 'family_needs.need_type_id')
                ->where('family_id', $id)->select('family_needs.*', 'need_types.name_ar', 'need_types.name_en')->get(),
            'camp_history' => DB::table('family_camp_history')->where('family_id', $id)->orderBy('moved_at')->get(),
            'reviews' => DB::table('family_reviews')->where('family_id', $id)->orderBy('reviewed_at')->get(),
        ];
    }

    public function store(Request $r)
    {
        $d = $r->validate([
            'head_name' => 'required|string|max:150',
            'id_number' => self::ID_RULE,
            'phone' => self::PHONE_RULE,
            'current_camp_id' => 'required|exists:camps,id',
            'governorate' => 'nullable|string|max:100', 'area' => 'nullable|string|max:100',
            'address_detail' => 'nullable|string',
        ]);
        try {
            $id = DB::table('families')->insertGetId($d + ['created_by' => $r->user()->id, 'created_at' => now(), 'updated_at' => now()]);
        } catch (QueryException $e) {
            if ($e->getCode() === '23505') {
                $existing = DB::table('families')->where('id_number', $d['id_number'])->value('family_no');
                return response()->json(['message' => 'duplicate_id_number', 'family_no' => $existing], 409);
            }
            throw $e;
        }
        Audit::log($r->user(), 'create', 'family', $id);
        return response()->json(['id' => $id], 201);
    }

    public function update(Request $r, int $id)
    {
        $f = DB::table('families')->find($id);
        abort_if(! $f, 404);
        $isAdmin = $r->user()->role->code === 'admin';
        if (! $isAdmin) {
            // Researchers edit only their own drafts or records returned for correction.
            abort_unless($f->created_by === $r->user()->id && in_array($f->status, ['draft', 'needs_correction'], true), 403);
        }
        $d = $r->validate([
            'head_name' => 'sometimes|string|max:150', 'id_number' => ['sometimes', 'regex:/^[0-9]{9}$/'],
            'phone' => ['sometimes', 'regex:/^0[0-9]{9}$/'], 'current_camp_id' => 'sometimes|exists:camps,id',
            'governorate' => 'nullable|string|max:100', 'area' => 'nullable|string|max:100', 'address_detail' => 'nullable|string',
        ]);
        try {
            DB::table('families')->where('id', $id)->update($d + ['updated_at' => now()]);
        } catch (QueryException $e) {
            if ($e->getCode() === '23505') {
                return response()->json(['message' => 'duplicate_id_number'], 409);
            }
            throw $e;
        }
        Audit::log($r->user(), 'update', 'family', $id, array_keys($d));
        return response()->noContent();
    }

    public function submit(Request $r, int $id)
    {
        $f = DB::table('families')->find($id);
        abort_if(! $f, 404);
        abort_unless($r->user()->role->code === 'admin' || $f->created_by === $r->user()->id, 403);
        if (! in_array($f->status, ['draft', 'needs_correction'], true)) {
            return response()->json(['message' => 'invalid_status'], 422);
        }
        if (DB::table('family_members')->where('family_id', $id)->doesntExist()) {
            return response()->json(['message' => 'members_required'], 422);
        }
        DB::table('families')->where('id', $id)->update(['status' => 'pending_review', 'updated_at' => now()]);
        Audit::log($r->user(), 'submit', 'family', $id);
        return response()->noContent();
    }

    public function review(Request $r, int $id)
    {
        $d = $r->validate(['decision' => 'required|in:approved,needs_correction', 'comment' => 'required_if:decision,needs_correction|nullable|string']);
        $f = DB::table('families')->find($id);
        abort_if(! $f, 404);
        if ($f->status !== 'pending_review') {
            return response()->json(['message' => 'not_pending_review'], 422);
        }
        if ($f->created_by === $r->user()->id) {
            return response()->json(['message' => 'cannot_review_own_record'], 403);
        }
        DB::transaction(function () use ($r, $id, $d) {
            DB::table('family_reviews')->insert(['family_id' => $id, 'reviewer_id' => $r->user()->id, 'decision' => $d['decision'], 'comment' => $d['comment'] ?? null, 'reviewed_at' => now()]);
            DB::table('families')->where('id', $id)->update(['status' => $d['decision'], 'updated_at' => now()]);
        });
        Audit::log($r->user(), 'review_'.$d['decision'], 'family', $id);
        return response()->noContent();
    }

    public function pending(Request $r)
    {
        return $this->scoped($r->user())->whereIn('families.status', ['pending_review'])->orderBy('families.updated_at')->paginate(30)
            ->through(fn ($f) => $this->present($f, $r->user()));
    }

    public function archive(Request $r, int $id)
    {
        abort_if(DB::table('families')->where('id', $id)->update(['status' => 'archived', 'updated_at' => now()]) === 0, 404);
        Audit::log($r->user(), 'archive', 'family', $id);
        return response()->noContent();
    }
}
