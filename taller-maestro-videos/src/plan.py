# Plan de los 8 videos: voz, textos en pantalla y tomas usadas.
# clip: (clave_fuente, inicio_s)   keys -> ver SRC en build.py
# kind: normal | split (2 fuentes lado a lado) | seq (2 fuentes una tras otra)

CABEZAL = dict(
    barra="$89.900 · Pagas al recibir",
    producto=["CABEZAL CORTADOR"],
    sonido="corte",
)
AFILADOR = dict(
    barra="$69.900 · Pagas al recibir",
    producto=["AFILADOR DE BROCAS"],
    sonido="esmeril",
)

VIDEOS = {
 "C1": dict(file="C1-gotera", **CABEZAL, ofertas=["2 POR $139.900", "3 POR $179.900"], scenes=[
    dict(voz="Llueve y la teja de zinc gotea.", txt="¿LLUEVE Y GOTEA?", clip=("rain", 0.0)),
    dict(voz="Con este cabezal, tu taladro corta la teja de reemplazo.", txt="TU TALADRO CORTA ZINC", clip=("ddgq", 2.5)),
    dict(voz="Recto o en curva, sin deformar la lámina.", txt="SIN DEFORMAR LA LÁMINA", clip=("dk1539", 6.5)),
    dict(voz="No incluye taladro. No corta acero inoxidable.", txt="NO INCLUYE TALADRO · NO CORTA INOXIDABLE", clip=("ddgq", 20.5)),
    dict(voz="Ochenta y nueve mil novecientos pesos. Envío gratis, pagas al recibir. Escríbenos.", card=True),
 ]),
 "C2": dict(file="C2-sin-chispas", **CABEZAL, ofertas=["2 POR $139.900", "3 POR $179.900"], scenes=[
    dict(voz="¿Todavía cortas lámina con pulidora?", txt="¿LÁMINA CON PULIDORA?", clip=("grinder", 0.0)),
    dict(voz="Con el cabezal no hay chispas ni disco que se rompa.", txt="CERO CHISPAS", clip=("fffcccp", 0.5)),
    dict(voz="El corte queda limpio y la lámina no se quema.", txt="CORTE LIMPIO, SIN QUEMAR", clip=("fffcccp", 11.0)),
    dict(voz="Zinc, drywall, hojalata, aluminio.", txt="ZINC · DRYWALL · LÁMINA HASTA 1 MM", clip=("dk1632", 13.0)),
    dict(voz="Ochenta y nueve mil novecientos pesos. Envío gratis, pagas al recibir.", card=True),
 ]),
 "C3": dict(file="C3-antes-de-cizalla", **CABEZAL, ofertas=["2 POR $139.900", "3 POR $179.900"], scenes=[
    dict(voz="Antes de comprar una cizalla eléctrica, mira esto.", txt="NO COMPRES CIZALLA", clip=("ddob", 4.5)),
    dict(voz="La tijera cansa y tuerce. Tu taladro corta derecho.", txt="TIJERA VS TALADRO", kind="seq", d1=1.7, clip=("tijera", 23.0), clip2=("fffcccp", 13.5)),
    dict(voz="Recto, en curva, en segundos.", txt="RECTO Y EN CURVA", clip=("dk1539", 9.0)),
    dict(voz="Se pone en el mandril y listo. No incluye taladro.", txt="SE PONE EN SEGUNDOS", clip=("fffcccp", 5.5)),
    dict(voz="Ochenta y nueve mil novecientos pesos. Pagas al recibir.", card=True),
 ]),
 "C4": dict(file="C4-regalo", **CABEZAL, ofertas=["2 POR $139.900"], scenes=[
    dict(voz="Si tu papá tiene taladro…", txt="¿TU PAPÁ TIENE TALADRO?", clip=("ddgq", 20.0)),
    dict(voz="Este es el regalo que sí va a usar.", txt="ESTE ES SU REGALO", clip=("ddgq", 13.0)),
    dict(voz="Corta zinc, drywall y lámina, recto o en curva.", txt="CORTA ZINC Y DRYWALL", clip=("dk1632", 9.0)),
    dict(voz="Ochenta y nueve mil novecientos pesos, o dos por ciento treinta y nueve mil novecientos. Envío gratis y pagas al recibir.", card=True),
 ]),
 "A1": dict(file="A1-botando-plata", **AFILADOR, ofertas=["2 POR $119.900"], scenes=[
    dict(voz="¿Cuántas brocas has botado este año?", txt="¿CUÁNTAS BROCAS HAS BOTADO?", clip=("dull", 0.0)),
    dict(voz="El problema no es la broca: se le gastó el filo.", txt="SE GASTÓ EL FILO", clip=("skid", 0.0)),
    dict(voz="Pones el afilador en tu taladro y le devuelves el filo.", txt="AFÍLALA CON TU TALADRO", clip=("digify", 1.3)),
    dict(voz="Y vuelve a perforar.", txt="VUELVE A PERFORAR", clip=("ia_afi", 0)),
    dict(voz="Sesenta y nueve mil novecientos pesos. Envío gratis, pagas al recibir.", card=True),
 ]),
 "A2": dict(file="A2-filo-en-segundos", **AFILADOR, ofertas=["2 POR $119.900"], scenes=[
    dict(voz="Esta broca estaba sin filo hace un minuto.", txt="ESTA BROCA ESTABA SIN FILO", clip=("ia_afi", 0)),
    dict(voz="Así la afilé, con el mismo taladro.", txt="ASÍ LA AFILÉ", clip=("lab", 3.0)),
    dict(voz="La punta queda lista otra vez.", txt="ANTES / DESPUÉS", clip=("macro", 0.0)),
    dict(voz="Sesenta y nueve mil novecientos pesos. Pagas al recibir. Escríbenos.", card=True),
 ]),
 "A3": dict(file="A3-sin-filo-vs-afilada", **AFILADOR, ofertas=["2 POR $119.900"], scenes=[
    dict(voz="Misma lámina, mismo taladro…", txt="SIN FILO VS AFILADA", clip=("compare", 0.0)),
    dict(voz="Una quema y patina, la otra entra de una.", txt="¿CUÁL PREFIERES?", clip=("compare", 3.5)),
    dict(voz="La diferencia es un minuto con el afilador.", txt="LA DIFERENCIA: 1 MINUTO", clip=("digify", 6.0)),
    dict(voz="Sesenta y nueve mil novecientos pesos. Envío gratis, pagas al recibir.", card=True),
 ]),
 "A4": dict(file="A4-regalo", **AFILADOR, ofertas=["2 POR $119.900"], scenes=[
    dict(voz="Para el que siempre anda con el taladro…", txt="PARA EL QUE SIEMPRE ANDA CON TALADRO", clip=("table", 0.0)),
    dict(voz="Un regalo útil: le devuelve el filo a sus brocas.", txt="ESTE ES SU REGALO", clip=("lab", 3.0)),
    dict(voz="Lleva dos: uno para él y uno para regalar.", txt="LLEVA 2: UNO PARA REGALAR", clip=("lab", 0.3)),
    dict(voz="Sesenta y nueve mil novecientos pesos, o dos por ciento diecinueve mil novecientos. Pagas al recibir.", card=True),
 ]),
}
