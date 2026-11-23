"""Generate the first installable REST Ribbon typeface using FontForge.

Run with the FontForge build's bundled Python:
  E:\\FontForgeBuilds\\bin\\ffpython.exe generate_rest_ribbon.py

The font is deliberately single-colour. REST controls theme colour and glow in
Flutter, keeping the letterforms usable on every theme and at small sizes.
"""

import math
import os
import unicodedata

import fontforge


OUT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "fonts", "RESTRibbon-Regular.ttf"))
EM = 1000
STROKE = 112
PENS = {}


def cubic(p0, p1, p2, p3, steps=12):
    points = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        points.append((u**3*p0[0] + 3*u*u*t*p1[0] + 3*u*t*t*p2[0] + t**3*p3[0],
                       u**3*p0[1] + 3*u*u*t*p1[1] + 3*u*t*t*p2[1] + t**3*p3[1]))
    return points


def join(*parts):
    result = []
    for part in parts:
        result.extend(part if not result else part[1:])
    return result


def ellipse_points(cx, cy, rx, ry, steps=48):
    return [(cx + rx * math.cos(2 * math.pi * i / steps),
             cy + ry * math.sin(2 * math.pi * i / steps)) for i in range(steps)]


def area(points):
    return sum(points[i][0] * points[(i + 1) % len(points)][1] -
               points[(i + 1) % len(points)][0] * points[i][1]
               for i in range(len(points))) / 2


def contour(glyph, points, clockwise=False):
    points = list(points)
    if (area(points) < 0) != clockwise:
        points.reverse()
    pen = PENS.get(glyph.glyphname)
    if pen is None:
        pen = glyph.glyphPen()
        PENS[glyph.glyphname] = pen
    pen.moveTo(points[0])
    for point in points[1:]:
        pen.lineTo(point)
    pen.closePath()


def filled_ellipse(glyph, cx, cy, rx, ry, steps=32):
    contour(glyph, ellipse_points(cx, cy, rx, ry, steps), clockwise=True)


def ring(glyph, cx, cy, rx, ry, thickness):
    contour(glyph, ellipse_points(cx, cy, rx, ry), clockwise=True)
    contour(glyph, ellipse_points(cx, cy, rx - thickness, ry - thickness), clockwise=False)


def unit(a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dy) or 1
    return dx / length, dy / length


def offset_side(points, radius, side):
    out = []
    for i, point in enumerate(points):
        prev_t = unit(points[max(0, i - 1)], point) if i else unit(points[0], points[1])
        next_t = unit(point, points[min(len(points) - 1, i + 1)]) if i < len(points) - 1 else prev_t
        n1 = (-prev_t[1] * side, prev_t[0] * side)
        n2 = (-next_t[1] * side, next_t[0] * side)
        sx, sy = n1[0] + n2[0], n1[1] + n2[1]
        sl = math.hypot(sx, sy)
        if sl < 0.001:
            sx, sy, sl = n2[0], n2[1], 1
        mx, my = sx / sl, sy / sl
        dot = max(0.25, abs(mx * n2[0] + my * n2[1]))
        scale = min(radius / dot, radius * 2.2)
        out.append((point[0] + mx * scale, point[1] + my * scale))
    return out


def stroke(glyph, points, width=STROKE):
    points = list(points)
    if len(points) < 2:
        return
    if not all(isinstance(p, (tuple, list)) and len(p) == 2 for p in points):
        raise ValueError("Invalid path in %s: %r" % (glyph.glyphname, points[:6]))
    radius = width / 2
    left = offset_side(points, radius, 1)
    right = offset_side(points, radius, -1)
    end_t = unit(points[-2], points[-1])
    end_angle = math.atan2(end_t[1], end_t[0])
    start_t = unit(points[0], points[1])
    start_angle = math.atan2(start_t[1], start_t[0])
    outline = list(left)
    for k in range(1, 13):
        a = end_angle + math.pi / 2 - k * math.pi / 12
        outline.append((points[-1][0] + radius * math.cos(a), points[-1][1] + radius * math.sin(a)))
    outline.extend(reversed(right[:-1]))
    for k in range(1, 13):
        a = start_angle - math.pi / 2 - k * math.pi / 12
        outline.append((points[0][0] + radius * math.cos(a), points[0][1] + radius * math.sin(a)))
    contour(glyph, outline, clockwise=True)


