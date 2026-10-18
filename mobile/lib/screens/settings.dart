import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/i18n.dart';
import '../core/widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context;
    return Scaffold(
      appBar: AppBar(title: Text(tr(c, 'settings'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        tile(c, '${s.user?['full_name']}', sub: '${s.user?['username']} · ${s.role}', icon: Icons.person_outline),
        sectionTitle(tr(c, 'language')),
        SegmentedButton<String>(
          segments: [ButtonSegment(value: 'ar', label: Text(tr(c, 'arabic'))), ButtonSegment(value: 'en', label: Text(tr(c, 'english')))],
          selected: {s.locale},
          onSelectionChanged: (v) => s.setLocale(v.first),
        ),
        SwitchListTile(title: Text(tr(c, 'dark_mode')), value: s.dark, onChanged: s.setDark),
        if (s.can('user.manage')) tile(c, tr(c, 'users'), icon: Icons.manage_accounts_outlined, trailing: const Icon(Icons.chevron_right), onTap: () => go(c, const UsersPage())),
        if (s.can('audit.view')) tile(c, tr(c, 'audit'), icon: Icons.receipt_long_outlined, trailing: const Icon(Icons.chevron_right), onTap: () => go(c, const AuditPage())),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: () async {
            Navigator.of(c).popUntil((r) => r.isFirst);
            await s.logout();
          },
          icon: const Icon(Icons.logout),
          label: Text(tr(c, 'logout')),
        ),
      ]),
    );
  }
}

class AuditPage extends StatelessWidget {
  const AuditPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'audit'))),
      body: PagedList(path: '/audit-logs', item: (c, it) => tile(c, '${it['action']} · ${it['entity']} ${it['entity_id'] ?? ''}', sub: '${it['created_at']}', icon: Icons.receipt_long_outlined)),
    );
  }
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  int refresh = 0;

  Future<void> create() async {
    final c = context;
    final s = st(c);
    final un = TextEditingController(), fn = TextEditingController(), pw = TextEditingController();
    int? role;
    List<Json> roles = [];
    try {
      roles = (await s.get('/roles') as List).map((e) => Json.from(e as Map)).toList();
    } catch (e) {
      if (c.mounted) toast(c, errMsg(c, e));
      return;
    }
    if (!c.mounted) return;
    final ok = await showDialog<bool>(
      context: c,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(tr(c, 'new_user')),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: un, decoration: InputDecoration(labelText: tr(c, 'username'))),
              TextField(controller: fn, decoration: InputDecoration(labelText: tr(c, 'full_name'))),
              TextField(controller: pw, obscureText: true, decoration: InputDecoration(labelText: tr(c, 'password'), helperText: tr(c, 'pwd_min'))),
              DropdownButtonFormField<int>(
                value: role,
                hint: Text(tr(c, 'role')),
                items: [for (final r in roles) DropdownMenuItem(value: r['id'] as int, child: Text('${r['name_ar']}'))],
                onChanged: (v) => setD(() => role = v),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr(c, 'cancel'))),
            FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(90, 40)), onPressed: () => Navigator.pop(ctx, true), child: Text(tr(c, 'save'))),
          ],
        ),
      ),
    );
    if (ok != true || role == null) return;
    try {
      await s.post('/users', {'username': un.text.trim(), 'full_name': fn.text.trim(), 'password': pw.text, 'role_id': role});
      if (mounted) setState(() => refresh++);
    } catch (e) {
      if (c.mounted) toast(c, errMsg(c, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context;
    return Scaffold(
      appBar: AppBar(title: Text(tr(c, 'users'))),
      floatingActionButton: FloatingActionButton.extended(onPressed: create, icon: const Icon(Icons.person_add_alt), label: Text(tr(c, 'new_user'))),
      body: Loader<List<Json>>(
        key: ValueKey(refresh),
        fetch: (s) async => (await s.get('/users') as List).map((e) => Json.from(e as Map)).toList(),
        builder: (c, users, reload) => ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
          for (final u in users)
            Card(
              child: SwitchListTile(
                title: Text('${u['full_name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${u['username']} · ${u['role']}'),
                value: u['is_active'] == true,
                onChanged: u['id'] == st(c).user?['id']
                    ? null
                    : (v) async {
                        try {
                          await st(c).patch('/users/${u['id']}/active', {'is_active': v});
                          reload();
                        } catch (e) {
                          if (c.mounted) toast(c, errMsg(c, e));
                        }
                      },
              ),
            ),
        ]),
      ),
    );
  }
}
