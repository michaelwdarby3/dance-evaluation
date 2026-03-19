#!/usr/bin/env python3
"""Extract poses from a video and save as a reference choreography JSON.

Usage:
    python tools/extract_reference.py input.mp4 \
        --name "My Dance" --style hipHop --bpm 120 \
        --output assets/references/my_dance.json

Requires: mediapipe, opencv-python
"""

import argparse
import json
from pathlib import Path

from pose_utils import extract_poses_from_video


def main():
    parser = argparse.ArgumentParser(description="Extract reference from video")
    parser.add_argument("video", help="Input video file")
    parser.add_argument("--output", "-o", required=True, help="Output JSON path")
    parser.add_argument("--name", default="Untitled Reference", help="Reference name")
    parser.add_argument("--id", default=None, help="Reference ID (defaults to filename)")
    parser.add_argument(
        "--style",
        default="hipHop",
        choices=["hipHop", "kPop", "contemporary", "freestyle"],
        help="Dance style",
    )
    parser.add_argument("--bpm", type=float, default=120.0, help="BPM of the music")
    parser.add_argument(
        "--difficulty",
        default="beginner",
        choices=["beginner", "intermediate", "advanced"],
    )
    parser.add_argument("--description", default="", help="Short description")
    parser.add_argument("--fps", type=float, default=15.0, help="Sample rate (fps)")
    parser.add_argument(
        "--multi-person",
        action="store_true",
        help="Extract multi-person poses (v2 format)",
    )
    parser.add_argument(
        "--num-poses",
        type=int,
        default=5,
        help="Max persons to detect per frame (only with --multi-person)",
    )
    args = parser.parse_args()

    ref_id = args.id or Path(args.output).stem
    num_poses = args.num_poses if args.multi_person else 1

    print(f"Extracting poses from {args.video} at ~{args.fps} fps (num_poses={num_poses})...")
    frames_json = extract_poses_from_video(
        args.video, target_fps=args.fps, num_poses=num_poses
    )

    if not frames_json:
        raise SystemExit("No poses detected in video")

    duration_ms = frames_json[-1]["ts"]

    if args.multi_person:
        # Build v2 multi-person format.
        # Transpose frame-major data to person-major PoseSequences.
        max_persons = max(len(f.get("persons", [])) for f in frames_json)
        persons = []
        for pi in range(max_persons):
            person_frames = []
            for f in frames_json:
                frame_persons = f.get("persons", [])
                if pi < len(frame_persons):
                    person_frames.append({
                        "ts": f["ts"],
                        "lm": frame_persons[pi]["lm"],
                    })
            if person_frames:
                persons.append({
                    "fps": args.fps,
                    "duration_ms": duration_ms,
                    "label": f"person_{pi}",
                    "frames": person_frames,
                })

        reference = {
            "version": 2,
            "id": ref_id,
            "name": args.name,
            "style": args.style,
            "bpm": args.bpm,
            "description": args.description or f"Reference extracted from {Path(args.video).name}",
            "difficulty": args.difficulty,
            "audio_asset": None,
            "persons": persons,
        }
        print(f"Saved {len(frames_json)} frames, {len(persons)} persons to v2 format")
    else:
        reference = {
            "id": ref_id,
            "name": args.name,
            "style": args.style,
            "bpm": args.bpm,
            "description": args.description or f"Reference extracted from {Path(args.video).name}",
            "difficulty": args.difficulty,
            "audio_asset": None,
            "poses": {
                "fps": args.fps,
                "duration_ms": duration_ms,
                "label": ref_id,
                "frames": frames_json,
            },
        }

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(reference, indent=2))

    print(f"Saved {len(frames_json)} frames to {out} ({duration_ms}ms)")


if __name__ == "__main__":
    main()
