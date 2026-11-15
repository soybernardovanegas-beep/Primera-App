"""Cierres con precio nuevo (XOLVETA). Mismo motor/voz/estilo que creativos/cabezal-cortador/voz.py
(rama claude/jolly-ride-q2f97s): Gemini TTS gemini-3.1-flash-tts-preview, voz Puck, mismo STYLE,
y el cierre acelerado x1.12 como entonces (CLOSE_TEMPO).
Salida: MP3 44.1 kHz mono, sin silencio en bordes (~0.05 s), -16 LUFS.
Uso: python3 -I generar.py [AD12 AD13 ...]
"""
import base64, json, os, re, subprocess, sys, time, urllib.request, urllib.error

S = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(S, "cache"); os.makedirs(CACHE, exist_ok=True)
MODEL = "gemini-3.1-flash-tts-preview"
VOICE = "Puck"
STYLE = ("Lee esto en español de Colombia, con acento colombiano natural, como un vendedor "
         "entusiasta y cercano en un anuncio de redes sociales, ritmo ágil y claro. "
         "Haz una pausa corta entre cada línea:\n\n")
RATE = 24000
CLOSE_TEMPO = 1.12

USTED = ("Llévelo por noventa y cuatro mil novecientos, o dos por ciento cuarenta y nueve mil novecientos. "
         "Envío gratis y paga al recibir. Toque el botón y pídalo hoy.")
TU = ("Llévalo por noventa y cuatro mil novecientos, o dos por ciento cuarenta y nueve mil novecientos. "
      "Envío gratis y pagas al recibir. Toca el botón y pídelo hoy.")
REGALO = ("Lleve dos por ciento cuarenta y nueve mil novecientos: uno para papá y otro para el suegro. "
          "O uno solo por noventa y cuatro mil novecientos. Envío gratis y paga al recibir. "
          "Toque el botón y pídalo hoy.")
ADS = {"AD12": USTED, "AD13": TU, "AD14": TU, "AD16": TU, "AD15": REGALO}


def request(text):
    body = json.dumps({
        "contents": [{"parts": [{"text": STYLE + text}]}],
        "generationConfig": {"responseModalities": ["AUDIO"],
                             "speechConfig": {"voiceConfig": {"prebuiltVoiceConfig": {"voiceName": VOICE}}}},
    }).encode()
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"
    for attempt in range(10):
        req = urllib.request.Request(url, body, {"Content-Type": "application/json",
                                                 "x-goog-api-key": os.environ.get("GEMINI_API_KEY", "x")})
        wait = min(5 * 2 ** attempt, 120)
        try:
            d = json.load(urllib.request.urlopen(req, timeout=180))
            return base64.b64decode(d["candidates"][0]["content"]["parts"][0]["inlineData"]["data"])
        except urllib.error.HTTPError as e:
            msg = e.read().decode(errors="replace")
            if e.code in (400, 401, 403):
                sys.exit(f"Error {e.code}: {msg[:300]}")
            m = re.search(r'"retryDelay":\s*"(\d+)', msg)
            if m:
                wait = min(int(m.group(1)) + 2, 900)
            print("  reintento", attempt + 1, e.code, f"espera {wait}s", flush=True)
        except (urllib.error.URLError, KeyError, TimeoutError) as e:
            print("  reintento", attempt + 1, e, flush=True)
        time.sleep(wait)
    sys.exit("TTS falló")


def dur(p):
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", p],
                       capture_output=True, text=True)
    return float(r.stdout.strip())


def main():
    only = sys.argv[1:] or list(ADS)
    raw_by_text = {}
    for name in only:
        text = ADS[name]
        raw = os.path.join(CACHE, f"{name}_raw.wav")
        if text in raw_by_text:          # AD13/14/16: mismo texto -> mismo audio
            raw = raw_by_text[text]
        elif not os.path.exists(raw):
            pcm = raw + ".pcm"
            open(pcm, "wb").write(request(text))
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(RATE), "-ac", "1",
                            "-i", pcm, raw], check=True)
            os.remove(pcm)
        raw_by_text[text] = raw
        out = os.path.join(S, f"cierre-{name}.mp3")
        trim = ("silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05,"
                "areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05,areverse")
        af = f"atempo={CLOSE_TEMPO},{trim},aresample=44100,loudnorm=I=-16:TP=-1.5:LRA=11"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", raw, "-af", af, "-ar", "44100", "-ac", "1",
                        "-c:a", "libmp3lame", "-b:a", "192k", out], check=True)
        print(f"{os.path.basename(out)}  {dur(out):.2f}s", flush=True)


if __name__ == "__main__":
    main()
