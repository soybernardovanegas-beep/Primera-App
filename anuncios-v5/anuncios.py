import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from motor import *

def T(lineas, resalta=()):
    return lambda t, D, vd, lead: [titulo(lineas, t, t + D, resalta)]
def CH(texto, color=None, x=60, y=300):
    return lambda t, D, vd, lead: [chip(texto, t, t + D, x, y, color)]
def N(n):
    return lambda t, D, vd, lead: [num(n, t, t + D)]

KW_COMUN = ["pagas al recibir", "garantía de 10 días", "envío gratis", "hoy"]

def ad17():
    beats = [
      dict(planos=[("avatar", 0, 3.1)], audio_clip="avatar", voz_dur=2.95, sub="Todo el mundo me pregunta si esto sí corta teja ondulada.",
           exacto=3.1, lead=0.1, extras=[T(["¿SÍ CORTA", "TEJA ONDULADA?"], ["TEJA ONDULADA?"])]),
      dict(voz="Recto…", planos=[("k39", 14.7, 18.2)], min=3.4),
      dict(voz="y en curva.", planos=[("k39", 8.6, 11.7)], min=3.0),
      dict(voz="Sin chispas y sin doblar la lámina.", planos=[("ddo", 20.9, 22.4), ("luke", 8.5, 10.5)], min=2.8),
      dict(voz="El secreto es la varilla de apoyo bien sujeta.", planos=[("fff", 4.7, 6.6), ("fff", 6.6, 8.3)], min=3.6),
      dict(voz="Se pone en el taladro que ya tienes. Pídelo hoy y pagas cuando te llegue.",
           planos=[("gq", 14.3, 17.0), ("dde", 9.8, 11.3), ("k39", 11.7, 14.7)], min=5.0),
    ]
    return construir("AD17-teja-ondulada", beats, ["teja ondulada", "sin chispas", "varilla de apoyo", "pagas cuando te llegue", "hoy"])


def LISTA(items, texto, y0=430, paso=122, fin="@E3"):
    """items: (rotulo, ok, frase-ancla). Cada fila entra cuando la voz llega a su ancla."""
    def f(t, D, vd, lead):
        out = []
        for k, (rot, ok, ancla) in enumerate(items):
            pos = texto.index(ancla) / max(1, len(texto))
            out += item(rot, ok, t + lead + vd * pos, fin, y0 + k * paso)
        return out
    return f

def ad18():
    L = ["Uno. Ajústalo en el mandril como una broca.", "Dos. Ajusta bien el cabezal con la llave Allen que viene incluida.",
         "Tres. Sujeta la varilla de apoyo para que no gire.", "Cuatro. Velocidad media y avanza despacio."]
    beats = [
      dict(voz="Si este cabezal no te corta, estás cometiendo este error.", planos=[("dde", 1.7, 2.8), ("dde", 9.8, 11.3), ("dde", 0, 1.7)], min=3.6,
           extras=[T(["EL ERROR #1", "AL CORTAR LÁMINA"], ["#1"])]),
      dict(voz=L[0], planos=[("mie", 16.9, 20.2)], min=3.6, extras=[N(1)]),
      dict(voz=L[1], planos=[("mie", 34.6, 38.1)], min=4.2, extras=[N(2)]),
      dict(voz=L[2], planos=[("fff", 4.7, 6.6), ("fff", 6.6, 8.3)], min=3.6, extras=[N(3)]),
      dict(voz=L[3], planos=[("gq", 14.3, 17.0), ("k32", 12.7, 14.3)], min=3.6, extras=[N(4)]),
      dict(voz="Con eso cortas como un profesional. Y si algo falla, tienes garantía de 10 días.",
           planos=[("ddo", 20.9, 22.4), ("k39", 11.7, 14.7)], min=5.2),
    ]
    return construir("AD18-lo-estas-usando-mal", beats, ["error", "llave allen", "varilla de apoyo", "velocidad media", "garantía de 10 días", "despacio"])

