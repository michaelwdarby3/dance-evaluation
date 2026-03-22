import 'package:flutter/material.dart';

import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/core/services/settings_service.dart';
import 'package:dance_evaluation/data/evaluation_history_repository.dart';
import 'package:dance_evaluation/data/reference_repository.dart';

/// App settings screen with grouped toggles and sliders.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsService _settings;

  @override
  void initState() {
    super.initState();
    _settings = ServiceLocator.instance.get<SettingsService>();
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ------ Capture ------
          _sectionHeader('Capture'),
          SwitchListTile(
            title: const Text('Audio Playback'),
            subtitle: const Text('Play reference audio or metronome during capture'),
            value: _settings.audioEnabled,
            onChanged: (v) => _settings.audioEnabled = v,
          ),
          SwitchListTile(
            title: const Text('Skeleton Overlay'),
            subtitle: const Text('Show real-time pose skeleton on camera preview'),
            value: _settings.skeletonOverlay,
            onChanged: (v) => _settings.skeletonOverlay = v,
          ),
          SwitchListTile(
            title: const Text('Reference Ghost'),
            subtitle: const Text('Show reference choreography overlay while recording'),
            value: _settings.referenceGhost,
            onChanged: (v) => _settings.referenceGhost = v,
          ),
          if (_settings.referenceGhost)
            ListTile(
              title: const Text('Ghost Opacity'),
              subtitle: Slider(
                value: _settings.ghostOpacity,
                min: 0.1,
                max: 1.0,
                divisions: 9,
                label: '${(_settings.ghostOpacity * 100).round()}%',
                onChanged: (v) => _settings.ghostOpacity = v,
              ),
            ),
          SwitchListTile(
            title: const Text('Video Recording'),
            subtitle: const Text('Record video for playback after evaluation'),
            value: _settings.videoRecording,
            onChanged: (v) => _settings.videoRecording = v,
          ),
          SwitchListTile(
            title: const Text('Mirror Preview'),
            subtitle: const Text('Mirror the front camera preview horizontally'),
            value: _settings.mirrorPreview,
            onChanged: (v) => _settings.mirrorPreview = v,
          ),
          _buildCountdownPicker(),
          _buildRecordingDurationPicker(),

          // ------ Detection ------
          _sectionHeader('Detection'),
          SwitchListTile(
            title: const Text('Multi-Person Detection'),
            subtitle: const Text('Detect and track up to 5 people simultaneously'),
            value: _settings.multiPersonDetection,
            onChanged: (v) => _settings.multiPersonDetection = v,
          ),

          // ------ Evaluation ------
          _sectionHeader('Evaluation'),
          _buildStylePicker(),
          SwitchListTile(
            title: const Text('AI Coaching'),
            subtitle: const Text('Enhanced feedback via Claude API (requires API key)'),
            value: _settings.aiCoaching,
            onChanged: (v) => _settings.aiCoaching = v,
          ),
          if (_settings.aiCoaching)
            ListTile(
              title: const Text('Claude API Key'),
              subtitle: Text(
                _settings.aiApiKey.isEmpty
                    ? 'Not configured'
                    : '••••${_settings.aiApiKey.substring((_settings.aiApiKey.length - 4).clamp(0, _settings.aiApiKey.length))}',
                style: TextStyle(
                  color: _settings.aiApiKey.isEmpty
                      ? Colors.orange
                      : Colors.green,
                ),
              ),
              trailing: const Icon(Icons.edit, size: 20),
              onTap: () => _showApiKeyDialog(),
            ),

          // ------ Feedback ------
          _sectionHeader('Feedback'),
          SwitchListTile(
            title: const Text('Haptic Feedback'),
            subtitle: const Text('Vibrate on countdown ticks and recording events'),
            value: _settings.hapticFeedback,
            onChanged: (v) => _settings.hapticFeedback = v,
          ),

          // ------ Data ------
          _sectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.orange),
            title: const Text('Clear Evaluation History'),
            subtitle: const Text('Delete all saved scores and sessions'),
            onTap: () => _confirmClearHistory(),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.orange),
            title: const Text('Clear Custom References'),
            subtitle: const Text('Delete all user-created references'),
            onTap: () => _confirmClearReferences(),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.restore, color: Colors.redAccent),
            title: const Text('Reset All Settings'),
            subtitle: const Text('Restore all settings to defaults'),
            onTap: () => _confirmResetSettings(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCountdownPicker() {
    const options = [3, 5, 10];
    return ListTile(
      title: const Text('Countdown Duration'),
      subtitle: const Text('Seconds before recording starts'),
      trailing: DropdownButton<int>(
        value: options.contains(_settings.countdownSeconds)
            ? _settings.countdownSeconds
            : options.first,
        underline: const SizedBox.shrink(),
        items: options
            .map((s) => DropdownMenuItem(value: s, child: Text('${s}s')))
            .toList(),
        onChanged: (v) {
          if (v != null) _settings.countdownSeconds = v;
        },
      ),
    );
  }

  Widget _buildRecordingDurationPicker() {
    const options = [15, 30, 60, 120];
    return ListTile(
      title: const Text('Max Recording Duration'),
      subtitle: const Text('Maximum length of a capture session'),
      trailing: DropdownButton<int>(
        value: options.contains(_settings.maxRecordingSeconds)
            ? _settings.maxRecordingSeconds
            : options.first,
        underline: const SizedBox.shrink(),
        items: options.map((s) {
          final label = s >= 60 ? '${s ~/ 60}m' : '${s}s';
          return DropdownMenuItem(value: s, child: Text(label));
        }).toList(),
        onChanged: (v) {
          if (v != null) _settings.maxRecordingSeconds = v;
        },
      ),
    );
  }

  Widget _buildStylePicker() {
    const styles = {
      'hip_hop': 'Hip Hop',
      'kpop': 'K-Pop',
      'contemporary': 'Contemporary',
      'freestyle': 'Freestyle',
    };
    return ListTile(
      title: const Text('Default Dance Style'),
      subtitle: const Text('Used when no reference specifies a style'),
      trailing: DropdownButton<String>(
        value: styles.containsKey(_settings.defaultStyle)
            ? _settings.defaultStyle
            : styles.keys.first,
        underline: const SizedBox.shrink(),
        items: styles.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: (v) {
          if (v != null) _settings.defaultStyle = v;
        },
      ),
    );
  }

  Future<void> _showApiKeyDialog() async {
    final controller = TextEditingController(text: _settings.aiApiKey);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Claude API Key'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'sk-ant-...',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          autocorrect: false,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      _settings.aiApiKey = result;
    }
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await _showConfirmDialog(
      'Clear History',
      'This will permanently delete all saved evaluation results. Continue?',
    );
    if (confirmed && mounted) {
      final repo =
          ServiceLocator.instance.get<EvaluationHistoryRepository>();
      repo.clearAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evaluation history cleared')),
        );
      }
    }
  }

  Future<void> _confirmClearReferences() async {
    final confirmed = await _showConfirmDialog(
      'Clear Custom References',
      'This will delete all user-created references. Built-in references will remain. Continue?',
    );
    if (confirmed && mounted) {
      final repo = ServiceLocator.instance.get<ReferenceRepository>();
      repo.deleteAllUserRefs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Custom references cleared')),
        );
      }
    }
  }

  Future<void> _confirmResetSettings() async {
    final confirmed = await _showConfirmDialog(
      'Reset Settings',
      'This will reset all settings to their default values. Continue?',
    );
    if (confirmed) {
      await _settings.resetAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings reset to defaults')),
        );
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
