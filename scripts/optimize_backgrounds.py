#!/usr/bin/env python3
"""
optimize_backgrounds.py

Batch-resizes and compresses background images for Wasteland Echoes.
Converts to JPEG (quality 82, resized to a max dimension of 1600px) by
default - matches every background already in the project. Use --png
for assets that need transparency (logos, UI icons), which quantizes
instead of converting format.

Requirements:
    pip install Pillow

Usage:
    # Process every image in a folder, save results into assets/backgrounds/
    python3 optimize_backgrounds.py ~/Downloads/new_backgrounds assets/backgrounds

    # A single file
    python3 optimize_backgrounds.py ~/Downloads/day6_something.png assets/backgrounds

    # Keep transparency (for logos/UI, not story backgrounds)
    python3 optimize_backgrounds.py ~/Downloads/new_logo.png assets/ui --png

    # Custom size/quality
    python3 optimize_backgrounds.py ~/Downloads/new_backgrounds assets/backgrounds --max-dim 1400 --quality 78

Output filenames match the input filenames (extension swapped to .jpg
unless --png is used) - so name your generated images to match the
"imageName" field in data/prompts.json BEFORE running this script,
e.g. day6_something.png -> day6_something.jpg
"""

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Pillow isn't installed. Run: pip install Pillow", file=sys.stderr)
    sys.exit(1)

VALID_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".tiff", ".bmp"}


def process_image(src: Path, out_dir: Path, max_dim: int, quality: int, keep_png: bool) -> None:
    try:
        img = Image.open(src)
    except Exception as e:
        print(f"  SKIP {src.name}: couldn't open ({e})")
        return

    before_size = src.stat().st_size
    w, h = img.size
    if max(w, h) > max_dim:
        scale = max_dim / max(w, h)
        img = img.resize((int(w * scale), int(h * scale)), Image.LANCZOS)

    out_dir.mkdir(parents=True, exist_ok=True)

    if keep_png:
        out_path = out_dir / f"{src.stem}.png"
        if img.mode != "RGBA":
            img = img.convert("RGBA")
        # Palette quantization keeps alpha but shrinks file size a lot for
        # flat/painted art. Safe for logos and UI graphics; skip it if a
        # given image looks banded afterward and re-save without this line.
        img = img.quantize(colors=256, method=Image.Quantize.FASTOCTREE,
                            dither=Image.Dither.FLOYDSTEINBERG)
        img.save(out_path, optimize=True)
    else:
        out_path = out_dir / f"{src.stem}.jpg"
        img = img.convert("RGB")
        img.save(out_path, "JPEG", quality=quality, optimize=True)

    after_size = out_path.stat().st_size
    pct = (1 - after_size / before_size) * 100 if before_size else 0
    print(f"  {src.name:<40} {before_size/1024:>8.0f}K -> {after_size/1024:>8.0f}K  ({pct:.0f}% smaller)")


def main():
    ap = argparse.ArgumentParser(description="Optimize background/UI images for Wasteland Echoes.")
    ap.add_argument("source", help="A single image file or a folder of images")
    ap.add_argument("out_dir", help="Output folder, e.g. assets/backgrounds")
    ap.add_argument("--max-dim", type=int, default=1600, help="Max width/height in pixels (default: 1600)")
    ap.add_argument("--quality", type=int, default=82, help="JPEG quality 1-100 (default: 82)")
    ap.add_argument("--png", action="store_true", help="Keep as PNG with transparency instead of converting to JPEG")
    args = ap.parse_args()

    src_path = Path(args.source).expanduser()
    out_dir = Path(args.out_dir).expanduser()

    if src_path.is_file():
        files = [src_path]
    elif src_path.is_dir():
        files = sorted(f for f in src_path.iterdir() if f.suffix.lower() in VALID_EXTENSIONS)
    else:
        print(f"Not found: {src_path}", file=sys.stderr)
        sys.exit(1)

    if not files:
        print("No images found.")
        return

    print(f"Processing {len(files)} image(s) -> {out_dir}\n")
    for f in files:
        process_image(f, out_dir, args.max_dim, args.quality, args.png)
    print("\nDone.")


if __name__ == "__main__":
    main()
