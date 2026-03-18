import '../constants/style_constants.dart';
import 'pose_sequence.dart';

/// A reference choreography that user performances are evaluated against.
class ReferenceChoreography {
  const ReferenceChoreography({
    required this.id,
    required this.name,
    required this.style,
    required this.poses,
    required this.bpm,
    required this.description,
    required this.difficulty,
    this.audioAsset,
  });

  /// Unique identifier for this choreography.
  final String id;

  /// Human-readable name (e.g. "Basic Hip Hop Groove 1").
  final String name;

  /// The dance style of this choreography.
  final DanceStyle style;

  /// The reference pose sequence.
  final PoseSequence poses;

  /// Beats per minute of the backing track.
  final double bpm;

  /// Optional path to an audio asset for playback.
  final String? audioAsset;

  /// Short description of the choreography.
  final String description;

  /// Difficulty level: "beginner", "intermediate", or "advanced".
  final String difficulty;

  @override
  String toString() =>
      'ReferenceChoreography(id: $id, name: $name, style: ${style.name}, '
      'frames: ${poses.frames.length}, bpm: $bpm, difficulty: $difficulty)';
}
