import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/formatters.dart';

class BleService {
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _targetCharacteristic;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _valueSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  final StreamController<List<ScanResult>> _discoveredDevicesController =
      StreamController<List<ScanResult>>.broadcast();
  final StreamController<String> _rxMessageController =
      StreamController<String>.broadcast();
  final StreamController<BluetoothConnectionState> _connectionStateController =
      StreamController<BluetoothConnectionState>.broadcast();
  final StreamController<String> _logController =
      StreamController<String>.broadcast();

  final List<ScanResult> _discoveredDevices = [];
  bool _isConnecting = false;

  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _targetCharacteristic != null && _connectedDevice != null;
  bool get isConnecting => _isConnecting;

  Stream<List<ScanResult>> get discoveredDevicesStream =>
      _discoveredDevicesController.stream;
  Stream<String> get rxMessageStream => _rxMessageController.stream;
  Stream<BluetoothConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<String> get logStream => _logController.stream;
  Stream<bool> get isScanningStream => FlutterBluePlus.isScanning;

  void _log(String message) {
    _logController.add(message);
    debugPrint('[BLE] $message');
  }

  Future<bool> isBluetoothAvailable() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return false;
    }
    return await FlutterBluePlus.isSupported;
  }

  Future<bool> ensureBluetoothOn() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;

    if (!await FlutterBluePlus.isSupported) {
      _log('Bluetooth tidak didukung di perangkat ini');
      return false;
    }

    var state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      if (Platform.isAndroid) {
        _log('Menyalakan Bluetooth...');
        try {
          await FlutterBluePlus.turnOn();
          state = await FlutterBluePlus.adapterState
              .where((s) => s == BluetoothAdapterState.on)
              .first
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          _log('Gagal menyalakan Bluetooth secara otomatis: $e');
        }
      }
    }

    if (state != BluetoothAdapterState.on) {
      _log('Bluetooth belum aktif. Silakan aktifkan Bluetooth');
      return false;
    }

    return true;
  }

  Future<void> startScan({
    Duration timeout = const Duration(seconds: 10),
    Function(BluetoothDevice device)? onAutoDeviceFound,
  }) async {
    final ready = await ensureBluetoothOn();
    if (!ready) return;

    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }

    _discoveredDevices.clear();
    _discoveredDevicesController.add([]);

    _log('Memulai pencarian perangkat BLE...');

    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        for (final r in results) {
          final index = _discoveredDevices.indexWhere(
            (d) => d.device.remoteId == r.device.remoteId,
          );
          if (index >= 0) {
            _discoveredDevices[index] = r;
          } else {
            _discoveredDevices.add(r);
            final name = _getDeviceName(r);
            if (name.isNotEmpty) {
              _log('Ditemukan: $name (${r.device.remoteId})');
            }
          }
        }
        _discoveredDevicesController.add(List.unmodifiable(_discoveredDevices));

        // Check if an ESP32 reaction device is found
        for (final r in results) {
          if (_isTargetDevice(r)) {
            _log('Perangkat target dikenali: ${_getDeviceName(r)}');
            if (onAutoDeviceFound != null) {
              onAutoDeviceFound(r.device);
            }
            break;
          }
        }
      },
      onError: (error) {
        _log('Scan error: $error');
      },
    );

    try {
      await FlutterBluePlus.startScan(timeout: timeout);
    } catch (e) {
      _log('Gagal memulai scan: $e');
    }
  }

  Future<void> stopScan() async {
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {}
    _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  bool _isTargetDevice(ScanResult result) {
    final name = _getDeviceName(result).trim().toLowerCase();
    for (final recognized in AppConstants.recognizedDeviceNames) {
      if (name == recognized.toLowerCase() || name.contains('reaction') || name.contains('esp32')) {
        return true;
      }
    }

    // Check service UUID in advertisement
    for (final uuid in result.advertisementData.serviceUuids) {
      if (uuid.str128.toLowerCase() == AppConstants.serviceUuid.toLowerCase()) {
        return true;
      }
    }

    return false;
  }

  String _getDeviceName(ScanResult result) {
    if (result.advertisementData.advName.isNotEmpty) {
      return result.advertisementData.advName;
    }
    if (result.device.platformName.isNotEmpty) {
      return result.device.platformName;
    }
    return '';
  }

  Future<bool> connect(BluetoothDevice device) async {
    if (_isConnecting) return false;
    _isConnecting = true;

    // IMPORTANT: Always stop scanning before attempting to connect
    await stopScan();
    // Allow radio state to settle
    await Future.delayed(const Duration(milliseconds: 300));

    _log('Menghubungkan ke ${device.platformName.isNotEmpty ? device.platformName : device.remoteId}...');

    try {
      // Connect to device
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      _log('Tersambung ke BLE peripheral, menegosiasikan MTU...');

      if (Platform.isAndroid) {
        try {
          await device.requestMtu(512);
        } catch (_) {}
      }

      _log('Mencari GATT Services...');
      final services = await device.discoverServices();
      BluetoothCharacteristic? targetChar;

      for (final service in services) {
        final sUuid = service.uuid.str128.toLowerCase();
        if (sUuid == AppConstants.serviceUuid.toLowerCase()) {
          for (final char in service.characteristics) {
            final cUuid = char.uuid.str128.toLowerCase();
            if (cUuid == AppConstants.characteristicUuid.toLowerCase()) {
              targetChar = char;
              break;
            }
          }
        }
      }

      if (targetChar == null) {
        throw Exception('Service / Characteristic Reaction Lab tidak ditemukan pada ESP32');
      }

      _targetCharacteristic = targetChar;
      _connectedDevice = device;

      // Subscribe to value notifications
      _valueSubscription?.cancel();
      _valueSubscription = targetChar.lastValueStream.listen(
        (bytes) {
          if (bytes.isNotEmpty) {
            final msg = utf8.decode(bytes, allowMalformed: true).trim();
            _rxMessageController.add(msg);
          }
        },
      );

      await targetChar.setNotifyValue(true);

      // Listen for connection status changes
      _connectionStateSubscription?.cancel();
      _connectionStateSubscription = device.connectionState.listen((state) {
        _connectionStateController.add(state);
        if (state == BluetoothConnectionState.disconnected) {
          _log('Koneksi ESP32 terputus');
          _cleanUpConnection();
        }
      });

      _log('Koneksi berhasil & siap menerima data!');
      _connectionStateController.add(BluetoothConnectionState.connected);
      _isConnecting = false;
      return true;
    } catch (error) {
      _log('Gagal menghubungkan: $error');
      _cleanUpConnection();
      try {
        await device.disconnect();
      } catch (_) {}
      _isConnecting = false;
      return false;
    }
  }

  void _cleanUpConnection() {
    _valueSubscription?.cancel();
    _valueSubscription = null;
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    _targetCharacteristic = null;
    _connectedDevice = null;
    _connectionStateController.add(BluetoothConnectionState.disconnected);
  }

  Future<void> disconnect() async {
    _log('Memutuskan koneksi...');
    final dev = _connectedDevice;
    _cleanUpConnection();
    if (dev != null) {
      try {
        await dev.disconnect();
      } catch (_) {}
    }
    _log('Koneksi terputus');
  }

  Future<bool> sendCommand(String command) async {
    final char = _targetCharacteristic;
    if (char == null) {
      _log('Gagal kirim: Perangkat belum tersambung');
      return false;
    }

    try {
      final bytes = Uint8List.fromList(utf8.encode(command));
      await char.write(bytes, withoutResponse: false);
      _log('TX  $command');
      return true;
    } catch (e) {
      _log('TX Gagal ($command): $e');
      return false;
    }
  }

  /// Sends configuration to ESP32:
  /// Converts brightness percentages (0-100%) to PWM values (0-255) for ESP32 hardware,
  /// and converts stop times in seconds to milliseconds.
  Future<bool> sendConfig({
    required int greenPercent,
    required int redPercent,
    required double minSeconds,
    required double maxSeconds,
  }) async {
    final pwmGreen = Formatters.percentToPwm(greenPercent);
    final pwmRed = Formatters.percentToPwm(redPercent);
    final minMs = (minSeconds * 1000).round();
    final maxMs = (maxSeconds * 1000).round();

    final cmd = 'CFG g=$pwmGreen r=$pwmRed min=$minMs max=$maxMs';
    return await sendCommand(cmd);
  }

  void dispose() {
    stopScan();
    disconnect();
    _discoveredDevicesController.close();
    _rxMessageController.close();
    _connectionStateController.close();
    _logController.close();
  }
}
