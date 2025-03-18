import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/whatsapp_provider.dart';
import '../../models/whatsapp_group.dart';

class WhatsAppGroupSelectionList extends StatelessWidget {
  const WhatsAppGroupSelectionList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WhatsAppProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
                child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            )),
          );
        }

        // Show sync status
        if (provider.isSyncing) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
                const SizedBox(height: 16),
                Text(
                  provider.syncMessage ?? 'Syncing groups...',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final groups = provider.groups;

        if (groups.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'No WhatsApp groups available',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Make sure the connected phone number is joined to WhatsApp groups',
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
                      onPressed: () => provider.loadGroups(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        // Show loading indicator
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Syncing groups... This may take a moment'),
                            duration: Duration(seconds: 5),
                          ),
                        );

                        // Start sync
                        final syncedGroups = await provider.syncGroups();

                        if (!context.mounted) return;

                        if (syncedGroups.isNotEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('Synced ${syncedGroups.length} groups'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'No groups synced. Ensure your phone is connected to groups.'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.sync),
                      label: const Text('Sync Groups'),
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
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return _WhatsAppGroupSelectionTile(group: group);
              },
            ),
            if (provider.error != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  provider.error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => provider.loadGroups(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      // Show loading indicator
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Syncing groups... This may take a moment'),
                          duration: Duration(seconds: 5),
                        ),
                      );

                      // Start sync
                      final syncedGroups = await provider.syncGroups();

                      if (!context.mounted) return;

                      if (syncedGroups.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('Synced ${syncedGroups.length} groups'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No new groups synced'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync Groups'),
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
}

class _WhatsAppGroupSelectionTile extends StatelessWidget {
  final WhatsAppGroup group;

  const _WhatsAppGroupSelectionTile({
    Key? key,
    required this.group,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WhatsAppProvider>(
      builder: (context, provider, _) {
        final isSelected = provider.isGroupSelected(group.id);

        return CheckboxListTile(
          value: isSelected,
          onChanged: (_) => provider.toggleGroupSelection(group.id),
          title: Text(group.name),
          subtitle: Row(
            children: [
              const Icon(Icons.people, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text('${group.participants} members'),
              if (group.isContact == true) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: const Text(
                    'Inactive',
                    style: TextStyle(fontSize: 10, color: Colors.orange),
                  ),
                ),
              ],
            ],
          ),
          secondary: CircleAvatar(
            backgroundColor: Colors.green,
            child: Text(
              group.name.isNotEmpty ? group.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Highlight WhatsApp groups with background color
          tileColor: group.isContact == true
              ? Colors.orange.withOpacity(0.05) // Inactive groups
              : Colors.green.withOpacity(0.05), // Active groups
        );
      },
    );
  }
}
