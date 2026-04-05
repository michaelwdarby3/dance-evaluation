#!/usr/bin/env python3
"""Generate realistic dance videos from reference choreography JSON files.

Uses ControlNet (OpenPose) + AnimateDiff to generate pose-conditioned video,
or falls back to skeleton-only rendering without GPU.

VRAM optimization strategy (current target: RTX 3070, 8GB):
    The pipeline applies several memory optimizations to fit in 8GB VRAM.
    These are documented inline with "VRAM NOTE" comments. If upgrading to a
    larger GPU (24GB+) or cloud instance (A100/H100), search for those notes
    to identify what can be removed or relaxed for faster generation:
    - xformers memory-efficient attention → can remove, standard attention is fine
    - Tiled VAE decoding → can remove, full-frame decode is faster
    - 8-bit quantization (bitsandbytes) → can use float16 or even float32
    - Model CPU offload → can use .to("cuda") to keep everything on GPU
    - VAE slicing → can remove, decode all frames at once

Usage:
    # AI-generated video (requires GPU)
    python tools/generate_reference_videos.py -r assets/references/hip_hop_basic.json

    # Skeleton-only (no GPU needed)
    python tools/generate_reference_videos.py --all --skeleton-only

    # Batch all references with AI
    python tools/generate_reference_videos.py --all
"""

import argparse
import gc
import subprocess
import tempfile
from pathlib import Path

import cv2
import numpy as np

from openpose_renderer import (
    blazepose_to_openpose,
    load_reference,
    render_openpose_frame,
    render_skeleton_video,
    save_skeleton_video,
)

# ---------------------------------------------------------------------------
# Style-specific prompts for Stable Diffusion
# ---------------------------------------------------------------------------
STYLE_PROMPTS = {
    "hipHop": "a person dancing hip hop in a bright studio, full body, sharp movements, dynamic pose",
    "kPop": "a person performing kpop choreography in a practice room, full body, precise movements",
    "rnb": "a person dancing R&B in a studio, full body, smooth fluid movements, graceful",
    "contemporary": "a person performing contemporary dance in a studio, full body, expressive movements",
    "jazz": "a person dancing jazz in a studio, full body, energetic sharp movements",
    "ballet": "a person performing ballet in a studio, full body, elegant precise movements",
    "breaking": "a person breakdancing in a studio, full body, athletic dynamic movements",
    "latin": "a person dancing salsa in a studio, full body, rhythmic hip movements",
}

DEFAULT_PROMPT = "a person dancing in a bright studio, full body visible, good lighting"
NEGATIVE_PROMPT = "blurry, low quality, distorted, extra limbs, disfigured, watermark, text, deformed"

# AnimateDiff context window
CHUNK_SIZE = 16
OVERLAP = 4


def get_prompt(style: str) -> str:
    """Get style-specific generation prompt."""
    return STYLE_PROMPTS.get(style, DEFAULT_PROMPT)


def find_references(ref_dir: str | Path) -> list[Path]:
    """Find all reference JSON files in a directory."""
    ref_dir = Path(ref_dir)
    return sorted(ref_dir.glob("*.json"))


def render_conditioning_frames(
    reference: dict, width: int, height: int, fps: int
) -> list[np.ndarray]:
    """Render OpenPose conditioning images from a reference."""
    return render_skeleton_video(reference, width, height, fps)


def blend_chunks(
    chunks: list[list[np.ndarray]], overlap: int
) -> list[np.ndarray]:
    """Blend overlapping chunks with linear interpolation.

    Args:
        chunks: List of frame lists, each chunk having CHUNK_SIZE frames.
        overlap: Number of overlapping frames between consecutive chunks.

    Returns:
        Single list of blended frames.
    """
    if not chunks:
        return []
    if len(chunks) == 1:
        return chunks[0]

    result = list(chunks[0])

    for chunk_idx in range(1, len(chunks)):
        chunk = chunks[chunk_idx]
        # Blend the overlap region
        for i in range(overlap):
            alpha = (i + 1) / (overlap + 1)
            blended = (
                result[-(overlap - i)] * (1 - alpha) + chunk[i] * alpha
            ).astype(np.uint8)
            result[-(overlap - i)] = blended
        # Append the non-overlapping tail
        result.extend(chunk[overlap:])

    return result


def _check_optional_deps() -> dict[str, bool]:
    """Check which optional VRAM-saving dependencies are available."""
    available = {}
    try:
        import xformers  # noqa: F401
        available["xformers"] = True
    except ImportError:
        available["xformers"] = False
    try:
        import bitsandbytes  # noqa: F401
        available["bitsandbytes"] = True
    except ImportError:
        available["bitsandbytes"] = False
    return available


