import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../config/app_config.dart';
import '../models/user.dart';
import 'storage_service.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  final FacebookAuth _facebookAuth;
  final StorageService _storageService;

  AuthService({
    FacebookAuth? facebookAuth,
    StorageService? storageService,
  })  : _facebookAuth = facebookAuth ?? FacebookAuth.instance,
        _storageService = storageService ?? StorageService();

  Future<User> login() async {
    try {
      // تسجيل الدخول باستخدام Facebook
      final LoginResult result = await _facebookAuth.login(
        permissions: AppConfig.requiredPermissions,
      );

      if (result.status == LoginStatus.success) {
        // جلب بيانات المستخدم
        final userData = await _facebookAuth.getUserData(
          fields: "id,name,email,picture.width(200)",
        );

        // إنشاء كائن المستخدم
        final user = User(
          id: userData['id'],
          name: userData['name'],
          email: userData['email'],
          pictureUrl: userData['picture']?['data']?['url'],
          accessToken: result.accessToken!.token,
        );

        // حفظ بيانات المستخدم
        await _storageService.saveAccessToken(user.accessToken);
        await _storageService.saveUserData(user);

        return user;
      } else if (result.status == LoginStatus.cancelled) {
        throw AuthException('تم إلغاء تسجيل الدخول');
      } else {
        throw AuthException('فشل تسجيل الدخول: ${result.message}');
      }
    } catch (e) {
      throw AuthException('حدث خطأ أثناء تسجيل الدخول: $e');
    }
  }

  Future<void> logout() async {
    try {
      await _facebookAuth.logOut();
      await _storageService.clearAll();
    } catch (e) {
      throw AuthException('حدث خطأ أثناء تسجيل الخروج: $e');
    }
  }

  Future<bool> isLoggedIn() async {
    try {
      final accessToken = await _facebookAuth.accessToken;
      return accessToken != null && !accessToken.isExpired;
    } catch (e) {
      return false;
    }
  }

  Future<User?> getCurrentUser() async {
    return await _storageService.getUserData();
  }

  Future<String?> getAccessToken() async {
    final token = await _storageService.getAccessToken();
    if (token == null) {
      final accessToken = await _facebookAuth.accessToken;
      return accessToken?.token;
    }
    return token;
  }
}
