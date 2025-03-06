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
    await _secureStorage.write(
      key: AppConfig.tokenKey,
      value: token,
    );
  }

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: AppConfig.tokenKey);
  }

  // حفظ وقراءة بيانات المستخدم
  Future<void> saveUserData(User user) async {
    await _secureStorage.write(
      key: AppConfig.userDataKey,
      value: jsonEncode(user.toJson()),
    );
  }

  Future<User?> getUserData() async {
    final userStr = await _secureStorage.read(key: AppConfig.userDataKey);
    if (userStr != null) {
      return User.fromJson(jsonDecode(userStr));
    }
    return null;
  }

  // حفظ وقراءة الصفحات المختارة
  Future<void> saveSelectedPages(List<FacebookPage> pages) async {
    final pagesJson = pages.map((page) => page.toJson()).toList();
    await _secureStorage.write(
      key: AppConfig.selectedPagesKey,
      value: jsonEncode(pagesJson),
    );
  }

  Future<List<FacebookPage>> getSelectedPages() async {
    final pagesStr = await _secureStorage.read(key: AppConfig.selectedPagesKey);
    if (pagesStr != null) {
      final List<dynamic> pagesJson = jsonDecode(pagesStr);
      return pagesJson.map((json) => FacebookPage.fromJson(json)).toList();
    }
    return [];
  }

  // حذف جميع البيانات
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
  }
}
