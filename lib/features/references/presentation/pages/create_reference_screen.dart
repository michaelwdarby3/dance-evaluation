import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/core/models/pose_sequence.dart';
import 'package:dance_evaluation/core/models/reference_choreography.dart';
import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/data/reference_repository.dart';
import 'package:dance_evaluation/features/capture/presentation/capture_controller.dart';
import 'package:dance_evaluation/features/upload/domain/video_file_picker.dart';
import 'package:dance_evaluation/features/upload/domain/video_pose_extractor.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';

enum _CreateState { form, picking, processing, done, error }

/// Screen for creating a new reference choreography from a video upload.
class CreateReferenceScreen extends StatefulWidget {
  const CreateReferenceScreen({super.key});

  @override
  State<CreateReferenceScreen> createState() => _CreateReferenceScreenState();
}

class _CreateReferenceScreenState extends State<CreateReferenceScreen> {
  final _nameController = TextEditingController();
  final _bpmController = TextEditingController(text: '120');
  DanceStyle _style = DanceStyle.hipHop;
  String _difficulty = 'beginner';

  _CreateState _state = _CreateState.form;
  double _progress = 0.0;
  int _frameCount = 0;
  String? _errorMessage;

  final List<PoseFrame> _extractedFrames = [];
  Duration _videoDuration = Duration.zero;

  @override
  void dispose() {
    _nameController.dispose();
    _bpmController.dispose();
    super.dispose();
  }

  Future<void> _pickAndExtract() async {
    final sl = ServiceLocator.instance;
    final picker = sl.get<VideoFilePicker>();
    final extractor = sl.get<VideoPoseExtractor>();

    setState(() {
      _state = _CreateState.picking;
      _extractedFrames.clear();
      _frameCount = 0;
      _progress = 0.0;
    });

    try {
      final videoUrl = await picker.pickVideo();
      if (videoUrl == null) {
        setState(() => _state = _CreateState.form);
        return;
      }

      setState(() => _state = _CreateState.processing);

      _videoDuration = await extractor.extractPoses(
        videoUrl: videoUrl,
        onProgress: (p) => setState(() => _progress = p),
        onFrame: (frame) {
          _extractedFrames.add(frame);
          setState(() => _frameCount = _extractedFrames.length);
        },
      );

      if (_extractedFrames.isEmpty) {
        throw Exception('No poses detected in video');
      }

      // Save the reference.
      final name = _nameController.text.trim().isEmpty
          ? 'Reference ${DateTime.now().millisecondsSinceEpoch}'
          : _nameController.text.trim();
      final bpm = double.tryParse(_bpmController.text) ?? 120.0;
      final id = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

      final ref = ReferenceChoreography(
        id: id,
        name: name,
        style: _style,
        poses: PoseSequence(
          frames: _extractedFrames,
          fps: _videoDuration.inMilliseconds > 0
              ? _extractedFrames.length / (_videoDuration.inMilliseconds / 1000)
              : _extractedFrames.length.toDouble(),
          duration: _videoDuration,
          label: id,
        ),
        bpm: bpm,
        description: 'Created from uploaded video',
        difficulty: _difficulty,
      );

      sl.get<ReferenceRepository>().save(ref);

      setState(() => _state = _CreateState.done);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _state = _CreateState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Reference'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: _buildBody(theme),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    switch (_state) {
      case _CreateState.form:
        return _buildForm(theme);
      case _CreateState.picking:
        return _buildPicking(theme);
      case _CreateState.processing:
        return _buildProcessing(theme);
      case _CreateState.done:
        return _buildDone(theme);
      case _CreateState.error:
        return _buildError(theme);
    }
  }

  Widget _buildForm(ThemeData theme) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Upload a dance video to create a reference that others '
            'can be evaluated against.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Reference Name',
              hintText: 'e.g. "Basic K-Pop Routine"',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<DanceStyle>(
            value: _style,
            decoration: const InputDecoration(
              labelText: 'Dance Style',
              border: OutlineInputBorder(),
            ),
            items: DanceStyle.values.map((s) {
              return DropdownMenuItem(value: s, child: Text(s.name));
            }).toList(),
            onChanged: (v) => setState(() => _style = v ?? _style),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _difficulty,
            decoration: const InputDecoration(
              labelText: 'Difficulty',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
              DropdownMenuItem(value: 'intermediate', child: Text('Intermediate')),
              DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
            ],
            onChanged: (v) => setState(() => _difficulty = v ?? _difficulty),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bpmController,
            decoration: const InputDecoration(
              labelText: 'BPM (optional)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _pickAndExtract,
            icon: const Icon(Icons.video_library),
            label: const Text('Select Video & Create'),
          ),
        ],
      ),
    );
  }

  Widget _buildPicking(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.upload_file, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        const Text('Select a video file...', style: TextStyle(fontSize: 18)),
      ],
    );
  }

  Widget _buildProcessing(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(
          'Extracting poses...',
          style: TextStyle(fontSize: 18, color: theme.colorScheme.secondary),
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(value: _progress),
        const SizedBox(height: 12),
        Text(
          '${(_progress * 100).round()}% ($_frameCount poses detected)',
          style: const TextStyle(fontSize: 14, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildDone(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        const Text('Reference created!', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 8),
        Text(
          '$_frameCount frames extracted',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => context.go('/'),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _buildError(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
        const SizedBox(height: 16),
        Text(
          _errorMessage ?? 'Unknown error',
          style: const TextStyle(fontSize: 16, color: Colors.redAccent),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => setState(() => _state = _CreateState.form),
          child: const Text('Try Again'),
        ),
      ],
    );
  }
}
