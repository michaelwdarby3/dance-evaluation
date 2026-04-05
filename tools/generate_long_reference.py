#!/usr/bin/env python3
"""Generate longer reference choreographies (15+ seconds) using keyframe
interpolation with cubic splines.

Usage:
    python generate_long_reference.py

Outputs JSON files in the v1 reference format to assets/references/.
Requires: numpy, scipy
"""

import json
import math
import os
from pathlib import Path

import numpy as np
from scipy.interpolate import CubicSpline

# BlazePose 33-landmark layout (index reference)
# 0-10: face, 11-12: shoulders, 13-14: elbows, 15-16: wrists,
# 17-22: hands, 23-24: hips, 25-26: knees, 27-28: ankles,
# 29-30: heels, 31-32: foot indices

FPS = 15
OUTPUT_DIR = Path(__file__).parent.parent / "assets" / "references"


def standing_neutral():
    """Neutral standing pose — all 33 landmarks."""
    return [
        # 0: nose
        (0.500, 0.180, 0.00, 0.95),
        # 1-6: eyes
        (0.490, 0.160, 0.00, 0.95),
        (0.475, 0.160, 0.00, 0.95),
        (0.460, 0.160, 0.00, 0.95),
        (0.510, 0.160, 0.00, 0.95),
        (0.525, 0.160, 0.00, 0.95),
        (0.540, 0.160, 0.00, 0.95),
        # 7-8: ears
        (0.440, 0.170, 0.00, 0.95),
        (0.560, 0.170, 0.00, 0.95),
        # 9-10: mouth
        (0.480, 0.210, 0.00, 0.95),
        (0.520, 0.210, 0.00, 0.95),
        # 11: left shoulder, 12: right shoulder
        (0.420, 0.280, 0.00, 0.95),
        (0.580, 0.280, 0.00, 0.95),
        # 13: left elbow, 14: right elbow
        (0.400, 0.420, 0.00, 0.95),
        (0.600, 0.420, 0.00, 0.95),
        # 15: left wrist, 16: right wrist
        (0.410, 0.550, 0.00, 0.95),
        (0.590, 0.550, 0.00, 0.95),
        # 17-18: pinkies
        (0.405, 0.570, 0.00, 0.95),
        (0.595, 0.570, 0.00, 0.95),
        # 19-20: index fingers
        (0.415, 0.575, 0.00, 0.95),
        (0.585, 0.575, 0.00, 0.95),
        # 21-22: thumbs
        (0.420, 0.560, 0.00, 0.95),
        (0.580, 0.560, 0.00, 0.95),
        # 23: left hip, 24: right hip
        (0.460, 0.530, 0.00, 0.95),
        (0.540, 0.530, 0.00, 0.95),
        # 25: left knee, 26: right knee
        (0.455, 0.700, 0.00, 0.95),
        (0.545, 0.700, 0.00, 0.95),
        # 27: left ankle, 28: right ankle
        (0.450, 0.870, 0.00, 0.95),
        (0.550, 0.870, 0.00, 0.95),
        # 29: left heel, 30: right heel
        (0.445, 0.885, 0.00, 0.95),
        (0.555, 0.885, 0.00, 0.95),
        # 31: left foot index, 32: right foot index
        (0.455, 0.895, 0.00, 0.95),
        (0.545, 0.895, 0.00, 0.95),
    ]


def apply_offsets(base, offsets):
    """Apply a dict of {landmark_index: (dx, dy, dz)} offsets to a base pose."""
    pose = [list(lm) for lm in base]
    for idx, (dx, dy, dz) in offsets.items():
        pose[idx][0] += dx
        pose[idx][1] += dy
        pose[idx][2] += dz
    return [tuple(lm) for lm in pose]


# ---------------------------------------------------------------------------
# Hip Hop Extended Groove — keyframes
# ---------------------------------------------------------------------------

