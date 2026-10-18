<?php

namespace App\Http\Controllers;

use App\Support\Audit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ReportController extends Controller
{
    /** Dashboard numbers: always computed from real records. */
    public function dashboard(Request $r)
    {
        $u = $r->user();
        $fam = DB::table('families');
        if ($u->role->code === 'field_researcher') {
            $fam->where('created_by', $u->id);
        }
        return [
            'families' => (clone $fam)->where('status', '<>', 'archived')->count(),
            'camps' => DB::table('camps')->where('status', 'active')->count(),
            'members' => DB::table('family_members')->whereIn('family_id', (clone $fam)->select('id'))->count(),
            'projects_active' => DB::table('projects')->where('status', 'active')->count(),
            'distributions' => DB::table('distributions')->count(),
            'pending_review' => (clone $fam)->where('status', 'pending_review')->count(),
            'needs_correction' => (clone $fam)->where('status', 'needs_correction')->count(),
            'recent_activity' => $u->can('audit.view')
                ? DB::table('audit_logs')->orderByDesc('id')->limit(10)->get(['action', 'entity', 'entity_id', 'created_at']) : [],
        ];
    }

    public function familiesByCamp(Request $r)
    {
        $rows = DB::table('v_camp_stats')->orderBy('name')->get();
        if ($r->query('format') === 'csv') {
            return $this->csv($r, 'families_by_camp', ['camp_code', 'camp_name', 'families', 'members'],
                $rows->map(fn ($x) => [$x->code, $x->name, $x->families_count, $x->members_count])->all());
        }
        return $rows;
    }

    public function byStatus()
    {
        return DB::table('families')->select('status', DB::raw('count(*) as total'))->groupBy('status')->get();
    }

    public function incomplete()
    {
        return DB::table('families')->where('status', '<>', 'archived')
            ->whereNotExists(fn ($q) => $q->select(DB::raw(1))->from('family_members')->whereColumn('family_members.family_id', 'families.id'))
            ->select('id', 'family_no', 'head_name', 'status')->limit(200)->get();
    }

    public function researcherActivity(Request $r)
    {
        return DB::table('families')->join('users', 'users.id', '=', 'families.created_by')
            ->when($r->filled('from'), fn ($q) => $q->where('families.created_at', '>=', $r->from))
            ->when($r->filled('to'), fn ($q) => $q->where('families.created_at', '<=', $r->to))
            ->select('users.id', 'users.full_name', DB::raw('count(*) as families_created'))
            ->groupBy('users.id', 'users.full_name')->orderByDesc('families_created')->get();
    }

    public function projectStats()
    {
        return DB::table('v_project_stats')->orderBy('name')->get();
    }

    public function auditLog(Request $r)
    {
        return DB::table('audit_logs')->when($r->filled('entity'), fn ($q) => $q->where('entity', $r->entity))
            ->orderByDesc('id')->paginate(50);
    }

    /** Exports contain aggregates only (no names, IDs or phones) and every export is audited. */
    private function csv(Request $r, string $name, array $head, array $rows)
    {
        Audit::log($r->user(), 'export', 'report', null, ['report' => $name, 'rows' => count($rows)]);
        $safe = fn ($v) => preg_match('/^[=+\-@]/', (string) $v) ? "'".$v : $v;   // CSV formula injection guard
        return response()->streamDownload(function () use ($head, $rows, $safe) {
            $out = fopen('php://output', 'w');
            fwrite($out, "\xEF\xBB\xBF");
            fputcsv($out, $head);
            foreach ($rows as $row) {
                fputcsv($out, array_map($safe, $row));
            }
            fclose($out);
        }, $name.'.csv', ['Content-Type' => 'text/csv; charset=UTF-8']);
    }
}
