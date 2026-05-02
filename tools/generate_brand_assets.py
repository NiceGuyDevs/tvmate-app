"""
Generate launcher mipmaps, adaptive foreground, native splash, and Flutter assets.
Requires: pip install pillow
Run from repo root: python tools/generate_brand_assets.py

Place your master branding PNG at: assets/images/IpTvIl.png
"""
from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Install Pillow: pip install pillow", file=sys.stderr)
    sys.exit(1)

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "images" / "IpTvIl.png"
RES = ROOT / "android" / "app" / "src" / "main" / "res"
ASSETS_IMG = ROOT / "assets" / "images"

MIPMAP_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def crop_launcher_icon(im: Image.Image) -> Image.Image:
    """
    Square launcher crop: centered on the left ~38% of the art (TV mascot),
    not a full-height strip — avoids ugly squashing on Shield circles.
    """
    w, h = im.size
    region_w = min(int(w * 0.38), h)
    cx = int(w * 0.19)
    left = max(0, cx - region_w // 2)
    left = min(left, max(0, w - region_w))
    top = max(0, (h - region_w) // 2)
    box = (left, top, left + region_w, top + region_w)
    return im.crop(box).resize((1024, 1024), Image.Resampling.LANCZOS)


def adaptive_foreground(icon1024: Image.Image) -> Image.Image:
    """432px adaptive safe area — icon ~72% width, centered on transparency."""
    size = 432
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inset = int(size * 0.72)
    scaled = icon1024.resize((inset, inset), Image.Resampling.LANCZOS)
    ox = (size - inset) // 2
    oy = (size - inset) // 2
    out.paste(scaled, (ox, oy), scaled)
    return out


def main() -> None:
    if not SRC.is_file():
        print(f"Missing source image: {SRC}", file=sys.stderr)
        print("Copy your branding PNG to assets/images/IpTvIl.png then re-run.", file=sys.stderr)
        sys.exit(1)

    im = Image.open(SRC).convert("RGBA")
    icon_master = crop_launcher_icon(im)

    for folder, px in MIPMAP_SIZES.items():
        out_dir = RES / folder
        out_dir.mkdir(parents=True, exist_ok=True)
        out = icon_master.resize((px, px), Image.Resampling.LANCZOS)
        out.save(out_dir / "ic_launcher.png", format="PNG")

    nodpi = RES / "drawable-nodpi"
    nodpi.mkdir(parents=True, exist_ok=True)
    adaptive_foreground(icon_master).save(nodpi / "ic_launcher_fg.png", format="PNG")

    max_w = 1920
    splash_src = im.copy()
    if splash_src.width > max_w:
        r = max_w / splash_src.width
        splash_src = splash_src.resize(
            (max_w, int(splash_src.height * r)),
            Image.Resampling.LANCZOS,
        )
    splash_src.save(nodpi / "branding_logo.png", format="PNG")
    ASSETS_IMG.mkdir(parents=True, exist_ok=True)
    splash_src.save(ASSETS_IMG / "splash_logo.png", format="PNG")

    print("OK: mipmap-*/ic_launcher.png")
    print("OK: drawable-nodpi/ic_launcher_fg.png (adaptive foreground)")
    print("OK: drawable-nodpi/branding_logo.png (native splash)")
    print("OK: assets/images/splash_logo.png (Flutter splash)")
    print("Note: TV home banner — run python tools/adjust_tvmate_tv_banner.py (does not touch splash)")


if __name__ == "__main__":
    main()
