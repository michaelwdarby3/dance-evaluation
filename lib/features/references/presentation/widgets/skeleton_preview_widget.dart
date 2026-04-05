import 'package:flutter/material.dart';

import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/core/models/pose_sequence.dart';

/// Body-only bone connections (indices 11-32, skipping face landmarks 0-10).
const _previewBones = <(int, int)>[
  // Torso
  (11, 12), // shoulders
  (11, 23), // left shoulder → left hip
  (12, 24), // right shoulder → right hip
  (23, 24), // hips
  // Left arm
  (11, 13), // shoulder → elbow
  (13, 15), // elbow → wrist
  // Right arm
  (12, 14), // shoulder → elbow
  (14, 16), // elbow → wrist
  // Left leg
  (23, 25), // hip → knee
  (25, 27), // knee → ankle
  (27, 31), // ankle → foot
  // Right leg
  (24, 26), // hip → knee
  (26, 28), // knee → ankle
  (28, 32), // ankle → foot
];

/// Animated skeleton preview that loops a [PoseSequence].
///
/// Tapping the preview opens a fullscreen dialog with play/pause controls.
class SkeletonPreviewWidget extends StatefulWidget {
  const SkeletonPreviewWidget({
    super.key,
    required this.poses,
    this.size = const Size(56, 56),
    this.label,
    this.mirror = false,
  });

  final PoseSequence poses;
  final Size size;

  /// Optional label shown in the fullscreen view (e.g. reference name).
  final String? label;

  /// Mirror the skeleton horizontally.
  final bool mirror;

  @override
  State<SkeletonPreviewWidget> createState() => _SkeletonPreviewWidgetState();
}

