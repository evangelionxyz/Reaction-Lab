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
    return Dialog(
      backgroundColor: const Color(0xff151c24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xff26323d)),
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
                    const Icon(Icons.bluetooth_searching, color: Color(0xff35d0ba)),
                    const SizedBox(width: 8),
                    const Text(
                      'Perangkat BLE Terdeteksi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
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
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
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
                          style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: devices.length,
                      separatorBuilder: (_, _) => const Divider(
                        color: Color(0xff26323d),
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
                                ? const Color(0xff35d0ba).withValues(alpha: 0.2)
                                : const Color(0xff26323d),
                            child: Icon(
                              Icons.devices,
                              color: isTarget ? const Color(0xff35d0ba) : Colors.grey,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight: isTarget ? FontWeight.bold : FontWeight.w500,
                              color: isTarget ? const Color(0xff35d0ba) : Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${item.device.remoteId} • RSSI: ${item.rssi} dBm',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
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
