import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import '../models/whatsapp_group.dart';
import '../config/app_config.dart';

class WhatsAppApiException implements Exception {
  final String message;
  final int? statusCode;

  WhatsAppApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class WhatsAppService {
  final http.Client _client;
  final String baseUrl;

  WhatsAppService(
      {http.Client? client, this.baseUrl = AppConfig.whatsappServerUrl})
      : _client = client ?? http.Client();

  // التحقق من حالة الاتصال
  Future<bool> checkConnectionStatus() async {
    try {
      print('التحقق من حالة اتصال واتساب من: $baseUrl/status');

      final response = await _client
          .get(
        Uri.parse('$baseUrl/status'),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('انتهت مهلة الاتصال بعنوان: $baseUrl/status');
          throw TimeoutException('انتهت مهلة الاتصال');
        },
      );

      print('استجابة حالة الاتصال: ${response.statusCode}');
      print('محتوى الاستجابة: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['connected'] == true;
      }

      return false;
    } catch (e) {
      print('خطأ في التحقق من حالة الاتصال: $e');

      if (e is SocketException) {
        print('نوع الخطأ: خطأ في الاتصال بالمقبس');
        print('عنوان: ${e.address}');
        print('منفذ: ${e.port}');
      }

      return false;
    }
  }

  // جلب رمز QR للمصادقة مع دعم صورة QR
  Future<Map<String, String?>> getQRCodeWithImage() async {
    try {
      print('جلب رمز QR لواتساب من: $baseUrl/qr-code');

      final response = await _client
          .get(
        Uri.parse('$baseUrl/qr-code'),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('انتهت مهلة الاتصال بعنوان: $baseUrl/qr-code');
          throw TimeoutException('انتهت مهلة الاتصال');
        },
      );

      print('استجابة جلب رمز QR: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'qrCode': data['qrCode'] as String?,
          'qrImage': data['qrImage'] as String?,
        };
      } else {
        throw WhatsAppApiException(
          'فشل في جلب رمز QR: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('خطأ في جلب رمز QR: $e');

      if (e is SocketException) {
        print('نوع الخطأ: خطأ في الاتصال بالمقبس');
        print('عنوان: ${e.address}');
        print('منفذ: ${e.port}');
      }

      if (e is WhatsAppApiException) rethrow;
      throw WhatsAppApiException('خطأ في جلب رمز QR: $e');
    }
  }

  // دالة لإرجاع رابط صورة QR مباشرة
  String getQRImageUrl() {
    return '$baseUrl/qr-image';
  }

