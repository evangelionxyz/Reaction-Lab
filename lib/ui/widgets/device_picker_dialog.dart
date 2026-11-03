import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DevicePickerDialog extends StatelessWidget {
  const DevicePickerDialog({
    super.key,
    required this.devices,
    required this.isScanning,
    required this.onSelect,
    required this.onRefreshScan,
  });

  final List<ScanResult> devices;
  final bool isScanning;
  final ValueChanged<BluetoothDevice> onSelect;
  final VoidCallback onRefreshScan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: theme.cardTheme.color ?? theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.bluetooth_searching, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Perangkat BLE Terdeteksi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih ESP32 atau perangkat Reaction Lab:',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: devices.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          isScanning
                              ? 'Mencari perangkat BLE di sekitar...'
                              : 'Tidak ada perangkat ditemukan.\nPastikan ESP32 menyala dan Bluetooth aktif.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: devices.length,
                      separatorBuilder: (_, _) => Divider(
                        color: theme.dividerColor.withValues(alpha: 0.1),
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final item = devices[index];
                        final name = item.advertisementData.advName.isNotEmpty
                            ? item.advertisementData.advName
                            : (item.device.platformName.isNotEmpty
                                ? item.device.platformName
                                : 'Perangkat Tanpa Nama');
                        final isTarget = name.toLowerCase().contains('reaction') ||
                            name.toLowerCase().contains('esp32');

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          leading: CircleAvatar(
                            backgroundColor: isTarget
                                ? colorScheme.primary.withValues(alpha: 0.2)
                                : colorScheme.onSurface.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.devices,
                              color: isTarget ? colorScheme.primary : colorScheme.onSurfaceVariant,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight: isTarget ? FontWeight.bold : FontWeight.w500,
                              color: isTarget ? colorScheme.primary : colorScheme.onSurface,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${item.device.remoteId} • RSSI: ${item.rssi} dBm',
                            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                          ),
                          trailing: FilledButton(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              onSelect(item.device);
                            },
                            child: const Text('Sambungkan', style: TextStyle(fontSize: 12)),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isScanning)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: isScanning ? null : onRefreshScan,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(isScanning ? 'Memindai...' : 'Pindai Ulang', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
