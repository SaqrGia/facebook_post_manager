import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/tiktok_account.dart';
import '../services/tiktok_service.dart';
import '../services/storage_service.dart';
import '../config/app_config.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class TikTokProvider with ChangeNotifier {
  final TikTokService _tikTokService;
  final StorageService _storageService;

  List<TikTokAccount> _accounts = [];
  Set<String> _selectedAccountIds = {};
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isPollingQR = false;
  String? _error;
  String _uploadStatus = '';
  int _uploadProgress = 0;

  // بيانات QR Code
  String? _qrCodeUrl;
  String? _qrToken;
  String? _clientTicket;
  String _qrStatus = '';

  TikTokProvider({
    TikTokService? tikTokService,
    StorageService? storageService,
  })  : _tikTokService = tikTokService ?? TikTokService(),
        _storageService = storageService ?? StorageService() {
    loadAccounts();
  }

  // Getters
  List<TikTokAccount> get accounts => List.unmodifiable(_accounts);
  Set<String> get selectedAccountIds => Set.unmodifiable(_selectedAccountIds);
  List<TikTokAccount> get selectedAccounts => _accounts
      .where((account) => _selectedAccountIds.contains(account.id))
      .toList();
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  bool get isPollingQR => _isPollingQR;
  String? get error => _error;
  String get uploadStatus => _uploadStatus;
  int get uploadProgress => _uploadProgress;
  String? get qrCodeUrl => _qrCodeUrl;
  String get qrStatus => _qrStatus;

  // تحميل الحسابات المحفوظة
  Future<void> loadAccounts() async {
    try {
      final accountsData = await _storageService.getTikTokAccounts();
      if (accountsData.isNotEmpty) {
        _accounts = accountsData;
        notifyListeners();
      }
    } catch (e) {
      print('خطأ في تحميل حسابات تيك توك المحفوظة: $e');
      _error = e.toString();
    }
  }

  // حفظ الحسابات
  Future<void> _saveAccounts() async {
    try {
      await _storageService.saveTikTokAccounts(_accounts);
    } catch (e) {
      print('خطأ في حفظ حسابات تيك توك: $e');
      _error = e.toString();
    }
  }

  // بدء عملية المصادقة التقليدية (للتوافقية)
  Future<void> startAuth() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final authUrl = _tikTokService.getAuthorizationUrl();

      final canLaunch = await canLaunchUrl(authUrl);
      if (!canLaunch) {
        throw Exception('لا يمكن فتح عنوان URL للمصادقة');
      }

      await launchUrl(
        authUrl,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      _error = 'فشل في بدء المصادقة: $e';
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // طلب رمز QR للمصادقة
  Future<bool> requestQRCode() async {
    _isLoading = true;
    _error = null;
    _qrCodeUrl = null;
    _qrToken = null;
    _clientTicket = null;
    _qrStatus = 'جاري التحميل...';
    notifyListeners();

    try {
      final qrData = await _tikTokService.getQRCode();

      _qrCodeUrl = qrData['qr_url'];
      _qrToken = qrData['token'];
      _clientTicket = qrData['client_ticket'];
      _qrStatus = 'new';

      return true;
    } catch (e) {
      _error = 'فشل في طلب رمز QR: $e';
      print(_error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // بدء استطلاع حالة QR
  Future<void> startQRPolling() async {
    if (_qrToken == null || _clientTicket == null) {
      _error = 'لم يتم طلب رمز QR بعد';
      notifyListeners();
      return;
    }

    if (_isPollingQR) {
      return; // منع الاستطلاع المتكرر
    }

    _isPollingQR = true;
    _error = null;
    notifyListeners();

    try {
      // استطلاع كل 2 ثانية
      const pollInterval = Duration(seconds: 2);
      bool shouldContinue = true;
      String? authCode;
      int attempts = 0;
      const maxAttempts = 30; // الحد الأقصى للمحاولات (60 ثانية)

      while (shouldContinue && _isPollingQR && attempts < maxAttempts) {
        attempts++;

        try {
          final statusData = await _tikTokService.checkQRCodeStatus(
            _qrToken!,
            _clientTicket!,
          );

          // تحديث الحالة
          _qrStatus = statusData['status'] ?? 'unknown';
          notifyListeners();

          print('حالة QR: $_qrStatus');

          // التحقق من حالة QR
          if (_qrStatus == 'confirmed') {
            // استخراج رمز التفويض من استجابة مختلفة
            if (statusData.containsKey('code')) {
              authCode = statusData['code'];
              shouldContinue = false;
            } else if (statusData.containsKey('redirect_uri')) {
              authCode =
                  _tikTokService.extractAuthCode(statusData['redirect_uri']);
              shouldContinue = false;
            }
          } else if (_qrStatus == 'expired') {
            shouldContinue = false;
            _error = 'انتهت صلاحية رمز QR، يرجى طلب رمز جديد';
          } else if (_qrStatus == 'utilised') {
            shouldContinue = false;
            _error = 'تم استخدام رمز QR بالفعل، يرجى طلب رمز جديد';
          }

          // إذا وصلنا إلى حالة نهائية، نتوقف عن الاستطلاع
          if (!shouldContinue) {
            break;
          }

          // انتظار قبل الاستطلاع التالي
          await Future.delayed(pollInterval);
        } catch (e) {
          print('خطأ في استطلاع حالة QR: $e');

          // تقليل عدد محاولات التكرار للخطأ نفسه
          if (attempts % 3 == 0) {
            _error =
                'حدث خطأ في استطلاع حالة QR، سيتم إعادة المحاولة... ($attempts/$maxAttempts)';
            notifyListeners();
          }

          // الاستمرار في الاستطلاع حتى في حالة الخطأ
          await Future.delayed(pollInterval);
        }
      }

      // إذا تجاوزنا الحد الأقصى للمحاولات
      if (attempts >= maxAttempts && shouldContinue) {
        _error = 'استغرق تأكيد QR وقتًا طويلاً جدًا. يرجى المحاولة مرة أخرى.';
        _qrStatus = 'expired';
        notifyListeners();
        return;
      }

      // إذا حصلنا على رمز تفويض، نستبدله برمز وصول
      if (authCode != null) {
        print('تم الحصول على رمز تفويض، جاري استبداله برمز وصول...');

        try {
          await _processAuthCode(authCode);
        } catch (e) {
          print('خطأ في معالجة رمز التفويض: $e');
          _error = 'فشل في معالجة رمز التفويض: $e';
          notifyListeners();
        }
      }
    } finally {
      _isPollingQR = false;
      notifyListeners();
    }
  }

  // إيقاف استطلاع حالة QR
  void stopQRPolling() {
    _isPollingQR = false;
    notifyListeners();
  }

  // معالجة رمز المصادقة
  Future<bool> processAuthCode(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      return await _processAuthCode(code);
    } catch (e) {
      _error = 'فشل المصادقة: $e';
      print(_error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// إعادة تحميل معلومات الحساب المرتبط
  Future<bool> refreshAccountInfo(String accountId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // البحث عن الحساب المرتبط
      final accountIndex =
          _accounts.indexWhere((account) => account.id == accountId);
      if (accountIndex < 0) {
        _error = 'الحساب غير موجود';
        notifyListeners();
        return false;
      }

      final account = _accounts[accountIndex];

      // الحصول على معلومات المستخدم
      try {
        final userInfo = await _tikTokService.getUserInfo(account.accessToken);

        // تحديث بيانات الحساب
        String username = 'مستخدم تيك توك';
        String? avatarUrl;

        if (userInfo.containsKey('data')) {
          username = userInfo['data']['creator_nickname'] ??
              userInfo['data']['creator_username'] ??
              userInfo['data']['display_name'] ??
              userInfo['data']['nickname'] ??
              'مستخدم تيك توك';

          avatarUrl = userInfo['data']['creator_avatar_url'] ??
              userInfo['data']['avatar_url'] ??
              userInfo['data']['avatar'];
        }

        // تحديث الحساب بالبيانات الجديدة
        final updatedAccount = account.copyWith(
          username: username,
          avatarUrl: avatarUrl,
        );

        _accounts[accountIndex] = updatedAccount;
        await _saveAccounts();

        return true;
      } catch (e) {
        print('فشل في تحديث معلومات الحساب: $e');
        return false;
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // المنطق الداخلي لمعالجة رمز المصادقة
  Future<bool> _processAuthCode(String code) async {
    try {
      print('معالجة رمز التفويض: $code');

      // تنظيف رمز التفويض - إذا كان يحتوي على أحرف خاصة
      final cleanedCode = code.contains('*') ? code.split('*')[0] : code;
      print('رمز التفويض بعد التنظيف: $cleanedCode');

      // استبدال الرمز برمز الوصول
      Map<String, dynamic> tokenData;
      try {
        tokenData = await _tikTokService.exchangeCodeForToken(code);
        print('تم الحصول على بيانات الرمز: $tokenData');
      } catch (e) {
        print('فشل في استبدال الرمز، محاولة التنظيف وإعادة المحاولة: $e');
        // محاولة ثانية بعد تنظيف الرمز
        tokenData = await _tikTokService.exchangeCodeForToken(cleanedCode);
      }

      // استخراج معلومات الرمز - معالجة هياكل الاستجابة المختلفة
      String? accessToken = tokenData['access_token'];
      String? refreshToken = tokenData['refresh_token'];
      int expiresIn = 0;

      if (accessToken == null && tokenData.containsKey('data')) {
        final data = tokenData['data'];
        accessToken = data['access_token'];
        refreshToken = data['refresh_token'];
        expiresIn = data['expires_in'] ?? 86400;
      } else {
        expiresIn = tokenData['expires_in'] ?? 86400;
      }

      if (accessToken == null) {
        throw Exception(
            'لم يتم العثور على رمز الوصول في الاستجابة بعد المعالجة: $tokenData');
      }

      // تعيين قيمة افتراضية لـ refreshToken إذا كان null
      refreshToken ??= '';

      // حساب تاريخ انتهاء الصلاحية
      final tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

      try {
        // الحصول على معلومات المستخدم
        final userData = await _tikTokService.getUserInfo(accessToken);
        print('تم الحصول على بيانات المستخدم: $userData');

        // معالجة هياكل بيانات API المختلفة
        Map<String, dynamic> userInfo;
        if (userData.containsKey('data')) {
          userInfo = userData['data'];
        } else {
          userInfo = userData;
        }

        // إنشاء حساب تيك توك
        final account = TikTokAccount(
          id: userInfo['open_id'] ??
              userInfo['user_id'] ??
              userInfo['union_id'] ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          username: userInfo['display_name'] ??
              userInfo['nickname'] ??
              'مستخدم تيك توك',
          avatarUrl: userInfo['avatar_url'] ?? userInfo['avatar'],
          accessToken: accessToken,
          tokenExpiry: tokenExpiry,
          refreshToken: refreshToken,
        );

        // التحقق مما إذا كان الحساب موجودًا بالفعل
        final existingIndex = _accounts.indexWhere((a) => a.id == account.id);
        if (existingIndex >= 0) {
          // تحديث الحساب الموجود
          _accounts[existingIndex] = account;
        } else {
          // إضافة حساب جديد
          _accounts.add(account);
        }

        // حفظ الحسابات
        await _saveAccounts();

        // إعادة تعيين حالة الواجهة
        _qrStatus = 'success';
        _error = null;
        notifyListeners();

        return true;
      } catch (e) {
        print('خطأ في الحصول على بيانات المستخدم: $e');

        // محاولة إنشاء حساب بدون بيانات المستخدم (الحد الأدنى)
        final account = TikTokAccount(
          id: 'tiktok_${DateTime.now().millisecondsSinceEpoch}',
          username: 'مستخدم تيك توك جديد',
          avatarUrl: null,
          accessToken: accessToken,
          tokenExpiry: tokenExpiry,
          refreshToken: refreshToken ?? '',
        );

        _accounts.add(account);
        await _saveAccounts();

        // نجحنا في إضافة الحساب رغم عدم الحصول على بياناته
        _qrStatus = 'success_partial';
        _error = 'تم الربط بنجاح ولكن لم نتمكن من جلب كامل معلومات الحساب';
        notifyListeners();

        return true;
      }
    } catch (e) {
      print('خطأ في معالجة رمز التفويض: $e');
      _error = 'فشل في ربط الحساب: $e';
      notifyListeners();
      throw e;
    }
  }

  // تبديل اختيار الحساب
  void toggleAccountSelection(String accountId) {
    if (_selectedAccountIds.contains(accountId)) {
      _selectedAccountIds.remove(accountId);
    } else {
      _selectedAccountIds.add(accountId);
    }
    notifyListeners();
  }

  // التحقق مما إذا كان الحساب مختارًا
  bool isAccountSelected(String accountId) =>
      _selectedAccountIds.contains(accountId);

  // مسح الاختيار
  void clearSelection() {
    _selectedAccountIds.clear();
    notifyListeners();
  }

  // تجديد الرمز إذا لزم الأمر
  Future<String> _getValidAccessToken(TikTokAccount account) async {
    // إذا لم تنتهي صلاحية الرمز، أرجعه
    if (!account.isTokenExpired) {
      return account.accessToken;
    }

    // وإلا، قم بتجديد الرمز
    try {
      final tokenData =
          await _tikTokService.refreshAccessToken(account.refreshToken);

      // استخراج معلومات الرمز
      final accessToken = tokenData['access_token'];
      final refreshToken = tokenData['refresh_token'] ?? account.refreshToken;
      final expiresIn = tokenData['expires_in'] as int;

      // حساب تاريخ انتهاء الصلاحية
      final tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

      // تحديث الحساب
      final updatedAccount = account.copyWith(
        accessToken: accessToken,
        refreshToken: refreshToken,
        tokenExpiry: tokenExpiry,
      );

      // تحديث الحساب في القائمة
      final index = _accounts.indexWhere((a) => a.id == account.id);
      if (index >= 0) {
        _accounts[index] = updatedAccount;
        // حفظ الحسابات
        await _saveAccounts();
      }

      return accessToken;
    } catch (e) {
      print('خطأ في تجديد الرمز: $e');
      throw Exception('فشل في تجديد الرمز: $e');
    }
  }

  // تحميل فيديو إلى تيك توك
  Future<bool> uploadVideoToTikTok({
    required File videoFile,
    required String caption,
  }) async {
    if (selectedAccounts.isEmpty) {
      _error = 'الرجاء اختيار حساب تيك توك واحد على الأقل';
      notifyListeners();
      return false;
    }

    _isUploading = true;
    _uploadProgress = 0;
    _uploadStatus = 'جاري التحضير للتحميل...';
    _error = null;
    notifyListeners();

    try {
      // التحقق من وجود ملف فيديو
      if (!await videoFile.exists()) {
        throw Exception('ملف الفيديو غير موجود');
      }

      // التحقق من حجم الملف
      final fileSize = await videoFile.length();
      if (fileSize > 4 * 1024 * 1024 * 1024) {
        // 4 جيجابايت كحد أقصى
        throw Exception('حجم الفيديو يتجاوز الحد الأقصى (4 جيجابايت)');
      }

      bool anySuccess = false;

      for (final account in selectedAccounts) {
        try {
          // 1. تحديث معلومات الحساب أولاً
          _uploadStatus = 'جاري تحديث معلومات الحساب...';
          _uploadProgress = 5;
          notifyListeners();

          await refreshAccountInfo(account.id);

          // 2. استخدام طريقة بديلة لتحميل الفيديو
          // بدلاً من استخدام الطريقة التي تفشل، سنستخدم PULL_FROM_URL

          _uploadStatus = 'جاري تحميل الفيديو إلى ${account.username}...';
          _uploadProgress = 20;
          notifyListeners();

          // إنشاء موقع مؤقت للملف
          final tempDir = await getTemporaryDirectory();
          final targetPath = path.join(tempDir.path,
              'video_${DateTime.now().millisecondsSinceEpoch}.mp4');

          // نسخ الفيديو إلى موقع مؤقت (في حال كان الملف الأصلي في مكان غير قابل للوصول)
          await videoFile.copy(targetPath);

          // تحميل الفيديو باستخدام الملف المؤقت
          final uploadResult = await _tikTokService.simpleVideoUpload(
            accessToken: account.accessToken,
            videoFile: File(targetPath),
            caption: caption,
            onProgress: (status, progress) {
              _uploadStatus = status;
              _uploadProgress = progress;
              notifyListeners();
            },
          );

          print('نتيجة تحميل الفيديو: $uploadResult');
          anySuccess = true;

          _uploadStatus = 'تم تحميل الفيديو بنجاح!';
          _uploadProgress = 100;
          notifyListeners();
        } catch (e) {
          print('فشل في التحميل إلى الحساب ${account.username}: $e');
          // نستمر بالمحاولة مع الحسابات الأخرى
        }
      }

      if (!anySuccess) {
        throw Exception('فشل في تحميل الفيديو إلى أي حساب مختار');
      }

      return anySuccess;
    } catch (e) {
      _error = e.toString();
      print('خطأ في uploadVideoToTikTok: $e');
      return false;
    } finally {
      // تأخير إخفاء مؤشر التحميل لمدة 3 ثوانٍ إذا كان ناجحاً (لإظهار رسالة النجاح)
      if (_uploadProgress == 100) {
        await Future.delayed(Duration(seconds: 3));
      }
      _isUploading = false;
      notifyListeners();
    }
  }

  // إزالة حساب
  Future<void> removeAccount(String accountId) async {
    _accounts.removeWhere((account) => account.id == accountId);
    _selectedAccountIds.remove(accountId);
    await _saveAccounts();
    notifyListeners();
  }

  // مسح الخطأ
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
