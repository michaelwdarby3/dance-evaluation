import 'pose_frame.dart';

/// A single frame containing pose data for multiple detected persons.
class MultiPoseFrame {
  const MultiPoseFrame({
    required this.timestamp,
    required this.persons,
  });

  /// Elapsed time from the start of the sequence.
  final Duration timestamp;

  /// One [PoseFrame] per detected person.
  final List<PoseFrame> persons;

  /// Number of persons detected in this frame.
  int get personCount => persons.length;

  /// Creates a [MultiPoseFrame] from a single-person [PoseFrame].
  factory MultiPoseFrame.fromSingle(PoseFrame frame) => MultiPoseFrame(
        timestamp: frame.timestamp,
        persons: [frame],
      );

  Map<String, dynamic> toJson() => {
        'ts': timestamp.inMilliseconds,
        'persons': persons.map((p) => p.toJson()).toList(),
      };

  factory MultiPoseFrame.fromJson(Map<String, dynamic> json) =>
      MultiPoseFrame(
        timestamp: Duration(milliseconds: json['ts'] as int),
        persons: (json['persons'] as List)
            .map((p) => PoseFrame.fromJson(p as Map<String, dynamic>))
            .toList(),
      );

  @override
  String toString() =>
      'MultiPoseFrame(timestamp: $timestamp, persons: $personCount)';
}
