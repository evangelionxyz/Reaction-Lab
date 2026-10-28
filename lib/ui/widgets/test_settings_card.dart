import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';

class TestSettingsCard extends StatefulWidget {
  const TestSettingsCard({
    super.key,
    required this.greenPercent,
    required this.redPercent,
    required this.minStopTimeSeconds,
    required this.maxStopTimeSeconds,
    required this.isConnected,
    required this.isTesting,
    required this.onGreenChanged,
    required this.onRedChanged,
    required this.onTimesChanged,
    required this.onSyncPressed,
    required this.onStartTestPressed,
  });

  final int greenPercent;
  final int redPercent;
  final double minStopTimeSeconds;
  final double maxStopTimeSeconds;
  final bool isConnected;
  final bool isTesting;

  final ValueChanged<int> onGreenChanged;
  final ValueChanged<int> onRedChanged;
  final void Function(double minTime, double maxTime) onTimesChanged;
  final VoidCallback onSyncPressed;
  final VoidCallback onStartTestPressed;

  @override
  State<TestSettingsCard> createState() => _TestSettingsCardState();
}

class _TestSettingsCardState extends State<TestSettingsCard> {
  late TextEditingController _minTimeController;
  late TextEditingController _maxTimeController;

  @override
  void initState() {
    super.initState();
    _minTimeController = TextEditingController(
      text: _formatTime(widget.minStopTimeSeconds),
    );
    _maxTimeController = TextEditingController(
      text: _formatTime(widget.maxStopTimeSeconds),
    );
  }

  @override
  void didUpdateWidget(covariant TestSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.minStopTimeSeconds != widget.minStopTimeSeconds) {
      final formatted = _formatTime(widget.minStopTimeSeconds);
      if (_minTimeController.text != formatted) {
        _minTimeController.text = formatted;
      }
    }
    if (oldWidget.maxStopTimeSeconds != widget.maxStopTimeSeconds) {
      final formatted = _formatTime(widget.maxStopTimeSeconds);
      if (_maxTimeController.text != formatted) {
        _maxTimeController.text = formatted;
      }
    }
  }

  @override
  void dispose() {
    _minTimeController.dispose();
    _maxTimeController.dispose();
    super.dispose();
  }

  String _formatTime(double time) {
    return time % 1 == 0 ? time.toInt().toString() : time.toString();
  }

  void _onTimeFieldChanged() {
    final minVal = double.tryParse(_minTimeController.text) ?? widget.minStopTimeSeconds;
    final maxVal = double.tryParse(_maxTimeController.text) ?? widget.maxStopTimeSeconds;
    widget.onTimesChanged(minVal, maxVal);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'TEST SETTINGS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Green Brightness (Percentage 0-100%)
            _buildBrightnessSlider(
              label: 'Green brightness',
              value: widget.greenPercent,
              color: Colors.teal,
              icon: Icons.light_mode,
              onChanged: widget.onGreenChanged,
            ),
            const SizedBox(height: 12),

            // Red Brightness (Percentage 0-100%)
            _buildBrightnessSlider(
              label: 'Red brightness',
              value: widget.redPercent,
              color: Colors.redAccent,
              icon: Icons.warning_amber_rounded,
              onChanged: widget.onRedChanged,
            ),
            const SizedBox(height: 16),

            // Stop Time Section Title
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 16, color: colorScheme.primary),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Durasi Tunggu Acak (Stop Time)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Text Fields for Min and Max Stop Time (No Sliders!)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Minimum stop time',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _minTimeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        decoration: const InputDecoration(
                          suffixText: 's',
                          hintText: '3',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onChanged: (_) => _onTimeFieldChanged(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Maximum stop time',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _maxTimeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        decoration: const InputDecoration(
                          suffixText: 's',
                          hintText: '6',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onChanged: (_) => _onTimeFieldChanged(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Rentang waktu tunggu: ${AppConstants.minAllowedStopTime.toInt()}s - ${AppConstants.maxAllowedStopTime.toInt()}s',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            const SizedBox(height: 18),

            // Action Buttons: Sync Settings & Start Test
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: widget.isConnected ? widget.onSyncPressed : null,
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text(
                    'Sync Settings',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.isConnected && !widget.isTesting
                        ? widget.onStartTestPressed
                        : null,
                    icon: widget.isTesting
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.play_arrow, size: 18),
                    label: Text(
                      widget.isTesting ? 'Testing...' : 'Start Test',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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

  /// Clean, responsive brightness control that will never wrap letters vertically
  Widget _buildBrightnessSlider({
    required String label,
    required int value,
    required Color color,
    required IconData icon,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$value%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            activeColor: color,
            inactiveColor: color.withValues(alpha: 0.2),
            onChanged: (val) => onChanged(val.round()),
          ),
        ),
      ],
    );
  }
}
