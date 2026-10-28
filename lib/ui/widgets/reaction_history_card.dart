import 'package:flutter/material.dart';

import '../../models/reaction_record.dart';

class ReactionHistoryCard extends StatelessWidget {
  const ReactionHistoryCard({
    super.key,
    required this.history,
    required this.onSaveTxtPressed,
    required this.onClearPressed,
  });

  final List<ReactionRecord> history;
  final VoidCallback onSaveTxtPressed;
  final VoidCallback onClearPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'REACTION TIME',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 1.4,
                  ),
                ),
                Text(
                  '${history.length} Data',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: history.isEmpty ? null : onSaveTxtPressed,
                    icon: const Icon(Icons.save_alt, size: 16),
                    label: const Text(
                      'SAVE AS TXT',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  child: Tooltip(
                    message: 'Hapus riwayat',
                    child: OutlinedButton(
                      onPressed: history.isEmpty ? null : onClearPressed,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: colorScheme.error,
                      ),
                      child: const Icon(Icons.delete_outline, size: 18),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            history.isEmpty
                ? const SizedBox(
                    height: 220,
                    child: Center(
                      child: Text(
                        'Belum ada hasil waktu reaksi',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: history.length,
                    separatorBuilder: (_, _) => const Divider(
                      color: Color(0xff26323d),
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final record = history[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 2),
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
                          child: Text(
                            '${record.index}',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        title: Text(
                          'Waktu reaksi #${record.index}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          record.timestamp,
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                        trailing: Text(
                          '${record.reactionTime} ms',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: colorScheme.primary,
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