def draw_glyph(font, char, paths=(), holes=(), circles=(), width=700, size=700):
    glyph = font.createChar(ord(char), "uni%04X" % ord(char))
    for pts in paths:
        stroke(glyph, pts)
    for cx, cy, rx, ry, thick in holes:
        ring(glyph, cx, cy, rx, ry, thick)
    for cx, cy, rx, ry in circles:
        filled_ellipse(glyph, cx, cy, rx, ry)
    glyph.width = width
    return glyph


def unpack_groups(groups):
    paths, holes = [], []
    for group in groups:
        points = []
        for item in group:
            if isinstance(item, (tuple, list)) and len(item) == 5 and all(isinstance(v, (int, float)) for v in item):
                holes.append(tuple(item))
            elif isinstance(item, (tuple, list)) and len(item) == 2 and all(isinstance(v, (int, float)) for v in item):
                points.append(tuple(item))
            elif isinstance(item, (tuple, list)) and item and isinstance(item[0], (tuple, list)):
                part = [tuple(p) for p in item if isinstance(p, (tuple, list)) and len(p) == 2]
                if points and part and points[-1] == part[0]:
                    part = part[1:]
                points.extend(part)
        if len(points) >= 2:
            paths.append(points)
    return paths, holes


def C(p0, p1, p2, p3):
    return cubic(p0, p1, p2, p3)


