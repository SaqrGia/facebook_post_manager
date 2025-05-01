import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/whatsapp_provider.dart';
import '../../models/whatsapp_channel.dart';

/// قائمة اختيار قنوات واتساب
///
/// تعرض قائمة بقنوات واتساب المتاحة ويمكن للمستخدم اختيارها للنشر
class WhatsAppChannelSelectionList extends StatelessWidget {
  const WhatsAppChannelSelectionList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WhatsAppProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingChannels) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
                child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            )),
          );
        }

        // عرض حالة المزامنة
        if (provider.isSyncingChannels) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
                const SizedBox(height: 16),
                Text(
                  provider.channelSyncMessage ?? 'جاري مزامنة القنوات...',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final channels = provider.channels;

        // تعديل الأزرار في حالة عدم وجود قنوات
        if (channels.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'لا توجد قنوات واتساب متاحة',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'يمكنك مزامنة القنوات الموجودة',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          provider.loadChannels(forceRefresh: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('تحديث'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        // عرض مؤشر التحميل
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'جاري مزامنة القنوات... قد يستغرق الأمر وقتًا'),
                            duration: Duration(seconds: 5),
                          ),
                        );

                        // بدء المزامنة
                        final syncedChannels = await provider.syncChannels();

                        if (!context.mounted) return;

                        if (syncedChannels.isNotEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'تم مزامنة ${syncedChannels.length} قناة'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'لم يتم العثور على قنوات، تأكد من اشتراكك في قنوات واتساب'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.sync),
                      label: const Text('مزامنة القنوات'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final channel = channels[index];
                return _WhatsAppChannelSelectionTile(channel: channel);
              },
            ),
            if (provider.channelError != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  provider.channelError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => provider.loadChannels(forceRefresh: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('تحديث'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      // عرض مؤشر التحميل
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'جاري مزامنة القنوات... قد يستغرق الأمر وقتًا'),
                          duration: Duration(seconds: 5),
                        ),
                      );

                      // بدء المزامنة
                      final syncedChannels = await provider.syncChannels();

                      if (!context.mounted) return;

                      if (syncedChannels.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('تم مزامنة ${syncedChannels.length} قناة'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('لم يتم مزامنة أي قنوات جديدة'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.sync),
                    label: const Text('مزامنة القنوات'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // حوار إنشاء قناة جديدة
  Future<void> _showCreateChannelDialog(
      BuildContext context, WhatsAppProvider provider) async {
    final formKey = GlobalKey<FormState>();
    final channelNameController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنشاء قناة جديدة'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: channelNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم القناة',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال اسم للقناة';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'وصف القناة (اختياري)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      // عرض مؤشر التحميل
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جاري إنشاء القناة...'),
          duration: Duration(seconds: 5),
        ),
      );

      // إنشاء القناة
      final channel = await provider.createChannel(
        channelName: channelNameController.text,
        description: descriptionController.text.isEmpty
            ? null
            : descriptionController.text,
      );

      if (!context.mounted) return;

      if (channel != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إنشاء القناة "${channel.channelName}" بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'فشل إنشاء القناة: ${provider.channelError ?? "خطأ غير معروف"}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// بطاقة قناة واتساب
class _WhatsAppChannelSelectionTile extends StatelessWidget {
  final WhatsAppChannel channel;

  const _WhatsAppChannelSelectionTile({
    Key? key,
    required this.channel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WhatsAppProvider>(
      builder: (context, provider, _) {
        final isSelected = provider.isChannelSelected(channel.id);

        return CheckboxListTile(
          value: isSelected,
          onChanged: (_) => provider.toggleChannelSelection(channel.id),
          title: Text(channel.channelName),
          subtitle: Row(
            children: [
              const Icon(Icons.broadcast_on_personal,
                  size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              if (channel.subscribeCount != null)
                Text('${channel.subscribeCount} مشترك'),
              if (channel.subscribeCount == null) const Text('قناة واتساب'),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.lightBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.lightBlue.withOpacity(0.5)),
                ),
                child: Text(
                  channel.owner ? 'مالك' : 'مشترك',
                  style: TextStyle(
                    fontSize: 10,
                    color: channel.owner ? Colors.blue : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          secondary: CircleAvatar(
            backgroundColor: Colors.lightBlue,
            child: Icon(
              Icons.broadcast_on_personal,
              color: Colors.white,
              size: 20,
            ),
          ),
          // تمييز قنوات واتساب بلون خلفية
          tileColor: Colors.lightBlue.withOpacity(0.05),
        );
      },
    );
  }
}
