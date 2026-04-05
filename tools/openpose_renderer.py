#!/usr/bin/env python3
"""BlazePose → OpenPose conversion and skeleton image rendering.

Renders colored OpenPose-style skeleton images suitable for ControlNet conditioning.
Can also render standalone skeleton videos from reference choreography JSON files.
"""

import json
from pathlib import Path

import cv2
import numpy as np

# ---------------------------------------------------------------------------
# BlazePose (33 landmarks) → OpenPose (25 keypoints) mapping
# ---------------------------------------------------------------------------
# Each entry is either an int (direct BlazePose index) or a tuple of two
# indices whose midpoint is used.

BLAZEPOSE_TO_OPENPOSE = {
    0: 0,            # Nose
    1: (11, 12),     # Neck (midpoint of L/R shoulder)
    2: 12,           # R Shoulder
    3: 14,           # R Elbow
    4: 16,           # R Wrist
    5: 11,           # L Shoulder
    6: 13,           # L Elbow
    7: 15,           # L Wrist
    8: (23, 24),     # Mid Hip (midpoint of L/R hip)
    9: 24,           # R Hip
    10: 26,          # R Knee
    11: 28,          # R Ankle
    12: 23,          # L Hip
    13: 25,          # L Knee
    14: 27,          # L Ankle
    15: 5,           # R Eye
    16: 2,           # L Eye
    17: 8,           # R Ear
    18: 7,           # L Ear
    19: 32,          # R Big Toe (rightFootIndex)
    20: 30,          # R Small Toe (rightHeel)
    21: 30,          # R Heel (rightHeel)
    22: 31,          # L Big Toe (leftFootIndex)
    23: 29,          # L Small Toe (leftHeel)
    24: 29,          # L Heel (leftHeel)
}

# ---------------------------------------------------------------------------
# OpenPose limb connections and canonical colors (from controlnet_aux)
# ---------------------------------------------------------------------------
# Each tuple: (keypoint_a, keypoint_b)
OPENPOSE_LIMBS = [
    (0, 1),    # Nose → Neck
    (1, 2),    # Neck → R Shoulder
    (2, 3),    # R Shoulder → R Elbow
    (3, 4),    # R Elbow → R Wrist
    (1, 5),    # Neck → L Shoulder
    (5, 6),    # L Shoulder → L Elbow
    (6, 7),    # L Elbow → L Wrist
    (1, 8),    # Neck → Mid Hip
    (8, 9),    # Mid Hip → R Hip
    (9, 10),   # R Hip → R Knee
    (10, 11),  # R Knee → R Ankle
    (8, 12),   # Mid Hip → L Hip
    (12, 13),  # L Hip → L Knee
    (13, 14),  # L Knee → L Ankle
    (0, 15),   # Nose → R Eye
    (15, 17),  # R Eye → R Ear
    (0, 16),   # Nose → L Eye
    (16, 18),  # L Eye → L Ear
]

# Canonical OpenPose colors (BGR for cv2) — matches controlnet_aux training data
OPENPOSE_COLORS = [
    (0, 0, 255),      # 0  Nose → Neck: red
    (0, 85, 255),     # 1  Neck → R Shoulder
    (0, 170, 255),    # 2  R Shoulder → R Elbow
    (0, 255, 255),    # 3  R Elbow → R Wrist
    (0, 255, 170),    # 4  Neck → L Shoulder
    (0, 255, 85),     # 5  L Shoulder → L Elbow
    (0, 255, 0),      # 6  L Elbow → L Wrist
    (255, 170, 0),    # 7  Neck → Mid Hip
    (255, 255, 0),    # 8  Mid Hip → R Hip
    (170, 255, 0),    # 9  R Hip → R Knee
    (85, 255, 0),     # 10 R Knee → R Ankle
    (255, 0, 0),      # 11 Mid Hip → L Hip
    (255, 0, 85),     # 12 L Hip → L Knee
    (255, 0, 170),    # 13 L Knee → L Ankle
    (255, 0, 255),    # 14 Nose → R Eye
    (170, 0, 255),    # 15 R Eye → R Ear
    (85, 0, 255),     # 16 Nose → L Eye
    (0, 0, 255),      # 17 L Eye → L Ear
]

