import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/i18n.dart';
import '../core/widgets.dart';

class FamiliesPage extends StatefulWidget {
  final bool standalone;
  const FamiliesPage({super.key, this.standalone = false});
  @override
  State<FamiliesPage> createState() => _FamiliesPageState();
}

class _FamiliesPageState extends State<FamiliesPage> {
  String q = '', status = '';
  final list = GlobalKey<PagedListState>();

  @override
  Widget build(BuildContext context) {
    final c = context;
    return Scaffold(
      appBar: widget.standalone ? AppBar(title: Text(tr(c, 'n_families'))) : null,
      floatingActionButton: st(c).can('family.create')
          ? FloatingActionButton.extended(
              onPressed: () async {
                await go(c, const FamilyWizard());
                list.currentState?.load(reset: true);
              },
              icon: const Icon(Icons.add),
              label: Text(tr(c, 'add_family')))
          : null,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: '${tr(c, 'head_name')} / ${tr(c, 'phone')} / ${tr(c, 'id_number')}', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            onSubmitted: (v) => setState(() => q = v.trim()),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (final s in ['', 'draft', 'pending_review', 'needs_correction', 'approved'])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(label: Text(s.isEmpty ? tr(c, 'all') : tr(c, 's_$s')), selected: status == s, onSelected: (_) => setState(() => status = s)),
              ),
          ]),
        ),
        Expanded(
          child: PagedList(
            key: list,
            path: '/families',
            query: {'q': q, if (status.isNotEmpty) 'status': status},
            item: (c, it) => tile(c, '${it['head_name']}',
                sub: '${it['family_no']} · ${it['camp_name']}',
                icon: Icons.groups_outlined,
                trailing: statusChip(c, '${it['status']}'),
                onTap: () async {
                  await go(c, FamilyDetail(id: it['id'] as int));
                  list.currentState?.load(reset: true);
                }),
          ),
        ),
      ]),
    );
  }
}

class ReviewQueue extends StatelessWidget {
  const ReviewQueue({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'pending_reviews'))),
      body: PagedList(
        path: '/reviews/pending',
        item: (c, it) => tile(c, '${it['head_name']}', sub: '${it['family_no']} · ${it['camp_name']}', icon: Icons.fact_check_outlined, trailing: statusChip(c, '${it['status']}'), onTap: () => go(c, FamilyDetail(id: it['id'] as int))),
      ),
    );
  }
}

class FamilyDetail extends StatelessWidget {
  final int id;
  const FamilyDetail({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'family_profile'))),
      body: Loader<Json>(
        fetch: (s) async => Json.from(await s.get('/families/$id') as Map),
        builder: (c, d, reload) {
          final s = st(c);
          final f = Json.from(d['family'] as Map);
          final status = '${f['status']}';
          final members = (d['members'] as List).map((e) => Json.from(e as Map)).toList();
          final needs = (d['needs'] as List).map((e) => Json.from(e as Map)).toList();
          final history = d['camp_history'] as List;
          final reviews = d['reviews'] as List;
          final mine = f['created_by'] == s.user?['id'];
          final editable = s.can('family.update') && (s.role == 'admin' || (mine && (status == 'draft' || status == 'needs_correction')));
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
              Expanded(child: Text('${f['head_name']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
              statusChip(c, status),
            ]),
            const SizedBox(height: 8),
            kv(tr(c, 'family_no'), '${f['family_no']}'),
            kv(tr(c, 'id_number'), f['id_number'] as String?),
            kv(tr(c, 'phone'), f['phone'] as String?),
            kv(tr(c, 'camp'), f['camp_name'] as String?),
            kv(tr(c, 'address'), f['address_detail'] as String?),
            const SizedBox(height: 8),
            if (editable) OutlinedButton.icon(onPressed: () async { await go(c, FamilyWizard(existing: d)); reload(); }, icon: const Icon(Icons.edit_outlined), label: Text(tr(c, 'edit'))),
            if (editable && (status == 'draft' || status == 'needs_correction'))
              Padding(padding: const EdgeInsets.only(top: 8), child: FilledButton(onPressed: () => act(() async { await s.post('/families/$id/submit'); if (c.mounted) toast(c, tr(c, 'done')); }), child: Text(tr(c, 'submit_review')))),
            if (s.can('family.review') && status == 'pending_review') ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: FilledButton(onPressed: () => act(() async { await s.post('/families/$id/review', {'decision': 'approved'}); }), child: Text(tr(c, 'approve')))),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    onPressed: () async {
                      final r = await askText(c, tr(c, 'comment'));
                      if (r == null || r.isEmpty) return;
                      await act(() async { await s.post('/families/$id/review', {'decision': 'needs_correction', 'comment': r}); });
                    },
                    child: Text(tr(c, 'return_corr')),
                  ),
                ),
              ]),
            ],
            sectionTitle('${tr(c, 'members')} (${members.length})'),
            for (final m in members) tile(c, '${m['full_name']}', sub: '${m['relation']} · ${m['birth_date'] ?? ''}', icon: Icons.person_outline),
            sectionTitle('${tr(c, 'needs')} (${needs.length})'),
            for (final n in needs) tile(c, '${n['name_ar']}', sub: '${n['notes'] ?? ''}', icon: Icons.volunteer_activism_outlined, trailing: Text('${n['status']}')),
            sectionTitle(tr(c, 'camp_history')),
            for (final h in history) tile(c, '${h['from_camp_id'] ?? '—'} → ${h['to_camp_id']}', sub: '${h['moved_at']}', icon: Icons.history),
            if (reviews.isNotEmpty) sectionTitle(tr(c, 'reviews')),
            for (final r in reviews) tile(c, '${r['decision']}', sub: '${r['comment'] ?? ''} · ${r['reviewed_at']}', icon: Icons.fact_check_outlined),
          ]);
        },
      ),
    );
  }
}

