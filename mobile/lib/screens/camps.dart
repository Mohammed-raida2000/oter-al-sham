import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/i18n.dart';
import '../core/widgets.dart';

class CampsPage extends StatefulWidget {
  final bool standalone;
  const CampsPage({super.key, this.standalone = false});
  @override
  State<CampsPage> createState() => _CampsPageState();
}

class _CampsPageState extends State<CampsPage> {
  String q = '';
  final list = GlobalKey<PagedListState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.standalone ? AppBar(title: Text(tr(context, 'n_camps'))) : null,
      floatingActionButton: st(context).can('camp.manage')
          ? FloatingActionButton.extended(
              onPressed: () async {
                if (await go<bool>(context, const CampForm()) == true) list.currentState?.load(reset: true);
              },
              icon: const Icon(Icons.add),
              label: Text(tr(context, 'add_camp')))
          : null,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: tr(context, 'search'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            onSubmitted: (v) => setState(() => q = v.trim()),
          ),
        ),
        Expanded(
          child: PagedList(
            key: list,
            path: '/camps',
            query: {'q': q},
            item: (c, it) => tile(c, '${it['name']}',
                sub: '${it['code']} · ${it['area']} · ${tr(c, 'families_count')}: ${it['families_count'] ?? 0}',
                icon: Icons.holiday_village_outlined,
                trailing: statusChip(c, '${it['status']}'),
                onTap: () => go(c, CampDetail(id: it['id'] as int))),
          ),
        ),
      ]),
    );
  }
}

class CampDetail extends StatelessWidget {
  final int id;
  const CampDetail({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'camp_details'))),
      body: Loader<Json>(
        fetch: (s) async => Json.from(await s.get('/camps/$id') as Map),
        builder: (c, d, reload) {
          final camp = Json.from(d['camp'] as Map);
          final stats = d['stats'] == null ? <String, dynamic>{} : Json.from(d['stats'] as Map);
          final projects = (d['projects'] as List);
          final dists = (d['distributions'] as List);
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('${camp['name']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            kv(tr(c, 'code'), '${camp['code']}'),
            kv(tr(c, 'governorate'), '${camp['governorate']}'),
            kv(tr(c, 'area'), '${camp['area']}'),
            kv(tr(c, 'address'), camp['address_detail'] as String?),
            kv(tr(c, 'rep_name'), camp['representative_name'] as String?),
            kv(tr(c, 'rep_phone'), camp['representative_phone'] as String?),
            kv(tr(c, 'families_count'), '${stats['families_count'] ?? 0}'),
            kv(tr(c, 'stat_members'), '${stats['members_count'] ?? 0}'),
            sectionTitle(tr(c, 'projects')),
            for (final p in projects) tile(c, '${p['name']}', sub: '${p['code']}', icon: Icons.assignment_outlined),
            sectionTitle(tr(c, 'distributions')),
            for (final x in dists) tile(c, '${x['title']}', sub: '${x['planned_on']}', icon: Icons.inventory_2_outlined, trailing: statusChip(c, '${x['status']}')),
          ]);
        },
      ),
    );
  }
}

class CampForm extends StatefulWidget {
  const CampForm({super.key});
  @override
  State<CampForm> createState() => _CampFormState();
}

class _CampFormState extends State<CampForm> {
  final key = GlobalKey<FormState>();
  final code = TextEditingController(), name = TextEditingController(), gov = TextEditingController(), area = TextEditingController();
  final addr = TextEditingController(), rep = TextEditingController(), repPhone = TextEditingController();
  bool busy = false;

  Future<void> save({bool confirmSimilar = false}) async {
    if (!key.currentState!.validate()) return;
    setState(() => busy = true);
    final s = st(context);
    try {
      await s.post('/camps', {
        'code': code.text.trim(), 'name': name.text.trim(), 'governorate': gov.text.trim(), 'area': area.text.trim(),
        'address_detail': addr.text.trim(), 'representative_name': rep.text.trim(), 'representative_phone': repPhone.text.trim(),
        if (confirmSimilar) 'confirm_similar': true,
      });
      if (!mounted) return;
      toast(context, tr(context, 'saved'));
      Navigator.pop(context, true);
      return;
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 409 && e.message == 'similar_names_exist') {
        final names = ((e.body['similar'] as List?) ?? const []).map((x) => '• ${x['name']} (${x['code']})').join('\n');
        final ok = await askYesNo(context, tr(context, 'similar_title'), '$names\n\n${tr(context, 'similar_body')}');
        if (ok && mounted) {
          setState(() => busy = false);
          return save(confirmSimilar: true);
        }
      } else {
        toast(context, errMsg(context, e));
      }
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context;
    return Scaffold(
      appBar: AppBar(title: Text(tr(c, 'add_camp'))),
      body: Form(
        key: key,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          field(c, code, tr(c, 'code'), req: true),
          field(c, name, tr(c, 'name'), req: true),
          field(c, gov, tr(c, 'governorate'), req: true),
          field(c, area, tr(c, 'area'), req: true),
          field(c, addr, tr(c, 'address'), lines: 2),
          field(c, rep, tr(c, 'rep_name')),
          field(c, repPhone, tr(c, 'rep_phone'), type: TextInputType.phone),
          FilledButton(onPressed: busy ? null : () => save(), child: Text(tr(c, 'save'))),
        ]),
      ),
    );
  }
}
