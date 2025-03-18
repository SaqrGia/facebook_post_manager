import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import '../models/user.dart';
import '../models/page.dart';

class StorageService {
  final FlutterSecureStorage _secureStorage;

  StorageService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  // حفظ وقراءة التوكن
  Future<void> saveAccessToken(String token) async {
    try {
      await _secureStorage.write(
        key: AppConfig.tokenKey,
        value: token,
      );
      // حفظ وقت انتهاء الصلاحية (إذا كان متاحًا في المستقبل)
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      await _secureStorage.write(
        key: '${AppConfig.tokenKey}_timestamp',
        value: currentTime.toString(),
      );
    } catch (e) {
      print('خطأ في حفظ رمز الوصول: $e');
      rethrow;
    }
  }

  Future<String?> getAccessToken() async {
    try {
      return await _secureStorage.read(key: AppConfig.tokenKey);
    } catch (e) {
      print('خطأ في قراءة رمز الوصول: $e');
      return null;
    }
  }

  // حفظ وقراءة بيانات المستخدم
  Future<void> saveUserData(User user) async {
    try {
      await _secureStorage.write(
        key: AppConfig.userDataKey,
        value: jsonEncode(user.toJson()),
      );
    } catch (e) {
      print('خطأ في حفظ بيانات المستخدم: $e');
      rethrow;
    }
  }

  Future<User?> getUserData() async {
    try {
      final userStr = await _secureStorage.read(key: AppConfig.userDataKey);
      if (userStr != null && userStr.isNotEmpty) {
        return User.fromJson(jsonDecode(userStr));
      }
      return null;
    } catch (e) {
      print('خطأ في قراءة بيانات المستخدم: $e');
      return null;
    }
  }

  // حفظ وقراءة الصفحات المختارة
  Future<void> saveSelectedPages(List<FacebookPage> pages) async {
    try {
      final pagesJson = pages.map((page) => page.toJson()).toList();
      await _secureStorage.write(
        key: AppConfig.selectedPagesKey,
        value: jsonEncode(pagesJson),
      );
    } catch (e) {
      print('خطأ في حفظ الصفحات المختارة: $e');
      rethrow;
    }
  }

  Future<List<FacebookPage>> getSelectedPages() async {
    try {
      final pagesStr =
          await _secureStorage.read(key: AppConfig.selectedPagesKey);
      if (pagesStr != null && pagesStr.isNotEmpty) {
        final List<dynamic> pagesJson = jsonDecode(pagesStr);
        return pagesJson.map((json) => FacebookPage.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('خطأ في قراءة الصفحات المختارة: $e');
      return [];
    }
  }

  // حفظ حالة تسجيل الدخول (إضافة دالة جديدة)
  Future<void> saveLoginState(bool isLoggedIn) async {
    try {
      await _secureStorage.write(
        key: 'login_state',
        value: isLoggedIn.toString(),
      );
    } catch (e) {
      print('خطأ في حفظ حالة تسجيل الدخول: $e');
    }
  }

  Future<bool> getLoginState() async {
    try {
      final stateStr = await _secureStorage.read(key: 'login_state');
      return stateStr == 'true';
    } catch (e) {
      print('خطأ في قراءة حالة تسجيل الدخول: $e');
      return false;
    }
  }

  // حذف جميع البيانات
  Future<void> clearAll() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      print('خطأ في حذف جميع البيانات: $e');
      rethrow;
    }
  }
}
