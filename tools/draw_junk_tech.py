#!/usr/bin/env python3
"""Rectify licensed electronics photographs into 64px RGB cube faces."""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance

from draw_junk_cubes import DESTINATION, SIZE, photograph


def project(photo, preview_width, corners, inset=0):
    scale = photo.width / preview_width
    far = SIZE - inset
    target = ((inset, inset), (inset, far), (far, far), (far, inset))
    matrix, values = [], []
    for (x, y), (u, v) in zip(target, corners):
        u, v = u * scale, v * scale
        matrix.extend(((x, y, 1, 0, 0, 0, -u*x, -u*y), (0, 0, 0, x, y, 1, -v*x, -v*y)))
        values.extend((u, v))
    coeffs = np.linalg.solve(matrix, values)
    return photo.transform((SIZE, SIZE), Image.Transform.PERSPECTIVE, coeffs, Image.Resampling.BICUBIC)


def fuse_rows(photo):
    preview = photo.resize((230, 450), Image.Resampling.LANCZOS)
    segment = preview.crop((190, 154, 222, 228)).rotate(90, expand=True)
    segment = segment.resize((57, 18), Image.Resampling.LANCZOS)
    image = Image.new("RGB", (SIZE, SIZE), "#46494a")
    for y in (2, 23, 44):
        image.paste(segment, (3, y))
    return image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("photos", type=Path)
    args = parser.parse_args()

    def read(name):
        return photograph(args.photos / f"{name}.jpg")

    tiles = {
        "motherboard": project(read("chip-macro"), 450, ((173,91), (134,211), (284,225), (313,104)), 16),
        "chips": project(read("chips"), 350, ((18,108), (20,251), (330,201), (328,55))),
        "blade-fuses": project(read("blade-fuses"), 350, ((86,50), (76,149), (233,165), (248,67))),
        "heat-sink": project(read("heat-flat"), 450, ((74,198), (113,374), (384,325), (429,151))),
        "ribbon": project(read("ribbon"), 350, ((7,59), (7,257), (344,257), (344,59))),
        "glass-fuses": fuse_rows(read("glass-fuses")),
    }
    for name, tile in tiles.items():
        ImageEnhance.Brightness(tile).enhance(1.08).save(DESTINATION / f"tech-{name}.png", optimize=True)


if __name__ == "__main__":
    main()
