"""
Generates theme-matched wallpapers in the same "overlapping soft circles"
style as the existing catppuccin/gruvbox/everforest wallpapers, using each
theme's own real palette so the wallpaper and the UI colors always agree.
Not a substitute for real photography — an honest, deterministic way to
guarantee color-accuracy per theme without sourcing/licensing external
images.
"""
from PIL import Image, ImageDraw
import random

W, H = 960, 600

def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def vertical_gradient_circle(size, top_color, bottom_color):
    """A circle filled with a top-to-bottom gradient, soft anti-aliased edge."""
    ss = 4  # supersample for smooth edges
    big = Image.new("RGBA", (size * ss, size * ss), (0, 0, 0, 0))
    grad = Image.new("RGBA", (1, size * ss), (0, 0, 0, 255))
    for y in range(size * ss):
        c = lerp(top_color, bottom_color, y / (size * ss))
        grad.putpixel((0, y), (*c, 255))
    grad = grad.resize((size * ss, size * ss))
    mask = Image.new("L", (size * ss, size * ss), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size * ss, size * ss), fill=255)
    big.paste(grad, (0, 0), mask)
    return big.resize((size, size), Image.LANCZOS)

def generate(path, background, circle_pairs, seed):
    """circle_pairs: list of (top_hex, bottom_hex, size_frac, opacity) for
    each circle, largest/backmost first."""
    rng = random.Random(seed)
    canvas = Image.new("RGBA", (W, H), (*hex_to_rgb(background), 255))

    positions = [
        (0.32, 0.0),
        (0.85, 0.55),
        (0.15, 0.75),
        (0.62, 0.25),
    ]

    for i, (top, bot, size_frac, opacity) in enumerate(circle_pairs):
        size = int(H * size_frac)
        circle = vertical_gradient_circle(size, hex_to_rgb(top), hex_to_rgb(bot))
        if opacity < 1.0:
            a = circle.split()[3].point(lambda v: int(v * opacity))
            circle.putalpha(a)
        px, py = positions[i % len(positions)]
        x = int(W * px - size / 2)
        y = int(H * py - size / 2)
        canvas.alpha_composite(circle, (x, y))

    canvas.convert("RGB").save(path, quality=90)
    print("wrote", path)

# ---- ariadne: deep indigo labyrinth + warm gold thread ----
generate(
    "ariadne-1.jpg",
    background="#14152b",
    circle_pairs=[
        ("#262a4a", "#1c1e3a", 1.35, 1.0),
        ("#3a3f66", "#262a4a", 1.05, 0.9),
        ("#d4af6a", "#8a6a3a", 0.42, 0.55),  # muted gold thread accent, soft
        ("#1c1e3a", "#14152b", 0.9, 0.85),
    ],
    seed=1,
)

# ---- horizon: dark UI layers + signature coral-pink accent ----
generate(
    "horizon-1.jpg",
    background="#1c1e26",
    circle_pairs=[
        ("#232530", "#1a1c23", 1.35, 1.0),
        ("#2e303e", "#232530", 1.05, 0.9),
        ("#e95678", "#b8425c", 0.4, 0.5),  # signature coral accent, soft
        ("#16161c", "#1c1e26", 0.9, 0.85),
    ],
    seed=2,
)

# ---- monochrome: pure grayscale, no hue at all ----
generate(
    "monochrome-1.jpg",
    background="#121212",
    circle_pairs=[
        ("#262626", "#1c1c1c", 1.35, 1.0),
        ("#3a3a3a", "#262626", 1.05, 0.9),
        ("#e0e0e0", "#8a8a8a", 0.4, 0.35),  # neutral highlight, soft
        ("#1c1c1c", "#121212", 0.9, 0.85),
    ],
    seed=3,
)
