import 'package:flutter/services.dart';

class TikTokNativeService {
  static const MethodChannel _channel =
      MethodChannel('com.your.app/tiktok_auth');

  // تسجيل الدخول باستخدام تيك توك
  Future<Map<String, dynamic>> login() async {
    try {
      final Map<String, dynamic> result = await _channel.invokeMethod('login');
      return result;
    } on PlatformException catch (e) {
      throw Exception('فشل في تسجيل الدخول: ${e.message}');
    }
  }

  // التحقق إذا كان التطبيق مثبت
  Future<bool> isTikTokInstalled() async {
    try {
      final bool result = await _channel.invokeMethod('isTikTokInstalled');
      return result;
    } on PlatformException catch (e) {
      print('خطأ في التحقق من وجود تطبيق تيك توك: ${e.message}');
      return false;
    }
  }
}
