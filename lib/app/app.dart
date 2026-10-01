import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../features/home/screens.dart';
import '../features/onboarding/forms.dart';
import 'app_state.dart';
import 'theme.dart';

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);
  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

class NossaPatotaApp extends StatefulWidget {
  const NossaPatotaApp({super.key, required this.state});
  final AppState state;
  @override
  State<NossaPatotaApp> createState() => _NossaPatotaAppState();
}

class _NossaPatotaAppState extends State<NossaPatotaApp> {
  late final GoRouter router = GoRouter(
    refreshListenable: widget.state,
    redirect: (context, route) {
      if (widget.state.recoveringPassword &&
          route.matchedLocation != '/reset-password') {
        return '/reset-password';
      }
      if (!widget.state.recoveringPassword &&
          route.matchedLocation == '/reset-password') {
        return widget.state.isSignedIn ? '/' : '/auth';
      }
      if (!widget.state.isSignedIn && route.matchedLocation != '/auth') {
        return '/auth';
      }
      if (widget.state.isSignedIn && route.matchedLocation == '/auth') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (_, _) => const ResetPasswordScreen(),
      ),
      GoRoute(path: '/agenda', builder: (_, _) => const AgendaScreen()),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
      GoRoute(
        path: '/create-patota',
        builder: (_, _) => const CreatePatotaScreen(),
      ),
      GoRoute(path: '/join', builder: (_, _) => const JoinPatotaScreen()),
      GoRoute(path: '/invite', builder: (_, _) => const InvitationScreen()),
      GoRoute(path: '/schedule', builder: (_, _) => const ScheduleScreen()),
      GoRoute(
        path: '/match/:id',
        builder: (_, route) => MatchScreen(id: route.pathParameters['id']!),
      ),
    ],
    errorBuilder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Página não encontrada')),
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('Voltar ao início'),
        ),
      ),
    ),
  );
  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    state: widget.state,
    child: MaterialApp.router(
      title: 'Nossa Patota',
      debugShowCheckedModeBanner: false,
      theme: PatotaTheme.light,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
    ),
  );
}

class ConfigurationRequiredApp extends StatelessWidget {
  const ConfigurationRequiredApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: PatotaTheme.light,
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.settings_outlined, size: 48),
                Text(
                  'Configure o ambiente do app',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Informe SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY via dart-define. '
                  'Para explorar sem servidor, execute com DEMO_MODE=true.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
