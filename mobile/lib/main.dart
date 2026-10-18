import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/app_state.dart';
import 'core/theme.dart';
import 'screens/login.dart';
import 'screens/shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ChangeNotifierProvider(create: (_) => AppState()..init(), child: const OterApp()));
}

class OterApp extends StatelessWidget {
  const OterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    Widget home;
    if (!s.ready) {
      home = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (s.showSplash) {
      home = const SplashScreen();
    } else if (s.user == null) {
      home = const LoginScreen();
    } else {
      home = const Shell();
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'عطر الشام',
      locale: Locale(s.locale),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: s.dark ? ThemeMode.dark : ThemeMode.light,
      home: home,
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimary,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 190,
            height: 190,
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Image.asset('assets/logo.png'),
          ),
          const SizedBox(height: 24),
          const Text('جمعية عطر الشام التعاونية\nللمشغولات الحرفية',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.5)),
          const SizedBox(height: 8),
          const Text('Oter Al-Sham Association', style: TextStyle(color: Colors.white70)),
        ]),
      ),
    );
  }
}
