/// Constants for MediaPipe BlazePose landmark indices, bone connections,
/// and key joint angle definitions.
class PoseConstants {
  PoseConstants._();

  /// Total number of landmarks in the BlazePose model.
  static const int landmarkCount = 33;

  // ---------------------------------------------------------------------------
  // Named landmark indices (BlazePose 33-point topology)
  // ---------------------------------------------------------------------------
  static const int nose = 0;
  static const int leftEyeInner = 1;
  static const int leftEye = 2;
  static const int leftEyeOuter = 3;
  static const int rightEyeInner = 4;
  static const int rightEye = 5;
  static const int rightEyeOuter = 6;
  static const int leftEar = 7;
  static const int rightEar = 8;
  static const int mouthLeft = 9;
  static const int mouthRight = 10;
  static const int leftShoulder = 11;
  static const int rightShoulder = 12;
  static const int leftElbow = 13;
  static const int rightElbow = 14;
  static const int leftWrist = 15;
  static const int rightWrist = 16;
  static const int leftPinky = 17;
  static const int rightPinky = 18;
  static const int leftIndex = 19;
  static const int rightIndex = 20;
  static const int leftThumb = 21;
  static const int rightThumb = 22;
  static const int leftHip = 23;
  static const int rightHip = 24;
  static const int leftKnee = 25;
  static const int rightKnee = 26;
  static const int leftAnkle = 27;
  static const int rightAnkle = 28;
  static const int leftHeel = 29;
  static const int rightHeel = 30;
  static const int leftFootIndex = 31;
  static const int rightFootIndex = 32;

  // ---------------------------------------------------------------------------
  // Bone connections for skeleton drawing
  // Each pair is (startLandmark, endLandmark).
  // ---------------------------------------------------------------------------
  static const List<(int, int)> boneConnections = [
    // Face
    (nose, leftEyeInner),
    (leftEyeInner, leftEye),
    (leftEye, leftEyeOuter),
    (leftEyeOuter, leftEar),
    (nose, rightEyeInner),
    (rightEyeInner, rightEye),
    (rightEye, rightEyeOuter),
    (rightEyeOuter, rightEar),
    (mouthLeft, mouthRight),

    // Torso
    (leftShoulder, rightShoulder),
    (leftShoulder, leftHip),
    (rightShoulder, rightHip),
    (leftHip, rightHip),

    // Left arm
    (leftShoulder, leftElbow),
    (leftElbow, leftWrist),
    (leftWrist, leftPinky),
    (leftWrist, leftIndex),
    (leftWrist, leftThumb),
    (leftIndex, leftPinky),

    // Right arm
    (rightShoulder, rightElbow),
    (rightElbow, rightWrist),
    (rightWrist, rightPinky),
    (rightWrist, rightIndex),
    (rightWrist, rightThumb),
    (rightIndex, rightPinky),

    // Left leg
    (leftHip, leftKnee),
    (leftKnee, leftAnkle),
    (leftAnkle, leftHeel),
    (leftAnkle, leftFootIndex),
    (leftHeel, leftFootIndex),

    // Right leg
    (rightHip, rightKnee),
    (rightKnee, rightAnkle),
    (rightAnkle, rightHeel),
    (rightAnkle, rightFootIndex),
    (rightHeel, rightFootIndex),
  ];

  // ---------------------------------------------------------------------------
  // Key joints: maps a human-readable joint name to the three landmark indices
  // that define the angle (vertex is the middle index).
  // ---------------------------------------------------------------------------
  static const Map<String, List<int>> keyJoints = {
    'leftElbow': [leftShoulder, leftElbow, leftWrist],
    'rightElbow': [rightShoulder, rightElbow, rightWrist],
    'leftShoulder': [leftElbow, leftShoulder, leftHip],
    'rightShoulder': [rightElbow, rightShoulder, rightHip],
    'leftHip': [leftShoulder, leftHip, leftKnee],
    'rightHip': [rightShoulder, rightHip, rightKnee],
    'leftKnee': [leftHip, leftKnee, leftAnkle],
    'rightKnee': [rightHip, rightKnee, rightAnkle],
    'leftAnkle': [leftKnee, leftAnkle, leftFootIndex],
    'rightAnkle': [rightKnee, rightAnkle, rightFootIndex],
  };
}
