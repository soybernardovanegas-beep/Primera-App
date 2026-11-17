"""Motor de render de anuncios XOLVETA (1080x1920, 30 fps, H.264+AAC, -14 LUFS)."""
import base64, hashlib, json, os, re, subprocess, sys, time, urllib.request, urllib.error
from PIL import Image, ImageDraw, ImageFilter, ImageFont
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fuentes import SRC, FUENTES, filtro

AQUI = os.path.dirname(os.path.abspath(__file__))
WORK = os.environ.get("XV_WORK", "/tmp/claude-0/-home-user-Primera-App/7f6186a7-390b-5611-a850-44352e5e8f96/scratchpad/work")
os.makedirs(WORK + "/vo", exist_ok=True)
FONTS = "/usr/share/fonts/opentype/inter"
MODEL, VOICE, TEMPO = os.environ.get("XV_TTS", "gemini-3.1-flash-tts-preview"), "Puck", 1.12
STYLE = ("Lee esto en español de Colombia, con acento colombiano natural, como un maestro de obra "
         "cercano que le explica algo a un vecino, tuteando, ritmo ágil y claro, sin sonar a vendedor "
         "de televisión. Haz una pausa de medio segundo entre cada línea y una pausa corta en las comas y los puntos suspensivos:\n\n")
AMARILLO = "&H0000D4FF&"; BLANCO = "&H00FFFFFF&"
CARD_T = 2.5

def run(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if r.returncode: sys.exit("ERROR:\n" + " ".join(map(str, cmd))[:400] + "\n" + r.stderr[-1500:])
    return r

def dur(path):
    return float(run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path]).stdout)

# ---------------------------------------------------------------- voz
_ULT = [0.0]
def tts(text):
    h = hashlib.md5((MODEL + VOICE + text).encode()).hexdigest()[:12]
    wav = f"{WORK}/vo/{h}.wav"
    if os.path.exists(wav): return wav
    body = json.dumps({"contents": [{"parts": [{"text": STYLE + text}]}],
        "generationConfig": {"responseModalities": ["AUDIO"],
        "speechConfig": {"voiceConfig": {"prebuiltVoiceConfig": {"voiceName": VOICE}}}}}).encode()
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"
    for a in range(12):
        try:
            espera = 14 - (time.time() - _ULT[0])
            if espera > 0: time.sleep(espera)      # ritmo: la cuota del TTS preview es por minuto
            _ULT[0] = time.time()
            r = urllib.request.Request(url, body, {"Content-Type": "application/json", "x-goog-api-key": "x"})
            d = json.load(urllib.request.urlopen(r, timeout=180))
            if "candidates" not in d: raise RuntimeError("sin audio: " + json.dumps(d)[:200])
            pcm = base64.b64decode(d["candidates"][0]["content"]["parts"][0]["inlineData"]["data"])
            open(wav + ".pcm", "wb").write(pcm)
            run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", "24000", "-ac", "1", "-i", wav + ".pcm",
                 "-af", "silenceremove=start_periods=1:start_threshold=-45dB,areverse,"
                        "silenceremove=start_periods=1:start_threshold=-45dB,areverse,"
                        f"atempo={TEMPO}", "-ar", "48000", wav])
            os.remove(wav + ".pcm"); return wav
        except urllib.error.HTTPError as e:
            msg = e.read().decode(errors="replace"); print("  reintento TTS", e.code, msg[:120], flush=True)
            m = re.search(r'"retryDelay":\s*"(\d+)', msg); time.sleep(int(m.group(1)) + 3 if m else min(60, 8 * (a + 1)))
        except Exception as e:
            print("  reintento TTS", e, flush=True); time.sleep(min(60, 8 * (a + 1)))
    sys.exit("TTS falló: " + text)

