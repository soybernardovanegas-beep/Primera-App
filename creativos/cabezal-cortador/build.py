import json, os, subprocess, sys
from PIL import Image, ImageDraw, ImageFont

S = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(S, "raw")
WORK = os.path.join(S, "work")
OUT = os.path.join(S, "out")
os.makedirs(WORK, exist_ok=True)
os.makedirs(OUT, exist_ok=True)
FD = "/usr/share/fonts/opentype/inter/"
BLACK = FD + "Inter-Black.otf"
XB = FD + "Inter-ExtraBold.otf"
W, H = 1080, 1920
LCX, LW = 385, 730  # text column left of the offer column
YEL, RED, GRN = (255, 212, 0), (229, 57, 53), (37, 211, 102)

# source clips and the crop that removes black bars / burned captions / watermarks
CLIPS = {
    "c1": ("77woshishuii_video_no_watermark.mp4", "crop=576:740:0:0"),
    "c3": ("Renata_Salazar_video_no_watermark.mp4", None),
    "c6": ("dropkiller-1539429091267256.mp4", "crop=720:1084:0:98"),
    "c7": ("dropkiller-1632841641762379.mp4", "crop=720:1180:0:90"),
    "c8": ("fffcccp_video_no_watermark.mp4", "crop=720:1160:0:60"),
    "c9": ("lukeadams_video_no_watermark.mp4", "crop=576:820:0:0"),
    "c10": ("mielectricoplomero_video_no_watermark.mp4", None),
    "c11": ("satatoolscolombia_video_no_watermark.mp4", None),
}

OFFER = {
    "precio": "$99.900",
    "envio": ["ENVÍO A TODA", "COLOMBIA"],
    "combo": "2 x $169.900",
    "ahorro": "Ahorras $29.900",  # 2 x 99.900 = 199.800 - 169.900 = 29.900
}


def font(p, s):
    return ImageFont.truetype(p, s)


def wrap(d, text, f, maxw):
    words, lines, cur = text.split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if d.textlength(t, font=f) <= maxw:
            cur = t
        else:
            lines.append(cur)
            cur = w
    lines.append(cur)
    return lines


def block(d, text, f, cx, y, maxw, fg, bg, pad=22, lh=1.12, radius=22):
    lines = wrap(d, text, f, maxw - 2 * pad)
    asc = f.size
    lw = max(d.textlength(l, font=f) for l in lines)
    bh = int(len(lines) * asc * lh + 2 * pad - asc * (lh - 1))
    bw = int(lw + 2 * pad)
    x0 = int(cx - bw / 2)
    if bg is not None:
        d.rounded_rectangle([x0, y, x0 + bw, y + bh], radius=radius, fill=bg)
    ty = y + pad - int(asc * 0.08)
    for l in lines:
        d.text((cx - d.textlength(l, font=f) / 2, ty), l, font=f, fill=fg)
        ty += int(asc * lh)
    return y + bh


def png(name, draw_fn):
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(im))
    p = os.path.join(WORK, name)
    im.save(p)
    return p


def side_column(d):
    x0, x1 = 770, 1058
    cx = (x0 + x1) / 2
    y = 480
    # price
    d.rounded_rectangle([x0, y, x1, y + 150], 22, fill=YEL)
    f = font(XB, 30)
    d.text((cx - d.textlength("PRECIO", font=f) / 2, y + 14), "PRECIO", font=f, fill="black")
    f = font(BLACK, 58)
    d.text((cx - d.textlength(OFFER["precio"], font=f) / 2, y + 52), OFFER["precio"], font=f, fill="black")
    y += 166
    # shipping
    d.rounded_rectangle([x0, y, x1, y + 112], 22, fill="white")
    f = font(BLACK, 34)
    for i, l in enumerate(OFFER["envio"]):
        d.text((cx - d.textlength(l, font=f) / 2, y + 16 + i * 42), l, font=f, fill="black")
    y += 128
    # promo
    d.rounded_rectangle([x0, y, x1, y + 196], 22, fill=RED)
    f = font(XB, 30)
    d.text((cx - d.textlength("PROMO", font=f) / 2, y + 14), "PROMO", font=f, fill="white")
    f = font(BLACK, 40)
    d.text((cx - d.textlength(OFFER["combo"], font=f) / 2, y + 56), OFFER["combo"], font=f, fill="white")
    f = font(XB, 31)
    d.rounded_rectangle([x0 + 18, y + 128, x1 - 18, y + 178], 14, fill=YEL)
    d.text((cx - d.textlength(OFFER["ahorro"], font=f) / 2, y + 134), OFFER["ahorro"], font=f, fill="black")
    y += 212
    # cash on delivery
    d.rounded_rectangle([x0, y, x1, y + 112], 22, fill=GRN)
    f = font(BLACK, 36)
    for i, l in enumerate(["PAGAS AL", "RECIBIR"]):
        d.text((cx - d.textlength(l, font=f) / 2, y + 14 + i * 44), l, font=f, fill="white")
    y += 124
    f = font(XB, 26)
    d.rounded_rectangle([x0, y, x1, y + 46], 12, fill=(0, 0, 0, 170))
    t = "No incluye taladro"
    d.text((cx - d.textlength(t, font=f) / 2, y + 8), t, font=f, fill="white")


