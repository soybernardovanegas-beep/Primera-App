import sys, os, re, hashlib, subprocess, array, wave, json
sys.path.insert(0, os.path.dirname(__file__))
from plan import VIDEOS
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
W, H, FPS = 1080, 1920, 30
FONT = "/usr/share/fonts/opentype/inter/Inter-Black.otf"
YELLOW = (255, 212, 0); ORANGE = (255, 106, 0); BLACK = (0, 0, 0); WHITE = (255, 255, 255); DARK = (17, 17, 17)
LEAD, TAIL, MIN_TOTAL, MIN_CARD = 0.4, 0.4, 19.0, 4.0
BED = os.environ.get('BED') == '1'  # sonido de herramienta sintético: desactivado (no gustó)

SRC = {
    "dk1632": "entrada/cabezal/dropkiller-1632.mp4", "dk1539": "entrada/cabezal/dropkiller-1539.mp4",
    "ddgq": "entrada/cabezal/igexport-DdGQ.mp4", "ddob": "entrada/cabezal/igexport-Ddob.mp4",
    "fffcccp": "entrada/cabezal/fffcccp.mp4", "lab": "entrada/afilador/laboratorio_ferretero.mp4",
    "digify": "entrada/afilador/Digify_Mx.mp4", "ia_sin": "tmp/ia_sin_loop.mp4", "ia_afi": "entrada/afilador/IA_broca_afilada.mp4",
}
# recorte extra (fracciones superior, inferior) para quitar textos pequeños de la fuente
EXTRA = {"fffcccp": (0.06, 0.08), "digify": (0.0, 0.24), "dk1632": (0.07, 0.0)}

