"""Load reference choreographies from JSON files on disk."""

import json
from pathlib import Path

import numpy as np

# Default directory — sibling to the api/ package.
_DEFAULT_DIR = Path(__file__).resolve().parent.parent.parent / "references"


def load_reference(
    reference_id: str, references_dir: Path | None = None
) -> list[np.ndarray]:
    """Load a reference JSON and return a list of (33, 4) numpy frames.

    Args:
        reference_id: The reference ID (matches the filename without .json).
        references_dir: Directory containing reference JSON files.

    Returns:
        List of numpy arrays, one per frame, shape (33, 4).

    Raises:
        FileNotFoundError: If the reference JSON doesn't exist.
        ValueError: If the JSON structure is unexpected.
    """
    ref_dir = references_dir or _DEFAULT_DIR
    path = ref_dir / f"{reference_id}.json"

    if not path.exists():
        raise FileNotFoundError(f"Reference not found: {path}")

    with open(path) as f:
        data = json.load(f)

    return _parse_frames(data)


def list_references(references_dir: Path | None = None) -> list[str]:
    """Return a list of available reference IDs."""
    ref_dir = references_dir or _DEFAULT_DIR
    if not ref_dir.exists():
        return []
    return [p.stem for p in sorted(ref_dir.glob("*.json"))]


def _parse_frames(data: dict) -> list[np.ndarray]:
    """Parse reference JSON into numpy frames.

    Supports the compact format used by the Flutter app:
      poses.frames[].lm[] with keys {x, y, z, v}
    """
    poses = data.get("poses", data)
    raw_frames = poses.get("frames", [])

    frames: list[np.ndarray] = []
    for raw in raw_frames:
        landmarks = raw.get("lm", raw.get("landmarks", []))
        arr = np.zeros((len(landmarks), 4), dtype=np.float64)
        for i, lm in enumerate(landmarks):
            arr[i, 0] = lm.get("x", 0.0)
            arr[i, 1] = lm.get("y", 0.0)
            arr[i, 2] = lm.get("z", 0.0)
            arr[i, 3] = lm.get("v", lm.get("visibility", 0.0))
        frames.append(arr)

    return frames
