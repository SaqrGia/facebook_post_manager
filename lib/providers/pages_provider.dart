import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/page.dart';
import '../models/instagram_account.dart';
import '../services/facebook_service.dart';
import '../services/storage_service.dart';
import '../providers/auth_provider.dart';
import 'package:mime/mime.dart';

class PagesProvider with ChangeNotifier {
  final FacebookService _facebookService;
  final StorageService _storageService;
  final AuthProvider _authProvider;

  List<FacebookPage> _pages = [];
  List<InstagramAccount> _instagramAccounts = [];
  Set<String> _selectedPageIds = {};
  Set<String> _selectedInstagramIds = {};
  bool _isLoading = false;
  String? _error;

  // إضافة متغيرات لمراقبة تقدم عملية نشر REELS
  String _uploadStatus = '';
  int _uploadProgress = 0;
  bool _isUploading = false;

  // getters لمتغيرات التقدم
  String get uploadStatus => _uploadStatus;
  int get uploadProgress => _uploadProgress;
  bool get isUploading => _isUploading;

  PagesProvider({
    required AuthProvider authProvider,
    FacebookService? facebookService,
    StorageService? storageService,
  })  : _authProvider = authProvider,
        _facebookService = facebookService ?? FacebookService(),
        _storageService = storageService ?? StorageService();

  // Getters
  List<FacebookPage> get pages => List.unmodifiable(_pages);
  List<InstagramAccount> get instagramAccounts =>
      List.unmodifiable(_instagramAccounts);
  List<FacebookPage> get selectedPages =>
      _pages.where((page) => _selectedPageIds.contains(page.id)).toList();
  List<InstagramAccount> get selectedInstagramAccounts => _instagramAccounts
      .where((account) => _selectedInstagramIds.contains(account.id))
      .toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  // دوال اختيار الصفحات وحسابات Instagram
  void togglePageSelection(String pageId) {
    if (_selectedPageIds.contains(pageId)) {
      _selectedPageIds.remove(pageId);
    } else {
      _selectedPageIds.add(pageId);
    }
    notifyListeners();
  }

  void toggleInstagramSelection(String instagramId) {
    if (_selectedInstagramIds.contains(instagramId)) {
      _selectedInstagramIds.remove(instagramId);
    } else {
      _selectedInstagramIds.add(instagramId);
    }
    notifyListeners();
  }

  bool isPageSelected(String pageId) => _selectedPageIds.contains(pageId);

  bool isInstagramSelected(String instagramId) =>
      _selectedInstagramIds.contains(instagramId);

  // تحميل الصفحات وحسابات Instagram
  Future<void> loadPages() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _authProvider.getAccessToken();
      if (token == null) {
        throw Exception('لم يتم العثور على رمز الوصول');
      }

      _pages = await _facebookService.getPages(token);
      await _storageService.saveSelectedPages(_pages);

