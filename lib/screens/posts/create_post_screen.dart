import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../../providers/pages_provider.dart';
import '../../providers/whatsapp_provider.dart';
import '../../providers/tiktok_provider.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/posts/post_form.dart';
import '../../widgets/pages/page_selection_list.dart';
import '../../widgets/instagram_selection_list.dart';
import '../../widgets/whatsapp/whatsapp_group_selection_list.dart';
import '../../widgets/tiktok/tiktok_account_selection_list.dart';
import 'package:mime/mime.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({Key? key}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _linkController = TextEditingController();
  bool _showPages = false;
  bool _showInstagramAccounts = false;
  bool _showWhatsAppGroups = false;
  bool _showTikTokAccounts = false; // إضافة جديدة
  bool _isSubmitting = false;
  List<File>? _selectedMedia;
  bool _isVideo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PagesProvider>().loadPages();

      // التحقق من اتصال واتساب وتحميل المجموعات إذا كان متصلاً
      _checkWhatsAppConnection();
      context.read<TikTokProvider>().loadAccounts();
    });
  }

  void _showMessage(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 5 : 3),
        action: isError
            ? SnackBarAction(
                label: 'حسناً',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              )
            : null,
      ),
    );
  }

  // دالة التحقق من اتصال واتساب
  Future<void> _checkWhatsAppConnection() async {
    final whatsappProvider = context.read<WhatsAppProvider>();
    final isConnected = await whatsappProvider.checkConnection();

    if (isConnected && mounted) {
      whatsappProvider.loadGroups();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  void _handleMediaSelected(List<File> files, bool isVideo) {
    setState(() {
      _selectedMedia = files;
      _isVideo = isVideo;
    });
  }

  void _handleMediaRemoved() {
    setState(() {
      _selectedMedia = null;
      _isVideo = false;
    });
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) return;

    final pagesProvider = context.read<PagesProvider>();
    final whatsappProvider = context.read<WhatsAppProvider>();
    final tiktokProvider = context.read<TikTokProvider>(); // إضافة جديدة

    // التحقق من اختيار منصة واحدة على الأقل
    bool hasSelectedPlatform = pagesProvider.selectedPages.isNotEmpty ||
        pagesProvider.selectedInstagramAccounts.isNotEmpty ||
        whatsappProvider.selectedGroupIds.isNotEmpty ||
        tiktokProvider.selectedAccountIds.isNotEmpty; // إضافة جديدة

    if (!hasSelectedPlatform) {
      _showMessage(
        context,
        'الرجاء اختيار منصة واحدة على الأقل (فيسبوك، انستغرام، واتساب، أو تيك توك)',
        isError: true,
      );
      return;
    }

    // التحقق من وجود محتوى للنشر (نص أو وسائط)
    bool hasMedia = _selectedMedia != null && _selectedMedia!.isNotEmpty;
    bool hasText = _messageController.text.isNotEmpty;

    if (!hasMedia && !hasText) {
      _showMessage(
        context,
        'يجب إدخال نص أو اختيار وسائط على الأقل',
        isError: true,
      );
      return;
    }

    // التحقق من وجود فيديو للنشر على تيك توك
    bool hasTikTokSelected = tiktokProvider.selectedAccountIds.isNotEmpty;
    bool hasVideo = hasMedia && _isVideo;

    if (hasTikTokSelected && !hasVideo) {
      _showMessage(
        context,
        'يجب اختيار فيديو للنشر على تيك توك',
        isError: true,
      );
      return;
    }

    // تحقق من نسب أبعاد الصور للنشر على Instagram
    if (hasMedia && pagesProvider.selectedInstagramAccounts.isNotEmpty) {
      // إضافة تحذير هنا إذا كان أي من الصور له أبعاد غير متوافقة مع Instagram
      bool hasLandscapeImages = false;
      bool hasPortraitImages = false;

      for (var media in _selectedMedia!) {
        try {
          final tempFile = media;
          final mimeType = lookupMimeType(tempFile.path) ?? '';

          // تحقق فقط إذا كان ملف صورة
          if (mimeType.startsWith('image/')) {
            // هنا يمكننا إضافة منطق لفحص أبعاد الصورة
            // كإجراء مؤقت، نضيف تنبيهًا عامًا
            hasLandscapeImages = true; // تفترض وجود صور أفقية
          }
        } catch (e) {
          print('خطأ في تحليل الصورة: $e');
        }
      }

      if (hasLandscapeImages) {
        _showMessage(
          context,
          'تنبيه: قد يتم تعديل أبعاد بعض الصور لتناسب متطلبات Instagram',
          isError: false,
        );
      }
    }

    setState(() => _isSubmitting = true);

    try {
      // معالجة منفصلة للفيسبوك/انستغرام وواتساب وتيك توك
      bool fbIgSuccess = true;
      bool waSuccess = true;
      bool ttSuccess = true; // إضافة جديدة
      String errorMessage = '';

      // النشر على فيسبوك وانستغرام
      if (pagesProvider.selectedPages.isNotEmpty ||
          pagesProvider.selectedInstagramAccounts.isNotEmpty) {
        try {
          fbIgSuccess = await pagesProvider.createPostOnSelectedPages(
            message: _messageController.text,
            link: _linkController.text.isNotEmpty ? _linkController.text : null,
            mediaFiles: _selectedMedia,
            context: context,
          );

          if (!fbIgSuccess && pagesProvider.error != null) {
            errorMessage += 'فيسبوك/انستغرام: ${pagesProvider.error}\n';
          }
        } catch (e) {
          fbIgSuccess = false;
          errorMessage += 'فيسبوك/انستغرام: $e\n';
        }
      }

      // النشر على واتساب
      if (whatsappProvider.selectedGroupIds.isNotEmpty) {
        try {
          // إرسال للمجموعات المحددة
          final results = await _sendToWhatsApp(
            whatsappProvider: whatsappProvider,
            message: _messageController.text,
            mediaFiles: _selectedMedia,
          );

          // التحقق من نجاح النشر على الأقل لمجموعة واحدة
          waSuccess = results.values.any((success) => success);

          if (!waSuccess && whatsappProvider.error != null) {
            errorMessage += 'واتساب: ${whatsappProvider.error}\n';
          }
        } catch (e) {
          waSuccess = false;
          errorMessage += 'واتساب: $e\n';
        }
      }

      // النشر على تيك توك (إضافة جديدة)
      if (hasTikTokSelected && hasVideo) {
        try {
          ttSuccess = await tiktokProvider.uploadVideoToTikTok(
            videoFile: _selectedMedia!.first,
            caption: _messageController.text,
          );

          if (!ttSuccess && tiktokProvider.error != null) {
            errorMessage += 'تيك توك: ${tiktokProvider.error}\n';
          }
        } catch (e) {
          ttSuccess = false;
          errorMessage += 'تيك توك: $e\n';
        }
      }

      if (!mounted) return;

      // تحديد رسالة النجاح بناءً على نتائج النشر
      String successMessage = '';
      if (fbIgSuccess && waSuccess && ttSuccess) {
        successMessage = 'تم نشر المنشور بنجاح على جميع المنصات';
      } else {
        List<String> successPlatforms = [];
        if (fbIgSuccess) successPlatforms.add('فيسبوك/انستغرام');
        if (waSuccess) successPlatforms.add('واتساب');
        if (ttSuccess) successPlatforms.add('تيك توك');

        if (successPlatforms.isNotEmpty) {
          successMessage = 'تم النشر بنجاح على: ${successPlatforms.join(', ')}';
        } else if (errorMessage.isNotEmpty) {
          throw Exception(errorMessage);
        } else {
          throw Exception('فشل النشر على جميع المنصات');
        }
      }

      _showMessage(context, successMessage);

      // تنظيف بعد النجاح
      _messageController.clear();
      _linkController.clear();
      setState(() {
        _showPages = false;
        _showInstagramAccounts = false;
        _showWhatsAppGroups = false;
        _showTikTokAccounts = false; // إضافة جديدة
        _selectedMedia = null;
        _isVideo = false;
      });

      pagesProvider.clearSelection();
      whatsappProvider.clearSelection();
      tiktokProvider.clearSelection(); // إضافة جديدة
    } catch (e) {
      if (!mounted) return;
      _showMessage(context, 'حدث خطأ: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

// إضافة دالة مساعدة خاصة لإرسال المحتوى إلى واتساب
  Future<Map<String, bool>> _sendToWhatsApp({
    required WhatsAppProvider whatsappProvider,
    String message = '',
    List<File>? mediaFiles,
  }) async {
    Map<String, bool> results = {};

    try {
      // التحقق من وجود وسائط
      bool hasMediaFiles = mediaFiles != null && mediaFiles.isNotEmpty;

      // التحقق من وجود محتوى للإرسال (إما وسائط أو نص)
      if (!hasMediaFiles && message.trim().isEmpty) {
        _showMessage(
          context,
          'يجب توفير نص أو وسائط للإرسال لمجموعات واتساب',
          isError: true,
        );
        return {};
      }

      // التحقق من وجود فيديو
      bool containsVideo = false;
      if (hasMediaFiles) {
        for (var file in mediaFiles!) {
          final mimeType = lookupMimeType(file.path) ?? '';
          if (mimeType.startsWith('video/')) {
            containsVideo = true;
            break;
          }
        }

        // إذا كان المحتوى يحتوي على فيديو، نعرض إشعاراً
        if (containsVideo && mediaFiles.length > 1) {
          _showMessage(
            context,
            'لا يمكن إرسال الفيديو مع صور أخرى، سيتم إرسال الفيديو فقط',
            isError: false,
          );

          // تصفية الفيديو فقط
          List<File> videoFiles = [];
          for (var file in mediaFiles) {
            final mimeType = lookupMimeType(file.path) ?? '';
            if (mimeType.startsWith('video/')) {
              videoFiles.add(file);
              break; // نأخذ أول فيديو فقط
            }
          }

          if (videoFiles.isNotEmpty) {
            mediaFiles = videoFiles;
          }
        } else if (containsVideo) {
          _showMessage(
            context,
            'جاري إرسال الفيديو إلى مجموعات واتساب، قد يستغرق الأمر وقتاً طويلاً...',
            isError: false,
          );
        }
      }

      int totalGroups = whatsappProvider.selectedGroupIds.length;
      int currentGroup = 0;

      // إرسال لكل مجموعة على حدة
      for (final groupId in whatsappProvider.selectedGroupIds) {
        currentGroup++;
        try {
          // أضف تحديثًا للمستخدم في المجموعات المتعددة
          if (totalGroups > 1) {
            _showMessage(
              context,
              'جاري الإرسال إلى المجموعة $currentGroup من $totalGroups...',
              isError: false,
            );
          }

          // استخدام الدالة المحدثة لإرسال الرسالة/الملفات
          bool success = await whatsappProvider.sendPostToGroup(
            groupId: groupId,
            message: message,
            mediaFiles: hasMediaFiles ? mediaFiles : null,
          );

          results[groupId] = success;

          // انتظار قصير بين الإرسالات
          await Future.delayed(const Duration(seconds: 2));
        } catch (e) {
          print('خطأ في إرسال المحتوى إلى المجموعة $groupId: $e');
          results[groupId] = false;
        }
      }

      return results;
    } catch (e) {
      print('خطأ عام في إرسال المحتوى إلى واتساب: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('منشور جديد'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isSubmitting ? () {} : _createPost,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // نموذج المنشور
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: PostForm(
                    formKey: _formKey,
                    messageController: _messageController,
                    linkController: _linkController,
                    isLoading: _isSubmitting,
                    onSubmit: _createPost,
                    onMediaSelected: _handleMediaSelected,
                    onMediaRemoved: _handleMediaRemoved,
                    selectedMedia: _selectedMedia,
                    isVideo: _isVideo,
                  ),
                ),

                // إضافة مؤشر تقدم نشر الريلز لانستغرام إذا كان متاحاً
                Consumer<PagesProvider>(
                  builder: (context, provider, _) {
                    if (provider.isUploading) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: provider.buildUploadProgressWidget(),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // إضافة مؤشر تقدم تيك توك
                Consumer<TikTokProvider>(
                  builder: (context, provider, _) {
                    if (provider.isUploading) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Container(
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
                                'نشر على تيك توك',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                value: provider.uploadProgress / 100,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  provider.uploadProgress == 100
                                      ? Colors.green
                                      : Colors.black,
                                ),
                                minHeight: 10,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${provider.uploadProgress}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: provider.uploadProgress == 100
                                      ? Colors.green
                                      : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    provider.uploadProgress == 100
                                        ? Icons.check_circle
                                        : Icons.upload_file,
                                    color: provider.uploadProgress == 100
                                        ? Colors.green
                                        : Colors.black,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(provider.uploadStatus),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                const Divider(),

                // Facebook Pages Selection
                ListTile(
                  title: const Text(
                    'اختيار صفحات فيسبوك',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Consumer<PagesProvider>(
                    builder: (context, provider, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${provider.selectedPages.length} مختارة'),
                        const SizedBox(width: 8),
                        Icon(
                          _showPages ? Icons.expand_less : Icons.expand_more,
                        ),
                      ],
                    ),
                  ),
                  onTap: () {
                    setState(() => _showPages = !_showPages);
                  },
                  leading: const Icon(Icons.facebook, color: Colors.blue),
                ),
                if (_showPages) const PageSelectionList(),

                const Divider(),

                // Instagram Accounts Selection
                ListTile(
                  title: const Text(
                    'اختيار حسابات انستقرام',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Consumer<PagesProvider>(
                    builder: (context, provider, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            '${provider.selectedInstagramAccounts.length} مختارة'),
                        const SizedBox(width: 8),
                        Icon(
                          _showInstagramAccounts
                              ? Icons.expand_less
                              : Icons.expand_more,
                        ),
                      ],
                    ),
                  ),
                  onTap: () {
                    setState(
                        () => _showInstagramAccounts = !_showInstagramAccounts);
                  },
                  leading: const Icon(Icons.camera_alt,
                      color: Color(0xFFC13584)), // لون انستقرام
                ),
                if (_showInstagramAccounts) const InstagramSelectionList(),

                const Divider(),

                // TikTok Accounts Selection (إضافة جديدة)
                ListTile(
                  title: const Text(
                    'اختيار حسابات تيك توك',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Consumer<TikTokProvider>(
                    builder: (context, provider, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${provider.selectedAccounts.length} مختارة'),
                        const SizedBox(width: 8),
                        Icon(
                          _showTikTokAccounts
                              ? Icons.expand_less
                              : Icons.expand_more,
                        ),
                      ],
                    ),
                  ),
                  onTap: () {
                    setState(() => _showTikTokAccounts = !_showTikTokAccounts);
                  },
                  leading: const Icon(Icons.music_note, color: Colors.black),
                ),
                if (_showTikTokAccounts)
                  Consumer<TikTokProvider>(
                    builder: (context, provider, _) {
                      if (provider.accounts.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  const Text(
                                    'لا توجد حسابات تيك توك مرتبطة',
                                    style: TextStyle(fontSize: 16),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                          context, '/tiktok_setup');
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text('ربط حساب تيك توك'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      return const TikTokAccountSelectionList();
                    },
                  ),

                const Divider(),

                // WhatsApp Groups Selection
                Consumer<WhatsAppProvider>(
                  builder: (context, whatsappProvider, _) {
                    // إذا لم يكن متصلاً بواتساب، اعرض زر الإعداد
                    if (!whatsappProvider.isConnected) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.message,
                                          color: Colors.green),
                                    ),
                                    const SizedBox(width: 16),
                                    const Expanded(
                                      child: Text(
                                        'واتساب',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'للنشر على مجموعات واتساب، يجب إعداد الاتصال أولاً',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                        context, '/whatsapp_setup');
                                  },
                                  icon: const Icon(Icons.qr_code),
                                  label: const Text('إعداد واتساب'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    // إذا كان متصلاً، اعرض قائمة المجموعات
                    return Column(
                      children: [
                        ListTile(
                          title: const Text(
                            'اختيار مجموعات واتساب',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                  '${whatsappProvider.selectedGroupIds.length} مختارة'),
                              const SizedBox(width: 8),
                              Icon(
                                _showWhatsAppGroups
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                            ],
                          ),
                          onTap: () {
                            setState(() =>
                                _showWhatsAppGroups = !_showWhatsAppGroups);
                          },
                          leading:
                              const Icon(Icons.message, color: Colors.green),
                        ),
                        if (_showWhatsAppGroups)
                          const WhatsAppGroupSelectionList(),
                      ],
                    );
                  },
                ),

                // عرض الأخطاء إذا وجدت
                Consumer<PagesProvider>(
                  builder: (context, provider, _) {
                    if (provider.error != null) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          provider.error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                Consumer<WhatsAppProvider>(
                  builder: (context, provider, _) {
                    if (provider.error != null) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          provider.error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                Consumer<TikTokProvider>(
                  builder: (context, provider, _) {
                    if (provider.error != null) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          provider.error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // إضافة مساحة في أسفل الشاشة لتجنب تداخل زر العائم
                const SizedBox(height: 80),
              ],
            ),
          ),

          // عرض مؤشر تقدم أثناء عملية النشر
          if (_isSubmitting)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: LoadingIndicator(message: 'جاري نشر المنشور...'),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/pages');
        },
        child: const Icon(Icons.pages),
        tooltip: 'عرض الصفحات',
      ),
    );
  }
}
