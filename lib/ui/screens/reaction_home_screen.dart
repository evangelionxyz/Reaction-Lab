import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../models/event_log_entry.dart';
import '../../models/reaction_record.dart';
import '../../services/ble_service.dart';
import '../../services/storage_service.dart';
import '../widgets/connection_card.dart';
import '../widgets/device_picker_dialog.dart';
import '../widgets/event_log_card.dart';
import '../widgets/reaction_history_card.dart';
import '../widgets/test_settings_card.dart';

class ReactionHomeScreen extends StatefulWidget {
  const ReactionHomeScreen({super.key});

  @override
  State<ReactionHomeScreen> createState() => _ReactionHomeScreenState();
}

class _ReactionHomeScreenState extends State<ReactionHomeScreen> {
  final BleService _bleService = BleService();
  final StorageService _storageService = StorageService();

  final List<ReactionRecord> _history = [];
  final List<EventLogEntry> _events = [
    EventLogEntry(
      timestamp: DateTime.now(),
      message: 'Aplikasi siap digunakan',
      technical: false,
    ),
  ];

  int _greenPercent = AppConstants.defaultGreenBrightness;
  int _redPercent = AppConstants.defaultRedBrightness;
  double _minStopTime = AppConstants.defaultMinStopTime;
  double _maxStopTime = AppConstants.defaultMaxStopTime;

  bool _isSimulationMode = !kIsWeb && !Platform.isAndroid && !Platform.isIOS;
  bool _isScanning = false;
  bool _isTesting = false;
  bool _technicalLog = true;

  StreamSubscription<String>? _rxSub;
  StreamSubscription<String>? _logSub;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;
  StreamSubscription<bool>? _scanSub;
  Timer? _testTimeoutTimer;

  bool get _isConnected => _isSimulationMode || _bleService.isConnected;

  @override
  void initState() {
    super.initState();
    _initServices();
    _loadHistory();
  }

  void _initServices() {
    _logSub = _bleService.logStream.listen((msg) {
      _addEvent(msg, technical: true);
    });

    _rxSub = _bleService.rxMessageStream.listen((message) {
      _addEvent('RX  $message', technical: true);
      if (message.startsWith('RESULT ')) {
        _recordResult(message);
      }
    });

    _connStateSub = _bleService.connectionStateStream.listen((state) {
      if (mounted) setState(() {});
    });

    _scanSub = _bleService.isScanningStream.listen((scanning) {
      if (mounted) setState(() => _isScanning = scanning);
    });
  }

  @override
  void dispose() {
    _testTimeoutTimer?.cancel();
    _rxSub?.cancel();
    _logSub?.cancel();
    _connStateSub?.cancel();
    _scanSub?.cancel();
    _bleService.dispose();
    super.dispose();
  }

  void _addEvent(String message, {bool technical = true}) {
    if (!mounted) return;
    setState(() {
      _events.insert(
        0,
        EventLogEntry(
          timestamp: DateTime.now(),
          message: message,
          technical: technical,
        ),
      );
      if (_events.length > 50) {
        _events.removeLast();
      }
    });
  }

  Future<void> _loadHistory() async {
    final loaded = await _storageService.loadHistory();
    if (mounted) {
      setState(() {
        _history.clear();
        _history.addAll(loaded);
      });
    }
  }

  Future<void> _scanDevices() async {
    if (_isSimulationMode) {
      _addEvent('Mode simulasi aktif (BLE dinonaktifkan)', technical: false);
      return;
    }

    _addEvent('Memindai perangkat Bluetooth LE...', technical: false);

    await _bleService.startScan(
      timeout: const Duration(seconds: 8),
      onAutoDeviceFound: (device) {
        _addEvent('Target ${device.platformName} ditemukan! Menghubungkan...', technical: false);
        _connectDevice(device);
      },
    );
  }