def add_base_glyphs(font):
    # The broad, continuous strokes and lifted wave-like joins echo the R logo.
    up = {
        "A": ([(110, 0), (350, 700), (590, 0)], [(205, 260), (500, 260)]),
        "B": ([(120, 0), (120, 700)], [C((120, 700), (610, 730), (600, 420), (120, 380)), C((120, 380), (620, 420), (610, -25), (120, 0))]),
        "C": ([C((570, 620), (210, 820), (75, 550), (90, 350)), C((90, 350), (75, 145), (220, -100), (570, 80))],),
        "D": ([(120, 0), (120, 700)], [C((120, 700), (680, 760), (680, -60), (120, 0))]),
        "E": ([(130, 0), (130, 700), (580, 700)], [(130, 350), (500, 350)], [(130, 0), (590, 0)]),
        "F": ([(130, 0), (130, 700), (590, 700)], [(130, 350), (500, 350)]),
        "G": ([join(C((570, 620), (210, 820), (75, 550), (90, 350)), C((90, 350), (75, 145), (220, -100), (570, 80)), [(570, 80), (570, 320), (390, 320)])],),
        "H": ([(120, 0), (120, 700)], [(580, 0), (580, 700)], [(120, 350), (580, 350)]),
        "I": ([(350, 0), (350, 700)], [(170, 700), (530, 700)], [(170, 0), (530, 0)]),
        "J": ([(180, 700), (570, 700), (570, 180), C((570, 180), (570, -50), (170, -70), (120, 170))],),
        "K": ([(130, 0), (130, 700)], [(570, 700), (150, 350), (590, 0)]),
        "L": ([(130, 700), (130, 0), (590, 0)],),
        "M": ([(100, 0), (100, 700), (350, 330), (600, 700), (600, 0)],),
        "N": ([(120, 0), (120, 700), (580, 0), (580, 700)],),
        "O": ([], [(350, 350, 260, 350, STROKE)]),
        "P": ([(130, 0), (130, 700)], [C((130, 700), (620, 760), (640, 320), (130, 350))]),
        "Q": ([(500, -110), (640, 40)], [(350, 350, 260, 350, STROKE)]),
        "R": ([(120, 0), (120, 700)], [join(C((120, 700), (620, 760), (640, 320), (120, 350)), [(240, 350), (600, 0)])]),
        "S": ([C((570, 610), (260, 830), (95, 630), (190, 420)), C((190, 420), (290, 300), (600, 390), (520, 170)), C((520, 170), (440, -30), (200, -40), (90, 90))],),
        "T": ([(100, 700), (600, 700)], [(350, 700), (350, 0)]),
        "U": ([(120, 700), (120, 200), C((120, 200), (120, -70), (580, -70), (580, 200)), (580, 700)],),
        "V": ([(100, 700), (350, 0), (600, 700)],),
        "W": ([(70, 700), (190, 0), (350, 380), (510, 0), (630, 700)],),
        "X": ([(120, 700), (580, 0)], [(580, 700), (120, 0)]),
        "Y": ([(100, 700), (350, 390), (600, 700)], [(350, 390), (350, 0)]),
        "Z": ([(110, 700), (590, 700), (110, 0), (590, 0)],),
    }
    for char, groups in up.items():
        paths, holes = unpack_groups(groups)
        # O and Q use a deliberately clean rounded counter.
        if char == "O":
            holes = [(350, 350, 260, 350, STROKE)]
        if char == "Q":
            holes = [(350, 350, 260, 350, STROKE)]
        draw_glyph(font, char, paths=paths, holes=holes, width=700)

    # Lowercase is a compact, single-storey companion with the same broad ribbon.
    lower = {
        "a": ([C((500, 430), (350, 600), (120, 520), (120, 300)), C((120, 300), (100, 20), (420, 0), (500, 160)), (500, 0), (500, 500)],),
        "b": ([(120, 700), (120, 260)], [C((120, 260), (260, 590), (570, 530), (570, 270)), C((570, 270), (570, -20), (230, -60), (120, 180))]),
        "c": ([C((520, 440), (300, 590), (100, 470), (110, 280)), C((110, 280), (100, 60), (320, -50), (520, 90))],),
        "d": ([C((500, 430), (350, 600), (120, 520), (120, 300)), C((120, 300), (100, 20), (420, 0), (500, 160)), (500, 0), (500, 700)],),
        "e": ([C((110, 280), (300, 300), (420, 300), (540, 320)), C((540, 320), (520, 560), (130, 590), (110, 300)), C((110, 300), (100, 30), (350, -50), (540, 80))],),
        "f": ([(170, 0), (170, 560), C((170, 560), (170, 740), (330, 760), (400, 660))], [(70, 470), (390, 470)]),
        "g": ([C((480, 430), (330, 580), (120, 520), (120, 300)), C((120, 300), (100, 40), (420, 0), (480, 170)), (480, 0), (480, -120), C((480, -120), (460, -270), (210, -270), (130, -190))],),
        "h": ([(120, 0), (120, 700)], [(120, 290), C((120, 290), (180, 570), (520, 560), (520, 300)), (520, 0)]),
        "i": ([(300, 0), (300, 500)],),
        "j": ([(330, 500), (330, -100), C((330, -100), (320, -260), (190, -260), (120, -210))],),
        "k": ([(120, 0), (120, 700)], [(500, 500), (140, 260), (520, 0)]),
        "l": ([(300, 700), (300, 0)],),
        "m": ([(100, 0), (100, 500)], [(100, 280), C((100, 280), (160, 580), (350, 570), (350, 300)), (350, 0)], [(350, 280), C((350, 280), (410, 580), (600, 570), (600, 300)), (600, 0)]),
        "n": ([(120, 0), (120, 500)], [(120, 280), C((120, 280), (180, 580), (520, 570), (520, 300)), (520, 0)]),
        "o": ([], [(320, 260, 220, 260, STROKE)]),
        "p": ([(120, 500), (120, -180)], [C((120, 260), (250, 590), (570, 550), (570, 280)), C((570, 280), (570, 0), (250, -40), (120, 180))]),
        "q": ([C((500, 430), (350, 600), (120, 520), (120, 300)), C((120, 300), (100, 20), (420, 0), (500, 160)), (500, 500), (500, -180)],),
        "r": ([(120, 0), (120, 500)], [(120, 280), C((160, 540), (300, 600), (480, 500), (520, 440))]),
        "s": ([C((500, 440), (310, 590), (100, 500), (150, 340)), C((150, 340), (200, 250), (500, 320), (500, 170)), C((500, 170), (490, -20), (250, -50), (100, 80))],),
        "t": ([(300, 650), (300, 120), C((300, 120), (300, -20), (430, -30), (500, 40))], [(130, 470), (470, 470)]),
        "u": ([(120, 500), (120, 190), C((120, 190), (120, -40), (500, -40), (500, 190)), (500, 500)],),
        "v": ([(90, 500), (320, 0), (550, 500)],),
        "w": ([(70, 500), (180, 0), (320, 290), (460, 0), (580, 500)],),
        "x": ([(120, 500), (520, 0)], [(520, 500), (120, 0)]),
        "y": ([(100, 500), (310, 0), (520, 500)], [(310, 0), (220, -190)]),
        "z": ([(110, 500), (520, 500), (110, 0), (520, 0)],),
    }
    for char, groups in lower.items():
        paths, holes = unpack_groups(groups)
        circles = [(300, 650, 40, 40)] if char == "i" else ([(330, 650, 40, 40)] if char == "j" else [])
        if char == "o":
            holes = [(320, 260, 220, 260, STROKE)]
        draw_glyph(font, char, paths=paths, holes=holes, circles=circles, width=640)

    # Numerals share the letterforms' rounded construction.
    nums = {
        "0": ([], [(350, 350, 245, 350, STROKE)]),
        "1": ([(220, 560), (350, 700), (350, 0), (210, 0)],),
        "2": ([C((130, 540), (240, 790), (620, 750), (590, 500)), C((590, 500), (570, 360), (170, 170), (120, 0)), (120, 0), (600, 0)],),
        "3": ([C((130, 620), (250, 790), (570, 740), (560, 520)), C((560, 520), (550, 400), (430, 360), (330, 350)), C((330, 350), (650, 350), (640, -20), (150, 40))],),
        "4": ([(470, 0), (470, 700), (100, 230), (620, 230)],),
        "5": ([(590, 700), (170, 700), (150, 390), C((150, 390), (590, 480), (650, 280), (560, 120)), C((560, 120), (470, -40), (220, -50), (100, 70))],),
        "6": ([C((530, 660), (260, 790), (110, 520), (120, 300)), C((120, 300), (130, -10), (590, -70), (600, 210)), C((600, 210), (610, 480), (160, 470), (120, 260))],),
        "7": ([(100, 700), (610, 700), (280, 0)],),
        "8": ([C((350, 370), (80, 370), (130, 730), (350, 700)), C((350, 700), (600, 730), (620, 390), (350, 370)), C((350, 370), (50, 350), (100, -30), (350, 0)), C((350, 0), (600, -30), (650, 350), (350, 370))],),
        "9": ([C((570, 400), (560, 720), (110, 780), (100, 500)), C((100, 500), (90, 220), (500, 220), (570, 430)), (570, 430), (570, 0)],),
    }
    for char, groups in nums.items():
        paths, holes = unpack_groups(groups)
        if char in ("0",):
            holes = [(350, 350, 245, 350, STROKE)]
        draw_glyph(font, char, paths=paths, holes=holes, width=700)


