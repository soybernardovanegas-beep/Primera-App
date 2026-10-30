"""Locución con Gemini TTS: una frase por gancho y por subtítulo, tramos ajustados a la voz.

python3 -I voz.py            # genera/usa caché en voz/cache, reescribe ads.json y voz/<name>.wav
Luego: python3 -I build.py
"""
import base64, hashlib, json, os, re, subprocess, sys, time, urllib.request, urllib.error

S = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(S, "raw")
VOZ = os.path.join(S, "voz")
CACHE = os.path.join(VOZ, "cache")
os.makedirs(CACHE, exist_ok=True)

MODEL = "gemini-2.5-flash-preview-tts"
VOICE = "Puck"
STYLE = ("Lee esto en español de Colombia, con acento colombiano natural, como un vendedor "
         "entusiasta y cercano en un anuncio de redes sociales, ritmo ágil y claro: ")
RATE = 24000
GAP = 0.3       # silencio después de cada frase
LEAD = 0.15     # silencio antes de la primera frase
MIN_SEG = 0.8   # duración mínima de un tramo de video

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


def tts(text):
    key = hashlib.sha1(f"{MODEL}|{VOICE}|{STYLE}|{text}".encode()).hexdigest()[:16]
    wav = os.path.join(CACHE, key + ".wav")
    if os.path.exists(wav):
        return wav
    body = json.dumps({
        "contents": [{"parts": [{"text": STYLE + text}]}],
        "generationConfig": {"responseModalities": ["AUDIO"],
                             "speechConfig": {"voiceConfig": {"prebuiltVoiceConfig": {"voiceName": VOICE}}}},
    }).encode()
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"
    for attempt in range(6):
        req = urllib.request.Request(url, body, {"Content-Type": "application/json",
                                                 "x-goog-api-key": os.environ.get("GEMINI_API_KEY", "x")})
        try:
            d = json.load(urllib.request.urlopen(req, timeout=120))
            pcm = base64.b64decode(d["candidates"][0]["content"]["parts"][0]["inlineData"]["data"])
            break
        except (urllib.error.HTTPError, urllib.error.URLError, KeyError, TimeoutError) as e:
            print("  reintento", attempt + 1, e)
            time.sleep(5 * 2 ** attempt)
    else:
        sys.exit(f"TTS falló: {text}")
    tmp = wav + ".pcm"
    open(tmp, "wb").write(pcm)
    # quita silencios al inicio y al final
    trim = ("silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.03,"
            "areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05,areverse")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(RATE), "-ac", "1", "-i", tmp,
                    "-af", trim, wav], check=True)
    os.remove(tmp)
    return wav


def groups(ad):
    """Agrupa tramos: gancho (tramos iniciales sin subtítulo), cada subtítulo, y cierre (último tramo)."""
    segs = ad["segments"]
    out, k = [], 0
    hook = []
    while k < len(segs) - 1 and not segs[k].get("cap"):
        hook.append(k)
        k += 1
    out.append((" ".join(spoken(t) for t, *_ in ad["hook"]), hook, True))
    while k < len(segs) - 1:
        cap, idx = segs[k]["cap"], []
        while k < len(segs) - 1 and segs[k].get("cap") == cap:
            idx.append(k)
            k += 1
        out.append((cap, idx, False))
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
        for gi, (text, idx, is_hook) in enumerate(groups(ad)):
            wav = tts(spoken(text))
            d = dur(wav)
            start = LEAD if gi == 0 else 0.0
            span = fit(ad, idx, start + d + GAP)
            if is_hook:
                ad["hook_dur"] = round(span, 2)
            parts.append((wav, t + start))
            print(f"  {t:5.2f}s +{d:4.2f}s  {spoken(text)}")
            t += span
        total = t + ad["segments"][-1]["dur"]
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