def hip_hop_extended_keyframes():
    """Return (times, poses) for a ~16s hip hop routine."""
    base = standing_neutral()
    keyframes = []
    times = []

    # Beat 0.0s — neutral stance, slight bounce
    times.append(0.0)
    keyframes.append(base)

    # Beat 1.0s — step right, arms bent at sides
    times.append(1.0)
    keyframes.append(apply_offsets(base, {
        0: (0.04, 0.01, 0), 7: (0.04, 0, 0), 8: (0.04, 0, 0),
        9: (0.04, 0, 0), 10: (0.04, 0, 0),
        1: (0.04, 0, 0), 2: (0.04, 0, 0), 3: (0.04, 0, 0),
        4: (0.04, 0, 0), 5: (0.04, 0, 0), 6: (0.04, 0, 0),
        11: (0.04, 0, 0), 12: (0.04, 0, 0),
        13: (0.03, -0.08, 0), 14: (0.05, -0.08, 0),
        15: (0.04, -0.02, 0), 16: (0.04, -0.02, 0),
        17: (0.04, -0.02, 0), 18: (0.04, -0.02, 0),
        19: (0.04, -0.02, 0), 20: (0.04, -0.02, 0),
        21: (0.04, -0.02, 0), 22: (0.04, -0.02, 0),
        23: (0.04, 0, 0), 24: (0.04, 0, 0),
        25: (0.06, 0, 0), 26: (0.02, 0, 0),
        27: (0.08, 0, 0), 28: (0.0, 0, 0),
        29: (0.08, 0, 0), 30: (0.0, 0, 0),
        31: (0.08, 0, 0), 32: (0.0, 0, 0),
    }))

    # Beat 2.0s — arms up V shape
    times.append(2.0)
    keyframes.append(apply_offsets(base, {
        11: (0.0, 0, 0), 12: (0.0, 0, 0),
        13: (-0.04, -0.15, 0), 14: (0.04, -0.15, 0),
        15: (-0.08, -0.28, 0), 16: (0.08, -0.28, 0),
        17: (-0.085, -0.30, 0), 18: (0.085, -0.30, 0),
        19: (-0.075, -0.30, 0), 20: (0.075, -0.30, 0),
        21: (-0.07, -0.29, 0), 22: (0.07, -0.29, 0),
        23: (0, 0.02, 0), 24: (0, 0.02, 0),
        25: (0, 0.02, 0), 26: (0, 0.02, 0),
    }))

    # Beat 3.5s — body roll (lean forward, lower torso)
    times.append(3.5)
    keyframes.append(apply_offsets(base, {
        0: (0, 0.04, 0.03),
        11: (0, 0.03, 0.02), 12: (0, 0.03, 0.02),
        13: (0.02, -0.04, 0), 14: (-0.02, -0.04, 0),
        15: (0.04, 0.02, 0), 16: (-0.04, 0.02, 0),
        17: (0.04, 0.03, 0), 18: (-0.04, 0.03, 0),
        19: (0.04, 0.03, 0), 20: (-0.04, 0.03, 0),
        21: (0.04, 0.02, 0), 22: (-0.04, 0.02, 0),
        23: (0, 0.04, 0), 24: (0, 0.04, 0),
        25: (0, 0.02, 0), 26: (0, 0.02, 0),
    }))

    # Beat 5.0s — step left, arms crossed at chest
    times.append(5.0)
    keyframes.append(apply_offsets(base, {
        0: (-0.04, 0, 0),
        1: (-0.04, 0, 0), 2: (-0.04, 0, 0), 3: (-0.04, 0, 0),
        4: (-0.04, 0, 0), 5: (-0.04, 0, 0), 6: (-0.04, 0, 0),
        7: (-0.04, 0, 0), 8: (-0.04, 0, 0),
        9: (-0.04, 0, 0), 10: (-0.04, 0, 0),
        11: (-0.04, 0, 0), 12: (-0.04, 0, 0),
        13: (-0.01, -0.10, 0.04), 14: (-0.07, -0.10, 0.04),
        15: (0.02, -0.10, 0.05), 16: (-0.10, -0.10, 0.05),
        17: (0.02, -0.10, 0.05), 18: (-0.10, -0.10, 0.05),
        19: (0.02, -0.10, 0.05), 20: (-0.10, -0.10, 0.05),
        21: (0.02, -0.10, 0.05), 22: (-0.10, -0.10, 0.05),
        23: (-0.04, 0, 0), 24: (-0.04, 0, 0),
        25: (-0.06, 0, 0), 26: (-0.02, 0, 0),
        27: (-0.08, 0, 0), 28: (0, 0, 0),
        29: (-0.08, 0, 0), 30: (0, 0, 0),
        31: (-0.08, 0, 0), 32: (0, 0, 0),
    }))

    # Beat 6.5s — freeze pose (wide stance, arms out)
    times.append(6.5)
    keyframes.append(apply_offsets(base, {
        11: (-0.02, 0, 0), 12: (0.02, 0, 0),
        13: (-0.10, -0.06, 0), 14: (0.10, -0.06, 0),
        15: (-0.16, -0.06, 0), 16: (0.16, -0.06, 0),
        17: (-0.165, -0.06, 0), 18: (0.165, -0.06, 0),
        19: (-0.155, -0.06, 0), 20: (0.155, -0.06, 0),
        21: (-0.15, -0.06, 0), 22: (0.15, -0.06, 0),
        23: (-0.03, 0, 0), 24: (0.03, 0, 0),
        25: (-0.05, 0, 0), 26: (0.05, 0, 0),
        27: (-0.06, 0, 0), 28: (0.06, 0, 0),
        29: (-0.06, 0, 0), 30: (0.06, 0, 0),
        31: (-0.06, 0, 0), 32: (0.06, 0, 0),
    }))

    # Beat 8.0s — bounce down (knees bent, arms at sides)
    times.append(8.0)
    keyframes.append(apply_offsets(base, {
        0: (0, 0.06, 0),
        1: (0, 0.06, 0), 2: (0, 0.06, 0), 3: (0, 0.06, 0),
        4: (0, 0.06, 0), 5: (0, 0.06, 0), 6: (0, 0.06, 0),
        7: (0, 0.06, 0), 8: (0, 0.06, 0),
        9: (0, 0.06, 0), 10: (0, 0.06, 0),
        11: (0, 0.06, 0), 12: (0, 0.06, 0),
        13: (0.02, 0.04, 0), 14: (-0.02, 0.04, 0),
        15: (0.03, 0.06, 0), 16: (-0.03, 0.06, 0),
        17: (0.03, 0.06, 0), 18: (-0.03, 0.06, 0),
        19: (0.03, 0.06, 0), 20: (-0.03, 0.06, 0),
        21: (0.03, 0.06, 0), 22: (-0.03, 0.06, 0),
        23: (0, 0.06, 0), 24: (0, 0.06, 0),
        25: (0.02, 0.03, 0), 26: (-0.02, 0.03, 0),
        27: (0, 0.01, 0), 28: (0, 0.01, 0),
        29: (0, 0.01, 0), 30: (0, 0.01, 0),
        31: (0, 0.01, 0), 32: (0, 0.01, 0),
    }))

    # Beat 9.5s — right arm wave high, left at hip
    times.append(9.5)
    keyframes.append(apply_offsets(base, {
        13: (0.03, -0.02, 0), 14: (0.02, -0.20, 0),
        15: (0.05, 0.0, 0), 16: (0.04, -0.32, 0),
        17: (0.05, 0.01, 0), 18: (0.04, -0.34, 0),
        19: (0.05, 0.01, 0), 20: (0.04, -0.34, 0),
        21: (0.05, 0.0, 0), 22: (0.04, -0.33, 0),
    }))

    # Beat 11.0s — left arm wave high, right at hip (mirror)
    times.append(11.0)
    keyframes.append(apply_offsets(base, {
        13: (-0.02, -0.20, 0), 14: (-0.03, -0.02, 0),
        15: (-0.04, -0.32, 0), 16: (-0.05, 0.0, 0),
        17: (-0.04, -0.34, 0), 18: (-0.05, 0.01, 0),
        19: (-0.04, -0.34, 0), 20: (-0.05, 0.01, 0),
        21: (-0.04, -0.33, 0), 22: (-0.05, 0.0, 0),
    }))

    # Beat 12.5s — both arms out to sides, step right
    times.append(12.5)
    keyframes.append(apply_offsets(base, {
        0: (0.03, 0, 0),
        11: (0.03, 0, 0), 12: (0.03, 0, 0),
        13: (-0.08, -0.08, 0), 14: (0.11, -0.08, 0),
        15: (-0.14, -0.10, 0), 16: (0.17, -0.10, 0),
        17: (-0.145, -0.10, 0), 18: (0.175, -0.10, 0),
        19: (-0.135, -0.10, 0), 20: (0.165, -0.10, 0),
        21: (-0.13, -0.10, 0), 22: (0.16, -0.10, 0),
        23: (0.03, 0, 0), 24: (0.03, 0, 0),
        25: (0.05, 0, 0), 26: (0.01, 0, 0),
        27: (0.07, 0, 0), 28: (-0.01, 0, 0),
        29: (0.07, 0, 0), 30: (-0.01, 0, 0),
        31: (0.07, 0, 0), 32: (-0.01, 0, 0),
    }))

    # Beat 14.0s — low crouch, arms forward
    times.append(14.0)
    keyframes.append(apply_offsets(base, {
        0: (0, 0.10, 0.04),
        1: (0, 0.10, 0.04), 2: (0, 0.10, 0.04), 3: (0, 0.10, 0.04),
        4: (0, 0.10, 0.04), 5: (0, 0.10, 0.04), 6: (0, 0.10, 0.04),
        7: (0, 0.10, 0.04), 8: (0, 0.10, 0.04),
        9: (0, 0.10, 0.04), 10: (0, 0.10, 0.04),
        11: (0, 0.10, 0.02), 12: (0, 0.10, 0.02),
        13: (-0.02, 0.04, -0.06), 14: (0.02, 0.04, -0.06),
        15: (-0.02, -0.02, -0.12), 16: (0.02, -0.02, -0.12),
        17: (-0.02, -0.02, -0.13), 18: (0.02, -0.02, -0.13),
        19: (-0.02, -0.02, -0.13), 20: (0.02, -0.02, -0.13),
        21: (-0.02, -0.02, -0.12), 22: (0.02, -0.02, -0.12),
        23: (0, 0.10, 0), 24: (0, 0.10, 0),
        25: (0.03, 0.06, 0), 26: (-0.03, 0.06, 0),
        27: (0.02, 0.02, 0), 28: (-0.02, 0.02, 0),
        29: (0.02, 0.02, 0), 30: (-0.02, 0.02, 0),
        31: (0.02, 0.02, 0), 32: (-0.02, 0.02, 0),
    }))

    # Beat 16.0s — back to neutral (closing pose)
    times.append(16.0)
    keyframes.append(base)

    return times, keyframes