def add_punctuation(font):
    space = font.createChar(32, "space")
    space.width = 300
    # Simple, legible punctuation made with the same softened stroke language.
    specs = {
        ".": ([], 300), ",": ([(300, 40), (240, -90)], 300),
        ":": ([], 300), ";": ([(300, 40), (240, -90)], 300),
        "!": ([(300, 680), (300, 170)], 300), "?": ([C((120, 520), (150, 780), (500, 760), (500, 520)), C((500, 520), (500, 380), (300, 350), (300, 190))], 620),
        "-": ([(120, 300), (500, 300)], 620), "_": ([(80, -80), (560, -80)], 650),
        "+": ([(300, 120), (300, 520)], 620), "=": ([(110, 390), (510, 390)], 620),
        "/": ([(120, -20), (500, 720)], 620), "\\": ([(500, -20), (120, 720)], 620),
        "(": ([C((430, 720), (120, 500), (120, 60), (430, -160))], 500),
        ")": ([C((120, 720), (430, 500), (430, 60), (120, -160))], 500),
        "[": ([(380, 700), (180, 700), (180, -100), (380, -100)], 500),
        "]": ([(120, 700), (320, 700), (320, -100), (120, -100)], 500),
        "'": ([(240, 700), (200, 540)], 300), "\"": ([(190, 700), (160, 540)], 420),
    }
    for ch, (paths, width) in specs.items():
        glyph = font.createChar(ord(ch))
        if paths and isinstance(paths[0], (tuple, list)) and len(paths[0]) == 2 and isinstance(paths[0][0], (int, float)):
            paths = [paths]
        for p in paths:
            stroke(glyph, p, 86)
        glyph.width = width
    for ch, cx in [(".", 150), (":", 150), (";", 150), ("!", 300)]:
        glyph = font[ord(ch)]
        if ch == ".":
            filled_ellipse(glyph, cx, 0, 45, 45)
        elif ch in (":", ";"):
            filled_ellipse(glyph, cx, 0, 42, 42)
            filled_ellipse(glyph, cx, 390, 42, 42)
        elif ch == "!":
            filled_ellipse(glyph, cx, 30, 45, 45)
    for ch, (_, width) in specs.items():
        font[ord(ch)].width = width


