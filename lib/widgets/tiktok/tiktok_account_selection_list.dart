import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/tiktok_account.dart';
import '../../providers/tiktok_provider.dart';

/// قائمة اختيار حسابات تيك توك
///
/// تسمح للمستخدم باختيار حسابات تيك توك لنشر المحتوى
class TikTokAccountSelectionList extends StatelessWidget {
  const TikTokAccountSelectionList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TikTokProvider>(
      builder: (context, provider, _) {
        final accounts = provider.accounts;

        if (provider.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            ),
          );
        }

        if (accounts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'لا توجد حسابات تيك توك مرتبطة',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/tiktok_setup');
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('ربط حساب تيك توك'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black, // لون تيك توك
                  ),
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
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final account = accounts[index];
                return _TikTokAccountSelectionTile(account: account);
              },
            ),
            // إظهار خطأ إذا وجد
            if (provider.error != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  provider.error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            // زر إضافة حساب جديد
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/tiktok_setup');
                },
                icon: const Icon(Icons.add),
                label: const Text('ربط حساب تيك توك جديد'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// بطاقة عرض حساب تيك توك فردي
class _TikTokAccountSelectionTile extends StatelessWidget {
  final TikTokAccount account;

  const _TikTokAccountSelectionTile({
    Key? key,
    required this.account,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TikTokProvider>(
      builder: (context, provider, _) {
        final isSelected = provider.isAccountSelected(account.id);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected ? Colors.black : Colors.grey.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              // صف الاختيار الرئيسي
              CheckboxListTile(
                value: isSelected,
                onChanged: (_) => provider.toggleAccountSelection(account.id),
                title: Text('@${account.username}'),
                subtitle: account.isTokenExpired
                    ? Row(
                        children: const [
                          Icon(Icons.error_outline,
                              color: Colors.red, size: 16),
                          SizedBox(width: 4),
                          Text('انتهت صلاحية الرمز - يلزم التحديث',
                              style: TextStyle(color: Colors.red)),
                        ],
                      )
                    : Row(
                        children: const [
                          Icon(Icons.check_circle,
                              color: Colors.green, size: 16),
                          SizedBox(width: 4),
                          Text('حساب نشط',
                              style: TextStyle(color: Colors.green)),
                        ],
                      ),
                secondary: account.avatarUrl != null
                    ? CircleAvatar(
                        backgroundImage: NetworkImage(account.avatarUrl!),
                        backgroundColor: Colors.black,
                      )
                    : CircleAvatar(
                        backgroundColor: Colors.black,
                        child: Text(
                          account.username.isNotEmpty
                              ? account.username[0].toUpperCase()
                              : 'T',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                // تمييز حسابات تيك توك بلون خلفية
                tileColor: isSelected ? Colors.black.withOpacity(0.05) : null,
                activeColor: Colors.black,
                checkColor: Colors.white,
                dense: false,
                controlAffinity: ListTileControlAffinity.trailing,
              ),
              // أزرار الإجراءات
              Padding(
                padding: const EdgeInsets.only(
                    left: 16, right: 16, bottom: 8, top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // زر تحديث الحساب
                    IconButton(
                      icon: const Icon(Icons.refresh,
                          size: 20, color: Colors.blue),
                      tooltip: 'تحديث الحساب',
                      onPressed: () async {
                        final success =
                            await provider.refreshAccountInfo(account.id);
                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم تحديث معلومات الحساب بنجاح'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                    ),
                    // زر إزالة الحساب
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: Colors.red),
                      tooltip: 'إزالة الحساب',
                      onPressed: () => _confirmAccountRemoval(
                        context,
                        provider,
                        account,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// تأكيد إزالة الحساب
  Future<void> _confirmAccountRemoval(
    BuildContext context,
    TikTokProvider provider,
    TikTokAccount account,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إزالة الحساب'),
        content:
            Text('هل أنت متأكد من رغبتك في إزالة حساب @${account.username}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      await provider.removeAccount(account.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إزالة الحساب بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
