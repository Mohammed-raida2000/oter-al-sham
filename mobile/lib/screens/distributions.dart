import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/i18n.dart';
import '../core/widgets.dart';

class DistributionsPage extends StatefulWidget {
  const DistributionsPage({super.key});
  @override
  State<DistributionsPage> createState() => _DistributionsPageState();
}

class _DistributionsPageState extends State<DistributionsPage> {
  final list = GlobalKey<PagedListState>();

  @override
  Widget build(BuildContext context) {
    final c = context;
    return Scaffold(
      floatingActionButton: st(c).can('distribution.manage')
          ? FloatingActionButton.extended(
              onPressed: () async {
                if (await go<bool>(c, const DistributionForm()) == true) list.currentState?.load(reset: true);
              },
              icon: const Icon(Icons.add),
              label: Text(tr(c, 'log_dist')))
          : null,
      body: PagedList(
        key: list,
        path: '/distributions',
        item: (c, it) => tile(c, '${it['title']}',
            sub: '${it['project']} · ${it['camp']}\n${it['assistance']} · ${it['planned_on']}',
            icon: Icons.inventory_2_outlined,
            trailing: statusChip(c, '${it['status']}'),
            onTap: () async {
              await go(c, DistributionDetail(id: it['id'] as int));
              list.currentState?.load(reset: true);
            }),
      ),
    );
  }
}