  // إعادة تشغيل عميل واتساب
  Future<bool> restartClient() async {
    try {
      print('إعادة تشغيل عميل واتساب...');

      final response = await _client
          .post(
        Uri.parse('$baseUrl/restart'),
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('انتهت مهلة إعادة تشغيل العميل');
          throw TimeoutException('انتهت مهلة الطلب');
        },
      );

      print('استجابة إعادة التشغيل: ${response.statusCode}');

      return response.statusCode == 200;
    } catch (e) {
      print('خطأ في إعادة تشغيل العميل: $e');
      return false;
    }
  }

  // مزامنة المجموعات - تنشيط المجموعات من جهات الاتصال
  Future<List<WhatsAppGroup>> syncGroups() async {
    try {
      print('طلب مزامنة مجموعات واتساب من: $baseUrl/sync-groups');

      final response = await _client
          .post(
        Uri.parse('$baseUrl/sync-groups'),
      )
          .timeout(
        const Duration(seconds: 60), // عملية المزامنة قد تستغرق وقتًا
        onTimeout: () {
          print('انتهت مهلة مزامنة المجموعات');
          throw TimeoutException('انتهت مهلة الطلب');
        },
      );

      print('استجابة مزامنة المجموعات: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('نتيجة المزامنة: ${response.body}');

        if (!data.containsKey('groups')) {
          print('تنسيق استجابة غير صحيح: لا يوجد مفتاح "groups"');
          return [];
        }

        final List<dynamic> groupsData = data['groups'];
        print('عدد المجموعات المنشطة: ${groupsData.length}');

        return groupsData
            .map((group) => WhatsAppGroup.fromJson(group))
            .toList();
      } else {
        throw WhatsAppApiException(
          'فشل في مزامنة مجموعات واتساب: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('خطأ في مزامنة مجموعات واتساب: $e');
      if (e is WhatsAppApiException) rethrow;
      throw WhatsAppApiException('خطأ في مزامنة مجموعات واتساب: $e');
    }
  }

  // جلب قائمة مجموعات واتساب
  Future<List<WhatsAppGroup>> getGroups() async {
    try {
      print('جلب مجموعات واتساب من: $baseUrl/groups');

      // إضافة تأخير قصير بعد التحقق من الاتصال (يساعد أحيانًا)
      await Future.delayed(const Duration(seconds: 1));

      final response = await _client
          .get(
        Uri.parse('$baseUrl/groups'),
      )
          .timeout(
        const Duration(seconds: 20), // زيادة مهلة الانتظار
        onTimeout: () {
          print('انتهت مهلة جلب المجموعات');
          throw TimeoutException('انتهت مهلة الطلب');
        },
      );

      print('استجابة جلب المجموعات: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('البيانات المستلمة: ${response.body}');

        if (!data.containsKey('groups')) {
          print('تنسيق استجابة غير صحيح: لا يوجد مفتاح "groups"');
          return [];
        }

        final List<dynamic> groupsData = data['groups'];
        final String source = data['source'] as String? ?? 'unknown';
        print('عدد المجموعات المستلمة: ${groupsData.length} (المصدر: $source)');

        return groupsData
            .map((group) => WhatsAppGroup.fromJson(group))
            .toList();
      } else {
        throw WhatsAppApiException(
          'فشل في جلب مجموعات واتساب: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('خطأ في جلب مجموعات واتساب: $e');
      if (e is WhatsAppApiException) rethrow;
      throw WhatsAppApiException('خطأ في جلب مجموعات واتساب: $e');
    }
  }

  // إرسال رسالة نصية إلى مجموعة
  Future<bool> sendTextMessage(String groupId, String message) async {
    try {
      print('إرسال رسالة نصية إلى مجموعة واتساب: $groupId');

      final response = await _client
          .post(
        Uri.parse('$baseUrl/send-message'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'groupId': groupId,
          'message': message,
        }),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('انتهت مهلة إرسال الرسالة');
          throw TimeoutException('انتهت مهلة الطلب');
        },
      );

      print('استجابة إرسال الرسالة النصية: ${response.statusCode}');

      if (response.statusCode == 200) {
        return true;
      } else {
        throw WhatsAppApiException(
          'فشل في إرسال الرسالة: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('خطأ في إرسال الرسالة النصية: $e');
      if (e is WhatsAppApiException) rethrow;
      throw WhatsAppApiException('خطأ في إرسال الرسالة النصية: $e');
    }
  }

  // إرسال وسائط إلى مجموعة
  Future<bool> sendMedia(String groupId, File file, {String? caption}) async {
    try {
      print('إرسال وسائط إلى مجموعة واتساب: $groupId');

      // إنشاء طلب متعدد الأجزاء
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/send-media'),
      );

      // إضافة الحقول
      request.fields['groupId'] = groupId;
      if (caption != null) request.fields['caption'] = caption;

      // تحديد نوع الوسائط
      final mimeType = lookupMimeType(file.path);
      print('نوع الملف: $mimeType');

      // إضافة الملف
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: mimeType != null ? MediaType.parse(mimeType) : null,
      ));

      // إرسال الطلب
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          print('انتهت مهلة إرسال الوسائط');
          throw TimeoutException('انتهت مهلة الطلب');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      print('استجابة إرسال الوسائط: ${response.statusCode}');
      print('محتوى الاستجابة: ${response.body}');

      if (response.statusCode == 200) {
        return true;
      } else {
        throw WhatsAppApiException(
          'فشل في إرسال الوسائط: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('خطأ في إرسال الوسائط: $e');
      if (e is WhatsAppApiException) rethrow;
      throw WhatsAppApiException('خطأ في إرسال الوسائط: $e');
    }
  }

  // دالة موحدة لإرسال منشور (نص أو وسائط)
  Future<bool> sendPost({
    required String groupId,
    required String message,
    File? mediaFile,
  }) async {
    try {
      if (mediaFile != null) {
        return await sendMedia(groupId, mediaFile, caption: message);
      } else {
        return await sendTextMessage(groupId, message);
      }
    } catch (e) {
      print('خطأ في إرسال المنشور: $e');
      if (e is WhatsAppApiException) rethrow;
      throw WhatsAppApiException('خطأ في إرسال المنشور: $e');
    }
  }
}
