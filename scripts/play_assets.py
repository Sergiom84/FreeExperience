"""Genera los recursos gráficos para la ficha de Google Play.

Salida en assets/Google/play/:
  - icon_512.png        (icono de la app, 512x512)
  - feature_1024x500.png (gráfico de funciones)
  - screenshot_1..5.png  (capturas ajustadas a ratio <= 2:1)
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_ICON = os.path.join(ROOT, "assets", "icon", "icon.png")
GOOGLE = os.path.join(ROOT, "assets", "Google")
OUT = os.path.join(GOOGLE, "play")
os.makedirs(OUT, exist_ok=True)

GEORGIA = "C:/Windows/Fonts/georgia.ttf"
GEORGIA_B = "C:/Windows/Fonts/georgiab.ttf"

# 1) Icono 512x512 (32-bit PNG)
icon = Image.open(SRC_ICON).convert("RGBA").resize((512, 512), Image.LANCZOS)
icon.save(os.path.join(OUT, "icon_512.png"))
print("icon_512.png OK")

# 2) Gráfico de funciones 1024x500 con gradiente cálido + icono + wordmark
W, H = 1024, 500
# Gradiente vertical cálido (atardecer), coherente con la estética de la app
top = (44, 26, 20)      # marrón muy oscuro
mid = (150, 74, 38)     # ámbar profundo
bot = (214, 138, 74)    # dorado cálido
feat = Image.new("RGB", (W, H))
px = feat.load()
for y in range(H):
    t = y / (H - 1)
    if t < 0.5:
        u = t / 0.5
        r = int(top[0] + (mid[0] - top[0]) * u)
        g = int(top[1] + (mid[1] - top[1]) * u)
        b = int(top[2] + (mid[2] - top[2]) * u)
    else:
        u = (t - 0.5) / 0.5
        r = int(mid[0] + (bot[0] - mid[0]) * u)
        g = int(mid[1] + (bot[1] - mid[1]) * u)
        b = int(mid[2] + (bot[2] - mid[2]) * u)
    for x in range(W):
        px[x, y] = (r, g, b)

# Resplandor radial suave alrededor del icono (izquierda)
glow = Image.new("L", (W, H), 0)
gd = ImageDraw.Draw(glow)
cx, cy = 250, H // 2
for rad in range(260, 0, -2):
    a = int(90 * (1 - rad / 260))
    gd.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=a)
glow_col = Image.new("RGB", (W, H), (255, 214, 150))
feat = Image.composite(glow_col, feat, glow)

# Icono circular a la izquierda
isz = 300
ic = Image.open(SRC_ICON).convert("RGBA").resize((isz, isz), Image.LANCZOS)
mask = Image.new("L", (isz, isz), 0)
ImageDraw.Draw(mask).ellipse([0, 0, isz, isz], fill=255)
feat.paste(ic, (cx - isz // 2, cy - isz // 2), mask)

# Wordmark a la derecha
draw = ImageDraw.Draw(feat)
title_font = ImageFont.truetype(GEORGIA_B, 92)
sub_font = ImageFont.truetype(GEORGIA, 34)
tx = 470
draw.text((tx, 220), "SoulKey", font=title_font, fill=(247, 240, 230))
feat.save(os.path.join(OUT, "feature_1024x500.png"))
print("feature_1024x500.png OK")

# 3) Capturas: pad a ratio 2:1 exacto (ancho = alto/2) con fondo muestreado
for i in range(1, 6):
    im = Image.open(os.path.join(GOOGLE, f"{i}.jpeg")).convert("RGB")
    w, h = im.size
    target_w = max(w, (h + 1) // 2)  # asegura h/w <= 2
    if target_w != w:
        bg = im.getpixel((0, 0))
        canvas = Image.new("RGB", (target_w, h), bg)
        canvas.paste(im, ((target_w - w) // 2, 0))
        im = canvas
    im.save(os.path.join(OUT, f"screenshot_{i}.png"))
    print(f"screenshot_{i}.png OK {im.size} ratio={im.size[1]/im.size[0]:.3f}")

print("\nTodo en", OUT)
