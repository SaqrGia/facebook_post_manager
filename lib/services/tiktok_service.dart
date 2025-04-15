import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import '../config/app_config.dart';
import 'dart:math';

/// استثناء مخصص لأخطاء TikTok API
class TikTokApiException implements Exception {
  final String message;
  final int? statusCode;

  TikTokApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// خدمة للتواصل مع TikTok API v2
///
/// تتعامل هذه الخدمة مع المصادقة، ونشر المحتوى، والحصول على معلومات المستخدم
/// باستخدام واجهة برمجة تطبيقات TikTok v2
class TikTokService {
  final http.Client _client;

  // عناوين API وفقًا للتوثيق الرسمي v2
  static const String _authUrl = 'https://www.tiktok.com/v2/auth/authorize/';
  static const String _tokenUrl = 'https://open.tiktokapis.com/v2/oauth/token/';
  static const String _userInfoUrl =
      'https://open.tiktokapis.com/v2/user/info/';
  static const String _qrCodeUrl =
      'https://open.tiktokapis.com/v2/oauth/get_qrcode/';
  static const String _checkQrCodeUrl =
      'https://open.tiktokapis.com/v2/oauth/check_qrcode/';
  static const String _refreshTokenUrl =
      'https://open.tiktokapis.com/v2/oauth/refresh_token/';

  // عناوين نشر المحتوى
  static const String _creatorInfoUrl =
      'https://open.tiktokapis.com/v2/post/publish/creator_info/query/';
  static const String _videoInitUrl =
      'https://open.tiktokapis.com/v2/post/publish/video/init/';
  static const String _publishStatusUrl =
      'https://open.tiktokapis.com/v2/post/publish/status/fetch/';

  TikTokService({http.Client? client}) : _client = client ?? http.Client();

  /// الحصول على رابط المصادقة - للأساليب التقليدية (غير QR)
  Uri getAuthorizationUrl() {
    final state = 'tiktok_auth_${DateTime.now().millisecondsSinceEpoch}';

    return Uri.parse(_authUrl).replace(
      queryParameters: {
        'client_key': AppConfig.tiktokClientKey,
        'redirect_uri': AppConfig.tiktokRedirectUri,
        'response_type': 'code',
        'scope': AppConfig.tiktokPermissions.join(','),
        'state': state,
      },
    );
  }

