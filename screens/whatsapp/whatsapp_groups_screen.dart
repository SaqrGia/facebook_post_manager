import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/whatsapp_provider.dart';
import '../../models/whatsapp_group.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/error_view.dart';

class WhatsAppGroupsScreen extends StatefulWidget {
  const WhatsAppGroupsScreen({Key? key}) : super(key: key);

  @override
  State<WhatsAppGroupsScreen> createState() => _WhatsAppGroupsScreenState();
}

class _WhatsAppGroupsScreenState extends State<WhatsAppGroupsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGroups();
    });
  }

  Future<void> _loadGroups() async {
    final provider = context.read<WhatsAppProvider>();

    // التحقق من حالة الاتصال أولاً
    final isConnected = await provider.checkConnection();
    if (!mounted) return;

    if (isConnected) {
      await provider.loadGroups();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مجموعات واتساب'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: () {
              Navigator.pushNamed(context, '/whatsapp_setup');
            },
            tooltip: 'إعداد واتساب',
          ),
        ],
      ),
      body: Consumer<WhatsAppProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
                child: LoadingIndicator(message: 'جاري تحميل المجموعات...'));
          }

          if (!provider.isConnected) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phonelink_erase,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'غير متصل بواتساب',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'يجب إعداد الاتصال أولاً عن طريق مسح رمز QR',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/whatsapp_setup');
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('إعداد واتساب'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ],
              ),
            );
          }

          if (provider.error != null) {
            return ErrorView(
              message: provider.error!,
              onRetry: _loadGroups,
            );
          }

          if (provider.groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.group_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'لا توجد مجموعات متاحة',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'تأكد من أن رقم الهاتف المرتبط منضم إلى مجموعات واتساب',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _loadGroups,
                    icon: const Icon(Icons.refresh),
                    label: const Text('تحديث'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadGroups,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.groups.length,
              itemBuilder: (context, index) {
                final group = provider.groups[index];
                return _WhatsAppGroupCard(group: group);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/create_post');
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
        tooltip: 'إنشاء منشور',
      ),
    );
  }
}

class _WhatsAppGroupCard extends StatelessWidget {
  final WhatsAppGroup group;

  const _WhatsAppGroupCard({
    Key? key,
    required this.group,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          // مستقبلاً: يمكن إضافة شاشة تفاصيل المجموعة هنا
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.green,
                radius: 24,
                child: Text(
                  group.name.isNotEmpty ? group.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.people, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${group.participants} مشارك',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Consumer<WhatsAppProvider>(
                builder: (context, provider, _) {
                  final isSelected = provider.isGroupSelected(group.id);
                  return IconButton(
                    icon: Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isSelected ? Colors.green : Colors.grey,
                    ),
                    onPressed: () {
                      provider.toggleGroupSelection(group.id);
                    },
                    tooltip: isSelected
                        ? 'إلغاء اختيار المجموعة'
                        : 'اختيار المجموعة',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
