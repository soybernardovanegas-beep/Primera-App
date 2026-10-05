#!/usr/bin/env python3
"""Edición de video con el estilo de Network Marketing Real.

Todo se hace con ffmpeg + libass, en una sola pasada de render:

    python3 nmr.py analizar    --entrada video.mp4 --json trabajo/cortes.json
    python3 nmr.py transcribir --entrada video.mp4 --json trabajo/transcripcion.json
    python3 nmr.py render      --plan trabajo/episodio.json [--prueba 0-90]
    python3 nmr.py partir      --entrada salidas/episodio.mp4 --max-mb 95
    python3 nmr.py fotogramas  --entrada video.mp4 --salida miniatura/ --cada 20

Los tiempos del plan (`t` de cada gráfico, `quitar`, `rango`) van SIEMPRE en
segundos del video ORIGINAL: el script los traslada a la línea de tiempo ya
cortada. Así el plan se escribe leyendo la transcripción, sin calcular nada.
"""
from __future__ import annotations

import argparse
import json
import math
import re
import shutil
import subprocess
import sys
import tempfile
from fractions import Fraction
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
FUENTES = RAIZ / "fuentes"

# Paleta medida sobre el episodio publicado.
VERDE = "3BDC84"         # acento: "REAL", barras, cifras, palabra activa
VERDE_OSCURO = "0B2A1C"  # caja de "Suscríbete" y paneles
FONDO = "03140F"         # fondo de portada/cierre y borde del panel lateral
BLANCO = "FFFFFF"
NEGRO = "000000"


# ---------------------------------------------------------------- utilidades

def ejecutar(cmd: list[str], capturar: bool = False) -> str:
    r = subprocess.run(cmd, capture_output=capturar, text=True)
    if r.returncode != 0:
        if capturar:
            sys.stderr.write(r.stderr[-4000:])
        raise SystemExit(f"Falló: {' '.join(cmd[:6])} …")
    return r.stdout if capturar else ""


def sondear(ruta: str) -> dict:
    datos = json.loads(ejecutar([
        "ffprobe", "-v", "error", "-print_format", "json",
        "-show_format", "-show_streams", ruta], capturar=True))
    v = next((s for s in datos["streams"] if s["codec_type"] == "video"), None)
    a = next((s for s in datos["streams"] if s["codec_type"] == "audio"), None)
    if v is None:
        raise SystemExit(f"{ruta} no tiene pista de video.")
    # r_frame_rate es una fracción exacta ("30000/1001"): redondear 29.97 a 30
    # desplaza 1,6 s el final de un video de 27 min y desincroniza todo.
    fps = Fraction(v.get("r_frame_rate", "30/1"))
    return {
        "ancho": int(v["width"]), "alto": int(v["height"]), "fps": fps,
        "duracion": float(datos["format"]["duration"]),
        "audio": a is not None,
        "tasa": int(a["sample_rate"]) if a else 48000,
        "rotacion": int(v.get("tags", {}).get("rotate", 0) or 0),
    }


def aviso_faststart(ruta: str) -> str | None:
    """Avisa si el índice (`moov`) está al final del MP4.

    Es la causa real de renders que se cuelgan antes del primer fotograma con
    material de cámara: hay que leer el archivo entero para encontrarlo."""
    try:
        with open(ruta, "rb") as f:
            pos, orden = 0, []
            tam_total = Path(ruta).stat().st_size
            while pos < tam_total and len(orden) < 20:
                f.seek(pos)
                cab = f.read(16)
                if len(cab) < 8:
                    break
                tam = int.from_bytes(cab[:4], "big")
                tipo = cab[4:8].decode("latin1")
                if tam == 1:  # tamaño de 64 bits: todo archivo > 4 GB
                    tam = int.from_bytes(cab[8:16], "big")
                elif tam == 0:
                    tam = tam_total - pos
                orden.append(tipo)
                pos += tam
    except OSError:
        return None
    if "moov" in orden and "mdat" in orden and orden.index("moov") > orden.index("mdat"):
        return (f"AVISO: el índice 'moov' de {ruta} está al final del archivo. "
                "Arréglalo sin recodificar antes de seguir:\n"
                f'  ffmpeg -i "{ruta}" -c copy -movflags +faststart rapido.mp4')
    return None


def hms(s: float) -> str:
    s = max(0.0, s)
    return f"{int(s // 60)}:{s % 60:05.2f}"


# ------------------------------------------------------------------ analizar

OPC_SILENCIO = {
    "umbral": -35.0,        # dBFS absoluto
    "margen_ruido": 8.0,    # dB sobre el ruido de fondo medido
    "pausa_maxima": 0.6,    # solo se cortan huecos más largos que esto
    "margen_antes": 0.15,   # aire antes de cada tramo (no comerse el ataque)
    "margen_despues": 0.25,
    "minimo_segmento": 0.35,
}


def energia(ruta: str) -> list[float]:
    """RMS en dBFS por ventanas de 20 ms, calculado por ffmpeg (rápido)."""
    salida = ejecutar([
        "ffmpeg", "-v", "error", "-i", ruta, "-map", "0:a:0", "-ac", "1", "-af",
        "aresample=16000,asetnsamples=n=320:p=0,"
        "astats=metadata=1:reset=1:measure_overall=RMS_level:measure_perchannel=none,"
        "ametadata=print:key=lavfi.astats.Overall.RMS_level:file=-",
        "-f", "null", "-"], capturar=True)
    db = []
    for linea in salida.splitlines():
        if linea.startswith("lavfi.astats"):
            v = linea.split("=", 1)[1]
            db.append(-100.0 if "inf" in v else max(-100.0, float(v)))
    return db


