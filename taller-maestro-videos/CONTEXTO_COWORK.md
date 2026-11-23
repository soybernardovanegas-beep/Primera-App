# Encargo para Claude Cowork (navegador): voces y tomas de IA para 8 anuncios de Taller Maestro

Responde siempre en español. Trabaja en el navegador con las herramientas de IA que ya tengo abiertas con mi sesión (Gemini / Google AI Studio / Flow o el generador de video que esté disponible). No publiques nada en Meta ni en ninguna red. Al terminar, sube todo a la carpeta de Drive indicada y avísame.

## 0. Contexto

Taller Maestro vende por WhatsApp, contraentrega en Colombia, dos productos. Estoy armando 8 videos verticales de anuncios para Meta (4 del cabezal cortador de lámina: C1–C4, y 4 del afilador de brocas: A1–A4). El montaje final lo hago yo con ffmpeg. **Tu trabajo es solo producir dos cosas: (A) las voces y (B) las tomas de video que me faltan.**

Productos, tal como son (no los inventes distintos):
- **Cabezal cortador de lámina:** accesorio metálico plateado que se monta en el mandril de un taladro y lo convierte en cizalla (dos ruedas de corte y un brazo/varilla estabilizadora). Corta teja de zinc, drywall, lámina delgada, recto y en curva, sin chispas. **No incluye taladro.**
- **Afilador de brocas:** cuerpo de plástico **azul** con una piedra de esmeril **rosada**, se monta en el taladro y le devuelve el filo a las brocas. **No incluye taladro.**

### Prohibiciones (todas, siempre)
- Nada de texto, subtítulos, logos, marcas ni marcas de agua dentro de la imagen. Si el taladro sale con una marca legible, repite la toma.
- No mostrar usos que el producto no hace: no cortar acero inoxidable ni lámina gruesa, no afilar brocas de concreto, no decir ni mostrar diámetros.
- Sin precio, sin testimonios, sin estrellas, sin cifras, sin urgencia.
- Sin personas hablando a cámara. Si aparecen manos, que no se vea el rostro.
- Sin chispas en las tomas del cabezal (el producto corta sin chispas). Solo la pulidora, en la toma que lo pide, las echa.

## PARTE A. Voces (Gemini, texto a voz)

Usa **Google AI Studio → Generar voz / Speech generation** (o la función de voz de Gemini disponible), un solo hablante.

- **Voz:** masculina, la que mejor suene cálida y cercana (por ejemplo "Orus"; si suena mal, prueba otra y usa la misma en los 8 videos).
- **Instrucción de estilo (pégala antes del texto, sin que la lea):**
  > Habla con acento paisa de Medellín, Colombia: entonación melodiosa y cantada, voz masculina cálida, cercana y amable, de maestro de obra antioqueño explicándole una herramienta a un colega, ritmo ágil pero claro. Lee exactamente este texto, sin añadir ni quitar palabras.
- **Reglas:** lee exactamente el texto; deja una pausa corta entre frases (cada línea en blanco es una pausa). Si el modelo lee la instrucción en voz alta, usa el campo de estilo/instrucciones separado en vez de pegarla en el texto. Cada audio debe durar **entre 14 y 22 s**. No cambies cifras ni palabras.
- **Entrega:** un archivo `.wav` por video, nombrado `VOZ_C1.wav` … `VOZ_A4.wav`. Primero entrégame una muestra de **C1** y espera mi aprobación antes de generar las otras 7.

Textos (los precios van dichos completos, tal cual):

**VOZ_C1**
```
Llueve y la teja de zinc gotea.

Con este cabezal, tu taladro corta la teja de reemplazo.

Recto o en curva, sin deformar la lámina.

No incluye taladro. No corta acero inoxidable.

Ochenta y nueve mil novecientos pesos. Envío gratis, pagas al recibir. Escríbenos.
```

**VOZ_C2**
```
¿Todavía cortas lámina con pulidora?

Con el cabezal no hay chispas ni disco que se rompa.

El corte queda limpio y la lámina no se quema.

Zinc, drywall, hojalata, aluminio.

Ochenta y nueve mil novecientos pesos. Envío gratis, pagas al recibir.
```

