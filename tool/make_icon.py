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
    android/…/res/mipmap-*/ legacy, adaptive and themed launcher icons
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


def _draw_star(
    icon: Image.Image,
    radius: float,
    stroke: float,
    colour=GOLD,
    dot: float | None = None,
) -> Image.Image:
    """The Rub el Hizb, centred, onto whatever is already there."""
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
            fill=colour,
            width=width,
            joint="curve",
        )

    # Defaults to scaling with the star; the desktop masters pin it instead,
    # because a proportionally smaller dot is harder to make out at 16 px.
    r_dot = (dot if dot is not None else (0.055 / 0.315) * radius) * SS
    draw.ellipse(
        [centre - r_dot, centre - r_dot, centre + r_dot, centre + r_dot],
        fill=colour,
    )
    return icon


def master(radius: float, stroke: float) -> Image.Image:
    """One master, at the given proportions."""
    return _draw_star(_background(), radius, stroke, dot=0.055)


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


# --- Android ----------------------------------------------------------------
#
# Two things are needed. The legacy PNG is what pre-Oreo launchers draw, and
# an adaptive icon is what everything since draws: two full-bleed layers the
# launcher masks to its own shape and shifts for parallax. The mask can take
# as much as the outer 18 of 108 dp, so the mark is drawn smaller here than in
# the legacy tile, sized to land inside the 66 dp that is always visible.
#
# A monochrome layer comes along for Android 13's themed icons, which tint one
# silhouette to the wallpaper; without it a themed launcher shows the whole
# coloured icon shrunk inside a circle.

ANDROID_RES = ROOT / "android/app/src/main/res"

# Density suffix to scale factor. Adaptive layers are 108 dp square.
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

# Proportions for the adaptive layers: 0.42 of 108 dp is 45 dp, which is the
# same share of the visible area that 0.63 is of the legacy tile.
ADAPTIVE_RADIUS = 0.21
ADAPTIVE_STROKE = 0.032

ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
"""


def _full_bleed_background() -> Image.Image:
    """The gradient without the rounded corners — the launcher does the mask."""
    gradient = Image.new("RGB", (1, SS))
    for y in range(SS):
        t = y / (SS - 1)
        gradient.putpixel(
            (0, y),
            tuple(int(a + (b - a) * t) for a, b in zip(TEAL_TOP, TEAL_BOTTOM)),
        )
    return gradient.resize((SS, SS)).convert("RGBA")


def android() -> None:
    print("Android")

    # Legacy launcher icon, at the same proportions as every other platform.
    for density, scale in DENSITIES.items():
        size = int(48 * scale)
        write(ANDROID_RES / f"mipmap-{density}/ic_launcher.png", size)

    layers = {
        "ic_launcher_background": _full_bleed_background(),
        "ic_launcher_foreground": _draw_star(
            Image.new("RGBA", (SS, SS), (0, 0, 0, 0)),
            ADAPTIVE_RADIUS,
            ADAPTIVE_STROKE,
        ),
        # Tinted by the launcher, so only the shape matters.
        "ic_launcher_monochrome": _draw_star(
            Image.new("RGBA", (SS, SS), (0, 0, 0, 0)),
            ADAPTIVE_RADIUS,
            ADAPTIVE_STROKE,
            colour=(255, 255, 255, 255),
        ),
    }

    for density, scale in DENSITIES.items():
        size = int(108 * scale)
        for name, layer in layers.items():
            path = ANDROID_RES / f"mipmap-{density}/{name}.png"
            path.parent.mkdir(parents=True, exist_ok=True)
            layer.resize((size, size), Image.LANCZOS).save(path)
        print(f"  mipmap-{density}/ 3 adaptive layers  {size}px")

    anydpi = ANDROID_RES / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        (anydpi / name).write_text(ADAPTIVE_XML)
        print(f"  {(anydpi / name).relative_to(ROOT)}")


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

    android()


if __name__ == "__main__":
    main()
