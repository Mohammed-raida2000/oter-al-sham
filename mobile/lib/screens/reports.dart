import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/i18n.dart';
import '../core/widgets.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  Widget section(BuildContext c, String titleKey, String path, String Function(Json) row) {
    return Card(
      child: ExpansionTile(
        title: Text(tr(c, titleKey), style: const TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.all(12),
        children: [
          SizedBox(
            height: 220,
            child: Loader<List<Json>>(
              fetch: (s) async => (await s.get(path) as List).map((e) => Json.from(e as Map)).toList(),
              builder: (c, rows, reload) => rows.isEmpty
                  ? Center(child: Text(tr(c, 'empty')))
                  : ListView(children: [for (final r in rows) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(row(r)))]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context;
    return Scaffold(
      appBar: AppBar(title: Text(tr(c, 'reports'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        section(c, 'r_by_camp', '/reports/families-by-camp', (r) => '${r['name']} — ${tr(c, 'families_count')}: ${r['families_count']} · ${tr(c, 'stat_members')}: ${r['members_count']}'),
        section(c, 'r_by_status', '/reports/families-by-status', (r) => '${tr(c, 's_${r['status']}')}: ${r['total']}'),
        section(c, 'r_incomplete', '/reports/incomplete', (r) => '${r['family_no']} — ${r['head_name']}'),
        section(c, 'r_researchers', '/reports/researchers', (r) => '${r['full_name']}: ${r['families_created']}'),
        section(c, 'r_projects', '/reports/projects', (r) => '${r['name']} — ${tr(c, 'distributions')}: ${r['distributions_count']} · ${tr(c, 'families_served')}: ${r['families_served']}'),
      ]),
    );
  }
}