class DistributionDetail extends StatelessWidget {
  final int id;
  const DistributionDetail({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'dist_details'))),
      body: Loader<Json>(
        fetch: (s) async => Json.from(await s.get('/distributions/$id') as Map),
        builder: (c, d, reload) {
          final s = st(c);
          final x = Json.from(d['distribution'] as Map);
          final counts = Json.from(d['counts'] as Map);
          final ben = (d['beneficiaries'] as List).map((e) => Json.from(e as Map)).toList();
          Future<void> act(Future<void> Function() fn) async {
            try {
              await fn();
              reload();
            } catch (e) {
              if (c.mounted) toast(c, errMsg(c, e));
            }
          }

          return ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              Expanded(child: Text('${x['title']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
              statusChip(c, '${x['status']}'),
            ]),
            const SizedBox(height: 8),
            kv(tr(c, 'planned_on'), '${x['planned_on']}'),
            kv(tr(c, 'mode'), x['mode'] == 'full_documentation' ? tr(c, 'mode_full') : tr(c, 'mode_names')),
            kv(tr(c, 'team'), x['responsible_team'] as String?),
            kv(tr(c, 'notes'), x['notes'] as String?),
            kv(tr(c, 'total'), '${counts['total']}'),
            kv(tr(c, 'received_count'), '${counts['received']}'),
            if (s.can('distribution.manage'))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 8, children: [
                  for (final st2 in ['scheduled', 'in_progress', 'completed', 'cancelled'])
                    ActionChip(label: Text(tr(c, 's_$st2')), onPressed: () => act(() async { await s.patch('/distributions/$id/status', {'status': st2}); })),
                ]),
              ),
            if ((d['items'] as List).isNotEmpty) sectionTitle(tr(c, 'items')),
            for (final it in d['items'] as List) tile(c, '${it['item_name']}', sub: '${it['quantity_per_family']} ${it['unit'] ?? ''}', icon: Icons.category_outlined),
            sectionTitle('${tr(c, 'beneficiaries')} (${ben.length})'),
            if (s.can('distribution.manage'))
              OutlinedButton.icon(
                onPressed: () async {
                  final no = await askText(c, tr(c, 'add_beneficiary'), hint: 'F-000001');
                  if (no == null || no.isEmpty) return;
                  await act(() async { await s.post('/distributions/$id/beneficiaries', {'family_no': no}); });
                },
                icon: const Icon(Icons.person_add_alt),
                label: Text(tr(c, 'add_beneficiary')),
              ),
            const SizedBox(height: 8),
            for (final b in ben)
              Card(
                child: ListTile(
                  title: Text('${b['head_name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${b['family_no']} · ${b['received'] == true ? tr(c, 'received') : tr(c, 'not_received')}'),
                  trailing: b['received'] == true
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          if (s.can('distribution.receive'))
                            FilledButton(
                              style: FilledButton.styleFrom(minimumSize: const Size(80, 38)),
                              onPressed: () async {
                                final idn = await askText(c, tr(c, 'receive_hint'), hint: tr(c, 'id_hint'), digits: true, maxLen: 9);
                                if (idn == null || idn.isEmpty) return;
                                await act(() async {
                                  await s.post('/distributions/$id/beneficiaries/${b['family_id']}/receive', {'id_number': idn});
                                  if (c.mounted) toast(c, tr(c, 'received'));
                                });
                              },
                              child: Text(tr(c, 'receive')),
                            ),
                          if (s.can('distribution.manage'))
                            IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => act(() async { await s.del('/distributions/$id/beneficiaries/${b['family_id']}'); })),
                        ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class DistributionForm extends StatefulWidget {
  const DistributionForm({super.key});
  @override
  State<DistributionForm> createState() => _DistributionFormState();
}

class _DistributionFormState extends State<DistributionForm> {
  final key = GlobalKey<FormState>();
  final title = TextEditingController(), team = TextEditingController(), notes = TextEditingController();
  Json? project, camp;
  int? assistance;
  String mode = 'names_only';
  String? date;
  List<Json> types = [];
  final items = <Json>[];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    st(context).get('/assistance-types').then((r) {
      if (mounted) setState(() => types = (r as List).map((x) => Json.from(x as Map)).toList());
    }).catchError((_) {});
  }

  Future<void> addItem() async {
    final c = context;
    final n = TextEditingController(), q = TextEditingController(), u = TextEditingController();
    final ok = await showDialog<bool>(
      context: c,
      builder: (ctx) => AlertDialog(
        title: Text(tr(c, 'items')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: n, decoration: InputDecoration(labelText: tr(c, 'item_name'))),
          TextField(controller: q, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr(c, 'quantity'))),
          TextField(controller: u, decoration: InputDecoration(labelText: tr(c, 'unit'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr(c, 'cancel'))),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(90, 40)), onPressed: () => Navigator.pop(ctx, true), child: Text(tr(c, 'add'))),
        ],
      ),
    );
    final qty = double.tryParse(q.text.trim());
    if (ok == true && n.text.trim().isNotEmpty && qty != null && qty > 0) {
      setState(() => items.add({'item_name': n.text.trim(), 'quantity_per_family': qty, 'unit': u.text.trim()}));
    }
  }

  Future<void> save() async {
    final c = context;
    if (!key.currentState!.validate()) return;
    if (project == null) return toast(c, tr(c, 'pick_project'));
    if (camp == null) return toast(c, tr(c, 'pick_camp'));
    if (assistance == null || date == null) return toast(c, tr(c, 'required'));
    if (mode == 'full_documentation' && items.isEmpty) return toast(c, tr(c, 'items'));
    setState(() => busy = true);
    try {
      await st(c).post('/distributions', {
        'title': title.text.trim(), 'project_id': project!['id'], 'camp_id': camp!['id'], 'assistance_type_id': assistance,
        'mode': mode, 'planned_on': date, 'responsible_team': team.text.trim(), 'notes': notes.text.trim(),
        if (mode == 'full_documentation') 'items': items,
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
      appBar: AppBar(title: Text(tr(c, 'new_dist'))),
      body: Form(
        key: key,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          field(c, title, tr(c, 'title'), req: true),
          Card(child: ListTile(leading: const Icon(Icons.assignment_outlined), title: Text(project == null ? '${tr(c, 'pick_project')} *' : '${project!['name']}'), trailing: const Icon(Icons.chevron_right), onTap: () async {
            final r = await go<Json>(c, PickerPage(titleKey: 'pick_project', path: '/projects', label: (x) => '${x['name']}', sub: (x) => '${x['code']}'));
            if (r != null) setState(() => project = r);
          })),
          Card(child: ListTile(leading: const Icon(Icons.holiday_village_outlined), title: Text(camp == null ? '${tr(c, 'pick_camp')} *' : '${camp!['name']}'), trailing: const Icon(Icons.chevron_right), onTap: () async {
            final r = await go<Json>(c, PickerPage(titleKey: 'pick_camp', path: '/camps', label: (x) => '${x['name']}', sub: (x) => '${x['code']}'));
            if (r != null) setState(() => camp = r);
          })),
          DropdownButtonFormField<int>(
            value: assistance,
            decoration: InputDecoration(labelText: '${tr(c, 'assistance')} *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            items: [for (final t in types) DropdownMenuItem(value: t['id'] as int, child: Text('${t['name_ar']}'))],
            onChanged: (v) => setState(() => assistance = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: mode,
            decoration: InputDecoration(labelText: tr(c, 'mode'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            items: [DropdownMenuItem(value: 'names_only', child: Text(tr(c, 'mode_names'))), DropdownMenuItem(value: 'full_documentation', child: Text(tr(c, 'mode_full')))],
            onChanged: (v) => setState(() => mode = v ?? 'names_only'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () async { final d = await pickDate(c); if (d != null) setState(() => date = d); }, child: Text(date ?? '${tr(c, 'planned_on')} *')),
          const SizedBox(height: 12),
          field(c, team, tr(c, 'team')),
          field(c, notes, tr(c, 'notes'), lines: 2),
          if (mode == 'full_documentation') ...[
            sectionTitle(tr(c, 'items')),
            for (final it in items) tile(c, '${it['item_name']}', sub: '${it['quantity_per_family']} ${it['unit']}', icon: Icons.category_outlined, trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => items.remove(it)))),
            OutlinedButton.icon(onPressed: addItem, icon: const Icon(Icons.add), label: Text(tr(c, 'add'))),
          ],
          const SizedBox(height: 12),
          FilledButton(onPressed: busy ? null : save, child: Text(tr(c, 'save'))),
        ]),
      ),
    );
  }
}
