import 'package:flutter_test/flutter_test.dart';

import 'package:esp32/core/utils/formatters.dart';
import 'package:esp32/models/reaction_record.dart';

void main() {
  group('Formatters tests', () {
    test('percentToPwm and pwmToPercent conversions', () {
      expect(Formatters.percentToPwm(0), 0);
      expect(Formatters.percentToPwm(100), 255);
      expect(Formatters.percentToPwm(70), 179);
      expect(Formatters.percentToPwm(-10), 0);
      expect(Formatters.percentToPwm(150), 255);

      expect(Formatters.pwmToPercent(0), 0);
      expect(Formatters.pwmToPercent(255), 100);
      expect(Formatters.pwmToPercent(180), 71);
    });

    test('timestamp formatting', () {
      final dt = DateTime(2026, 10, 29, 14, 5, 9);
      expect(Formatters.formatTimestamp(dt), '29-10-2026 14:05:09');
      expect(Formatters.formatLogTimestamp(dt), '29 Oct 2026 • 14:05:09');
    });
  });

  group('ReactionRecord tests', () {
    test('CSV parsing and serialization (3 fields)', () {
      const line = '29-10-2026 14:05:09,1,450';
      final record = ReactionRecord.fromCsv(line);
      expect(record.timestamp, '29-10-2026 14:05:09');
      expect(record.index, 1);
      expect(record.reactionTime, 450);
      expect(record.csv, line);
    });

    test('CSV parsing legacy (4 fields: gas + brake)', () {
      const line = '29-10-2026 14:05:09,200,250,2';
      final record = ReactionRecord.fromCsv(line);
      expect(record.index, 2);
      expect(record.reactionTime, 450);
    });
  });
}

