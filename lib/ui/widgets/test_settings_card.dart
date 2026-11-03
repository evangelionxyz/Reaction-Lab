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
    required this.onGreenChanged,
    required this.onRedChanged,
    required this.onTimesChanged,
    required this.onSyncPressed,
  });

  final int greenPercent;
  final int redPercent;
  final double minStopTimeSeconds;
  final double maxStopTimeSeconds;
  final bool isConnected;

  final ValueChanged<int> onGreenChanged;
  final ValueChanged<int> onRedChanged;
  final void Function(double minTime, double maxTime) onTimesChanged;
  final VoidCallback onSyncPressed;

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
            _BrightnessSlider(
              label: 'Green brightness',
              value: widget.greenPercent,
              color: Colors.teal,
              icon: Icons.light_mode,
              onChanged: widget.onGreenChanged,
            ),
            const SizedBox(height: 12),

            // Red Brightness (Percentage 0-100%)
            _BrightnessSlider(
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
                        decoration: InputDecoration(
                          suffixText: 's',
                          hintText: '3',
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                        decoration: InputDecoration(
                          suffixText: 's',
                          hintText: '6',
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

            // Action Button: Sync Settings
            FilledButton.icon(
              onPressed: widget.isConnected ? widget.onSyncPressed : null,
              icon: const Icon(Icons.sync, size: 18),
              label: const Text(
                'Sync Settings',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrightnessSlider extends StatefulWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final ValueChanged<int> onChanged;

  const _BrightnessSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.onChanged,
  });

  @override
  State<_BrightnessSlider> createState() => _BrightnessSliderState();
}

class _BrightnessSliderState extends State<_BrightnessSlider> {
  late int _localValue;

  @override
  void initState() {
    super.initState();
    _localValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant _BrightnessSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _localValue = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(widget.icon, color: widget.color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.label,
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
                color: widget.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$_localValue%',
                style: TextStyle(
                  color: widget.color,
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
            value: _localValue.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            activeColor: widget.color,
            inactiveColor: widget.color.withValues(alpha: 0.2),
            onChanged: (val) {
              setState(() => _localValue = val.round());
            },
            onChangeEnd: (val) {
              widget.onChanged(val.round());
            },
          ),
        ),
      ],
    );
  }
}