# Joint/keypoint colors — canonical 25-point palette
OPENPOSE_JOINT_COLORS = [
    (0, 0, 255),      # 0  Nose
    (0, 85, 255),     # 1  Neck
    (0, 170, 255),    # 2  R Shoulder
    (0, 255, 255),    # 3  R Elbow
    (0, 255, 170),    # 4  R Wrist
    (0, 255, 85),     # 5  L Shoulder
    (0, 255, 0),      # 6  L Elbow
    (85, 255, 0),     # 7  L Wrist
    (170, 255, 0),    # 8  Mid Hip
    (255, 255, 0),    # 9  R Hip
    (255, 170, 0),    # 10 R Knee
    (255, 85, 0),     # 11 R Ankle
    (255, 0, 0),      # 12 L Hip
    (255, 0, 85),     # 13 L Knee
    (255, 0, 170),    # 14 L Ankle
    (255, 0, 255),    # 15 R Eye
    (170, 0, 255),    # 16 L Eye
    (85, 0, 255),     # 17 R Ear
    (0, 0, 255),      # 18 L Ear
    (170, 255, 0),    # 19 R Big Toe
    (170, 255, 0),    # 20 R Small Toe
    (170, 255, 0),    # 21 R Heel
    (255, 0, 0),      # 22 L Big Toe
    (255, 0, 0),      # 23 L Small Toe
    (255, 0, 0),      # 24 L Heel
]


def blazepose_to_openpose(landmarks: list[dict]) -> list[tuple[float, float, float]]:
    """Convert 33 BlazePose landmarks to 25 OpenPose keypoints.

    Args:
        landmarks: List of 33 dicts with keys 'x', 'y', 'z', 'v' (visibility).
                   Coordinates are normalized [0, 1].

    Returns:
        List of 25 tuples (x, y, confidence) in normalized coordinates.
    """
    keypoints = []
    for op_idx in range(25):
        source = BLAZEPOSE_TO_OPENPOSE[op_idx]
        if isinstance(source, tuple):
            a, b = source
            lm_a, lm_b = landmarks[a], landmarks[b]
            x = (lm_a["x"] + lm_b["x"]) / 2
            y = (lm_a["y"] + lm_b["y"]) / 2
            conf = min(lm_a.get("v", 1.0), lm_b.get("v", 1.0))
        else:
            lm = landmarks[source]
            x = lm["x"]
            y = lm["y"]
            conf = lm.get("v", 1.0)
        keypoints.append((x, y, conf))
    return keypoints


def render_openpose_frame(
    keypoints: list[tuple[float, float, float]],
    width: int = 512,
    height: int = 512,
    line_width: int = 4,
    joint_radius: int = 4,
    confidence_threshold: float = 0.3,
) -> np.ndarray:
    """Render an OpenPose skeleton frame on a black background.

    Args:
        keypoints: 25 OpenPose keypoints as (x, y, confidence) in normalized [0,1].
        width: Output image width.
        height: Output image height.
        line_width: Limb line thickness in pixels.
        joint_radius: Joint circle radius in pixels.
        confidence_threshold: Minimum confidence to draw a keypoint/limb.

    Returns:
        BGR numpy array of shape (height, width, 3).
    """
    canvas = np.zeros((height, width, 3), dtype=np.uint8)

    # Convert normalized coords to pixel coords
    pts = []
    for x, y, c in keypoints:
        px = int(x * width)
        py = int(y * height)
        pts.append((px, py, c))

    # Draw limbs
    for limb_idx, (a, b) in enumerate(OPENPOSE_LIMBS):
        if a >= len(pts) or b >= len(pts):
            continue
        pa, pb = pts[a], pts[b]
        if pa[2] < confidence_threshold or pb[2] < confidence_threshold:
            continue
        color = OPENPOSE_COLORS[limb_idx % len(OPENPOSE_COLORS)]
        cv2.line(canvas, (pa[0], pa[1]), (pb[0], pb[1]), color, line_width, cv2.LINE_AA)

    # Draw joints on top
    for i, (px, py, c) in enumerate(pts):
        if c < confidence_threshold:
            continue
        color = OPENPOSE_JOINT_COLORS[i % len(OPENPOSE_JOINT_COLORS)]
        cv2.circle(canvas, (px, py), joint_radius, color, -1, cv2.LINE_AA)

    return canvas


