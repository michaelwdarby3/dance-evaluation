"""Pose math utilities — normalization, distance, similarity, angles.

Ported from lib/core/utils/pose_math.dart.

Frames are numpy arrays of shape (33, 4) with columns [x, y, z, visibility].
"""

import math

import numpy as np

from .constants import LEFT_HIP, LEFT_SHOULDER, RIGHT_HIP, RIGHT_SHOULDER


def normalize_pose(frame: np.ndarray) -> np.ndarray:
    """Center on hip midpoint and scale so torso height = 1.0.

    Args:
        frame: (33, 4) array — columns x, y, z, visibility.

    Returns:
        Normalized copy with same shape.
    """
    lh = frame[LEFT_HIP, :3]
    rh = frame[RIGHT_HIP, :3]
    mid_hip = (lh + rh) / 2.0

    ls = frame[LEFT_SHOULDER, :3]
    rs = frame[RIGHT_SHOULDER, :3]
    mid_shoulder = (ls + rs) / 2.0

    torso_height = float(np.linalg.norm(mid_shoulder - mid_hip))
    if torso_height == 0:
        torso_height = 1.0

    out = frame.copy()
    out[:, :3] = (frame[:, :3] - mid_hip) / torso_height
    return out


def pose_distance(a: np.ndarray, b: np.ndarray) -> float:
    """Sum of per-landmark Euclidean distances between two (33, 4) frames."""
    diff = a[:, :3] - b[:, :3]
    return float(np.sum(np.sqrt(np.sum(diff * diff, axis=1))))


def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    """Cosine similarity between two 1-D vectors. Returns 0 if either is zero."""
    dot = float(np.dot(a, b))
    mag_a = float(np.linalg.norm(a))
    mag_b = float(np.linalg.norm(b))
    if mag_a == 0 or mag_b == 0:
        return 0.0
    return dot / (mag_a * mag_b)


def pose_to_vector(frame: np.ndarray) -> np.ndarray:
    """Flatten (33, 4) frame to 1-D vector of [x1, y1, z1, x2, ...] (99 elements)."""
    return frame[:, :3].ravel()


def angle_between(frame: np.ndarray, a_idx: int, b_idx: int, c_idx: int) -> float:
    """Angle in degrees at vertex b formed by segments a-b and b-c."""
    a = frame[a_idx, :3]
    b = frame[b_idx, :3]
    c = frame[c_idx, :3]

    ba = a - b
    bc = c - b

    cross = np.cross(ba, bc)
    cross_mag = float(np.linalg.norm(cross))
    dot = float(np.dot(ba, bc))

    return math.degrees(math.atan2(cross_mag, dot))
