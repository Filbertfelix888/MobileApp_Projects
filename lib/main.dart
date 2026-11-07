import 'package:flutter/material.dart';

import 'System Login/login_page.dart';
import 'System Login/register_page.dart';
import 'Home/home_page.dart';
import 'Project/project_detail_page.dart';
import 'app_navigation.dart';
import 'environment_config.dart';
import 'session_manager.dart';
import 'ui/Theme/app_theme.dart';
import 'ui/Theme/theme_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeNotifier.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.homePage = const HomePage(),
    this.loginPage = const LoginPage(),
  });

  static final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();

  final Widget homePage;
  final Widget loginPage;

  @override
  Widget build(BuildContext context) {
    AppNavigation.registerLoginNavigator((warning) {
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (_) => false,
        arguments: warning,
      );
    });
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeNotifier.themeMode,
      builder: (context, currentMode, child) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'Mobile App',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,

          theme: AppTheme.light,
          darkTheme: AppTheme.dark,

          initialRoute: '/',
          routes: {
            '/login': (context) => loginPage,
            '/signup': (context) => const RegisterPage(),
            '/': (context) =>
                _ProtectedRoute(loginPage: loginPage, child: homePage),
          },
          onGenerateRoute: (settings) {
            final name = settings.name ?? '';
            const prefix = '/projects/';
            if (!name.startsWith(prefix) || name.length == prefix.length) {
              return null;
            }
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => _ProtectedRoute(
                loginPage: loginPage,
                child: ProjectDetailPage(
                  boardId: name.substring(prefix.length),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ProtectedRoute extends StatefulWidget {
  const _ProtectedRoute({required this.child, required this.loginPage});

  final Widget child;
  final Widget loginPage;

  @override
  State<_ProtectedRoute> createState() => _ProtectedRouteState();
}

class _ProtectedRouteState extends State<_ProtectedRoute> {
  late final Future<Map<String, dynamic>?> _session = _loadSession();

  Future<Map<String, dynamic>?> _loadSession() async {
    try {
      final environment = await EnvironmentConfig.snapshot();
      final session = await SessionManager.getSessionForEnvironment(
        environment.environment,
      );
      final token = session?['access_token'];
      return token is String && token.isNotEmpty ? session : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _session,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final token = snapshot.data?['access_token'];
        return snapshot.connectionState == ConnectionState.done &&
                !snapshot.hasError &&
                token is String &&
                token.isNotEmpty
            ? widget.child
            : widget.loginPage;
      },
    );
  }
}