def accent(glyph, kind, cx, top):
    width = 70
    if kind == "acute":
        stroke(glyph, [(cx + 40, top + 100), (cx - 35, top + 210)], width)
    elif kind == "grave":
        stroke(glyph, [(cx - 40, top + 100), (cx + 35, top + 210)], width)
    elif kind == "circumflex":
        stroke(glyph, [(cx - 90, top + 115), (cx, top + 205), (cx + 90, top + 115)], width)
    elif kind == "tilde":
        stroke(glyph, C((cx - 120, top + 145), (cx - 40, top + 230), (cx + 25, top + 70), (cx + 120, top + 155)), width)
    elif kind == "diaeresis":
        filled_ellipse(glyph, cx - 85, top + 150, 35, 35)
        filled_ellipse(glyph, cx + 85, top + 150, 35, 35)
    elif kind == "ring":
        ring(glyph, cx, top + 160, 68, 68, 64)
    elif kind == "macron":
        stroke(glyph, [(cx - 105, top + 150), (cx + 105, top + 150)], width)
    elif kind == "cedilla":
        stroke(glyph, [(cx + 20, 10), (cx + 65, -75), (cx - 15, -140)], width)
    elif kind == "dot":
        filled_ellipse(glyph, cx, top + 155, 38, 38)
    elif kind == "breve":
        stroke(glyph, C((cx - 100, top + 120), (cx - 70, top + 215), (cx + 70, top + 215), (cx + 100, top + 120)), width)
    elif kind == "ogonek":
        stroke(glyph, [(cx + 55, 0), (cx + 125, -70), (cx + 95, -145)], width)


