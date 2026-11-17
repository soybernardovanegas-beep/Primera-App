"""Fuentes y recortes. Cada preset recorta el borde con avisos/logos y devuelve 1080x1920."""
import os
SRC = os.environ.get("XV_SRC", "/tmp/claude-0/-home-user-Primera-App/7f6186a7-390b-5611-a850-44352e5e8f96/scratchpad/drive")
# nombre corto -> (archivo, ancho, alto, preset)
FUENTES = {
 "avatar": ("vids-sin-titulo.mp4", 1080, 1920, "full"),
 "gq":   ("igexport-DdGQxm8SLTz.mp4", 720, 1280, "full"),
 "dde":  ("igexport-DdeEohWTxsU.mp4", 720, 1280, "disc"),
 "ddo":  ("igexport-DdobDpKzPrM.mp4", 720, 1280, "full"),
 "dfz":  ("igexport-DfZyVrgGV1R.mp4", 720, 1280, "disc2"),
 "fff":  ("fffcccp.mp4", 720, 1280, "disc"),
 "k39":  ("dropkiller-1539429091267256.mp4", 720, 1280, "lbox"),
 "k32":  ("dropkiller-1632841641762379.mp4", 720, 1280, "full"),
 "luke": ("lukeadams.mp4", 576, 986, "sub"),
 "ren":  ("Renata_Salazar.mp4", 576, 1024, "full"),
 "mie":  ("mielectricoplomero.mp4", 576, 1024, "full"),
}
# (y0, y1) en fracción de la altura útil; después se recorta al centro en 9:16
PRESETS = {"full": (0.0, 1.0), "disc": (0.09, 0.92), "disc2": (0.09, 0.86),
           "lbox": (98/1280, 1182/1280), "sub": (0.0, 0.80)}
def filtro(clave, extra_zoom=1.0):
    f, w, h, p = FUENTES[clave]
    y0, y1 = PRESETS[p]
    ch = int(h * (y1 - y0)) // 2 * 2; cy = int(h * y0)
    cw = int(ch * 9 / 16) // 2 * 2; cx = (w - cw) // 2
    z = ""
    if extra_zoom > 1.0:
        zw = int(cw / extra_zoom) // 2 * 2; zh = int(zw * 16 / 9) // 2 * 2
        z = f",crop={zw}:{zh}:{(cw-zw)//2}:{(ch-zh)//2}"
    return f"crop={cw}:{ch}:{cx}:{cy}{z},scale=1080:1920:flags=lanczos,setsar=1,fps=30,format=yuv420p"
