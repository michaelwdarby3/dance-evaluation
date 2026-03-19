import '../constants/style_constants.dart';
import 'pose_sequence.dart';

/// A reference choreography that user performances are evaluated against.
class ReferenceChoreography {
  ReferenceChoreography({
    required this.id,
    required this.name,
    required this.style,
    required this.poses,
    List<PoseSequence>? personPoses,
    required this.bpm,
    required this.description,
    required this.difficulty,
    this.audioAsset,
    this.version = 1,
  }) : personPoses = personPoses ?? [poses];

  factory ReferenceChoreography.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int? ?? 1;

    List<PoseSequence> personPoses;
    PoseSequence primaryPoses;

    if (version >= 2 && json.containsKey('persons')) {
      // v2 multi-person format.
      personPoses = (json['persons'] as List)
          .map((p) => PoseSequence.fromJson(p as Map<String, dynamic>))
          .toList();
      if (personPoses.isEmpty) {
        throw FormatException('v2 reference has empty persons list');
      }
      primaryPoses = personPoses.first;
    } else {
      // v1 single-person format.
      primaryPoses =
          PoseSequence.fromJson(json['poses'] as Map<String, dynamic>);
      personPoses = [primaryPoses];
    }

    return ReferenceChoreography(
      id: json['id'] as String,
      name: json['name'] as String,
      style: DanceStyle.values.byName(json['style'] as String),
      poses: primaryPoses,
      personPoses: personPoses,
      bpm: (json['bpm'] as num).toDouble(),
      description: json['description'] as String,
      difficulty: json['difficulty'] as String,
      audioAsset: json['audio_asset'] as String?,
      version: version,
    );
  }

  /// Unique identifier for this choreography.
  final String id;

  /// Human-readable name (e.g. "Basic Hip Hop Groove 1").
  final String name;

  /// The dance style of this choreography.
  final DanceStyle style;

  /// The reference pose sequence (first person for backwards compat).
  final PoseSequence poses;

  /// All person pose sequences. For single-person, contains just [poses].
  final List<PoseSequence> personPoses;

  /// Beats per minute of the backing track.
  final double bpm;

  /// Optional path to an audio asset for playback.
  final String? audioAsset;

  /// Short description of the choreography.
  final String description;

  /// Difficulty level: "beginner", "intermediate", or "advanced".
  final String difficulty;

  /// JSON format version (1 = single-person, 2 = multi-person).
  final int version;

  /// Whether this is a multi-person choreography.
  bool get isMultiPerson => personPoses.length > 1;

  /// Number of persons in this choreography.
  int get personCount => personPoses.length;

  Map<String, dynamic> toJson() {
    if (isMultiPerson) {
      return {
        'version': 2,
        'id': id,
        'name': name,
        'style': style.name,
        'persons': personPoses.map((p) => p.toJson()).toList(),
        'bpm': bpm,
        'description': description,
        'difficulty': difficulty,
        'audio_asset': audioAsset,
      };
    }
    return {
      'id': id,
      'name': name,
      'style': style.name,
      'poses': poses.toJson(),
      'bpm': bpm,
      'description': description,
      'difficulty': difficulty,
      'audio_asset': audioAsset,
    };
  }

  @override
  String toString() =>
      'ReferenceChoreography(id: $id, name: $name, style: ${style.name}, '
      'persons: $personCount, frames: ${poses.frames.length}, '
      'bpm: $bpm, difficulty: $difficulty)';
}