**VOZ_C3**
```
Antes de comprar una cizalla eléctrica, mira esto.

La tijera cansa y tuerce. Tu taladro corta derecho.

Recto, en curva, en segundos.

Se pone en el mandril y listo. No incluye taladro.

Ochenta y nueve mil novecientos pesos. Pagas al recibir.
```

**VOZ_C4**
```
Si tu papá tiene taladro…

Este es el regalo que sí va a usar.

Corta zinc, drywall y lámina, recto o en curva.

Ochenta y nueve mil novecientos pesos, o dos por ciento treinta y nueve mil novecientos. Envío gratis y pagas al recibir.
```

**VOZ_A1**
```
¿Cuántas brocas has botado este año?

El problema no es la broca: se le gastó el filo.

Pones el afilador en tu taladro y le devuelves el filo.

Y vuelve a perforar.

Sesenta y nueve mil novecientos pesos. Envío gratis, pagas al recibir.
```

**VOZ_A2**
```
Esta broca estaba sin filo hace un minuto.

Así la afilé, con el mismo taladro.

La punta queda lista otra vez.

Sesenta y nueve mil novecientos pesos. Pagas al recibir. Escríbenos.
```

**VOZ_A3**
```
Misma lámina, mismo taladro…

Una quema y patina, la otra entra de una.

La diferencia es un minuto con el afilador.

Sesenta y nueve mil novecientos pesos. Envío gratis, pagas al recibir.
```

**VOZ_A4**
```
Para el que siempre anda con el taladro…

Un regalo útil: le devuelve el filo a sus brocas.

Lleva dos: uno para él y uno para regalar.

Sesenta y nueve mil novecientos pesos, o dos por ciento diecinueve mil novecientos. Pagas al recibir.
```

## PARTE B. Tomas de video (IA, en el navegador)

### Herramienta: Google Flow (cuenta Google AI Pro)
Usa **Flow** (labs.google/fx/tools/flow) con mi cuenta de Google AI Pro, que ya está iniciada en el navegador. Es el generador de video con Veo.
- Crea un **proyecto nuevo por grupo** (Cabezal, Afilador) para que el set se mantenga.
- Fija la **orientación vertical 9:16** y pide **3 resultados por prompt** si el selector lo permite.
- **Consistencia:** primero genera la imagen fija del set (con el generador de imágenes de Flow o Gemini) y úsala en el modo **"Frames to Video"** (imagen inicial) o **"Ingredients to Video"** (imágenes de referencia del producto y del taladro). Las tomas del afilador deben partir del mismo fotograma de referencia que las ya hechas.
- **Duración:** pide la más larga que ofrezca (normalmente 8 s) y yo recorto a 5–6 s. No hace falta audio: si Flow genera sonido, déjalo, lo descarto al montar.
- **Créditos:** usa **Veo en modo rápido (Fast)** para probar el encuadre y la consistencia, y la calidad máxima solo para las tomas que ya sirvan. Si te quedas sin créditos, avísame en vez de seguir con otra herramienta.
- **Descarga** cada toma en la mayor resolución disponible (idealmente 1080p) y renómbrala como indico abajo.

### Reglas generales de generación
- **Formato:** vertical 9:16, resolución 1080×1920 (si el generador solo da 720×1280, está bien). **5 a 8 s** por toma. Sin audio, sin música, sin voz (el audio lo pongo yo).
- **Consistencia:** para cada grupo, genera primero **una imagen fija** del set (taladro, banco, lámina, luz) y úsala como imagen inicial en todas las tomas de ese grupo (modo imagen a video). Misma semilla si el generador la permite. Genera **3 variantes** de cada toma y quédate con todas; yo escojo.
- **Producto fiel:** si el generador permite imágenes de referencia, usa las fotos reales del producto que te paso en Drive y pide que el producto se vea **idéntico** (afilador: cuerpo azul + piedra rosada; cabezal: metálico plateado con dos ruedas). Si el producto sale distinto al real, repite.
- **Set del cabezal:** taller con banco de madera, tablero de herramientas de fondo, luz cálida lateral, taladro inalámbrico **rojo sin marca visible**, lámina galvanizada plateada y teja de zinc.
- **Set del afilador:** el mismo de las tomas ya hechas que te adjunto (`IA_broca_sin_filo.mp4`, `IA_broca_afilada.mp4`): taladro inalámbrico verde oscuro y negro, banco de madera, lámina de acero gris, taller con herramientas desenfocadas. **Todas las tomas del afilador deben compartir ese mismo taladro, banco y luz.**
- **Prompt negativo** (si el generador lo admite): `text, subtitles, logos, brand names, watermark, extra fingers, deformed hands, floating tools, cartoon, CGI look, blur, low resolution, sparks (except where requested)`.
- **Nombres de archivo:** exactamente los que indico abajo, `.mp4`.

