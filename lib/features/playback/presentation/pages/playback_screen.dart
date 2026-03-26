import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import 'package:dance_evaluation/core/constants/pose_constants.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/core/models/pose_sequence.dart';

/// Plays back the user's recorded performance with a skeleton overlay.
class PlaybackScreen extends StatefulWidget {
  const PlaybackScreen({
    super.key,
    required this.videoPath,
    required this.poseSequence,
  });

  final String videoPath;
  final PoseSequence poseSequence;

  @override
  State<PlaybackScreen> createState() => _PlaybackScreenState();
}

class _PlaybackScreenState extends State<PlaybackScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  String? _error;
  PoseFrame? _currentFrame;
  Timer? _overlayTimer;
  double _playbackSpeed = 1.0;
  static const _speeds = [0.25, 0.5, 1.0, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      if (kIsWeb || widget.videoPath.startsWith('blob:')) {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoPath),
        );
      } else {
        _controller = VideoPlayerController.file(File(widget.videoPath));
      }

      await _controller.initialize();
      _controller.addListener(_onPlayerUpdate);

      // Sync skeleton overlay at 15fps.
      _overlayTimer = Timer.periodic(
        const Duration(milliseconds: 67),
        (_) => _syncOverlay(),
      );

      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not load video: $e');
      }
    }
  }

  void _onPlayerUpdate() {
    if (mounted) setState(() {});
  }

  void _syncOverlay() {
    if (!_controller.value.isPlaying) return;
    final position = _controller.value.position;
    final frame = _frameAtTime(position);
    if (frame != _currentFrame) {
      setState(() => _currentFrame = frame);
    }
  }

  PoseFrame? _frameAtTime(Duration time) {
    final frames = widget.poseSequence.frames;
    if (frames.isEmpty) return null;

    final targetMs = time.inMilliseconds;
    final durationMs = widget.poseSequence.duration.inMilliseconds;
    if (durationMs > 0 && targetMs >= durationMs) return frames.last;

    // Binary search.
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
  void dispose() {
    _overlayTimer?.cancel();
    _controller.removeListener(_onPlayerUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Playback')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (!_initialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Playback')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final videoSize = _controller.value.size;
    final aspectRatio =
        videoSize.width > 0 ? videoSize.width / videoSize.height : 16 / 9;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Your Performance'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Video + skeleton overlay.
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(_controller),
                    if (_currentFrame != null)
                      CustomPaint(
                        painter: _PlaybackSkeletonPainter(
                          frame: _currentFrame!,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Playback controls.
          _buildSpeedSelector(),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildSpeedSelector() {
    return Container(
      color: const Color(0xFF1E1E2C),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _speeds.map((speed) {
          final isSelected = _playbackSpeed == speed;
          final label = speed == 1.0 ? '1x' : '${speed}x';
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _playbackSpeed = speed);
                _controller.setPlaybackSpeed(speed);
              },
              labelStyle: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.black87 : Colors.white70,
              ),
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildControls() {
    final position = _controller.value.position;
    final duration = _controller.value.duration;
    final isPlaying = _controller.value.isPlaying;

    final posStr = _formatDuration(position);
    final durStr = _formatDuration(duration);

    return Container(
      color: const Color(0xFF1E1E2C),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Seek bar.
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                ),
                activeTrackColor: const Color(0xFF7C4DFF),
                inactiveTrackColor: Colors.white12,
                thumbColor: const Color(0xFF7C4DFF),
                overlayColor:
                    const Color(0xFF7C4DFF).withValues(alpha: 0.2),
              ),
              child: Slider(
                value: duration.inMilliseconds > 0
                    ? position.inMilliseconds /
                        duration.inMilliseconds
                    : 0,
                onChanged: (v) {
                  final newPos = Duration(
                    milliseconds:
                        (v * duration.inMilliseconds).round(),
                  );
                  _controller.seekTo(newPos);
                  _syncOverlay();
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  posStr,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.replay_10),
                      color: Colors.white70,
                      onPressed: () {
                        final newPos = position - const Duration(seconds: 10);
                        _controller.seekTo(
                          newPos < Duration.zero ? Duration.zero : newPos,
                        );
                      },
                    ),
                    IconButton(
                      iconSize: 48,
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                      ),
                      color: const Color(0xFF7C4DFF),
                      onPressed: () {
                        if (isPlaying) {
                          _controller.pause();
                        } else {
                          _controller.play();
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.forward_10),
                      color: Colors.white70,
                      onPressed: () {
                        final newPos = position + const Duration(seconds: 10);
                        _controller.seekTo(
                          newPos > duration ? duration : newPos,
                        );
                      },
                    ),
                  ],
                ),
                Text(
                  durStr,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// Paints the skeleton overlay on the playback video.
class _PlaybackSkeletonPainter extends CustomPainter {
  _PlaybackSkeletonPainter({required this.frame});

  final PoseFrame frame;

  @override
  void paint(Canvas canvas, Size size) {
    final bonePaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final jointPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    // Draw bones.
    for (final (start, end) in PoseConstants.boneConnections) {
      if (start >= frame.landmarks.length ||
          end >= frame.landmarks.length) {
        continue;
      }
      final startLm = frame.landmarks[start];
      final endLm = frame.landmarks[end];
      if (startLm.visibility <= 0.3 || endLm.visibility <= 0.3) continue;

      canvas.drawLine(
        Offset(startLm.x * size.width, startLm.y * size.height),
        Offset(endLm.x * size.width, endLm.y * size.height),
        bonePaint,
      );
    }

    // Draw joints.
    for (final lm in frame.landmarks) {
      if (lm.visibility <= 0.3) continue;
      canvas.drawCircle(
        Offset(lm.x * size.width, lm.y * size.height),
        3.5,
        jointPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PlaybackSkeletonPainter oldDelegate) =>
      oldDelegate.frame != frame;
}
