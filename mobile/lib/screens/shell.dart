import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/i18n.dart';
import '../core/widgets.dart';
import 'camps.dart';
import 'distributions.dart';
import 'families.dart';
import 'home.dart';
import 'projects.dart';
import 'settings.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final tabs = <(String, IconData, Widget)>[
      ('n_home', Icons.home_outlined, const HomePage()),
      if (s.can('camp.view')) ('n_camps', Icons.holiday_village_outlined, const CampsPage()),
      if (s.can('project.view')) ('n_projects', Icons.assignment_outlined, const ProjectsPage()),
      if (s.can('family.view')) ('n_families', Icons.groups_outlined, const FamiliesPage()),
      if (s.can('distribution.view')) ('n_dist', Icons.inventory_2_outlined, const DistributionsPage()),
    ];
    if (i >= tabs.length) i = 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, tabs[i].$1)),
        actions: [IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => go(context, const SettingsPage()))],
      ),
      body: tabs[i].$3,
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (v) => setState(() => i = v),
        destinations: [for (final t in tabs) NavigationDestination(icon: Icon(t.$2), label: tr(context, t.$1))],
      ),
    );
  }
}
