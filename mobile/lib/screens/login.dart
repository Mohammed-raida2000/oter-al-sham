import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final base = TextEditingController(), user = TextEditingController(), pass = TextEditingController();
  final key = GlobalKey<FormState>();
  bool busy = false, showServer = false;
  String? err;

  @override
  void initState() {
    super.initState();
    base.text = st(context).baseUrl;
    showServer = base.text.isEmpty;
  }

  Future<void> submit() async {
    if (!key.currentState!.validate()) return;
    setState(() {
      busy = true;
      err = null;
    });
    try {
      await st(context).login(base.text, user.text, pass.text);
    } catch (e) {
      if (mounted) setState(() => err = errMsg(context, e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: key,
              child: Column(children: [
                Container(
                  width: 104,
                  height: 104,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black12)),
                  child: Image.asset('assets/logo.png'),
                ),
                const SizedBox(height: 16),
                Text(tr(context, 'login'), style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(tr(context, 'login_sub'), style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                if (showServer) field(context, base, tr(context, 'server'), req: true, type: TextInputType.url, hint: 'https://...'),
                field(context, user, tr(context, 'username'), req: true),
                field(context, pass, tr(context, 'password'), req: true, obscure: true),
                if (err != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(err!, style: const TextStyle(color: Colors.red))),
                FilledButton(onPressed: busy ? null : submit, child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(tr(context, 'login'))),
                if (!showServer) TextButton(onPressed: () => setState(() => showServer = true), child: Text(tr(context, 'change_server'))),
                const SizedBox(height: 12),
                Text(tr(context, 'admin_only_accounts'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
