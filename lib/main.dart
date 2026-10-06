import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path_provider/path_provider.dart';

const serviceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const characteristicUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

void main() => runApp(const ReactionApp());

class ReactionRecord {
  const ReactionRecord({
    required this.gas,
    required this.brake,
    required this.index,
    required this.timestamp,
  });

  final int gas;
  final int brake;
  final int index;
  final String timestamp;

  String get csv => '$timestamp,$gas,$brake,$index';
}

class ReactionApp extends StatelessWidget {
  const ReactionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff087f73),
      brightness: Brightness.light,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Reaction Lab',
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfff4f3ee),
      ),
      home: const ReactionHomePage(),
    );
  }
}

class ReactionHomePage extends StatefulWidget {
  const ReactionHomePage({super.key});

  @override
  State<ReactionHomePage> createState() => _ReactionHomePageState();
}

class _ReactionHomePageState extends State<ReactionHomePage> {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _valueSubscription;
  final List<ReactionRecord> _history = [];
  final List<String> _events = ['Ready to connect'];
  int _green = 180;
  int _red = 180;
  double _minimum = 3;
  double _maximum = 6;
  bool _scanning = false;
  bool _connecting = false;
  final bool _simulation = !Platform.isAndroid && !Platform.isIOS;

  bool get _connected => _simulation || _characteristic != null;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _valueSubscription?.cancel();
    _device?.disconnect();
    super.dispose();
  }

  void _addEvent(String event) {
    if (!mounted) return;
    setState(() {
      _events.insert(0, event);
      if (_events.length > 8) _events.removeLast();
    });
  }

  Future<void> _scan() async {
    if (_scanning) return;
    if (_simulation) {
      _addEvent('Simulation mode active');
      return;
    }
    setState(() => _scanning = true);
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        if (result.device.platformName == 'Reaction ESP32') {
          _connect(result.device);
        }
      }
    });
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));
    } catch (error) {
      _addEvent('Scan error: $error');
    } finally {
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    if (_connecting || _connected) return;
    setState(() => _connecting = true);
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      final services = await device.discoverServices();
      final service = services
          .where((item) => item.uuid.str128.toLowerCase() == serviceUuid)
          .firstOrNull;
      _characteristic = service?.characteristics
          .where((item) => item.uuid.str128.toLowerCase() == characteristicUuid)
          .firstOrNull;
      if (_characteristic == null) {
        throw Exception('Reaction service not found');
      }
      await _characteristic!.setNotifyValue(true);
      _valueSubscription = _characteristic!.onValueReceived.listen(_onMessage);
      _device = device;
      _addEvent('Connected to Reaction ESP32');
      await _sendConfig();
    } catch (error) {
      _addEvent('Connection failed: $error');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _disconnect() async {
    await _valueSubscription?.cancel();
    _valueSubscription = null;
    await _device?.disconnect();
    if (mounted) {
      setState(() {
        _device = null;
        _characteristic = null;
      });
    }
    _addEvent('Disconnected');
  }

  Future<void> _send(String command) async {
    if (_simulation) {
      _addEvent('TX  $command');
      return;
    }
    final characteristic = _characteristic;
    if (characteristic == null) return;
    await characteristic.write(
      Uint8List.fromList(utf8.encode(command)),
      withoutResponse: false,
    );
    _addEvent('TX  $command');
  }

  Future<void> _sendConfig() => _send(
    'CFG g=$_green r=$_red min=${(_minimum * 1000).round()} max=${(_maximum * 1000).round()}',
  );

  void _onMessage(List<int> bytes) {
    final message = utf8.decode(bytes, allowMalformed: true).trim();
    _addEvent('RX  $message');
    if (message.startsWith('RESULT ')) _recordResult(message);
  }

  Future<void> _recordResult(String message) async {
    final fields = <String, String>{};
    for (final part in message.substring(7).split(' ')) {
      final pair = part.split('=');
      if (pair.length == 2) fields[pair[0]] = pair[1];
    }
    final record = ReactionRecord(
      gas: int.tryParse(fields['gas'] ?? '') ?? 0,
      brake: int.tryParse(fields['brake'] ?? '') ?? 0,
      index: int.tryParse(fields['index'] ?? '') ?? 0,
      timestamp: DateTime.now().toIso8601String(),
    );
    setState(() => _history.insert(0, record));
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}reaction_history.txt',
    );
    await file.writeAsString('${record.csv}\n', mode: FileMode.append);
  }

  Future<void> _loadHistory() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}reaction_history.txt',
    );
    if (!await file.exists()) return;
    final rows = await file.readAsLines();
    final records = rows.reversed
        .take(20)
        .map((row) {
          final parts = row.split(',');
          if (parts.length != 4) return null;
          return ReactionRecord(
            timestamp: parts[0],
            gas: int.tryParse(parts[1]) ?? 0,
            brake: int.tryParse(parts[2]) ?? 0,
            index: int.tryParse(parts[3]) ?? 0,
          );
        })
        .whereType<ReactionRecord>()
        .toList();
    if (mounted) setState(() => _history.addAll(records));
  }

  Future<void> _startTest() async {
    if (!_connected) return;
    if (_simulation) {
      _addEvent('Simulation test started');
      await Future<void>.delayed(const Duration(milliseconds: 700));
      _onMessage(utf8.encode('RESULT gas=412 brake=286 index=143'));
      return;
    }
    await _send('START');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'REACTION LAB',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
        ),
        actions: [
          Icon(
            _connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            color: _connected ? Colors.teal : Colors.grey,
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 760;
          final content = wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _controls()),
                    const SizedBox(width: 24),
                    Expanded(child: _historyPanel()),
                  ],
                )
              : Column(
                  children: [
                    _controls(),
                    const SizedBox(height: 24),
                    _historyPanel(),
                  ],
                );
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
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

  Widget _controls() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _connectionPanel(),
      const SizedBox(height: 16),
      _panel(
        'TEST SETTINGS',
        Column(
          children: [
            _slider(
              'Green brightness',
              _green.toDouble(),
              Colors.teal,
              (value) => setState(() => _green = value.round()),
              Icons.light_mode,
            ),
            _slider(
              'Red brightness',
              _red.toDouble(),
              Colors.redAccent,
              (value) => setState(() => _red = value.round()),
              Icons.warning_amber,
            ),
            _slider(
              'Minimum stop time',
              _minimum,
              Colors.blueGrey,
              (value) => setState(() => _minimum = value),
              Icons.timer_outlined,
              suffix: ' s',
            ),
            _slider(
              'Maximum stop time',
              _maximum,
              Colors.blueGrey,
              (value) => setState(() => _maximum = value),
              Icons.timer,
              suffix: ' s',
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _connected ? _sendConfig : null,
              icon: const Icon(Icons.sync),
              label: const Text('SYNC SETTINGS'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: _connected ? _startTest : null,
        icon: const Icon(Icons.play_arrow),
        label: const Text('START REACTION TEST'),
        style: FilledButton.styleFrom(padding: const EdgeInsets.all(18)),
      ),
      const SizedBox(height: 16),
      _panel(
        'EVENT LOG',
        SizedBox(
          height: 156,
          child: ListView.builder(
            itemCount: _events.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                _events[index],
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _connectionPanel() => _panel(
    'DEVICE',
    Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _connected
                    ? (_simulation ? 'Desktop simulator' : 'Reaction ESP32')
                    : 'No device connected',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _simulation
                    ? 'Wokwi / local simulation'
                    : (_connecting ? 'Connecting...' : 'BLE peripheral'),
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _connected && !_simulation ? _disconnect : _scan,
          icon: Icon(_connected ? Icons.link_off : Icons.search),
          label: Text(
            _connected ? 'DISCONNECT' : (_scanning ? 'SCANNING' : 'SCAN'),
          ),
        ),
      ],
    ),
  );

  Widget _slider(
    String label,
    double value,
    Color color,
    ValueChanged<double> onChanged,
    IconData icon, {
    String suffix = '',
  }) => Row(
    children: [
      Icon(icon, color: color),
      const SizedBox(width: 10),
      Expanded(child: Text(label)),
      SizedBox(
        width: 170,
        child: Slider(
          value: value,
          min: label.contains('time') ? 1 : 0,
          max: label.contains('time') ? 15 : 255,
          divisions: label.contains('time') ? 14 : 255,
          activeColor: color,
          onChanged: onChanged,
        ),
      ),
      SizedBox(
        width: 48,
        child: Text(
          '${value.toStringAsFixed(0)}$suffix',
          textAlign: TextAlign.end,
        ),
      ),
    ],
  );

  Widget _historyPanel() => _panel(
    'REACTION HISTORY',
    _history.isEmpty
        ? const SizedBox(
            height: 240,
            child: Center(child: Text('No results yet')),
          )
        : Column(
            children: _history
                .map(
                  (record) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.shade50,
                      child: Text('${record.index}'),
                    ),
                    title: Text(
                      '${record.gas} ms gas  /  ${record.brake} ms brake',
                    ),
                    subtitle: Text(record.timestamp),
                    trailing: Text(
                      '${record.gas + record.brake} ms',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                )
                .toList(),
          ),
  );

  Widget _panel(String title, Widget child) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.black12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade600,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}
