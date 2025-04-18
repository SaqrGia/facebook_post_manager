import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import '../config/app_config.dart';
import '../models/page.dart';
import '../models/instagram_account.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class FacebookApiException implements Exception {
  final String message;
  final int? statusCode;

  FacebookApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class FacebookService {
  final http.Client _client;

  FacebookService({http.Client? client}) : _client = client ?? http.Client();

  // جلب صفحات Facebook
  Future<List<FacebookPage>> getPages(String accessToken) async {
    try {
      print('جلب الصفحات باستخدام التوكن: ${accessToken.substring(0, 10)}...');

      final response = await _client.get(
        Uri.parse('${AppConfig.baseUrl}/me/accounts').replace(
          queryParameters: {
            'access_token': accessToken,
            'fields':
                'id,name,access_token,category,picture,fan_count,talking_about_count,instagram_business_account',
            'limit': '100', // زيادة حد النتائج
          },
        ),
      );

      print('استجابة جلب الصفحات: ${response.statusCode}');
      print('محتوى الاستجابة: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (!data.containsKey('data') || data['data'] == null) {
          throw FacebookApiException('البيانات غير متوفرة');
        }

        final List<dynamic> pagesData = data['data'];
        print('عدد الصفحات المسترجعة: ${pagesData.length}');

        return pagesData
            .map((pageData) => FacebookPage.fromJson(pageData))
            .toList();
      } else {
        throw FacebookApiException(
          'فشل في جلب الصفحات: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('خطأ في جلب الصفحات: $e');
      if (e is FacebookApiException) rethrow;
      throw FacebookApiException('خطأ في الاتصال: $e');
    }
  }

  // جلب حسابات Instagram المرتبطة بصفحات Facebook
  Future<List<InstagramAccount>> getInstagramAccounts(
      String accessToken) async {
    try {
      print('جلب حسابات Instagram...');
      final List<FacebookPage> pages = await getPages(accessToken);
      List<InstagramAccount> instagramAccounts = [];

      for (var page in pages) {
        print('فحص الصفحة ${page.name} للبحث عن حساب Instagram...');

        // إذا كان لدينا معلومات Instagram مباشرة من استجابة الصفحات
        if (page.instagramBusinessAccount != null) {
          final igAccountId = page.instagramBusinessAccount!['id'];
          print('تم العثور على حساب Instagram مباشرة: $igAccountId');

          final igResponse = await _client.get(
            Uri.parse('${AppConfig.baseUrl}/$igAccountId').replace(
              queryParameters: {
                'access_token': page.accessToken,
                'fields': 'id,username,profile_picture_url'
              },
            ),
          );

          if (igResponse.statusCode == 200) {
            final igData = json.decode(igResponse.body);
            instagramAccounts.add(InstagramAccount(
                id: igData['id'],
                username: igData['username'],
                profilePictureUrl: igData['profile_picture_url'],
                pageId: page.id,
                pageAccessToken: page.accessToken));
          }
        } else {
          // طريقة بديلة للبحث عن حساب Instagram
          final response = await _client.get(
            Uri.parse('${AppConfig.baseUrl}/${page.id}').replace(
              queryParameters: {
                'access_token': page.accessToken,
                'fields': 'instagram_business_account'
              },
            ),
          );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data.containsKey('instagram_business_account') &&
                data['instagram_business_account'] != null) {
              final igAccountId = data['instagram_business_account']['id'];
              print('تم العثور على حساب Instagram: $igAccountId');

              final igResponse = await _client.get(
                Uri.parse('${AppConfig.baseUrl}/$igAccountId').replace(
                  queryParameters: {
                    'access_token': page.accessToken,
                    'fields': 'id,username,profile_picture_url'
                  },
                ),
              );

              if (igResponse.statusCode == 200) {
                final igData = json.decode(igResponse.body);
                instagramAccounts.add(InstagramAccount(
                    id: igData['id'],
                    username: igData['username'],
                    profilePictureUrl: igData['profile_picture_url'],
                    pageId: page.id,
                    pageAccessToken: page.accessToken));
              }
            }
          }
        }
      }

      print('عدد حسابات Instagram المسترجعة: ${instagramAccounts.length}');
      return instagramAccounts;
    } catch (e) {
      print('خطأ في جلب حسابات Instagram: $e');
      throw FacebookApiException('فشل في جلب حسابات Instagram: $e');
    }
  }

  Future<File> prepareImageForInstagram(File imageFile,
      {bool isCarousel = false}) async {
    try {
      // قراءة الصورة
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        throw FacebookApiException('فشل في قراءة الصورة');
      }

      // الحصول على أبعاد الصورة
      final width = image.width;
      final height = image.height;
      final aspectRatio = width / height;

      // نسب العرض إلى الارتفاع المدعومة من Instagram
      double minRatio =
          isCarousel ? 1.0 : 0.8; // 1:1 للألبوم، 4:5 للصور الفردية
      double maxRatio = 1.91; // 1.91:1 لكليهما

      img.Image? resizedImage;

      // إذا كانت النسبة ضمن الحدود المدعومة
      if (aspectRatio >= minRatio && aspectRatio <= maxRatio) {
        // لا نحتاج لتغيير أبعاد الصورة
        return imageFile;
      }

      // إذا كانت النسبة أقل من الحد الأدنى (صورة طويلة جداً)
      if (aspectRatio < minRatio) {
        // حساب العرض الجديد بناءً على النسبة الدنيا
        final newWidth = (height * minRatio).round();

        // إنشاء صورة جديدة بخلفية بيضاء
        resizedImage = img.Image(width: newWidth, height: height);
        img.fill(resizedImage, color: img.ColorRgb8(255, 255, 255));

        // وضع الصورة الأصلية في المنتصف
        final offsetX = (newWidth - width) ~/ 2;
        img.compositeImage(resizedImage, image, dstX: offsetX, dstY: 0);
      }
      // إذا كانت النسبة أكبر من الحد الأقصى (صورة عريضة جداً)
      else if (aspectRatio > maxRatio) {
        // حساب الارتفاع الجديد بناءً على النسبة القصوى
        final newHeight = (width / maxRatio).round();

        // إنشاء صورة جديدة بخلفية بيضاء
        resizedImage = img.Image(width: width, height: newHeight);
        img.fill(resizedImage, color: img.ColorRgb8(255, 255, 255));

        // وضع الصورة الأصلية في المنتصف
        final offsetY = (newHeight - height) ~/ 2;
        img.compositeImage(resizedImage, image, dstX: 0, dstY: offsetY);
      }

      if (resizedImage == null) {
        return imageFile;
      }

      // حفظ الصورة المعدلة في ملف مؤقت
      final tempDir = await getTemporaryDirectory();
      final fileName = path.basename(imageFile.path);
      final targetPath = path.join(tempDir.path, 'instagram_$fileName');

      final File outputFile = File(targetPath);
      await outputFile.writeAsBytes(img.encodeJpg(resizedImage, quality: 95));

      return outputFile;
    } catch (e) {
      print('خطأ في تحضير الصورة لإنستغرام: $e');
      // في حالة الخطأ نعيد الصورة الأصلية ونسجل الخطأ
      return imageFile;
    }
  }

  // نشر منشور على Facebook
  Future<String> createPost({
    required String pageId,
    required String pageAccessToken,
    String message = '', // جعل الرسالة اختيارية مع قيمة افتراضية فارغة
    String? link,
    List<File>? mediaFiles,
  }) async {
    try {
      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        // تحديد إذا كان فيديو أو صور
        bool isVideo =
            lookupMimeType(mediaFiles[0].path)?.startsWith('video/') ?? false;

        if (isVideo) {
          // نشر فيديو مع/بدون رسالة
          return _publishVideoWithMessage(
              pageId, pageAccessToken, message, mediaFiles[0], link);
        } else {
          // نشر صور مع/بدون رسالة
          return _publishPhotosWithMessage(
              pageId, pageAccessToken, message, mediaFiles, link);
        }
      } else if (message.isNotEmpty || link != null) {
        // نشر نص فقط أو رابط
        final Map<String, String> body = {
          'access_token': pageAccessToken,
        };

        if (message.isNotEmpty) body['message'] = message;
        if (link != null) body['link'] = link;

        final response = await _client.post(
          Uri.parse('${AppConfig.baseUrl}/$pageId/feed'),
          body: body,
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          return data['id'] as String;
        } else {
          throw FacebookApiException(
            'فشل في نشر المنشور',
            statusCode: response.statusCode,
          );
        }
      } else {
        throw FacebookApiException('يجب توفير نص أو وسائط أو رابط للنشر');
      }
    } catch (e) {
      if (e is FacebookApiException) rethrow;
      throw FacebookApiException('خطأ في النشر: $e');
    }
  }

  // نشر صور مع رسالة
  Future<String> _publishPhotosWithMessage(
    String pageId,
    String pageAccessToken,
    String message,
    List<File> photos,
    String? link,
  ) async {
    try {
      // في حالة صورة واحدة
      if (photos.length == 1) {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('${AppConfig.baseUrl}/$pageId/photos'),
        );

        request.fields['access_token'] = pageAccessToken;
        if (message.isNotEmpty) {
          request.fields['message'] = message;
        }
        if (link != null) request.fields['link'] = link;

        final file = photos[0];
        final stream = http.ByteStream(file.openRead());
        final length = await file.length();
        final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';

        final multipartFile = http.MultipartFile(
          'source',
          stream,
          length,
          filename: path.basename(file.path),
          contentType: MediaType.parse(mimeType),
        );

        request.files.add(multipartFile);

        final response = await http.Response.fromStream(await request.send());

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data['post_id'] ?? data['id'];
        } else {
          throw FacebookApiException(
            'فشل في نشر الصورة',
            statusCode: response.statusCode,
          );
        }
      }
      // في حالة صور متعددة
      else {
        // أولاً، نرفع كل صورة للحصول على معرفات الصور
        List<String> photoIds = [];

        for (final file in photos) {
          var request = http.MultipartRequest(
            'POST',
            Uri.parse('${AppConfig.baseUrl}/$pageId/photos'),
          );

          request.fields['access_token'] = pageAccessToken;
          request.fields['published'] = 'false'; // لا ننشر الصور بعد

          final stream = http.ByteStream(file.openRead());
          final length = await file.length();
          final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';

          final multipartFile = http.MultipartFile(
            'source',
            stream,
            length,
            filename: path.basename(file.path),
            contentType: MediaType.parse(mimeType),
          );

          request.files.add(multipartFile);

          final response = await http.Response.fromStream(await request.send());

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            photoIds.add(data['id']);
          } else {
            throw FacebookApiException(
              'فشل في رفع الصورة',
              statusCode: response.statusCode,
            );
          }
        }

        // ثم ننشر المنشور مع معرفات الصور
        final Map<String, dynamic> body = {
          'access_token': pageAccessToken,
        };

        if (message.isNotEmpty) {
          body['message'] = message;
        }
        if (link != null) body['link'] = link;

        // إضافة معرفات الصور
        for (int i = 0; i < photoIds.length; i++) {
          body['attached_media[$i]'] = '{"media_fbid":"${photoIds[i]}"}';
        }

        final response = await _client.post(
          Uri.parse('${AppConfig.baseUrl}/$pageId/feed'),
          body: body,
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data['id'];
        } else {
          throw FacebookApiException(
            'فشل في نشر المنشور مع الصور',
            statusCode: response.statusCode,
          );
        }
      }
    } catch (e) {
      if (e is FacebookApiException) rethrow;
      throw FacebookApiException('خطأ في نشر الصور: $e');
    }
  }

  // نشر فيديو مع رسالة
  Future<String> _publishVideoWithMessage(
    String pageId,
    String pageAccessToken,
    String message,
    File video,
    String? link,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/$pageId/videos'),
      );

      request.fields['access_token'] = pageAccessToken;
      if (message.isNotEmpty) {
        request.fields['description'] = message;
      }
      if (link != null) request.fields['link'] = link;

      final stream = http.ByteStream(video.openRead());
      final length = await video.length();
      final mimeType = lookupMimeType(video.path) ?? 'video/mp4';

      final multipartFile = http.MultipartFile(
        'source',
        stream,
        length,
        filename: path.basename(video.path),
        contentType: MediaType.parse(mimeType),
      );

      request.files.add(multipartFile);

      final response = await http.Response.fromStream(await request.send());

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['id'];
      } else {
        throw FacebookApiException(
          'فشل في نشر الفيديو',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is FacebookApiException) rethrow;
      throw FacebookApiException('خطأ في نشر الفيديو: $e');
    }
  }

  // نشر صورة على Instagram
  Future<String> publishToInstagram({
    required String instagramAccountId,
    required String pageAccessToken,
    required File imageFile,
    String caption = '',
  }) async {
    try {
      print('بدء نشر صورة على Instagram...');

      // تأكد من أن الملف موجود
      if (!await imageFile.exists()) {
        throw FacebookApiException('ملف الصورة غير موجود');
      }

      // 1. أولاً: رفع الصورة إلى Facebook للحصول على URL
      var uploadRequest = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/me/photos'),
      );

      uploadRequest.fields['access_token'] = pageAccessToken;
      uploadRequest.fields['published'] = 'false'; // لا ننشر على Facebook

      final stream = http.ByteStream(imageFile.openRead());
      final length = await imageFile.length();

      final multipartFile = http.MultipartFile(
        'source',
        stream,
        length,
        filename: path.basename(imageFile.path),
      );

      uploadRequest.files.add(multipartFile);

      final uploadResponse =
          await http.Response.fromStream(await uploadRequest.send());
      print('استجابة رفع الصورة: ${uploadResponse.statusCode}');
      print('محتوى استجابة الرفع: ${uploadResponse.body}');

      if (uploadResponse.statusCode != 200) {
        throw FacebookApiException(
          'فشل في رفع الصورة لإنستقرام: ${uploadResponse.body}',
          statusCode: uploadResponse.statusCode,
        );
      }

      // استخراج رقم تعريف الصورة
      final uploadData = json.decode(uploadResponse.body);
      final photoId = uploadData['id'];

      // استخراج URL الصورة
      final photoResponse = await _client.get(
        Uri.parse('${AppConfig.baseUrl}/$photoId').replace(
          queryParameters: {
            'access_token': pageAccessToken,
            'fields': 'images',
          },
        ),
      );

      final photoData = json.decode(photoResponse.body);
      final imageUrl = photoData['images'][0]['source'];

      print('تم الحصول على URL الصورة: $imageUrl');

      // 2. إنشاء container Instagram باستخدام URL الصورة
      final containerResponse = await _client.post(
        Uri.parse('${AppConfig.baseUrl}/$instagramAccountId/media'),
        body: {
          'access_token': pageAccessToken,
          'image_url': imageUrl,
          'caption': caption,
        },
      );

      print('استجابة container: ${containerResponse.statusCode}');
      print('محتوى استجابة container: ${containerResponse.body}');

      if (containerResponse.statusCode != 200) {
        throw FacebookApiException(
          'فشل في تحضير الوسائط للنشر على Instagram: ${containerResponse.body}',
          statusCode: containerResponse.statusCode,
        );
      }

      final containerData = json.decode(containerResponse.body);
      if (!containerData.containsKey('id')) {
        throw FacebookApiException(
          'لم يتم العثور على معرف container في الاستجابة: ${containerResponse.body}',
        );
      }

      final String containerId = containerData['id'];
      print('تم إنشاء container بنجاح, ID: $containerId');

      // إضافة تأخير قبل النشر - قد يساعد في بعض الحالات
      await Future.delayed(Duration(seconds: 2));

      // 3. نشر الوسائط باستخدام container ID
      final publishResponse = await _client.post(
        Uri.parse('${AppConfig.baseUrl}/$instagramAccountId/media_publish'),
        body: {
          'access_token': pageAccessToken,
          'creation_id': containerId,
        },
      );

      print('استجابة النشر: ${publishResponse.statusCode}');
      print('محتوى استجابة النشر: ${publishResponse.body}');

      if (publishResponse.statusCode == 200) {
        final publishData = json.decode(publishResponse.body);
        print('تم النشر بنجاح على Instagram');

        // إضافة تنبيه للتأكد من اكتمال العملية حتى لو أظهر التطبيق نجاح مزيفاً
        print('تحقق من نجاح النشر: $publishData');

        return publishData['id'];
      } else {
        throw FacebookApiException(
          'فشل في نشر الوسائط على Instagram: ${publishResponse.body}',
          statusCode: publishResponse.statusCode,
        );
      }
    } catch (e) {
      print('خطأ في النشر على Instagram: $e');
      if (e is FacebookApiException) rethrow;
      throw FacebookApiException('خطأ في النشر على Instagram: $e');
    }
  }

  Future<String> publishInstagramCarousel({
    required String instagramAccountId,
    required String pageAccessToken,
    required List<File> imageFiles,
    String caption = '',
  }) async {
    try {
      print('بدء نشر ألبوم صور على Instagram...');

      if (imageFiles.isEmpty) {
        throw FacebookApiException('لا توجد صور لنشرها');
      }

      // 1. أولاً: نقوم برفع كل صورة والحصول على container IDs
      List<String> containerIds = [];

      for (int i = 0; i < imageFiles.length; i++) {
        final file = imageFiles[i];
        print('جاري رفع الصورة ${i + 1} من ${imageFiles.length}...');

        // رفع الصورة إلى Facebook للحصول على URL
        var uploadRequest = http.MultipartRequest(
          'POST',
          Uri.parse('${AppConfig.baseUrl}/me/photos'),
        );

        uploadRequest.fields['access_token'] = pageAccessToken;
        uploadRequest.fields['published'] = 'false'; // لا ننشر على Facebook

        final stream = http.ByteStream(file.openRead());
        final length = await file.length();

        final multipartFile = http.MultipartFile(
          'source',
          stream,
          length,
          filename: path.basename(file.path),
        );

        uploadRequest.files.add(multipartFile);

        final uploadResponse =
            await http.Response.fromStream(await uploadRequest.send());

        if (uploadResponse.statusCode != 200) {
          throw FacebookApiException(
            'فشل في رفع الصورة لإنستقرام: ${uploadResponse.body}',
            statusCode: uploadResponse.statusCode,
          );
        }

        // استخراج رقم تعريف الصورة
        final uploadData = json.decode(uploadResponse.body);
        final photoId = uploadData['id'];

        // استخراج URL الصورة
        final photoResponse = await _client.get(
          Uri.parse('${AppConfig.baseUrl}/$photoId').replace(
            queryParameters: {
              'access_token': pageAccessToken,
              'fields': 'images',
            },
          ),
        );

        final photoData = json.decode(photoResponse.body);
        final imageUrl = photoData['images'][0]['source'];

        print('تم الحصول على URL الصورة ${i + 1}: $imageUrl');

        // إنشاء container Instagram للصورة
        final containerResponse = await _client.post(
          Uri.parse('${AppConfig.baseUrl}/$instagramAccountId/media'),
          body: {
            'access_token': pageAccessToken,
            'image_url': imageUrl,
            // نضيف التعليق فقط للصورة الأولى في الألبوم (وليس لكل صورة)
            if (i == 0 && caption.isNotEmpty) 'caption': caption,
          },
        );

        if (containerResponse.statusCode != 200) {
          throw FacebookApiException(
            'فشل في تحضير الوسائط للنشر على Instagram: ${containerResponse.body}',
            statusCode: containerResponse.statusCode,
          );
        }

        final containerData = json.decode(containerResponse.body);
        final String containerId = containerData['id'];
        print('تم إنشاء container للصورة ${i + 1}, ID: $containerId');

        containerIds.add(containerId);
      }

      // 2. إنشاء carousel media container باستخدام children_ids
      // المشكلة كانت في طريقة تنسيق معرفات children - التصحيح أدناه
      print('إنشاء carousel container باستخدام ${containerIds.length} صورة...');

      // تكوين قائمة JSON للـ children بصيغة صحيحة
      final Map<String, String> carouselParams = {
        'access_token': pageAccessToken,
        'media_type': 'CAROUSEL',
      };

      // إضافة معرفات children بصيغة مختلفة (مفتاح منفرد لكل معرف)
      for (int i = 0; i < containerIds.length; i++) {
        carouselParams['children[$i]'] = containerIds[i];
      }

      // اطبع المعلمات للتدقيق
      print('معلمات carousel: $carouselParams');

      final carouselResponse = await _client.post(
        Uri.parse('${AppConfig.baseUrl}/$instagramAccountId/media'),
        body: carouselParams,
      );

      print('استجابة carousel container: ${carouselResponse.statusCode}');
      print('محتوى استجابة carousel: ${carouselResponse.body}');

      if (carouselResponse.statusCode != 200) {
        throw FacebookApiException(
          'فشل في إنشاء carousel container للنشر على Instagram: ${carouselResponse.body}',
          statusCode: carouselResponse.statusCode,
        );
      }

      final carouselData = json.decode(carouselResponse.body);
      if (!carouselData.containsKey('id')) {
        throw FacebookApiException(
          'لم يتم العثور على معرف carousel container في الاستجابة: ${carouselResponse.body}',
        );
      }

      final String carouselId = carouselData['id'];
      print('تم إنشاء carousel container بنجاح, ID: $carouselId');

      // 3. نشر الألبوم باستخدام carousel container ID
      // إضافة تأخير قبل محاولة النشر لإعطاء Instagram وقتًا لمعالجة الصور
      await Future.delayed(Duration(seconds: 3));

      final publishResponse = await _client.post(
        Uri.parse('${AppConfig.baseUrl}/$instagramAccountId/media_publish'),
        body: {
          'access_token': pageAccessToken,
          'creation_id': carouselId,
        },
      );

      print('استجابة نشر الألبوم: ${publishResponse.statusCode}');
      print('محتوى استجابة النشر: ${publishResponse.body}');

      if (publishResponse.statusCode == 200) {
        final publishData = json.decode(publishResponse.body);
        print('تم النشر بنجاح على Instagram كألبوم صور');
        return publishData['id'];
      } else {
        throw FacebookApiException(
          'فشل في نشر الألبوم على Instagram: ${publishResponse.body}',
          statusCode: publishResponse.statusCode,
        );
      }
    } catch (e) {
      print('خطأ في نشر ألبوم على Instagram: $e');
      if (e is FacebookApiException) rethrow;
      throw FacebookApiException('خطأ في نشر ألبوم على Instagram: $e');
    }
  }

  // دالة لنشر الـ REELS على Instagram
  Future<String> publishReelsToInstagram({
    required String instagramAccountId,
    required String pageAccessToken,
    required File videoFile,
    String caption = '',
    Function(String status, int progressPercent)? onProgress,
  }) async {
    try {
      print('بدء عملية نشر REELS على Instagram باستخدام الطريقة الرسمية...');

      // تحديث التقدم
      if (onProgress != null) {
        onProgress('بدء رفع الفيديو إلى Facebook...', 10);
      }

      // 1. أولاً، نرفع الفيديو إلى صفحة Facebook (دون نشره) للحصول على URL
      print('رفع الفيديو إلى Facebook للحصول على URL...');

      // استخدام واجهة API لرفع الفيديو
      var uploadRequest = http.MultipartRequest(
        'POST',
        Uri.parse('https://graph.facebook.com/v17.0/me/videos'),
      );

      uploadRequest.fields['access_token'] = pageAccessToken;
      uploadRequest.fields['published'] = 'false'; // مهم: نرفع بدون نشر
      uploadRequest.fields['description'] =
          'Video for Instagram REELS'; // وصف داخلي

      // إعداد ملف الفيديو
      final stream = http.ByteStream(videoFile.openRead());
      final length = await videoFile.length();
      final mimeType = lookupMimeType(videoFile.path) ?? 'video/mp4';

      final multipartFile = http.MultipartFile(
        'source', // المعلمة المطلوبة لرفع الفيديو إلى Facebook
        stream,
        length,
        filename: path.basename(videoFile.path),
        contentType: MediaType.parse(mimeType),
      );

      uploadRequest.files.add(multipartFile);

      print('جاري رفع الفيديو إلى Facebook...');

      if (onProgress != null) {
        onProgress('جاري رفع الفيديو...', 20);
      }

      final uploadResponse =
          await http.Response.fromStream(await uploadRequest.send());

      print('استجابة رفع الفيديو إلى Facebook: ${uploadResponse.statusCode}');
      print('محتوى استجابة الرفع: ${uploadResponse.body}');

      if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
        throw FacebookApiException(
          'فشل في رفع الفيديو إلى Facebook: ${uploadResponse.body}',
          statusCode: uploadResponse.statusCode,
        );
      }

      // 2. الحصول على معرف الفيديو واستخراج URL
      final uploadData = json.decode(uploadResponse.body);
      if (!uploadData.containsKey('id')) {
        throw FacebookApiException(
            'لم يتم العثور على معرف الفيديو في استجابة Facebook');
      }

      final String videoId = uploadData['id'];
      print('تم رفع الفيديو بنجاح، معرف الفيديو: $videoId');

      // انتظار قليلاً للتأكد من معالجة الفيديو
      await Future.delayed(const Duration(seconds: 5));

      if (onProgress != null) {
        onProgress('جلب رابط الفيديو...', 40);
      }

      // 3. الحصول على رابط الفيديو
      print('جلب رابط الفيديو من Facebook...');
      final videoResponse = await http.get(
        Uri.parse('https://graph.facebook.com/v17.0/$videoId').replace(
          queryParameters: {
            'access_token': pageAccessToken,
            'fields': 'source', // نحتاج إلى حقل source للحصول على URL
          },
        ),
      );

      print('استجابة جلب رابط الفيديو: ${videoResponse.statusCode}');
      print('محتوى استجابة جلب الرابط: ${videoResponse.body}');

      if (videoResponse.statusCode != 200) {
        throw FacebookApiException(
          'فشل في الحصول على رابط الفيديو: ${videoResponse.body}',
          statusCode: videoResponse.statusCode,
        );
      }

      final videoData = json.decode(videoResponse.body);
      if (!videoData.containsKey('source')) {
        throw FacebookApiException(
            'لم يتم العثور على رابط الفيديو في الاستجابة');
      }

      final String videoUrl = videoData['source'];
      print('تم الحصول على رابط الفيديو: $videoUrl');

      if (onProgress != null) {
        onProgress('إنشاء container للريلز...', 50);
      }

      // 4. إنشاء container على Instagram باستخدام الرابط
      print('إنشاء container للريلز على Instagram باستخدام رابط الفيديو...');
      final containerResponse = await http.post(
        Uri.parse('https://graph.facebook.com/v17.0/$instagramAccountId/media'),
        body: {
          'access_token': pageAccessToken,
          'media_type': 'REELS',
          'video_url': videoUrl, // هذا هو الحقل المطلوب
          if (caption.isNotEmpty) 'caption': caption,
        },
      );

      print('استجابة إنشاء container: ${containerResponse.statusCode}');
      print('محتوى استجابة container: ${containerResponse.body}');

      if (containerResponse.statusCode != 200) {
        throw FacebookApiException(
          'فشل في إنشاء container للريلز: ${containerResponse.body}',
          statusCode: containerResponse.statusCode,
        );
      }

      final containerData = json.decode(containerResponse.body);
      if (!containerData.containsKey('id')) {
        throw FacebookApiException(
            'لم يتم العثور على معرف container في الاستجابة');
      }

      final String containerId = containerData['id'];
      print('تم إنشاء container بنجاح، المعرف: $containerId');

      // 5. انتظار اكتمال معالجة الريلز
      bool isReady = false;
      int attempts = 0;
      const maxAttempts = 60; // زيادة عدد المحاولات للملفات الكبيرة

      print('انتظار اكتمال معالجة الريلز...');

      while (!isReady && attempts < maxAttempts) {
        attempts++;

        // تحديث تقدم المعالجة
        if (onProgress != null) {
          int progress = 50 + (attempts * 40 ~/ maxAttempts);
          if (progress > 90) progress = 90;
          onProgress(
              'معالجة الفيديو... (${attempts}/${maxAttempts})', progress);
        }

        await Future.delayed(const Duration(seconds: 3));

        final statusResponse = await http.get(
          Uri.parse('https://graph.facebook.com/v17.0/$containerId').replace(
            queryParameters: {
              'access_token': pageAccessToken,
              'fields': 'status_code',
            },
          ),
        );

        if (statusResponse.statusCode == 200) {
          final statusData = json.decode(statusResponse.body);
          final statusCode = statusData['status_code'] ?? 'UNKNOWN';

          print('حالة معالجة الريلز (محاولة $attempts): $statusCode');

          if (statusCode == 'FINISHED') {
            isReady = true;
          } else if (statusCode == 'ERROR' || statusCode == 'EXPIRED') {
            throw FacebookApiException(
              'فشل في معالجة الريلز: $statusCode',
            );
          }
          // الاستمرار في الانتظار للحالات الأخرى
        } else {
          print('خطأ في الحصول على حالة الريلز: ${statusResponse.statusCode}');
          // الاستمرار في المحاولة
        }
      }

      if (!isReady) {
        throw FacebookApiException('استغرق تحميل الريلز وقتاً طويلاً جداً');
      }

      if (onProgress != null) {
        onProgress('نشر الريلز على Instagram...', 95);
      }

      // 6. نشر الريلز
      print('نشر الريلز على Instagram...');
      final publishResponse = await http.post(
        Uri.parse(
            'https://graph.facebook.com/v17.0/$instagramAccountId/media_publish'),
        body: {
          'access_token': pageAccessToken,
          'creation_id': containerId,
        },
      );

      print('استجابة النشر: ${publishResponse.statusCode}');
      print('محتوى استجابة النشر: ${publishResponse.body}');

      if (publishResponse.statusCode == 200) {
        final publishData = json.decode(publishResponse.body);
        print('تم نشر الريلز على Instagram بنجاح!');

        if (onProgress != null) {
          onProgress('تم النشر بنجاح!', 100);
        }

        return publishData['id'];
      } else {
        throw FacebookApiException(
          'فشل في نشر الريلز على Instagram: ${publishResponse.body}',
          statusCode: publishResponse.statusCode,
        );
      }
    } catch (e) {
      print('خطأ نهائي في نشر الريلز على Instagram: $e');

      if (onProgress != null) {
        onProgress('حدث خطأ: $e', 0);
      }

      if (e is FacebookApiException) rethrow;
      throw FacebookApiException('خطأ في نشر الريلز على Instagram: $e');
    }
  }

  // دالة مبسطة للنشر على Instagram (للصور والفيديو)
  Future<String> publishToInstagramWithFallback({
    required String instagramAccountId,
    required String pageAccessToken,
    File? mediaFile,
    List<File>? mediaFiles,
    String? videoUrl,
    String caption = '',
    Function(String status, int progressPercent)? onProgress,
  }) async {
    try {
      // تحديث حالة التقدم
      if (onProgress != null) {
        onProgress('بدء عملية النشر على Instagram...', 5);
      }

      // التحقق من وجود ملفات وسائط متعددة
      bool hasMultipleFiles = mediaFiles != null && mediaFiles.length > 1;

      // إذا كان لدينا ملف واحد وليس لدينا قائمة ملفات متعددة
      if (mediaFile != null && !hasMultipleFiles) {
        // التحقق هل الملف فيديو
        bool isVideo =
            lookupMimeType(mediaFile.path)?.startsWith('video/') ?? false;

        // تحديث حالة التقدم
        if (onProgress != null) {
          onProgress(
              isVideo
                  ? 'جاري تحضير الفيديو للنشر...'
                  : 'جاري تحضير الصورة للنشر...',
              10);
        }

        if (isVideo) {
          // نشر فيديو كـ REELS
          print('نشر فيديو على Instagram كـ REELS...');
          String result = await publishReelsToInstagram(
            instagramAccountId: instagramAccountId,
            pageAccessToken: pageAccessToken,
            videoFile: mediaFile,
            caption: caption,
            onProgress: onProgress,
          );

          if (onProgress != null) {
            onProgress('تم نشر الفيديو بنجاح!', 100);
          }

          return result;
        } else {
          // نشر صورة فردية
          print('نشر صورة فردية على Instagram...');

          if (onProgress != null) {
            onProgress('جاري نشر الصورة على Instagram...', 20);
          }

          final result = await publishToInstagram(
            instagramAccountId: instagramAccountId,
            pageAccessToken: pageAccessToken,
            imageFile: mediaFile,
            caption: caption,
          );

          if (onProgress != null) {
            onProgress('تم نشر الصورة بنجاح!', 100);
          }

          return result;
        }
      }
      // إذا كان لدينا ملفات متعددة (أكثر من صورة واحدة)
      else if (hasMultipleFiles) {
        // نشر ألبوم (carousel)
        if (onProgress != null) {
          onProgress('جاري تحضير ألبوم الصور للنشر...', 10);
        }

        final result = await publishInstagramCarousel(
          instagramAccountId: instagramAccountId,
          pageAccessToken: pageAccessToken,
          imageFiles: mediaFiles,
          caption: caption,
        );

        if (onProgress != null) {
          onProgress('تم نشر ألبوم الصور بنجاح!', 100);
        }

        return result;
      } else {
        throw FacebookApiException('يجب توفير ملف وسائط للنشر على Instagram');
      }
    } catch (e) {
      print('خطأ في نشر المحتوى على Instagram: $e');

      if (onProgress != null) {
        onProgress('حدث خطأ: $e', 0);
      }

      if (e is FacebookApiException) rethrow;
      throw FacebookApiException('خطأ في نشر المحتوى على Instagram: $e');
    }
  }

  // دوال إضافية مثل getPageInsights و scheduleBatchPosts
  Future<Map<String, dynamic>> getPageInsights({
    required String pageId,
    required String pageAccessToken,
    required String metric,
    required String period,
  }) async {
    try {
      final response = await _client.get(
        Uri.parse('${AppConfig.baseUrl}/$pageId/insights').replace(
          queryParameters: {
            'access_token': pageAccessToken,
            'metric': metric,
            'period': period,
          },
        ),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw FacebookApiException(
          'فشل في جلب الإحصائيات',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is FacebookApiException) rethrow;
      throw FacebookApiException('خطأ في جلب الإحصائيات: $e');
    }
  }

  Future<List<String>> scheduleBatchPosts({
    required String pageId,
    required String pageAccessToken,
    required List<Map<String, dynamic>> posts,
  }) async {
    try {
      final batch = posts
          .map((post) => {
                'method': 'POST',
                'relative_url': '$pageId/feed',
                'body': {
                  'message': post['message'],
                  'access_token': pageAccessToken,
                  if (post['link'] != null) 'link': post['link'],
                  if (post['photo_id'] != null) 'photo_id': post['photo_id'],
                  if (post['video_id'] != null) 'video_id': post['video_id'],
                },
              })
          .toList();

      final response = await _client.post(
        Uri.parse('${AppConfig.baseUrl}'),
        body: {
          'access_token': pageAccessToken,
          'batch': jsonEncode(batch),
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        return results
            .map((result) {
              final bodyData = json.decode(result['body']);
              return bodyData['id']?.toString() ?? '';
            })
            .where((id) => id.isNotEmpty)
            .toList();
      } else {
        throw FacebookApiException(
          'فشل في جدولة المنشورات',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is FacebookApiException) rethrow;
      throw FacebookApiException('خطأ في جدولة المنشورات: $e');
    }
  }
}