def _apply_vram_optimizations(pipe, deps: dict[str, bool]) -> None:
    """Apply memory optimizations based on available libraries.

    VRAM NOTE: All of these exist to fit in 8GB. On 24GB+ GPUs, you can skip
    this entire function and just do pipe.to("cuda") for maximum speed.
    """
    # VRAM NOTE: xformers replaces standard attention with a memory-efficient
    # implementation (~1-2GB savings). On 24GB+ GPU, standard attention is fine
    # and marginally faster for small batch sizes.
    if deps.get("xformers"):
        pipe.enable_xformers_memory_efficient_attention()
        print("  [VRAM] xformers memory-efficient attention: enabled")
    else:
        print("  [VRAM] xformers not installed, using default attention")

    # VRAM NOTE: Tiled VAE decodes latents in spatial tiles instead of all at
    # once (~1GB savings). Remove on 24GB+ GPUs for faster decode.
    pipe.enable_vae_tiling()
    print("  [VRAM] Tiled VAE decoding: enabled")

    # VRAM NOTE: VAE slicing processes frames one at a time through the VAE
    # instead of batching. Remove on 24GB+ GPUs.
    pipe.enable_vae_slicing()
    print("  [VRAM] VAE slicing: enabled")

    # VRAM NOTE: CPU offload moves each pipeline component (UNet, VAE,
    # ControlNet, text encoder) to GPU only when active, then back to CPU.
    # This is the single biggest VRAM saver but also the biggest speed cost.
    # On 24GB+ GPUs, replace with pipe.to("cuda") for ~3-4x speedup.
    pipe.enable_model_cpu_offload()
    print("  [VRAM] Model CPU offload: enabled")


def _load_controlnet_quantized(model_id: str, use_8bit: bool):
    """Load ControlNet, optionally with 8-bit quantization.

    VRAM NOTE: 8-bit quantization via bitsandbytes cuts model weights memory
    roughly in half with minor quality loss. On 24GB+ GPUs, load with
    torch_dtype=torch.float16 (or float32) instead for best quality.
    """
    import torch
    from diffusers import ControlNetModel

    if use_8bit:
        try:
            from diffusers import BitsAndBytesConfig
            quantization_config = BitsAndBytesConfig(load_in_8bit=True)
            print("  [VRAM] Loading ControlNet in 8-bit (bitsandbytes)")
            return ControlNetModel.from_pretrained(
                model_id,
                quantization_config=quantization_config,
                torch_dtype=torch.float16,
            )
        except (ImportError, Exception) as e:
            print(f"  [VRAM] 8-bit ControlNet failed ({e}), falling back to float16")

    return ControlNetModel.from_pretrained(model_id, torch_dtype=torch.float16)


