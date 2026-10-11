import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path_provider/path_provider.dart';

const serviceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const characteristicUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

void main() => runApp(const ReactionApp());

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
}

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

class ReactionApp extends StatelessWidget {
  const ReactionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff35d0ba),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Reaction Lab',
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xff0d1117),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff0d1117),
          foregroundColor: Color(0xfff1f5f9),
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xff151c24),
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: Color(0xff26323d)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xff111820),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
            borderSide: BorderSide(color: Color(0xff33404c)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
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
  final List<EventLogEntry> _events = [
    EventLogEntry(
      timestamp: DateTime.now(),
      message: 'Ready to connect',
      technical: false,
    ),
  ];
  int _green = 180;
  int _red = 180;
  double _minimum = 3;
  double _maximum = 6;
  bool _scanning = false;
  bool _connecting = false;
  bool _simulating = false;
  bool _technicalLog = true;
  final bool _simulation = !Platform.isAndroid && !Platform.isIOS;

  bool get _connected => _simulation || _characteristic != null;

  List<EventLogEntry> get _visibleEvents => _events
      .where((event) => _technicalLog || !event.technical)
      .toList(growable: false);

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

  void _addEvent(String event, {bool technical = true}) {
    if (!mounted) return;
    setState(() {
      _events.insert(
        0,
        EventLogEntry(
          timestamp: DateTime.now(),
          message: event,
          technical: technical,
        ),
      );
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
    _addEvent('Scanning for BLE devices...');
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final name = result.device.platformName.isNotEmpty
            ? result.device.platformName
            : result.advertisementData.advName;
        if (name.isNotEmpty) {
          _addEvent('Discovered: $name');
        }
        if (name == 'Reaction ESP32') {
          _addEvent('Found Reaction ESP32, connecting...');
          _connect(result.device);
          break;
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
      if (mounted) {
        setState(() => _scanning = false);
        _addEvent('Scan finished');
      }
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    if (_connecting || _connected) return;
    setState(() => _connecting = true);
    try {
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 10),
      );
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

    final gas = int.tryParse(fields['gas'] ?? '') ?? 0;
    final brake = int.tryParse(fields['brake'] ?? '') ?? 0;
    final reactionTime =
        int.tryParse(fields['reaction'] ?? '') ??
        int.tryParse(fields['time'] ?? '') ??
        (gas + brake);
    final record = ReactionRecord(
      reactionTime: reactionTime,
      index: int.tryParse(fields['index'] ?? '') ?? 0,
      timestamp: _formatTimestamp(DateTime.now()),
    );
    setState(() => _history.insert(0, record));
    if (mounted && _simulating) {
      setState(() => _simulating = false);
    }
    _addEvent('Waktu reaksi #${record.index} diterima', technical: false);
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}reaction_history.txt',
    );
    await file.writeAsString('${record.csv}\n', mode: FileMode.append);
  }

  Future<void> _clearHistory() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}reaction_history.txt',
    );

    if (await file.exists()) await file.delete();
    if (!mounted) return;

    setState(_history.clear);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reaction history cleared')));
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
          if (parts.length == 3) {
            return ReactionRecord(
              timestamp: _normalizeTimestamp(parts[0]),
              index: int.tryParse(parts[1]) ?? 0,
              reactionTime: int.tryParse(parts[2]) ?? 0,
            );
          }
          if (parts.length != 4) return null;
          return ReactionRecord(
            timestamp: _normalizeTimestamp(parts[0]),
            reactionTime:
                (int.tryParse(parts[1]) ?? 0) + (int.tryParse(parts[2]) ?? 0),
            index: int.tryParse(parts[3]) ?? 0,
          );
        })
        .whereType<ReactionRecord>()
        .toList();
    if (mounted) setState(() => _history.addAll(records));
  }

  Future<void> _saveHistoryAsTxt() async {
    if (_history.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No history to save')));
      return;
    }

    final fileTimestamp = _formatTimestamp(DateTime.now())
        .replaceAll(' ', '_')
        .replaceAll(':', '-');
    final suggestedName = 'reaction_history_$fileTimestamp.txt';

    final buffer = StringBuffer('History Waktu Reaksi\n\n');
    for (final record in _history) {
      buffer.writeln(
        'Waktu reaksi #${record.index} | ${record.timestamp} | ${record.reactionTime} ms',
      );
    }

    final defaultDirectory = await _getDefaultSaveDirectory();
    final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
    final saveUri = await FilePicker.saveFile(
      dialogTitle: 'Save reaction history',
      fileName: suggestedName,
      initialDirectory: defaultDirectory,
      type: FileType.custom,
      allowedExtensions: const ['txt'],
      bytes: bytes,
      mimeType: 'text/plain',
    );

    if (saveUri == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Saved TXT: ${saveUri.toString()}')));
  }

  Future<String?> _getDefaultSaveDirectory() async {
    if (Platform.isAndroid) {
      final directories = await getExternalStorageDirectories(
        type: StorageDirectory.downloads,
      );
      if (directories != null && directories.isNotEmpty) {
        return directories.first.path;
      }
    }

    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads.path;

    final documents = await getApplicationDocumentsDirectory();
    return documents.path;
  }

  Future<void> _startTest() async {
    if (!_connected || _simulating) return;
    setState(() => _simulating = true);
    if (_simulation) {
      try {
        _addEvent('Simulation test started');
        await Future<void>.delayed(const Duration(seconds: 2));
        _onMessage(utf8.encode('RESULT gas=412 brake=286 index=143'));
      } finally {
        if (mounted) setState(() => _simulating = false);
      }
      return;
    }
    try {
      await _send('START');
    } catch (error) {
      if (mounted) setState(() => _simulating = false);
      _addEvent('Start error: $error');
    }
  }

  String _formatTimestamp(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '$day-$month-$year $hour:$minute:$second';
  }

  String _formatLogTimestamp(DateTime dateTime) {
    const months = [
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
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '$day ${months[dateTime.month - 1]} ${dateTime.year} • '
        '$hour:$minute:$second';
  }

  String _normalizeTimestamp(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return _formatTimestamp(parsed);
  }

  Future<void> _syncSettings() async {
    if (_minimum > _maximum) {
      setState(() {
        final normalized = max(_minimum, _maximum);
        _maximum = normalized;
        _minimum = normalized - 1;
      });
    }
    await _sendConfig();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reaction Lab',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.4),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Row(
              children: [
                Icon(
                  _connected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: _connected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  _connected ? 'Connected' : 'Offline',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
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
              (value) => setState(() {
                _minimum = min(value, _maximum - 1);
                _maximum = max(_minimum + 1, _maximum);
              }),

              Icons.timer_outlined,
              suffix: ' s',
            ),
            _slider(
              'Maximum stop time',
              _maximum,
              Colors.blueGrey,
              (value) => setState(() {
                _maximum = max(value, _minimum + 1);
                _minimum = min(_maximum - 1, _minimum);
              }),
              Icons.timer,
              suffix: ' s',
            ),
            const SizedBox(height: 8),

            Row(
              spacing: 8,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: _connected ? _syncSettings : null,
                  icon: const Icon(Icons.sync),
                  label: const Text(
                    'Sync Settings',
                    style: TextStyle(fontSize: 12),
                  ),
                ),

                Expanded(
                  child: FilledButton.icon(
                    onPressed: _connected && !_simulating ? _startTest : null,
                    icon: _simulating
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(
                      _simulating ? 'Simulating...' : 'Start Test',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _panel(
        'EVENT LOG',
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _technicalLog ? 'Technical diagnostics' : 'Reaction data',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: _technicalLog,
                  onChanged: (value) => setState(() => _technicalLog = value),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 210,
              child: _visibleEvents.isEmpty
                  ? Center(
                      child: Text(
                        'No reaction data yet',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _visibleEvents.length,
                      itemBuilder: (context, index) {
                        final event = _visibleEvents[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Icon(
                                  Icons.circle,
                                  size: 7,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatLogTimestamp(event.timestamp),
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                _simulation
                    ? 'Wokwi / local simulation'
                    : (_connecting ? 'Connecting...' : 'BLE peripheral'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
    'REACTION TIME',
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saveHistoryAsTxt,
                icon: const Icon(Icons.save_alt),
                label: const Text('SAVE AS TXT'),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              child: Tooltip(
                message: 'Clear history',
                child: OutlinedButton(
                  onPressed: _clearHistory,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Icon(Icons.delete_outline),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
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
                        leading: CircleAvatar(child: Text('${record.index}')),
                        title: Text('Waktu reaksi #${record.index}'),
                        subtitle: Text(record.timestamp),
                        trailing: Text(
                          '${record.reactionTime} ms',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                    .toList(),
              ),
      ],
    ),
  );

  Widget _panel(String title, Widget child) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}