def detectar_tramos(db: list[float], op: dict) -> tuple[list[list[float]], float, float]:
    paso = 0.02
    ordenado = sorted(db)
    ruido = ordenado[int(len(ordenado) * 0.1)] if ordenado else -100
    # Umbral adaptativo: el más exigente entre el absoluto y ruido + margen.
    umbral = max(op["umbral"], ruido + op["margen_ruido"])
    bruto, ini = [], None
    for i, v in enumerate(db):
        if v > umbral and ini is None:
            ini = i
        elif v <= umbral and ini is not None:
            bruto.append([ini * paso, i * paso]); ini = None
    if ini is not None:
        bruto.append([ini * paso, len(db) * paso])
    unidos: list[list[float]] = []
    for t in bruto:
        if unidos and t[0] - unidos[-1][1] < op["pausa_maxima"]:
            unidos[-1][1] = t[1]
        else:
            unidos.append(list(t))
    total = len(db) * paso
    finales: list[list[float]] = []
    for a, b in unidos:
        a, b = max(0, a - op["margen_antes"]), min(total, b + op["margen_despues"])
        if finales and a <= finales[-1][1]:
            finales[-1][1] = max(finales[-1][1], b)
        else:
            finales.append([a, b])
    return [t for t in finales if t[1] - t[0] >= op["minimo_segmento"]], ruido, umbral


def cmd_analizar(a):
    if (aviso := aviso_faststart(a.entrada)):
        print(aviso)
    info = sondear(a.entrada)
    if not info["audio"]:
        raise SystemExit("El video no tiene audio: no hay silencios que detectar.")
    op = dict(OPC_SILENCIO)
    for k in op:
        if getattr(a, k, None) is not None:
            op[k] = getattr(a, k)
    db = energia(a.entrada)
    tramos, ruido, umbral = detectar_tramos(db, op)
    final = sum(b - x for x, b in tramos)
    huecos = [tramos[i][0] - tramos[i - 1][1] for i in range(1, len(tramos))]
    print(f"Video:   {info['ancho']}x{info['alto']} @ {float(info['fps']):.3f} fps")
    print(f"Ruido de fondo {ruido:.1f} dBFS · umbral efectivo {umbral:.1f} dBFS")
    print(f"Duración {hms(info['duracion'])} -> {hms(final)}  "
          f"(se quitan {hms(info['duracion'] - final)}, "
          f"{100 * (1 - final / info['duracion']):.1f} %)")
    print(f"{len(tramos)} tramos, {len(huecos)} empalmes "
          f"(uno cada {final / max(1, len(huecos)):.1f} s)")
    if huecos:
        print("Cambios de encuadre según el umbral de --cambio-encuadre:")
        for u in (0.5, 0.8, 1.0, 1.5, 2.0):
            n = sum(1 for h in huecos if h >= u)
            print(f"  >= {u:.1f} s: {n:4d} cambios (uno cada {final / max(1, n):.0f} s)")
    Path(a.json).parent.mkdir(parents=True, exist_ok=True)
    Path(a.json).write_text(json.dumps({
        "fuente": a.entrada, "duracion": info["duracion"],
        "fps": str(info["fps"]), "ruido": round(ruido, 1), "umbral": round(umbral, 1),
        "opciones": op, "segmentos": [[round(x, 3), round(b, 3)] for x, b in tramos],
    }, indent=1, ensure_ascii=False))
    print(f"Escrito {a.json}")


# --------------------------------------------------------------- transcribir

def cmd_transcribir(a):
    if a.srt:
        palabras = palabras_desde_srt(Path(a.srt).read_text(encoding="utf-8-sig"))
    else:
        try:
            from faster_whisper import WhisperModel  # type: ignore
        except ImportError:
            raise SystemExit("Instala faster-whisper:  pip install faster-whisper\n"
                             "o pasa una transcripción existente con --srt archivo.srt")
        print(f"Cargando modelo {a.modelo} (la primera vez se descarga)…")
        try:
            modelo = WhisperModel(a.modelo, device="cpu", compute_type="int8")
        except Exception as e:  # red bloqueada a huggingface.co, sin espacio…
            raise SystemExit(f"No se pudo cargar el modelo de Whisper: {e}\n"
                             "Si la red bloquea huggingface.co, usa --srt con los "
                             "subtítulos de YouTube/CapCut o permite ese dominio.")
        segs, _ = modelo.transcribe(a.entrada, language="es", word_timestamps=True,
                                    vad_filter=True, beam_size=5)
        palabras = []
        for s in segs:
            for w in s.words or []:
                palabras.append({"t0": round(w.start, 2), "t1": round(w.end, 2),
                                 "w": w.word.strip()})
            print(f"  {hms(s.end)}", end="\r")
    Path(a.json).parent.mkdir(parents=True, exist_ok=True)
    Path(a.json).write_text(json.dumps({"palabras": palabras}, ensure_ascii=False))
    # Versión legible para planificar los gráficos: una frase por línea.
    txt = Path(a.json).with_suffix(".txt")
    txt.write_text("\n".join(f"[{f['t0']:7.2f}-{f['t1']:7.2f}] {f['texto']}"
                             for f in frases(palabras, 90)), encoding="utf-8")
    print(f"\n{len(palabras)} palabras -> {a.json} y {txt}")


def palabras_desde_srt(texto: str) -> list[dict]:
    """Convierte un SRT/VTT en palabras con tiempos repartidos por longitud."""
    def seg(m):
        h, mi, s, ms = m
        return int(h) * 3600 + int(mi) * 60 + int(s) + int(ms) / 1000
    palabras = []
    patron = re.compile(r"(\d+):(\d\d):(\d\d)[,.](\d+)\s*-->\s*(\d+):(\d\d):(\d\d)[,.](\d+)")
    bloques = re.split(r"\n\s*\n", texto.replace("\r", ""))
    for b in bloques:
        m = patron.search(b)
        if not m:
            continue
        t0, t1 = seg(m.groups()[:4]), seg(m.groups()[4:])
        linea = " ".join(l for l in b[m.end():].strip().splitlines())
        linea = re.sub(r"<[^>]+>", "", linea)
        ws = linea.split()
        if not ws:
            continue
        total = sum(len(w) + 1 for w in ws)
        t = t0
        for w in ws:
            d = (t1 - t0) * (len(w) + 1) / total
            palabras.append({"t0": round(t, 2), "t1": round(t + d, 2), "w": w})
            t += d
    return palabras