def kpop_extended_keyframes():
    """Return (times, poses) for a ~16s K-Pop sync dance routine.

    K-Pop style: precise, sharp arm movements, formations, point choreography.
    """
    base = standing_neutral()
    keyframes = []
    times = []

    # 0.0s — starting pose: hands at sides, feet together
    times.append(0.0)
    keyframes.append(base)

    # 1.0s — right arm point forward, left on hip
    times.append(1.0)
    keyframes.append(apply_offsets(base, {
        13: (0.03, -0.06, 0), 14: (0.02, -0.18, -0.08),
        15: (0.05, -0.02, 0), 16: (0.0, -0.28, -0.15),
        17: (0.05, -0.02, 0), 18: (0.0, -0.28, -0.16),
        19: (0.05, -0.02, 0), 20: (0.0, -0.28, -0.16),
        21: (0.05, -0.02, 0), 22: (0.0, -0.28, -0.15),
    }))

    # 2.0s — both arms crossed in front, slight squat
    times.append(2.0)
    keyframes.append(apply_offsets(base, {
        0: (0, 0.03, 0),
        11: (0, 0.03, 0), 12: (0, 0.03, 0),
        13: (0.04, -0.06, 0.04), 14: (-0.04, -0.06, 0.04),
        15: (0.08, -0.12, 0.06), 16: (-0.08, -0.12, 0.06),
        17: (0.08, -0.12, 0.06), 18: (-0.08, -0.12, 0.06),
        19: (0.08, -0.12, 0.06), 20: (-0.08, -0.12, 0.06),
        21: (0.08, -0.12, 0.06), 22: (-0.08, -0.12, 0.06),
        23: (0, 0.03, 0), 24: (0, 0.03, 0),
        25: (0.02, 0.02, 0), 26: (-0.02, 0.02, 0),
    }))

    # 3.5s — sharp left point, right arm bent at chest
    times.append(3.5)
    keyframes.append(apply_offsets(base, {
        0: (-0.02, 0, 0),
        13: (-0.06, -0.18, 0), 14: (0.02, -0.10, 0.04),
        15: (-0.12, -0.28, 0), 16: (0.06, -0.12, 0.06),
        17: (-0.12, -0.30, 0), 18: (0.06, -0.12, 0.06),
        19: (-0.12, -0.30, 0), 20: (0.06, -0.12, 0.06),
        21: (-0.12, -0.29, 0), 22: (0.06, -0.12, 0.06),
    }))

    # 5.0s — both arms up, wrists flicked, weight on right
    times.append(5.0)
    keyframes.append(apply_offsets(base, {
        0: (0.02, -0.01, 0),
        11: (0.02, 0, 0), 12: (0.02, 0, 0),
        13: (-0.02, -0.18, 0), 14: (0.06, -0.18, 0),
        15: (-0.04, -0.30, 0), 16: (0.08, -0.30, 0),
        17: (-0.05, -0.32, 0), 18: (0.09, -0.32, 0),
        19: (-0.03, -0.32, 0), 20: (0.07, -0.32, 0),
        21: (-0.04, -0.31, 0), 22: (0.08, -0.31, 0),
        23: (0.02, 0, 0), 24: (0.02, 0, 0),
        25: (0.04, 0, 0), 26: (0.0, 0, 0),
        27: (0.05, 0, 0), 28: (-0.01, 0, 0),
    }))

    # 6.5s — body wave: lean back, arms flowing down
    times.append(6.5)
    keyframes.append(apply_offsets(base, {
        0: (0, -0.02, -0.03),
        11: (0, 0.01, -0.02), 12: (0, 0.01, -0.02),
        13: (0.04, 0.02, -0.02), 14: (-0.04, 0.02, -0.02),
        15: (0.06, 0.06, 0), 16: (-0.06, 0.06, 0),
        17: (0.06, 0.07, 0), 18: (-0.06, 0.07, 0),
        19: (0.06, 0.07, 0), 20: (-0.06, 0.07, 0),
        21: (0.06, 0.06, 0), 22: (-0.06, 0.06, 0),
        23: (0, 0.02, 0.01), 24: (0, 0.02, 0.01),
    }))

    # 8.0s — sharp right step, left arm point up, right down
    times.append(8.0)
    keyframes.append(apply_offsets(base, {
        0: (0.05, 0, 0),
        11: (0.05, 0, 0), 12: (0.05, 0, 0),
        13: (-0.04, -0.20, 0), 14: (0.07, 0.0, 0),
        15: (-0.06, -0.34, 0), 16: (0.09, 0.06, 0),
        17: (-0.06, -0.36, 0), 18: (0.09, 0.07, 0),
        19: (-0.06, -0.36, 0), 20: (0.09, 0.07, 0),
        21: (-0.06, -0.35, 0), 22: (0.09, 0.06, 0),
        23: (0.05, 0, 0), 24: (0.05, 0, 0),
        25: (0.07, 0, 0), 26: (0.03, 0, 0),
        27: (0.09, 0, 0), 28: (0.01, 0, 0),
        29: (0.09, 0, 0), 30: (0.01, 0, 0),
        31: (0.09, 0, 0), 32: (0.01, 0, 0),
    }))

    # 9.5s — mirror: sharp left step, right arm point up, left down
    times.append(9.5)
    keyframes.append(apply_offsets(base, {
        0: (-0.05, 0, 0),
        11: (-0.05, 0, 0), 12: (-0.05, 0, 0),
        13: (-0.07, 0.0, 0), 14: (0.04, -0.20, 0),
        15: (-0.09, 0.06, 0), 16: (0.06, -0.34, 0),
        17: (-0.09, 0.07, 0), 18: (0.06, -0.36, 0),
        19: (-0.09, 0.07, 0), 20: (0.06, -0.36, 0),
        21: (-0.09, 0.06, 0), 22: (0.06, -0.35, 0),
        23: (-0.05, 0, 0), 24: (-0.05, 0, 0),
        25: (-0.03, 0, 0), 26: (-0.07, 0, 0),
        27: (-0.01, 0, 0), 28: (-0.09, 0, 0),
        29: (-0.01, 0, 0), 30: (-0.09, 0, 0),
        31: (-0.01, 0, 0), 32: (-0.09, 0, 0),
    }))

    # 11.0s — formation: T-pose arms, wide stance
    times.append(11.0)
    keyframes.append(apply_offsets(base, {
        11: (-0.02, 0, 0), 12: (0.02, 0, 0),
        13: (-0.12, -0.10, 0), 14: (0.12, -0.10, 0),
        15: (-0.20, -0.10, 0), 16: (0.20, -0.10, 0),
        17: (-0.205, -0.10, 0), 18: (0.205, -0.10, 0),
        19: (-0.195, -0.10, 0), 20: (0.195, -0.10, 0),
        21: (-0.19, -0.10, 0), 22: (0.19, -0.10, 0),
        23: (-0.03, 0, 0), 24: (0.03, 0, 0),
        25: (-0.05, 0, 0), 26: (0.05, 0, 0),
        27: (-0.06, 0, 0), 28: (0.06, 0, 0),
        29: (-0.06, 0, 0), 30: (0.06, 0, 0),
        31: (-0.06, 0, 0), 32: (0.06, 0, 0),
    }))

    # 12.5s — hair flip: right hand to head, lean left
    times.append(12.5)
    keyframes.append(apply_offsets(base, {
        0: (-0.03, 0.01, 0),
        11: (-0.03, 0, 0), 12: (-0.03, 0, 0),
        13: (0.02, -0.04, 0), 14: (-0.01, -0.22, 0),
        15: (0.04, 0.0, 0), 16: (0.02, -0.30, 0.02),
        17: (0.04, 0.01, 0), 18: (0.02, -0.31, 0.02),
        19: (0.04, 0.01, 0), 20: (0.02, -0.31, 0.02),
        21: (0.04, 0.0, 0), 22: (0.02, -0.30, 0.02),
        23: (-0.03, 0, 0), 24: (-0.03, 0, 0),
        25: (-0.04, 0, 0), 26: (-0.02, 0, 0),
    }))

    # 14.0s — ending pose: both hands heart shape at chest
    times.append(14.0)
    keyframes.append(apply_offsets(base, {
        13: (0.02, -0.12, 0.04), 14: (-0.02, -0.12, 0.04),
        15: (0.05, -0.16, 0.06), 16: (-0.05, -0.16, 0.06),
        17: (0.04, -0.17, 0.06), 18: (-0.04, -0.17, 0.06),
        19: (0.05, -0.17, 0.06), 20: (-0.05, -0.17, 0.06),
        21: (0.04, -0.16, 0.06), 22: (-0.04, -0.16, 0.06),
    }))

    # 16.0s — return to neutral
    times.append(16.0)
    keyframes.append(base)

    return times, keyframes


