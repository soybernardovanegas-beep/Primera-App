# Anuncios v5 — XOLVETA cabezal cortador (AD17–AD21)

Formato: 1080×1920, 30 fps, H.264 + AAC 128k, -14 LUFS (picos bajo -1,5 dB). Voz: Gemini TTS `gemini-3.1-flash-tts-preview`, voz Puck, acelerada 1,12× (`motor.py`). Subtítulos quemados Inter ExtraBold/Black, palabras clave en amarillo #FFD400, dentro de las zonas seguras de Reels. Sin precios en ningún anuncio. Tarjeta final de 2,5 s con fondo desenfocado y botón verde #25D366.

| Anuncio | Duración | Peso |
|---|---|---|
| AD17-teja-ondulada.mp4 | 22.3 s | 11.7 MB |
| AD18-lo-estas-usando-mal.mp4 | 24.6 s | 13.5 MB |
| AD19-vs-cizalla.mp4 | 22.3 s | 12.0 MB |
| AD20-si-y-no.mp4 | 23.8 s | 12.4 MB |
| AD21-regalo-papa.mp4 | 19.6 s | 9.7 MB |

## AD17-teja-ondulada — «¿Sí corta teja ondulada?»

0–3 s · Avatar (clip propio `Vídeo sin título.mp4`, 3,1 s): «Todo el mundo me pregunta si esto sí corta teja ondulada.» Texto: ¿SÍ CORTA TEJA ONDULADA?
3–15 s · Voz Puck: «Recto… / y en curva. / Sin chispas y sin doblar la lámina. / El secreto es la varilla de apoyo bien sujeta.» Planos: corte recto largo en un solo plano sobre teja ondulada, corte en curva, borde limpio en primer plano, varilla de apoyo.
Cierre · «Se pone en el taladro que ya tienes. Pídelo hoy y pagas cuando te llegue.»

**Notas:** El avatar solo tiene clip de gancho; el cierre lo dice la voz Puck sobre planos reales.

## AD18-lo-estas-usando-mal — «Si no te corta, lo estás usando mal»

Gancho · texto: EL ERROR #1 AL CORTAR LÁMINA. «Si este cabezal no te corta, estás cometiendo este error.»
Tutorial con números grandes: 1 «Uno. Ajústalo en el mandril como una broca.» · 2 «Dos. Ajusta bien el cabezal con la llave Allen que viene incluida.» · 3 «Tres. Sujeta la varilla de apoyo para que no gire.» · 4 «Cuatro. Velocidad media y avanza despacio.»
Cierre · «Con eso cortas como un profesional. Y si algo falla, tienes garantía de 10 días.»

**Notas:** No hay `xv-paso-1/2/3.jpg`: los pasos usan planos de video del material de Drive, sin Ken Burns. Los planos de los pasos 2 y 3 son aproximados (muestran el cabezal y el armado, no el gesto exacto de cada paso).

## AD19-vs-cizalla — «No te gastes una fortuna en una cizalla»

0–2 s · primer plano del corte limpio, sin voz.
Gancho · texto: ¿TODAVÍA CORTAS CON PULIDORA? «No te gastes una fortuna en una cizalla eléctrica.»
Comparación en secuencia con rótulos PULIDORA / TIJERA / CABEZAL: «La pulidora saca chispas, hace ruido y quema el galvanizado. La tijera te deja la mano molida y el borde torcido. Esto corta limpio, con el taladro que ya tienes.»
Cierre · «Pídelo hoy. Envío gratis y pagas al recibir.»

**Notas:** El opener de 2 s va sin sonido: no pude verificar que el audio original no tenga voz o música. Si quieres el sonido real del corte, hay que escucharlo antes de añadirlo (`XV_SONIDO=1`). No hay `imagen-5-comparacion-v2.jpg`.

## AD20-si-y-no — «Lo que sí corta y lo que no»

Gancho · filas LO QUE SÍ / LO QUE NO. «Antes de comprarlo, mira lo que sí corta… y lo que no.»
Lista animada: ✔ Teja de zinc · ✔ Perfiles de drywall · ✔ Hierro hasta 1 mm · ✔ Aluminio y cobre · ✘ Acero inoxidable · ✘ Lámina gruesa. «Sí corta teja de zinc, perfiles de drywall, lámina de hierro hasta un milímetro, aluminio y cobre. No corta acero inoxidable ni lámina gruesa. Si lo tuyo es lámina delgada, es para ti.»
Cierre · «Y si no te convence, tienes garantía de 10 días. Pagas cuando te llegue.»

**Notas:** No hay planos reales de drywall ni de aluminio en el material: esos ítems van con planos genéricos de corte. Revisa si prefieres cambiarlos.

## AD21-regalo-papa — «El regalo para el que arregla todo»

Gancho · texto: EL REGALO PARA EL QUE ARREGLA TODO. «¿No sabes qué regalarle a tu papá esta Navidad?»
Demo · «Convierte su taladro en cortadora de lámina. Recto, en curva y sin chispas. Llévalo en combo: uno para tu papá y otro para el suegro.» (pantalla dividida PARA PAPÁ / PARA EL SUEGRO)
Cierre · «Pídelo hoy y llega antes de Navidad. Pagas al recibir.» Tarjeta con moño rojo discreto.

**Notas:** Sin música: no hay una pista libre y segura disponible. «Llega antes de Navidad» es una promesa de entrega: confírmala con la transportadora. No hay `AD15` ni `xv-clip-b`: se usan planos de corte en curva del material de Drive.

## Material y derechos
Todo el video sale de la carpeta de Drive «Cabezal taladro corta lamina». Salvo el clip del avatar, son videos de terceros (marcas y creadores ajenos). Se usaron solo tramos sin nombres, logos ni textos quemados, recortando bordes con avisos. Los derechos de ese material no están resueltos: Meta puede rechazar o retirar anuncios con contenido ajeno. Algunos taladros muestran la marca de la herramienta en tamaño pequeño.

## Reproducir
`python3 anuncios.py ad17 ad18 ad19 ad20 ad21` (variable `XV_SRC` = carpeta con los videos de Drive; `XV_TTS` = modelo de voz). La voz gratuita de Gemini permite solo 10 llamadas al día por modelo; el motor usa una por anuncio.
