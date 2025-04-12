import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import '../config/app_config.dart';
import '../models/tiktok_account.dart';

class TikTokApiException implements Exception {
  final String message;
  final int? statusCode;

  TikTokApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class TikTokService {
  final http.Client _client;

  TikTokService({http.Client? client}) : _client = client ?? http.Client();

  // إنشاء client_ticket فريد
  String generateClientTicket() {
    final random = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(16, (_) => chars[random.nextInt(chars.length)]).join();
  }

  // الحصول على رابط المصادقة التقليدي (للاحتفاظ بالتوافقية)
  Uri getAuthorizationUrl() {
    return Uri.parse(AppConfig.tiktokAuthUrl).replace(
      queryParameters: {
        'client_key': AppConfig.tiktokClientKey,
        'redirect_uri': AppConfig.tiktokRedirectUri,
        'response_type': 'code',
        'scope': AppConfig.tiktokPermissions.join(','),
        'state': 'myappstate123',
      },
    );
  }

  // طلب رمز QR من TikTok
  Future<Map<String, dynamic>> getQRCode() async {
    try {
      print('طلب رمز QR من TikTok...');

      final response = await _client.post(
        Uri.parse('${AppConfig.tiktokApiBaseUrl}/oauth/get_qrcode/'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_key': AppConfig.tiktokClientKey,
          'scope': AppConfig.tiktokPermissions.join(','),
          'state': 'myappstate123',
        },
      );

      print('استجابة طلب QR: ${response.statusCode}');
      print('محتوى الاستجابة: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data.containsKey('error')) {
          throw TikTokApiException(
            'خطأ في طلب رمز QR: ${data['error_description'] ?? data['error']}',
          );
        }

        if (!data.containsKey('scan_qrcode_url') ||
            !data.containsKey('token')) {
          throw TikTokApiException('بيانات رمز QR غير مكتملة في الاستجابة');
        }

        // إنشاء وإضافة client_ticket
        final clientTicket = generateClientTicket();
        String qrUrl = data['scan_qrcode_url'];

        // استبدال client_ticket في عنوان URL
        if (qrUrl.contains('client_ticket=tobefilled')) {
          qrUrl = qrUrl.replaceAll(
              'client_ticket=tobefilled', 'client_ticket=$clientTicket');
        } else if (qrUrl.contains('client_ticket=')) {
          final regex = RegExp(r'client_ticket=([^&]*)');
          qrUrl = qrUrl.replaceAllMapped(
              regex, (match) => 'client_ticket=$clientTicket');
        } else {
          // إضافة client_ticket إذا لم يكن موجودًا
          final separator = qrUrl.contains('?') ? '&' : '?';
          qrUrl = '$qrUrl${separator}client_ticket=$clientTicket';
        }

        return {
          'qr_url': qrUrl,
          'token': data['token'],
          'client_ticket': clientTicket,
        };
      } else {
        throw TikTokApiException(
          'فشل في طلب رمز QR: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('خطأ في طلب رمز QR: $e');
      if (e is TikTokApiException) rethrow;
      throw TikTokApiException('خطأ في الاتصال: $e');
    }
  }

  // التحقق من حالة رمز QR
  Future<Map<String, dynamic>> checkQRCodeStatus(
      String token, String clientTicket) async {
    try {
      print('التحقق من حالة رمز QR...');

      final response = await _client.post(
        Uri.parse('${AppConfig.tiktokApiBaseUrl}/oauth/check_qrcode/'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_key': AppConfig.tiktokClientKey,
          'client_secret': AppConfig.tiktokClientSecret,
          'token': token,
        },
      );

      print('استجابة التحقق من حالة QR: ${response.statusCode}');
      print('محتوى الاستجابة: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data.containsKey('error')) {
          throw TikTokApiException(
            'خطأ في التحقق من حالة QR: ${data['error_description'] ?? data['error']}',
          );
        }

        // التحقق من سلامة client_ticket إذا كان موجودًا
        if (data.containsKey('client_ticket') &&
            data['client_ticket'] != null &&
            data['client_ticket'] != '' &&
            data['client_ticket'] != clientTicket) {
          throw TikTokApiException(
              'عدم تطابق client_ticket، قد تكون هناك محاولة اختراق');
        }

        return data;
      } else {
        throw TikTokApiException(
          'فشل في التحقق من حالة QR: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('خطأ في التحقق من حالة QR: $e');
      if (e is TikTokApiException) rethrow;
      throw TikTokApiException('خطأ في الاتصال: $e');
    }
  }

  // استخلاص رمز التفويض من URI
  String? extractAuthCode(String redirectUri) {
    try {
      final uri = Uri.parse(redirectUri);
      return uri.queryParameters['code'];
    } catch (e) {
      print('خطأ في استخلاص رمز التفويض: $e');
      return null;
    }
  }

  // استبدال رمز المصادقة برمز الوصول
  Future<Map<String, dynamic>> exchangeCodeForToken(String authCode) async {
    try {
      print('استبدال رمز المصادقة برمز الوصول...');

      final response = await _client.post(
        Uri.parse('${AppConfig.tiktokApiBaseUrl}/oauth/token/'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_key': AppConfig.tiktokClientKey,
          'client_secret': AppConfig.tiktokClientSecret,
          'code': authCode,
          'grant_type': 'authorization_code',
          'redirect_uri': AppConfig.tiktokRedirectUri,
        },
      );

      print('استجابة استبدال الرمز: ${response.statusCode}');
      print('محتوى الاستجابة: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (!data.containsKey('access_token')) {
          throw TikTokApiException('لم يتم العثور على رمز الوصول في الاستجابة');
        }
        return data;
      } else {
        throw TikTokApiException(
          'فشل استبدال رمز المصادقة: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('خطأ في استبدال رمز المصادقة: $e');
      if (e is TikTokApiException) rethrow;
      throw TikTokApiException('خطأ في الاتصال: $e');
    }
  }

  // الحصول على معلومات المستخدم
  Future<Map<String, dynamic>> getUserInfo(String accessToken) async {
    try {
      print('جلب معلومات مستخدم تيك توك...');

      final response = await _client.get(
        Uri.parse('${AppConfig.tiktokApiBaseUrl}/user/info/'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      print('استجابة معلومات المستخدم: ${response.statusCode}');
      print('محتوى الاستجابة: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (!data.containsKey('data') || data['data'] == null) {
          throw TikTokApiException(
              'لم يتم العثور على بيانات المستخدم في الاستجابة');
        }
        return data['data'];
      } else {
        throw TikTokApiException(
          'فشل في الحصول على معلومات المستخدم: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('خطأ في الحصول على معلومات المستخدم: $e');
      if (e is TikTokApiException) rethrow;
      throw TikTokApiException('خطأ في الاتصال: $e');
    }
  }

  // تحديث رمز الوصول
  Future<Map<String, dynamic>> refreshAccessToken(String refreshToken) async {
    try {
      print('تحديث رمز الوصول لتيك توك...');

      final response = await _client.post(
        Uri.parse('${AppConfig.tiktokApiBaseUrl}/oauth/refresh_token/'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_key': AppConfig.tiktokClientKey,
          'client_secret': AppConfig.tiktokClientSecret,
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        },
      );

      print('استجابة تحديث الرمز: ${response.statusCode}');
      print('محتوى الاستجابة: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (!data.containsKey('access_token')) {
          throw TikTokApiException('لم يتم العثور على رمز الوصول في الاستجابة');
        }
        return data;
      } else {
        throw TikTokApiException(
          'فشل في تحديث رمز الوصول: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('خطأ في تحديث رمز الوصول: $e');
      if (e is TikTokApiException) rethrow;
      throw TikTokApiException('خطأ في الاتصال: $e');
    }
  }

  // بقية الدوال المتعلقة بتحميل الفيديو ونشره - لم يتم تغييرها من التنفيذ السابق

  // بدء تحميل فيديو
  Future<String> initVideoUpload(String accessToken, int fileSize) async {
    try {
      print('بدء تحميل فيديو تيك توك...');

      final response = await _client.post(
        Uri.parse('${AppConfig.tiktokApiBaseUrl}/video/init/'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'source_info': {
            'source': 'FILE_UPLOAD',
            'video_size': fileSize,
          }
        }),
      );

      print('استجابة بدء التحميل: ${response.statusCode}');
      print('محتوى الاستجابة: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (!data.containsKey('data') ||
            !data['data'].containsKey('upload_id')) {
          throw TikTokApiException(
              'لم يتم العثور على معرف التحميل في الاستجابة');
        }
        return data['data']['upload_id'];
      } else {
        throw TikTokApiException(
          'فشل في بدء تحميل الفيديو: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('خطأ في بدء تحميل الفيديو: $e');
      if (e is TikTokApiException) rethrow;
      throw TikTokApiException('خطأ في الاتصال: $e');
    }
  }

  // تحميل جزء من الفيديو
  Future<void> uploadVideoChunk(
    String accessToken,
    String uploadId,
    List<int> chunkData,
    int chunkIndex,
    Function(int progress)? onProgress,
  ) async {
    try {
      print('تحميل جزء الفيديو $chunkIndex...');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.tiktokApiBaseUrl}/video/fragment/'),
      );

      request.headers['Authorization'] = 'Bearer $accessToken';

      request.fields['upload_id'] = uploadId;
      request.fields['chunk_index'] = chunkIndex.toString();

      final multipartFile = http.MultipartFile.fromBytes(
        'video_binary',
        chunkData,
        filename: 'chunk_$chunkIndex.mp4',
        contentType: MediaType('video', 'mp4'),
      );

      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('استجابة تحميل الجزء: ${response.statusCode}');
      print('محتوى الاستجابة: ${response.body}');

      if (response.statusCode != 200) {
        throw TikTokApiException(
          'فشل في تحميل جزء الفيديو: ${response.body}',
          statusCode: response.statusCode,
        );
      }

      // الإبلاغ عن التقدم
      if (onProgress != null) {
        onProgress(chunkIndex);
      }
    } catch (e) {
      print('خطأ في تحميل جزء الفيديو: $e');
      if (e is TikTokApiException) rethrow;
      throw TikTokApiException('خطأ في الاتصال: $e');
    }
  }

  // إكمال تحميل الفيديو ونشر المنشور
  Future<String> completeVideoUpload(
    String accessToken,
    String uploadId,
    String caption,
  ) async {
    try {
      print('إنهاء تحميل فيديو تيك توك...');

      final response = await _client.post(
        Uri.parse('${AppConfig.tiktokApiBaseUrl}/video/publish/'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'upload_id': uploadId,
          'video_info': {
            'title': caption,
            'privacy_level': 'PUBLIC_TO_EVERYONE',
            'disable_duet': false,
            'disable_comment': false,
            'disable_stitch': false,
          }
        }),
      );

      print('استجابة إكمال التحميل: ${response.statusCode}');
      print('محتوى الاستجابة: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (!data.containsKey('data') ||
            !data['data'].containsKey('video_id')) {
          throw TikTokApiException(
              'لم يتم العثور على معرف الفيديو في الاستجابة');
        }
        return data['data']['video_id'];
      } else {
        throw TikTokApiException(
          'فشل في إكمال تحميل الفيديو: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('خطأ في إكمال تحميل الفيديو: $e');
      if (e is TikTokApiException) rethrow;
      throw TikTokApiException('خطأ في الاتصال: $e');
    }
  }

  // تحميل فيديو إلى تيك توك
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

      // التحقق من وجود الملف
      if (!await videoFile.exists()) {
        throw TikTokApiException('ملف الفيديو غير موجود');
      }

      // الحصول على حجم الملف
      final fileSize = await videoFile.length();
      if (fileSize > 1024 * 1024 * 60) {
        // حد 60 ميجابايت
        throw TikTokApiException(
            'حجم الفيديو يتجاوز الحد المسموح به (60 ميجابايت)');
      }

      // بدء التحميل
      if (onProgress != null) {
        onProgress('بدء التحميل...', 10);
      }

      final uploadId = await initVideoUpload(accessToken, fileSize);

      // قراءة بايتات الملف
      final videoBytes = await videoFile.readAsBytes();

      // حساب حجم الأجزاء (توصي تيك توك بأجزاء بحجم 5 ميجابايت)
      final int chunkSize = 5 * 1024 * 1024; // 5 ميجابايت
      final int totalChunks = (fileSize / chunkSize).ceil();

      // تحميل الأجزاء
      for (int i = 0; i < totalChunks; i++) {
        final int start = i * chunkSize;
        final int end =
            (start + chunkSize > fileSize) ? fileSize : start + chunkSize;
        final List<int> chunk = videoBytes.sublist(start, end);

        if (onProgress != null) {
          final progressPercent = 10 + ((i + 1) * 70 ~/ totalChunks);
          onProgress(
              'تحميل جزء الفيديو ${i + 1}/$totalChunks...', progressPercent);
        }

        await uploadVideoChunk(
          accessToken,
          uploadId,
          chunk,
          i,
          (progress) {
            if (onProgress != null) {
              final progressPercent = 10 + ((progress + 1) * 70 ~/ totalChunks);
              onProgress('تم تحميل الجزء ${progress + 1}/$totalChunks',
                  progressPercent);
            }
          },
        );
      }

      // إكمال التحميل والنشر
      if (onProgress != null) {
        onProgress('إنهاء وتنفيذ النشر...', 90);
      }

      final videoId = await completeVideoUpload(
        accessToken,
        uploadId,
        caption,
      );

      if (onProgress != null) {
        onProgress('تم نشر الفيديو بنجاح!', 100);
      }

      return videoId;
    } catch (e) {
      print('خطأ في تحميل الفيديو إلى تيك توك: $e');
      if (onProgress != null) {
        onProgress('خطأ: $e', 0);
      }
      if (e is TikTokApiException) rethrow;
      throw TikTokApiException('خطأ في تحميل الفيديو إلى تيك توك: $e');
    }
  }
}
