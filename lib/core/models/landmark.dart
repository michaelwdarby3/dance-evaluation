/// A single 3-D pose landmark with normalised coordinates and confidence.
class Landmark {
  const Landmark({
    required this.x,
    required this.y,
    required this.z,
    this.visibility = 0.0,
  });

  /// Normalised x coordinate (0.0 - 1.0 relative to image width).
  final double x;

  /// Normalised y coordinate (0.0 - 1.0 relative to image height).
  final double y;

  /// Depth value from the pose model.
  final double z;

  /// Confidence score for this landmark (0.0 - 1.0).
  final double visibility;

  Landmark copyWith({
    double? x,
    double? y,
    double? z,
    double? visibility,
  }) {
    return Landmark(
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      visibility: visibility ?? this.visibility,
    );
  }

  @override
  String toString() =>
      'Landmark(x: ${x.toStringAsFixed(3)}, y: ${y.toStringAsFixed(3)}, '
      'z: ${z.toStringAsFixed(3)}, visibility: ${visibility.toStringAsFixed(2)})';
}