def ad19():
    beats = [
      dict(planos=[("luke", 8.8, 10.8)], exacto=2.0, **({"sonido": ("luke", 8.8, 10.8)} if os.environ.get("XV_SONIDO") else {})),
      dict(voz="No te gastes una fortuna en una cizalla eléctrica.", planos=[("gq", 0, 2.9)], min=3.3,
           extras=[T(["¿TODAVÍA CORTAS", "CON PULIDORA?"], ["PULIDORA?"])]),
      dict(voz="La pulidora saca chispas, hace ruido y quema el galvanizado.", planos=[("ddo", 0, 4.1)], min=4.0, extras=[CH("PULIDORA", "&H003030E0&")]),
      dict(voz="La tijera te deja la mano molida y el borde torcido.", planos=[("ren", 0, 3.9)], min=3.9, extras=[CH("TIJERA", "&H003030E0&")]),
      dict(voz="Esto corta limpio, con el taladro que ya tienes.", planos=[("dde", 14.8, 17.9), ("k39", 8.6, 11.7)], min=4.2, extras=[CH("CABEZAL", "&H0050C800&")]),
      dict(voz="Pídelo hoy. Envío gratis y pagas al recibir.", planos=[("k39", 14.7, 18.2), ("dde", 9.8, 11.3)], min=4.8),
    ]
    return construir("AD19-vs-cizalla", beats, ["fortuna", "chispas", "ruido", "borde torcido", "corta limpio", "envío gratis", "pagas al recibir", "hoy"])

def ad20():
    t1 = "Sí corta teja de zinc, perfiles de drywall, lámina de hierro hasta un milímetro, aluminio y cobre."
    t2 = "No corta acero inoxidable ni lámina gruesa."
    beats = [
      dict(voz="Antes de comprarlo, mira lo que sí corta… y lo que no.", planos=[("dde", 1.7, 2.8), ("dde", 0, 1.7)], min=3.4,
           extras=[lambda t, D, vd, lead: item("LO QUE SÍ", True, t, t + D, 820) + item("LO QUE NO", False, t, t + D, 960)]),
      dict(voz=t1, planos=[("k39", 14.7, 18.2), ("fff", 4.7, 6.6), ("dde", 0, 1.7), ("ddo", 20.9, 22.4), ("dfz", 2.6, 4.5)], min=8.0,
           extras=[LISTA([("Teja de zinc", True, "teja de zinc"), ("Perfiles de drywall", True, "perfiles de drywall"),
                          ("Hierro hasta 1 mm", True, "lámina de hierro"), ("Aluminio y cobre", True, "aluminio y cobre")], t1)]),
      dict(voz=t2, planos=[("mie", 34.6, 38.1)], min=3.2,
           extras=[LISTA([("Acero inoxidable", False, "acero inoxidable"), ("Lámina gruesa", False, "lámina gruesa")], t2, y0=430 + 4 * 122)]),
      dict(voz="Si lo tuyo es lámina delgada, es para ti.", planos=[("k39", 5.4, 8.6)], min=3.4),
      dict(voz="Y si no te convence, tienes garantía de 10 días. Pagas cuando te llegue.", planos=[("gq", 14.3, 17.0), ("dde", 9.8, 11.3)], min=5.2),
    ]
    return construir("AD20-si-y-no", beats, ["sí corta", "no corta", "garantía de 10 días", "pagas cuando te llegue", "lámina delgada"])

def ad21():
    beats = [
      dict(voz="¿No sabes qué regalarle a tu papá esta Navidad?", planos=[("dde", 1.7, 2.8), ("dde", 0, 1.7)], min=3.4,
           extras=[T(["EL REGALO PARA", "EL QUE", "ARREGLA TODO"], ["ARREGLA TODO"])]),
      dict(voz="Convierte su taladro en cortadora de lámina.", planos=[("dde", 9.8, 11.3), ("k39", 5.4, 8.6)], min=3.4),
      dict(voz="Recto, en curva y sin chispas.", planos=[("k39", 14.7, 18.2), ("fff", 10.6, 12.7)], min=3.4),
      dict(voz="Llévalo en combo: uno para tu papá y otro para el suegro.", split=True, planos=[("k39", 14.7, 18.2), ("k39", 8.6, 11.7)], min=4.4,
           extras=[CH("PARA PAPÁ", "&H0050C800&", 60, 300), CH("PARA EL SUEGRO", "&H0050C800&", 60, 990)]),
      dict(voz="Pídelo hoy y llega antes de Navidad. Pagas al recibir.", planos=[("gq", 14.3, 17.0), ("dde", 14.8, 17.9)], min=5.0),
    ]
    return construir("AD21-regalo-papa", beats, ["navidad", "combo", "sin chispas", "hoy", "pagas al recibir"], tarjeta_lazo=True)

if __name__ == "__main__":
    which = sys.argv[1:] or ["ad17"]
    for w in which:
        out, total, _ = globals()[w]()
        n = os.path.basename(out)[:-4]
        p = hoja_pruebas(out, total, n, [1.2, total * 0.45, total - 4.0, total - 1.0])
        miniatura(out, 1.4, f"{AQUI}/{n}.jpg")
        print("hoja:", p)
