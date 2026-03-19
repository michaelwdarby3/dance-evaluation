import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/features/upload/presentation/upload_controller.dart';

class UploadProcessingScreen extends StatefulWidget {
  const UploadProcessingScreen({super.key, this.referenceKey});

  final String? referenceKey;

  @override
  State<UploadProcessingScreen> createState() =>
      _UploadProcessingScreenState();
}

class _UploadProcessingScreenState extends State<UploadProcessingScreen> {
  late final UploadController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ServiceLocator.instance.get<UploadController>();
    _controller.addListener(_onStateChanged);
    _controller.pickAndProcess();
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});

    if (_controller.state == UploadState.done) {
      Future.microtask(() {
        if (mounted) {
          final refParam = widget.referenceKey != null
              ? '?ref=${widget.referenceKey}'
              : '';
          context.go('/evaluation/latest$refParam');
        }
      });
    }

    if (_controller.state == UploadState.idle) {
      // User cancelled the file picker — go back.
      Future.microtask(() {
        if (mounted) context.pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Video'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _controller.reset();
            context.pop();
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _buildBody(theme),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    switch (_controller.state) {
      case UploadState.idle:
      case UploadState.picking:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.upload_file, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            const Text('Select a video file...', style: TextStyle(fontSize: 18)),
          ],
        );

      case UploadState.processing:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Analyzing video...',
              style: TextStyle(
                fontSize: 18,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _controller.progress),
            const SizedBox(height: 12),
            Text(
              '${(_controller.progress * 100).round()}% '
              '(${_controller.frameCount} poses detected)',
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        );

      case UploadState.done:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('Processing complete!', style: TextStyle(fontSize: 18)),
          ],
        );

      case UploadState.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              _controller.errorMessage ?? 'Unknown error',
              style: const TextStyle(fontSize: 16, color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _controller.reset();
                _controller.pickAndProcess();
              },
              child: const Text('Try Again'),
            ),
          ],
        );
    }
  }
}