def frases(palabras: list[dict], max_car: int, pausa: float = 0.5) -> list[dict]:
    """Agrupa palabras en frases cortas (corte por longitud, pausa o puntuación)."""
    out, actual = [], []
    for i, p in enumerate(palabras):
        if actual:
            texto = " ".join(x["w"] for x in actual)
            hueco = p["t0"] - actual[-1]["t1"]
            if (len(texto) + 1 + len(p["w"]) > max_car or hueco > pausa
                    or texto[-1:] in ".?!"):
                out.append(actual); actual = []
        actual.append(p)
    if actual:
        out.append(actual)
    return [{"t0": g[0]["t0"], "t1": g[-1]["t1"],
             "texto": " ".join(x["w"] for x in g), "palabras": g} for g in out]


# ---------------------------------------------------------- línea de tiempo

class Linea:
    """Tramos conservados (en fotogramas del original) y su traslado a la salida."""

    def __init__(self, tramos_s: list[list[float]], fps: Fraction, duracion: float):
        self.fps = fps
        self.tramos: list[tuple[int, int]] = []
        fin = int(duracion * fps)
        for a, b in tramos_s:
            # Los límites se ajustan a fotogramas exactos y video y audio se
            # cortan con esos mismos límites: si no, cada tramo derivaría
            # hasta un fotograma y en 300 empalmes se notaría el desfase.
            fa, fb = max(0, round(a * fps)), min(fin, round(b * fps))
            if fb - fa >= 3:
                self.tramos.append((fa, fb))
        if not self.tramos:
            raise SystemExit("No queda ningún tramo que montar.")
        self.inicio_salida = []
        acum = 0
        for fa, fb in self.tramos:
            self.inicio_salida.append(acum)
            acum += fb - fa
        self.total = acum

    def segundos(self, fotogramas: int) -> float:
        return float(Fraction(fotogramas) / self.fps)

    @property
    def duracion(self) -> float:
        return self.segundos(self.total)

    def a_salida(self, t: float) -> float:
        """Segundo del original -> segundo de la salida (si cae en un hueco
        eliminado, se lleva al inicio del siguiente tramo)."""
        f = t * float(self.fps)
        for (fa, fb), ini in zip(self.tramos, self.inicio_salida):
            if f < fb:
                return self.segundos(ini + max(0, f - fa))
        return self.duracion


def restar(tramos: list[list[float]], quitar: list[list[float]]) -> list[list[float]]:
    for qa, qb in quitar:
        nuevo = []
        for a, b in tramos:
            if qb <= a or qa >= b:
                nuevo.append([a, b]); continue
            if qa > a:
                nuevo.append([a, qa])
            if qb < b:
                nuevo.append([qb, b])
        tramos = nuevo
    return tramos


def recortar_a(tramos: list[list[float]], rangos: list[list[float]]) -> list[list[float]]:
    out = []
    for ra, rb in rangos:
        for a, b in tramos:
            x, y = max(a, ra), min(b, rb)
            if y - x > 0.05:
                out.append([x, y])
    return out


# ---------------------------------------------------------------------- ASS

def c(hexrgb: str, alfa: int = 0) -> str:
    """Color ASS: &HBBGGRR& — `alfa` 0 opaco … 255 transparente."""
    return f"&H{hexrgb[4:6]}{hexrgb[2:4]}{hexrgb[0:2]}&"


def a(alfa: int) -> str:
    return f"&H{alfa:02X}&"


def t_ass(s: float) -> str:
    s = max(0.0, s)
    cs = int(round(s * 100))
    return f"{cs // 360000}:{cs // 6000 % 60:02d}:{cs // 100 % 60:02d}.{cs % 100:02d}"


def esc(texto: str) -> str:
    return texto.replace("{", "(").replace("}", ")").replace("\n", "\\N")


def rect(x0, y0, x1, y1) -> str:
    return f"m {x0:.0f} {y0:.0f} l {x1:.0f} {y0:.0f} {x1:.0f} {y1:.0f} {x0:.0f} {y1:.0f}"


def elipse(cx, cy, rx, ry) -> str:
    k = 0.5523
    return (f"m {cx - rx:.0f} {cy:.0f} "
            f"b {cx - rx:.0f} {cy - ry * k:.0f} {cx - rx * k:.0f} {cy - ry:.0f} {cx:.0f} {cy - ry:.0f} "
            f"b {cx + rx * k:.0f} {cy - ry:.0f} {cx + rx:.0f} {cy - ry * k:.0f} {cx + rx:.0f} {cy:.0f} "
            f"b {cx + rx:.0f} {cy + ry * k:.0f} {cx + rx * k:.0f} {cy + ry:.0f} {cx:.0f} {cy + ry:.0f} "
            f"b {cx - rx * k:.0f} {cy + ry:.0f} {cx - rx:.0f} {cy + ry * k:.0f} {cx - rx:.0f} {cy:.0f}")


