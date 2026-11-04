import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/enet_theme.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/data/secure_session_storage.dart';
import 'features/auth/data/supabase_auth_repository.dart';
import 'features/auth/domain/auth_repository.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/shell/presentation/enet_shell.dart';

const _supabaseUrl = String.fromEnvironment('ENET_SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('ENET_SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Fail closed. Never fall back to the old, insecure demo auth adapter.
  final url = Uri.tryParse(_supabaseUrl);
  if (url == null || url.scheme != 'https' || url.host.isEmpty ||
      _supabaseKey.trim().isEmpty) {
    runApp(const _SetupRequiredApp(
      message: 'eNet ID не настроен. Укажите HTTPS URL проекта Supabase и publishable key через --dart-define.',
    ));
    return;
  }

  try {
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabaseKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureSessionStorage(),
      ),
    );
    runApp(ENetApp(
      repository: SupabaseAuthRepository(Supabase.instance.client),
    ));
  } catch (_) {
    runApp(const _SetupRequiredApp(
      message: 'Не удалось запустить eNet ID. Проверьте настройки, защищённое хранилище и подключение.',
    ));
  }
}

class ENetApp extends StatefulWidget {
  const ENetApp({super.key, required this.repository});

  final AuthRepository repository;

  @override
  State<ENetApp> createState() => _ENetAppState();
}

class _ENetAppState extends State<ENetApp> {
  late final AuthController auth;

  @override
  void initState() {
    super.initState();
    auth = AuthController(widget.repository);
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
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eNet',
      debugShowCheckedModeBanner: false,
      theme: ENetTheme.dark,
      scrollBehavior: const ENetScrollBehavior(),
      home: AnimatedSwitcher(
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

class _SetupRequiredApp extends StatelessWidget {
  const _SetupRequiredApp({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ENetTheme.dark,
    home: Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined, size: 54),
                const SizedBox(height: 22),
                const Text('eNet ID: требуется настройка',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('Инструкция: docs/ENET_ID_SETUP.md',
                  textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