  Future<void> _connectDevice(BluetoothDevice device) async {
    final success = await _bleService.connect(device);
    if (!mounted) return;

    if (success) {
      _addEvent('Berhasil terhubung ke ${device.platformName}', technical: false);
      await _syncSettings();
    } else {
      _addEvent('Gagal menghubungkan ke perangkat', technical: false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Koneksi BLE gagal. Pastikan ESP32 dalam jangkauan dan menyala.'),
        ),
      );
    }
    setState(() {});
  }

  Future<void> _disconnectDevice() async {
    await _bleService.disconnect();
    if (mounted) {
      setState(() {});
      _addEvent('Terputus dari ESP32', technical: false);
    }
  }

  void _showDevicePicker() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StreamBuilder<List<ScanResult>>(
          stream: _bleService.discoveredDevicesStream,
          initialData: const [],
          builder: (context, snapshot) {
            return DevicePickerDialog(
              devices: snapshot.data ?? [],
              isScanning: _isScanning,
              onSelect: (device) => _connectDevice(device),
              onRefreshScan: _scanDevices,
            );
          },
        );
      },
    );

    // If not already scanning, start a scan
    if (!_isScanning) {
      _scanDevices();
    }
  }

  Future<void> _syncSettings() async {
    // Validate min and max stop times
    if (_minStopTime < AppConstants.minAllowedStopTime) {
      _minStopTime = AppConstants.minAllowedStopTime;
    }
    if (_maxStopTime > AppConstants.maxAllowedStopTime) {
      _maxStopTime = AppConstants.maxAllowedStopTime;
    }
    if (_minStopTime > _maxStopTime) {
      final temp = _minStopTime;
      _minStopTime = _maxStopTime;
      _maxStopTime = temp;
    }

    if (_isSimulationMode) {
      _addEvent(
        'Sinkronisasi simulasi: Green=$_greenPercent%, Red=$_redPercent%, Min=${_minStopTime}s, Max=${_maxStopTime}s',
        technical: false,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengaturan berhasil diperbarui (Simulasi)')),
        );
      }
      return;
    }

    final sent = await _bleService.sendConfig(
      greenPercent: _greenPercent,
      redPercent: _redPercent,
      minSeconds: _minStopTime,
      maxSeconds: _maxStopTime,
    );

    if (sent && mounted) {
      _addEvent('Pengaturan terkirim ke ESP32', technical: false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengaturan berhasil disinkronkan ke ESP32')),
      );
    }
  }

  Future<void> _startTest() async {
    if (!_isConnected || _isTesting) return;
    setState(() => _isTesting = true);

    if (_isSimulationMode) {
      try {
        _addEvent('Uji reaksi dimulai (Mode Simulasi)...', technical: false);
        await Future<void>.delayed(const Duration(seconds: 2));
        final fakeGas = 200 + Random().nextInt(300);
        final fakeBrake = 180 + Random().nextInt(250);
        final fakeIndex = 100000 ~/ (fakeGas + fakeBrake);
        _recordResult('RESULT gas=$fakeGas brake=$fakeBrake index=$fakeIndex');
      } finally {
        if (mounted) setState(() => _isTesting = false);
      }
      return;
    }

    _testTimeoutTimer?.cancel();
    _testTimeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && _isTesting) {
        setState(() => _isTesting = false);
        _addEvent('Waktu pengujian habis. Tidak ada respons dari ESP32.', technical: false);
      }
    });

    try {
      final sent = await _bleService.sendCommand('START');
      if (!sent) {
        _testTimeoutTimer?.cancel();
        if (mounted) setState(() => _isTesting = false);
      }
    } catch (e) {
      _testTimeoutTimer?.cancel();
      if (mounted) setState(() => _isTesting = false);
      _addEvent('Gagal memulai uji: $e');
    }
  }

  Future<void> _recordResult(String message) async {
    final fields = <String, String>{};
    for (final part in message.substring(7).split(' ')) {
      final pair = part.split('=');
      if (pair.length == 2) fields[pair[0]] = pair[1];
    }

    final gas = int.tryParse(fields['gas'] ?? '') ?? 0;
    final brake = int.tryParse(fields['brake'] ?? '') ?? 0;
    final reactionTime =
        int.tryParse(fields['reaction'] ?? '') ??
        int.tryParse(fields['time'] ?? '') ??
        (gas + brake);

    final record = ReactionRecord(
      reactionTime: reactionTime,
      index: int.tryParse(fields['index'] ?? '') ?? (_history.length + 1),
      timestamp: Formatters.formatTimestamp(DateTime.now()),
    );

    _testTimeoutTimer?.cancel();

    setState(() {
      _history.insert(0, record);
      _isTesting = false;
    });

    _addEvent(
      'Hasil diterima: Waktu Reaksi #${record.index} = ${record.reactionTime} ms',
      technical: false,
    );

    await _storageService.appendRecord(record);
  }

  Future<void> _clearHistory() async {
    await _storageService.clearHistory();
    if (!mounted) return;
    setState(() => _history.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Riwayat waktu reaksi berhasil dihapus')),
    );
  }

  Future<void> _saveHistoryAsTxt() async {
    if (_history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada riwayat untuk disimpan')),
      );
      return;
    }

    final path = await _storageService.saveHistoryAsTxt(_history);
    if (!mounted) return;

    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Riwayat berhasil disimpan: $path')),
      );
    }
  }

  void _onTimesChanged(double minTime, double maxTime) {
    setState(() {
      _minStopTime = minTime;
      _maxStopTime = maxTime;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final deviceName = _bleService.connectedDevice?.platformName.isNotEmpty == true
        ? _bleService.connectedDevice!.platformName
        : 'Reaction ESP32';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reaction Lab',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.4),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Row(
              children: [
                Icon(
                  _isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: _isConnected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isSimulationMode
                      ? 'Simulasi'
                      : (_isConnected ? 'Connected' : 'Offline'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 760;

          final controlsColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConnectionCard(
                isConnected: _isConnected,
                isConnecting: _bleService.isConnecting,
                isScanning: _isScanning,
                isSimulationMode: _isSimulationMode,
                deviceName: deviceName,
                onScanPressed: _scanDevices,
                onDisconnectPressed: _disconnectDevice,
                onShowDevicePicker: _showDevicePicker,
                onToggleSimulation: (val) {
                  setState(() => _isSimulationMode = val);
                  if (val) {
                    _disconnectDevice();
                  }
                },
              ),
              const SizedBox(height: 16),
              TestSettingsCard(
                greenPercent: _greenPercent,
                redPercent: _redPercent,
                minStopTimeSeconds: _minStopTime,
                maxStopTimeSeconds: _maxStopTime,
                isConnected: _isConnected,
                isTesting: _isTesting,
                onGreenChanged: (val) => setState(() => _greenPercent = val),
                onRedChanged: (val) => setState(() => _redPercent = val),
                onTimesChanged: _onTimesChanged,
                onSyncPressed: _syncSettings,
                onStartTestPressed: _startTest,
              ),
              const SizedBox(height: 16),
              EventLogCard(
                events: _events,
                isTechnicalLog: _technicalLog,
                onToggleTechnicalLog: (val) => setState(() => _technicalLog = val),
              ),
            ],
          );

          final content = isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: controlsColumn),
                    const SizedBox(width: 24),
                    Expanded(
                      child: ReactionHistoryCard(
                        history: _history,
                        onSaveTxtPressed: _saveHistoryAsTxt,
                        onClearPressed: _clearHistory,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    controlsColumn,
                    const SizedBox(height: 16),
                    ReactionHistoryCard(
                      history: _history,
                      onSaveTxtPressed: _saveHistoryAsTxt,
                      onClearPressed: _clearHistory,
                    ),
                  ],
                );

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: content,
              ),
            ),
          );
        },
      ),
    );
  }
}
