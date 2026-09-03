#!/usr/bin/env python3
"""Generate the app icon for every platform.

    python3 tool/make_icon.py

The mark is the Rub el Hizb — the eight-pointed star formed by two squares,
one turned forty-five degrees from the other. It is the sign used in the
mushaf itself to mark divisions of the text, which is close to what this app
is for, and it survives being shrunk to a taskbar in a way a book or a
magnifier does not.

Needs Pillow. Everything is drawn several times larger than needed and
resampled down, which is what keeps the diagonals clean.

Outputs
    assets/icon/            what the Linux runner loads at startup
    macos/…/AppIcon.appiconset/
    windows/runner/resources/app_icon.ico
"""

from math import cos, radians, sin
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent

SS = 2048  # supersampled master

# The teal is the app's own seed colour, lit from the top.
TEAL_TOP = (14, 140, 119)
TEAL_BOTTOM = (4, 70, 61)
GOLD = (242, 206, 134, 255)

CORNER = 0.225  # corner radius, as a fraction of the icon
LINE_SIZES = [512, 256, 128, 64, 48, 32, 24, 16]


def _background() -> Image.Image:
    gradient = Image.new("RGB", (1, SS))
    for y in range(SS):
        t = y / (SS - 1)
        gradient.putpixel(
            (0, y),
            tuple(int(a + (b - a) * t) for a, b in zip(TEAL_TOP, TEAL_BOTTOM)),
        )

    mask = Image.new("L", (SS, SS), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, SS - 1, SS - 1], radius=int(CORNER * SS), fill=255
    )

    icon = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
    icon.paste(gradient.resize((SS, SS)), (0, 0), mask)
    return icon


def _square(cx: float, cy: float, r: float, rotation: float):
    return [
        (
            cx + r * cos(radians(rotation + 90 * i)),
            cy + r * sin(radians(rotation + 90 * i)),
        )
        for i in range(4)
    ]


def master(radius: float, stroke: float) -> Image.Image:
    """One master, at the given proportions."""
    icon = _background()
    draw = ImageDraw.Draw(icon)
    centre = SS / 2
    r = radius * SS
    width = int(stroke * SS)

    for rotation in (0, 45):
        points = _square(centre, centre, r, rotation)
        # Carrying one point past the start rounds the closing joint too;
        # without it the corner where the outline meets itself is notched.
        draw.line(
            points + [points[0], points[1]],
            fill=GOLD,
            width=width,
            joint="curve",
        )

    dot = 0.055 * SS
    draw.ellipse(
        [centre - dot, centre - dot, centre + dot, centre + dot], fill=GOLD
    )
    return icon


# Below about 32 pixels the thin proportions silt up, so small sizes come
# from a slightly heavier drawing rather than from the same one shrunk.
LARGE = master(radius=0.315, stroke=0.048)
SMALL = master(radius=0.300, stroke=0.060)


def render(size: int) -> Image.Image:
    source = SMALL if size <= 32 else LARGE
    return source.resize((size, size), Image.LANCZOS)


def write(path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    render(size).save(path)
    print(f"  {path.relative_to(ROOT)}  {size}px")


def main() -> None:
    print("Linux (loaded from the bundle at startup)")
    for size in (512, 128, 48):
        write(ROOT / f"assets/icon/app_icon_{size}.png", size)

    print("macOS")
    appicon = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for size in (16, 32, 64, 128, 256, 512, 1024):
        write(appicon / f"app_icon_{size}.png", size)

    print("Windows")
    ico = ROOT / "windows/runner/resources/app_icon.ico"
    ico.parent.mkdir(parents=True, exist_ok=True)
    # Every size in the .ico is rendered from a master rather than left to
    # Pillow to downscale, so the small entries get the heavier drawing.
    frames = [render(size) for size in LINE_SIZES if size <= 256]
    frames[0].save(
        ico,
        format="ICO",
        sizes=[(f.width, f.height) for f in frames],
        append_images=frames[1:],
    )
    print(f"  {ico.relative_to(ROOT)}  {[f.width for f in frames]}")


if __name__ == "__main__":
    main()
