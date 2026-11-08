#!/usr/bin/env python3
"""Composite the junk cube's 64px faces from CC0 color maps and original marks."""
import argparse
from pathlib import Path
from random import Random

from PIL import Image, ImageDraw, ImageOps

SIZE = 64
DESTINATION = Path(__file__).resolve().parents[1] / "assets/quarry-textures/junk"


def surface(color, seed=21, grain=6):
    rng = Random(seed)
    image = Image.new("RGB", (SIZE, SIZE))
    pixels = []
    for y in range(SIZE):
        for x in range(SIZE):
            edge = -10 if min(x, y, 63 - x, 63 - y) < 2 else 0
            shift = rng.randint(-grain, grain) + edge
            pixels.append(tuple(max(0, min(255, value + shift)) for value in color))
    image.putdata(pixels)
    return image


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


def dispenser():
    body = surface((162, 54, 54))
    draw = ImageDraw.Draw(body)
    panel(draw, "#7a3034", "#d37a71")
    window = body.copy()
    draw = ImageDraw.Draw(window)
    draw.rectangle((5, 5, 58, 43), fill="#6d9390", outline="#5a3035", width=2)
    palette = (("#e36a50", "#ffb18e"), ("#ffcb51", "#fff0a6"), ("#69b4c9", "#b8eaf4"),
               ("#a7bd58", "#e7ed9b"), ("#dc80b1", "#ffd0e6"), ("#e7dbb9", "#fff9e5"))
    for row, offsets in enumerate(((13, 26, 39, 51), (10, 20, 32, 44, 54), (13, 26, 39, 51))):
        for i, x in enumerate(offsets):
            y = 16 + row*10 + (i % 2)
            color, highlight = palette[(row*3+i*5) % len(palette)]
            draw.ellipse((x-5, y-5, x+5, y+5), fill=color, outline="#744c4d")
            draw.ellipse((x-3, y-3, x, y-1), fill=highlight)
    draw.line((8, 38, 8, 8, 55, 8), fill="#d7e6d7", width=2)
    side = window.copy()
    draw.rectangle((12, 47, 28, 59), fill="#b4b6a7", outline="#633b3e")
    draw.line((16, 52, 23, 52), fill="#434747", width=2)
    draw.rounded_rectangle((35, 47, 52, 59), radius=2, fill="#542c34", outline="#e4a285")
    draw.ellipse((42, 52, 48, 58), fill="#66afd1")
    top = body.copy()
    draw = ImageDraw.Draw(top)
    draw.rectangle((6, 6, 57, 57), fill="#ac5e51", outline="#7a3034", width=2)
    screws(draw, ((12, 12), (50, 12), (12, 50), (50, 50)), "#77373a", "#e9af8f")
    return {"front": window, "side": side, "top": top, "back": body}


LETTERS = {
    "A": ("01110", "11011", "11011", "11111", "11011", "11011", "11011"),
    "B": ("11110", "11011", "11011", "11110", "11011", "11011", "11110"),
    "R": ("11110", "11011", "11011", "11110", "11100", "11010", "11011"),
}


def alphabet(source):
    body = material(source, "#a5754b", "#dfbc87")
    faces = {}
    for face, letter, color in (("front", "A", "#994443"), ("side", "B", "#455f91"),
                                ("top", "R", "#668553")):
        image = body.copy()
        draw = ImageDraw.Draw(image)
        draw.rectangle((6, 6, 57, 57), outline=color, width=4)
        for y, row in enumerate(LETTERS[letter]):
            for x, ink in enumerate(row[::-1] if letter == "R" else row):
                if ink == "1":
                    left, top = 19 + x*5, 14 + y*5
                    draw.rectangle((left, top, left+4, top+4), fill=color)
        for x, y in ((8, 8), (7, 44), (32, 7), (56, 22), (48, 55)):
            draw.line((x-1, y, x+2, y+1), fill="#d4ab77")
        faces[face] = image
    return faces


def fan():
    body = surface((220, 211, 173))
    panel(ImageDraw.Draw(body), "#aaa589", "#f5ead1")
    front, top = body.copy(), body.copy()
    draw = ImageDraw.Draw(front)
    draw.ellipse((6, 6, 57, 57), fill="#383e3a", outline="#8e8d73", width=2)
    for points in (((31, 31), (24, 10), (34, 10), (45, 16), (41, 23)),
                   ((31, 31), (53, 34), (49, 44), (40, 52), (33, 46)),
                   ((31, 31), (15, 49), (10, 39), (10, 28), (18, 25))):
        draw.polygon(points, fill="#8e9b91")
    for y in range(12, 54, 4):
        for x in range(9, 55):
            if (x-31.5)**2 + (y-31.5)**2 < 23**2:
                draw.point((x, y), fill="#dbd2b6")
    draw.ellipse((26, 26, 37, 37), fill="#dad2b8", outline="#676d60")
    screws(draw, ((7, 7), (55, 7), (7, 55), (55, 55)), "#847e63", "#f1e4c1")
    draw = ImageDraw.Draw(top)
    draw.rounded_rectangle((19, 20, 44, 28), radius=3, fill="#8d8b72")
    draw.ellipse((26, 34, 38, 46), fill="#645e4f", outline="#b0a17d")
    draw.line((31, 38, 35, 36), fill="#eee2b4", width=2)
    return {"front": front, "side": body, "top": top}


