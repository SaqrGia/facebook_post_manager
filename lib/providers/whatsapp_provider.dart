import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/whatsapp_group.dart';
import '../models/whatsapp_channel.dart';
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

      print('التحقق من اتصال واتساب باستخدام معرف الهاتف: $targetPhoneId');

      _isConnected =
          await _service.checkConnectionStatus(phoneId: targetPhoneId);

      // تأكد من حفظ معرف الهاتف إذا كان الاتصال ناجحًا
      if (_isConnected) {
        _activePhoneId = targetPhoneId;
        await _savePhoneId(targetPhoneId);

        // طباعة قيمة معرف الهاتف للتحقق
        print('تم الاتصال بنجاح. معرف الهاتف النشط هو: $_activePhoneId');
      } else {
        print('فشل الاتصال بواتساب');
      }

      return _isConnected;
    } catch (e) {
      _error = e.toString();
      _isConnected = false;
      print('خطأ في التحقق من اتصال واتساب: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // طريقة لحفظ المجموعات في التخزين المحلي
  Future<void> _saveGroupsToStorage(List<WhatsAppGroup> groups) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final groupsJson =
          groups.map((group) => jsonEncode(group.toJson())).toList();
      await prefs.setStringList('whatsapp_groups', groupsJson);
      print('تم حفظ ${groups.length} مجموعة في التخزين المحلي');
    } catch (e) {
      print('خطأ في حفظ المجموعات: $e');
    }
  }

