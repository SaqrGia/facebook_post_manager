import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pages_provider.dart';
import '../../models/page.dart';

class PageSelectionList extends StatelessWidget {
  const PageSelectionList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PagesProvider>(
      builder: (context, provider, _) {
        final pages = provider.pages;

        if (pages.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('لا توجد صفحات متاحة'),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: pages.length,
          itemBuilder: (context, index) {
            final page = pages[index];
            return _PageSelectionTile(page: page);
          },
        );
      },
    );
  }
}

class _PageSelectionTile extends StatelessWidget {
  final FacebookPage page;

  const _PageSelectionTile({
    Key? key,
    required this.page,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PagesProvider>(
      builder: (context, provider, _) {
        final isSelected = provider.isPageSelected(page.id);

        return CheckboxListTile(
          value: isSelected,
          onChanged: (_) => provider.togglePageSelection(page.id),
          title: Text(page.name),
          subtitle: page.category != null ? Text(page.category!) : null,
          secondary: page.pictureUrl != null
              ? CircleAvatar(
                  backgroundImage: NetworkImage(page.pictureUrl!),
                )
              : const CircleAvatar(
                  child: Icon(Icons.pages),
                ),
        );
      },
    );
  }
}
