#!/usr/bin/env python3
"""Composite the junk cube's 64px faces from CC0 color maps and original marks."""
import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageOps

SIZE = 64
DESTINATION = Path(__file__).resolve().parents[1] / "assets/quarry-textures/junk"


def material(path, dark, light):
    source = Image.open(path).convert("L")
    crop = source.crop((64, 64, 576, 576)).resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    return ImageOps.colorize(ImageOps.autocontrast(crop, cutoff=2), dark, light)


def panel(draw, edge, line):
    draw.rectangle((0, 0, 63, 63), outline=edge, width=2)
    draw.line((2, 61, 2, 2, 61, 2), fill=line)


def screws(draw, points, dark, light):
    for x, y in points:
        draw.ellipse((x-1, y-1, x+2, y+2), fill=dark)
        draw.point((x, y), fill=light)


def plywood(source):
    body = material(source, "#a77343", "#ddba82")
    draw = ImageDraw.Draw(body)
    panel(draw, "#9e693d", "#e6c293")
    screws(draw, ((6, 6), (56, 6), (6, 56), (56, 56)), "#674b34", "#c4a47b")
    front, top = body.copy(), body.copy()
    draw = ImageDraw.Draw(front)
    draw.rectangle((9, 23, 54, 39), fill="#cfaf7a", outline="#8c6748")
    draw.text((32, 31), "SUGGEST", fill="#553c2d", anchor="mm")
    draw = ImageDraw.Draw(top)
    draw.rounded_rectangle((12, 29, 51, 35), radius=2, fill="#402d23")
    draw.line((14, 36, 49, 36), fill="#edc89a")
    return {"front": front, "top": top, "side": body}


def photograph(path):
    return ImageOps.exif_transpose(Image.open(path)).convert("RGB")


def crop(photo, bounds, preview_width):
    scale = photo.width / preview_width
    return photo.crop(tuple(round(x * scale) for x in bounds)).resize(
        (SIZE, SIZE), Image.Resampling.LANCZOS)


def face(photo, corners, preview_width):
    scale = photo.width / preview_width
    points = [value * scale for point in corners for value in point]
    return photo.transform((SIZE, SIZE), Image.Transform.QUAD, points, Image.Resampling.BICUBIC)


def gumballs(photo):
    left = (photo.width - photo.height) // 2
    tile = photo.crop((left, 0, left + photo.height, photo.height))
    tile = tile.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    return {"tile": ImageEnhance.Brightness(tile).enhance(1.16)}


def alphabet(photo):
    # Rectify individual wooden block faces from the photographed stack.
    return {
        "front": face(photo, ((283, 134), (282, 163), (312, 165), (315, 137)), 560),
        "side": face(photo, ((278, 199), (276, 235), (309, 238), (311, 203)), 560),
        "top": face(photo, ((320, 97), (317, 136), (354, 140), (357, 102)), 560),
    }


def fan(photo):
    front = face(photo, ((2, 49), (10, 306), (270, 294), (258, 41)), 560)
    side = crop(photo, (298, 43, 523, 51), 560)
    top = crop(photo, (314, 29, 502, 46), 560)
    return {"front": front, "side": side, "top": top}


def aquarium(photo):
    front = crop(photo, (100, 15, 315, 224), 340)
    side = crop(photo, (0, 4, 130, 214), 340)
    top = ImageEnhance.Color(crop(photo, (9, 7, 93, 58), 340)).enhance(.65)
    for image in (front, side, top):
        panel(ImageDraw.Draw(image), "#425b57", "#a2bfac")
    return {"front": front, "side": side, "top": top}


def ice(photo, key_photo):
    body = crop(photo, (33, 48, 198, 213), 232)
    key = key_photo.crop((100, 153, 1745, 997)).convert("RGBA")
    alpha = Image.new("L", key.size)
    alpha.putdata([max(0, min(215, (r - b - 20) * 13)) for r, _, b, _ in key.get_flattened_data()])
    key.putalpha(alpha)
    key.thumbnail((42, 26), Image.Resampling.LANCZOS)
    key = key.rotate(24, Image.Resampling.BICUBIC, expand=True)
    front = body.copy()
    front.paste(key, ((SIZE-key.width)//2, (SIZE-key.height)//2), key)
    front = Image.blend(front, body, .13)
    return {"front": front, "side": body}


def tickets(photo):
    front = face(photo, ((67, 98), (31, 246), (199, 272), (235, 115)), 560)
    side = face(photo, ((171, 125), (153, 244), (493, 195), (510, 57)), 560)
    return {"front": front, "side": side}


def moving_box(source):
    side = material(source, "#946441", "#cc9a65")
    draw = ImageDraw.Draw(side)
    panel(draw, "#8c613f", "#d2a87c")
    draw.rounded_rectangle((20, 10, 43, 15), radius=2, fill="#684632")
    front = side.copy()
    draw = ImageDraw.Draw(front)
    draw.text((9, 28), "KITCHEN", fill="#795238")
    draw.line((8, 31, 50, 28), fill="#623f2d", width=2)
    draw.text((14, 39), "ROCKS", fill="#503b2d")
    top = side.rotate(90)
    draw = ImageDraw.Draw(top)
    draw.rectangle((27, 0, 37, 63), fill="#bd9561")
    draw.line((31, 0, 31, 63), fill="#9b764c")
    draw.line((27, 0, 27, 63), fill="#d5a975")
    return {"front": front, "side": side, "top": top}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plywood", type=Path, help="Poly Haven Plywood diffuse JPEG")
    parser.add_argument("cardboard", type=Path, help="ambientCG Paper005 Color JPEG")
    parser.add_argument("photos", type=Path, help="Folder containing the licensed source photographs")
    args = parser.parse_args()

    def photo(name):
        return photograph(args.photos / (name + ".jpg"))
    DESTINATION.mkdir(parents=True, exist_ok=True)
    objects = {
        "suggestion-box": plywood(args.plywood),
        "gumballs": gumballs(photo("gumballs-haribo")),
        "alphabet-block": alphabet(photo("alphabet")),
        "box-fan": fan(photo("fan")),
        "cube-aquarium": aquarium(photo("fish")),
        "ice-cube": ice(photo("ice"), photo("key")),
        "ticket-box": tickets(photo("ticket")),
        "moving-box": moving_box(args.cardboard),
    }
    for name, faces in objects.items():
        for face, image in faces.items():
            image.save(DESTINATION / f"{name}-{face}.png", optimize=True)