class Ass:
    def __init__(self, ancho: int, alto: int):
        self.w, self.h = ancho, alto
        self.eventos: list[tuple[float, str]] = []

    def ev(self, t0: float, t1: float, texto: str, capa: int = 1):
        if t1 - t0 > 0.01:
            self.eventos.append((t0, f"Dialogue: {capa},{t_ass(t0)},{t_ass(t1)},Base,,0,0,0,,{texto}"))

    def forma(self, t0, t1, dibujo, color, alfa=0, blur=0, capa=0, extra=""):
        self.ev(t0, t1, f"{{\\an7\\pos(0,0)\\bord0\\shad0\\1c{c(color)}\\1a{a(alfa)}"
                        f"\\blur{blur}{extra}\\p1}}{dibujo}{{\\p0}}", capa)

    def texto(self, t0, t1, x, y, txt, fuente, tam, color=BLANCO, alfa=0,
              esp=0, an=5, halo=False, borde=0, capa=2, entrada=0.0, extra=""):
        """Texto con fundido y una pequeña subida al entrar (`entrada` = retardo)."""
        ini, fin = t0 + entrada, t1
        estilo = (f"\\an{an}\\fn{fuente}\\fs{tam}\\fsp{esp}\\1c{c(color)}\\1a{a(alfa)}"
                  f"\\shad0")
        if "\\bord" in extra:
            pass      # el llamador define su propio contorno (CONTORNO)
        elif halo:    # halo oscuro difuso, como en los títulos del episodio
            estilo += f"\\bord5\\3c{c(NEGRO)}\\3a{a(0x90)}\\blur8"
        elif borde:   # contorno duro, para los subtítulos de los shorts
            estilo += f"\\bord{borde}\\3c{c(NEGRO)}\\blur1"
        else:
            estilo += "\\bord0"
        self.ev(ini, fin, f"{{{estilo}\\move({x},{y + 18},{x},{y},0,260)\\fad(180,200){extra}}}"
                          f"{esc(txt)}", capa)

    def barra(self, t0, t1, cx, y, ancho, alto, color=VERDE, retardo=0.15, capa=2,
              desde_izq=False):
        """Barra verde que crece desde el centro (o desde la izquierda)."""
        x0, x1 = cx - ancho / 2, cx + ancho / 2
        if desde_izq:
            x0, x1 = cx, cx + ancho
        y0, y1 = y - alto / 2, y + alto / 2
        r0, r1 = int(retardo * 1000), int(retardo * 1000) + 380
        ini = f"\\clip({x0:.0f},{y0 - 2:.0f},{x0 + 1:.0f},{y1 + 2:.0f})" if desde_izq else \
              f"\\clip({cx - 1:.0f},{y0 - 2:.0f},{cx + 1:.0f},{y1 + 2:.0f})"
        self.forma(t0, t1, rect(x0, y0, x1, y1), color, capa=capa,
                   extra=f"{ini}\\t({r0},{r1},\\clip({x0:.0f},{y0 - 2:.0f},{x1:.0f},{y1 + 2:.0f}))"
                         f"\\fad(0,200)")

    def velo(self, t0, t1, alfa=0x70, capa=0):
        self.forma(t0, t1, rect(-10, -10, self.w + 10, self.h + 10), NEGRO, alfa, capa=capa,
                   extra="\\fad(220,260)")

    def escribir(self, ruta: Path):
        cab = (
            "[Script Info]\nScriptType: v4.00+\nWrapStyle: 2\nScaledBorderAndShadow: yes\n"
            f"PlayResX: {self.w}\nPlayResY: {self.h}\nYCbCr Matrix: TV.709\n\n"
            "[V4+ Styles]\nFormat: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, "
            "OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, "
            "Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, "
            "MarginV, Encoding\n"
            "Style: Base,Montserrat SemiBold,40,&H00FFFFFF,&H00FFFFFF,&H00000000,&H00000000,"
            "0,0,0,0,100,100,0,0,1,0,0,5,0,0,0,1\n\n"
            "[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, "
            "Effect, Text\n")
        lineas = [e for _, e in sorted(self.eventos, key=lambda x: x[0])]
        ruta.write_text(cab + "\n".join(lineas) + "\n", encoding="utf-8")


# ------------------------------------------------------- gráficos: episodio
# Tamaños calibrados midiendo el ancho de cada texto en el episodio publicado
# (libass y CSS no miden igual: no copies tamaños de un diseño web sin medir).

FN_BLACK, FN_XB, FN_BOLD = "Montserrat Black", "Montserrat ExtraBold", "Montserrat\\b1"
FN_SEMI, FN_MED = "Montserrat SemiBold", "Montserrat Medium"
CONTORNO = f"\\bord6\\3c&H141414&\\3a&H30&\\blur2"   # cifras y preguntas grandes


def g_marca_h(s: Ass, t0, t1):
    s.forma(t0, t1, rect(64, 50, 70, 80), VERDE, extra="\\fad(400,300)", capa=3)
    s.ev(t0, t1, f"{{\\an4\\pos(82,65)\\fn{FN_BOLD}\\fs20\\fsp7.5\\bord0\\shad0"
                 f"\\1c{c(BLANCO)}\\1a{a(0x20)}\\fad(400,300)}}NETWORK MARKETING "
                 f"{{\\1c{c(VERDE)}}}REAL", 3)


def g_titulo_h(s: Ass, t0, t1, g):
    s.texto(t0, t1, 960, 858, g["texto"].upper(), FN_BLACK, 112, esp=1.5, halo=True)
    s.barra(t0, t1, 960, 917, 180, 6)
    if g.get("sub"):
        s.texto(t0, t1, 960, 953, g["sub"].upper(), FN_MED, 37, alfa=0x18, esp=7,
                halo=True, entrada=0.2)


def g_dato_h(s: Ass, t0, t1, g):
    abajo = g.get("posicion", "centro") == "abajo"
    if not abajo:   # cifra protagonista: se oscurece el plano
        s.velo(t0, t1, 0x58)
        y_arr, y, y_bar, y_ab, fs, ancho = 467, 605, 708, 770, 200, 220
    else:           # cifra sobre el pecho, sin oscurecer
        y_arr, y, y_bar, y_ab, fs, ancho = 727, 845, 917, 952, 160, 105
    if g.get("arriba"):
        s.texto(t0, t1, 960, y_arr, g["arriba"].upper(), FN_BOLD, 38, VERDE, esp=12.5,
                halo=abajo)
    s.texto(t0, t1, 960, y, g["valor"].upper(), FN_BLACK, fs, entrada=0.1, extra=CONTORNO)
    s.barra(t0, t1, 960, y_bar, ancho, 8)
    if g.get("abajo"):
        s.texto(t0, t1, 960, y_ab, g["abajo"].upper(), FN_MED, 33, alfa=0x60, esp=12,
                entrada=0.3)


def g_pregunta_h(s: Ass, t0, t1, g):
    s.velo(t0, t1, 0x50)
    fs = 146 if len(g["texto"]) <= 18 else max(90, int(146 * 18 / len(g["texto"])))
    s.texto(t0, t1, 960, 605, g["texto"].upper(), FN_BLACK, fs, esp=1, extra=CONTORNO)
    s.barra(t0, t1, 960, 688, 220, 8)


def panel_izq(s: Ass, t0, t1):
    # Degradado verde oscuro desde la izquierda: dos capas difuminadas.
    s.forma(t0, t1, rect(-200, -60, 700, 1140), FONDO, 0x18, blur=90,
            extra="\\fad(300,300)")
    s.forma(t0, t1, rect(-200, -60, 980, 1140), "0D3A26", 0x70, blur=160,
            extra="\\fad(300,300)")