def interpolate_sequence(times, keyframes, fps):
    """Interpolate keyframe poses into a full sequence at the given fps."""
    duration = times[-1]
    n_frames = int(duration * fps)
    t_out = np.linspace(0, duration, n_frames, endpoint=False)

    n_landmarks = len(keyframes[0])
    # Build arrays: shape (n_keyframes, n_landmarks, 4) for x, y, z, v
    kf_array = np.array(keyframes)  # (K, 33, 4)

    frames = []
    for fi, t in enumerate(t_out):
        landmarks = []
        for li in range(n_landmarks):
            coords = []
            for ci in range(3):  # x, y, z
                cs = CubicSpline(times, kf_array[:, li, ci], bc_type="clamped")
                coords.append(float(cs(t)))
            # visibility is constant
            v = float(kf_array[0, li, 3])
            landmarks.append({
                "x": round(coords[0], 6),
                "y": round(coords[1], 6),
                "z": round(coords[2], 6),
                "v": round(v, 4),
            })
        frames.append({
            "ts": round(t * 1000),  # milliseconds
            "lm": landmarks,
        })

    return frames, round(duration * 1000)


def write_reference(filename, ref_id, name, style, difficulty, bpm,
                    description, times, keyframes, fps=FPS):
    """Generate and write a reference JSON file."""
    frames, duration_ms = interpolate_sequence(times, keyframes, fps)

    ref = {
        "id": ref_id,
        "name": name,
        "style": style,
        "poses": {
            "fps": float(fps),
            "duration_ms": duration_ms,
            "label": ref_id,
            "frames": frames,
        },
        "bpm": bpm,
        "description": description,
        "difficulty": difficulty,
        "audio_asset": None,
    }

    out_path = OUTPUT_DIR / filename
    with open(out_path, "w") as f:
        json.dump(ref, f, indent=2)

    n = len(frames)
    print(f"Wrote {out_path.name}: {n} frames, {duration_ms / 1000:.1f}s")


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Hip Hop Extended Groove
    times, keyframes = hip_hop_extended_keyframes()
    write_reference(
        filename="hip_hop_extended.json",
        ref_id="hip_hop_extended",
        name="Hip Hop Extended Groove",
        style="hipHop",
        difficulty="intermediate",
        bpm=95.0,
        description="A 16-second hip hop routine with steps, arm waves, "
                    "body rolls, and a freeze. Great for practicing full "
                    "combinations.",
        times=times,
        keyframes=keyframes,
    )

    # K-Pop Extended Sync
    times, keyframes = kpop_extended_keyframes()
    write_reference(
        filename="kpop_extended.json",
        ref_id="kpop_extended",
        name="K-Pop Extended Sync",
        style="kPop",
        difficulty="intermediate",
        bpm=110.0,
        description="A 16-second K-Pop routine with sharp arm hits, body "
                    "waves, and synchronized point choreography. Practice "
                    "precision and energy.",
        times=times,
        keyframes=keyframes,
    )


if __name__ == "__main__":
    main()
