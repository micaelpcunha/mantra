import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_setup_page.dart';
import 'config/supabase_config.dart';
import 'home_page.dart';
import 'l10n/app_localizations.dart';
import 'login_page.dart';
import 'reset_password_page.dart';
import 'services/account_setup_service.dart';
import 'services/auth_service.dart';
import 'services/browser_url_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBootstrap());
}

class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: initializeSupabase(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootstrapApp(
            child: _StartupScaffold(message: 'A abrir a aplicacao...'),
          );
        }

        if (snapshot.hasError) {
          return _BootstrapApp(
            child: _StartupScaffold(
              message: 'Nao foi possivel iniciar a aplicacao.',
              details: '${snapshot.error}',
            ),
          );
        }

        return const MyApp();
      },
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static MyAppState of(BuildContext context) {
    final state = context.findAncestorStateOfType<MyAppState>();
    assert(state != null, 'MyApp state not found in context');
    return state!;
  }

  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  Locale locale = const Locale('pt');
  late final StreamSubscription<AuthState> _authSubscription;
  bool _isPasswordRecoveryFlow = false;

  @override
  void initState() {
    super.initState();
    _isPasswordRecoveryFlow = _isRecoveryCallbackUrl();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.passwordRecovery) {
        setState(() {
          _isPasswordRecoveryFlow = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  void setLocale(Locale newLocale) {
    setState(() {
      locale = newLocale;
    });
  }

  Future<void> _cancelPasswordRecovery() async {
    if (AuthService.instance.currentSession != null) {
      await AuthService.instance.signOut();
    }

    if (!mounted) return;
    _clearPasswordRecoveryState();
  }

  void _completePasswordRecovery() {
    if (!mounted) return;
    _clearPasswordRecoveryState();
  }

  void _clearPasswordRecoveryState() {
    clearAuthCallbackUrl();
    setState(() {
      _isPasswordRecoveryFlow = false;
    });
  }

  bool _isRecoveryCallbackUrl() {
    if (!kIsWeb) return false;

    final uri = Uri.base;
    final params = <String, String>{
      ...uri.queryParameters,
      ..._parseFragment(uri.fragment),
    };
    return params['type'] == 'recovery';
  }

  Map<String, String> _parseFragment(String fragment) {
    if (fragment.isEmpty || !fragment.contains('=')) {
      return const <String, String>{};
    }

    try {
      return Uri.splitQueryString(fragment);
    } catch (_) {
      return const <String, String>{};
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BootstrapApp(
      locale: locale,
      child: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        initialData: AuthState(
          AuthChangeEvent.initialSession,
          Supabase.instance.client.auth.currentSession,
        ),
        builder: (context, snapshot) {
          final session = snapshot.data?.session;
          if (_isPasswordRecoveryFlow) {
            return ResetPasswordPage(
              onCompleted: _completePasswordRecovery,
              onCancel: _cancelPasswordRecovery,
            );
          }
          return session == null
              ? const LoginPage()
              : const _AuthenticatedAppGate();
        },
      ),
    );
  }
}

class _AuthenticatedAppGate extends StatefulWidget {
  const _AuthenticatedAppGate();

  @override
  State<_AuthenticatedAppGate> createState() => _AuthenticatedAppGateState();
}

class _AuthenticatedAppGateState extends State<_AuthenticatedAppGate> {
  late Future<AccountSetupState> _accountStateFuture;

  @override
  void initState() {
    super.initState();
    _accountStateFuture = AccountSetupService.instance.fetchCurrentState();
  }

  Future<void> _reload() async {
    setState(() {
      _accountStateFuture = AccountSetupService.instance.fetchCurrentState();
    });
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AccountSetupState>(
      future: _accountStateFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StartupScaffold(message: 'A validar a conta...');
        }

        if (snapshot.hasError) {
          return _AccountGateErrorScaffold(
            details: '${snapshot.error}',
            onRetry: _reload,
            onSignOut: _signOut,
          );
        }

        final accountState = snapshot.data!;
        if (accountState.requiresCompanySetup) {
          return AccountSetupPage(
            email: accountState.email,
            initialFullName: accountState.fullName,
            initialCompanyName: accountState.pendingCompanyName,
            onCompleted: _reload,
          );
        }

        return const HomePage();
      },
    );
  }
}

class _BootstrapApp extends StatelessWidget {
  const _BootstrapApp({required this.child, this.locale});

  final Widget child;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF6F7F4);
    const surface = Color(0xFFFFFEFB);
    const surfaceSoft = Color(0xFFF1F4EF);
    const primary = Color(0xFF29465B);
    const secondary = Color(0xFF4E7A6A);
    const border = Color(0xFFD7DFD7);
    const textPrimary = Color(0xFF1D2730);
    const textSecondary = Color(0xFF5F6B72);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: primary,
          secondary: secondary,
          surface: surface,
          error: Color(0xFFB42318),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        textTheme: const TextTheme(
          displaySmall: TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w800,
            height: 1.08,
            color: textPrimary,
          ),
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
          headlineSmall: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
          titleLarge: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
          bodyLarge: TextStyle(fontSize: 15, height: 1.5, color: textPrimary),
          bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: textSecondary,
          ),
          bodySmall: TextStyle(
            fontSize: 12.5,
            height: 1.45,
            color: textSecondary,
          ),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: border, width: 1),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceSoft,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primary, width: 1.2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 14,
          ),
          labelStyle: const TextStyle(color: textSecondary),
          hintStyle: const TextStyle(color: textSecondary),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: secondary,
          foregroundColor: Colors.white,
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          side: BorderSide.none,
          backgroundColor: surfaceSoft,
          selectedColor: primary.withOpacity(0.12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: surface.withOpacity(0.96),
          elevation: 0,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            return TextStyle(
              color: states.contains(WidgetState.selected)
                  ? textPrimary
                  : textSecondary,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            );
          }),
        ),
      ),
      home: child,
    );
  }
}

class _StartupScaffold extends StatelessWidget {
  const _StartupScaffold({required this.message, this.details});

  final String message;
  final String? details;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              if (details != null) ...[
                const SizedBox(height: 12),
                Text(
                  details!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountGateErrorScaffold extends StatelessWidget {
  const _AccountGateErrorScaffold({
    required this.details,
    required this.onRetry,
    required this.onSignOut,
  });

  final String details;
  final Future<void> Function() onRetry;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40),
                    const SizedBox(height: 16),
                    Text(
                      'Nao foi possivel validar a conta.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      details,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () async {
                        await onRetry();
                      },
                      child: const Text('Tentar novamente'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () async {
                        await onSignOut();
                      },
                      child: const Text('Terminar sessao'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
