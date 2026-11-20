#!/usr/bin/env python3
"""Draw the quarry's original 64-pixel pattern tiles using only the standard library."""
from math import atan2, cos, hypot, pi, sin, tau
from pathlib import Path
from random import Random
from struct import pack
from zlib import compress, crc32

SIZE = 64
DESTINATION = Path(__file__).resolve().parents[1] / "assets/quarry-textures"
CREAM = (233, 217, 179)


def mix(first, second, amount):
    return tuple(a + (b-a)*amount for a, b in zip(first, second))


def inside_star(x, y, radius):
    angle = (atan2(y, x) + pi/2) % tau
    section = angle % (tau/5)
    delta = section if section < pi/5 else tau/5-section
    inner = radius*.45
    return hypot(x, y) < radius*inner*sin(pi/5)/(inner*sin(pi/5-delta)+radius*sin(delta))


def stars(x, y):
    row, column = int(y//32), int(x//32)
    dx, dy = (x+row*7) % 32-16, (y+column*4) % 32-16
    return (225, 124, 48) if inside_star(dx, dy, 11.8) else CREAM


def daisies(x, y):
    row = int(y//32)
    dx, dy = (x+row*10) % 32-16, y % 32-16
    if hypot(dx, dy) < 3.1:
        return (236, 189, 91)
    for i in range(5):
        angle = i*tau/5 + .25 + row*.33
        if hypot(dx-4.7*cos(angle), dy-4.7*sin(angle)) < 3.45:
            return (234, 184, 208)
    return (145, 96, 172)


def gingham(x, y, dye):
    cross = int(x//16) % 2 + int(y//16) % 2
    twill = (.045 if int(x+y) % 4 < 2 else -.025)
    return mix((236, 223, 203), dye, (.08, .52, .89)[cross]+twill)


def pips(x, y):
    row = int(y//16)
    distance = hypot((x+8*(row%2)) % 16-8, y % 16-8)
    return (58, 52, 53) if distance < 3.8 else CREAM


def waves(x, y):
    distance = abs((y-3.9*sin(x*tau/32)+8) % 16-8)
    return (73, 112, 169) if distance < 2.15 else CREAM


def knit(x, y):
    column = int(x//16)
    dx = (x % 16)-8
    dy = (y+column*4) % 8-4
    # A pair of lit loops in every stitch, with dark wool showing between.
    bend = (abs(dx)-3.55-dy*.82)/2.35
    loop = max(0, 1-bend*bend-(dy/4.1)**2)
    rib = .09*sin(y*tau/4+x*tau/8)
    return mix((43, 58, 113), (130, 155, 220), max(0, loop*.87+rib))


def studs(x, y):
    dx, dy = x % 16-8, y % 16-8
    radius = hypot(dx, dy)
    if radius < 4.1:
        return (246, 197, 58)
    if radius < 5.5:
        return (255, 216, 89) if dx+dy < 0 else (171, 113, 25)
    if hypot(dx-1, dy-1) < 6.2:
        return (177, 118, 24)
    return (218, 160, 35)


def fired_brick(x, y):
    row = int(y//16)
    u, v = (x+16*(row%2)) % 32, y % 16
    if u < 1.6 or v < 1.6:
        return (222, 188, 163)
    tone = (.08, .20, .03, .13)[row] + .04*sin(x*tau/32)
    if u < 3 or v < 2.9:
        tone += .16
    return mix((160, 60, 49), (222, 111, 81), tone)


def write_png(path, draw):
    random = Random(7351)
    rows = bytearray()
    offsets = (.125, .375, .625, .875)
    for y in range(SIZE):
        rows.append(0)
        for x in range(SIZE):
            pixels = [draw(x+dx, y+dy) for dx in offsets for dy in offsets]
            grain = random.uniform(-5, 5)
            grain += 2.5*cos((x+y)*tau/8) + 2*sin((x-2*y)*tau/32)
            rows.extend(max(0, min(255, round(sum(channel)/16+grain))) for channel in zip(*pixels))

    def chunk(name, data):
        return pack(">I", len(data)) + name + data + pack(">I", crc32(name+data))

    path.write_bytes(b"\x89PNG\r\n\x1a\n"
                     + chunk(b"IHDR", pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
                     + chunk(b"IDAT", compress(rows, 9)) + chunk(b"IEND", b""))


if __name__ == "__main__":
    for name, draw in {
        "orange-stars": stars,
        "violet-daisies": daisies,
        "blue-gingham": lambda x, y: gingham(x, y, (74, 107, 174)),
        "red-gingham": lambda x, y: gingham(x, y, (182, 76, 70)),
        "cream-pips": pips,
        "blue-waves": waves,
        "blue-knit": knit,
        "gold-studs": studs,
        "fired-brick": fired_brick,
    }.items():
        write_png(DESTINATION / f"motif-{name}.png", draw)
