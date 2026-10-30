import 'package:flutter/material.dart';
import 'core/theme/enet_theme.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/data/demo_auth_repository.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/shell/presentation/enet_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ENetApp());
}

class ENetApp extends StatefulWidget {
  const ENetApp({super.key});
  @override
  State<ENetApp> createState() => _ENetAppState();
}

class _ENetAppState extends State<ENetApp> {
  late final AuthController auth;
  @override
  void initState() {
    super.initState();
    auth = AuthController(DemoAuthRepository());
    auth.addListener(_update);
  }
  void _update() => setState(() {});
  @override
  void dispose() {
    auth.removeListener(_update);
    auth.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'eNet',
    debugShowCheckedModeBanner: false,
    theme: ENetTheme.dark,
    home: AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      child: auth.user == null
        ? AuthScreen(key: const ValueKey('auth'), auth: auth)
        : ENetShell(key: const ValueKey('shell'), auth: auth),
    ),
  );
}
