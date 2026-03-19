"""Shared MediaPipe pose extraction utilities using the tasks API (>=0.10.9)."""

from pathlib import Path
from urllib.request import urlretrieve

import cv2
import mediapipe as mp
from mediapipe.tasks import python as mp_python
from mediapipe.tasks.python import vision

# BlazePose model download
_MODEL_URL = "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_full/float16/latest/pose_landmarker_full.task"
_MODEL_DIR = Path(__file__).parent / ".cache"
_MODEL_PATH = _MODEL_DIR / "pose_landmarker_full.task"


def ensure_model() -> str:
    """Download the pose landmarker model if not cached. Returns path."""
    if _MODEL_PATH.exists():
        return str(_MODEL_PATH)
    _MODEL_DIR.mkdir(parents=True, exist_ok=True)
    print(f"Downloading pose landmarker model...")
    urlretrieve(_MODEL_URL, _MODEL_PATH)
    print(f"Saved to {_MODEL_PATH}")
    return str(_MODEL_PATH)


def extract_poses_from_video(
    video_path: str,
    target_fps: float = 10.0,
    num_poses: int = 1,
) -> list[dict]:
    """Extract 33-landmark pose frames from a video file.

    When num_poses == 1 (default), returns legacy format:
        [{"ts": int_ms, "lm": [{"x","y","z","v"}, ...]}, ...]

    When num_poses > 1, returns multi-person format:
        [{"ts": int_ms, "persons": [{"lm": [...]}, {"lm": [...]}]}, ...]
    """
    model_path = ensure_model()

    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise RuntimeError(f"Cannot open video: {video_path}")

    video_fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    frame_interval = max(1, round(video_fps / target_fps))

    # Create PoseLandmarker in VIDEO mode.
    options = vision.PoseLandmarkerOptions(
        base_options=mp_python.BaseOptions(model_asset_path=model_path),
        running_mode=vision.RunningMode.VIDEO,
        num_poses=num_poses,
    )
    landmarker = vision.PoseLandmarker.create_from_options(options)

    frames_json = []
    frame_idx = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        if frame_idx % frame_interval == 0:
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
            ts_ms = round(frame_idx / video_fps * 1000)

            result = landmarker.detect_for_video(mp_image, ts_ms)

            if result.pose_landmarks and len(result.pose_landmarks) > 0:
                if num_poses == 1:
                    # Legacy single-person format.
                    landmarks = []
                    for lm in result.pose_landmarks[0]:
                        landmarks.append({
                            "x": round(lm.x, 6),
                            "y": round(lm.y, 6),
                            "z": round(lm.z, 6),
                            "v": round(lm.visibility, 4),
                        })
                    frames_json.append({"ts": ts_ms, "lm": landmarks})
                else:
                    # Multi-person format.
                    persons = []
                    for person_landmarks in result.pose_landmarks:
                        landmarks = []
                        for lm in person_landmarks:
                            landmarks.append({
                                "x": round(lm.x, 6),
                                "y": round(lm.y, 6),
                                "z": round(lm.z, 6),
                                "v": round(lm.visibility, 4),
                            })
                        persons.append({"lm": landmarks})
                    frames_json.append({"ts": ts_ms, "persons": persons})

        frame_idx += 1

    cap.release()
    landmarker.close()

    return frames_json