def g_panel_h(s: Ass, t0, t1, g):
    panel_izq(s, t0, t1)
    if g.get("arriba"):
        s.texto(t0, t1, 150, 348, g["arriba"].upper(), FN_BOLD, 36, VERDE, esp=11,
                an=4, entrada=0.15)
    texto = g["texto"].upper()
    if "\n" not in texto and len(texto) > 12:   # dos líneas, como en el original
        texto = texto.replace(" ", "\n", 1)
    s.texto(t0, t1, 150, 390, texto, FN_BLACK, 108, an=7, entrada=0.25, extra="\\q2")
    if g.get("grafica"):
        # Línea ascendente que se dibuja de izquierda a derecha.
        pts = [(150, 790), (240, 745), (300, 772), (390, 700), (450, 722), (560, 620)]
        arriba_ = " ".join(f"{x} {y}" for x, y in pts[1:])
        abajo_ = " ".join(f"{x} {y + 7}" for x, y in reversed(pts))
        s.forma(t0, t1, f"m {pts[0][0]} {pts[0][1]} l {arriba_} {abajo_}", VERDE, capa=2,
                extra="\\clip(140,580,141,820)\\t(400,1400,\\clip(140,580,600,820))\\fad(0,200)")
        s.forma(t0, t1, "m 556 604 l 588 612 566 636", VERDE, capa=2,
                extra="\\alpha&HFF&\\t(1350,1450,\\alpha&H00&)\\fad(0,200)")


def g_lista_h(s: Ass, t0, t1, g):
    panel_izq(s, t0, t1)
    items = g["items"]
    activo = int(g.get("activo", len(items)))
    alto_barra = max(790, 435 + 70 * activo + 80)
    s.forma(t0, t1, rect(108, 220, 113, alto_barra), VERDE, capa=2,
            extra=f"\\clip(100,218,120,222)\\t(0,500,\\clip(100,218,120,{alto_barra}))"
                  "\\fad(0,250)")
    s.texto(t0, t1, 150, 229, g.get("arriba", f"{len(items)} ideas").upper(),
            FN_BOLD, 30, VERDE, esp=9.3, an=4, entrada=0.1)
    s.texto(t0, t1, 150, 262, g["titulo"].upper(), FN_XB, 59, an=7, entrada=0.2,
            extra="\\q2")
    for i in range(activo):
        y = 435 + 70 * i
        es_activo = i == activo - 1
        retardo = 0.45 if es_activo else 0.3
        s.texto(t0, t1, 150, y, f"{i + 1:02d}", FN_XB, 40, VERDE,
                alfa=0 if es_activo else 0x30, an=4, entrada=retardo)
        s.texto(t0, t1, 226, y, items[i], FN_MED, 42,
                alfa=0 if es_activo else 0x68, an=4, entrada=retardo)


def tarjeta(s: Ass, t0, t1, sub: str, fundido_salida=True):
    fo = 450 if fundido_salida else 0
    s.forma(t0 - 0.35, t1, rect(-10, -10, s.w + 10, s.h + 10), NEGRO, capa=5,
            extra=f"\\fad(300,{fo})")
    s.forma(t0, t1, elipse(960, 540, 1000, 560), "0B3A1F", 0x70, blur=260, capa=6,
            extra=f"\\fad(500,{fo})")
    for x, y, txt, fn, tam, col, esp, alfa, ent in (
            (960, 331, "PODCAST", FN_BOLD, 36, VERDE, 18, 0, 0.15),
            (960, 455, "NETWORK MARKETING", FN_BLACK, 137, BLANCO, 5.5, 0, 0.3),
            (960, 575, "REAL", FN_BLACK, 137, VERDE, 5.5, 0, 0.45),
            (960, 772, sub.upper(), FN_MED, 29, BLANCO, 10.4, 0x40, 0.8)):
        if txt:
            s.ev(t0 + ent, t1, f"{{\\an5\\pos({x},{y})\\fn{fn}\\fs{tam}\\fsp{esp}"
                               f"\\1c{c(col)}\\1a{a(alfa)}\\bord0\\shad0\\fad(300,{fo})}}{esc(txt)}", 7)
    s.forma(t0, t1, rect(830, 682, 1090, 690), VERDE, capa=7,
            extra=f"\\clip(959,670,961,700)\\t(600,1000,\\clip(830,670,1090,700))\\fad(0,{fo})")


def g_portada_h(s: Ass, t0, t1, g):
    tarjeta(s, t0, t1, g.get("subtitulo", ""))


def g_suscribete_h(s: Ass, t0, t1, g):
    s.forma(t0, t1, rect(110, 880, 750, 984), VERDE_OSCURO, 0x14, capa=1,
            extra="\\clip(110,870,111,990)\\t(0,350,\\clip(110,870,760,990))\\fad(0,250)")
    s.forma(t0, t1, rect(110, 880, 120, 984), VERDE, capa=2, extra="\\fad(150,250)")
    s.texto(t0, t1, 150, 916, g.get("texto", "Suscríbete").upper(), FN_BLACK, 45,
            esp=4.3, an=4, entrada=0.25)
    s.texto(t0, t1, 150, 956, g.get("sub", "y activa la campanita").upper(),
            FN_BOLD, 24, VERDE, esp=7, an=4, entrada=0.4)


def g_cierre_h(s: Ass, t0, t1, g):
    tarjeta(s, t0, t1, g.get("subtitulo", "Nos vemos en el próximo episodio"),
            fundido_salida=False)
    # Fundido final a negro.
    s.forma(t1 - 0.7, t1, rect(-10, -10, s.w + 10, s.h + 10), NEGRO, capa=9,
            extra="\\fad(650,0)")


def subtitulos_h(s: Ass, grupos, ocupado):
    for g in grupos:
        if any(g["t0"] < b and g["t1"] > a_ for a_, b in ocupado):
            continue
        txt = g["texto"]
        txt = txt[:1].upper() + txt[1:]
        s.ev(g["t0"], g["t1"],
             f"{{\\an2\\pos(960,1022)\\fn{FN_SEMI}\\fs53\\bord2\\3c{c(NEGRO)}\\3a{a(0xA0)}"
             f"\\blur3\\shad0}}{esc(txt)}", 1)


# --------------------------------------------------------- gráficos: shorts

