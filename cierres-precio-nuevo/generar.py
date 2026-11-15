import base64, json, os, subprocess, sys, time, urllib.request, urllib.error, re
OUT = sys.argv[1]; TMP = sys.argv[2]
MODEL = "gemini-3.1-flash-tts-preview"; VOICE = "Puck"; RATE = 24000; TEMPO = 1.12
STYLE = ("Lee esto en español de Colombia, con acento colombiano natural, como un vendedor "
         "entusiasta y cercano en un anuncio de redes sociales, ritmo ágil y claro. "
         "Haz una pausa corta entre cada línea:\n\n")
TU = "Llévalo por noventa y cuatro mil novecientos, o dos por ciento cuarenta y nueve mil novecientos. Envío gratis y pagas al recibir. Toca el botón y pídelo hoy."
T = {"AD12": "Llévelo por noventa y cuatro mil novecientos, o dos por ciento cuarenta y nueve mil novecientos. Envío gratis y paga al recibir. Toque el botón y pídalo hoy.",
     "AD13": TU,
     "AD15": "Lleve dos por ciento cuarenta y nueve mil novecientos: uno para papá y otro para el suegro. O uno solo por noventa y cuatro mil novecientos. Envío gratis y paga al recibir. Toque el botón y pídalo hoy."}
def req(text):
    body = json.dumps({"contents": [{"parts": [{"text": STYLE + text}]}],
        "generationConfig": {"responseModalities": ["AUDIO"],
        "speechConfig": {"voiceConfig": {"prebuiltVoiceConfig": {"voiceName": VOICE}}}}}).encode()
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"
    for a in range(8):
        try:
            r = urllib.request.Request(url, body, {"Content-Type": "application/json", "x-goog-api-key": "x"})
            d = json.load(urllib.request.urlopen(r, timeout=180))
            return base64.b64decode(d["candidates"][0]["content"]["parts"][0]["inlineData"]["data"])
        except urllib.error.HTTPError as e:
            msg = e.read().decode(errors="replace"); print("retry", e.code, msg[:200], flush=True)
            m = re.search(r'"retryDelay":\s*"(\d+)', msg); time.sleep(int(m.group(1)) + 2 if m else 5 * 2 ** a)
        except Exception as e:
            print("retry", e, flush=True); time.sleep(5 * 2 ** a)
    sys.exit("fail")
for name, text in T.items():
    for take in sys.argv[3:] or ["1"]:
        pcm = f"{TMP}/{name}_{take}.pcm"
        if not os.path.exists(pcm): open(pcm, "wb").write(req(text))
        print("ok", name, take, flush=True)