### B1. Tomas del CABEZAL (set cabezal)

**C1_teja_gotera.mp4** — C1, 6 s
```
Vertical 9:16, realistic handheld close-up. A corroded, cracked galvanized zinc roofing sheet on a roof, heavy rain falling, clear water drops dripping through a hole and crack in the sheet and falling into a bucket below. Wet metal texture, grey overcast light, soft rain ambience visual only. No text, no logos, no people, no watermark. 6 seconds, realistic motion.
```

**C1C3_cabezal_mesa.mp4** — C1 y C3, 5 s
```
Vertical 9:16 close-up product shot in a tidy workshop. A silver metal sheet-cutting drill attachment (two round cutting wheels, metal body, a stabilizing arm) resting on a wooden workbench, camera slowly pushes in and orbits slightly, warm side light, shallow depth of field, realistic metal reflections. No drill visible, no text, no logos, no brand marks, no watermark. 5 seconds.
```

**C1C3_cabezal_mandril.mp4** — C1 y C3, 6 s (opcional si no se usa el recorte)
```
Vertical 9:16 close-up, handheld. Bare hands without gloves screw the silver sheet-cutting attachment into the chuck of a red cordless drill and tighten the chuck, then the hands let go to show it mounted. Workshop with pegboard of tools blurred in the background, warm light. No text, no logos, no faces, no watermark. 6 seconds.
```

**C2_split_pulidora.mp4** — C2, 6 s (solo el lado de la pulidora; el lado del cabezal lo pongo yo)
```
Vertical 9:16 close-up. An angle grinder cutting a flat galvanized metal sheet on a workbench, a long shower of bright orange sparks flying, dust and slight burn discoloration on the cut edge. Gloved hands, safety glasses reflection, workshop background. No text, no logos, no brand marks, no faces, no watermark. 6 seconds.
```

**C2C4_drywall.mp4** — C2 y C4, 6 s
```
Vertical 9:16 close-up. A red cordless drill with a silver sheet-cutting attachment cuts a white drywall (plasterboard) panel on a workbench, a clean straight cut line, fine white dust only, no sparks. Hands steady, workshop background, warm light. No text, no logos, no faces, no watermark. 6 seconds.
```

**C2_aluminio_borde.mp4** — C2, 6 s
```
Vertical 9:16 close-up. A red cordless drill with a silver sheet-cutting attachment cuts a thin aluminium sheet in a smooth curve, then the camera moves to a macro close-up of the clean, unburned cut edge. No sparks, no smoke, no discoloration. Workshop, warm light. No text, no logos, no faces, no watermark. 6 seconds.
```

**C3_tijera_vs_cabezal.mp4** — C3, 6 s (pantalla dividida vertical, 2 mitades)
```
Vertical 9:16 split screen, two halves side by side, same corrugated galvanized sheet and same workbench. Left half: a person struggling with hand tin snips, the cut line goes crooked and the sheet bends. Right half: a red cordless drill with a silver sheet-cutting attachment cuts a perfectly straight, clean line. Synchronized timing, no text, no logos, no faces, no watermark. 6 seconds.
```

**C4_taller_entra_cabezal.mp4** — C4, 5 s
```
Vertical 9:16, handheld. In a cozy workshop, a red cordless drill rests on a bench; a hand enters the frame holding the silver sheet-cutting attachment and brings it toward the drill chuck. Warm light, pegboard of tools blurred behind. No text, no logos, no faces, no watermark. 5 seconds.
```

