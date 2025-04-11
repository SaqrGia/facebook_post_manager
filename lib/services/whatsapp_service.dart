import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
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
  final String productId;
  final String apiKey;

  WhatsAppService({
    http.Client? client,
    this.productId = AppConfig.maytapiProductId,
    this.apiKey = AppConfig.maytapiApiKey,
  }) : _client = client ?? http.Client();

  // URL الرئيسي للـ API
  String get baseUrl => 'https://api.maytapi.com/api';

  // Headers لمصادقة Maytapi API
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-maytapi-key': apiKey,
      };

  // التحقق من حالة الاتصال
  Future<bool> checkConnectionStatus({required String phoneId}) async {
    try {
      print('التحقق من حالة اتصال واتساب للهاتف: $phoneId');

      final response = await _client
          .get(
        Uri.parse('$baseUrl/$productId/$phoneId/status'),
        headers: _headers,
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('انتهت مهلة الاتصال');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['status'] != null) {
          return data['status']['loggedIn'] == true;
        }
      }

      return false;
    } catch (e) {
      print('خطأ في التحقق من حالة الاتصال: $e');
      return false;
    }
  }

  // الحصول على رمز QR للمصادقة
  Future<Map<String, String?>> getQRCode({required String phoneId}) async {
    try {
      print('جلب رمز QR للهاتف: $phoneId');

      final response = await _client
          .get(
        Uri.parse('$baseUrl/$productId/$phoneId/qrCode'),
        headers: _headers,
      )
          .timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException('انتهت مهلة جلب QR');
        },
      );

      // تحويل البيانات إلى صورة قابلة للعرض
      if (response.statusCode == 200) {
        // تنسيق الاستجابة قد يكون صورة مباشرة
        if (response.headers['content-type']?.contains('image/') ?? false) {
          final base64Image = base64Encode(response.bodyBytes);
          final imgType =
              response.headers['content-type']?.split('/').last ?? 'png';
          return {
            'qrCode': base64Image,
            'qrImage': 'data:image/$imgType;base64,$base64Image',
          };
        }

        // للتوافق مع استجابات API المختلفة
        try {
          final data = json.decode(response.body);
          // إذا تم إرجاع بيانات JSON
          return {
            'qrCode': null,
            'qrImage': null,
          };
        } catch (_) {
          // إذا كانت البيانات ليست JSON صالح، نفترض أنها بيانات QR
          final base64Image = base64Encode(response.bodyBytes);
          return {
            'qrCode': base64Image,
            'qrImage': 'data:image/png;base64,$base64Image',
          };
        }
      } else {
        throw WhatsAppApiException(
          'فشل في جلب رمز QR',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('خطأ في جلب رمز QR: $e');
      if (e is WhatsAppApiException) rethrow;
      throw WhatsAppApiException('خطأ في جلب رمز QR: $e');
    }
  }

  // الحصول على URL مباشر لصورة QR
  String getQRImageUrl({required String phoneId}) {
    return '$baseUrl/$productId/$phoneId/qrCode';
  }

  // تسجيل الخروج من واتساب
  Future<bool> logout({required String phoneId}) async {
    try {
      print('تسجيل الخروج من واتساب للهاتف: $phoneId');

      final response = await _client
          .get(
        Uri.parse('$baseUrl/$productId/$phoneId/logout'),
        headers: _headers,
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('انتهت مهلة تسجيل الخروج');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else {
        return false;
      }
    } catch (e) {
      print('خطأ في تسجيل الخروج: $e');
      return false;
    }
  }

  // الحصول على كل المجموعات
  Future<List<WhatsAppGroup>> getGroups({required String phoneId}) async {
    try {
      print('جلب مجموعات واتساب للهاتف: $phoneId');

      final response = await _client
          .get(
        Uri.parse('$baseUrl/$productId/$phoneId/getGroups'),
        headers: _headers,
      )
          .timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException('انتهت مهلة جلب المجموعات');
        },
      );

      print('استجابة جلب المجموعات: ${response.statusCode}');
      print('محتوى الاستجابة: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] != true || !data.containsKey('data')) {
          print('تم استلام استجابة ناجحة ولكن البيانات غير صالحة');
          print('استجابة API: $data');
          return [];
        }

        final List<dynamic> groupsData = data['data'];
        print('عدد المجموعات المستلمة: ${groupsData.length}');

        // توضيح محتوى البيانات للتشخيص
        if (groupsData.isNotEmpty) {
          print('عينة من بيانات المجموعة الأولى: ${groupsData[0]}');
        }

        // معالجة أكثر مرونة للبيانات
        return groupsData.map((group) {
          // تحديد عدد المشاركين
          int participants = 0;
          if (group['participants'] is List) {
            participants = (group['participants'] as List).length;
          } else if (group.containsKey('participants_count')) {
            participants = group['participants_count'] ?? 0;
          }

          // استخراج معرف المجموعة
          String groupId = '';
          if (group['id'] != null) {
            groupId = group['id'].toString();
          } else if (group.containsKey('_serialized')) {
            groupId = group['_serialized'].toString();
          } else if (group.containsKey('chatId')) {
            groupId = group['chatId'].toString();
          }

          if (groupId.isEmpty) {
            print('تحذير: مجموعة بدون معرف: $group');
            groupId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
          }

          // استخراج اسم المجموعة
          String groupName = group['name'] ?? 'مجموعة بدون اسم';
          if (groupName.isEmpty && group.containsKey('subject')) {
            groupName = group['subject'] ?? 'مجموعة بدون اسم';
          }

          // تحديد ما إذا كانت المجموعة نشطة
          bool isContact = group['isContact'] == true;
          if (!isContact && group.containsKey('isGroup')) {
            isContact = !(group['isGroup'] == true);
          }

          return WhatsAppGroup(
            id: groupId,
            name: groupName,
            participants: participants,
            isContact: isContact,
          );
        }).toList();
      } else {
        print('فشل في جلب مجموعات واتساب، رمز الحالة: ${response.statusCode}');
        print('محتوى الاستجابة: ${response.body}');

        throw WhatsAppApiException(
          'فشل في جلب مجموعات واتساب (${response.statusCode}): ${response.body}',
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
  Future<bool> sendTextMessage({
    required String phoneId,
    required String groupId,
    required String message,
  }) async {
    try {
      // رفض إرسال الرسائل الفارغة
      if (message.trim().isEmpty) {
        print('محاولة إرسال رسالة نصية فارغة، تم رفض الطلب');
        throw WhatsAppApiException('لا يمكن إرسال رسالة فارغة');
      }

      print('إرسال رسالة نصية إلى المجموعة: $groupId');

      final response = await _client
          .post(
        Uri.parse('$baseUrl/$productId/$phoneId/sendMessage'),
        headers: _headers,
        body: json.encode({
          'to_number': groupId,
          'type': 'text',
          'message': message,
        }),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('انتهت مهلة إرسال الرسالة');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else {
        throw WhatsAppApiException(
          'فشل في إرسال الرسالة النصية',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('خطأ في إرسال الرسالة النصية: $e');
      if (e is WhatsAppApiException) rethrow;
      throw WhatsAppApiException('خطأ في إرسال الرسالة النصية: $e');
    }
  }

  Future<bool> sendMultipleMedia({
    required String phoneId,
    required String groupId,
    required List<File> files,
    String? caption,
  }) async {
    try {
      // التحقق من وجود الملفات
      if (files.isEmpty) {
        print('قائمة ملفات الوسائط فارغة');
        throw WhatsAppApiException('لا توجد ملفات وسائط للإرسال');
      }

      print('إرسال ${files.length} وسائط إلى المجموعة: $groupId');

      // إضافة تتبع إضافي لتشخيص المشكلة
      for (int i = 0; i < files.length; i++) {
        print(
            'تحقق من الملف ${i + 1}: ${files[i].path}, الحجم: ${await files[i].length()} بايت');
      }

      // ملاحظة: تمت إزالة إضافة النص التوضيحي التلقائي
      String mediaCaption = caption ?? '';

      // إرسال رسالة نصية مسبقة إذا كان هناك عدد كبير من الصور
      if (files.length > 3 && caption != null && caption.isNotEmpty) {
        print('إرسال رسالة نصية مسبقة نظراً لوجود ${files.length} صور');
        await sendTextMessage(
          phoneId: phoneId,
          groupId: groupId,
          message:
              "$caption\n\n(${files.length} صور)", // إضافة عدد الصور للنص فقط
        );

        // لتجنب الازدواجية، نحذف النص التوضيحي من الصور
        mediaCaption = '';
      }

      // إرسال الصور واحدة تلو الأخرى مع فاصل زمني لتجنب الحظر
      bool allSuccess = true;
      int successCount = 0;

      // تخزين الصور التي تم إرسالها بنجاح لتسجيل التقدم
      List<int> successfulIndices = [];

      for (int i = 0; i < files.length; i++) {
        final file = files[i];

        try {
          // تحديد نص توضيحي خاص لكل صورة
          String currentCaption = '';

          // إضافة النص التوضيحي فقط للصورة الأولى إذا كان موجودًا
          if (i == 0 && mediaCaption.isNotEmpty) {
            currentCaption = mediaCaption;
          }

          print(
              'إرسال الصورة ${i + 1} من ${files.length} إلى المجموعة $groupId');

          // تأكد من وجود الملف قبل الإرسال
          if (!await file.exists()) {
            print('خطأ: الملف ${file.path} غير موجود');
            continue;
          }

          // إضافة تأخير قبل كل إرسال لتجنب الترشيح من قبل WhatsApp API
          if (i > 0) {
            // تأخير أطول بين الإرسالات المتتالية
            await Future.delayed(Duration(milliseconds: 1500));
          }

          final success = await sendMedia(
            phoneId: phoneId,
            groupId: groupId,
            file: file,
            caption: currentCaption,
          );

          if (success) {
            successCount++;
            successfulIndices.add(i);
            print('نجاح إرسال الصورة ${i + 1} من ${files.length}');
          } else {
            print('فشل إرسال الصورة ${i + 1} من ${files.length}');
            allSuccess = false;
          }
        } catch (e) {
          print('خطأ في إرسال الصورة ${i + 1}: $e');
          allSuccess = false;
        }
      }

      // إذا نجحت في إرسال بعض الصور على الأقل
      if (successCount > 0) {
        if (successCount < files.length) {
          print(
              'تم إرسال $successCount من أصل ${files.length} صور، الصور المرسلة: $successfulIndices');
        } else {
          print('تم إرسال جميع الصور بنجاح (${files.length})');
        }
        return true;
      }

      return false;
    } catch (e) {
      print('خطأ عام في إرسال الصور المتعددة: $e');

      // محاولة إرسال النص كرسالة منفصلة إذا فشل إرسال الوسائط
      if (caption != null && caption.isNotEmpty) {
        try {
          print('محاولة إرسال النص بدلاً من الوسائط بعد الفشل');
          return await sendTextMessage(
            phoneId: phoneId,
            groupId: groupId,
            message: '$caption (تعذر إرسال الصور)',
          );
        } catch (_) {
          // إذا فشل أيضًا
          if (e is WhatsAppApiException) rethrow;
          throw WhatsAppApiException('خطأ في إرسال الوسائط المتعددة: $e');
        }
      } else {
        if (e is WhatsAppApiException) rethrow;
        throw WhatsAppApiException('خطأ في إرسال الوسائط المتعددة: $e');
      }
    }
  }

  // إرسال وسائط (صور أو فيديو) إلى مجموعة
  Future<bool> sendMedia({
    required String phoneId,
    required String groupId,
    required File file,
    String? caption,
  }) async {
    try {
      // التحقق من وجود الملف
      if (!await file.exists()) {
        print('ملف الوسائط غير موجود: ${file.path}');
        throw WhatsAppApiException('ملف الوسائط غير موجود');
      }

      print('إرسال وسائط إلى المجموعة: $groupId');

      // تحديد نوع الملف
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
      final fileName = path.basename(file.path);

      // قراءة وتحويل الملف إلى base64
      final bytes = await file.readAsBytes();
      final base64File = base64Encode(bytes);

      // إنشاء بيانات الطلب - استخدام نفس التنسيق للصور والفيديو (data URI)
      final Map<String, dynamic> payload = {
        'to_number': groupId,
        'type': 'media',
        'message': 'data:$mimeType;base64,$base64File',
        'filename': fileName,
      };

      // إضافة النص التوضيحي إذا كان موجوداً
      if (caption != null && caption.isNotEmpty) {
        payload['text'] = caption;
      }

      print('إرسال طلب إلى: $baseUrl/$productId/$phoneId/sendMessage');

      final response = await _client
          .post(
        Uri.parse('$baseUrl/$productId/$phoneId/sendMessage'),
        headers: _headers,
        body: json.encode(payload),
      )
          .timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('انتهت مهلة إرسال الوسائط');
        },
      );

      print('استجابة إرسال الوسائط: ${response.statusCode}');
      print('محتوى الاستجابة: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else {
        throw WhatsAppApiException(
          'فشل في إرسال الوسائط: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('خطأ في إرسال الوسائط: $e');

      // محاولة إرسال النص كرسالة منفصلة إذا فشل إرسال الوسائط
      if (caption != null && caption.isNotEmpty) {
        try {
          print('محاولة إرسال النص بدلاً من الوسائط بعد الفشل');
          return await sendTextMessage(
            phoneId: phoneId,
            groupId: groupId,
            message: '$caption (تعذر إرسال الوسائط)',
          );
        } catch (_) {
          // إذا فشل أيضًا
          if (e is WhatsAppApiException) rethrow;
          throw WhatsAppApiException('خطأ في إرسال الوسائط: $e');
        }
      } else {
        if (e is WhatsAppApiException) rethrow;
        throw WhatsAppApiException('خطأ في إرسال الوسائط: $e');
      }
    }
  }

  // دالة موحدة لإرسال منشور (نص أو وسائط)
  Future<bool> sendPost({
    required String phoneId,
    required String groupId,
    String message = '',
    File? mediaFile,
    List<File>? mediaFiles,
  }) async {
    try {
      // أضف تأخير قصير قبل إرسال الطلب لتجنب التقييد على API
      await Future.delayed(const Duration(milliseconds: 300));

      // طباعة معلومات تشخيصية إضافية
      print('sendPost - groupId: $groupId, message length: ${message.length}');
      print(
          'sendPost - mediaFile: ${mediaFile != null}, mediaFiles: ${mediaFiles?.length ?? 0}');

      // التحقق من وجود ملفات وسائط متعددة (أكثر من ملف واحد)
      bool hasMultipleFiles = mediaFiles != null && mediaFiles.length > 1;

      // تحقق من وجود ملف وسائط منفرد صالح
      bool hasSingleFile = mediaFile != null && await mediaFile.exists();

      // إذا كان لدينا ملفات متعددة (أهم من ملف منفرد)
      if (hasMultipleFiles) {
        // التحقق من أن الملفات موجودة
        List<File> validFiles = [];
        for (var file in mediaFiles!) {
          if (await file.exists()) {
            validFiles.add(file);
            print('ملف صالح: ${file.path}, الحجم: ${await file.length()} بايت');
          } else {
            print('ملف غير صالح: ${file.path}');
          }
        }

        if (validFiles.isEmpty) {
          throw WhatsAppApiException('لا توجد ملفات وسائط صالحة للإرسال');
        }

        // إرسال الوسائط المتعددة مع الرسالة النصية
        print('إرسال ${validFiles.length} ملفات وسائط إلى المجموعة: $groupId');
        return await sendMultipleMedia(
          phoneId: phoneId,
          groupId: groupId,
          files: validFiles,
          caption: message.isNotEmpty ? message : null,
        );
      }
      // إذا كان لدينا ملف منفرد
      else if (hasSingleFile) {
        // تحقق من حجم الملف وتحذير إذا كان كبيرًا جدًا
        final fileSize = await mediaFile!.length();
        if (fileSize > 10 * 1024 * 1024) {
          // أكثر من 10 ميجابايت
          print(
              'تحذير: حجم الملف كبير (${(fileSize / (1024 * 1024)).toStringAsFixed(2)} ميجابايت) وقد يفشل الإرسال');
        }

        print('إرسال وسائط فردية إلى المجموعة: $groupId');
        // إرسال الوسائط مع أو بدون تعليق (حسب ما إذا كان النص فارغًا أم لا)
        return await sendMedia(
          phoneId: phoneId,
          groupId: groupId,
          file: mediaFile!,
          caption: message.isNotEmpty ? message : null,
        );
      }
      // إذا كان لدينا رسالة نصية فقط
      else if (message.isNotEmpty) {
        // إرسال رسالة نصية فقط
        print('إرسال رسالة نصية إلى المجموعة: $groupId');
        return await sendTextMessage(
          phoneId: phoneId,
          groupId: groupId,
          message: message,
        );
      }
      // لا توجد وسائط ولا رسالة نصية
      else {
        print('لا يمكن إرسال منشور فارغ (بدون نص ووسائط)');
        throw WhatsAppApiException('لا يمكن إرسال منشور فارغ (بدون نص ووسائط)');
      }
    } catch (e) {
      print('خطأ في إرسال المنشور: $e');
      if (e is WhatsAppApiException) rethrow;
      throw WhatsAppApiException('خطأ في إرسال المنشور: $e');
    }
  }
}
