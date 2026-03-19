import 'pose_sequence.dart';

/// An ordered collection of [PoseSequence]s — one per tracked person.
class MultiPoseSequence {
  const MultiPoseSequence({
    required this.personSequences,
    required this.fps,
    required this.duration,
  });

  /// One [PoseSequence] per tracked person, indexed by person ID.
  final List<PoseSequence> personSequences;

  /// Frames per second of the source.
  final double fps;

  /// Total duration.
  final Duration duration;

  /// Number of tracked persons.
  int get personCount => personSequences.length;

  /// Creates a [MultiPoseSequence] wrapping a single [PoseSequence].
  factory MultiPoseSequence.fromSingle(PoseSequence sequence) =>
      MultiPoseSequence(
        personSequences: [sequence],
        fps: sequence.fps,
        duration: sequence.duration,
      );

  Map<String, dynamic> toJson() => {
        'fps': fps,
        'duration_ms': duration.inMilliseconds,
        'persons': personSequences.map((s) => s.toJson()).toList(),
      };

  factory MultiPoseSequence.fromJson(Map<String, dynamic> json) =>
      MultiPoseSequence(
        fps: (json['fps'] as num).toDouble(),
        duration: Duration(milliseconds: json['duration_ms'] as int),
        personSequences: (json['persons'] as List)
            .map((s) => PoseSequence.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  @override
  String toString() =>
      'MultiPoseSequence(persons: $personCount, fps: $fps, duration: $duration)';
}
