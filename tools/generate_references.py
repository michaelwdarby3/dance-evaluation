#!/usr/bin/env python3
"""Generate a set of reference choreography videos and extract pose data.

Usage:
    python tools/generate_references.py

Single-person references are generated with Wan2.1 text-to-video (1.3B).
Multi-person references are extracted from real stock footage (Mixkit, CC-free).

Requires: diffusers, torch, mediapipe, opencv-python
GPU: ~8GB VRAM (RTX 3070 compatible)
"""

import json
import subprocess
import tempfile
from pathlib import Path
from urllib.request import urlretrieve

import numpy as np
import torch
from PIL import Image

from pose_utils import extract_poses_from_video

# ---------------------------------------------------------------------------
# Single-person references (generated via Wan2.1)
# ---------------------------------------------------------------------------
SINGLE_PERSON_REFERENCES = [
    {
        "id": "kpop_basic_1",
        "name": "K-Pop Point Choreography",
        "style": "kPop",
        "bpm": 128.0,
        "difficulty": "beginner",
        "prompt": "a person performing kpop dance choreography in a bright studio, full body visible, clean background",
    },
    {
        "id": "kpop_basic_2",
        "name": "K-Pop Wave Routine",
        "style": "kPop",
        "bpm": 120.0,
        "difficulty": "beginner",
        "prompt": "a person doing kpop dance moves with arm waves in a practice room, full body, good lighting",
    },
    {
        "id": "kpop_intermediate",
        "name": "K-Pop Sync Dance",
        "style": "kPop",
        "bpm": 132.0,
        "difficulty": "intermediate",
        "prompt": "a dancer performing energetic kpop choreography with sharp movements in a dance studio, full body",
    },
    {
        "id": "rnb_basic_1",
        "name": "R&B Smooth Groove",
        "style": "hipHop",
        "bpm": 90.0,
        "difficulty": "beginner",
        "prompt": "a person dancing smooth r&b style in a studio, slow body rolls and grooves, full body visible",
    },
    {
        "id": "rnb_basic_2",
        "name": "R&B Body Wave",
        "style": "hipHop",
        "bpm": 95.0,
        "difficulty": "beginner",
        "prompt": "a person performing slow smooth dance moves in a dark studio with colored lights, full body visible",
    },
    {
        "id": "rnb_intermediate",
        "name": "R&B Freestyle Flow",
        "style": "hipHop",
        "bpm": 100.0,
        "difficulty": "intermediate",
        "prompt": "a dancer doing fluid r&b choreography with isolations in a dance studio, full body, good lighting",
    },
]

# ---------------------------------------------------------------------------
# Multi-person references (extracted from real stock footage)
# Source: Mixkit (https://mixkit.co) — free for commercial and personal use.
# ---------------------------------------------------------------------------
MULTI_PERSON_REFERENCES = [
    {
        "id": "duo_sunset",
        "name": "Duo Sunset Dance",
        "style": "freestyle",
        "bpm": 110.0,
        "difficulty": "beginner",
        "multi_person": True,
        "video_url": "https://assets.mixkit.co/videos/4636/4636-720.mp4",
        "source": "Mixkit #4636 — Couple in Love Dancing Happily",
    },
    {
        "id": "duo_neon",
        "name": "Duo Neon Contemporary",
        "style": "contemporary",
        "bpm": 100.0,
        "difficulty": "intermediate",
        "multi_person": True,
        "video_url": "https://assets.mixkit.co/videos/40931/40931-720.mp4",
        "source": "Mixkit #40931 — Two Girls Dancing with Blue Neon Lights",
    },
    {
        "id": "group_street",
        "name": "Street Group Choreography",
        "style": "hipHop",
        "bpm": 95.0,
        "difficulty": "intermediate",
        "multi_person": True,
        "video_url": "https://assets.mixkit.co/videos/51295/51295-720.mp4",
        "source": "Mixkit #51295 — Five Young People Dancing a Choreography",
    },
]


def load_wan_pipeline():
    """Load the Wan2.1 1.3B text-to-video pipeline."""
    from diffusers import AutoencoderKLWan, WanPipeline

    print("Loading Wan2.1 1.3B text-to-video pipeline...")
    model_id = "Wan-AI/Wan2.1-T2V-1.3B-Diffusers"

    vae = AutoencoderKLWan.from_pretrained(
        model_id, subfolder="vae", torch_dtype=torch.float32
    )
    pipe = WanPipeline.from_pretrained(
        model_id, vae=vae, torch_dtype=torch.bfloat16
    )
    pipe.enable_model_cpu_offload()

    return pipe


def load_modelscope_pipeline():
    """Fallback: load the ModelScope 1.7B pipeline."""
    from diffusers import DiffusionPipeline

    print("Loading ModelScope 1.7B text-to-video pipeline (fallback)...")
    pipe = DiffusionPipeline.from_pretrained(
        "ali-vilab/text-to-video-ms-1.7b",
        torch_dtype=torch.float16,
        variant="fp16",
    )
    pipe.enable_attention_slicing()
    pipe.enable_model_cpu_offload()
    return pipe


def generate_video_wan(pipe, prompt: str, output_path: Path):
    """Generate a video with Wan2.1 and save as MP4."""
    print(f"  Generating: '{prompt[:60]}...'")

    with torch.no_grad():
        result = pipe(
            prompt,
            num_frames=81,
            width=832,
            height=480,
            num_inference_steps=30,
            guidance_scale=5.0,
        )

    video_frames = result.frames[0]
    print(f"  Got {len(video_frames)} frames")
    _save_frames_as_mp4(video_frames, output_path, fps=15)


