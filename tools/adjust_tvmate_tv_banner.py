"""
Resize the TVMate.Pro master art for Android TV **banner only** (16:9).

Does **not** touch the loading splash — that comes from **`tools/generate_brand_assets.py`**
(`IpTvIl.png` → `branding_logo.png` / `splash_logo.png`).

Place the source PNG at: assets/images/tvmate_pro_brand_master.png
Run from repo root: python tools/adjust_tvmate_tv_banner.py

Writes:
  - drawable-nodpi/tv_banner_logo.png — 1920×1080, letterboxed on black (Leanback row)
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
SRC = ROOT / "assets" / "images" / "tvmate_pro_brand_master.png"
RES = ROOT / "android" / "app" / "src" / "main" / "res"
NODPI = RES / "drawable-nodpi"

BANNER_W, BANNER_H = 1920, 1080


def main() -> None:
    if not SRC.is_file():
        print(f"Missing: {SRC}", file=sys.stderr)
        sys.exit(1)

    im = Image.open(SRC).convert("RGBA")
    w, h = im.size

    NODPI.mkdir(parents=True, exist_ok=True)

    scale = min(BANNER_W / w, BANNER_H / h)
    nw, nh = int(w * scale), int(h * scale)
    scaled = im.resize((nw, nh), Image.Resampling.LANCZOS)
    banner = Image.new("RGBA", (BANNER_W, BANNER_H), (0, 0, 0, 255))
    banner.paste(scaled, ((BANNER_W - nw) // 2, (BANNER_H - nh) // 2), scaled)
    banner.save(NODPI / "tv_banner_logo.png", format="PNG", optimize=True)

    print("OK: drawable-nodpi/tv_banner_logo.png (16:9)")


if __name__ == "__main__":
    main()