def hook_png(name, lines):
    def fn(d):
        y = 285
        for i, (t, size, fg, bg) in enumerate(lines):
            y = block(d, t, font(BLACK, int(size * 0.82)), LCX, y, LW, fg, bg) + 14
    return png(name, fn)


def caption_png(name, text):
    def fn(d):
        f = font(BLACK, 60)
        lines = wrap(d, text, f, LW - 44)
        h = len(lines) * 67 + 44
        block(d, text, f, LCX, 1250 - h, LW, "black", YEL)
    return png(name, fn)


def endcard_png(name, headline):
    def fn(d):
        d.rectangle([0, 0, W, H], fill=(0, 0, 0, 165))
        cx = W / 2
        y = 290
        y = block(d, headline, font(BLACK, 58), cx, y, 1000, "white", None, pad=6) + 18
        y = block(d, OFFER["precio"], font(BLACK, 150), cx, y, 1000, "black", YEL, pad=26) + 22
        y = block(d, "PROMO 2 x $169.900", font(BLACK, 70), cx, y, 1000, "white", RED) + 12
        y = block(d, OFFER["ahorro"], font(XB, 46), cx, y, 1000, "black", YEL, pad=14) + 26
        f = font(XB, 44)
        for t in ["Envío a toda Colombia", "Pagas al recibir", "No incluye taladro"]:
            d.text((cx - d.textlength(t, font=f) / 2, y), t, font=f, fill="white")
            y += 58
        y += 18
        block(d, "ESCRÍBENOS POR WHATSAPP", font(BLACK, 54), cx, y, 1000, "white", GRN, pad=26, radius=40)
    return png(name, fn)


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode:
        print(r.stderr[-3000:])
        sys.exit(1)


def seg(i, clip, ss, dur, speed=1.0):
    src, crop = CLIPS[clip]
    vf = (crop + "," if crop else "") + \
        f"scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H},setsar=1"
    if speed != 1.0:
        vf += f",setpts=PTS/{speed}"
    vf += ",fps=30,eq=saturation=1.08:contrast=1.04"
    p = os.path.join(WORK, f"seg_{i}.mp4")
    run(["ffmpeg", "-v", "error", "-y", "-ss", str(ss), "-t", str(dur * speed), "-i", os.path.join(RAW, src),
         "-vf", vf, "-an", "-c:v", "libx264", "-crf", "18", "-preset", "veryfast", "-t", str(dur), p])
    return p


def build(ad):
    name = ad["name"]
    segs, t = [], 0.0
    caps = []
    for k, s in enumerate(ad["segments"]):
        p = seg(f"{name}_{k}", s["clip"], s["ss"], s["dur"], s.get("speed", 1.0))
        segs.append(p)
        if s.get("cap"):
            caps.append((s["cap"], t, t + s["dur"]))
        t += s["dur"]
    total = t
    end_dur = ad["segments"][-1]["dur"]
    end_t = total - end_dur

    # merge consecutive identical captions
    merged = []
    for c in caps:
        if merged and merged[-1][0] == c[0] and abs(merged[-1][2] - c[1]) < 1e-6:
            merged[-1] = (c[0], merged[-1][1], c[2])
        else:
            merged.append(c)

    inputs = []
    for p in segs:
        inputs += ["-i", p]
    n = len(segs)
    fc = "".join(f"[{i}:v]" for i in range(n)) + f"concat=n={n}:v=1:a=0[v0]"
    ov = [(png(f"{name}_side.png", side_column), 0, end_t),
          (hook_png(f"{name}_hook.png", ad["hook"]), 0, ad.get("hook_dur", 3.0))]
    for j, (txt, a, b) in enumerate(merged):
        ov.append((caption_png(f"{name}_cap{j}.png", txt), a, b))
    ov.append((endcard_png(f"{name}_end.png", ad["end_headline"]), end_t, total + 1))
    last = "v0"
    for j, (p, a, b) in enumerate(ov):
        inputs += ["-i", p]
        idx = n + j
        fc += f";[{last}][{idx}:v]overlay=0:0:enable='between(t,{a:.3f},{b - 0.001:.3f})'[v{j + 1}]"
        last = f"v{j + 1}"

    out = os.path.join(OUT, name + ".mp4")
    audio = ad.get("audio")
    cmd = ["ffmpeg", "-v", "error", "-y"] + inputs
    if audio and os.path.exists(audio):
        cmd += ["-i", audio]
        amap = ["-map", f"{n + len(ov)}:a", "-c:a", "aac", "-b:a", "160k", "-af", "apad"]
    else:
        cmd += ["-f", "lavfi", "-t", str(total), "-i", "anullsrc=r=44100:cl=stereo"]
        amap = ["-map", f"{n + len(ov)}:a", "-c:a", "aac", "-b:a", "128k"]
    cmd += ["-filter_complex", fc, "-map", f"[{last}]"] + amap + \
        ["-t", f"{total:.3f}", "-c:v", "libx264", "-crf", "21", "-preset", "medium", "-pix_fmt", "yuv420p",
         "-r", "30", "-movflags", "+faststart", out]
    run(cmd)
    print("OK", out, round(total, 2))


if __name__ == "__main__":
    ads = json.load(open(os.path.join(S, "ads.json")))
    only = sys.argv[1:]
    for ad in ads:
        if not only or ad["name"] in only:
            build(ad)
