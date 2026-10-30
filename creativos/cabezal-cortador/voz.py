"""Locución con Gemini TTS: una petición por video (gancho + subtítulos, una línea cada uno),
cortada por las pausas entre líneas; los tramos se ajustan a la duración de cada frase.

python3 -I voz.py            # genera/usa caché en voz/cache, reescribe ads.json y voz/<name>.wav
Luego: python3 -I build.py
"""
import base64, hashlib, json, os, re, subprocess, sys, time, urllib.request, urllib.error

S = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(S, "raw")
VOZ = os.path.join(S, "voz")
CACHE = os.path.join(VOZ, "cache")
os.makedirs(CACHE, exist_ok=True)

MODEL = "gemini-3.1-flash-tts-preview"
VOICE = "Puck"
STYLE = ("Lee esto en español de Colombia, con acento colombiano natural, como un vendedor "
         "entusiasta y cercano en un anuncio de redes sociales, ritmo ágil y claro. "
         "Haz una pausa corta entre cada línea:\n\n")
RATE = 24000
GAP = 0.3       # silencio después de cada frase
LEAD = 0.15     # silencio antes de la primera frase
MIN_SEG = 0.8   # duración mínima de un tramo de video
END_MIN = 3.5   # duración mínima de la tarjeta de cierre
CLOSE_TEMPO = 1.12  # el cierre es largo (cifras en palabras): se acelera un poco para quedar < 30 s
# oferta hablada sobre la tarjeta de cierre (igual en los 7 videos)
CLOSE = ("Llévalo por solo $99.900 pesos, o dos por $169.900. "
         "Envío a toda Colombia y pagas al recibir. ¡Escríbenos por WhatsApp!")

# clip -> archivo (igual que build.py)
sys.path.insert(0, S)
from build import CLIPS  # noqa: E402

# cómo se dice en voz lo que en pantalla va con cifras
SPOKEN = [
    ("$169.900", "ciento sesenta y nueve mil novecientos"),
    ("$99.900", "noventa y nueve mil novecientos"),
    ("Lleva 2 por", "Lleva dos por"),
    ("calibre 20 (1 mm)", "calibre veinte, de un milímetro,"),
    ("hasta 1 mm", "hasta de un milímetro"),
]


def spoken(text):
    for a, b in SPOKEN:
        text = text.replace(a, b)
    if text.isupper() or sum(c.isupper() for c in text) > len(text) * 0.6:
        text = text.lower()
        text = re.sub(r"(^|[¿¡.] ?)([a-záéíóúñ])", lambda m: m.group(1) + m.group(2).upper(), text)
    if not re.search(r"[.?!,]$", text):
        text += "."
    return text


def dur(p):
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", p],
                       capture_output=True, text=True)
    return float(r.stdout.strip())


def request(text):
    body = json.dumps({
        "contents": [{"parts": [{"text": STYLE + text}]}],
        "generationConfig": {"responseModalities": ["AUDIO"],
                             "speechConfig": {"voiceConfig": {"prebuiltVoiceConfig": {"voiceName": VOICE}}}},
    }).encode()
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"
    for attempt in range(12):
        req = urllib.request.Request(url, body, {"Content-Type": "application/json",
                                                 "x-goog-api-key": os.environ.get("GEMINI_API_KEY", "x")})
        wait = min(5 * 2 ** attempt, 120)
        try:
            d = json.load(urllib.request.urlopen(req, timeout=180))
            return base64.b64decode(d["candidates"][0]["content"]["parts"][0]["inlineData"]["data"])
        except urllib.error.HTTPError as e:
            msg = e.read().decode(errors="replace")
            m = re.search(r'"retryDelay":\s*"(\d+)', msg)  # 429: Gemini dice cuánto esperar
            if m:
                wait = min(int(m.group(1)) + 2, 900)
            if wait > 600 and "PerDay" in msg:
                sys.exit(f"Cuota de {MODEL} agotada: {msg[:400]}")
            print("  reintento", attempt + 1, e.code, f"espera {wait}s", flush=True)
        except (urllib.error.URLError, KeyError, TimeoutError) as e:
            print("  reintento", attempt + 1, e, flush=True)
        time.sleep(wait)
    sys.exit("TTS falló")


