import 'dart:io';
import 'package:flutter/material.dart';
import 'media_picker.dart';

class PostForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController messageController;
  final TextEditingController linkController;
  final VoidCallback onSubmit;
  final bool isLoading;
  final Function(List<File>, bool)? onMediaSelected;
  final Function()? onMediaRemoved;
  final List<File>? selectedMedia;
  final bool isVideo;

  const PostForm({
    Key? key,
    required this.formKey,
    required this.messageController,
    required this.linkController,
    required this.onSubmit,
    required this.isLoading,
    this.onMediaSelected,
    this.onMediaRemoved,
    this.selectedMedia,
    this.isVideo = false,
  }) : super(key: key);

  @override
  State<PostForm> createState() => _PostFormState();
}

class _PostFormState extends State<PostForm> {
  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: widget.messageController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'نص المنشور (اختياري)',
              hintText: 'اكتب هنا محتوى المنشور...',
              border: OutlineInputBorder(),
            ),
            // تم إزالة validator لجعل الحقل اختيارياً
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: widget.linkController,
            decoration: const InputDecoration(
              labelText: 'رابط (اختياري)',
              hintText: 'أدخل الرابط إذا كنت تريد مشاركته',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          if (widget.onMediaSelected != null && widget.onMediaRemoved != null)
            MediaPickerWidget(
              onMediaSelected: widget.onMediaSelected!,
              onRemoveMedia: widget.onMediaRemoved!,
              selectedMedia: widget.selectedMedia,
              isVideo: widget.isVideo,
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: widget.isLoading ? null : widget.onSubmit,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.isLoading) ...[
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(widget.isLoading ? 'جاري النشر...' : 'نشر'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
