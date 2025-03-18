import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // إتاحة بعض الوقت لعرض الشاشة البدائية
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // التحقق من حالة تسجيل الدخول
    final authProvider = context.read<AuthProvider>();
    await authProvider.checkAuthStatus();

    if (!mounted) return;

    // توجيه المستخدم بناءً على حالة تسجيل الدخول
    if (authProvider.isLoggedIn) {
      // إذا كان المستخدم مسجل دخوله، انتقل إلى شاشة إنشاء منشور
      Navigator.pushReplacementNamed(context, '/create_post');
    } else {
      // إذا لم يكن المستخدم مسجل دخوله، انتقل إلى شاشة تسجيل الدخول
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.8),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // شعار التطبيق
              const Icon(
                Icons.facebook,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 24),
              // اسم التطبيق
              Text(
                'مدير صفحات فيسبوك',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 48),
              // مؤشر التحميل
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
