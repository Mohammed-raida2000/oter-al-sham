import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/i18n.dart';
import '../core/widgets.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});
  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  String q = '';
  final list = GlobalKey<PagedListState>();

  @override
  Widget build(BuildContext context) {
    final c = context;
    return Scaffold(
      floatingActionButton: st(c).can('project.manage')
          ? FloatingActionButton.extended(
              onPressed: () async {
                if (await go<bool>(c, const ProjectForm()) == true) list.currentState?.load(reset: true);
              },
              icon: const Icon(Icons.add),
              label: Text(tr(c, 'new_project')))
          : null,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: tr(c, 'search'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            onSubmitted: (v) => setState(() => q = v.trim()),
          ),
        ),
        Expanded(
          child: PagedList(
            key: list,
            path: '/projects',
            query: {'q': q},
            item: (c, it) => tile(c, '${it['name']}',
                sub: '${it['code']} · ${it['project_type']}\n${it['starts_on'] ?? ''} – ${it['ends_on'] ?? ''}',
                icon: Icons.assignment_outlined,
                trailing: statusChip(c, '${it['status']}'),
                onTap: () => go(c, ProjectDetail(id: it['id'] as int))),
          ),
        ),
      ]),
    );
  }
}

class ProjectDetail extends StatelessWidget {
  final int id;
  const ProjectDetail({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'project_details'))),
      body: Loader<Json>(
        fetch: (s) async => Json.from(await s.get('/projects/$id') as Map),
        builder: (c, d, reload) {
          final p = Json.from(d['project'] as Map);
          final stats = d['stats'] == null ? <String, dynamic>{} : Json.from(d['stats'] as Map);
          return ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              Expanded(child: Text('${p['name']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
              statusChip(c, '${p['status']}'),
            ]),
            const SizedBox(height: 8),
            kv(tr(c, 'code'), '${p['code']}'),
            kv(tr(c, 'project_type'), '${p['project_type']}'),
            kv(tr(c, 'description'), p['description'] as String?),
            kv(tr(c, 'starts_on'), p['starts_on'] as String?),
            kv(tr(c, 'ends_on'), p['ends_on'] as String?),
            kv(tr(c, 'target_count'), '${p['target_family_count'] ?? ''}'),
            kv(tr(c, 'families_served'), '${stats['families_served'] ?? 0}'),
            kv(tr(c, 'distributions'), '${stats['distributions_count'] ?? 0}'),
            sectionTitle(tr(c, 'target_camps')),
            for (final k in d['camps'] as List) tile(c, '${k['name']}', sub: '${k['code']}', icon: Icons.holiday_village_outlined),
            sectionTitle(tr(c, 'distributions')),
            for (final x in d['distributions'] as List) tile(c, '${x['title']}', sub: '${x['planned_on']}', icon: Icons.inventory_2_outlined, trailing: statusChip(c, '${x['status']}')),
          ]);
        },
      ),
    );
  }
}

class ProjectForm extends StatefulWidget {
  const ProjectForm({super.key});
  @override
  State<ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends State<ProjectForm> {
  final key = GlobalKey<FormState>();
  final code = TextEditingController(), name = TextEditingController(), type = TextEditingController();
  final desc = TextEditingController(), target = TextEditingController();
  String? starts, ends;
  final camps = <Json>[];
  bool busy = false;

  Future<void> save() async {
    if (!key.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await st(context).post('/projects', {
        'code': code.text.trim(), 'name': name.text.trim(), 'project_type': type.text.trim(),
        'description': desc.text.trim(), 'starts_on': starts, 'ends_on': ends,
        if (target.text.trim().isNotEmpty) 'target_family_count': int.tryParse(target.text.trim()),
        'camp_ids': [for (final k in camps) k['id']],
      });
      if (!mounted) return;
      toast(context, tr(context, 'saved'));
      Navigator.pop(context, true);
      return;
    } catch (e) {
      if (mounted) toast(context, errMsg(context, e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context;
    return Scaffold(
      appBar: AppBar(title: Text(tr(c, 'new_project'))),
      body: Form(
        key: key,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          field(c, code, tr(c, 'code'), req: true),
          field(c, name, tr(c, 'name'), req: true),
          field(c, type, tr(c, 'project_type'), req: true),
          field(c, desc, tr(c, 'description'), lines: 3),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () async { final d = await pickDate(c); if (d != null) setState(() => starts = d); }, child: Text(starts ?? tr(c, 'starts_on')))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () async { final d = await pickDate(c); if (d != null) setState(() => ends = d); }, child: Text(ends ?? tr(c, 'ends_on')))),
          ]),
          const SizedBox(height: 12),
          field(c, target, tr(c, 'target_count'), type: TextInputType.number),
          sectionTitle(tr(c, 'target_camps')),
          Wrap(spacing: 6, children: [for (final k in camps) Chip(label: Text('${k['name']}'), onDeleted: () => setState(() => camps.remove(k)))]),
          TextButton.icon(
            onPressed: () async {
              final r = await go<Json>(c, PickerPage(titleKey: 'pick_camp', path: '/camps', label: (x) => '${x['name']}', sub: (x) => '${x['code']}'));
              if (r != null && !camps.any((k) => k['id'] == r['id'])) setState(() => camps.add(r));
            },
            icon: const Icon(Icons.add),
            label: Text(tr(c, 'add')),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: busy ? null : save, child: Text(tr(c, 'save'))),
        ]),
      ),
    );
  }
}
