import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/tiktok_account.dart';
import '../services/tiktok_service.dart';
import '../services/storage_service.dart';
import '../config/app_config.dart';

/// مزود حالة TikTok
///
/// يدير هذا المزود حالة المصادقة وحسابات TikTok في التطبيق
/// يوفر واجهة سهلة للتفاعل مع TikTok API
class TikTokProvider with ChangeNotifier {
  final TikTokService _tikTokService;
  final StorageService _storageService;

  // حالة الحسابات
  List<TikTokAccount> _accounts = [];
  Set<String> _selectedAccountIds = {};

  // حالة المصادقة
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isPollingQR = false;
  String? _error;
  String _uploadStatus = '';
  int _uploadProgress = 0;

  // بيانات QR Code
  String? _qrCodeUrl;
  String? _qrToken;
  String _qrStatus = '';

  // مؤقت استطلاع QR
  Timer? _qrPollingTimer;

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

  @override
  void dispose() {
    _stopQRPolling();
    super.dispose();
  }

  /// تحميل الحسابات المحفوظة
  Future<void> loadAccounts() async {
    try {
      final accountsData = await _storageService.getTikTokAccounts();
      if (accountsData.isNotEmpty) {
        _accounts = accountsData;
        notifyListeners();
      }
    } catch (e) {
      print('خطأ في تحميل حسابات تيك توك المحفوظة: $e');
      _error = 'فشل في تحميل الحسابات: $e';
      notifyListeners();
    }
  }

  /// حفظ الحسابات في التخزين المحلي
  Future<void> _saveAccounts() async {
    try {
      await _storageService.saveTikTokAccounts(_accounts);
    } catch (e) {
      print('خطأ في حفظ حسابات تيك توك: $e');
      _error = 'فشل في حفظ الحسابات: $e';
      notifyListeners();
    }
  }

