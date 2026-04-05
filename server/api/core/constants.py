"""BlazePose landmark indices, key joints, and style weight profiles.

Ported from:
  lib/core/constants/pose_constants.dart
  lib/core/constants/style_constants.dart
"""

LANDMARK_COUNT = 33

# Named landmark indices (BlazePose 33-point topology)
NOSE = 0
LEFT_EYE_INNER = 1
LEFT_EYE = 2
LEFT_EYE_OUTER = 3
RIGHT_EYE_INNER = 4
RIGHT_EYE = 5
RIGHT_EYE_OUTER = 6
LEFT_EAR = 7
RIGHT_EAR = 8
MOUTH_LEFT = 9
MOUTH_RIGHT = 10
LEFT_SHOULDER = 11
RIGHT_SHOULDER = 12
LEFT_ELBOW = 13
RIGHT_ELBOW = 14
LEFT_WRIST = 15
RIGHT_WRIST = 16
LEFT_PINKY = 17
RIGHT_PINKY = 18
LEFT_INDEX = 19
RIGHT_INDEX = 20
LEFT_THUMB = 21
RIGHT_THUMB = 22
LEFT_HIP = 23
RIGHT_HIP = 24
LEFT_KNEE = 25
RIGHT_KNEE = 26
LEFT_ANKLE = 27
RIGHT_ANKLE = 28
LEFT_HEEL = 29
RIGHT_HEEL = 30
LEFT_FOOT_INDEX = 31
RIGHT_FOOT_INDEX = 32

# Key joints: maps joint name -> (a, b, c) landmark indices.
# The angle is measured at vertex b.
KEY_JOINTS: dict[str, list[int]] = {
    "leftElbow": [LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST],
    "rightElbow": [RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST],
    "leftShoulder": [LEFT_ELBOW, LEFT_SHOULDER, LEFT_HIP],
    "rightShoulder": [RIGHT_ELBOW, RIGHT_SHOULDER, RIGHT_HIP],
    "leftHip": [LEFT_SHOULDER, LEFT_HIP, LEFT_KNEE],
    "rightHip": [RIGHT_SHOULDER, RIGHT_HIP, RIGHT_KNEE],
    "leftKnee": [LEFT_HIP, LEFT_KNEE, LEFT_ANKLE],
    "rightKnee": [RIGHT_HIP, RIGHT_KNEE, RIGHT_ANKLE],
    "leftAnkle": [LEFT_KNEE, LEFT_ANKLE, LEFT_FOOT_INDEX],
    "rightAnkle": [RIGHT_KNEE, RIGHT_ANKLE, RIGHT_FOOT_INDEX],
}

# Evaluation dimensions
DIMENSIONS = ("timing", "technique", "expression", "spatialAwareness")

# Style weight profiles: style -> {dimension: weight}
# Weights sum to 1.0 per style.
STYLE_WEIGHTS: dict[str, dict[str, float]] = {
    "hipHop": {
        "timing": 0.30,
        "technique": 0.30,
        "expression": 0.20,
        "spatialAwareness": 0.20,
    },
    "kPop": {
        "timing": 0.25,
        "technique": 0.35,
        "expression": 0.15,
        "spatialAwareness": 0.25,
    },
    "contemporary": {
        "timing": 0.20,
        "technique": 0.25,
        "expression": 0.35,
        "spatialAwareness": 0.20,
    },
    "freestyle": {
        "timing": 0.25,
        "technique": 0.25,
        "expression": 0.25,
        "spatialAwareness": 0.25,
    },
}