class _SkeletonPreviewWidgetState extends State<SkeletonPreviewWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final durationMs = widget.poses.duration.inMilliseconds;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs > 0 ? durationMs : 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openFullscreen() {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (_) => SkeletonFullscreenDialog(
        poses: widget.poses,
        label: widget.label,
        mirror: widget.mirror,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openFullscreen,
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: widget.size.width,
            height: widget.size.height,
            color: const Color(0xFF1A1A2E),
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final elapsed = Duration(
                      milliseconds: (_controller.value *
                              widget.poses.duration.inMilliseconds)
                          .round(),
                    );
                    return CustomPaint(
                      size: widget.size,
                      painter: _SkeletonPreviewPainter(
                        sequence: widget.poses,
                        elapsed: elapsed,
                        mirror: widget.mirror,
                      ),
                    );
                  },
                ),
                const Positioned(
                  right: 2,
                  bottom: 2,
                  child: Icon(
                    Icons.fullscreen,
                    size: 14,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fullscreen dialog for skeleton animation with play/pause and scrub bar.
class SkeletonFullscreenDialog extends StatefulWidget {
  const SkeletonFullscreenDialog({
    super.key,
    required this.poses,
    this.label,
    this.mirror = false,
  });

  final PoseSequence poses;
  final String? label;
  final bool mirror;

  @override
  State<SkeletonFullscreenDialog> createState() =>
      _SkeletonFullscreenDialogState();
}

class _SkeletonFullscreenDialogState extends State<SkeletonFullscreenDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _playing = true;

  @override
  void initState() {
    super.initState();
    final durationMs = widget.poses.duration.inMilliseconds;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs > 0 ? durationMs : 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    setState(() {
      if (_playing) {
        _controller.stop();
      } else {
        _controller.repeat();
      }
      _playing = !_playing;
    });
  }

  String _formatDuration(Duration d) {
    final s = d.inMilliseconds / 1000;
    return s.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final durationMs = widget.poses.duration.inMilliseconds;

    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF0D0D1A),
      child: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                  if (widget.label != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.label!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    const Spacer(),
                ],
              ),
            ),
            // Skeleton animation (expanded to fill)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Keep square aspect ratio, centered
                    final side = constraints.biggest.shortestSide;
                    final canvasSize = Size(side, side);
                    return Center(
                      child: RepaintBoundary(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: canvasSize.width,
                            height: canvasSize.height,
                            color: const Color(0xFF1A1A2E),
                            child: AnimatedBuilder(
                              animation: _controller,
                              builder: (context, _) {
                                final elapsed = Duration(
                                  milliseconds:
                                      (_controller.value * durationMs).round(),
                                );
                                return CustomPaint(
                                  size: canvasSize,
                                  painter: _SkeletonPreviewPainter(
                                    sequence: widget.poses,
                                    elapsed: elapsed,
                                    boneWidth: 3.0,
                                    jointRadius: 5.0,
                                    mirror: widget.mirror,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress bar
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              activeTrackColor: const Color(0xFFBB86FC),
                              inactiveTrackColor: Colors.white12,
                              thumbColor: const Color(0xFFBB86FC),
                              overlayColor:
                                  const Color(0xFFBB86FC).withValues(alpha: 0.2),
                            ),
                            child: Slider(
                              value: _controller.value,
                              onChanged: (v) {
                                _controller.value = v;
                                if (_playing) {
                                  _controller.stop();
                                  setState(() => _playing = false);
                                }
                              },
                              onChangeEnd: (v) {
                                if (!_playing) {
                                  _controller.repeat();
                                  setState(() => _playing = true);
                                }
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(Duration(
                                    milliseconds:
                                        (_controller.value * durationMs)
                                            .round(),
                                  )),
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  _formatDuration(widget.poses.duration),
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  // Play/pause
                  IconButton(
                    iconSize: 48,
                    icon: Icon(
                      _playing ? Icons.pause_circle : Icons.play_circle,
                      color: const Color(0xFFBB86FC),
                    ),
                    onPressed: _togglePlayback,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonPreviewPainter extends CustomPainter {
  _SkeletonPreviewPainter({
    required this.sequence,
    required this.elapsed,
    this.boneWidth = 1.5,
    this.jointRadius = 2.0,
    this.mirror = false,
  });

  final PoseSequence sequence;
  final Duration elapsed;
  final double boneWidth;
  final double jointRadius;
  final bool mirror;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = _frameAtTime(elapsed);
    if (frame == null) return;

    final bonePaint = Paint()
      ..color = const Color(0xFFBB86FC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = boneWidth
      ..strokeCap = StrokeCap.round;

    final jointPaint = Paint()
      ..color = const Color(0xFFCE93D8)
      ..style = PaintingStyle.fill;

    // Draw bones.
    for (final (start, end) in _previewBones) {
      if (start >= frame.landmarks.length || end >= frame.landmarks.length) {
        continue;
      }
      final startLm = frame.landmarks[start];
      final endLm = frame.landmarks[end];
      if (startLm.visibility <= 0.3 || endLm.visibility <= 0.3) continue;

      canvas.drawLine(
        _toCanvas(startLm, size),
        _toCanvas(endLm, size),
        bonePaint,
      );
    }

    // Draw joints (body landmarks only: 11-32).
    for (var i = 11; i < frame.landmarks.length; i++) {
      final lm = frame.landmarks[i];
      if (lm.visibility <= 0.3) continue;
      canvas.drawCircle(_toCanvas(lm, size), jointRadius, jointPaint);
    }
  }

  Offset _toCanvas(Landmark lm, Size size) {
    final x = mirror ? (1.0 - lm.x) * size.width : lm.x * size.width;
    return Offset(x, lm.y * size.height);
  }

  PoseFrame? _frameAtTime(Duration time) {
    final frames = sequence.frames;
    if (frames.isEmpty) return null;

    final targetMs = time.inMilliseconds;
    final durationMs = sequence.duration.inMilliseconds;
    if (durationMs > 0 && targetMs >= durationMs) return frames.last;

    int lo = 0, hi = frames.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (frames[mid].timestamp.inMilliseconds < targetMs) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }

    if (lo > 0) {
      final prevDiff =
          (frames[lo - 1].timestamp.inMilliseconds - targetMs).abs();
      final currDiff =
          (frames[lo].timestamp.inMilliseconds - targetMs).abs();
      if (prevDiff < currDiff) return frames[lo - 1];
    }

    return frames[lo];
  }

  @override
  bool shouldRepaint(covariant _SkeletonPreviewPainter oldDelegate) =>
      oldDelegate.elapsed != elapsed || oldDelegate.mirror != mirror;
}