def generate_ai_video(
    reference: dict,
    output_path: Path,
    width: int = 512,
    height: int = 512,
    fps: int = 8,
    num_inference_steps: int = 20,
    controlnet_scale: float = 0.8,
    seed: int | None = None,
) -> None:
    """Generate an AI video using ControlNet + AnimateDiff.

    Applies aggressive VRAM optimizations for 8GB GPUs. See module docstring
    and inline "VRAM NOTE" comments for what to change on larger hardware.

    Args:
        reference: Loaded reference choreography dict.
        output_path: Path for the output MP4.
        width: Frame width.
        height: Frame height.
        fps: Output FPS.
        num_inference_steps: Diffusion denoising steps.
        controlnet_scale: ControlNet conditioning scale.
        seed: Random seed for reproducibility.
    """
    import torch
    from diffusers import (
        AnimateDiffControlNetPipeline,
        DDIMScheduler,
        MotionAdapter,
    )
    from PIL import Image

    deps = _check_optional_deps()
    print(f"Optional deps: xformers={'yes' if deps['xformers'] else 'no'}, "
          f"bitsandbytes={'yes' if deps['bitsandbytes'] else 'no'}")

    style = reference.get("style", "")
    prompt = get_prompt(style)
    print(f"Prompt: {prompt}")

    # Render conditioning frames
    print("Rendering OpenPose conditioning frames...")
    cond_frames = render_conditioning_frames(reference, width, height, fps)
    total_frames = len(cond_frames)
    print(f"Total conditioning frames: {total_frames}")

    # Load pipeline components
    print("Loading motion adapter...")
    motion_adapter = MotionAdapter.from_pretrained(
        "guoyww/animatediff-motion-adapter-v1-5-3",
        torch_dtype=torch.float16,
    )

    # VRAM NOTE: ControlNet is one of the larger models. 8-bit quantization
    # saves ~500MB VRAM here. Use float16 on 24GB+ GPUs.
    print("Loading ControlNet...")
    controlnet = _load_controlnet_quantized(
        "lllyasviel/control_v11p_sd15_openpose",
        use_8bit=deps["bitsandbytes"],
    )

    print("Loading AnimateDiff + ControlNet pipeline...")
    pipe = AnimateDiffControlNetPipeline.from_pretrained(
        "runwayml/stable-diffusion-v1-5",
        motion_adapter=motion_adapter,
        controlnet=controlnet,
        torch_dtype=torch.float16,
        variant="fp16",
    )
    pipe.scheduler = DDIMScheduler.from_config(
        pipe.scheduler.config,
        beta_schedule="linear",
        clip_sample=False,
        timestep_spacing="linspace",
        steps_offset=1,
    )

    # Apply VRAM optimizations
    print("Applying VRAM optimizations...")
    _apply_vram_optimizations(pipe, deps)

    generator = torch.Generator(device="cpu")
    if seed is not None:
        generator.manual_seed(seed)

    # Chunked generation
    stride = CHUNK_SIZE - OVERLAP
    chunks_needed = max(1, (total_frames - OVERLAP + stride - 1) // stride)
    print(f"Generating {chunks_needed} chunk(s) of {CHUNK_SIZE} frames...")

    generated_chunks = []
    for chunk_idx in range(chunks_needed):
        start = chunk_idx * stride
        end = min(start + CHUNK_SIZE, total_frames)
        chunk_cond = cond_frames[start:end]

        # Pad to CHUNK_SIZE if needed (last chunk may be shorter)
        while len(chunk_cond) < CHUNK_SIZE:
            chunk_cond.append(chunk_cond[-1])

        # Convert to PIL images (RGB)
        cond_pil = [Image.fromarray(cv2.cvtColor(f, cv2.COLOR_BGR2RGB)) for f in chunk_cond]

        print(f"  Chunk {chunk_idx + 1}/{chunks_needed} (frames {start}-{end - 1})...")

        with torch.no_grad():
            result = pipe(
                prompt=prompt,
                negative_prompt=NEGATIVE_PROMPT,
                num_frames=CHUNK_SIZE,
                conditioning_frames=cond_pil,
                width=width,
                height=height,
                num_inference_steps=num_inference_steps,
                controlnet_conditioning_scale=controlnet_scale,
                generator=generator,
            )

        # Extract frames as numpy arrays (BGR)
        chunk_frames = []
        for frame in result.frames[0]:
            if isinstance(frame, np.ndarray):
                arr = (frame * 255).clip(0, 255).astype(np.uint8)
            else:
                arr = np.array(frame)
            chunk_frames.append(cv2.cvtColor(arr, cv2.COLOR_RGB2BGR))

        # Trim padding from last chunk
        actual_len = end - start
        generated_chunks.append(chunk_frames[:actual_len])

    # Free GPU memory
    del pipe, controlnet, motion_adapter
    gc.collect()
    torch.cuda.empty_cache()

    # Blend chunks
    print("Blending chunks...")
    final_frames = blend_chunks(generated_chunks, OVERLAP)

    # Trim to exact frame count
    final_frames = final_frames[:total_frames]

    # Save to MP4
    _save_video(final_frames, output_path, fps)
    print(f"Saved AI video: {output_path} ({len(final_frames)} frames @ {fps} fps)")


def _save_video(frames: list[np.ndarray], output_path: Path, fps: int) -> None:
    """Save frames to MP4 using ffmpeg."""
    import imageio_ffmpeg

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


def main():
    parser = argparse.ArgumentParser(
        description="Generate dance videos from reference choreography JSON files"
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("-r", "--reference", help="Path to a single reference JSON")
    group.add_argument(
        "--all", action="store_true", help="Process all references in assets/references/"
    )
    parser.add_argument(
        "--skeleton-only",
        action="store_true",
        help="Render skeleton-only video (no GPU needed)",
    )
    parser.add_argument("--width", type=int, default=512, help="Frame width (default: 512)")
    parser.add_argument("--height", type=int, default=512, help="Frame height (default: 512)")
    parser.add_argument("--fps", type=int, default=8, help="Output FPS (default: 8)")
    parser.add_argument(
        "--steps", type=int, default=20, help="Diffusion inference steps (default: 20)"
    )
    parser.add_argument(
        "--controlnet-scale",
        type=float,
        default=0.8,
        help="ControlNet conditioning scale (default: 0.8)",
    )
    parser.add_argument("--seed", type=int, default=None, help="Random seed")
    parser.add_argument(
        "--output-dir",
        default="assets/reference_videos",
        help="Output directory (default: assets/reference_videos/)",
    )
    args = parser.parse_args()

    # Determine which references to process
    if args.all:
        ref_dir = Path(__file__).parent.parent / "assets" / "references"
        ref_paths = find_references(ref_dir)
        if not ref_paths:
            print(f"No reference JSON files found in {ref_dir}")
            return
        print(f"Found {len(ref_paths)} references")
    else:
        ref_paths = [Path(args.reference)]

    output_dir = Path(args.output_dir)

    for ref_path in ref_paths:
        print(f"\n{'='*60}")
        print(f"Processing: {ref_path.name}")
        print(f"{'='*60}")

        reference = load_reference(ref_path)
        ref_id = reference.get("id", ref_path.stem)

        if args.skeleton_only:
            output_path = output_dir / f"{ref_id}.mp4"
            frames = render_skeleton_video(reference, args.width, args.height, args.fps)
            print(f"Rendered {len(frames)} skeleton frames")
            save_skeleton_video(frames, output_path, args.fps)
        else:
            output_path = output_dir / f"{ref_id}.mp4"
            generate_ai_video(
                reference,
                output_path,
                width=args.width,
                height=args.height,
                fps=args.fps,
                num_inference_steps=args.steps,
                controlnet_scale=args.controlnet_scale,
                seed=args.seed,
            )

    print(f"\nDone! Videos saved to {output_dir}/")


if __name__ == "__main__":
    main()
