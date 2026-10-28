class Formatters {
  static const List<String> months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String formatTimestamp(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '$day-$month-$year $hour:$minute:$second';
  }

  static String formatLogTimestamp(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '$day ${months[dateTime.month - 1]} ${dateTime.year} • $hour:$minute:$second';
  }

  static String normalizeTimestamp(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return formatTimestamp(parsed);
  }

  /// Converts percentage (0-100) to PWM duty cycle (0-255)
  static int percentToPwm(int percent) {
    return ((percent.clamp(0, 100) / 100.0) * 255).round().clamp(0, 255);
  }

  /// Converts PWM duty cycle (0-255) to percentage (0-100)
  static int pwmToPercent(int pwm) {
    return ((pwm.clamp(0, 255) / 255.0) * 100).round().clamp(0, 100);
  }
}

