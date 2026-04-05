import 'package:flutter/material.dart';

import 'package:dance_evaluation/core/services/settings_service.dart';

/// Expandable settings panel overlaid on the capture screen.
///
/// Groups settings into collapsible sections. Tapping the gear icon toggles
/// the panel open/closed.
class CaptureSettingsPanel extends StatefulWidget {
  const CaptureSettingsPanel({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final SettingsService settings;

  /// Called when any setting changes so the parent can rebuild.
  final VoidCallback onChanged;

  @override
  State<CaptureSettingsPanel> createState() => _CaptureSettingsPanelState();
}

class _CaptureSettingsPanelState extends State<CaptureSettingsPanel>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late final AnimationController _animController;
  late final Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
    if (_isOpen) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  void _onSettingChanged() {
    setState(() {});
    widget.onChanged();
  }

  SettingsService get _s => widget.settings;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Gear toggle button
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 4),
            child: Material(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _toggle,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _isOpen ? Icons.close : Icons.settings,
                    color: Colors.white70,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Animated settings panel
        SizeTransition(
          sizeFactor: _slideAnimation,
          axisAlignment: 1.0,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            decoration: const BoxDecoration(
              color: Color(0xE6121220),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                _buildDisplayGroup(),
                _buildRecordingGroup(),
                _buildDetectionGroup(),
                _buildFeedbackGroup(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Display
  // ---------------------------------------------------------------------------

  Widget _buildDisplayGroup() {
    return _SettingsGroup(
      title: 'Display',
      icon: Icons.visibility,
      children: [
        _switchTile(
          'Mirror Video',
          _s.mirrorPreview,
          (v) {
            _s.mirrorPreview = v;
            _onSettingChanged();
          },
        ),
        _switchTile(
          'Mirror Skeleton',
          _s.mirrorSkeleton,
          (v) {
            _s.mirrorSkeleton = v;
            _onSettingChanged();
          },
        ),
        _switchTile(
          'Skeleton Overlay',
          _s.skeletonOverlay,
          (v) {
            _s.skeletonOverlay = v;
            _onSettingChanged();
          },
        ),
        _switchTile(
          'Reference Ghost',
          _s.referenceGhost,
          (v) {
            _s.referenceGhost = v;
            _onSettingChanged();
          },
        ),
        if (_s.referenceGhost)
          _sliderTile(
            'Ghost Opacity',
            _s.ghostOpacity,
            0.1,
            1.0,
            9,
            '${(_s.ghostOpacity * 100).round()}%',
            (v) {
              _s.ghostOpacity = v;
              _onSettingChanged();
            },
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Recording
  // ---------------------------------------------------------------------------

  Widget _buildRecordingGroup() {
    return _SettingsGroup(
      title: 'Recording',
      icon: Icons.videocam,
      children: [
        _switchTile(
          'Audio Playback',
          _s.audioEnabled,
          (v) {
            _s.audioEnabled = v;
            _onSettingChanged();
          },
        ),
        _switchTile(
          'Video Recording',
          _s.videoRecording,
          (v) {
            _s.videoRecording = v;
            _onSettingChanged();
          },
        ),
        _dropdownTile(
          'Countdown',
          _s.countdownSeconds,
          {3: '3s', 5: '5s', 10: '10s'},
          (v) {
            _s.countdownSeconds = v;
            _onSettingChanged();
          },
        ),
        _dropdownTile(
          'Max Duration',
          _s.maxRecordingSeconds,
          {15: '15s', 30: '30s', 60: '1m', 120: '2m'},
          (v) {
            _s.maxRecordingSeconds = v;
            _onSettingChanged();
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Detection
  // ---------------------------------------------------------------------------

  Widget _buildDetectionGroup() {
    return _SettingsGroup(
      title: 'Detection',
      icon: Icons.person_search,
      children: [
        _switchTile(
          'Multi-Person',
          _s.multiPersonDetection,
          (v) {
            _s.multiPersonDetection = v;
            _onSettingChanged();
          },
        ),
        _sliderTile(
          'Confidence',
          _s.minConfidence,
          0.0,
          0.8,
          8,
          '${(_s.minConfidence * 100).round()}%',
          (v) {
            _s.minConfidence = v;
            _onSettingChanged();
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Feedback
  // ---------------------------------------------------------------------------

  Widget _buildFeedbackGroup() {
    return _SettingsGroup(
      title: 'Feedback',
      icon: Icons.feedback,
      children: [
        _switchTile(
          'Haptic Feedback',
          _s.hapticFeedback,
          (v) {
            _s.hapticFeedback = v;
            _onSettingChanged();
          },
        ),
        _switchTile(
          'AI Coaching',
          _s.aiCoaching,
          (v) {
            _s.aiCoaching = v;
            _onSettingChanged();
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Reusable tile builders
  // ---------------------------------------------------------------------------

  Widget _switchTile(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: onChanged,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _sliderTile(
    String label,
    double value,
    double min,
    double max,
    int divisions,
    String displayLabel,
    ValueChanged<double> onChanged,
  ) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text(displayLabel,
              style: const TextStyle(fontSize: 12, color: Colors.white38)),
        ],
      ),
      subtitle: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 2,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        ),
        child: Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _dropdownTile<T>(
    String label,
    T value,
    Map<T, String> options,
    ValueChanged<T> onChanged,
  ) {
    final effectiveValue = options.containsKey(value) ? value : options.keys.first;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: DropdownButton<T>(
        value: effectiveValue,
        underline: const SizedBox.shrink(),
        isDense: true,
        style: const TextStyle(fontSize: 13, color: Colors.white70),
        items: options.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

/// A single collapsible settings group with a header icon and title.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: Icon(icon, size: 20, color: Colors.white54),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      dense: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.only(left: 8, right: 8),
      collapsedIconColor: Colors.white38,
      iconColor: Colors.white54,
      children: children,
    );
  }
}
