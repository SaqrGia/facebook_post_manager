import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/whatsapp_group.dart';
import '../services/whatsapp_service.dart';

class WhatsAppProvider with ChangeNotifier {
  final WhatsAppService _service;

  List<WhatsAppGroup> _groups = [];
  Set<String> _selectedGroupIds = {};
  bool _isConnected = false;
  bool _isLoading = false;
  bool _isSyncing = false; // حالة مزامنة المجموعات
  String? _qrCode;
  String? _qrImage;
  String? _error;
  String? _syncMessage; // رسالة مزامنة المجموعات

  WhatsAppProvider({required WhatsAppService service}) : _service = service;

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

  // دالة للحصول على URL صورة QR
  String getQRImageUrl() {
    return _service.getQRImageUrl();
  }

  // التحقق من حالة الاتصال
  Future<bool> checkConnection() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _isConnected = await _service.checkConnectionStatus();
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

  // جلب رمز QR
  Future<Map<String, String?>> getQRCode() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final qrData = await _service.getQRCodeWithImage();
      _qrCode = qrData['qrCode'];
      _qrImage = qrData['qrImage'];
      return qrData;
    } catch (e) {
      _error = e.toString();
      return {'qrCode': null, 'qrImage': null};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // إعادة تشغيل العميل
  Future<bool> restartClient() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.restartClient();
      if (result) {
        _qrCode = null;
        _qrImage = null;
        _isConnected = false;
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

  // مزامنة المجموعات
  Future<List<WhatsAppGroup>> syncGroups() async {
    _isSyncing = true;
    _syncMessage = 'جاري مزامنة المجموعات...';
    _error = null;
    notifyListeners();

    try {
      final syncedGroups = await _service.syncGroups();
      _syncMessage = 'تم مزامنة ${syncedGroups.length} مجموعة';

      // تحديث قائمة المجموعات إذا تم مزامنة مجموعات جديدة
      if (syncedGroups.isNotEmpty) {
        _groups = syncedGroups;
      }

      return syncedGroups;
    } catch (e) {
      _error = e.toString();
      _syncMessage = 'فشل في مزامنة المجموعات';
      return [];
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // جلب قائمة المجموعات مع إعادة المحاولة
  Future<void> loadGroups() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // محاولة أولى
      _groups = await _service.getGroups();

      // إذا كانت المجموعات فارغة، حاول تشغيل المزامنة
      if (_groups.isEmpty) {
        print('لم يتم العثور على مجموعات، جاري تشغيل المزامنة...');
        final syncedGroups = await syncGroups();

        // إذا لم تنجح المزامنة، حاول مرة أخرى جلب المجموعات بعد تأخير
        if (syncedGroups.isEmpty) {
          await Future.delayed(const Duration(seconds: 3));
          _groups = await _service.getGroups();
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // اختيار المجموعات
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

  // إرسال منشور إلى مجموعة
  Future<bool> sendPostToGroup({
    required String groupId,
    required String message,
    File? mediaFile,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.sendPost(
        groupId: groupId,
        message: message,
        mediaFile: mediaFile,
      );

      return result;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // إرسال منشور إلى مجموعات متعددة
  Future<Map<String, bool>> sendPostToGroups({
    required String message,
    File? mediaFile,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final results = <String, bool>{};

    try {
      for (final groupId in _selectedGroupIds) {
        try {
          final success = await _service.sendPost(
            groupId: groupId,
            message: message,
            mediaFile: mediaFile,
          );
          results[groupId] = success;
        } catch (e) {
          print('فشل إرسال المنشور إلى المجموعة $groupId: $e');
          results[groupId] = false;
        }
      }

      // إذا فشلت جميع الإرسالات
      if (results.values.every((success) => !success)) {
        _error = 'فشل إرسال المنشور إلى جميع المجموعات';
      }
      // إذا فشلت بعض الإرسالات
      else if (results.values.any((success) => !success)) {
        _error = 'فشل إرسال المنشور إلى بعض المجموعات';
      }

      return results;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // تنظيف الخطأ
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