      // جلب حسابات Instagram
      _instagramAccounts = await _facebookService.getInstagramAccounts(token);
    } catch (e) {
      _error = e.toString();
      // محاولة تحميل الصفحات المخزنة محلياً
      _pages = await _storageService.getSelectedPages();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateUploadStatus(String status, int progress, bool hasError) {
    _isUploading = true;
    _uploadStatus = status;
    _uploadProgress = progress;

    // في حالة النجاح مع نسبة 100%، نتحقق من عدم وجود خطأ فعلي
    if (progress == 100 && !hasError) {
      // اترك حالة الرفع ظاهرة لفترة كافية لعرض النجاح
      Future.delayed(Duration(seconds: 3), () {
        if (_uploadProgress == 100) {
          _isUploading = false;
          notifyListeners();
        }
      });
    }

    // إذا حدث خطأ، نحدث حالة الخطأ ونخفي مؤشر التقدم
    if (hasError) {
      _error = status;

      // تأخير قصير قبل إخفاء مؤشر التقدم
      Future.delayed(Duration(seconds: 2), () {
        _isUploading = false;
        notifyListeners();
      });
    }

    notifyListeners();
  }

  // إنشاء منشور - مع دعم نشر الفيديو كـ REELS على Instagram
  Future<bool> createPostOnSelectedPages({
    String message = '',
    String? link,
    List<File>? mediaFiles,
    BuildContext? context, // إضافة معلمة Context لعرض واجهة تقدم العملية
  }) async {
    if (selectedPages.isEmpty && selectedInstagramAccounts.isEmpty) {
      _error = 'الرجاء اختيار صفحة فيسبوك أو حساب انستقرام واحد على الأقل';
      notifyListeners();
      return false;
    }

    if (message.isEmpty && (mediaFiles == null || mediaFiles.isEmpty)) {
      _error = 'يجب إدخال نص أو اختيار وسائط على الأقل';
      notifyListeners();
      return false;
    }

    _isLoading = true;

    // إعادة تعيين متغيرات التقدم
    _isUploading = false;
    _uploadProgress = 0;
    _uploadStatus = '';
    _error = null; // تصفير رسالة الخطأ في بداية العملية

    notifyListeners();

    try {
      String? fbPostId; // لتخزين معرف منشور الفيسبوك
      bool anySuccess = false; // للتأكد من نجاح النشر على الأقل منصة واحدة

      // التحقق هل الوسائط فيديو
      bool isVideo = false;
      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        isVideo = lookupMimeType(mediaFiles.first.path)?.startsWith('video/') ??
            false;
      }

      // التحقق هل لدينا صور متعددة
      bool hasMultipleImages =
          mediaFiles != null && mediaFiles.length > 1 && !isVideo;

      // النشر على صفحات Facebook
      bool facebookSuccess = false;
      if (selectedPages.isNotEmpty) {
        try {
          _isUploading = true;
          _uploadStatus = 'جاري النشر على صفحات Facebook...';
          _uploadProgress = 10;
          notifyListeners();

          for (final page in selectedPages) {
            // نشر المحتوى على الصفحة
            fbPostId = await _facebookService.createPost(
              pageId: page.id,
              pageAccessToken: page.accessToken,
              message: message,
              link: link,
              mediaFiles: mediaFiles,
            );

            print(
                'تم النشر على صفحة Facebook: ${page.name}, معرف المنشور: $fbPostId');
          }

          facebookSuccess = true;
          anySuccess = true;

          _uploadStatus = 'تم النشر على Facebook بنجاح!';
          _uploadProgress = 30;
          notifyListeners();
        } catch (e) {
          print('خطأ في النشر على Facebook: $e');
          _error = 'فشل النشر على Facebook: $e';
          notifyListeners();
        }
      }

      // النشر على حسابات Instagram
      bool instagramSuccess = false;
      if (mediaFiles != null &&
          mediaFiles.isNotEmpty &&
          selectedInstagramAccounts.isNotEmpty) {
        _isUploading = true;
        _uploadStatus = 'جاري الاستعداد للنشر على Instagram...';
        _uploadProgress = 40;
        notifyListeners();

        for (final igAccount in selectedInstagramAccounts) {
          try {
            print('جاري النشر على حساب Instagram: ${igAccount.username}');

            String igPostId;

            if (isVideo) {
              // استخدام دالة النشر المحسنة للـ REELS
              igPostId = await _facebookService.publishToInstagramWithFallback(
                instagramAccountId: igAccount.id,
                pageAccessToken: igAccount.pageAccessToken,
                mediaFile: mediaFiles.first,
                caption: message,
                onProgress: (status, progressPercent) {
                  // حساب التقدم مع تعديل مدى النسبة ليكون بين 40% و 90%
                  int adjustedProgress = 40 + ((progressPercent * 50) ~/ 100);
                  _uploadStatus = status;
                  _uploadProgress = adjustedProgress;
                  notifyListeners();
                },
              );
            } else if (hasMultipleImages) {
              // للصور المتعددة - استخدام طريقة الألبوم
              _uploadStatus = 'جاري نشر ألبوم صور على Instagram...';
              _uploadProgress = 50;
              notifyListeners();

              igPostId = await _facebookService.publishToInstagramWithFallback(
                instagramAccountId: igAccount.id,
                pageAccessToken: igAccount.pageAccessToken,
                mediaFiles: mediaFiles,
                caption: message,
                onProgress: (status, progressPercent) {
                  // حساب التقدم مع تعديل مدى النسبة ليكون بين 40% و 90%
                  int adjustedProgress = 40 + ((progressPercent * 50) ~/ 100);
                  _uploadStatus = status;
                  _uploadProgress = adjustedProgress;
                  notifyListeners();
                },
              );
            } else {
              // للصور المفردة - استخدام الطريقة العادية
              _uploadStatus = 'جاري نشر الصورة على Instagram...';
              _uploadProgress = 50;
              notifyListeners();

              igPostId = await _facebookService.publishToInstagram(
                instagramAccountId: igAccount.id,
                pageAccessToken: igAccount.pageAccessToken,
                imageFile: mediaFiles.first,
                caption: message,
              );
            }

            print('تم النشر على Instagram بنجاح! معرف المنشور: $igPostId');
            instagramSuccess = true;
            anySuccess = true;

            _uploadStatus = 'تم النشر على Instagram بنجاح!';
            _uploadProgress = 100;
            notifyListeners();

            // إخفاء مؤشر التقدم بعد فترة
            Future.delayed(Duration(seconds: 3), () {
              if (_uploadProgress == 100) {
                _isUploading = false;
                notifyListeners();
              }
            });
          } catch (e) {
            String errorMsg =
                'فشل في النشر على Instagram (${igAccount.username}): $e';
            print(errorMsg);
            _error = errorMsg;
            _uploadProgress = 0;
            notifyListeners();

            // لا نعيد الخطأ، بل نستمر مع باقي الحسابات
          }
        }
      }

      // إذا لم ينجح النشر على أي منصة
      if (!anySuccess) {
        _error = 'فشل النشر على جميع المنصات المحددة';
        _isUploading = false;
        notifyListeners();
        return false;
      }

      // إذا كان هناك خطأ ولكن تم النشر على بعض الحسابات بنجاح، نعدل رسالة الخطأ
      if (_error != null && anySuccess) {
        _error = 'تم النشر على بعض الحسابات، ولكن حدثت أخطاء أخرى: $_error';
        notifyListeners();
      }

      return anySuccess;
    } catch (e) {
      _error = e.toString();

      // تحديث الحالة في واجهة المستخدم
      _isUploading = false;
      _uploadStatus = 'حدث خطأ: $e';
      _uploadProgress = 0;
      notifyListeners();

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // عرض واجهة تقدم عملية الرفع
  Widget buildUploadProgressWidget() {
    if (!_isUploading) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'نشر على Instagram',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _uploadProgress / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              _uploadProgress == 100 ? Colors.green : Colors.purple,
            ),
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
          ),
          const SizedBox(height: 8),
          Text(
            '$_uploadProgress%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _uploadProgress == 100 ? Colors.green : Colors.purple,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                _uploadProgress == 100 ? Icons.check_circle : Icons.upload,
                color: _uploadProgress == 100 ? Colors.green : Colors.purple,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_uploadStatus),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // الدوال الإضافية
  Future<Map<String, dynamic>?> getPageInsights({
    required String pageId,
    required String metric,
    required String period,
  }) async {
    try {
      final page = _pages.firstWhere((p) => p.id == pageId);
      return await _facebookService.getPageInsights(
        pageId: pageId,
        pageAccessToken: page.accessToken,
        metric: metric,
        period: period,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> scheduleBatchPosts({
    required String pageId,
    required List<Map<String, dynamic>> posts,
  }) async {
    try {
      final page = _pages.firstWhere((p) => p.id == pageId);
      final postIds = await _facebookService.scheduleBatchPosts(
        pageId: pageId,
        pageAccessToken: page.accessToken,
        posts: posts,
      );
      return postIds.isNotEmpty;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  FacebookPage? getPageById(String pageId) {
    try {
      return _pages.firstWhere((page) => page.id == pageId);
    } catch (_) {
      return null;
    }
  }

  void clearSelection() {
    _selectedPageIds.clear();
    _selectedInstagramIds.clear();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