def g_marca_v(s: Ass, t0, t1):
    s.ev(t0, t1, f"{{\\an5\\pos(540,127)\\fn{FN_BOLD}\\fs28\\fsp8.9\\bord2\\3c{c(NEGRO)}"
                 f"\\3a{a(0xB0)}\\blur4\\shad0\\1c{c(BLANCO)}\\1a{a(0x20)}}}NETWORK MARKETING "
                 f"{{\\1c{c(VERDE)}}}REAL", 3)


def g_gancho_v(s: Ass, t0, t1, lineas: list[str]):
    s.forma(t0, t1, rect(70, 270, 1010, 540), "0B3A22", 0x30, blur=45, capa=1,
            extra="\\fad(150,250)")
    for i, l in enumerate(lineas[:2]):
        # Que quepa en 1040 px: 117 de tamaño llena el ancho con ~19 letras.
        fs = min(118, int(117 * 19 / max(len(l), 1)))
        s.texto(t0, t1, 540, 360 + 102 * i, l.upper(), FN_BLACK, fs,
                VERDE if i == 1 else BLANCO, esp=1.7, halo=True, entrada=0.12 * i)


def g_titulo_v(s: Ass, t0, t1, g):
    fs = min(85, int(85 * 19 / max(len(g["texto"]), 1)))
    s.texto(t0, t1, 540, 474, g["texto"].upper(), FN_BLACK, fs, esp=3.3, halo=True)
    s.barra(t0, t1, 540, 527, 130, 7)


def subtitulos_v(s: Ass, grupos):
    """Subtítulos palabra a palabra: grupo de hasta 3 palabras en mayúsculas,
    contorno negro y la palabra que suena en verde."""
    for g in grupos:
        ps = g["palabras"]
        for i, p in enumerate(ps):
            fin = ps[i + 1]["t0"] if i + 1 < len(ps) else g["t1"]
            partes = []
            for j, q in enumerate(ps):
                w = esc(q["w"].upper())
                partes.append(f"{{\\1c{c(VERDE)}}}{w}{{\\1c{c(BLANCO)}}}" if j == i else w)
            # 84 llena ~965 px con 26 letras; los grupos más largos se reducen.
            tam = min(84, int(84 * 26 / max(len(g["texto"]), 1)))
            s.ev(p["t0"], max(fin, p["t0"] + 0.05),
                 f"{{\\an5\\pos(540,1345)\\fn{FN_BLACK}\\fs{tam}\\fsp1.6\\bord6\\3c{c(NEGRO)}"
                 f"\\shad0\\blur1\\1c{c(BLANCO)}}}" + " ".join(partes), 4)


def g_final_v(s: Ass, t0, t1, texto):
    s.texto(t0, t1, 540, 1640, texto.upper(), FN_BOLD, 34, esp=8.5, halo=True)
    s.barra(t0, t1, 540, 1692, 240, 5, retardo=0.3)


# -------------------------------------------------------------------- render

def cargar_palabras(plan: dict, base: Path) -> list[dict]:
    ruta = plan.get("transcripcion")
    if not ruta:
        return []
    p = (base / ruta) if not Path(ruta).is_absolute() else Path(ruta)
    if not p.exists():
        print(f"AVISO: no existe {p}; se renderiza sin subtítulos.")
        return []
    if p.suffix.lower() in (".srt", ".vtt"):
        return palabras_desde_srt(p.read_text(encoding="utf-8-sig"))
    return json.loads(p.read_text(encoding="utf-8"))["palabras"]


def palabras_a_salida(palabras, linea: Linea) -> list[dict]:
    out = []
    fps = float(linea.fps)
    for p in palabras:
        mitad = (p["t0"] + p["t1"]) / 2 * fps
        # Solo las palabras que caen dentro de un tramo conservado.
        if not any(fa <= mitad < fb for fa, fb in linea.tramos):
            continue
        out.append({**p, "t0": linea.a_salida(p["t0"]), "t1": linea.a_salida(p["t1"])})
    return out


def construir_ass(plan, linea: Linea, palabras, vertical: bool) -> Ass:
    W, H = (1080, 1920) if vertical else (1920, 1080)
    s = Ass(W, H)
    fin = linea.duracion
    ocupado = []
    graficos = plan.get("graficos", [])
    cierre = next((g for g in graficos if g["tipo"] == "cierre"), None)
    fin_contenido = fin - (cierre.get("dur", 4) if cierre else 0)

    for g in graficos:
        tipo = g["tipo"]
        if tipo == "cierre":
            t0, t1 = fin_contenido, fin
        else:
            t0 = linea.a_salida(float(g["t"]))
            t1 = min(fin_contenido, t0 + float(g.get("dur", 2.5)))
        if vertical:
            {"titulo": g_titulo_v}.get(tipo, lambda *x: print(
                f"AVISO: '{tipo}' no existe en vertical"))(s, t0, t1, g)
            continue
        fn = {"titulo": g_titulo_h, "dato": g_dato_h, "pregunta": g_pregunta_h,
              "panel": g_panel_h, "lista": g_lista_h, "portada": g_portada_h,
              "suscribete": g_suscribete_h, "cierre": g_cierre_h}.get(tipo)
        if fn is None:
            raise SystemExit(f"Tipo de gráfico desconocido: {tipo}")
        fn(s, t0, t1, g)
        # Los gráficos que ocupan la franja inferior o toda la pantalla
        # sustituyen al subtítulo mientras están en pantalla.
        if tipo in ("titulo", "dato", "pregunta", "portada", "suscribete", "cierre"):
            ocupado.append((t0 - 0.35, t1 + 0.1))

    if vertical:
        g_marca_v(s, 0, fin)
        if plan.get("gancho"):
            g_gancho_v(s, 0, min(fin, float(plan.get("gancho_dur", 3.2))), plan["gancho"])
        if plan.get("final", "Episodio completo en el canal"):
            g_final_v(s, max(0, fin - 3.5), fin, plan.get("final", "Episodio completo en el canal"))
        if palabras:
            subtitulos_v(s, frases(palabras, 20, pausa=0.35))
    else:
        marca = plan.get("marca", {"desde": 0})
        if marca is not False:
            m0 = linea.a_salida(float(marca.get("desde", 0)))
            # La marca no se pisa con la portada.
            port = [g for g in graficos if g["tipo"] == "portada"]
            if port:
                m0 = max(m0, linea.a_salida(float(port[0]["t"])) + float(port[0].get("dur", 3)))
            g_marca_h(s, m0, fin_contenido)
        if palabras and plan.get("subtitulos", True):
            subtitulos_h(s, frases(palabras, 42), ocupado)
    return s


