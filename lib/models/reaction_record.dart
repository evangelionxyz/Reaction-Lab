class ReactionRecord {
  const ReactionRecord({
    required this.reactionTime,
    required this.index,
    required this.timestamp,
  });

  final int reactionTime;
  final int index;
  final String timestamp;

  String get csv => '$timestamp,$index,$reactionTime';

  factory ReactionRecord.fromCsv(String csvLine, {String Function(String)? normalizer}) {
    final parts = csvLine.split(',');
    if (parts.length == 3) {
      final ts = normalizer != null ? normalizer(parts[0]) : parts[0];
      return ReactionRecord(
        timestamp: ts,
        index: int.tryParse(parts[1]) ?? 0,
        reactionTime: int.tryParse(parts[2]) ?? 0,
      );
    }
    if (parts.length == 4) {
      final ts = normalizer != null ? normalizer(parts[0]) : parts[0];
      final gas = int.tryParse(parts[1]) ?? 0;
      final brake = int.tryParse(parts[2]) ?? 0;
      return ReactionRecord(
        timestamp: ts,
        reactionTime: gas + brake,
        index: int.tryParse(parts[3]) ?? 0,
      );
    }
    throw FormatException('Invalid CSV line format: $csvLine');
  }
}