def silences(wav):
    r = subprocess.run(["ffmpeg", "-i", wav, "-af", "silencedetect=n=-40dB:d=0.12", "-f", "null", "-"],
                       capture_output=True, text=True)
    st = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", r.stderr)]
    en = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", r.stderr)]
    return list(zip(st, en))


def pick_cuts(sil, chars, total):
    """Elige len(chars)-1 pausas cuyo reparto se parezca más a la longitud de cada línea."""
    import math
    n, k = len(chars), len(sil)
    if n == 1:
        return []
    if k < n - 1:
        return None
    rate = total / sum(chars)
    mids = [(a + b) / 2 for a, b in sil]

    def cost(i, t0, t1):  # línea i entre t0 y t1
        return math.log(max(t1 - t0, 0.05) / (chars[i] * rate)) ** 2

    INF = float("inf")
    # best[j][c] = costo de las líneas 0..j terminando en el corte c
    best = [[INF] * k for _ in range(n - 1)]
    back = [[-1] * k for _ in range(n - 1)]
    for c in range(k):
        best[0][c] = cost(0, 0, mids[c]) - 0.5 * (sil[c][1] - sil[c][0])
    for j in range(1, n - 1):
        for c in range(j, k):
            for p in range(j - 1, c):
                v = best[j - 1][p] + cost(j, mids[p], mids[c]) - 0.5 * (sil[c][1] - sil[c][0])
                if v < best[j][c]:
                    best[j][c], back[j][c] = v, p
    if n == 1:
        return []
    c = min(range(k), key=lambda c: best[n - 2][c] + cost(n - 1, mids[c], total))
    out = []
    for j in range(n - 2, -1, -1):
        out.append(sil[c])
        c = back[j][c]
    return out[::-1]


def tts_lines(lines):
    """Una petición con todas las líneas; devuelve un wav recortado por línea."""
    key = hashlib.sha1(f"{MODEL}|{VOICE}|{STYLE}|{lines}".encode()).hexdigest()[:16]
    outs = [os.path.join(CACHE, f"{key}_{i}.wav") for i in range(len(lines))]
    if all(os.path.exists(p) for p in outs):
        return outs
    for attempt in range(3):
        full = os.path.join(CACHE, f"{key}_full{attempt}.wav")
        if not os.path.exists(full):
            tmp = full + ".pcm"
            open(tmp, "wb").write(request("\n".join(lines)))
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(RATE), "-ac", "1", "-i", tmp,
                            full], check=True)
            os.remove(tmp)
        total = dur(full)
        allsil = silences(full)
        sil = [(a, b) for a, b in allsil if a > 0.05 and b < total - 0.05]  # internas
        cuts = pick_cuts(sil, [len(l) for l in lines], total)
        if cuts is not None:
            edges = [0.0] + [(a + b) / 2 for a, b in cuts] + [total]
            spans, ok = [], True
            for i, line in enumerate(lines):
                t0, t1 = edges[i], edges[i + 1]
                for x, y in allsil:  # quita la media pausa que queda en cada borde
                    if x <= t0 + 0.02 < y:
                        t0 = y - 0.03
                    if x < t1 - 0.02 <= y:
                        t1 = x + 0.05
                spans.append((t0, t1))
                cps = len(line) / (t1 - t0)
                if not 8 <= cps <= 24:  # el corte no cuadra con el texto
                    print(f"  corte dudoso ({cps:.1f} c/s): {line}", flush=True)
                    ok = False
            if ok:
                for (t0, t1), p in zip(spans, outs):
                    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", full, "-ss", f"{t0:.3f}",
                                    "-to", f"{t1:.3f}", p], check=True)
                return outs
        print("  no se pudo cortar por pausas, se pide de nuevo", flush=True)
    sys.exit("No se pudo cortar la locución en frases")


