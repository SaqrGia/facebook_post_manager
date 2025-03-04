import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/page.dart';
import '../../providers/pages_provider.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_indicator.dart';

class PageDetailsScreen extends StatefulWidget {
  final String pageId;

  const PageDetailsScreen({Key? key, required this.pageId}) : super(key: key);

  @override
  State<PageDetailsScreen> createState() => _PageDetailsScreenState();
}

class _PageDetailsScreenState extends State<PageDetailsScreen> {
  Map<String, dynamic>? _insights;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    final pagesProvider = context.read<PagesProvider>();
    final insights = await pagesProvider.getPageInsights(
      pageId: widget.pageId,
      metric: 'page_impressions,page_engaged_users',
      period: 'day',
    );
    if (mounted) {
      setState(() => _insights = insights);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الصفحة')),
      body: Consumer<PagesProvider>(
        builder: (context, provider, _) {
          final page = provider.getPageById(widget.pageId);

          if (page == null) {
            return const ErrorView(message: 'لم يتم العثور على الصفحة');
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPageHeader(page),
                const SizedBox(height: 24),
                _buildInsightsSection(),
                const SizedBox(height: 24),
                _buildActionButtons(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPageHeader(FacebookPage page) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              page.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (page.category != null) ...[
              const SizedBox(height: 8),
              Text(page.category!),
            ],
            if (page.fanCount != null) ...[
              const SizedBox(height: 8),
              Text('${page.fanCount} معجب'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsSection() {
    if (_insights == null) {
      return const LoadingIndicator();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'إحصائيات الصفحة',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            // عرض الإحصائيات هنا
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pushNamed(
              context,
              '/create_post',
              arguments: widget.pageId,
            );
          },
          icon: const Icon(Icons.post_add),
          label: const Text('منشور جديد'),
        ),
        ElevatedButton.icon(
          onPressed: _loadInsights,
          icon: const Icon(Icons.refresh),
          label: const Text('تحديث الإحصائيات'),
        ),
      ],
    );
  }
}
