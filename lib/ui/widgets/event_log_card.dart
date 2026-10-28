import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../models/event_log_entry.dart';

class EventLogCard extends StatelessWidget {
  const EventLogCard({
    super.key,
    required this.events,
    required this.isTechnicalLog,
    required this.onToggleTechnicalLog,
  });

  final List<EventLogEntry> events;
  final bool isTechnicalLog;
  final ValueChanged<bool> onToggleTechnicalLog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final visibleEvents = events
        .where((event) => isTechnicalLog || !event.technical)
        .toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'EVENT LOG',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                Text(
                  isTechnicalLog ? 'Diagnostik' : 'Data Reaksi',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Switch.adaptive(
                  value: isTechnicalLog,
                  onChanged: onToggleTechnicalLog,
                  activeTrackColor: colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: visibleEvents.isEmpty
                  ? Center(
                      child: Text(
                        'Belum ada aktivitas atau log',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: visibleEvents.length,
                      itemBuilder: (context, index) {
                        final event = visibleEvents[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: event.technical
                                      ? colorScheme.primary
                                      : Colors.amberAccent,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      Formatters.formatLogTimestamp(event.timestamp),
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      event.message,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