  /// طلب رمز QR للمصادقة
  ///
  /// يعود بعنوان URL لرمز QR وtoken للتحقق من حالة المسح
  Future<Map<String, dynamic>> getQRCode() async {
    try {
      final response = await _client.post(
        Uri.parse('https://open.tiktokapis.com/v2/oauth/get_qrcode/'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_key': AppConfig.tiktokClientKey,
          'scope': AppConfig.tiktokPermissions.join(','),
          'state': 'tiktok_qr_${DateTime.now().millisecondsSinceEpoch}',
        },
      );

      print('استجابة QR: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // التعامل مع الهيكل المباشر بدون data و error
        if (data != null &&
            data.containsKey('scan_qrcode_url') &&
            data.containsKey('token')) {
          // توليد معرّف فريد للعميل
          final random = Random();
          final clientTicket =
              'client_ticket_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(1000)}';

          // استبدال client_ticket في عنوان URL
          String qrUrl = data['scan_qrcode_url'] as String;
          if (qrUrl.contains('client_ticket=tobefilled')) {
            qrUrl = qrUrl.replaceFirst(
                'client_ticket=tobefilled', 'client_ticket=$clientTicket');
          }

          return {
            'qr_url': qrUrl,
            'token': data['token'],
            'client_ticket': clientTicket
          };
        }

        // محاولة التعامل مع الهياكل الأخرى المحتملة
        // ...

        throw TikTokApiException(
            'البيانات المستلمة غير متوافقة مع الهيكل المتوقع. البيانات: $data');
      } else {
        throw TikTokApiException(
          'فشل في طلب رمز QR: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is TikTokApiException) rethrow;
      throw TikTokApiException('خطأ في طلب رمز QR: $e');
    }
  }

  /// التحقق من حالة رمز QR
  ///
  /// يستخدم للتحقق مما إذا تم مسح الرمز وتأكيده
  Future<Map<String, dynamic>> checkQRCodeStatus(String token) async {
    try {
      // إعداد الطلب لفحص حالة رمز QR
      final response = await _client.post(
        Uri.parse(_checkQrCodeUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: 'client_key=${Uri.encodeComponent(AppConfig.tiktokClientKey)}'
            '&client_secret=${Uri.encodeComponent(AppConfig.tiktokClientSecret)}'
            '&token=${Uri.encodeComponent(token)}',
      );

      print('استجابة فحص QR: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // تعريف النتيجة الافتراضية
        Map<String, dynamic> result = {
          'status': 'unknown',
          'code': null,
        };

        // التعامل مع هيكل البيانات المباشر (بدون data و error)
        if (data != null) {
          // الحالة 1: هيكل بسيط مع status
          if (data.containsKey('status')) {
            result['status'] = data['status'];

            // إذا تم تأكيد المسح وتم استلام رمز
            if (data['status'] == 'confirmed' && data.containsKey('code')) {
              // استخدام الرمز كاملاً بدون تنظيف أو تعديل
              result['code'] = data['code'];
              print('تم استلام رمز التفويض: ${data['code']}');
            }

            // حفظ state لاستخدامه لاحقًا إذا كان متوفرًا
            if (data.containsKey('state')) {
              result['state'] = data['state'];
            }

            // حفظ client_ticket لاستخدامه لاحقًا إذا كان متوفرًا
            if (data.containsKey('client_ticket')) {
              result['client_ticket'] = data['client_ticket'];
            }

            return result;
          }

          // الحالة 2: هيكل مع data و error
          if (data.containsKey('error') && data.containsKey('data')) {
            // إذا كان هناك خطأ، نتحقق من رمز الخطأ
            final error = data['error'];
            if (error != null && error['code'] != 'ok') {
              throw TikTokApiException(
                'خطأ في التحقق من حالة QR: ${error['message'] ?? "خطأ غير معروف"}',
              );
            }

            // إذا كانت البيانات موجودة، نستخرجها
            final responseData = data['data'];
            if (responseData != null) {
              result['status'] = responseData['status'] ?? 'unknown';
              if (responseData.containsKey('code')) {
                // استخدام الرمز كاملاً بدون تنظيف
                result['code'] = responseData['code'];
                print('تم استلام رمز التفويض: ${responseData['code']}');
              }

              // الحفاظ على أي معلومات إضافية
              if (responseData.containsKey('state')) {
                result['state'] = responseData['state'];
              }
              if (responseData.containsKey('client_ticket')) {
                result['client_ticket'] = responseData['client_ticket'];
              }
            }
            return result;
          }
        }

        // في حالة عدم التعرف على هيكل البيانات، نعيد النتيجة الافتراضية
        print('لم يتم التعرف على هيكل البيانات: $data');
        return result;
      } else {
        throw TikTokApiException(
          'فشل في التحقق من حالة QR: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('خطأ في التحقق من حالة QR: $e');
      if (e is TikTokApiException) rethrow;
      throw TikTokApiException('خطأ في التحقق من حالة QR: $e');
    }
  }

  /// استبدال رمز المصادقة برمز الوصول
  ///
  /// يستخدم رمز المصادقة (الذي تم الحصول عليه من عملية المصادقة) للحصول على رمز الوصول
  Future<Map<String, dynamic>> exchangeCodeForToken(String authCode) async {
    try {
      print('معالجة رمز التفويض: $authCode');

      // Limpiar el código eliminando todo después del caracter "*"
      String cleanedCode = authCode;
      // if (authCode.contains('*')) {
      //   int starIndex = authCode.indexOf('*');
      //   cleanedCode = authCode.substring(0, starIndex);
      //   print('الرمز بعد التنظيف: $cleanedCode');
      // }

      // Asegurar que redirect_uri termina con "/"
      String redirectUri = AppConfig.tiktokRedirectUri;
      if (!redirectUri.endsWith('/')) {
        redirectUri = redirectUri + '/';
      }

      // Construir el cuerpo de la solicitud sin codificar el código de autorización
      final body =
          'client_key=${Uri.encodeComponent(AppConfig.tiktokClientKey)}'
          '&client_secret=${Uri.encodeComponent(AppConfig.tiktokClientSecret)}'
          '&code=$cleanedCode' // NO codificar el código de autorización
          '&grant_type=authorization_code'
          '&redirect_uri=${Uri.encodeComponent(redirectUri)}';

      print('إرسال طلب تبادل الرمز مع الجسم: $body');

      final response = await _client.post(
        Uri.parse(_tokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
        },
        body: body,
      );

      print('استجابة تبادل الرمز: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Verificar si hay errores en la respuesta
        if (data.containsKey('error')) {
          print(
              'خطأ في تبادل الرمز: ${data['error_description'] ?? data['error']}');
          throw TikTokApiException(
            'خطأ في تبادل الرمز: ${data['error_description'] ?? data['error']}',
          );
        }

        // Procesar diferentes formatos de respuesta
        if (data.containsKey('access_token')) {
          return data;
        } else if (data.containsKey('data') && data['data'] != null) {
          if (data['data'].containsKey('access_token')) {
            return data['data'];
          }
        }

        throw TikTokApiException(
            'البيانات المستلمة لا تحتوي على رمز الوصول: $data');
      } else {
        throw TikTokApiException(
          'فشل في تبادل رمز المصادقة: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('خطأ في تبادل رمز المصادقة: $e');
      if (e is TikTokApiException) rethrow;
      throw TikTokApiException('خطأ في تبادل رمز المصادقة: $e');
    }
  }

  /// تجديد رمز الوصول
  ///
  /// يستخدم رمز التحديث للحصول على رمز وصول جديد
  Future<Map<String, dynamic>> refreshAccessToken(String refreshToken) async {
    try {
      final response = await _client.post(
        Uri.parse(_refreshTokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_key': AppConfig.tiktokClientKey,
          'client_secret': AppConfig.tiktokClientSecret,
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['error']['code'] != 'ok') {
          throw TikTokApiException(
            'خطأ في تجديد الرمز: ${data['error']['message']}',
            statusCode: response.statusCode,
          );
        }

        return data['data'];
      } else {
        throw TikTokApiException(
          'فشل في تجديد رمز الوصول: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is TikTokApiException) rethrow;
      throw TikTokApiException('خطأ في تجديد رمز الوصول: $e');
    }
  }

  /// الحصول على معلومات المستخدم
  ///
  /// يستخدم رمز الوصول للحصول على معلومات المستخدم
  Future<Map<String, dynamic>> getUserInfo(String accessToken) async {
    try {
      final response = await _client.get(
        Uri.parse(_userInfoUrl).replace(
          queryParameters: {
            'fields':
                'open_id,union_id,avatar_url,display_name,bio_description,profile_deep_link',
          },
        ),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['error']['code'] != 'ok') {
          throw TikTokApiException(
            'خطأ في الحصول على معلومات المستخدم: ${data['error']['message']}',
            statusCode: response.statusCode,
          );
        }

        return data['data'];
      } else {
        throw TikTokApiException(
          'فشل في الحصول على معلومات المستخدم: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is TikTokApiException) rethrow;
      throw TikTokApiException('خطأ في الحصول على معلومات المستخدم: $e');
    }
  }

  /// استعلام معلومات المنشئ وخياراته المتاحة
  Future<Map<String, dynamic>> queryCreatorInfo(String accessToken) async {
    try {
      final response = await _client.post(
        Uri.parse(_creatorInfoUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['error']['code'] != 'ok') {
          throw TikTokApiException(
            'خطأ في استعلام معلومات المنشئ: ${data['error']['message']}',
            statusCode: response.statusCode,
          );
        }

        return data;
      } else {
        throw TikTokApiException(
          'فشل في استعلام معلومات المنشئ: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is TikTokApiException) rethrow;
      throw TikTokApiException('خطأ في استعلام معلومات المنشئ: $e');
    }
  }

  /// بدء تحميل فيديو
  Future<Map<String, dynamic>> initVideoUpload({
    required String accessToken,
    required int fileSize,
    required String caption,
    required Map<String, dynamic> creatorInfo,
  }) async {
    try {
      // الحصول على خيارات الخصوصية المتاحة من معلومات المنشئ
      List<dynamic> privacyOptions =
          creatorInfo['data']['privacy_level_options'] ?? ['SELF_ONLY'];
      String privacyLevel = privacyOptions.contains('PUBLIC_TO_EVERYONE')
          ? 'PUBLIC_TO_EVERYONE'
          : privacyOptions.first.toString();

      // حساب حجم الأجزاء المثالي للتحميل
      int chunkSize = fileSize < 5 * 1024 * 1024
          ? fileSize
          : fileSize < 64 * 1024 * 1024
              ? 10 * 1024 * 1024 // 10 ميجابايت للملفات المتوسطة
              : 64 * 1024 * 1024; // 64 ميجابايت للملفات الكبيرة

      int totalChunkCount = (fileSize / chunkSize).ceil();

      final response = await _client.post(
        Uri.parse(_videoInitUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode({
          "post_info": {
            "title": caption,
            "privacy_level": privacyLevel,
            "disable_duet": creatorInfo['data']['duet_disabled'] ?? false,
            "disable_comment": creatorInfo['data']['comment_disabled'] ?? false,
            "disable_stitch": creatorInfo['data']['stitch_disabled'] ?? false,
          },
          "source_info": {
            "source": "FILE_UPLOAD",
            "video_size": fileSize,
            "chunk_size": chunkSize,
            "total_chunk_count": totalChunkCount,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['error']['code'] != 'ok') {
          throw TikTokApiException(
            'خطأ في بدء تحميل الفيديو: ${data['error']['message']}',
            statusCode: response.statusCode,
          );
        }

        return {
          'publish_id': data['data']['publish_id'],
          'upload_url': data['data']['upload_url'],
        };
      } else {
        throw TikTokApiException(
          'فشل في بدء تحميل الفيديو: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is TikTokApiException) rethrow;
      throw TikTokApiException('خطأ في بدء تحميل الفيديو: $e');
    }
  }

  /// تحميل جزء من الفيديو
  Future<void> uploadVideoChunk({
    required String uploadUrl,
    required List<int> chunkData,
    required int startByte,
    required int endByte,
    required int totalFileSize,
    required String mimeType,
  }) async {
    try {
      final request = http.Request('PUT', Uri.parse(uploadUrl));

      // إضافة الترويسات المطلوبة
      request.headers['Content-Type'] = mimeType;
      request.headers['Content-Length'] = chunkData.length.toString();
      request.headers['Content-Range'] =
          'bytes $startByte-$endByte/$totalFileSize';

      // إضافة محتوى الجزء
      request.bodyBytes = chunkData;

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      // التحقق من صحة الاستجابة - قبول 206 للتحميل الجزئي و201 للتحميل الكامل
      if (response.statusCode != 206 && response.statusCode != 201) {
        throw TikTokApiException(
          'فشل في تحميل جزء الفيديو. الرمز: ${response.statusCode}، الرسالة: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is TikTokApiException) rethrow;
      throw TikTokApiException('خطأ في تحميل جزء الفيديو: $e');
    }
  }

  /// التحقق من حالة النشر
  Future<Map<String, dynamic>> checkPublishStatus(
      String accessToken, String publishId) async {
    try {
      final response = await _client.post(
        Uri.parse(_publishStatusUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode({
          'publish_id': publishId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['error']['code'] != 'ok') {
          throw TikTokApiException(
            'خطأ في استعلام حالة النشر: ${data['error']['message']}',
            statusCode: response.statusCode,
          );
        }

        return data;
      } else {
        throw TikTokApiException(
          'فشل في استعلام حالة النشر: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is TikTokApiException) rethrow;
      throw TikTokApiException('خطأ في التحقق من حالة النشر: $e');
    }
  }

  /// تحميل فيديو كامل (عملية مبسطة)
  Future<String> uploadVideo({
    required String accessToken,
    required File videoFile,
    required String caption,
    Function(String status, int progressPercent)? onProgress,
  }) async {
    try {
      if (onProgress != null) {
        onProgress('تحضير تحميل الفيديو...', 5);
      }

      // 1. التحقق من وجود الملف
      if (!await videoFile.exists()) {
        throw TikTokApiException('ملف الفيديو غير موجود');
      }

      // 2. استعلام معلومات المنشئ (مطلوب)
      if (onProgress != null) {
        onProgress('استعلام معلومات المستخدم...', 10);
      }
      final creatorInfoResponse = await queryCreatorInfo(accessToken);

      // 3. الحصول على حجم الملف
      final fileSize = await videoFile.length();
      if (fileSize > 4 * 1024 * 1024 * 1024) {
        // الحد 4 جيجابايت
        throw TikTokApiException(
            'حجم الفيديو يتجاوز الحد المسموح به (4 جيجابايت)');
      }

      // 4. بدء عملية التحميل
      if (onProgress != null) {
        onProgress('تهيئة عملية التحميل...', 20);
      }
      final initData = await initVideoUpload(
        accessToken: accessToken,
        fileSize: fileSize,
        caption: caption,
        creatorInfo: creatorInfoResponse,
      );

      final String publishId = initData['publish_id'];
      final String uploadUrl = initData['upload_url'];

      // 5. قراءة محتوى الملف
      if (onProgress != null) {
        onProgress('قراءة الفيديو...', 30);
      }
      final videoBytes = await videoFile.readAsBytes();

      // 6. تحديد نوع الوسائط
      final mimeType = lookupMimeType(videoFile.path) ?? 'video/mp4';

      // 7. حساب حجم الأجزاء
      int chunkSize = fileSize < 5 * 1024 * 1024
          ? fileSize.toInt()
          : fileSize < 64 * 1024 * 1024
              ? 10 * 1024 * 1024 // 10 ميجابايت للملفات المتوسطة
              : 64 * 1024 * 1024; // 64 ميجابايت للملفات الكبيرة

      final int totalChunks = (fileSize / chunkSize).ceil();

      // 8. تحميل الأجزاء
      if (totalChunks == 1) {
        // إذا كان الملف يمكن تحميله دفعة واحدة
        if (onProgress != null) {
          onProgress('تحميل الفيديو...', 40);
        }

        await uploadVideoChunk(
          uploadUrl: uploadUrl,
          chunkData: videoBytes,
          startByte: 0,
          endByte: fileSize - 1,
          totalFileSize: fileSize,
          mimeType: mimeType,
        );
      } else {
        // إذا كان يجب تقسيم الملف إلى أجزاء
        for (int i = 0; i < totalChunks; i++) {
          final int start = i * chunkSize;
          final int end = (start + chunkSize > fileSize)
              ? fileSize - 1
              : start + chunkSize - 1;
          final List<int> chunk = videoBytes.sublist(start, end + 1);

          if (onProgress != null) {
            final progressPercent = 40 + ((i + 1) * 40 ~/ totalChunks);
            onProgress(
                'تحميل جزء الفيديو ${i + 1}/$totalChunks...', progressPercent);
          }

          await uploadVideoChunk(
            uploadUrl: uploadUrl,
            chunkData: chunk,
            startByte: start,
            endByte: end,
            totalFileSize: fileSize,
            mimeType: mimeType,
          );

          // انتظار قصير بين الأجزاء
          if (i < totalChunks - 1) {
            await Future.delayed(Duration(milliseconds: 500));
          }
        }
      }

      // 9. فحص حالة النشر
      if (onProgress != null) {
        onProgress('التحقق من حالة النشر...', 90);
      }

      bool isComplete = false;
      int attempts = 0;
      const maxAttempts = 30;
      String? videoId;

      while (!isComplete && attempts < maxAttempts) {
        attempts++;

        await Future.delayed(Duration(seconds: 3));

        final statusResponse = await checkPublishStatus(accessToken, publishId);

        if (statusResponse['data'] != null &&
            statusResponse['data']['status'] != null) {
          final status = statusResponse['data']['status'];

          if (status == 'PUBLISH_OK' || status == 'SUCCESS') {
            isComplete = true;
            videoId = statusResponse['data']['video_id'] ?? publishId;

            if (onProgress != null) {
              onProgress('تم نشر الفيديو بنجاح!', 100);
            }
          } else if (status == 'PROCESSING') {
            if (onProgress != null) {
              onProgress('جاري معالجة الفيديو... (${attempts}/${maxAttempts})',
                  90 + (attempts * 10 ~/ maxAttempts));
            }
          } else if (status == 'FAILED' || status == 'ERROR') {
            throw TikTokApiException(
              'فشل في نشر الفيديو: ${statusResponse['data']['error_message'] ?? "خطأ غير معروف"}',
            );
          }
        }
      }

      if (!isComplete) {
        throw TikTokApiException(
            'استغرق تأكيد نشر الفيديو وقتًا طويلاً. يرجى التحقق من حساب تيك توك.');
      }

      return videoId ?? publishId;
    } catch (e) {
      if (onProgress != null) {
        onProgress('خطأ: $e', 0);
      }
      if (e is TikTokApiException) rethrow;
      throw TikTokApiException('خطأ في تحميل الفيديو: $e');
    }
  }
}
