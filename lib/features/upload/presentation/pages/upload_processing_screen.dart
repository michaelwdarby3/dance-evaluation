import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dance_evaluation/core/constants/pose_constants.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';
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
            const Text('Select a video file...',
                style: TextStyle(fontSize: 18)),
          ],
        );

      case UploadState.processing:
        return _buildProcessingView(theme);

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

  Widget _buildProcessingView(ThemeData theme) {
    final eta = _controller.estimatedSecondsRemaining;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Skeleton preview
        Container(
          width: 200,
          height: 280,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: _controller.latestFrame != null
              ? CustomPaint(
                  painter: _SkeletonPreviewPainter(
                    frame: _controller.latestFrame!,
                    color: theme.colorScheme.primary,
                  ),
                )
              : Center(
                  child: Icon(
                    Icons.accessibility_new,
                    size: 48,
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
        ),
        const SizedBox(height: 24),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _controller.progress,
            minHeight: 8,
            backgroundColor:
                theme.colorScheme.primary.withValues(alpha: 0.15),
          ),
        ),
        const SizedBox(height: 16),

        // Status line
        Text(
          'Analyzing video...',
          style: TextStyle(
            fontSize: 18,
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),

        // Stats row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StatChip(
              icon: Icons.percent,
              label: '${(_controller.progress * 100).round()}%',
            ),
            const SizedBox(width: 16),
            _StatChip(
              icon: Icons.videocam,
              label: '${_controller.frameCount} frames',
            ),
            if (_controller.personsInLatestFrame > 0) ...[
              const SizedBox(width: 16),
              _StatChip(
                icon: Icons.people,
                label: '${_controller.personsInLatestFrame}',
              ),
            ],
          ],
        ),

        if (eta != null) ...[
          const SizedBox(height: 12),
          Text(
            _formatEta(eta),
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ],
    );
  }

  String _formatEta(double seconds) {
    if (seconds < 2) return 'Almost done...';
    if (seconds < 60) return '~${seconds.round()}s remaining';
    final minutes = (seconds / 60).floor();
    final secs = (seconds % 60).round();
    return '~${minutes}m ${secs}s remaining';
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.white70),
        ),
      ],
    );
  }
}

/// Draws a simple skeleton from a PoseFrame, centered in the available space.
class _SkeletonPreviewPainter extends CustomPainter {
  _SkeletonPreviewPainter({required this.frame, required this.color});

  final PoseFrame frame;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bonePaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final jointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Find bounding box of visible landmarks to center the skeleton.
    double minX = 1, maxX = 0, minY = 1, maxY = 0;
    int visible = 0;
    for (final lm in frame.landmarks) {
      if (lm.visibility <= 0.3) continue;
      visible++;
      if (lm.x < minX) minX = lm.x;
      if (lm.x > maxX) maxX = lm.x;
      if (lm.y < minY) minY = lm.y;
      if (lm.y > maxY) maxY = lm.y;
    }

    if (visible < 3) return;

    // Add padding and compute transform to fit skeleton in canvas.
    final rangeX = (maxX - minX).clamp(0.05, 1.0);
    final rangeY = (maxY - minY).clamp(0.05, 1.0);
    const padding = 20.0;
    final drawW = size.width - padding * 2;
    final drawH = size.height - padding * 2;
    final scale =
        (drawW / rangeX) < (drawH / rangeY) ? drawW / rangeX : drawH / rangeY;

    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;

    Offset toCanvas(Landmark lm) {
      final x = padding + (lm.x - centerX) * scale + drawW / 2;
      final y = padding + (lm.y - centerY) * scale + drawH / 2;
      return Offset(x, y);
    }

    // Draw bones.
    for (final (start, end) in PoseConstants.boneConnections) {
      final startLm = frame.landmarks[start];
      final endLm = frame.landmarks[end];
      if (startLm.visibility <= 0.3 || endLm.visibility <= 0.3) continue;
      canvas.drawLine(toCanvas(startLm), toCanvas(endLm), bonePaint);
    }

    // Draw joints.
    for (final lm in frame.landmarks) {
      if (lm.visibility <= 0.3) continue;
      canvas.drawCircle(toCanvas(lm), 4.0, jointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SkeletonPreviewPainter oldDelegate) =>
      !identical(oldDelegate.frame, frame);
}