def aquarium():
    face = surface((92, 156, 145))
    draw = ImageDraw.Draw(face)
    draw.rectangle((0, 0, 63, 7), fill="#3a635e")
    draw.rectangle((0, 53, 63, 63), fill="#b49779")
    rng = Random(410)
    for _ in range(78):
        x, y = rng.randrange(4, 60), rng.randrange(52, 60)
        draw.line((x, y, x+rng.randint(1, 3), y), fill=rng.choice(("#dac3a0", "#8a8272", "#ae7e77")))
    draw.polygon(((9, 54), (9, 41), (12, 41), (12, 44), (16, 44), (16, 39), (23, 40), (25, 55)),
                 fill="#85809d")
    draw.rectangle((15, 48, 19, 55), fill="#56516b")
    for x, y in ((49, 37), (53, 29), (49, 23)):
        draw.ellipse((x, y, x+3, y+3), outline="#b1d9be")
    panel(draw, "#426664", "#b3ded2")
    front = face.copy()
    draw = ImageDraw.Draw(front)
    draw.polygon(((37, 30), (45, 25), (45, 35)), fill="#d58c45")
    draw.ellipse((23, 24, 40, 36), fill="#ec994a", outline="#9f5c38")
    draw.point((27, 29), fill="#453935")
    draw.line((29, 26, 34, 26), fill="#ffd78e")
    top = surface((118, 177, 158))
    draw = ImageDraw.Draw(top)
    panel(draw, "#3a635e", "#b3ded2")
    draw.arc((13, 16, 51, 44), 200, 322, fill="#a9d3b6", width=2)
    return {"front": front, "side": face, "top": top}


def ice():
    rng = Random(31)
    side = surface((156, 205, 224), grain=9)
    draw = ImageDraw.Draw(side)
    draw.polygon(((0, 0), (25, 0), (9, 21), (0, 31)), fill="#c9e8ee")
    draw.polygon(((50, 45), (63, 37), (63, 63), (38, 63)), fill="#badce8")
    draw.line((2, 57, 3, 3, 58, 3), fill="#ecf4f3", width=2)
    for _ in range(18):
        x, y, r = rng.randrange(8, 55), rng.randrange(8, 55), rng.randrange(1, 4)
        draw.arc((x, y, x+r, y+r), 178, 325, fill="#d1eaf0")
    front = side.copy()
    draw = ImageDraw.Draw(front)
    draw.ellipse((12, 19, 29, 36), outline="#ac9066", width=4)
    draw.line((26, 30, 49, 44), fill="#b29a6b", width=5)
    draw.line((45, 41, 41, 48, 45, 50, 49, 44), fill="#b29a6b", width=2)
    draw.line((27, 29, 47, 41), fill="#d5c598")
    return {"front": front, "side": side}


def tickets():
    body = surface((165, 61, 60))
    draw = ImageDraw.Draw(body)
    panel(draw, "#803e42", "#d08276")
    draw.rounded_rectangle((10, 12, 53, 51), radius=5, outline="#9a4645", width=2)
    front = body.copy()
    draw = ImageDraw.Draw(front)
    draw.rounded_rectangle((9, 20, 54, 32), radius=3, fill="#532f35", outline="#c58a73")
    draw.polygon(((21, 28), (42, 28), (40, 47), (37, 45), (32, 47), (29, 45),
                  (23, 47)), fill="#e8cc9a")
    draw.text((32, 37), "000", fill="#653e37", anchor="mm")
    return {"front": front, "side": body}


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
    args = parser.parse_args()
    DESTINATION.mkdir(parents=True, exist_ok=True)
    objects = {
        "suggestion-box": plywood(args.plywood),
        "gumball-dispenser": dispenser(),
        "alphabet-block": alphabet(args.plywood),
        "box-fan": fan(),
        "cube-aquarium": aquarium(),
        "ice-cube": ice(),
        "ticket-box": tickets(),
        "moving-box": moving_box(args.cardboard),
    }
    for name, faces in objects.items():
        for face, image in faces.items():
            image.save(DESTINATION / f"{name}-{face}.png", optimize=True)
