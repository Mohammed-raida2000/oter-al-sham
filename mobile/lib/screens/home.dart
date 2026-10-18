import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/i18n.dart';
import '../core/widgets.dart';
import 'camps.dart';
import 'distributions.dart';
import 'families.dart';
import 'reports.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = st(context);
    return Loader<Json>(
      fetch: (s) async => Json.from(await s.get('/dashboard') as Map),
      builder: (c, d, reload) {
        final stats = [
          ('stat_families', d['families']),
          ('stat_camps', d['camps']),
          ('stat_members', d['members']),
          ('stat_projects', d['projects_active']),
          ('stat_dist', d['distributions']),
          ('stat_pending', d['pending_review']),
          ('stat_correction', d['needs_correction']),
        ];
        final recent = (d['recent_activity'] as List?) ?? const [];
        return RefreshIndicator(
          onRefresh: () async => reload(),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text('${tr(c, 'welcome')} ${s.user?['full_name'] ?? ''}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.7,
              children: [
                for (final e in stats)
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(tr(c, e.$1), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('${e.$2 ?? 0}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
              ],
            ),
            sectionTitle(tr(c, 'quick')),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (s.can('family.create')) FilledButton.icon(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => go(c, const FamilyWizard()), icon: const Icon(Icons.person_add_alt), label: Text(tr(c, 'add_family'))),
              if (s.can('family.view')) FilledButton.tonalIcon(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => go(c, const FamiliesPage(standalone: true)), icon: const Icon(Icons.search), label: Text(tr(c, 'find_family'))),
              if (s.can('camp.view')) FilledButton.tonalIcon(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => go(c, const CampsPage(standalone: true)), icon: const Icon(Icons.holiday_village_outlined), label: Text(tr(c, 'view_camps'))),
              if (s.can('distribution.manage')) FilledButton.tonalIcon(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => go(c, const DistributionForm()), icon: const Icon(Icons.inventory_2_outlined), label: Text(tr(c, 'log_dist'))),
              if (s.can('family.review')) FilledButton.tonalIcon(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => go(c, const ReviewQueue()), icon: const Icon(Icons.fact_check_outlined), label: Text(tr(c, 'review_records'))),
              if (s.can('report.view')) FilledButton.tonalIcon(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => go(c, const ReportsPage()), icon: const Icon(Icons.bar_chart), label: Text(tr(c, 'reports'))),
            ]),
            if (recent.isNotEmpty) ...[
              sectionTitle(tr(c, 'recent')),
              for (final r in recent) tile(c, '${r['action']} · ${r['entity']}', sub: '${r['created_at']}', icon: Icons.history),
            ],
          ]),
        );
      },
    );
  }
}
