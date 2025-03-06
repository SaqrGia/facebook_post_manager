import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pages_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/pages/page_card.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/error_view.dart';

class PagesScreen extends StatefulWidget {
  const PagesScreen({Key? key}) : super(key: key);

  @override
  State<PagesScreen> createState() => _PagesScreenState();
}

class _PagesScreenState extends State<PagesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PagesProvider>().loadPages();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('صفحاتي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: Consumer<PagesProvider>(
        builder: (context, pagesProvider, _) {
          if (pagesProvider.isLoading) {
            return const Center(child: LoadingIndicator());
          }

          if (pagesProvider.error != null) {
            return ErrorView(
              message: pagesProvider.error!,
              onRetry: () => pagesProvider.loadPages(),
            );
          }

          if (pagesProvider.pages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.pages, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'لا توجد صفحات متاحة',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => pagesProvider.loadPages(),
                    child: const Text('تحديث'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => pagesProvider.loadPages(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pagesProvider.pages.length,
              itemBuilder: (context, index) {
                final page = pagesProvider.pages[index];
                return PageCard(
                  page: page,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/create_post',
                      arguments: page.id,
                    );
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/batch_posts');
        },
        child: const Icon(Icons.post_add),
      ),
    );
  }
}
