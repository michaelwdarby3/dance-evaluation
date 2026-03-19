#!/usr/bin/env python3
"""Generate a short video of a person dancing using ModelScope text-to-video.

Usage:
    python tools/generate_dance_video.py [--prompt "..."] [--output path.mp4] [--frames 16]

Requires: diffusers, torch, PIL
GPU: ~7GB VRAM (RTX 3070 compatible)
"""

import argparse
import subprocess
import tempfile
from pathlib import Path

import numpy as np
import torch
from diffusers import DiffusionPipeline


def main():
    parser = argparse.ArgumentParser(description="Generate dance test videos")
    parser.add_argument(
        "--prompt",
        default="a person dancing hip hop in a studio, full body visible, good lighting",
        help="Text prompt for video generation",
    )
    parser.add_argument(
        "--output",
        default="assets/test_videos/dance_test.mp4",
        help="Output video path",
    )
    parser.add_argument(
        "--frames", type=int, default=16, help="Number of frames to generate"
    )
    parser.add_argument(
        "--width", type=int, default=256, help="Video width"
    )
    parser.add_argument(
        "--height", type=int, default=256, help="Video height"
    )
    args = parser.parse_args()

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    print("Loading ModelScope text-to-video pipeline...")
    pipe = DiffusionPipeline.from_pretrained(
        "ali-vilab/text-to-video-ms-1.7b",
        torch_dtype=torch.float16,
        variant="fp16",
    )
    pipe.enable_attention_slicing()
    pipe.enable_model_cpu_offload()  # moves modules to GPU only when needed

    print(f"Generating {args.frames} frames: '{args.prompt}'")
    with torch.no_grad():
        result = pipe(
            args.prompt,
            num_frames=args.frames,
            width=args.width,
            height=args.height,
            num_inference_steps=10,
        )

    video_frames = result.frames[0]  # List of PIL Images

    # Free GPU memory before saving
    del pipe
    torch.cuda.empty_cache()
    print(f"Got {len(video_frames)} frames, saving...")

    # Save frames as PNGs, then stitch with ffmpeg.
    from PIL import Image

    with tempfile.TemporaryDirectory() as tmpdir:
        for i, frame in enumerate(video_frames):
            if isinstance(frame, np.ndarray):
                frame_uint8 = (frame * 255).clip(0, 255).astype(np.uint8)
                Image.fromarray(frame_uint8).save(f"{tmpdir}/frame_{i:04d}.png")
            else:
                frame.save(f"{tmpdir}/frame_{i:04d}.png")
        print(f"Saved {len(video_frames)} PNGs to temp dir")

        # Find the imageio-bundled ffmpeg.
        import imageio_ffmpeg
        ffmpeg_bin = imageio_ffmpeg.get_ffmpeg_exe()

        cmd = [
            ffmpeg_bin, "-y",
            "-framerate", "8",
            "-i", f"{tmpdir}/frame_%04d.png",
            "-c:v", "libx264",
            "-pix_fmt", "yuv420p",
            "-crf", "23",
            str(output),
        ]
        print(f"Running ffmpeg...")
        subprocess.run(cmd, check=True, capture_output=True)

    print(f"Saved to {output} ({len(video_frames)} frames)")


if __name__ == "__main__":
    main()