def encuadres(linea: Linea, plan: dict) -> list[float]:
    """Nivel de zoom de cada tramo. Solo cambia en cortes que quitaron una
    pausa real: cambiar de plano en cada respiración marea."""
    cfg = plan.get("encuadre", {})
    niveles = cfg.get("niveles", [1.0, 1.18])
    minimo = float(cfg.get("cambio_minimo", 0.8))
    out, idx = [], 0
    for i, (fa, fb) in enumerate(linea.tramos):
        if i > 0:
            hueco = linea.segundos(fa - linea.tramos[i - 1][1])
            if hueco >= minimo or hueco < 0:
                idx = (idx + 1) % len(niveles)
        out.append(niveles[idx])
    return out


def recorte(sw, sh, W, H, z, cx, cy) -> str:
    cw = min(sw, sh * W / H) / z
    ch = cw * H / W
    cw, ch = int(cw) // 2 * 2, int(ch) // 2 * 2
    x = min(max(0, cx * sw - cw / 2), sw - cw)
    y = min(max(0, cy * sh - ch / 2), sh - ch)
    return f"crop={cw}:{ch}:{int(x)}:{int(y)},scale={W}:{H}:flags=lanczos,setsar=1"


def cmd_render(arg):
    ruta_plan = Path(arg.plan).resolve()
    plan = json.loads(ruta_plan.read_text(encoding="utf-8"))
    base = ruta_plan.parent

    def ruta(p):
        return str(p if Path(p).is_absolute() else (base / p).resolve())

    fuente = ruta(plan["fuente"])
    if (aviso := aviso_faststart(fuente)):
        print(aviso)
    info = sondear(fuente)
    vertical = plan.get("formato", "horizontal") == "vertical"
    W, H = (1080, 1920) if vertical else (1920, 1080)

    if plan.get("cortes"):
        tramos = json.loads(Path(ruta(plan["cortes"])).read_text())["segmentos"]
    else:
        tramos = [[0, info["duracion"]]]
    if plan.get("rango"):
        r = plan["rango"]
        tramos = recortar_a(tramos, r if isinstance(r[0], list) else [r])
    tramos = restar(tramos, plan.get("quitar", []))
    linea = Linea(tramos, info["fps"], info["duracion"])
    zooms = encuadres(linea, plan)
    centro = plan.get("encuadre", {}).get("centro", [0.5, 0.42])

    palabras = palabras_a_salida(cargar_palabras(plan, base), linea)
    s = construir_ass(plan, linea, palabras, vertical)

    # Ventana de prueba (segundos de la salida): renderiza solo los tramos que
    # la tocan, para validar el estilo en un minuto en vez de en horas.
    sel = list(range(len(linea.tramos)))
    desfase = 0.0
    if arg.prueba:
        pa, pb = (float(x) for x in arg.prueba.split("-"))
        sel = [i for i in sel
               if linea.segundos(linea.inicio_salida[i]) < pb
               and linea.segundos(linea.inicio_salida[i] + linea.tramos[i][1] - linea.tramos[i][0]) > pa]
        desfase = linea.segundos(linea.inicio_salida[sel[0]])
        s.eventos = [(t, desplazar(e, desfase)) for t, e in s.eventos]

    trabajo = Path(tempfile.mkdtemp(prefix="nmr-"))
    ass_ruta = trabajo / "graficos.ass"
    s.escribir(ass_ruta)
    if arg.ass:
        shutil.copy(ass_ruta, arg.ass)

    audio_ext = plan.get("audio")
    sr = info["tasa"]
    if audio_ext:
        sr = sondear(ruta(audio_ext))["tasa"]
    fps = info["fps"]
    n = len(sel)
    partes = [f"[0:v]split={n}" + "".join(f"[s{i}]" for i in range(n)) if n > 1 else "[0:v]null[s0]",
              f"[{1 if audio_ext else 0}:a]asplit={n}" + "".join(f"[r{i}]" for i in range(n))
              if n > 1 else f"[{1 if audio_ext else 0}:a]anull[r0]"]
    desfase_audio = float(plan.get("audio_desfase", 0))
    for k, i in enumerate(sel):
        fa, fb = linea.tramos[i]
        sa = round((Fraction(fa) / fps + Fraction(desfase_audio).limit_denominator(1000)) * sr)
        sb = sa + round(Fraction(fb - fa) / fps * sr)
        d = float(Fraction(fb - fa) / fps)
        partes.append(f"[s{k}]trim=start_frame={fa}:end_frame={fb},setpts=PTS-STARTPTS,"
                      f"{recorte(info['ancho'], info['alto'], W, H, zooms[i], *centro)}[v{k}]")
        # Rampa de 15 ms en cada empalme: sin ella se oye un chasquido.
        partes.append(f"[r{k}]atrim=start_sample={max(0, sa)}:end_sample={sb},asetpts=PTS-STARTPTS,"
                      f"aformat=sample_rates=48000:channel_layouts=stereo,"
                      f"afade=t=in:d=0.015,afade=t=out:st={max(0, d - 0.015):.4f}:d=0.015[a{k}]")
    partes.append("".join(f"[v{k}][a{k}]" for k in range(n)) + f"concat=n={n}:v=1:a=1[cv][ca]")
    fuentes = str(FUENTES).replace("\\", "/").replace(":", "\\:")
    assf = str(ass_ruta).replace("\\", "/").replace(":", "\\:")
    grade = plan.get("color", "eq=contrast=1.05:saturation=1.07:gamma=0.98,vignette=angle=PI/5")
    partes.append(f"[cv]{grade + ',' if grade else ''}ass=filename='{assf}':fontsdir='{fuentes}',"
                  f"format=yuv420p[vout]")
    total = linea.segundos(sum(linea.tramos[i][1] - linea.tramos[i][0] for i in sel))
    partes.append(f"[ca]highpass=f=70,loudnorm=I=-14:TP=-1.5:LRA=11,"
                  f"aresample=48000,afade=t=out:st={max(0, total - 0.8):.3f}:d=0.8[aout]")
    grafo = trabajo / "grafo.txt"
    grafo.write_text(";\n".join(partes))

    salida = ruta(plan.get("salida", "salidas/salida.mp4")) if not arg.salida else arg.salida
    if arg.prueba:
        salida = str(Path(salida).with_name(Path(salida).stem + f"_prueba{arg.prueba}.mp4"))
    Path(salida).parent.mkdir(parents=True, exist_ok=True)
    version = ejecutar(["ffmpeg", "-version"], capturar=True).split()[2]
    opcion_grafo = "-/filter_complex" if version[:1].isdigit() and int(version.split(".")[0]) >= 7 \
        else "-filter_complex_script"
    cmd = ["ffmpeg", "-hide_banner", "-y", "-i", fuente]
    if audio_ext:
        cmd += ["-i", ruta(audio_ext)]
    cmd += [opcion_grafo, str(grafo), "-map", "[vout]", "-map", "[aout]",
            "-r", f"{fps.numerator}/{fps.denominator}",
            "-c:v", "libx264", "-preset", arg.preset, "-crf", str(arg.crf), "-g", "60",
            "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", salida]
    print(f"{n} tramos · salida {hms(total)} · {W}x{H} -> {salida}")
    subprocess.run(cmd, check=True)
    print(f"Listo: {salida}")
    if arg.max_mb and not arg.prueba:
        partir(salida, arg.max_mb)


