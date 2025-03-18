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
      // التحقق أولاً إذا كان هناك رمز وصول مخزن
      final storedToken = await _storageService.getAccessToken();
      if (storedToken != null) {
        final storedUser = await _storageService.getUserData();
        if (storedUser != null) {
          // التحقق من صلاحية رمز الوصول
          final accessToken = await _facebookAuth.accessToken;
          if (accessToken != null && !accessToken.isExpired) {
            // تسجيل حالة تسجيل الدخول
            await _storageService.saveLoginState(true);
            return storedUser;
          }
        }
      }

      // إذا لم يكن هناك رمز صالح، نقوم بتسجيل الدخول من جديد
      print('تسجيل الدخول باستخدام Facebook...');
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

        // تسجيل حالة تسجيل الدخول
        await _storageService.saveLoginState(true);

        print('تم تسجيل الدخول بنجاح وحفظ البيانات');
        return user;
      } else if (result.status == LoginStatus.cancelled) {
        throw AuthException('تم إلغاء تسجيل الدخول');
      } else {
        throw AuthException('فشل تسجيل الدخول: ${result.message}');
      }
    } catch (e) {
      print('حدث خطأ أثناء تسجيل الدخول: $e');
      throw AuthException('حدث خطأ أثناء تسجيل الدخول: $e');
    }
  }

  Future<void> logout() async {
    try {
      await _facebookAuth.logOut();
      await _storageService.clearAll();

      // تسجيل حالة تسجيل الخروج
      await _storageService.saveLoginState(false);

      print('تم تسجيل الخروج وحذف البيانات');
    } catch (e) {
      print('حدث خطأ أثناء تسجيل الخروج: $e');
      throw AuthException('حدث خطأ أثناء تسجيل الخروج: $e');
    }
  }

  Future<bool> isLoggedIn() async {
    try {
      // التحقق من حالة تسجيل الدخول المخزنة
      final loginState = await _storageService.getLoginState();

      if (!loginState) {
        return false;
      }

      // التحقق من رمز الوصول
      final accessToken = await _facebookAuth.accessToken;
      final storedToken = await _storageService.getAccessToken();

      // التحقق من أن رموز الوصول متوافقة وصالحة
      if (accessToken != null &&
          !accessToken.isExpired &&
          storedToken != null) {
        // التحقق أيضًا من بيانات المستخدم
        final userData = await _storageService.getUserData();
        return userData != null;
      }

      // محاولة استخدام الرمز المخزن إذا لم يكن هناك رمز في الذاكرة
      if (accessToken == null && storedToken != null) {
        try {
          // محاولة استخدام الرمز المخزن (قد لا تنجح دائمًا)
          final result = await _facebookAuth.getUserData();
          return result.isNotEmpty;
        } catch (_) {
          return false;
        }
      }

      return false;
    } catch (e) {
      print('خطأ في التحقق من حالة تسجيل الدخول: $e');
      return false;
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      // محاولة استرداد بيانات المستخدم من التخزين
      final user = await _storageService.getUserData();

      // التحقق من صلاحية رمز الوصول
      final accessToken = await _facebookAuth.accessToken;

      if (user != null && accessToken != null && !accessToken.isExpired) {
        return user;
      } else if (user != null) {
        // إذا كان المستخدم موجودًا ولكن رمز الوصول غير صالح، نحاول تحديث البيانات
        try {
          final userData = await _facebookAuth.getUserData(
            fields: "id,name,email,picture.width(200)",
          );

          if (userData.isNotEmpty && userData['id'] == user.id) {
            // تحديث بيانات المستخدم
            final updatedUser = User(
              id: userData['id'],
              name: userData['name'],
              email: userData['email'],
              pictureUrl: userData['picture']?['data']?['url'],
              accessToken: accessToken?.token ?? user.accessToken,
            );

            await _storageService.saveUserData(updatedUser);
            return updatedUser;
          }
        } catch (_) {
          // إذا فشل التحديث، نعيد المستخدم الحالي
          return user;
        }
      }

      return user;
    } catch (e) {
      print('خطأ في استرداد بيانات المستخدم الحالي: $e');
      return null;
    }
  }

  Future<String?> getAccessToken() async {
    try {
      // محاولة الحصول على رمز الوصول من التخزين أولاً
      final token = await _storageService.getAccessToken();
      if (token != null) {
        return token;
      }

      // إذا لم يكن موجودًا في التخزين، نحاول الحصول عليه من Facebook Auth
      final accessToken = await _facebookAuth.accessToken;

      if (accessToken != null && !accessToken.isExpired) {
        // حفظ الرمز في التخزين
        await _storageService.saveAccessToken(accessToken.token);
        return accessToken.token;
      }

      return null;
    } catch (e) {
      print('خطأ في الحصول على رمز الوصول: $e');
      return null;
    }
  }
}