def add_latin_extensions(font):
    for cp in list(range(0x00A0, 0x0100)) + list(range(0x0100, 0x0180)) + [0x1E9E]:
        ch = chr(cp)
        if cp in (0x00A0,):
            glyph = font.createChar(cp, "nbspace")
            glyph.addReference("space")
            glyph.width = 300
            continue
        normalized = unicodedata.normalize("NFD", ch)
        base = normalized[0]
        marks = [unicodedata.name(c, "") for c in normalized[1:]]
        if base not in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz":
            if ch == "ẞ":
                g = font.createChar(cp, "uni1E9E")
                g.addReference(font[ord("B")].glyphname)
                g.addReference(font[ord("S")].glyphname, (0.78, 0, 0, 0.78, 180, 0))
                g.width = 760
            continue
        base_glyph = font[ord(base)]
        glyph = font.createChar(cp, "uni%04X" % cp)
        mappings = {
            "COMBINING GRAVE ACCENT": "grave", "COMBINING ACUTE ACCENT": "acute",
            "COMBINING CIRCUMFLEX ACCENT": "circumflex", "COMBINING TILDE": "tilde",
            "COMBINING DIAERESIS": "diaeresis", "COMBINING RING ABOVE": "ring",
            "COMBINING MACRON": "macron", "COMBINING CEDILLA": "cedilla",
            "COMBINING DOT ABOVE": "dot", "COMBINING BREVE": "breve",
            "COMBINING OGONEK": "ogonek", "COMBINING CARON": "circumflex",
        }
        top = 700 if base.isupper() else (520 if base in "bdfhklt" else 520)
        for mark in marks:
            kind = next((v for k, v in mappings.items() if k in mark), None)
            if kind:
                accent(glyph, kind, base_glyph.width / 2, top)
        glyph.addReference(base_glyph.glyphname)
        glyph.width = base_glyph.width
    # Common European ligatures and punctuation.
    oe = font.createChar(0x0152, "OEmacron")
    oe.addReference(font[ord("O")].glyphname)
    stroke(oe, [(200, 350), (500, 350)], 64)
    oe.width = 850
    oel = font.createChar(0x0153, "oemacron")
    oel.addReference(font[ord("o")].glyphname)
    stroke(oel, [(190, 260), (470, 260)], 60)
    oel.width = 800
    glyph = font.createChar(0x2026, "ellipsis")
    for cx in (100, 300, 500):
        filled_ellipse(glyph, cx, 0, 36, 36)
    glyph.width = 600
    glyph = font.createChar(0x2019, "quoteright")
    stroke(glyph, [(150, 700), (210, 540)], 78)
    glyph.width = 300
    glyph = font.createChar(0x2018, "quoteleft")
    stroke(glyph, [(210, 700), (150, 540)], 78)
    glyph.width = 300
    glyph = font.createChar(0x201C, "quotedblleft")
    glyph.addReference(font[0x2018].glyphname)
    glyph.addReference(font[0x2018].glyphname, (1, 0, 0, 1, 170, 0))
    glyph.width = 450
    glyph = font.createChar(0x201D, "quotedblright")
    glyph.addReference(font[0x2019].glyphname)
    glyph.addReference(font[0x2019].glyphname, (1, 0, 0, 1, 170, 0))
    glyph.width = 450
    glyph = font.createChar(0x201E, "quotedblbase")
    glyph.addReference(font[0x2018].glyphname, (1, 0, 0, 1, 0, -570))
    glyph.addReference(font[0x2018].glyphname, (1, 0, 0, 1, 170, -570))
    glyph.width = 450
    glyph = font.createChar(0x2013, "endash")
    stroke(glyph, [(100, 300), (520, 300)], 86)
    glyph.width = 620
    glyph = font.createChar(0x2014, "emdash")
    stroke(glyph, [(100, 300), (750, 300)], 86)
    glyph.width = 850
    glyph = font.createChar(0x00D7, "multiply")
    stroke(glyph, [(150, 500), (500, 120)], 86)
    stroke(glyph, [(500, 500), (150, 120)], 86)
    glyph.width = 620
    glyph = font.createChar(0x00F7, "divide")
    stroke(glyph, [(140, 300), (500, 300)], 86)
    filled_ellipse(glyph, 320, 500, 40, 40)
    filled_ellipse(glyph, 320, 100, 40, 40)
    glyph.width = 620
    glyph = font.createChar(0x00B7, "periodcentered")
    filled_ellipse(glyph, 150, 250, 42, 42)
    glyph.width = 300
    for cp, is_left in [(0x00AB, True), (0x00BB, False)]:
        glyph = font.createChar(cp, "guillemotleft" if is_left else "guillemotright")
        paths = [[(280, 520), (130, 350), (280, 180)], [(510, 520), (360, 350), (510, 180)]]
        if not is_left:
            paths = [[(x + 230 if x < 300 else x - 230, y) for x, y in reversed(path)] for path in paths]
        for path in paths:
            stroke(glyph, path, 70)
        glyph.width = 650
    glyph = font.createChar(0x00BF, "questiondown")
    glyph.addReference(font[ord("?")].glyphname, (-1, 0, 0, -1, 620, 700))
    glyph.width = 620
    # These letters do not have canonical Unicode decompositions.
    for cp, first, second, offset, width in [
        (0x00C6, "A", "E", 330, 880), (0x00E6, "a", "e", 300, 840),
    ]:
        ligature = font.createChar(cp, "uni%04X" % cp)
        ligature.addReference(font[ord(first)].glyphname, (0.76, 0, 0, 0.76, 0, 0))
        ligature.addReference(font[ord(second)].glyphname, (0.76, 0, 0, 0.76, offset, 0))
        ligature.width = width
    for cp, base, y0, y1, width in [
        (0x00D8, "O", 50, 650, 700), (0x00F8, "o", 0, 500, 640),
    ]:
        slashed = font.createChar(cp, "uni%04X" % cp)
        stroke(slashed, [(115, y0), (585, y1)], 76)
        slashed.addReference(font[ord(base)].glyphname)
        slashed.width = width
    sharp_s = font.createChar(0x00DF, "germandbls")
    sharp_s.addReference(font[ord("s")].glyphname, (0.82, 0, 0, 0.82, 0, 220))
    sharp_s.addReference(font[ord("s")].glyphname, (0.82, 0, 0, 0.82, 330, 0))
    sharp_s.width = 830


def build():
    font = fontforge.font()
    font.encoding = "UnicodeFull"
    font.em = EM
    font.fontname = "RESTRibbon-Regular"
    font.familyname = "REST Ribbon"
    font.fullname = "REST Ribbon Regular"
    font.weight = "Regular"
    font.version = "0.1"
    font.copyright = "Copyright 2026 REST. Original typeface artwork."
    font.ascent = 960
    font.descent = 280
    add_base_glyphs(font)
    add_punctuation(font)
    add_latin_extensions(font)
    font.selection.all()
    font.removeOverlap()
    font.correctDirection()
    font.generate(OUT)
    print("Generated", OUT)


build()
