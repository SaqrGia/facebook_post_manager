import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService();

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // تحسين: استخدام getAccessToken أولاً للتحقق من وجود رمز وصول مخزن
      final token = await _authService.getAccessToken();
      if (token != null) {
        // استخدام isLoggedIn للتحقق من صلاحية الرمز
        final isTokenValid = await _authService.isLoggedIn();

        if (isTokenValid) {
          _currentUser = await _authService.getCurrentUser();

          // إذا لم نستطع استرداد بيانات المستخدم، نقوم بتسجيل الخروج
          if (_currentUser == null) {
            await _authService.logout();
          }
        } else {
          // إذا انتهت صلاحية الرمز، نقوم بتسجيل الخروج
          await _authService.logout();
        }
      }
    } catch (e) {
      _error = e.toString();
      // في حالة حدوث خطأ، نحاول تسجيل الخروج لإعادة ضبط الحالة
      try {
        await _authService.logout();
      } catch (_) {
        // تجاهل أي خطأ في عملية تسجيل الخروج
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await _authService.login();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
      _currentUser = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> getAccessToken() async {
    return await _authService.getAccessToken();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