def tts_lineas(lineas):
    """Una sola llamada TTS para todas las líneas; se parte por los N-1 silencios más largos."""
    if len(lineas) == 1: return [tts(lineas[0])]
    h = hashlib.md5((MODEL + "|".join(lineas)).encode()).hexdigest()[:12]
    marca = f"{WORK}/vo/multi_{h}.json"
    if os.path.exists(marca): return json.load(open(marca))
    todo = tts("\n".join(lineas))
    r = run(["ffmpeg", "-hide_banner", "-i", todo, "-af", "silencedetect=noise=-38dB:d=0.22", "-f", "null", "-"]).stderr
    ini = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", r)]
    fin = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", r)]
    sil = [(a, b) for a, b in zip(ini, fin) if a > 0.15]
    D = dur(todo)
    sil = [x for x in sil if x[1] < D - 0.1]
    if len(sil) < len(lineas) - 1: sys.exit(f"Solo {len(sil)} pausas para {len(lineas)} líneas: {lineas}")
    cortes = sorted(sorted(sil, key=lambda x: x[1] - x[0], reverse=True)[:len(lineas) - 1])
    pts = [0.0] + [(a + b) / 2 for a, b in cortes] + [D]; out = []
    for k in range(len(lineas)):
        w = f"{WORK}/vo/{h}_{k}.wav"
        run(["ffmpeg", "-v", "error", "-y", "-ss", f"{pts[k]:.3f}", "-to", f"{pts[k+1]:.3f}", "-i", todo, "-af",
             "silenceremove=start_periods=1:start_threshold=-45dB,areverse,silenceremove=start_periods=1:start_threshold=-45dB,areverse", w])
        out.append(w)
    json.dump(out, open(marca, "w")); return out

