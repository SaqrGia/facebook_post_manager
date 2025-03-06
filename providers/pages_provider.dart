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

    notifyListeners();

    try {
      String? videoUrl; // سنخزن هنا رابط الفيديو
      String? fbPostId; // لتخزين معرف منشور الفيسبوك

      // التحقق هل الوسائط فيديو
      bool isVideo = false;
      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        isVideo = lookupMimeType(mediaFiles.first.path)?.startsWith('video/') ??
            false;
      }

      // النشر على صفحات Facebook
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

      // النشر على حسابات Instagram
      bool anyInstagramSuccess = false;
      if (mediaFiles != null &&
          mediaFiles.isNotEmpty &&
          selectedInstagramAccounts.isNotEmpty) {
        // تحديث حالة الرفع للواجهة
        _isUploading = true;
        _uploadStatus = 'جاري الاستعداد لنشر المحتوى على Instagram...';
        _uploadProgress = 5;
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
                  // تحديث حالة التقدم في واجهة المستخدم
                  _uploadStatus = status;
                  _uploadProgress = progressPercent;
                  notifyListeners();
                },
              );
            } else {
              // للصور - استخدام الطريقة العادية
              _uploadStatus = 'جاري نشر الصورة على Instagram...';
              _uploadProgress = 20;
              notifyListeners();

              igPostId = await _facebookService.publishToInstagram(
                instagramAccountId: igAccount.id,
                pageAccessToken: igAccount.pageAccessToken,
                imageFile: mediaFiles.first,
                caption: message,
              );

              _uploadStatus = 'تم نشر الصورة بنجاح!';
              _uploadProgress = 100;
              notifyListeners();
            }

            print('تم النشر على Instagram بنجاح! معرف المنشور: $igPostId');
            anyInstagramSuccess = true;
          } catch (e) {
            String errorMsg =
                'فشل في النشر على Instagram (${igAccount.username}): $e';
            print(errorMsg);
            _error = errorMsg;

            // تحديث الحالة في واجهة المستخدم
            _uploadStatus = 'حدث خطأ: $errorMsg';
            _uploadProgress = 0;

            notifyListeners();
            // نستمر مع الحسابات الأخرى
          }
        }
      }

      // إعادة تعيين حالة الرفع
      _isUploading = false;
      notifyListeners();

      // إذا كان هناك خطأ ولكن تم النشر على بعض الحسابات بنجاح، نعدل رسالة الخطأ
      if (_error != null && (selectedPages.isNotEmpty || anyInstagramSuccess)) {
        _error = 'تم النشر على بعض الحسابات، ولكن حدثت أخطاء أخرى: $_error';
      }

      return true;
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