/// 4 steps: data -> members -> needs -> review. Creates a draft at step 1 and edits it through the API.
class FamilyWizard extends StatefulWidget {
  final Json? existing; // response of GET /families/{id}
  const FamilyWizard({super.key, this.existing});
  @override
  State<FamilyWizard> createState() => _FamilyWizardState();
}

class _FamilyWizardState extends State<FamilyWizard> {
  final key1 = GlobalKey<FormState>();
  final head = TextEditingController(), idn = TextEditingController(), phone = TextEditingController(), addr = TextEditingController();
  Json? camp;
  int? familyId;
  int step = 0;
  bool busy = false;
  final members = <Json>[];
  final needs = <Json>[];
  List<Json> needTypes = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      final f = Json.from(e['family'] as Map);
      familyId = f['id'] as int;
      head.text = '${f['head_name']}';
      final id = '${f['id_number'] ?? ''}';
      idn.text = RegExp(r'^[0-9]{9}$').hasMatch(id) ? id : '';
      phone.text = '${f['phone'] ?? ''}';
      addr.text = '${f['address_detail'] ?? ''}';
      camp = {'id': f['current_camp_id'], 'name': f['camp_name']};
      members.addAll((e['members'] as List).map((x) => Json.from(x as Map)));
      needs.addAll((e['needs'] as List).map((x) => Json.from(x as Map)));
    }
    st(context).get('/need-types').then((r) {
      if (mounted) setState(() => needTypes = (r as List).map((x) => Json.from(x as Map)).toList());
    }).catchError((_) {});
  }

  Future<void> run(Future<void> Function() fn) async {
    setState(() => busy = true);
    try {
      await fn();
    } catch (e) {
      if (mounted) toast(context, errMsg(context, e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> saveData() async {
    if (!key1.currentState!.validate()) return;
    final c = context;
    if (!RegExp(r'^[0-9]{9}$').hasMatch(idn.text.trim())) return toast(c, tr(c, 'bad_id'));
    if (!RegExp(r'^0[0-9]{9}$').hasMatch(phone.text.trim())) return toast(c, tr(c, 'bad_phone'));
    if (camp == null) return toast(c, tr(c, 'pick_camp'));
    await run(() async {
      final s = st(c);
      if (familyId == null) {
        final chk = Json.from(await s.get('/families/check', q: {'id_number': idn.text.trim(), 'phone': phone.text.trim()}) as Map);
        if (chk['id_exists'] == true) {
          if (c.mounted) toast(c, '${tr(c, 'id_exists')} ${chk['family_no']}');
          return;
        }
        if ((chk['phone_matches'] ?? 0) > 0) {
          if (!c.mounted || !await askYesNo(c, tr(c, 'phone'), tr(c, 'phone_exists'))) return;
        }
      }
      final body = {
        'head_name': head.text.trim(), 'id_number': idn.text.trim(), 'phone': phone.text.trim(),
        'current_camp_id': camp!['id'], 'address_detail': addr.text.trim(),
      };
      if (familyId == null) {
        final r = await s.post('/families', body) as Map;
        familyId = r['id'] as int;
      } else {
        await s.patch('/families/$familyId', body);
      }
      if (mounted) setState(() => step = 1);
    });
  }

  Future<void> addMember() async {
    final c = context;
    final name = TextEditingController(), rel = TextEditingController();
    String? birth;
    final ok = await showDialog<bool>(
      context: c,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(tr(c, 'add_member')),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: InputDecoration(labelText: tr(c, 'member_name'))),
              TextField(controller: rel, decoration: InputDecoration(labelText: tr(c, 'relation'))),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () async { final d = await pickDate(ctx); if (d != null) setD(() => birth = d); }, child: Text(birth ?? tr(c, 'birth_date'))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr(c, 'cancel'))),
            FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(90, 40)), onPressed: () => Navigator.pop(ctx, true), child: Text(tr(c, 'add'))),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty || rel.text.trim().isEmpty) return;
    await run(() async {
      final r = await st(c).post('/families/$familyId/members', {'full_name': name.text.trim(), 'relation': rel.text.trim(), if (birth != null) 'birth_date': birth}) as Map;
      setState(() => members.add({'id': r['id'], 'full_name': name.text.trim(), 'relation': rel.text.trim(), 'birth_date': birth}));
    });
  }

  Future<void> addNeed() async {
    final c = context;
    int? typeId;
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: c,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(tr(c, 'add_need')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(
              value: typeId,
              hint: Text(tr(c, 'need_type')),
              items: [for (final t in needTypes) DropdownMenuItem(value: t['id'] as int, child: Text('${t['name_ar']}'))],
              onChanged: (v) => setD(() => typeId = v),
            ),
            TextField(controller: notes, decoration: InputDecoration(labelText: tr(c, 'notes'))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr(c, 'cancel'))),
            FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(90, 40)), onPressed: () => Navigator.pop(ctx, true), child: Text(tr(c, 'add'))),
          ],
        ),
      ),
    );
    if (ok != true || typeId == null) return;
    await run(() async {
      final r = await st(c).post('/families/$familyId/needs', {'need_type_id': typeId, 'notes': notes.text.trim()}) as Map;
      final nm = needTypes.firstWhere((t) => t['id'] == typeId)['name_ar'];
      setState(() => needs.add({'id': r['id'], 'name_ar': nm, 'notes': notes.text.trim()}));
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context;
    final labels = ['step_data', 'step_members', 'step_needs', 'step_review'];
    Widget body;
    switch (step) {
      case 0:
        body = Form(
          key: key1,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            field(c, head, tr(c, 'head_name'), req: true),
            field(c, idn, tr(c, 'id_number'), req: true, type: TextInputType.number, maxLen: 9, hint: tr(c, 'id_hint')),
            field(c, phone, tr(c, 'phone'), req: true, type: TextInputType.phone, maxLen: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.holiday_village_outlined),
                title: Text(camp == null ? '${tr(c, 'pick_camp')} *' : '${camp!['name']}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final r = await go<Json>(c, PickerPage(titleKey: 'pick_camp', path: '/camps', label: (x) => '${x['name']}', sub: (x) => '${x['code']} · ${x['area']}'));
                  if (r != null) setState(() => camp = r);
                },
              ),
            ),
            field(c, addr, tr(c, 'address'), lines: 2),
            Text(tr(c, 'both_required'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        );
        break;
      case 1:
        body = ListView(padding: const EdgeInsets.all(16), children: [
          for (final m in members)
            tile(c, '${m['full_name']}', sub: '${m['relation']} · ${m['birth_date'] ?? ''}', icon: Icons.person_outline,
                trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: busy ? null : () => run(() async { await st(c).del('/families/$familyId/members/${m['id']}'); setState(() => members.remove(m)); }))),
          OutlinedButton.icon(onPressed: busy ? null : addMember, icon: const Icon(Icons.add), label: Text(tr(c, 'add_member'))),
        ]);
        break;
      case 2:
        body = ListView(padding: const EdgeInsets.all(16), children: [
          for (final n in needs) tile(c, '${n['name_ar']}', sub: '${n['notes'] ?? ''}', icon: Icons.volunteer_activism_outlined),
          OutlinedButton.icon(onPressed: busy ? null : addNeed, icon: const Icon(Icons.add), label: Text(tr(c, 'add_need'))),
        ]);
        break;
      default:
        body = ListView(padding: const EdgeInsets.all(16), children: [
          tile(c, head.text, sub: '${tr(c, 'id_number')}: ${idn.text} · ${phone.text}', icon: Icons.groups_outlined),
          tile(c, '${tr(c, 'members')}: ${members.length}', icon: Icons.person_outline),
          tile(c, '${tr(c, 'needs')}: ${needs.length}', icon: Icons.volunteer_activism_outlined),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: busy ? null : () => run(() async {
              await st(c).post('/families/$familyId/submit');
              if (c.mounted) {
                toast(c, tr(c, 'done'));
                Navigator.pop(c, true);
              }
            }),
            child: Text(tr(c, 'submit_review')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)), onPressed: () => Navigator.pop(c, true), child: Text(tr(c, 'save_draft'))),
        ]);
    }
    return Scaffold(
      appBar: AppBar(title: Text(tr(c, widget.existing == null ? 'new_family' : 'edit_family'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            for (var i = 0; i < 4; i++)
              Expanded(
                child: Column(children: [
                  Container(height: 5, margin: const EdgeInsets.symmetric(horizontal: 3), decoration: BoxDecoration(color: i <= step ? Theme.of(c).colorScheme.primary : Colors.black12, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(height: 4),
                  Text(tr(c, labels[i]), style: const TextStyle(fontSize: 11)),
                ]),
              ),
          ]),
        ),
        if (busy) const LinearProgressIndicator(),
        Expanded(child: body),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Row(children: [
            if (step > 0) Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)), onPressed: busy ? null : () => setState(() => step--), child: Text(tr(c, 'back')))),
            if (step > 0 && step < 3) const SizedBox(width: 8),
            if (step < 3) Expanded(child: FilledButton(onPressed: busy ? null : () => step == 0 ? saveData() : setState(() => step++), child: Text(tr(c, 'next')))),
          ]),
        ),
      ]),
    );
  }
}