### B2. Tomas del AFILADOR (set afilador — MISMO taladro, banco y luz que las tomas adjuntas)

**A1_caja_brocas_gastadas.mp4** — A1, 5 s
```
Vertical 9:16 close-up, handheld. An open metal toolbox full of worn, dull, dark drill bits, some chipped, scattered over a wooden workbench in a workshop; a hand picks one up and shows its dull tip. Same workshop, warm side light as the reference. No text, no logos, no faces, no watermark. 5 seconds.
```

**A1_broca_sin_filo_larga.mp4** — A1 y A3, 6 s (rehacer la ya existente, más larga y con el mismo set)
```
Vertical 9:16 close-up, handheld. The same dark-green cordless drill with a dull, worn twist drill bit pressed against the same flat grey steel plate on the same wooden bench. The drill spins but the bit skids and wanders, leaving only shallow scratches; it does not penetrate. Gloved hand, same lighting. No text, no logos, no faces, no watermark. 6 seconds.
```

**A1A2_broca_afilada_perforando.mp4** — A1, A2 y A3, 6 s (rehacer sin humo exagerado y sin que la broca salga volando)
```
Vertical 9:16 close-up, handheld. The same dark-green cordless drill with the same twist drill bit, now freshly sharpened with bright cutting edges, pressed against the same grey steel plate on the same wooden bench. It bites at once and drills cleanly, a continuous curl of metal chips spirals out, no smoke. The drill is lifted straight up at the end showing a neat round hole; the bit stays in the chuck. Same lighting. No text, no logos, no faces, no watermark. 6 seconds.
```

**A2_punta_antes_despues.mp4** — A2, 6 s (macro, dos mitades en el tiempo)
```
Vertical 9:16 extreme macro of a twist drill bit tip. First 3 seconds: the tip is dull, rounded and dark. Cut to the next 3 seconds: the same tip now sharp with bright, defined cutting edges. Same lighting, shallow depth of field, neutral dark background. No text, no logos, no watermark.
```

**A3_split_mismo_set.mp4** — A3, 6 s (pantalla dividida vertical)
```
Vertical 9:16 split screen, two halves side by side, same grey steel plate, same dark-green cordless drill and same bench. Left half: the dull drill bit skids and wanders, faint scratch marks. Right half: the sharpened bit drills in cleanly with curling metal chips. Synchronized start, same lighting, no text, no logos, no faces, no watermark. 6 seconds.
```

**A4_taller_taladro_cajabrocas.mp4** — A4, 5 s
```
Vertical 9:16, handheld. A cozy workshop table with a dark-green cordless drill and an open case of neatly arranged drill bits, warm side light, tools on a pegboard blurred behind; slow push-in. No text, no logos, no faces, no watermark. 5 seconds.
```

**A4_dos_afiladores_mesa.mp4** — A4, 5 s (opcional; hay un clip real que lo cubre)
```
Vertical 9:16 close-up top-down. Two identical blue plastic drill-bit sharpeners with pink grinding stones lying side by side on a wooden table, the product looks exactly like the reference photo. Warm side light, shallow depth of field. No text, no logos, no brand marks, no watermark. 5 seconds.
```

### Lo que NO hay que generar
Estas ya las cubro con clips que tengo: montaje y afilado en primer plano del afilador (A1, A2), corte recto/curvo del cabezal en teja y lámina, y corte con borde limpio. No las generes.

## Entrega
1. Sube todo a Drive en la carpeta **`Anuncios/Entrega_IA/`** con dos subcarpetas: `voces/` (los 8 `.wav`) y `tomas/` (los `.mp4`).
2. Para cada toma, deja **3 variantes** con sufijos `_v1`, `_v2`, `_v3`.
3. Avísame con una lista: nombre de archivo, duración y si el producto salió fiel al real. Si una toma no la lograste después de 3 intentos, dímelo en vez de dejar una mala.
4. No uses ni subas videos de otros creadores. No publiques nada.
