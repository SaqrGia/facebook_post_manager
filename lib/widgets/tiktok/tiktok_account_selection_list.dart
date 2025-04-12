import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/tiktok_account.dart';
import '../../providers/tiktok_provider.dart';

class TikTokAccountSelectionList extends StatelessWidget {
  const TikTokAccountSelectionList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TikTokProvider>(
      builder: (context, provider, _) {
        final accounts = provider.accounts;

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
                  icon: const Icon(Icons.qr_code),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/tiktok_setup');
                },
                icon: const Icon(Icons.add),
                label: const Text('ربط حساب تيك توك جديد'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black, // لون تيك توك
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

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

        return CheckboxListTile(
          value: isSelected,
          onChanged: (_) => provider.toggleAccountSelection(account.id),
          title: Text('@${account.username}'),
          subtitle: account.isTokenExpired
              ? const Text('انتهت صلاحية الرمز - انقر للتحديث',
                  style: TextStyle(color: Colors.red))
              : const Text('حساب تيك توك'),
          secondary: account.avatarUrl != null
              ? CircleAvatar(
                  backgroundImage: NetworkImage(account.avatarUrl!),
                  backgroundColor: Colors.black,
                )
              : const CircleAvatar(
                  backgroundColor: Colors.black, // لون تيك توك
                  child: Icon(Icons.music_note, color: Colors.white),
                ),
          // تمييز حسابات تيك توك بلون مختلف
          tileColor: Colors.black.withOpacity(0.05),
          activeColor: Colors.black,
        );
      },
    );
  }
}
