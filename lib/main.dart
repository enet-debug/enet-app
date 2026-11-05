import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/enet_theme.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/data/api_auth_repository.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/shell/presentation/enet_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
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
    auth = AuthController(ApiAuthRepository());
    auth.addListener(_update);
    auth.restoreSession();
  }

  void _update() => setState(() {});

  @override
  void dispose() {
    auth.removeListener(_update);
    auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eNet',
      debugShowCheckedModeBanner: false,
      theme: ENetTheme.dark,
      scrollBehavior: const ENetScrollBehavior(),
      home: auth.initializing
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : AnimatedSwitcher(
        duration: const Duration(milliseconds: 550),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: .985, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: auth.user == null
            ? AuthScreen(key: const ValueKey('auth'), auth: auth)
            : ENetShell(key: const ValueKey('shell'), auth: auth),
      ),
    );
  }
}
