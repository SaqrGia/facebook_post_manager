import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pages_provider.dart';
import '../../providers/whatsapp_provider.dart'; // أضفنا هذا
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/posts/post_form.dart';
import '../../widgets/pages/page_selection_list.dart';
import '../../widgets/instagram_selection_list.dart';
import '../../widgets/whatsapp/whatsapp_group_selection_list.dart'; // أضفنا هذا

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
  bool _showWhatsAppGroups = false; // أضفنا هذا
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
    });
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

    // التحقق من اختيار منصة واحدة على الأقل
    bool hasSelectedPlatform = pagesProvider.selectedPages.isNotEmpty ||
        pagesProvider.selectedInstagramAccounts.isNotEmpty ||
        whatsappProvider.selectedGroupIds.isNotEmpty;

    if (!hasSelectedPlatform) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'الرجاء اختيار منصة واحدة على الأقل (فيسبوك، انستغرام، أو واتساب)')),
      );
      return;
    }

    // التحقق من وجود محتوى للنشر (نص أو وسائط)
    if (_messageController.text.isEmpty &&
        (_selectedMedia == null || _selectedMedia!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب إدخال نص أو اختيار وسائط على الأقل')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // النشر على Facebook و Instagram
      bool fbIgSuccess = true;
      if (pagesProvider.selectedPages.isNotEmpty ||
          pagesProvider.selectedInstagramAccounts.isNotEmpty) {
        fbIgSuccess = await pagesProvider.createPostOnSelectedPages(
          message: _messageController.text,
          link: _linkController.text.isNotEmpty ? _linkController.text : null,
          mediaFiles: _selectedMedia,
          context: context,
        );
      }

      // النشر على واتساب
      bool waSuccess = true;
      if (whatsappProvider.selectedGroupIds.isNotEmpty) {
        final results = await whatsappProvider.sendPostToGroups(
          message: _messageController.text,
          mediaFile:
              _selectedMedia?.isNotEmpty == true ? _selectedMedia!.first : null,
        );

        // إذا فشل النشر على جميع المجموعات
        waSuccess = results.values.any((success) => success);
      }

      if (!mounted) return;

      // تحديد رسالة النجاح بناءً على نتائج النشر
      String successMessage;
      if (fbIgSuccess && waSuccess) {
        successMessage = 'تم نشر المنشور بنجاح على جميع المنصات';
      } else if (fbIgSuccess) {
        successMessage = 'تم النشر بنجاح على فيسبوك/انستغرام فقط';
      } else if (waSuccess) {
        successMessage = 'تم النشر بنجاح على واتساب فقط';
      } else {
        throw Exception('فشل النشر على جميع المنصات');
      }

      // تنظيف بعد النجاح
      _messageController.clear();
      _linkController.clear();
      setState(() {
        _showPages = false;
        _showInstagramAccounts = false;
        _showWhatsAppGroups = false;
        _selectedMedia = null;
        _isVideo = false;
      });

      pagesProvider.clearSelection();
      whatsappProvider.clearSelection();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
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
            onPressed: _isSubmitting ? null : _createPost,
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
