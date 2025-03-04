import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pages_provider.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/posts/post_form.dart';
import '../../widgets/pages/page_selection_list.dart';
import '../../widgets/instagram_selection_list.dart';

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
  bool _isSubmitting = false;
  List<File>? _selectedMedia;
  bool _isVideo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PagesProvider>().loadPages();
    });
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
    if (pagesProvider.selectedPages.isEmpty &&
        pagesProvider.selectedInstagramAccounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'الرجاء اختيار صفحة فيسبوك أو حساب انستقرام واحد على الأقل')),
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
      final success = await pagesProvider.createPostOnSelectedPages(
        message: _messageController.text,
        link: _linkController.text.isNotEmpty ? _linkController.text : null,
        mediaFiles: _selectedMedia,
        context: context, // تمرير السياق للسماح بعرض واجهات التقدم عند الحاجة
      );

      if (!mounted) return;

      if (success) {
        _messageController.clear();
        _linkController.clear();
        setState(() {
          _showPages = false;
          _showInstagramAccounts = false;
          _selectedMedia = null;
          _isVideo = false;
        });

        pagesProvider.clearSelection();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم نشر المنشور بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(pagesProvider.error ?? 'حدث خطأ أثناء النشر'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      body: Consumer<PagesProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: LoadingIndicator());
          }

          return Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
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

                    // إضافة مؤشر تقدم نشر الريلز هنا عندما يكون هناك عملية رفع جارية
                    if (provider.isUploading)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: provider.buildUploadProgressWidget(),
                      ),

                    const Divider(),

                    // Facebook Pages Selection
                    ListTile(
                      title: const Text(
                        'اختيار صفحات فيسبوك',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${provider.selectedPages.length} مختارة'),
                          const SizedBox(width: 8),
                          Icon(
                            _showPages ? Icons.expand_less : Icons.expand_more,
                          ),
                        ],
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
                      trailing: Row(
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
                      onTap: () {
                        setState(() =>
                            _showInstagramAccounts = !_showInstagramAccounts);
                      },
                      leading: const Icon(Icons.camera_alt,
                          color: Color(0xFFC13584)), // لون انستقرام
                    ),
                    if (_showInstagramAccounts) const InstagramSelectionList(),

                    if (provider.error != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          provider.error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // إضافة مساحة في أسفل الشاشة لتجنب تداخل زر العائم
                    const SizedBox(height: 80),
                  ],
                ),
              ),

              // بدلاً من الشاشة المؤقتة الكاملة، يمكننا عرض مؤشر تقدم محدد أثناء عملية النشر
              if (_isSubmitting && !provider.isUploading)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: LoadingIndicator(),
                  ),
                ),
            ],
          );
        },
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