// طريقة لاسترجاع المجموعات من التخزين المحلي
  Future<List<WhatsAppGroup>> _loadGroupsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final groupsJson = prefs.getStringList('whatsapp_groups') ?? [];
      if (groupsJson.isEmpty) {
        print('لا توجد مجموعات مخزنة');
        return [];
      }

      print('تم العثور على ${groupsJson.length} مجموعة مخزنة');
      return groupsJson
          .map((json) {
            try {
              final Map<String, dynamic> data = jsonDecode(json);
              return WhatsAppGroup.fromJson(data);
            } catch (e) {
              print('خطأ في قراءة بيانات مجموعة: $e');
              return null;
            }
          })
          .whereType<WhatsAppGroup>()
          .toList();
    } catch (e) {
      print('خطأ في تحميل المجموعات: $e');
      return [];
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
    // إذا كانت قائمة المجموعات غير فارغة وليس مطلوباً تحديث إجباري، نستخدم القائمة الحالية
    if (!forceRefresh && _groups.isNotEmpty) {
      print('استخدام ${_groups.length} مجموعة محملة مسبقًا');
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // في حالة عدم وجود تحديث إجباري، نحاول تحميل المجموعات من التخزين المحلي أولاً
      if (!forceRefresh) {
        final savedGroups = await _loadGroupsFromStorage();
        if (savedGroups.isNotEmpty) {
          _groups = savedGroups;
          _isLoading = false;
          notifyListeners();
          print('تم تحميل ${savedGroups.length} مجموعة من التخزين المحلي');
          return;
        }
      }

      // إذا كان التحديث إجباري أو لم تكن هناك مجموعات مخزنة، نقوم بتحميلها من الخادم
      if (_activePhoneId == null) {
        print('لا يوجد معرف هاتف نشط. محاولة تحميل المعرف المحفوظ...');
        await _loadSavedPhoneId(); // محاولة تحميل المعرف المحفوظ
      }

      if (_activePhoneId == null) {
        _error = 'لا يوجد معرف هاتف نشط. يرجى إعداد واتساب أولاً.';
        print(_error);
        _groups = [];
        notifyListeners();
        return;
      }

      print(
          'جلب مجموعات واتساب من الخادم باستخدام معرف الهاتف: $_activePhoneId');
      _groups = await _service.getGroups(phoneId: _activePhoneId!);
      print('تم جلب ${_groups.length} مجموعة من الخادم');

      // حفظ المجموعات في التخزين المحلي للاستخدام في المستقبل
      await _saveGroupsToStorage(_groups);

      _lastGroupsUpdate = DateTime.now();
    } catch (e) {
      _error = e.toString();
      print('خطأ في جلب مجموعات واتساب: $e');

      // في حال الفشل، نحاول تحميل المجموعات من التخزين المحلي
      if (_groups.isEmpty) {
        try {
          final savedGroups = await _loadGroupsFromStorage();
          if (savedGroups.isNotEmpty) {
            _groups = savedGroups;
            print(
                'تم تحميل ${savedGroups.length} مجموعة من التخزين المحلي بعد فشل التحميل من الخادم');
          } else {
            _groups = [];
          }
        } catch (_) {
          _groups = [];
        }
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
    String message = '',
    File? mediaFile,
    List<File>? mediaFiles,
    int maxRetries = 2,
  }) async {
    try {
      if (_activePhoneId == null) {
        _error = 'لا يوجد معرف هاتف نشط. يرجى إعداد واتساب أولاً.';
        notifyListeners();
        return false;
      }

      // التحقق من وجود محتوى للإرسال
      bool hasMediaFile = mediaFile != null && await mediaFile.exists();
      bool hasMediaFiles = mediaFiles != null && mediaFiles.isNotEmpty;
      bool hasMedia = hasMediaFile || hasMediaFiles;
      bool hasText = message.trim().isNotEmpty;

      if (!hasMedia && !hasText) {
        _error = 'يجب توفير نص أو وسائط للإرسال.';
        notifyListeners();
        return false;
      }

      // طباعة المعلومات التشخيصية
      print(
          'sendPostToGroup - groupId: $groupId, hasMediaFile: $hasMediaFile, hasMediaFiles: $hasMediaFiles (${mediaFiles?.length ?? 0})');
      if (hasMediaFiles) {
        for (int i = 0; i < mediaFiles!.length; i++) {
          print(
              'mediaFiles[$i]: ${mediaFiles[i].path}, exists: ${await mediaFiles[i].exists()}');
        }
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

          // قم بإرسال الوسائط أو النص باستخدام sendPost
          if (hasMediaFiles) {
            // ملاحظة: نسمح للدالة sendPost بالتعامل مع ملف وحيد أو ملفات متعددة
            success = await _service.sendPost(
              phoneId: _activePhoneId!,
              groupId: groupId,
              message: message,
              mediaFiles: mediaFiles,
            );
          } else if (hasMediaFile) {
            success = await _service.sendPost(
              phoneId: _activePhoneId!,
              groupId: groupId,
              message: message,
              mediaFile: mediaFile,
            );
          } else {
            success = await _service.sendTextMessage(
              phoneId: _activePhoneId!,
              groupId: groupId,
              message: message,
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

          // محاولة أخيرة
          if (attempt == maxRetries &&
              hasMediaFiles &&
              mediaFiles!.length > 1) {
            try {
              print(
                  'فشل إرسال الصور المتعددة، محاولة إرسال الصورة الأولى فقط...');
              success = await _service.sendPost(
                phoneId: _activePhoneId!,
                groupId: groupId,
                message: message,
                mediaFile: mediaFiles.first,
              );

              if (success) {
                _lastMessageResults[groupId] = true;
                notifyListeners();
                return true;
              }
            } catch (e) {
              print('فشل أيضًا في إرسال الصورة الأولى فقط: $e');
            }
          }
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
    List<File>? mediaFiles,
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

      // طباعة معلومات تشخيصية عن الملفات
      if (mediaFiles != null) {
        print('إرسال ${mediaFiles.length} ملف إلى ${totalGroups} مجموعة');
        for (int i = 0; i < mediaFiles.length; i++) {
          File file = mediaFiles[i];
          bool exists = await file.exists();
          print('ملف[$i]: ${file.path}, موجود: $exists');
          if (exists) {
            print('حجم الملف: ${await file.length()} بايت');
          }
        }
      }

      // استخدام التأخير لتجنب القيود على معدل الاستخدام
      for (final groupId in _selectedGroupIds) {
        try {
          final success = await sendPostToGroup(
            groupId: groupId,
            message: message,
            mediaFile: mediaFile,
            mediaFiles: mediaFiles,
          );

          results[groupId] = success;

          if (success) {
            successCount++;
          }

          // تأخير بين الطلبات
          if (_selectedGroupIds.length > 1) {
            await Future.delayed(const Duration(seconds: 3));
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
        print('لا يوجد معرف هاتف نشط. محاولة تحميل المعرف المحفوظ...');
        await _loadSavedPhoneId(); // محاولة تحميل المعرف المحفوظ
      }

      if (_activePhoneId == null) {
        _error = 'لا يوجد معرف هاتف نشط. يرجى إعداد واتساب أولاً.';
        print(_error);
        return [];
      }

      // تحديث قائمة المجموعات
      print('مزامنة مجموعات واتساب باستخدام معرف الهاتف: $_activePhoneId');
      final oldGroupCount = _groups.length;
      _groups = await _service.getGroups(phoneId: _activePhoneId!);
      print('تم جلب ${_groups.length} مجموعة');

      // حفظ المجموعات المحدثة في التخزين المحلي
      await _saveGroupsToStorage(_groups);

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
      print('خطأ في مزامنة المجموعات: $e');
      return [];
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  // إضافة هذه المتغيرات والدوال إلى WhatsAppProvider في lib/providers/whatsapp_provider.dart

  // متغيرات القنوات
  List<WhatsAppChannel> _channels = [];
  Set<String> _selectedChannelIds = {};
  bool _isLoadingChannels = false;
  bool _isSyncingChannels = false;
  String? _channelError;
  String? _channelSyncMessage;

  // Getters للقنوات
  List<WhatsAppChannel> get channels => List.unmodifiable(_channels);
  Set<String> get selectedChannelIds => Set.unmodifiable(_selectedChannelIds);
  List<WhatsAppChannel> get selectedChannels => _channels
      .where((channel) => _selectedChannelIds.contains(channel.id))
      .toList();
  bool get isLoadingChannels => _isLoadingChannels;
  bool get isSyncingChannels => _isSyncingChannels;
  String? get channelError => _channelError;
  String? get channelSyncMessage => _channelSyncMessage;

  // دوال اختيار القنوات
  bool isChannelSelected(String channelId) =>
      _selectedChannelIds.contains(channelId);

  void toggleChannelSelection(String channelId) {
    if (_selectedChannelIds.contains(channelId)) {
      _selectedChannelIds.remove(channelId);
    } else {
      _selectedChannelIds.add(channelId);
    }
    notifyListeners();
  }

  // حفظ القنوات في التخزين المحلي
  Future<void> _saveChannelsToStorage(List<WhatsAppChannel> channels) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final channelsJson =
          channels.map((channel) => jsonEncode(channel.toJson())).toList();
      await prefs.setStringList('whatsapp_channels', channelsJson);
      print('تم حفظ ${channels.length} قناة في التخزين المحلي');
    } catch (e) {
      print('خطأ في حفظ القنوات: $e');
    }
  }

  // استرجاع القنوات من التخزين المحلي
  Future<List<WhatsAppChannel>> _loadChannelsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final channelsJson = prefs.getStringList('whatsapp_channels') ?? [];
      if (channelsJson.isEmpty) {
        print('لا توجد قنوات مخزنة');
        return [];
      }

      print('تم العثور على ${channelsJson.length} قناة مخزنة');
      return channelsJson
          .map((json) {
            try {
              final Map<String, dynamic> data = jsonDecode(json);
              return WhatsAppChannel.fromJson(data);
            } catch (e) {
              print('خطأ في قراءة بيانات قناة: $e');
              return null;
            }
          })
          .whereType<WhatsAppChannel>()
          .toList();
    } catch (e) {
      print('خطأ في تحميل القنوات: $e');
      return [];
    }
  }

  // تحميل قنوات واتساب
  Future<void> loadChannels({bool forceRefresh = false}) async {
    // إذا كانت قائمة القنوات غير فارغة وليس مطلوباً تحديث إجباري، نستخدم القائمة الحالية
    if (!forceRefresh && _channels.isNotEmpty) {
      print('استخدام ${_channels.length} قناة محملة مسبقًا');
      return;
    }

    _isLoadingChannels = true;
    _channelError = null;
    notifyListeners();

    try {
      // في حالة عدم وجود تحديث إجباري، نحاول تحميل القنوات من التخزين المحلي أولاً
      if (!forceRefresh) {
        final savedChannels = await _loadChannelsFromStorage();
        if (savedChannels.isNotEmpty) {
          _channels = savedChannels;
          _isLoadingChannels = false;
          notifyListeners();
          print('تم تحميل ${savedChannels.length} قناة من التخزين المحلي');
          return;
        }
      }

      // إذا كان التحديث إجباري أو لم تكن هناك قنوات مخزنة، نقوم بتحميلها من الخادم
      if (_activePhoneId == null) {
        print('لا يوجد معرف هاتف نشط. محاولة تحميل المعرف المحفوظ...');
        await _loadSavedPhoneId(); // محاولة تحميل المعرف المحفوظ
      }

      if (_activePhoneId == null) {
        _channelError = 'لا يوجد معرف هاتف نشط. يرجى إعداد واتساب أولاً.';
        print(_channelError);
        _channels = [];
        notifyListeners();
        return;
      }

      print('جلب قنوات واتساب من الخادم باستخدام معرف الهاتف: $_activePhoneId');
      _channels = await _service.getChannels(phoneId: _activePhoneId!);
      print('تم جلب ${_channels.length} قناة من الخادم');

      // حفظ القنوات في التخزين المحلي للاستخدام في المستقبل
      await _saveChannelsToStorage(_channels);
    } catch (e) {
      _channelError = e.toString();
      print('خطأ في جلب قنوات واتساب: $e');

      // في حال الفشل، نحاول تحميل القنوات من التخزين المحلي
      if (_channels.isEmpty) {
        try {
          final savedChannels = await _loadChannelsFromStorage();
          if (savedChannels.isNotEmpty) {
            _channels = savedChannels;
            print(
                'تم تحميل ${savedChannels.length} قناة من التخزين المحلي بعد فشل التحميل من الخادم');
          } else {
            _channels = [];
          }
        } catch (_) {
          _channels = [];
        }
      }
    } finally {
      _isLoadingChannels = false;
      notifyListeners();
    }
  }

  // مزامنة القنوات (نفس تحديث القنوات لكن بإعلام المستخدم)
  Future<List<WhatsAppChannel>> syncChannels() async {
    _isSyncingChannels = true;
    _channelSyncMessage = 'جاري مزامنة القنوات...';
    _channelError = null;
    notifyListeners();

    try {
      if (_activePhoneId == null) {
        print('لا يوجد معرف هاتف نشط. محاولة تحميل المعرف المحفوظ...');
        await _loadSavedPhoneId(); // محاولة تحميل المعرف المحفوظ
      }

      if (_activePhoneId == null) {
        _channelError = 'لا يوجد معرف هاتف نشط. يرجى إعداد واتساب أولاً.';
        print(_channelError);
        return [];
      }

      // تحديث قائمة القنوات
      print('مزامنة قنوات واتساب باستخدام معرف الهاتف: $_activePhoneId');
      final oldChannelCount = _channels.length;
      _channels = await _service.getChannels(phoneId: _activePhoneId!);
      print('تم جلب ${_channels.length} قناة');

      // حفظ القنوات المحدثة في التخزين المحلي
      await _saveChannelsToStorage(_channels);

      final newChannelCount = _channels.length;
      _channelSyncMessage = 'تم مزامنة ${_channels.length} قناة';

      if (newChannelCount > oldChannelCount) {
        _channelSyncMessage =
            'تم إضافة ${newChannelCount - oldChannelCount} قناة جديدة';
      }

      return _channels;
    } catch (e) {
      _channelError = e.toString();
      _channelSyncMessage = 'فشل في مزامنة القنوات';
      print('خطأ في مزامنة القنوات: $e');
      return [];
    } finally {
      _isSyncingChannels = false;
      notifyListeners();
    }
  }

  // إنشاء قناة جديدة
  Future<WhatsAppChannel?> createChannel({
    required String channelName,
    String? description,
  }) async {
    try {
      if (_activePhoneId == null) {
        throw WhatsAppApiException(
            'لا يوجد معرف هاتف نشط. يرجى إعداد واتساب أولاً.');
      }

      _isLoadingChannels = true;
      _channelError = null;
      notifyListeners();

      // إنشاء القناة
      final channel = await _service.createChannel(
        phoneId: _activePhoneId!,
        channelName: channelName,
        description: description,
      );

      if (channel != null) {
        // إضافة القناة الجديدة إلى القائمة
        _channels.add(channel);
        await _saveChannelsToStorage(_channels);
      }

      _isLoadingChannels = false;
      notifyListeners();
      return channel;
    } catch (e) {
      _channelError = e.toString();
      _isLoadingChannels = false;
      notifyListeners();
      return null;
    }
  }

  // الحصول على رابط دعوة للقناة
  Future<String?> getChannelInviteLink(String channelId) async {
    try {
      if (_activePhoneId == null) {
        throw WhatsAppApiException(
            'لا يوجد معرف هاتف نشط. يرجى إعداد واتساب أولاً.');
      }

      final inviteLink = await _service.getChannelInviteLink(
        phoneId: _activePhoneId!,
        channelId: channelId,
      );

      if (inviteLink != null) {
        // تحديث القناة في القائمة
        final index = _channels.indexWhere((c) => c.id == channelId);
        if (index >= 0) {
          _channels[index] = _channels[index].copyWith(inviteLink: inviteLink);
          await _saveChannelsToStorage(_channels);
          notifyListeners();
        }
      }

      return inviteLink;
    } catch (e) {
      _channelError = e.toString();
      notifyListeners();
      return null;
    }
  }

  // إرسال منشور إلى قناة واحدة
  Future<bool> sendPostToChannel({
    required String channelId,
    String message = '',
    File? mediaFile,
    List<File>? mediaFiles,
    int maxRetries = 2,
  }) async {
    try {
      if (_activePhoneId == null) {
        _error = 'لا يوجد معرف هاتف نشط. يرجى إعداد واتساب أولاً.';
        notifyListeners();
        return false;
      }

      // التحقق من وجود محتوى للإرسال
      bool hasMediaFile = mediaFile != null && await mediaFile.exists();
      bool hasMediaFiles = mediaFiles != null && mediaFiles.isNotEmpty;
      bool hasMedia = hasMediaFile || hasMediaFiles;
      bool hasText = message.trim().isNotEmpty;

      if (!hasMedia && !hasText) {
        _error = 'يجب توفير نص أو وسائط للإرسال.';
        notifyListeners();
        return false;
      }

      // طباعة المعلومات التشخيصية
      print(
          'sendPostToChannel - channelId: $channelId, hasMediaFile: $hasMediaFile, hasMediaFiles: $hasMediaFiles (${mediaFiles?.length ?? 0})');
      if (hasMediaFiles) {
        for (int i = 0; i < mediaFiles!.length; i++) {
          print(
              'mediaFiles[$i]: ${mediaFiles[i].path}, exists: ${await mediaFiles[i].exists()}');
        }
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
                'إعادة محاولة إرسال المنشور إلى القناة $channelId، المحاولة ${attempt}');
          }

          // قم بإرسال الوسائط أو النص
          if (hasMediaFiles) {
            success = await _service.sendPost(
              phoneId: _activePhoneId!,
              groupId: channelId,
              message: message,
              mediaFiles: mediaFiles,
              isChannel: true, // تعيين isChannel إلى true لقنوات واتساب
            );
          } else if (hasMediaFile) {
            success = await _service.sendPost(
              phoneId: _activePhoneId!,
              groupId: channelId,
              message: message,
              mediaFile: mediaFile,
              isChannel: true, // تعيين isChannel إلى true لقنوات واتساب
            );
          } else {
            success = await _service.sendTextMessage(
              phoneId: _activePhoneId!,
              groupId: channelId,
              message: message,
              isChannel: true, // تعيين isChannel إلى true لقنوات واتساب
            );
          }

          if (success) {
            _lastMessageResults[channelId] = true;
            notifyListeners();
            return true;
          }
        } catch (e) {
          lastException = e is WhatsAppApiException
              ? e
              : WhatsAppApiException('خطأ في إرسال المنشور: $e');
          print('فشل في المحاولة $attempt: ${lastException.message}');

          // محاولة أخيرة
          if (attempt == maxRetries &&
              hasMediaFiles &&
              mediaFiles!.length > 1) {
            try {
              print(
                  'فشل إرسال الصور المتعددة، محاولة إرسال الصورة الأولى فقط...');
              success = await _service.sendPost(
                phoneId: _activePhoneId!,
                groupId: channelId,
                message: message,
                mediaFile: mediaFiles.first,
                isChannel: true, // تعيين isChannel إلى true لقنوات واتساب
              );

              if (success) {
                _lastMessageResults[channelId] = true;
                notifyListeners();
                return true;
              }
            } catch (e) {
              print('فشل أيضًا في إرسال الصورة الأولى فقط: $e');
            }
          }
        }
      }

      // إذا وصلنا إلى هنا، فشلت جميع المحاولات
      _error = lastException?.message ?? 'فشل إرسال المنشور بعد عدة محاولات';
      _lastMessageResults[channelId] = false;
      notifyListeners();
      return false;
    } catch (e) {
      print('خطأ خارجي في إرسال المنشور إلى القناة $channelId: $e');
      _error = 'فشل إرسال المنشور: $e';
      _lastMessageResults[channelId] = false;
      notifyListeners();
      return false;
    }
  }

  // إرسال منشور إلى قنوات متعددة
  Future<Map<String, bool>> sendPostToChannels({
    required String message,
    File? mediaFile,
    List<File>? mediaFiles,
  }) async {
    _isLoading = true;
    _error = null;
    _lastMessageResults.clear();
    notifyListeners();

    final results = <String, bool>{};

    try {
      if (_activePhoneId == null) {
        _error = 'لا يوجد معرف هاتف نشط. يرجى إعداد واتساب أولاً.';
        return {for (var id in _selectedChannelIds) id: false};
      }

      int successCount = 0;
      int totalChannels = _selectedChannelIds.length;

      // طباعة معلومات تشخيصية عن الملفات
      if (mediaFiles != null) {
        print('إرسال ${mediaFiles.length} ملف إلى ${totalChannels} قناة');
        for (int i = 0; i < mediaFiles.length; i++) {
          File file = mediaFiles[i];
          bool exists = await file.exists();
          print('ملف[$i]: ${file.path}, موجود: $exists');
          if (exists) {
            print('حجم الملف: ${await file.length()} بايت');
          }
        }
      }

      // استخدام التأخير لتجنب القيود على معدل الاستخدام
      for (final channelId in _selectedChannelIds) {
        try {
          final success = await sendPostToChannel(
            channelId: channelId,
            message: message,
            mediaFile: mediaFile,
            mediaFiles: mediaFiles,
          );

          results[channelId] = success;

          if (success) {
            successCount++;
          }

          // تأخير بين الطلبات
          if (_selectedChannelIds.length > 1) {
            await Future.delayed(const Duration(seconds: 3));
          }

          // تحديث النتائج باستمرار
          _lastMessageResults = Map.from(results);
          notifyListeners();
        } catch (e) {
          print('فشل إرسال المنشور إلى القناة $channelId: $e');
          results[channelId] = false;
          _lastMessageResults[channelId] = false;
        }
      }

      // تحديث رسالة الخطأ بناءً على نتائج الإرسال
      if (successCount == 0) {
        _error = 'فشل إرسال المنشور إلى جميع القنوات (${totalChannels} قناة)';
      } else if (successCount < totalChannels) {
        _error =
            'تم إرسال المنشور بنجاح إلى $successCount من أصل $totalChannels قناة';
      } else {
        _error = null;
      }

      return results;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