def load_reference(path: str | Path) -> dict:
    """Load a reference choreography JSON file."""
    with open(path) as f:
        return json.load(f)


def render_skeleton_video(
    reference_json: dict | str | Path,
    width: int = 512,
    height: int = 512,
    output_fps: int = 8,
) -> list[np.ndarray]:
    """Render all frames from a reference JSON as OpenPose skeleton images.

    Resamples to output_fps if the reference has a different FPS.

    Args:
        reference_json: Either a loaded dict or a path to the JSON file.
        width: Output frame width.
        height: Output frame height.
        output_fps: Desired output FPS (frames resampled if needed).

    Returns:
        List of BGR numpy arrays, one per output frame.
    """
    if isinstance(reference_json, (str, Path)):
        reference_json = load_reference(reference_json)

    poses = reference_json["poses"]
    source_fps = poses.get("fps", 15.0)
    frames = poses["frames"]
    duration_ms = poses.get("duration_ms", 0)

    if not frames:
        return []

    # Determine output frame count
    if duration_ms > 0:
        duration_s = duration_ms / 1000.0
    else:
        # Estimate from last frame timestamp
        duration_s = frames[-1].get("ts", 0) / 1000.0

    output_frame_count = max(1, int(duration_s * output_fps))

    # Build output frames by nearest-neighbor resampling
    output_frames = []
    for out_idx in range(output_frame_count):
        out_time_ms = (out_idx / output_fps) * 1000.0

        # Find nearest source frame by timestamp
        best_idx = 0
        best_dist = float("inf")
        for src_idx, frame in enumerate(frames):
            src_time = frame.get("ts", src_idx / source_fps * 1000.0)
            dist = abs(src_time - out_time_ms)
            if dist < best_dist:
                best_dist = dist
                best_idx = src_idx

        landmarks = frames[best_idx]["lm"]
        keypoints = blazepose_to_openpose(landmarks)
        canvas = render_openpose_frame(keypoints, width, height)
        output_frames.append(canvas)

    return output_frames


def save_skeleton_video(
    frames: list[np.ndarray],
    output_path: str | Path,
    fps: int = 8,
) -> None:
    """Save rendered skeleton frames to an MP4 video using ffmpeg.

    Args:
        frames: List of BGR numpy arrays.
        output_path: Path for the output MP4 file.
        fps: Output framerate.
    """
    import subprocess
    import tempfile

    import imageio_ffmpeg

    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    ffmpeg_bin = imageio_ffmpeg.get_ffmpeg_exe()

    with tempfile.TemporaryDirectory() as tmpdir:
        for i, frame in enumerate(frames):
            cv2.imwrite(f"{tmpdir}/frame_{i:04d}.png", frame)

        cmd = [
            ffmpeg_bin, "-y",
            "-framerate", str(fps),
            "-i", f"{tmpdir}/frame_%04d.png",
            "-c:v", "libx264",
            "-pix_fmt", "yuv420p",
            "-crf", "23",
            str(output_path),
        ]
        subprocess.run(cmd, check=True, capture_output=True)

    print(f"Saved skeleton video: {output_path} ({len(frames)} frames @ {fps} fps)")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Render OpenPose skeleton video from reference JSON")
    parser.add_argument("reference", help="Path to reference choreography JSON")
    parser.add_argument("-o", "--output", help="Output MP4 path")
    parser.add_argument("--width", type=int, default=512)
    parser.add_argument("--height", type=int, default=512)
    parser.add_argument("--fps", type=int, default=8)
    args = parser.parse_args()

    ref_path = Path(args.reference)
    output = args.output or f"assets/reference_videos/{ref_path.stem}_skeleton.mp4"

    print(f"Loading {ref_path}...")
    frames = render_skeleton_video(ref_path, args.width, args.height, args.fps)
    print(f"Rendered {len(frames)} frames")
    save_skeleton_video(frames, output, args.fps)