def desplazar(evento: str, d: float) -> str:
    campos = evento.split(",", 3)

    def mover(t):
        h, m, s_ = t.split(":")
        return t_ass(int(h) * 3600 + int(m) * 60 + float(s_) - d)
    campos[1], campos[2] = mover(campos[1]), mover(campos[2])
    return ",".join(campos)


# -------------------------------------------------------- partir / fotogramas

def partir(entrada: str, max_mb: float):
    """Divide en partes de menos de `max_mb` (p. ej. 95 MB por el límite de
    100 MB por archivo de GitHub), cortando en keyframes sin recodificar."""
    tam = Path(entrada).stat().st_size / 1e6
    if tam <= max_mb:
        print(f"{entrada} pesa {tam:.0f} MB: no hace falta partirlo.")
        return
    dur = sondear(entrada)["duracion"]
    n = math.ceil(tam / (max_mb * 0.95))
    cortes = ",".join(f"{dur * i / n:.3f}" for i in range(1, n))
    patron = str(Path(entrada).with_name(Path(entrada).stem + "_parte%d_de_" + str(n) + ".mp4"))
    ejecutar(["ffmpeg", "-v", "error", "-y", "-i", entrada, "-map", "0", "-c", "copy",
              "-f", "segment", "-segment_times", cortes, "-reset_timestamps", "1",
              "-segment_start_number", "1", "-movflags", "+faststart", patron])
    for f in sorted(Path(entrada).parent.glob(Path(entrada).stem + "_parte*")):
        print(f"  {f.name}: {f.stat().st_size / 1e6:.0f} MB")


def cmd_partir(a):
    partir(a.entrada, a.max_mb)


def cmd_fotogramas(a):
    """Exporta fotogramas a resolución completa para elegir la miniatura."""
    info = sondear(a.entrada)
    Path(a.salida).mkdir(parents=True, exist_ok=True)
    tiempos = [float(x) for x in a.tiempos.split(",")] if a.tiempos else \
        [t for t in range(int(a.cada), int(info["duracion"]), int(a.cada))]
    for t in tiempos:
        ejecutar(["ffmpeg", "-v", "error", "-y", "-ss", f"{t:.2f}", "-i", a.entrada,
                  "-frames:v", "1", "-q:v", "2", str(Path(a.salida) / f"f_{t:07.2f}.jpg")])
    ejecutar(["ffmpeg", "-v", "error", "-y", "-pattern_type", "glob", "-i",
              str(Path(a.salida) / "f_*.jpg"), "-vf", "scale=384:-1,tile=6x6",
              "-frames:v", "1", str(Path(a.salida) / "_hoja.jpg")])
    print(f"{len(tiempos)} fotogramas en {a.salida} (vista general: _hoja.jpg)")


# ----------------------------------------------------------------------- CLI

def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    q = sub.add_parser("analizar", help="detectar silencios y escribir cortes.json")
    q.add_argument("--entrada", required=True)
    q.add_argument("--json", required=True)
    for k, v in OPC_SILENCIO.items():
        q.add_argument("--" + k.replace("_", "-"), dest=k, type=float, default=None,
                       help=f"por defecto {v}")
    q.set_defaults(f=cmd_analizar)

    q = sub.add_parser("transcribir", help="transcripción con tiempos por palabra")
    q.add_argument("--entrada")
    q.add_argument("--json", required=True)
    q.add_argument("--modelo", default="small")
    q.add_argument("--srt", help="usar un .srt/.vtt existente en vez de Whisper")
    q.set_defaults(f=cmd_transcribir)

    q = sub.add_parser("render", help="montar el video final a partir de un plan JSON")
    q.add_argument("--plan", required=True)
    q.add_argument("--prueba", help="solo una ventana de la salida, p. ej. 0-90")
    q.add_argument("--salida")
    q.add_argument("--crf", type=int, default=20)
    q.add_argument("--preset", default="medium")
    q.add_argument("--max-mb", type=float, default=None, help="partir el resultado")
    q.add_argument("--ass", help="guardar también el .ass generado aquí")
    q.set_defaults(f=cmd_render)

    q = sub.add_parser("partir", help="dividir en partes de menos de N MB")
    q.add_argument("--entrada", required=True)
    q.add_argument("--max-mb", type=float, default=95)
    q.set_defaults(f=cmd_partir)

    q = sub.add_parser("fotogramas", help="fotogramas para la miniatura")
    q.add_argument("--entrada", required=True)
    q.add_argument("--salida", required=True)
    q.add_argument("--cada", type=float, default=20)
    q.add_argument("--tiempos", help="lista de segundos separados por comas")
    q.set_defaults(f=cmd_fotogramas)

    a = p.parse_args()
    a.f(a)


if __name__ == "__main__":
    main()