# ---------------------------------------------------------------- subtítulos / textos (ASS)
def ts(t):
    if isinstance(t, str): return t
    h = int(t // 3600); m = int(t % 3600 // 60); s = t % 60
    return f"{h}:{m:02d}:{s:05.2f}"

def norm(w): return re.sub(r"[^\wáéíóúüñ#]", "", w.lower())

def subs(text, t0, t1, kws):
    """Divide `text` en eventos de máx. 2 líneas (24 car.) con tiempos proporcionales a los caracteres."""
    toks = text.split(); flags = [False] * len(toks); nt = [norm(w) for w in toks]
    for k in kws:
        kt = [norm(x) for x in k.split()]
        for i in range(len(toks) - len(kt) + 1):
            if nt[i:i + len(kt)] == kt:
                for j in range(len(kt)): flags[i + j] = True
    ev = []; cur = []; cl = 0; lines = 1
    def flush():
        nonlocal cur, cl, lines
        if cur: ev.append(cur)
        cur = []; cl = 0; lines = 1
    for i, w in enumerate(toks):
        L = len(w)
        if cl and cl + 1 + L > 24:
            if lines == 2: flush()
            else: lines = 2; cl = 0; cur.append((None, False))
        cl += (1 if cl else 0) + L; cur.append((w, flags[i]))
        if re.search(r"[.?!…]$", w) and len(cur) >= 3: flush()
    flush()
    tot = sum(len(w) + 1 for e in ev for w, _ in e if w) or 1
    out = []; t = t0
    for e in ev:
        n = sum(len(w) + 1 for w, _ in e if w); d = (t1 - t0) * n / tot
        parts = []
        for w, f in e:
            if w is None: parts.append("\\N")
            else:
                parts.append((("{\\c" + AMARILLO + "}" + w + "{\\c" + BLANCO + "}") if f else w) + " ")
        s = "".join(parts).replace(" \\N", "\\N").strip()
        out.append(f"Dialogue: 0,{ts(t)},{ts(t + d)},Sub,,0,0,0,,{s}")
        t += d
    return out

ASS_HEAD = f"""[Script Info]
ScriptType: v4.00+
PlayResX: 1080
PlayResY: 1920
WrapStyle: 2
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name,Fontname,Fontsize,PrimaryColour,SecondaryColour,OutlineColour,BackColour,Bold,Italic,Underline,StrikeOut,ScaleX,ScaleY,Spacing,Angle,BorderStyle,Outline,Shadow,Alignment,MarginL,MarginR,MarginV,Encoding
Style: Sub,Inter ExtraBold,62,{BLANCO},{BLANCO},&H26000000&,&H00000000&,0,0,0,0,100,100,0,0,3,20,0,2,60,60,430,1
Style: Titulo,Inter Black,92,{BLANCO},{BLANCO},&H26000000&,&H00000000&,0,0,0,0,100,100,0,0,3,26,0,2,50,50,720,1
Style: Chip,Inter Black,60,&H00000000&,&H00000000&,{AMARILLO},&H00000000&,0,0,0,0,100,100,0,0,3,18,0,7,0,0,0,1
Style: Num,Inter Black,210,&H00000000&,&H00000000&,{AMARILLO},&H00000000&,0,0,0,0,100,100,0,0,3,34,0,8,0,0,285,1
Style: Item,Inter Black,70,{BLANCO},{BLANCO},&H26000000&,&H00000000&,0,0,0,0,100,100,0,0,3,20,0,7,0,0,0,1
Style: Nada,Inter Black,10,&H00FFFFFF&,&H00FFFFFF&,&H00000000&,&H00000000&,0,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1

[Events]
Format: Layer,Start,End,Style,Name,MarginL,MarginR,MarginV,Effect,Text
"""

def titulo(lineas, t0, t1, resalta=()):
    s = "\\N".join(lineas)
    for r in resalta: s = s.replace(r, "{\\c" + AMARILLO + "}" + r + "{\\c" + BLANCO + "}")
    return f"Dialogue: 1,{ts(t0)},{ts(t1)},Titulo,,0,0,0,,{{\\fad(120,80)}}{s}"

def num(n, t0, t1):
    return f"Dialogue: 1,{ts(t0)},{ts(t1)},Num,,0,0,0,,{{\\fad(80,60)}} {n} "

def chip(texto, t0, t1, x=60, y=300, color=None):
    c = ("{\\3c" + color + "\\1c&H00FFFFFF&}") if color else ""
    return f"Dialogue: 1,{ts(t0)},{ts(t1)},Chip,,0,0,0,,{{\\pos({x},{y})}}{c}{texto}"

CHECK = "m 6 34 l 22 18 l 34 30 l 64 0 l 80 16 l 34 62 l 6 34"
CRUZ = "m 0 16 l 16 0 l 40 24 l 64 0 l 80 16 l 56 40 l 80 64 l 64 80 l 40 56 l 16 80 l 0 64 l 24 40"
def item(texto, ok, t0, t1, y):
    """Fila de lista con ícono dibujado (vector) y 'pop' corto."""
    col = "&H0000C800&" if ok else "&H003030E0&"   # verde / rojo (BGR)
    forma = CHECK if ok else CRUZ
    pop = "\\fscx55\\fscy55\\t(0,140,\\fscx108\\fscy108)\\t(140,240,\\fscx100\\fscy100)"
    a = f"Dialogue: 2,{ts(t0)},{ts(t1)},Nada,,0,0,0,,{{\\an7\\pos(70,{y + 6})\\1c{col}\\bord0\\shad0\\p1{pop}}}{forma}{{\\p0}}"
    b = f"Dialogue: 2,{ts(t0)},{ts(t1)},Item,,0,0,0,,{{\\an7\\pos(190,{y - 12}){pop}\\3c&H26000000&}}{texto}"
    return [a, b]

# ---------------------------------------------------------------- tarjeta final
def hacer_tarjeta(frame_png, out_png):
    base = Image.open(frame_png).convert("RGB").resize((1080, 1920))
    base = base.filter(ImageFilter.GaussianBlur(34))
    base = Image.blend(base, Image.new("RGB", base.size, (0, 0, 0)), 0.62)
    d = ImageDraw.Draw(base)
    fb = ImageFont.truetype(f"{FONTS}/Inter-ExtraBold.otf", 56); fk = ImageFont.truetype(f"{FONTS}/Inter-Black.otf", 74)
    filas = ["Envío gratis a toda Colombia", "Pagas al recibir", "Garantía de 10 días"]
    y = 640
    mw = max(d.textlength(t, font=fb) for t in filas)
    for t in filas:
        x0 = (1080 - (mw + 110)) / 2
        cx, cy = x0 + 40, y + 46
        d.ellipse((cx - 40, cy - 40, cx + 40, cy + 40), fill=(37, 211, 102))
        d.line([(cx - 18, cy + 2), (cx - 4, cy + 16), (cx + 22, cy - 14)], fill="white", width=11, joint="curve")
        d.text((x0 + 110, y + 4), t, font=fb, fill="white"); y += 140
    bw, bh = 780, 160; bx, by = (1080 - bw) // 2, 1130
    d.rounded_rectangle((bx, by, bx + bw, by + bh), radius=80, fill=(37, 211, 102))
    t = "PÍDELO AQUÍ"; w = d.textlength(t, font=fk)
    d.text(((1080 - w) / 2, by + 36), t, font=fk, fill="white")
    return base

def lazo(img):
    """Moño rojo pequeño (esquina) para el anuncio de Navidad."""
    d = ImageDraw.Draw(img); cx, cy = 900, 360
    d.polygon([(cx, cy), (cx - 90, cy - 55), (cx - 90, cy + 55)], fill=(200, 25, 40))
    d.polygon([(cx, cy), (cx + 90, cy - 55), (cx + 90, cy + 55)], fill=(200, 25, 40))
    d.ellipse((cx - 24, cy - 24, cx + 24, cy + 24), fill=(150, 15, 30))
    d.polygon([(cx - 10, cy + 20), (cx - 55, cy + 110), (cx - 25, cy + 105)], fill=(200, 25, 40))
    d.polygon([(cx + 10, cy + 20), (cx + 55, cy + 110), (cx + 25, cy + 105)], fill=(200, 25, 40))
    return img

# ---------------------------------------------------------------- render
def cortar(clave, a, b, salida, zoom=1.0, vel=None):
    d = b - a; extra = ""
    if vel: extra = f",setpts=PTS/{vel}"
    run(["ffmpeg", "-v", "error", "-y", "-ss", f"{a:.3f}", "-t", f"{d:.3f}", "-i", f"{SRC}/{FUENTES[clave][0]}",
         "-an", "-vf", filtro(clave, zoom) + extra, "-c:v", "libx264", "-preset", "veryfast", "-crf", "17", salida])

def panel(clave, a, d, w, h, salida):
    """Mitad de pantalla dividida (w x h) tomada del centro del plano."""
    f = filtro(clave) + f",crop=1080:{h * 1080 // w if False else h}:0:{(1920 - h) // 2},scale={w}:{h}"
    run(["ffmpeg", "-v", "error", "-y", "-ss", f"{a:.3f}", "-t", f"{d:.3f}", "-i", f"{SRC}/{FUENTES[clave][0]}",
         "-an", "-vf", f, "-c:v", "libx264", "-preset", "veryfast", "-crf", "17", salida])

def construir(nombre, beats, kws, tarjeta_lazo=False):
    print(f"\n=== {nombre} ===", flush=True)
    W = f"{WORK}/{nombre}"; os.makedirs(W, exist_ok=True)
    t = 0.0; ass = []; clips = []; audio = []   # audio: (archivo, inicio)
    ultimo_plano = None; fines = []
    textos = [b["voz"] for b in beats if b.get("voz")]
    vox = dict(zip([id(b) for b in beats if b.get("voz")], tts_lineas(textos)))
    for i, bt in enumerate(beats):
        txt = bt.get("voz")
        vd = 0.0; wav = None
        if bt.get("audio_clip"):
            ac = f"{W}/b{i}_clipaudio.wav"
            run(["ffmpeg", "-v", "error", "-y", "-i", f"{SRC}/{FUENTES[bt['audio_clip']][0]}", "-vn", "-ac", "1", "-ar", "48000", ac])
            wav = ac; vd = bt["voz_dur"]
        elif txt:
            wav = vox[id(bt)]; vd = dur(wav)
        lead = bt.get("lead", 0.12)
        D = max(vd + lead + bt.get("cola", 0.40), bt.get("min", 0))
        if bt.get("exacto"): D = bt["exacto"]
        # planos
        shots = bt["planos"]
        if bt.get("split"):   # pantalla dividida: dos paneles apilados
            (c1, a1, b1), (c2, a2, b2) = shots
            hh = 960
            p1, p2 = f"{W}/b{i}_p1.mp4", f"{W}/b{i}_p2.mp4"
            panel(c1, a1, min(D, b1 - a1), 1080, hh, p1); panel(c2, a2, min(D, b2 - a2), 1080, hh, p2)
            out = f"{W}/b{i}.mp4"
            run(["ffmpeg", "-v", "error", "-y", "-i", p1, "-i", p2, "-filter_complex",
                 f"[0:v]tpad=stop_mode=clone:stop_duration=5,trim=duration={D:.3f},setpts=PTS-STARTPTS[a];"
                 f"[1:v]tpad=stop_mode=clone:stop_duration=5,trim=duration={D:.3f},setpts=PTS-STARTPTS[b];"
                 f"[a][b]vstack,format=yuv420p,fps=30[v]", "-map", "[v]", "-c:v", "libx264", "-preset", "veryfast", "-crf", "17", out])
            clips.append(out)
        else:
            tot = sum(b - a for _, a, b, *_ in [(s[0], s[1], s[2]) for s in shots])
            for j, s in enumerate(shots):
                c, a, b = s[0], s[1], s[2]; zoom = s[3] if len(s) > 3 else 1.0
                d = D * (b - a) / tot if len(shots) > 1 else D
                avail = b - a
                vel = None
                if d > avail + 0.05:
                    vel = avail / d
                    if vel < 0.68: sys.exit(f"{nombre} beat {i}: plano {c} {a}-{b} muy corto para {d:.2f}s")
                    print(f"  aviso: {c} {a}-{b} estirado x{vel:.2f}")
                    d_src = avail
                else:
                    d_src = d
                out = f"{W}/b{i}_{j}.mp4"
                cortar(c, a, a + d_src, out, zoom, vel)
                clips.append(out)
        if wav: audio.append((wav, t + lead))
        # subtítulos
        if txt or bt.get("sub"):
            ass += subs(bt.get("sub", txt), t + lead, t + lead + vd, kws)
        for ev in bt.get("extras", []):
            ass += ev(t, D, vd, lead)
        if bt.get("sonido"):
            c, a, b = bt["sonido"]; sw = f"{W}/b{i}_amb.wav"
            run(["ffmpeg", "-v", "error", "-y", "-ss", f"{a:.2f}", "-t", f"{b-a:.2f}", "-i", f"{SRC}/{FUENTES[c][0]}", "-vn", "-ac", "1", "-ar", "48000",
                 "-af", "afade=t=in:d=0.05,afade=t=out:st=%.2f:d=0.2" % max(0, b - a - 0.2), sw])
            audio.append((sw, t))
        fines.append(t + D)
        t += D
    TOTAL = t
    ass = [re.sub(r"@E(\d+)", lambda m: ts(fines[int(m.group(1))]), e) for e in ass]
    # unir
    lista = f"{W}/lista.txt"; open(lista, "w").write("".join(f"file '{c}'\n" for c in clips))
    crudo = f"{W}/crudo.mp4"
    run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", lista, "-c", "copy", crudo])
    # tarjeta
    run(["ffmpeg", "-v", "error", "-y", "-sseof", "-0.2", "-i", crudo, "-frames:v", "1", f"{W}/ult.png"])
    card = hacer_tarjeta(f"{W}/ult.png", None)
    if tarjeta_lazo: card = lazo(card)
    card.save(f"{W}/tarjeta.png")
    open(f"{W}/s.ass", "w").write(ASS_HEAD + "\n".join(ass) + "\n")
    # audio
    entradas = []; fc = []
    for k, (w, st) in enumerate(audio):
        entradas += ["-i", w]; fc.append(f"[{k+1}:a]adelay={int(st*1000)}|{int(st*1000)},apad[a{k}]")
    n = len(audio)
    mezcla = "".join(f"[a{k}]" for k in range(n)) + f"amix=inputs={n}:duration=longest:normalize=0,atrim=0:{TOTAL:.3f},asetpts=PTS-STARTPTS[mx]"
    t0c = TOTAL - CARD_T
    fv = (f"[0:v]ass={W}/s.ass:fontsdir={FONTS}[v0];"
          f"[{n+1}:v]format=rgba,fade=in:st={t0c:.3f}:d=0.25:alpha=1[cd];[v0][cd]overlay=enable='gte(t,{t0c:.3f})':format=auto,format=yuv420p[vv]")
    base = ["ffmpeg", "-v", "error", "-y", "-i", crudo] + entradas + ["-loop", "1", "-framerate", "30", "-t", f"{TOTAL:.3f}", "-i", f"{W}/tarjeta.png"]
    # 1ª pasada: medir loudness
    pre = f"{W}/pre.wav"
    run(base + ["-filter_complex", ";".join(fc) + ";" + mezcla, "-map", "[mx]", "-t", f"{TOTAL:.3f}", "-ar", "48000", "-ac", "2", pre])
    m = run(["ffmpeg", "-hide_banner", "-i", pre, "-af", "loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json", "-f", "null", "-"]).stderr
    j = json.loads(m[m.rindex("{"):m.rindex("}") + 1])
    ln = (f"loudnorm=I=-14:TP=-1.5:LRA=11:measured_I={j['input_i']}:measured_TP={j['input_tp']}:"
          f"measured_LRA={j['input_lra']}:measured_thresh={j['input_thresh']}:offset={j['target_offset']}:linear=true")
    out = f"{AQUI}/{nombre}.mp4"
    run(base + ["-filter_complex", ";".join(fc) + ";" + mezcla + f";[mx]{ln}[aa];" + fv, "-map", "[vv]", "-map", "[aa]",
                "-t", f"{TOTAL:.3f}", "-c:v", "libx264", "-preset", "medium", "-crf", "21", "-maxrate", "7M", "-bufsize", "14M",
                "-profile:v", "high", "-pix_fmt", "yuv420p", "-r", "30", "-c:a", "aac", "-b:a", "128k", "-ar", "48000", "-ac", "2",
                "-movflags", "+faststart", out])
    mb = os.path.getsize(out) / 1e6
    print(f"  {nombre}.mp4  {TOTAL:.1f}s  {mb:.1f} MB", flush=True)
    return out, TOTAL, [(w, tx) for w, tx in []]

def miniatura(mp4, t, jpg):
    run(["ffmpeg", "-v", "error", "-y", "-ss", f"{t:.2f}", "-i", mp4, "-frames:v", "1", "-q:v", "2", jpg])

def hoja_pruebas(mp4, total, nombre, ts_list):
    run(["mkdir", "-p", f"{WORK}/prueba"])
    ims = []
    for k, t in enumerate(ts_list):
        o = f"{WORK}/prueba/{nombre}_{k}.jpg"
        run(["ffmpeg", "-v", "error", "-y", "-ss", f"{t:.2f}", "-i", mp4, "-frames:v", "1", "-vf", "scale=360:-2", o]); ims.append(Image.open(o))
    S = Image.new("RGB", (sum(i.width for i in ims) + 10 * (len(ims) - 1), ims[0].height), "white"); x = 0
    for i in ims: S.paste(i, (x, 0)); x += i.width + 10
    p = f"{WORK}/prueba/{nombre}_hoja.jpg"; S.save(p, quality=90); return p
