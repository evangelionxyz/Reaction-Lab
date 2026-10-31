import 'package:flutter/material.dart';

class ConnectionCard extends StatelessWidget {
  const ConnectionCard({
    super.key,
    required this.isConnected,
    required this.isConnecting,
    required this.isScanning,
    required this.deviceName,
    required this.onScanPressed,
    required this.onDisconnectPressed,
    required this.onShowDevicePicker,
  });

  final bool isConnected;
  final bool isConnecting;
  final bool isScanning;
  final String deviceName;
  final VoidCallback onScanPressed;
  final VoidCallback onDisconnectPressed;
  final VoidCallback onShowDevicePicker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
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
                        isConnected ? deviceName : 'No device connected',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (isConnecting
                            ? 'Menghubungkan ke ESP32...'
                            : (isScanning
                                  ? 'Memindai perangkat...'
                                  : (isConnected
                                        ? 'Terhubung via BLE'
                                        : 'BLE peripheral'))),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
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
                      : Icon(
                          isConnected ? Icons.link_off : Icons.search,
                          size: 16,
                        ),
                  label: Text(
                    isConnected
                        ? 'DISCONNECT'
                        : (isConnecting
                              ? 'CONNECTING'
                              : (isScanning ? 'SCANNING' : 'SCAN')),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
