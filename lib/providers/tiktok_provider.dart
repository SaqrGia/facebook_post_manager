import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/tiktok_account.dart';
import '../services/tiktok_service.dart';
import '../services/storage_service.dart';
import '../config/app_config.dart';

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

      while (shouldContinue && _isPollingQR) {
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
            if (statusData.containsKey('redirect_uri')) {
              authCode =
                  _tikTokService.extractAuthCode(statusData['redirect_uri']);
              shouldContinue = false;
            }
            // أضف هذا الجزء للتعامل مع التنسيق المختلف للاستجابة
            else if (statusData.containsKey('code')) {
              authCode = statusData['code'];
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
          // يمكن استمرار الاستطلاع رغم الخطأ
          await Future.delayed(pollInterval);
        }
      }

      // إذا حصلنا على رمز تفويض، نستبدله برمز وصول
      if (authCode != null) {
        print('تم الحصول على رمز تفويض، جاري استبداله برمز وصول...');
        await _processAuthCode(authCode);
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

  // المنطق الداخلي لمعالجة رمز المصادقة
  Future<bool> _processAuthCode(String code) async {
    try {
      print('معالجة رمز التفويض: $code');

      // استبدال الرمز برمز الوصول
      final tokenData = await _tikTokService.exchangeCodeForToken(code);
      print('تم الحصول على بيانات الرمز: $tokenData');

      // استخراج معلومات الرمز
      final accessToken = tokenData['access_token'];
      final refreshToken = tokenData['refresh_token'];
      final expiresIn = tokenData['expires_in'] as int;

      // حساب تاريخ انتهاء الصلاحية
      final tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

      // الحصول على معلومات المستخدم
      final userData = await _tikTokService.getUserInfo(accessToken);
      print('تم الحصول على بيانات المستخدم: $userData');

      // إنشاء حساب تيك توك
      final account = TikTokAccount(
        id: userData['open_id'] ??
            userData['user_id'] ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        username: userData['display_name'] ?? 'مستخدم تيك توك',
        avatarUrl: userData['avatar_url'],
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

      return true;
    } catch (e) {
      print('خطأ في معالجة رمز التفويض: $e');
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
      bool anySuccess = false;

      for (final account in selectedAccounts) {
        try {
          // الحصول على رمز وصول صالح
          final accessToken = await _getValidAccessToken(account);

          // تحميل الفيديو
          final videoId = await _tikTokService.uploadVideo(
            accessToken: accessToken,
            videoFile: videoFile,
            caption: caption,
            onProgress: (status, progress) {
              _uploadStatus = 'حساب ${account.username}: $status';
              _uploadProgress = progress;
              notifyListeners();
            },
          );

          print('تم تحميل الفيديو بنجاح إلى تيك توك: $videoId');
          anySuccess = true;
        } catch (e) {
          print('خطأ في التحميل إلى الحساب ${account.username}: $e');
          // متابعة مع الحسابات الأخرى
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
