import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/pages_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/posts/create_post_screen.dart';
import 'screens/pages/pages_screen.dart'; // أضفنا هذا السطر

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, PagesProvider>(
          create: (context) => PagesProvider(
            authProvider: Provider.of<AuthProvider>(context, listen: false),
          ),
          update: (context, auth, previous) => PagesProvider(
            authProvider: auth,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'مدير صفحات فيسبوك',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar')],
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/create_post': (context) => const CreatePostScreen(),
          '/pages': (context) => const PagesScreen(),
        },
      ),
    );
  }
}