def generate_video_modelscope(pipe, prompt: str, output_path: Path):
    """Generate a video with ModelScope and save as MP4."""
    print(f"  Generating: '{prompt[:60]}...'")

    with torch.no_grad():
        result = pipe(
            prompt,
            num_frames=24,
            width=256,
            height=256,
            num_inference_steps=15,
        )

    video_frames = result.frames[0]
    print(f"  Got {len(video_frames)} frames")
    _save_frames_as_mp4(video_frames, output_path, fps=8)


def _save_frames_as_mp4(video_frames, output_path: Path, fps: int = 8):
    """Save a list of PIL/numpy frames as an MP4 file."""
    import imageio_ffmpeg

    ffmpeg_bin = imageio_ffmpeg.get_ffmpeg_exe()

    with tempfile.TemporaryDirectory() as tmpdir:
        for i, frame in enumerate(video_frames):
            if isinstance(frame, np.ndarray):
                frame_uint8 = (frame * 255).clip(0, 255).astype(np.uint8)
                Image.fromarray(frame_uint8).save(f"{tmpdir}/frame_{i:04d}.png")
            else:
                frame.save(f"{tmpdir}/frame_{i:04d}.png")

        output_path.parent.mkdir(parents=True, exist_ok=True)
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

    print(f"  Saved video: {output_path}")


def download_video(url: str, output_path: Path):
    """Download a video from a URL."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    if output_path.exists():
        print(f"  Already downloaded: {output_path}")
        return
    print(f"  Downloading: {url}")
    urlretrieve(url, output_path)
    print(f"  Saved: {output_path}")


def extract_reference(
    video_path: Path,
    ref_info: dict,
    output_path: Path,
    target_fps: float = 10.0,
    multi_person: bool = False,
    num_poses: int = 5,
):
    """Extract poses from video and save as reference JSON."""
    actual_num_poses = num_poses if multi_person else 1
    frames_json = extract_poses_from_video(
        str(video_path), target_fps=target_fps, num_poses=actual_num_poses
    )

    if not frames_json:
        print(f"  WARNING: No poses detected in {video_path}")
        return False

    duration_ms = frames_json[-1]["ts"]
    description = ref_info.get("source", f"Generated reference: {ref_info['name']}")

    if multi_person:
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
                    "fps": target_fps,
                    "duration_ms": duration_ms,
                    "label": f"person_{pi}",
                    "frames": person_frames,
                })

        reference = {
            "version": 2,
            "id": ref_info["id"],
            "name": ref_info["name"],
            "style": ref_info["style"],
            "bpm": ref_info["bpm"],
            "description": description,
            "difficulty": ref_info["difficulty"],
            "audio_asset": None,
            "persons": persons,
        }
        print(f"  Detected {len(persons)} persons across {len(frames_json)} frames")
    else:
        reference = {
            "id": ref_info["id"],
            "name": ref_info["name"],
            "style": ref_info["style"],
            "bpm": ref_info["bpm"],
            "description": description,
            "difficulty": ref_info["difficulty"],
            "audio_asset": None,
            "poses": {
                "fps": target_fps,
                "duration_ms": duration_ms,
                "label": ref_info["id"],
                "frames": frames_json,
            },
        }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(reference, indent=2))
    print(f"  Saved reference: {output_path} ({len(frames_json)} frames, {duration_ms}ms)")
    return True


def main():
    project_root = Path(__file__).parent.parent
    video_dir = project_root / "assets" / "test_videos"
    multi_video_dir = video_dir / "multi_person"
    ref_dir = project_root / "assets" / "references"

    # ------------------------------------------------------------------
    # Phase 1: Generate single-person references with Wan2.1
    # ------------------------------------------------------------------
    single_pending = [
        r for r in SINGLE_PERSON_REFERENCES
        if not (ref_dir / f"{r['id']}.json").exists()
    ]

    if single_pending:
        # Try Wan2.1 first, fall back to ModelScope.
        try:
            pipe = load_wan_pipeline()
            generate_fn = generate_video_wan
        except Exception as e:
            print(f"Wan2.1 unavailable ({e}), falling back to ModelScope")
            pipe = load_modelscope_pipeline()
            generate_fn = generate_video_modelscope

        for i, ref_info in enumerate(single_pending):
            print(f"\n[Single {i + 1}/{len(single_pending)}] {ref_info['name']}")

            video_path = video_dir / f"{ref_info['id']}.mp4"
            ref_path = ref_dir / f"{ref_info['id']}.json"

            generate_fn(pipe, ref_info["prompt"], video_path)
            torch.cuda.empty_cache()
            extract_reference(video_path, ref_info, ref_path)

        del pipe
        torch.cuda.empty_cache()
    else:
        print("All single-person references already exist, skipping generation.")

    # ------------------------------------------------------------------
    # Phase 2: Multi-person references from real footage
    # ------------------------------------------------------------------
    multi_pending = [
        r for r in MULTI_PERSON_REFERENCES
        if not (ref_dir / f"{r['id']}.json").exists()
    ]

    if multi_pending:
        print("\n--- Multi-person references (real footage) ---")

        for i, ref_info in enumerate(multi_pending):
            print(f"\n[Multi {i + 1}/{len(multi_pending)}] {ref_info['name']}")

            video_path = multi_video_dir / f"{ref_info['id']}.mp4"
            ref_path = ref_dir / f"{ref_info['id']}.json"

            download_video(ref_info["video_url"], video_path)
            extract_reference(
                video_path, ref_info, ref_path, multi_person=True
            )
    else:
        print("All multi-person references already exist, skipping.")

    # ------------------------------------------------------------------
    # Summary
    # ------------------------------------------------------------------
    print("\nDone! References:")
    for f in sorted(ref_dir.glob("*.json")):
        print(f"  {f.name}")


if __name__ == "__main__":
    main()
