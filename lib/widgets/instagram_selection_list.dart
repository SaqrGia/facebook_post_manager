import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pages_provider.dart';
import '../models/instagram_account.dart';

class InstagramSelectionList extends StatelessWidget {
  const InstagramSelectionList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PagesProvider>(
      builder: (context, provider, _) {
        final accounts = provider.instagramAccounts;

        if (accounts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('لا توجد حسابات انستقرام مرتبطة متاحة'),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: accounts.length,
          itemBuilder: (context, index) {
            final account = accounts[index];
            return _InstagramSelectionTile(account: account);
          },
        );
      },
    );
  }
}

class _InstagramSelectionTile extends StatelessWidget {
  final InstagramAccount account;

  const _InstagramSelectionTile({
    Key? key,
    required this.account,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PagesProvider>(
      builder: (context, provider, _) {
        final isSelected = provider.isInstagramSelected(account.id);

        return CheckboxListTile(
          value: isSelected,
          onChanged: (_) => provider.toggleInstagramSelection(account.id),
          title: Text('@${account.username}'),
          subtitle: const Text('حساب انستقرام'),
          secondary: account.profilePictureUrl != null
              ? CircleAvatar(
                  backgroundImage: NetworkImage(account.profilePictureUrl!),
                )
              : const CircleAvatar(
                  backgroundColor: Color(0xFFC13584), // لون انستقرام
                  child: Icon(Icons.camera_alt, color: Colors.white),
                ),
          // تمييز حسابات انستقرام بلون مختلف
          tileColor: Colors.pink.withOpacity(0.05),
        );
      },
    );
  }
}