  /// طلب رمز QR للمصادقة
  Future<bool> requestQRCode() async {
    _isLoading = true;
    _error = null;
    _qrCodeUrl = null;
    _qrToken = null;
    _qrStatus = 'جاري التحميل...';
    notifyListeners();

    try {
      final qrData = await _tikTokService.getQRCode();

      _qrCodeUrl = qrData['qr_url'];
      _qrToken = qrData['token'];
      _qrStatus = 'new';

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'فشل في طلب رمز QR: $e';
      print(_error);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// بدء استطلاع حالة QR
  void startQRPolling() {
    if (_qrToken == null) {
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

    // استطلاع كل 2 ثانية
    const pollInterval = Duration(seconds: 2);
    int attempts = 0;
    const maxAttempts = 30; // الحد الأقصى للمحاولات (60 ثانية)

    _qrPollingTimer = Timer.periodic(pollInterval, (timer) async {
      attempts++;

      if (attempts >= maxAttempts || !_isPollingQR) {
        _stopQRPolling();

        if (attempts >= maxAttempts) {
          _error = 'انتهت مهلة انتظار مسح رمز QR';
          _qrStatus = 'expired';
          notifyListeners();
        }
        return;
      }

      try {
        final statusData = await _tikTokService.checkQRCodeStatus(_qrToken!);

        // تحديث الحالة
        _qrStatus = statusData['status'] ?? 'unknown';
        notifyListeners();

        print('حالة QR: $_qrStatus (المحاولة ${attempts})');

        // التحقق من حالة QR
        if (_qrStatus == 'confirmed') {
          _stopQRPolling();

          // استخراج رمز التفويض - مع التحقق من وجوده
          final authCode = statusData['code'];
          if (authCode != null) {
            print('تم الحصول على رمز تفويض من QR، جاري معالجته...');
            await _processAuthCode(authCode);
          } else {
            _error =
                'تم تأكيد المسح ولكن لم يتم تلقي رمز التفويض، يرجى المحاولة مرة أخرى';
            notifyListeners();
          }
        } else if (_qrStatus == 'expired') {
          _stopQRPolling();
          _error = 'انتهت صلاحية رمز QR، يرجى طلب رمز جديد';
          notifyListeners();
        } else if (_qrStatus == 'used') {
          _stopQRPolling();
          _error = 'تم استخدام رمز QR بالفعل، يرجى طلب رمز جديد';
          notifyListeners();
        }
      } catch (e) {
        print('خطأ في استطلاع حالة QR: $e');

        // لا نوقف الاستطلاع للخطأ المؤقت
        if (attempts % 3 == 0) {
          // نعرض الخطأ كل 3 محاولات فقط
          _error = 'خطأ في استطلاع حالة QR: $e';
          notifyListeners();
        }
      }
    });
  }

  /// إيقاف استطلاع حالة QR
  void _stopQRPolling() {
    _qrPollingTimer?.cancel();
    _qrPollingTimer = null;
    _isPollingQR = false;
    notifyListeners();
  }

  Future<bool> authenticateWithManualToken({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
    String? openId,
    List<String>? scopes,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // تحقق من النطاقات المطلوبة أولاً (إضافة جديدة)
      final requiredScopes = ['user.info.basic'];

      // إذا كانت النطاقات محددة، تحقق منها
      if (scopes != null && scopes.isNotEmpty) {
        final hasRequiredScopes =
            requiredScopes.every((scope) => scopes.contains(scope));
        if (!hasRequiredScopes) {
          _error =
              'رمز الوصول لا يحتوي على النطاقات المطلوبة: ${requiredScopes.join(", ")}';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // إذا لم يتم توفير معرف المستخدم، نحاول الحصول عليه من API
      String userId = openId ?? '';
      if (openId == null) {
        try {
          // محاولة الحصول على معلومات المستخدم باستخدام الرمز المقدم
          final userInfo = await _tikTokService.getUserInfo(accessToken);
          userId = userInfo['open_id'] ?? '';

          if (userId.isEmpty) {
            throw TikTokApiException(
                'لم نتمكن من الحصول على معرف المستخدم من واجهة برمجة التطبيقات');
          }
        } catch (e) {
          // إضافة رسالة خطأ أكثر وضوحاً
          if (e
              .toString()
              .contains('user did not authorize the scope required')) {
            _error =
                'خطأ في النطاقات: يرجى التأكد من منح الصلاحيات التالية عند إنشاء رمز الوصول: ${requiredScopes.join(", ")}';
          } else {
            _error = 'خطأ في التحقق من الرمز: $e';
          }
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // حساب تاريخ انتهاء الصلاحية
      final tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

      // إنشاء حساب بالبيانات المقدمة
      final account = TikTokAccount(
        id: userId,
        username: 'مستخدم TikTok', // سيتم تحديثه لاحقًا إذا أمكن
        accessToken: accessToken,
        tokenExpiry: tokenExpiry,
        refreshToken: refreshToken,
      );

      // محاولة الحصول على مزيد من معلومات المستخدم
      try {
        final userInfo = await _tikTokService.getUserInfo(accessToken);

        // تحديث الحساب بمعلومات حقيقية
        final updatedAccount = account.copyWith(
          username: userInfo['display_name'] ?? 'مستخدم TikTok',
          avatarUrl: userInfo['avatar_url'],
        );

        // التحقق مما إذا كان هناك حساب موجود بالفعل بهذا المعرف
        final existingIndex = _accounts.indexWhere((a) => a.id == userId);
        if (existingIndex >= 0) {
          _accounts[existingIndex] = updatedAccount;
        } else {
          _accounts.add(updatedAccount);
        }

        // حفظ الحساب في التخزين
        await _saveAccounts();

        _isLoading = false;
        notifyListeners();
        return true;
      } catch (e) {
        // إذا فشل الحصول على تفاصيل إضافية، لا يزال بإمكاننا حفظ الحساب الأساسي
        final existingIndex = _accounts.indexWhere((a) => a.id == userId);
        if (existingIndex >= 0) {
          _accounts[existingIndex] = account;
        } else {
          _accounts.add(account);
        }

        await _saveAccounts();

        _error = 'تم حفظ الحساب ولكن بمعلومات محدودة: $e';
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = 'خطأ في تسجيل الرمز: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// معالجة رمز المصادقة الذي تم الحصول عليه من المصادقة
  Future<bool> processAuthCode(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      return await _processAuthCode(code);
    } catch (e) {
      _error = 'فشل المصادقة: $e';
      print(_error);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// المنطق الداخلي لمعالجة رمز المصادقة
  Future<bool> _processAuthCode(String code) async {
    try {
      print('معالجة رمز التفويض: $code');

      // استبدال الرمز برمز الوصول
      final tokenData = await _tikTokService.exchangeCodeForToken(code);

      // استخراج معلومات الرمز
      final accessToken = tokenData['access_token'];
      final refreshToken = tokenData['refresh_token'] ?? '';
      final openId = tokenData['open_id'];
      final expiresIn = tokenData['expires_in'] as int;

      if (accessToken == null || openId == null) {
        throw Exception('بيانات الرمز غير مكتملة');
      }

      // حساب تاريخ انتهاء الصلاحية
      final tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

      // الحصول على معلومات المستخدم
      final userInfo = await _tikTokService.getUserInfo(accessToken);

      // إنشاء حساب تيك توك
      final account = TikTokAccount(
        id: openId,
        username: userInfo['display_name'] ?? 'مستخدم تيك توك',
        avatarUrl: userInfo['avatar_url'],
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

      _isLoading = false;
      _qrStatus = 'success';
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = 'فشل في معالجة رمز التفويض: $e';
      notifyListeners();
      throw e;
    }
  }

  /// تحديث معلومات الحساب المرتبط
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
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final account = _accounts[accountIndex];

      // تجديد الرمز إذا لزم الأمر
      String accessToken = account.accessToken;
      if (account.isTokenExpired) {
        try {
          final tokenData =
              await _tikTokService.refreshAccessToken(account.refreshToken);
          accessToken = tokenData['access_token'];

          // تحديث الحساب بالرمز الجديد
          final updatedAccount = account.copyWith(
            accessToken: accessToken,
            refreshToken: tokenData['refresh_token'] ?? account.refreshToken,
            tokenExpiry: DateTime.now().add(
              Duration(seconds: tokenData['expires_in'] as int),
            ),
          );

          _accounts[accountIndex] = updatedAccount;
          await _saveAccounts();
        } catch (e) {
          print('فشل في تجديد الرمز: $e');
          _error = 'فشل في تجديد الرمز: $e';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // الحصول على معلومات المستخدم
      try {
        final userInfo = await _tikTokService.getUserInfo(accessToken);

        // تحديث الحساب بالمعلومات الجديدة
        final updatedAccount = _accounts[accountIndex].copyWith(
          username:
              userInfo['display_name'] ?? _accounts[accountIndex].username,
          avatarUrl:
              userInfo['avatar_url'] ?? _accounts[accountIndex].avatarUrl,
        );

        _accounts[accountIndex] = updatedAccount;
        await _saveAccounts();

        _isLoading = false;
        notifyListeners();
        return true;
      } catch (e) {
        _error = 'فشل في تحديث معلومات الحساب: $e';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'حدث خطأ: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// تبديل اختيار الحساب
  void toggleAccountSelection(String accountId) {
    if (_selectedAccountIds.contains(accountId)) {
      _selectedAccountIds.remove(accountId);
    } else {
      _selectedAccountIds.add(accountId);
    }
    notifyListeners();
  }

  /// التحقق مما إذا كان الحساب مختارًا
  bool isAccountSelected(String accountId) =>
      _selectedAccountIds.contains(accountId);

  /// مسح الاختيار
  void clearSelection() {
    _selectedAccountIds.clear();
    notifyListeners();
  }

  /// تحميل فيديو إلى تيك توك
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
          // استخدام طريقة تحميل الفيديو المبسطة
          _uploadStatus = 'جاري تحميل الفيديو إلى ${account.username}...';
          _uploadProgress = 10;
          notifyListeners();

          // تجديد الرمز إذا لزم الأمر
          String accessToken = account.accessToken;
          if (account.isTokenExpired) {
            try {
              final tokenData =
                  await _tikTokService.refreshAccessToken(account.refreshToken);
              accessToken = tokenData['access_token'];

              // تحديث الحساب بالرمز الجديد
              final updatedAccount = account.copyWith(
                accessToken: accessToken,
                refreshToken:
                    tokenData['refresh_token'] ?? account.refreshToken,
                tokenExpiry: DateTime.now().add(
                  Duration(seconds: tokenData['expires_in'] as int),
                ),
              );

              // تحديث الحساب في القائمة
              final index = _accounts.indexWhere((a) => a.id == account.id);
              if (index >= 0) {
                _accounts[index] = updatedAccount;
                await _saveAccounts();
              }
            } catch (e) {
              print('فشل في تجديد الرمز: $e');
              continue; // تخطي هذا الحساب والانتقال إلى الحساب التالي
            }
          }

          // تحميل الفيديو
          final videoId = await _tikTokService.uploadVideo(
            accessToken: accessToken,
            videoFile: videoFile,
            caption: caption,
            onProgress: (status, progress) {
              _uploadStatus = status;
              _uploadProgress = progress;
              notifyListeners();
            },
          );

          print(
              'تم تحميل الفيديو بنجاح إلى حساب ${account.username}، معرف الفيديو: $videoId');
          anySuccess = true;
        } catch (e) {
          print('فشل في التحميل إلى الحساب ${account.username}: $e');
          // نستمر بالمحاولة مع الحسابات الأخرى
        }
      }

      if (!anySuccess) {
        throw Exception('فشل في تحميل الفيديو إلى أي حساب مختار');
      }

      _uploadStatus = 'تم تحميل الفيديو بنجاح!';
      _uploadProgress = 100;
      notifyListeners();

      // تأخير إخفاء مؤشر التحميل
      await Future.delayed(Duration(seconds: 3));
      _isUploading = false;
      notifyListeners();

      return true;
    } catch (e) {
      _error = e.toString();
      _isUploading = false;
      notifyListeners();
      return false;
    }
  }

  /// إزالة حساب
  Future<void> removeAccount(String accountId) async {
    _accounts.removeWhere((account) => account.id == accountId);
    _selectedAccountIds.remove(accountId);
    await _saveAccounts();
    notifyListeners();
  }

  /// مسح الخطأ
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