def faster(wav, tempo):
    out = wav[:-4] + f"_x{tempo}.wav"
    if not os.path.exists(out):
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", wav, "-af", f"atempo={tempo}", out], check=True)
    return out


def groups(ad):
    """Agrupa tramos: gancho (tramos iniciales sin subtítulo), cada subtítulo, y cierre (último tramo).
    Devuelve (texto, índices de tramo, tipo) con tipo "hook", "cap" o "close"."""
    segs = ad["segments"]
    out, k = [], 0
    hook = []
    while k < len(segs) - 1 and not segs[k].get("cap"):
        hook.append(k)
        k += 1
    out.append((" ".join(spoken(t) for t, *_ in ad["hook"]), hook, "hook"))
    while k < len(segs) - 1:
        cap, idx = segs[k]["cap"], []
        while k < len(segs) - 1 and segs[k].get("cap") == cap:
            idx.append(k)
            k += 1
        out.append((cap, idx, "cap"))
    out.append((CLOSE, [len(segs) - 1], "close"))  # debe ir de último (ver main)
    return out


def fit(ad, idx, target):
    """Reparte target segundos entre los tramos idx, proporcional a su duración actual."""
    segs = ad["segments"]
    cur = sum(segs[i]["dur"] for i in idx)
    new = [max(MIN_SEG, segs[i]["dur"] * target / cur) for i in idx]
    extra = sum(new) - target
    if extra > 1e-3:  # algún tramo quedó en el mínimo: quita el exceso a los demás
        free = [j for j, v in enumerate(new) if v > MIN_SEG]
        tot = sum(new[j] for j in free) or 1
        for j in free:
            new[j] = max(MIN_SEG, new[j] - extra * new[j] / tot)
    for i, v in zip(idx, new):
        s = segs[i]
        s["dur"] = round(v, 2)
        src = os.path.join(RAW, CLIPS[s["clip"]][0])
        room = dur(src) - 0.05 - s["dur"] * s.get("speed", 1.0)
        if s["ss"] > room:  # no alcanza el clip: arranca antes
            s["ss"] = round(max(0.0, room), 2)
    return sum(segs[i]["dur"] for i in idx)


def main():
    path = os.path.join(S, "ads.json")
    ads = json.load(open(path))
    only = sys.argv[1:]
    for ad in ads:
        if only and ad["name"] not in only:
            continue
        print(ad["name"])
        t, parts = 0.0, []
        gs = groups(ad)
        # el cierre es igual en todos: se pide una sola vez y se pega al final
        wavs = tts_lines([spoken(text) for text, _, kind in gs if kind != "close"]) + [faster(tts_lines([spoken(CLOSE)])[0], CLOSE_TEMPO)]
        for gi, ((text, idx, kind), wav) in enumerate(zip(gs, wavs)):
            d = dur(wav)
            start = LEAD if gi == 0 else 0.0
            span = fit(ad, idx, max(END_MIN, d + 2 * GAP) if kind == "close" else start + d + GAP)
            if kind == "hook":
                ad["hook_dur"] = round(span, 2)
            parts.append((wav, t + start))
            print(f"  {t:5.2f}s +{d:4.2f}s  {spoken(text)}", flush=True)
            t += span
        total = t
        inputs, fc = [], ""
        for j, (wav, at) in enumerate(parts):
            inputs += ["-i", wav]
            fc += f"[{j}:a]adelay={int(at * 1000)}:all=1[a{j}];"
        fc += "".join(f"[a{j}]" for j in range(len(parts))) + \
            f"amix=inputs={len(parts)}:normalize=0,apad,atrim=0:{total:.3f},loudnorm=I=-14:TP=-1.5:LRA=11[out]"
        out = os.path.join(VOZ, ad["name"] + ".wav")
        subprocess.run(["ffmpeg", "-v", "error", "-y"] + inputs +
                       ["-filter_complex", fc, "-map", "[out]", "-ar", "48000", "-ac", "1", out], check=True)
        ad["audio"] = os.path.relpath(out, S)
        print(f"  total {total:.2f}s")
    json.dump(ads, open(path, "w"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
