import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'session.dart';
import 'shell.dart';
import 'theme.dart';
import 'welcome_screen.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await session.load();
  final prefs = await SharedPreferences.getInstance();
  runApp(KasiJobsApp(showWelcome: !(prefs.getBool('seen_welcome') ?? false)));
}

class KasiJobsApp extends StatefulWidget {
  const KasiJobsApp({super.key, required this.showWelcome});
  final bool showWelcome;

  @override
  State<KasiJobsApp> createState() => _KasiJobsAppState();
}

class _KasiJobsAppState extends State<KasiJobsApp> {
  late bool welcome = widget.showWelcome;

  Future<void> _finish() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('seen_welcome', true);
    if (mounted) setState(() => welcome = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kasi Jobs',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      scrollBehavior: const AppScrollBehavior(),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: welcome
            ? WelcomeScreen(key: const ValueKey('welcome'), onDone: _finish)
            : const Shell(key: ValueKey('shell')),
      ),
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}