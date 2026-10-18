import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'i18n.dart';

AppState st(BuildContext c) => c.read<AppState>();

void toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

String errMsg(BuildContext c, Object e) {
  if (e is ApiException) {
    final k = 'e_${e.message}';
    final t = tr(c, k);
    return t == k ? e.message : t;
  }
  return tr(c, 'e_network');
}

Future<T?> go<T>(BuildContext c, Widget w) => Navigator.of(c).push<T>(MaterialPageRoute(builder: (_) => w));

Widget statusChip(BuildContext c, String s) {
  final Color col = switch (s) {
    'approved' || 'active' || 'completed' => Colors.green,
    'pending_review' || 'in_progress' || 'planned' || 'scheduled' => Colors.orange,
    'needs_correction' || 'cancelled' || 'suspended' => Colors.red,
    _ => Colors.grey,
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(color: col.withAlpha(40), borderRadius: BorderRadius.circular(99)),
    child: Text(tr(c, 's_$s'), style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w600)),
  );
}

Widget field(BuildContext c, TextEditingController ctl, String label,
    {bool req = false, TextInputType? type, bool obscure = false, int? maxLen, int lines = 1, String? hint}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: ctl,
      keyboardType: type,
      obscureText: obscure,
      maxLength: maxLen,
      maxLines: obscure ? 1 : lines,
      decoration: InputDecoration(
        labelText: req ? '$label *' : label,
        hintText: hint,
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: req ? (v) => (v == null || v.trim().isEmpty) ? tr(c, 'required') : null : null,
    ),
  );
}

Widget tile(BuildContext c, String title, {String? sub, Widget? trailing, IconData icon = Icons.circle_outlined, VoidCallback? onTap}) {
  return Card(
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(backgroundColor: Theme.of(c).colorScheme.primaryContainer, child: Icon(icon, size: 20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: sub == null ? null : Text(sub),
      trailing: trailing,
    ),
  );
}

Widget sectionTitle(String t) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    );

Widget kv(String k, String? v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(k, style: const TextStyle(color: Colors.grey))),
        Expanded(child: Text(v == null || v.isEmpty ? '—' : v)),
      ]),
    );

Future<String?> pickDate(BuildContext c) async {
  final d = await showDatePicker(context: c, initialDate: DateTime.now(), firstDate: DateTime(1950), lastDate: DateTime(2100));
  if (d == null) return null;
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

Future<String?> askText(BuildContext c, String title, {String? hint, bool digits = false, int? maxLen}) {
  final ctl = TextEditingController();
  return showDialog<String>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctl, autofocus: true, maxLength: maxLen, keyboardType: digits ? TextInputType.number : null, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr(c, 'cancel'))),
        FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(90, 40)), onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: Text(tr(c, 'confirm'))),
      ],
    ),
  );
}

Future<bool> askYesNo(BuildContext c, String title, String body) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr(c, 'cancel'))),
        FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(90, 40)), onPressed: () => Navigator.pop(ctx, true), child: Text(tr(c, 'confirm'))),
      ],
    ),
  );
  return r ?? false;
}

/// Loads one value and rebuilds on reload.
class Loader<T> extends StatefulWidget {
  final Future<T> Function(AppState s) fetch;
  final Widget Function(BuildContext c, T data, VoidCallback reload) builder;
  const Loader({super.key, required this.fetch, required this.builder});
  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  late Future<T> f;
  @override
  void initState() {
    super.initState();
    f = widget.fetch(st(context));
  }

  void reload() => setState(() => f = widget.fetch(st(context)));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: f,
      builder: (c, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(errMsg(c, snap.error!)),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: reload, child: Text(tr(c, 'retry'))),
            ]),
          );
        }
        return widget.builder(c, snap.data as T, reload);
      },
    );
  }
}

/// Paginated list backed by a Laravel paginator endpoint.
class PagedList extends StatefulWidget {
  final String path;
  final Map<String, dynamic> query;
  final Widget Function(BuildContext c, Json item) item;
  const PagedList({super.key, required this.path, this.query = const {}, required this.item});
  @override
  State<PagedList> createState() => PagedListState();
}

class PagedListState extends State<PagedList> {
  final items = <Json>[];
  int page = 0, gen = 0;
  bool more = true, loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  @override
  void didUpdateWidget(PagedList old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.query.toString() != widget.query.toString()) load(reset: true);
  }

  Future<void> load({bool reset = false}) async {
    if (loading && !reset) return;
    final my = ++gen;
    final s = st(context);
    setState(() {
      loading = true;
      error = null;
      if (reset) {
        items.clear();
        page = 0;
        more = true;
      }
    });
    try {
      final r = await s.get(widget.path, q: {...widget.query, 'page': page + 1}) as Map;
      if (!mounted || my != gen) return;
      final data = (r['data'] as List).map((e) => Json.from(e as Map)).toList();
      setState(() {
        items.addAll(data);
        page++;
        more = r['next_page_url'] != null;
        loading = false;
      });
    } catch (e) {
      if (!mounted || my != gen) return;
      setState(() {
        error = errMsg(context, e);
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && loading) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty && error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(error!),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => load(reset: true), child: Text(tr(context, 'retry'))),
        ]),
      );
    }
    if (items.isEmpty) return Center(child: Text(tr(context, 'empty')));
    return RefreshIndicator(
      onRefresh: () => load(reset: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: items.length + (more ? 1 : 0),
        itemBuilder: (c, i) {
          if (i < items.length) return widget.item(c, items[i]);
          return Padding(
            padding: const EdgeInsets.all(8),
            child: loading ? const Center(child: CircularProgressIndicator()) : TextButton(onPressed: () => load(), child: Text(tr(c, 'load_more'))),
          );
        },
      ),
    );
  }
}

/// Full-screen picker that returns the chosen item (used for camps and projects).
class PickerPage extends StatefulWidget {
  final String titleKey, path;
  final String Function(Json) label;
  final String Function(Json)? sub;
  const PickerPage({super.key, required this.titleKey, required this.path, required this.label, this.sub});
  @override
  State<PickerPage> createState() => _PickerPageState();
}

class _PickerPageState extends State<PickerPage> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, widget.titleKey))),
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
            path: widget.path,
            query: {'q': q},
            item: (c, it) => tile(c, widget.label(it), sub: widget.sub?.call(it), onTap: () => Navigator.pop(c, it)),
          ),
        ),
      ]),
    );
  }
}
