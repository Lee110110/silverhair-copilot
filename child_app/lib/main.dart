import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/network/api_client.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/sos/sos_provider.dart';
import 'features/coscreen/coscreen_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  ApiClient.onUnauthorized = () async {
    final context = navigatorKey.currentContext;
    if (context != null) {
      Provider.of<AuthService>(context, listen: false).logout();
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
    }
  };
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => SosProvider()),
      ],
      child: const ChildApp(),
    ),
  );
}

class ChildApp extends StatelessWidget {
  const ChildApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: '银发陪驾 · 子女版',
      theme: AppTheme.theme,
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/coscreen') {
          final args = settings.arguments as Map<String, dynamic>?;
          final elderlyId = args?['elderlyId'] as String? ?? '';
          return MaterialPageRoute(
            builder: (_) => CoScreenScreen(elderlyId: elderlyId),
          );
        }
        return null;
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Provider.of<AuthService>(context, listen: false).loadSavedAuth();
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final auth = Provider.of<AuthService>(context);
    if (auth.isLoggedIn) {
      return const HomeScreen();
    }
    return const LoginScreen();
  }
}
