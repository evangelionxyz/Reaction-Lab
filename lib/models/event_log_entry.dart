class EventLogEntry {
  const EventLogEntry({
    required this.timestamp,
    required this.message,
    required this.technical,
  });

  final DateTime timestamp;
  final String message;
  final bool technical;
}

