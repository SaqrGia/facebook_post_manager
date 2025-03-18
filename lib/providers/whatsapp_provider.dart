import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/whatsapp_group.dart';
import '../services/whatsapp_service.dart';
import '../config/app_config.dart';

class WhatsAppProvider with ChangeNotifier {
  final WhatsAppService _service;

  List<WhatsAppGroup> _groups = [];
  Set<String> _selectedGroupIds = {};
  bool _isConnected = false;
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _qrCode;
  String? _qrImage;
  String? _error;
  String? _syncMessage;

  // تخزين معرف الهاتف النشط
  String? _activePhoneId;

  // مؤقت تحديث المجموعات (لتقليل عدد الطلبات)
  DateTime? _lastGroupsUpdate;

  // متغير لتتبع نتيجة آخر رسالة
  Map<String, bool> _lastMessageResults = {};

  WhatsAppProvider({required WhatsAppService service}) : _service = service {
    _loadSavedPhoneId();
  }

  // تحميل معرف الهاتف المحفوظ
  Future<void> _loadSavedPhoneId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _activePhoneId = prefs.getString('whatsapp_phone_id');
      if (_activePhoneId != null) {
        _checkConnectionForSavedPhone();
      }
    } catch (e) {
      print('خطأ في تحميل معرف الهاتف المحفوظ: $e');
    }
  }

  // حفظ معرف الهاتف
  Future<void> _savePhoneId(String phoneId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('whatsapp_phone_id', phoneId);
      _activePhoneId = phoneId;
    } catch (e) {
      print('خطأ في حفظ معرف الهاتف: $e');
    }
  }

  // التحقق من اتصال الهاتف المحفوظ
  Future<void> _checkConnectionForSavedPhone() async {
    if (_activePhoneId != null) {
      await checkConnection(phoneId: _activePhoneId!);
    }
  }

  // Getters
  List<WhatsAppGroup> get groups => List.unmodifiable(_groups);
  Set<String> get selectedGroupIds => Set.unmodifiable(_selectedGroupIds);
  List<WhatsAppGroup> get selectedGroups =>
      _groups.where((group) => _selectedGroupIds.contains(group.id)).toList();
  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get qrCode => _qrCode;
  String? get qrImage => _qrImage;
  String? get error => _error;
  String? get syncMessage => _syncMessage;
  String? get activePhoneId => _activePhoneId;
  Map<String, bool> get lastMessageResults =>
      Map.unmodifiable(_lastMessageResults);

  // الحصول على URL مباشر لصورة QR
  String getQRImageUrl() {
    // تحديد رقم الهاتف المستخدم
    final phoneId = _activePhoneId ?? AppConfig.maytapiDefaultPhoneId;
    return _service.getQRImageUrl(phoneId: phoneId);
  }

  // التحقق من حالة الاتصال
  Future<bool> checkConnection({String? phoneId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // استخدام معرف الهاتف المقدم أو الافتراضي
      final targetPhoneId =
          phoneId ?? _activePhoneId ?? AppConfig.maytapiDefaultPhoneId;

      _isConnected =
          await _service.checkConnectionStatus(phoneId: targetPhoneId);

      // إذا تم الاتصال، احفظ معرف الهاتف
      if (_isConnected && (phoneId != null && phoneId != _activePhoneId)) {
        await _savePhoneId(phoneId);
      }

      return _isConnected;
    } catch (e) {
      _error = e.toString();
      _isConnected = false;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // الحصول على رمز QR للمصادقة
  Future<Map<String, String?>> getQRCode({String? phoneId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // استخدام معرف الهاتف المقدم أو الافتراضي
      final targetPhoneId =
          phoneId ?? _activePhoneId ?? AppConfig.maytapiDefaultPhoneId;

      final qrData = await _service.getQRCode(phoneId: targetPhoneId);
      _qrCode = qrData['qrCode'];
      _qrImage = qrData['qrImage'];

      // إذا كنا نحصل على رمز QR لهاتف جديد، احفظه كنشط
      if (phoneId != null && phoneId != _activePhoneId) {
        await _savePhoneId(phoneId);
      }

      return qrData;
    } catch (e) {
      _error = e.toString();
      return {'qrCode': null, 'qrImage': null};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // إعادة تشغيل العميل (تسجيل الخروج في Maytapi)
  Future<bool> restartClient() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_activePhoneId == null) {
        _error = 'لا يوجد هاتف نشط لإعادة تشغيله';
        return false;
      }

      final result = await _service.logout(phoneId: _activePhoneId!);
      if (result) {
        _qrCode = null;
        _qrImage = null;
        _isConnected = false;
        // لا تمسح معرف الهاتف لأننا يمكننا إعادة الاتصال بنفس الهاتف
      }
      return result;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // تحميل مجموعات واتساب مع كاش للتقليل من طلبات API
  Future<void> loadGroups({bool forceRefresh = false}) async {
    // تحقق مما إذا كان يجب تحديث المجموعات أم لا
    final now = DateTime.now();
    final shouldUpdate = forceRefresh ||
        _lastGroupsUpdate == null ||
        now.difference(_lastGroupsUpdate!).inMinutes > 15; // تحديث كل 15 دقيقة

    if (!shouldUpdate && _groups.isNotEmpty) {
      // استخدام البيانات المخزنة مؤقتًا إذا كانت حديثة
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_activePhoneId == null) {
        _error = 'لا يوجد معرف هاتف نشط. يرجى إعداد واتساب أولاً.';
        _groups = [];
        return;
      }

      _groups = await _service.getGroups(phoneId: _activePhoneId!);
      _lastGroupsUpdate = now;
    } catch (e) {
      _error = e.toString();
      // الاحتفاظ بالمجموعات القديمة في حالة فشل التحديث
      if (_groups.isEmpty) {
        _groups = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // دالة مساعدة لاختيار المجموعة
  bool isGroupSelected(String groupId) => _selectedGroupIds.contains(groupId);

  void toggleGroupSelection(String groupId) {
    if (_selectedGroupIds.contains(groupId)) {
      _selectedGroupIds.remove(groupId);
    } else {
      _selectedGroupIds.add(groupId);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedGroupIds.clear();
    notifyListeners();
  }

  // إرسال منشور إلى مجموعة واحدة مع آلية إعادة المحاولة
  Future<bool> sendPostToGroup({
    required String groupId,
    required String message,
    File? mediaFile,
    int maxRetries = 2,
  }) async {
    try {
      if (_activePhoneId == null) {
        _error = 'لا يوجد معرف هاتف نشط. يرجى إعداد واتساب أولاً.';
        notifyListeners();
        return false;
      }

      bool success = false;
      WhatsAppApiException? lastException;

      // آلية إعادة المحاولة
      for (int attempt = 0; attempt <= maxRetries; attempt++) {
        try {
          // إذا كانت هذه ليست المحاولة الأولى، أضف تأخيرًا قبل إعادة المحاولة
          if (attempt > 0) {
            await Future.delayed(Duration(seconds: 2 * attempt));
            print(
                'إعادة محاولة إرسال المنشور إلى المجموعة $groupId، المحاولة ${attempt}');
          }

          // إذا كانت هناك وسائط ولم ننجح في إرسالها في المحاولة الأولى، حاول إرسال النص فقط
          if (mediaFile != null && attempt > 0) {
            print('فشل إرسال الوسائط في المحاولة السابقة، إرسال النص فقط');
            success = await _service.sendTextMessage(
              phoneId: _activePhoneId!,
              groupId: groupId,
              message: message,
            );
          } else {
            success = await _service.sendPost(
              phoneId: _activePhoneId!,
              groupId: groupId,
              message: message,
              mediaFile: mediaFile,
            );
          }

          if (success) {
            _lastMessageResults[groupId] = true;
            notifyListeners();
            return true;
          }
        } catch (e) {
          lastException = e is WhatsAppApiException
              ? e
              : WhatsAppApiException('خطأ في إرسال المنشور: $e');
          print('فشل في المحاولة $attempt: ${lastException.message}');
        }
      }

      // إذا وصلنا إلى هنا، فشلت جميع المحاولات
      _error = lastException?.message ?? 'فشل إرسال المنشور بعد عدة محاولات';
      _lastMessageResults[groupId] = false;
      notifyListeners();
      return false;
    } catch (e) {
      print('خطأ خارجي في إرسال المنشور إلى المجموعة $groupId: $e');
      _error = 'فشل إرسال المنشور: $e';
      _lastMessageResults[groupId] = false;
      notifyListeners();
      return false;
    }
  }

  // إرسال منشور إلى مجموعات متعددة
  Future<Map<String, bool>> sendPostToGroups({
    required String message,
    File? mediaFile,
  }) async {
    _isLoading = true;
    _error = null;
    _lastMessageResults.clear();
    notifyListeners();

    final results = <String, bool>{};

    try {
      if (_activePhoneId == null) {
        _error = 'لا يوجد معرف هاتف نشط. يرجى إعداد واتساب أولاً.';
        return {for (var id in _selectedGroupIds) id: false};
      }

      int successCount = 0;
      int totalGroups = _selectedGroupIds.length;

      // استخدام التأخير لتجنب القيود على معدل الاستخدام
      for (final groupId in _selectedGroupIds) {
        try {
          final success = await sendPostToGroup(
            groupId: groupId,
            message: message,
            mediaFile: mediaFile,
          );

          results[groupId] = success;

          if (success) {
            successCount++;
          }

          // تأخير بين الطلبات
          if (_selectedGroupIds.length > 1) {
            await Future.delayed(const Duration(seconds: 2));
          }

          // تحديث النتائج باستمرار
          _lastMessageResults = Map.from(results);
          notifyListeners();
        } catch (e) {
          print('فشل إرسال المنشور إلى المجموعة $groupId: $e');
          results[groupId] = false;
          _lastMessageResults[groupId] = false;
        }
      }

      // تحديث رسالة الخطأ بناءً على نتائج الإرسال
      if (successCount == 0) {
        _error = 'فشل إرسال المنشور إلى جميع المجموعات (${totalGroups} مجموعة)';
      } else if (successCount < totalGroups) {
        _error =
            'تم إرسال المنشور بنجاح إلى $successCount من أصل $totalGroups مجموعة';
      } else {
        _error = null;
      }

      return results;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // مسح الخطأ
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // مزامنة المجموعات (نفس تحديث المجموعات لكن بإعلام المستخدم)
  Future<List<WhatsAppGroup>> syncGroups() async {
    _isSyncing = true;
    _syncMessage = 'جاري مزامنة المجموعات...';
    _error = null;
    notifyListeners();

    try {
      if (_activePhoneId == null) {
        _error = 'لا يوجد معرف هاتف نشط. يرجى إعداد واتساب أولاً.';
        return [];
      }

      // تحديث قائمة المجموعات
      final oldGroupCount = _groups.length;
      _groups = await _service.getGroups(phoneId: _activePhoneId!);
      _lastGroupsUpdate = DateTime.now();

      final newGroupCount = _groups.length;
      _syncMessage = 'تم مزامنة ${_groups.length} مجموعة';

      if (newGroupCount > oldGroupCount) {
        _syncMessage = 'تم إضافة ${newGroupCount - oldGroupCount} مجموعة جديدة';
      }

      return _groups;
    } catch (e) {
      _error = e.toString();
      _syncMessage = 'فشل في مزامنة المجموعات';
      return [];
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
