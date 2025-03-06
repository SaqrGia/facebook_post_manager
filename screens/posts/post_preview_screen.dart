import 'package:flutter/material.dart';
import '../../models/post.dart';

class PostPreviewScreen extends StatelessWidget {
  final Post post;
  final VoidCallback? onEdit;
  final VoidCallback? onPublish;

  const PostPreviewScreen({
    Key? key,
    required this.post,
    this.onEdit,
    this.onPublish,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('معاينة المنشور'),
        actions: [
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: onEdit,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'محتوى المنشور',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(post.message),
                    if (post.link != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'الرابط:',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        post.link!,
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ],
                    if (post.scheduledTime != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'موعد النشر:',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(post.scheduledTime.toString()),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: onPublish != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: onPublish,
                  child: const Text('نشر الآن'),
                ),
              ),
            )
          : null,
    );
  }
}
