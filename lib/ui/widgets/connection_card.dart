import 'package:flutter/material.dart';

class ConnectionCard extends StatelessWidget {
  const ConnectionCard({
    super.key,
    required this.isConnected,
    required this.isConnecting,
    required this.isScanning,
    required this.isSimulationMode,
    required this.deviceName,
    required this.onScanPressed,
    required this.onDisconnectPressed,
    required this.onShowDevicePicker,
    required this.onToggleSimulation,
  });

  final bool isConnected;
  final bool isConnecting;
  final bool isScanning;
  final bool isSimulationMode;
  final String deviceName;
  final VoidCallback onScanPressed;
  final VoidCallback onDisconnectPressed;
  final VoidCallback onShowDevicePicker;
  final ValueChanged<bool> onToggleSimulation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Simulation Mode Card (as seen in screenshot)
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Simulation Mode',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isSimulationMode
                            ? 'Mode Simulasi — menghasilkan data lokal'
                            : 'BLE Mode — menerima data dari ESP32',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: isSimulationMode,
                  onChanged: onToggleSimulation,
                  activeTrackColor: colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Device Connection Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'DEVICE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isConnected
                                ? (isSimulationMode ? 'Simulator Aktif' : deviceName)
                                : 'No device connected',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isSimulationMode
                                ? 'Wokwi / simulasi lokal'
                                : (isConnecting
                                    ? 'Menghubungkan ke ESP32...'
                                    : (isScanning
                                        ? 'Memindai perangkat...'
                                        : (isConnected ? 'Terhubung via BLE' : 'BLE peripheral'))),
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isSimulationMode) ...[
                      if (!isConnected)
                        IconButton(
                          tooltip: 'Daftar perangkat BLE',
                          icon: const Icon(Icons.list_alt),
                          onPressed: onShowDevicePicker,
                        ),
                      const SizedBox(width: 4),
                      OutlinedButton.icon(
                        onPressed: isConnecting
                            ? null
                            : (isConnected ? onDisconnectPressed : onScanPressed),
                        icon: isScanning || isConnecting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(isConnected ? Icons.link_off : Icons.search, size: 16),
                        label: Text(
                          isConnected
                              ? 'DISCONNECT'
                              : (isConnecting
                                  ? 'CONNECTING'
                                  : (isScanning ? 'SCANNING' : 'SCAN')),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
