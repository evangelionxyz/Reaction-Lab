class AppConstants {
  // BLE UUIDs
  static const String serviceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const String characteristicUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

  // Target BLE Device Name
  static const String defaultDeviceName = 'Reaction ESP32';
  static const List<String> recognizedDeviceNames = [
    'Reaction ESP32',
    'ESP32_Test_BLE - Clone 1',
  ];

  // Default Settings (Brightness in 0-100%, Time in seconds)
  static const int defaultGreenBrightness = 70; // 70% corresponds to ~180 PWM
  static const int defaultRedBrightness = 70;   // 70% corresponds to ~180 PWM
  static const double defaultMinStopTime = 3.0; // 3 seconds
  static const double defaultMaxStopTime = 6.0; // 6 seconds

  // Constraints
  static const double minAllowedStopTime = 1.0;
  static const double maxAllowedStopTime = 60.0;

  // File names
  static const String historyFileName = 'reaction_history.txt';
}