def run(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if r.returncode: print(" ".join(cmd)[:300], "\n", r.stderr[-1500:]); raise SystemExit(1)
    return r.stderr

def dur(p):
    return float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", p]))

def font(sz): return ImageFont.truetype(FONT, sz)

# ---------- preparación ----------
def prep_ia_loop():
    if os.path.exists("tmp/ia_sin_loop.mp4"): return
    run(["ffmpeg", "-v", "error", "-y", "-i", "entrada/afilador/IA_broca_sin_filo.mp4", "-filter_complex",
         "[0:v]fps=30,split=2[a][b];[b]reverse[r];[a][r]concat=n=2[x];[x]split=2[x1][x2];[x1][x2]concat=n=2[o]",
         "-map", "[o]", "-c:v", "libx264", "-preset", "veryfast", "-crf", "17", "-pix_fmt", "yuv420p", "tmp/ia_sin_loop.mp4"])

_crop = {}
def letterbox(key):
    if key in _crop: return _crop[key]
    p = SRC[key]
    err = subprocess.run(["ffmpeg", "-ss", "3", "-t", "4", "-i", p, "-vf", "cropdetect=24:2:0", "-f", "null", "-"], capture_output=True, text=True).stderr
    m = re.findall(r"crop=(\d+):(\d+):(\d+):(\d+)", err)
    c = tuple(map(int, m[-1])) if m else None
    _crop[key] = c
    return c

def trimmed(text):
    base = "tmp/phr/" + hashlib.md5(text.encode()).hexdigest()[:12]
    if not os.path.exists(base + "_t.wav"):
        run(["ffmpeg", "-v", "error", "-y", "-i", base + ".wav", "-af",
             "silenceremove=start_periods=1:start_threshold=-45dB,areverse,silenceremove=start_periods=1:start_threshold=-45dB,areverse",
             base + "_t.wav"])
    return base + "_t.wav"

# ---------- video ----------
def clip_filter(key, w, h):
    f = []
    lb = letterbox(key)
    if lb: f.append("crop=%d:%d:%d:%d" % lb)
    if key in EXTRA:
        t, b = EXTRA[key]
        f.append("crop=iw:ih*%.3f:0:ih*%.3f" % (1 - t - b, t))
    f.append("scale=%d:%d:force_original_aspect_ratio=increase,crop=%d:%d,fps=30,setsar=1,format=yuv420p" % (w, h, w, h))
    return ",".join(f)

def cut(key, ss, d, out, w=W, h=H):
    L = dur(SRC[key])
    if ss + d > L: ss = max(0, L - d)
    run(["ffmpeg", "-v", "error", "-y", "-stream_loop", "-1", "-ss", "%.3f" % ss, "-i", SRC[key], "-t", "%.3f" % d, "-an",
         "-vf", clip_filter(key, w, h), "-c:v", "libx264", "-preset", "veryfast", "-crf", "17", out])

def make_scene(vid, i, sc, d):
    out = "tmp/scn/%s_%d.mp4" % (vid, i)
    os.makedirs("tmp/scn", exist_ok=True)
    kind = sc.get("kind", "normal")
    if sc.get("card"):
        run(["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i", "color=c=0x111111:s=1080x1920:r=30", "-t", "%.3f" % d,
             "-c:v", "libx264", "-preset", "veryfast", "-crf", "17", "-pix_fmt", "yuv420p", out])
    elif kind == "split":
        a, b = out + ".a.mp4", out + ".b.mp4"
        cut(sc["clip"][0], sc["clip"][1], d, a, 540, H); cut(sc["clip2"][0], sc["clip2"][1], d, b, 540, H)
        run(["ffmpeg", "-v", "error", "-y", "-i", a, "-i", b, "-filter_complex", "hstack", "-c:v", "libx264", "-preset", "veryfast", "-crf", "17", "-pix_fmt", "yuv420p", out])
    elif kind == "seq":
        a, b = out + ".a.mp4", out + ".b.mp4"
        cut(sc["clip"][0], sc["clip"][1], d / 2, a); cut(sc["clip2"][0], sc["clip2"][1], d / 2, b)
        open(out + ".txt", "w").write("file '%s'\nfile '%s'\n" % (os.path.abspath(a), os.path.abspath(b)))
        run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", out + ".txt", "-c", "copy", out])
    else:
        cut(sc["clip"][0], sc["clip"][1], d, out)
    return out

# ---------- textos ----------
def wrap(words, f, maxw):
    lines, cur = [], ""
    for w_ in words:
        t = (cur + " " + w_).strip()
        if f.getlength(t) <= maxw or not cur: cur = t
        else: lines.append(cur); cur = w_
    if cur: lines.append(cur)
    return lines

def chunks(text, maxlines, f, maxw=920):
    words, out, cur = text.split(), [], []
    for w_ in words:
        if len(wrap(cur + [w_], f, maxw)) > maxlines and cur:
            out.append(cur); cur = [w_]
        else: cur.append(w_)
    if cur: out.append(cur)
    return [" ".join(c) for c in out]

def draw_box_text(d, lines, f, y, fg, bg, pad=22, lh=None):
    lh = lh or int(f.size * 1.18)
    for ln in lines:
        tw = f.getlength(ln)
        x0 = (W - tw) / 2
        d.rectangle([x0 - pad, y, x0 + tw + pad, y + lh], fill=bg)
        d.text((x0, y + (lh - f.size) // 2 - f.size * 0.12), ln, font=f, fill=fg)
        y += lh
    return y

def layer_bar(d, barra):
    sz = 64
    while font(sz).getlength(barra) > 1020 and sz > 56: sz -= 2
    d.rectangle([0, 290, W, 390], fill=YELLOW)
    f = font(sz)
    d.text(((W - f.getlength(barra)) / 2, 340 - sz * 0.62), barra, font=f, fill=BLACK)

def layer_headline(d, txt):
    f = font(64)
    lines = wrap(txt.split(), f, 900)
    y = draw_box_text(d, lines, f, 430, WHITE, BLACK)
    d.rectangle([60, y, W - 60, y + 8], fill=ORANGE)

def layer_sub(d, txt, card):
    f = font(60)
    lines = wrap(txt.split(), f, 940)
    if card:
        draw_box_text(d, lines, f, 1160, WHITE, BLACK, pad=16, lh=84)
    else:
        n = len(lines); y = 1235 - n * 84
        draw_box_text(d, lines, f, y, WHITE, BLACK, pad=16, lh=84)

def layer_card(d, v):
    price = v["barra"].split(" ·")[0]
    d.rectangle([0, 0, W, H], fill=DARK)
    d.rectangle([0, 270, W, 280], fill=ORANGE)
    y = 420
    def center(t, sz, col, y, lh=None):
        f = font(sz); d.text(((W - f.getlength(t)) / 2, y), t, font=f, fill=col); return y + (lh or int(sz * 1.25))
    y = center("TALLER MAESTRO", 60, ORANGE, y, 74)
    for ln in v["producto"]: y = center(ln, 66, WHITE, y, 84)
    y = center(price, 150, YELLOW, y + 4, 170)
    for o in v["ofertas"]: y = center(o, 66, WHITE, y, 74)
    y += 12
    for ln in ["ENVÍO GRATIS", "PAGAS AL RECIBIR", "GARANTÍA 10 DÍAS"]: y = center(ln, 60, WHITE, y, 62)
    center("ESCRÍBENOS POR WHATSAPP", 60, ORANGE, y + 4, 70)

def render_overlay(v, keys, cache):
    k = tuple(keys)
    if k in cache: return cache[k]
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    for kind, *args in keys:
        if kind == "card": layer_card(d, v)
        elif kind == "bar": layer_bar(d, v["barra"])
        elif kind == "head": layer_headline(d, args[0])
        elif kind == "sub": layer_sub(d, args[0], args[1])
    p = "tmp/ov/%s_%d.png" % (v["id"], len(cache))
    os.makedirs("tmp/ov", exist_ok=True); im.save(p); cache[k] = p
    return p

# ---------- audio ----------
def bed_filter(kind, T):
    if kind == "corte":
        return ("anoisesrc=c=pink:r=48000:a=0.9:d=%.2f,highpass=f=1500,lowpass=f=7000,tremolo=f=6.5:d=0.85[n];"
                "aevalsrc='0.35*sin(2*PI*(150+14*sin(2*PI*3.1*t))*t)+0.15*sin(2*PI*300*t)':s=48000:d=%.2f[m];"
                "[n][m]amix=inputs=2:normalize=0[bed]" % (T, T))
    return ("anoisesrc=c=white:r=48000:a=0.7:d=%.2f,highpass=f=700,lowpass=f=5500,tremolo=f=28:d=0.5[n];"
            "aevalsrc='0.4*sin(2*PI*(210+9*sin(2*PI*2.3*t))*t)+0.2*sin(2*PI*420*t)':s=48000:d=%.2f[m];"
            "[n][m]amix=inputs=2:normalize=0[bed]" % (T, T))

def build(vid):
    v = dict(VIDEOS[vid]); v["id"] = vid
    sc = v["scenes"]
    for s in sc: s["tw"] = trimmed(s["voz"]); s["dv"] = dur(s["tw"])
    durs = [LEAD + s["dv"] + (1.0 if s.get("card") else TAIL) for s in sc]
    durs[-1] = max(durs[-1], MIN_CARD)
    total = sum(durs)
    if total < MIN_TOTAL:
        extra = (MIN_TOTAL - total) / (len(sc) - 1)
        for i in range(len(sc) - 1): durs[i] += extra
        total = MIN_TOTAL
    starts = [sum(durs[:i]) for i in range(len(sc))]
    print(vid, "duración total %.1f s" % total, [round(x, 1) for x in durs])
    # escenas
    for i, s in enumerate(sc): make_scene(vid, i, s, durs[i])
    lst = "tmp/scn/%s.txt" % vid
    open(lst, "w").write("".join("file '%s'\n" % os.path.abspath("tmp/scn/%s_%d.mp4" % (vid, i)) for i in range(len(sc))))
    run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", "tmp/%s_video.mp4" % vid])
    # voz: pista con silencios
    sr = 24000
    buf = array.array("h", [0]) * int(total * sr + sr)
    events = []  # (t0, t1, key)
    for i, s in enumerate(sc):
        w_ = wave.open(s["tw"]); pcm = array.array("h"); pcm.frombytes(w_.readframes(w_.getnframes())); w_.close()
        o = int((starts[i] + LEAD) * sr)
        for j, x in enumerate(pcm):
            if o + j < len(buf): buf[o + j] = x
        t0 = starts[i] + LEAD
        # subtítulos sincronizados por reparto proporcional de caracteres
        cs = chunks(s["voz"], 1 if s.get("card") else 2, font(60))
        tot_c = sum(len(c) for c in cs); t = t0
        for c in cs:
            dd = s["dv"] * len(c) / tot_c
            events.append((t, t + dd, ("sub", c, bool(s.get("card"))))); t += dd
        if s.get("card"): events.append((starts[i], total, ("card",)))
        elif s.get("txt"): events.append((starts[i], starts[i] + durs[i], ("head", s["txt"])))
    events.append((0, total, ("bar",)))
    raw = "tmp/%s_vraw.wav" % vid
    w_ = wave.open(raw, "wb"); w_.setnchannels(1); w_.setsampwidth(2); w_.setframerate(sr); w_.writeframes(buf[:int(total * sr)].tobytes()); w_.close()
    os.makedirs("voz", exist_ok=True)
    run(["ffmpeg", "-v", "error", "-y", "-i", raw, "-af", "loudnorm=I=-16:TP=-1.5:LRA=7,aresample=48000", "voz/%s.wav" % vid])
    # mezcla: voz al frente, sonido de herramienta con ducking
    if BED:
        fc = (bed_filter(v["sonido"], total + 1) + ";[bed]volume=0.55[b];"
              "[0:a]asplit=2[v1][v2];[b][v2]sidechaincompress=threshold=0.015:ratio=10:attack=15:release=350:makeup=1[bd];"
              "[v1][bd]amix=inputs=2:normalize=0:duration=first,loudnorm=I=-16:TP=-1.5:LRA=9[a]")
    else:
        fc = "[0:a]loudnorm=I=-16:TP=-1.5:LRA=9[a]"
    run(["ffmpeg", "-v", "error", "-y", "-i", "voz/%s.wav" % vid, "-filter_complex", fc, "-map", "[a]", "-t", "%.3f" % total, "-ar", "48000", "tmp/%s_audio.wav" % vid])
    # overlays por intervalos
    cuts = sorted(set([0, total] + [e[0] for e in events] + [e[1] for e in events]))
    cache, lines = {}, []
    order = {"card": 0, "bar": 1, "head": 2, "sub": 3}
    for a, b in zip(cuts, cuts[1:]):
        if b - a < 0.01: continue
        keys = sorted([e[2] for e in events if e[0] <= a + 1e-6 and e[1] >= b - 1e-6], key=lambda k: order[k[0]])
        p = render_overlay(v, keys, cache)
        lines.append("file '%s'\nduration %.3f\n" % (os.path.abspath(p), b - a))
    lines.append("file '%s'\n" % os.path.abspath(p))
    open("tmp/%s_ov.txt" % vid, "w").write("".join(lines))
    out = "salida/%s.mp4" % v["file"]
    run(["ffmpeg", "-v", "error", "-y", "-i", "tmp/%s_video.mp4" % vid, "-f", "concat", "-safe", "0", "-i", "tmp/%s_ov.txt" % vid,
         "-i", "tmp/%s_audio.wav" % vid, "-filter_complex", "[1:v]fps=30,format=rgba[ov];[0:v][ov]overlay=0:0:shortest=1,format=yuv420p[o]",
         "-map", "[o]", "-map", "2:a", "-t", "%.3f" % total, "-c:v", "libx264", "-preset", "veryfast", "-crf", "21", "-r", "30",
         "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", out])
    print("->", out, "%.1f MB" % (os.path.getsize(out) / 1e6))

if __name__ == "__main__":
    os.makedirs("salida", exist_ok=True)
    prep_ia_loop()
    for vid in (sys.argv[1:] or VIDEOS): build(vid)
