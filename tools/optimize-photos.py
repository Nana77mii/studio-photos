#!/usr/bin/env python3
"""
为 studio-photos 生成响应式衍生图。

对每张原图按长边生成三档 WebP（thumb 600 / frame 1600 / full 3000），
写入 photos/opt/<id>-<tier>.webp，并把三档路径写进 photos/index.json 的
`src` 字段（保留原 `url` 作为向后兼容的回退）。

用法：
    python3 tools/optimize-photos.py --ids mrad3lj9te64 mrab3mzrzsa2 --no-index
    python3 tools/optimize-photos.py --all --write-index
    python3 tools/optimize-photos.py --all --write-index --quality 84
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
import time
from pathlib import Path

from PIL import Image, ImageOps

TIERS = [
    ("thumb", 600),
    ("frame", 1600),
    ("full", 3000),
]

ROOT = Path(__file__).resolve().parent.parent
PHOTOS = ROOT / "photos"
OUT = PHOTOS / "opt"
INDEX = PHOTOS / "index.json"


def human(n: int) -> str:
    return f"{n / 1024 / 1024:.2f} MB" if n >= 1024 * 1024 else f"{n / 1024:.0f} KB"


def variants(src: Path, quality: int) -> tuple[dict[str, Path], tuple[int, int], tuple[int, int]]:
    """生成三档衍生图，返回 {tier: 路径}、原始像素尺寸、纠正方向后的尺寸。"""
    out: dict[str, Path] = {}
    with Image.open(src) as im:
        orig = im.size
        # 手机/相机常把方向记在 EXIF 里，浏览器会自己摆正；我们也必须摆正，
        # 否则衍生图的宽高和 index.json 里的 w/h 对不上。
        fixed = ImageOps.exif_transpose(im)
        size = fixed.size
        for tier, long_edge in TIERS:
            w, h = size
            scale = min(1.0, long_edge / max(w, h))
            nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
            dest = OUT / f"{src.stem}-{tier}.webp"
            resized = fixed if (nw, nh) == size else fixed.resize((nw, nh), Image.LANCZOS)
            resized.save(dest, "WEBP", quality=quality, method=6)
            out[tier] = dest
    return out, orig, size


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ids", nargs="*", help="只处理这些 id")
    ap.add_argument("--all", action="store_true", help="处理清单里的全部照片")
    ap.add_argument("--quality", type=int, default=82)
    ap.add_argument("--write-index", action="store_true", help="把 src 字段写回 index.json")
    ap.add_argument("--no-index", action="store_true", help="只出图，不碰 index.json")
    ap.add_argument("--clean", action="store_true", help="开始前清空 photos/opt")
    args = ap.parse_args()

    records = json.loads(INDEX.read_text())
    by_id = {r["id"]: r for r in records}

    if args.all:
        targets = list(by_id)
    elif args.ids:
        missing = [i for i in args.ids if i not in by_id]
        if missing:
            print(f"清单里没有这些 id: {missing}", file=sys.stderr)
            return 1
        targets = args.ids
    else:
        ap.error("要么 --all，要么 --ids")

    if args.clean and OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True, exist_ok=True)

    total_before = total_after = 0
    mismatch: list[str] = []
    started = time.time()

    for i, pid in enumerate(targets, 1):
        rec = by_id[pid]
        src = PHOTOS / f"{pid}.jpg"
        if not src.exists():
            print(f"跳过 {pid}：找不到 {src.name}")
            continue

        paths, orig, fixed = variants(src, args.quality)
        before = src.stat().st_size
        after = sum(p.stat().st_size for p in paths.values())
        total_before += before
        total_after += after

        declared = (rec.get("w"), rec.get("h"))
        if declared != fixed:
            mismatch.append(f"{pid}: 清单写 {declared}，实际（含方向纠正）是 {fixed}")

        tiers = "  ".join(f"{t} {human(paths[t].stat().st_size):>8}" for t, _ in TIERS)
        print(f"[{i:>2}/{len(targets)}] {pid}  {human(before):>9} -> {human(after):>8}  |  {tiers}")

        if args.write_index and not args.no_index:
            # 相对路径：本地 http.server 预览和 GitHub Pages 项目站点都能正确解析，
            # 不像绝对 raw 地址那样把本地预览也钉在线上。
            rec["src"] = {t: f"photos/opt/{paths[t].name}" for t, _ in TIERS}
            rec["w"], rec["h"] = fixed

    elapsed = time.time() - started
    saved = total_before - total_after
    pct = (saved / total_before * 100) if total_before else 0
    print(f"\n合计：{human(total_before)} -> {human(total_after)}"
          f"  （省 {human(saved)}，{pct:.0f}%），耗时 {elapsed:.1f}s")

    if mismatch:
        print("\n宽高不一致（已按实际值纠正）：")
        for m in mismatch:
            print("  " + m)

    if args.write_index and not args.no_index:
        INDEX.write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
        print(f"\n已写回 {INDEX.relative_to(ROOT)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
