"""Genera el ícono de Mi Red: un diamante formado por una red de contactos.

Uso (requiere Pillow):  python3 tool/make_icon.py && dart run flutter_launcher_icons

Crea en assets/icon/:
  icon.png             ícono completo (iOS y Android antiguos)
  icon_foreground.png  solo el diamante, transparente (ícono adaptable de Android)
  icon_monochrome.png  silueta para los íconos temáticos de Android 13+
y en android/.../res/drawable-*/ic_notification.png la silueta blanca que
Android muestra en la barra de notificaciones.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
SCALE = 4  # se dibuja 4 veces más grande y se reduce: bordes suaves
BG_TOP = (42, 33, 27)
BG_BOTTOM = (18, 14, 11)
GOLD_LIGHT = (240, 210, 140)
GOLD = (201, 164, 92)
GOLD_DARK = (150, 115, 55)

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets' / 'icon'
RES = ROOT / 'android' / 'app' / 'src' / 'main' / 'res'
NOTIFICATION_SIZES = {'mdpi': 24, 'hdpi': 36, 'xhdpi': 48, 'xxhdpi': 72, 'xxxhdpi': 96}


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def emblem(size):
    """Diamante: sus vértices son personas y sus aristas, las conexiones."""
    s = size * SCALE
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def p(x, y):
        # Grilla de 0..1, reducida y centrada (el diamante va de y=0.30 a 0.84).
        k = 0.86
        return ((0.5 + (x - 0.5) * k) * s, (0.5 + (y - 0.57) * k) * s)

    top = [p(0.30, 0.30), p(0.50, 0.30), p(0.70, 0.30)]
    girdle = [p(0.14, 0.44), p(0.32, 0.44), p(0.50, 0.44), p(0.68, 0.44), p(0.86, 0.44)]
    tip = p(0.50, 0.84)

    # Relleno tenue de las facetas.
    d.polygon([top[0], top[2], girdle[4], tip, girdle[0]], fill=GOLD + (38,))
    d.polygon([top[0], top[1], girdle[2], girdle[1]], fill=GOLD_LIGHT + (40,))
    d.polygon([girdle[1], girdle[2], tip], fill=GOLD_LIGHT + (30,))

    edges = [
        (top[0], top[1]), (top[1], top[2]),
        (top[0], girdle[0]), (top[2], girdle[4]),
        (top[0], girdle[1]), (top[1], girdle[1]), (top[1], girdle[3]),
        (top[2], girdle[3]), (top[1], girdle[2]),
        (girdle[0], girdle[4]),
        (girdle[0], tip), (girdle[1], tip), (girdle[2], tip),
        (girdle[3], tip), (girdle[4], tip),
    ]
    w = int(0.022 * s)
    for a, b in edges:
        d.line([a, b], fill=GOLD, width=w)

    def node(c, r, color):
        r *= s
        d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=GOLD_DARK)
        r2 = r * 0.82
        d.ellipse([c[0] - r2, c[1] - r2, c[0] + r2, c[1] + r2], fill=color)
        # Brillo.
        r3 = r * 0.30
        cx, cy = c[0] - r * 0.25, c[1] - r * 0.25
        d.ellipse([cx - r3, cy - r3, cx + r3, cy + r3], fill=(255, 245, 220, 200))

    for c in girdle + [tip]:
        node(c, 0.045, GOLD)
    for c in (top[0], top[2]):
        node(c, 0.052, GOLD)
    node(top[1], 0.075, GOLD_LIGHT)  # tú, en la cima de tu red

    return img.resize((size, size), Image.LANCZOS)


def background(size):
    bg = Image.new('RGB', (size, size))
    d = ImageDraw.Draw(bg)
    for y in range(size):
        d.line([(0, y), (size, y)], fill=lerp(BG_TOP, BG_BOTTOM, y / size))
    # Resplandor dorado detrás del diamante.
    glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    r = size * 0.36
    c = size / 2
    gd.ellipse([c - r, c - r * 0.95, c + r, c + r * 0.95], fill=GOLD + (70,))
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.09))
    return Image.alpha_composite(bg.convert('RGBA'), glow)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    full = background(SIZE)
    full.alpha_composite(emblem(SIZE))
    full.convert('RGB').save(OUT / 'icon.png')

    # flutter_launcher_icons ya deja un margen del 16 % en el ícono
    # adaptable, así que el diamante va a tamaño completo.
    fg = emblem(SIZE)
    fg.save(OUT / 'icon_foreground.png')

    silhouette = white_silhouette(fg)
    silhouette.save(OUT / 'icon_monochrome.png')

    # Barra de notificaciones: silueta blanca con un pequeño margen.
    for density, px in NOTIFICATION_SIZES.items():
        folder = RES / f'drawable-{density}'
        folder.mkdir(parents=True, exist_ok=True)
        icon = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
        big = white_silhouette(emblem(int(SIZE * 1.25)))
        icon.alpha_composite(big, (-(big.width - SIZE) // 2, -(big.height - SIZE) // 2))
        icon.resize((px, px), Image.LANCZOS).save(folder / 'ic_notification.png')


def white_silhouette(img):
    """Mismo dibujo en blanco sólido, conservando solo la forma."""
    alpha = img.getchannel('A').point(lambda a: 255 if a > 90 else 0)
    out = Image.new('RGBA', img.size, (255, 255, 255, 0))
    out.putalpha(alpha)
    return out


if __name__ == '__main__':
    main()
