---
name: editar-podcast-nmr
description: Edita los videos del podcast Network Marketing Real (NMR) con su estilo de marca — corte de silencios, encuadre alterno, subtítulos, títulos clave, cifras, panel de ideas, portada, "Suscríbete", cierre, shorts verticales con subtítulos palabra a palabra y fotogramas para la miniatura. Úsalo siempre que Bernardo pida editar un episodio, un video del podcast, sacar shorts/reels de un episodio o preparar la miniatura.
---

# Edición del podcast Network Marketing Real

Reproduce la edición de los episodios ya publicados (ver `referencia/estilo.md`
para las medidas exactas). Todo se hace con **ffmpeg + libass en una sola
pasada**, con `scripts/nmr.py`. No hace falta Remotion ni GPU.

```
S=.claude/skills/editar-podcast-nmr/scripts/nmr.py
python3 $S analizar    --entrada VIDEO --json trabajo/cortes.json
python3 $S transcribir --entrada VIDEO --json trabajo/transcripcion.json   # o --srt subs.srt
python3 $S render      --plan trabajo/episodio.json --prueba 0-90           # validar estilo
python3 $S render      --plan trabajo/episodio.json --max-mb 95             # final (+ partes)
python3 $S render      --plan trabajo/short1.json                           # shorts
python3 $S fotogramas  --entrada VIDEO --salida entregas/miniatura --cada 20
```

## Flujo

1. **Conseguir el material.** Bernardo suele grabar un solo clip 4K 29,97 fps
   (cámara Sony, `C00xx.MP4`, audio PCM). Puede llegar por el repo, Google
   Drive (conector) o una ruta local. Si trae además una **pista de voz
   mejorada**, se usa con `"audio"` en el plan (debe estar sincronizada con el
   video; si no, ajusta `"audio_desfase"` en segundos).
2. **Analizar** (`analizar`). Imprime duración final, número de cortes y una
   tabla de cuántos cambios de encuadre saldrían con cada umbral. Si avisa de
   `moov` al final, ejecuta el `ffmpeg … +faststart` que propone antes de seguir.
   Si es 4K y el render va a ser lento, crea un intermedio **1440p** (nunca
   1080p: el encuadre cerrado necesita ≥ 2266 px de origen):
   `ffmpeg -i in.mp4 -vf scale=2560:1440 -c:v libx264 -preset veryfast -crf 18 -g 15 -c:a copy inter.mp4`
3. **Transcribir** (`transcribir`, faster-whisper `small`, español, tiempos por
   palabra). Escribe también `transcripcion.txt` (una frase por línea con su
   tiempo) — **léelo entero** antes de planificar. Si la red bloquea
   huggingface.co, pide a Bernardo el `.srt` (YouTube Studio / CapCut) y usa
   `--srt`, o que permita ese dominio en el entorno.
4. **Escribir el plan** `trabajo/episodio.json` (formato abajo) siguiendo las
   reglas editoriales. Todos los tiempos (`t`, `quitar`, `rango`) son **segundos
   del video original**, tal como aparecen en la transcripción: el script los
   traslada a la línea de tiempo ya cortada.
5. **Prueba de 60–90 s** con `--prueba 0-90` (segundos de la salida). Extrae
   fotogramas donde hay gráficos y **míralos** (Read sobre los PNG) antes del
   render final: textos que se salen, solapes con la cara, cortes bruscos.
6. **Render final** con `--max-mb 95` si se va a subir al repo (GitHub rechaza
   archivos > 100 MB; así se entregó el episodio anterior: `parte1_de_5` …).
7. **Shorts**: 3 por episodio, verticales, 35–55 s (ver reglas).
8. **Miniatura**: `fotogramas` y elegir 2 de referencia (una seria, una
   sonriendo), como `entregas/miniatura/referencia_seria.jpg`.
9. **Entregar**: copiar a `entregas/` (`NMR_episodio_parteN_de_M.mp4`,
   `shorts/shortN_tema.mp4`, `miniatura/`), commit y push a la rama de trabajo.

## Reglas editoriales (lo que se hizo en el episodio publicado)

**Estructura**
- **Cold open (primeros ~25–30 s)**: el gancho tal cual lo dice Bernardo, sin
  intro previa, con un gráfico cada 2–4 s: `titulo` para las frases paralelas
  ("Misma compañía", "Mismo producto", "Mismo plan" + sub "de compensación"),
  `dato` para cifras ("90 días"), `panel` para el concepto central ("La otra /
  Libertad financiera" con `grafica: true`) y `pregunta` para la pregunta
  retórica que abre el tema ("¿Qué las separa?").
- Justo después: **`portada`** de 3 s (fundido a negro + "PODCAST / NETWORK
  MARKETING REAL" + el tema del episodio como subtítulo). La voz sigue debajo.
- La **marca** (arriba a la izquierda) aparece sola al terminar la portada y se
  queda hasta el cierre.
- **Cuerpo**: subtítulos en todo momento (frases cortas, minúscula normal) +
  un `titulo` en cada frase clave, cada 20–40 s (2–4 palabras, la idea que
  resume lo que dice, p. ej. "Lo que no te define", "Verdadera libertad" con
  sub "en network marketing"). No dos gráficos a la vez.
- Si el episodio enumera ideas, **`lista`** al empezar cada una (5 s), con
  `items` = todas las ideas hasta la actual y `activo` = número de la actual;
  las anteriores salen atenuadas.
- Cifras/porcentajes que dice → `dato` (`posicion: "abajo"` si no quieres
  oscurecer el plano, como "99% / de las personas / cree que no va a llegar alto").
- **`suscribete`** 5 s cuando pide suscribirse (o en el último minuto si no lo pide).
- **`cierre`** de 4 s al final ("Nos vemos en el próximo episodio") con
  fundido a negro.

**Corte**
- Solo se quitan silencios (`analizar`). Además, en `quitar` van los tramos
  que Bernardo repite o en los que se equivoca y vuelve a empezar (búscalos en
  la transcripción: misma frase dos veces seguidas). No hagas otros cortes de
  contenido sin preguntar.
- Encuadre alterno abierto/cerrado (`niveles: [1.0, 1.18]`) que **solo cambia
  en pausas reales** (`cambio_minimo: 0.8` s). Si el análisis da más de un
  cambio cada ~8 s, sube `cambio_minimo` a 1.0–1.5.

**Shorts (3 por episodio)**
- Momentos autocontenidos de 35–55 s con una idea fuerte: el gancho del
  episodio, la fórmula/regla principal y una frase emocional ("El miedo nunca
  se va"). Nombre: `shortN_tema_en_snake_case.mp4`.
- `gancho`: 2 líneas (blanca + verde) los primeros 3 s, que resuman la
  tensión ("Misma compañía / Resultados opuestos").
- `titulo` arriba cuando cambia de idea; subtítulos palabra a palabra siempre;
  "Episodio completo en el canal" los últimos 3,5 s (automático).
- Con `rango` puedes unir varios trozos del original: `[[a,b],[c,d]]`.

## Formato del plan

```json
{
  "fuente": "../material/C0093.MP4",
  "audio": null,
  "cortes": "cortes.json",
  "transcripcion": "transcripcion.json",
  "salida": "../entregas/NMR_episodio.mp4",
  "encuadre": {"niveles": [1.0, 1.18], "cambio_minimo": 0.8, "centro": [0.5, 0.42]},
  "quitar": [[312.4, 318.9]],
  "subtitulos": true,
  "graficos": [
    {"tipo": "titulo",   "t": 5.2,  "dur": 2.2, "texto": "Mismo plan", "sub": "de compensación"},
    {"tipo": "dato",     "t": 9.0,  "dur": 3,   "arriba": "Renuncia en los primeros", "valor": "90 días"},
    {"tipo": "panel",    "t": 12.0, "dur": 3.5, "arriba": "La otra", "texto": "Libertad financiera", "grafica": true},
    {"tipo": "pregunta", "t": 20.0, "dur": 3,   "texto": "¿Qué las separa?"},
    {"tipo": "portada",  "t": 28.0, "dur": 3,   "subtitulo": "6 ideas para crecer en network marketing"},
    {"tipo": "lista",    "t": 75.0, "dur": 5,   "arriba": "6 ideas", "titulo": "Para crecer en\nnetwork marketing",
                         "items": ["El origen no te define", "Enfoque en lo que controlas"], "activo": 2},
    {"tipo": "dato",     "t": 50.0, "dur": 3,   "posicion": "abajo", "arriba": "De las personas", "valor": "99%", "abajo": "cree que no va a llegar alto"},
    {"tipo": "suscribete", "t": 1290, "dur": 5},
    {"tipo": "cierre", "dur": 4}
  ]
}
```

- Rutas relativas al propio JSON. `dur` en segundos de pantalla.
- Short: `"formato": "vertical"`, `"rango"`, `"gancho": ["línea 1", "línea 2"]`,
  `"encuadre": {"niveles": [1.0, 1.12], "centro": [0.5, 0.45]}`; en vertical
  solo existe el gráfico `titulo`. `"final"` cambia el texto de cierre.
- `"color"` sustituye la corrección de color (por defecto
  `eq=contrast=1.05:saturation=1.07:gamma=0.98,vignette=angle=PI/5`; `""` la quita).
- `"marca": {"desde": t}` fuerza cuándo aparece la marca; `false` la quita.
- Ejemplos completos en `ejemplos/`.

## Lecciones técnicas (no repetir errores)

- **29,97 ≠ 30.** El script usa la fracción exacta de ffprobe y ajusta cada
  tramo a fotogramas exactos; no redondees fps a mano.
- **`moov` al final del MP4** hace que todo parezca colgado: usa `+faststart`.
- El ruido de fondo se mide en cada archivo (percentil 10 + 8 dB); no
  calibres el umbral a mano salvo que el análisis corte de más/menos.
- Rampa de audio de 15 ms en cada empalme (si no, chasquidos) y `loudnorm`
  a −14 LUFS (estándar YouTube).
- Nada de zoom continuo (`zoompan`): cuesta 1,6× y no aporta; lo que tapa los
  cortes es el cambio de encuadre.
- Los tamaños de letra están calibrados midiendo el episodio publicado; si
  añades un gráfico nuevo, mide su ancho en un fotograma del original
  (filtro `bbox`) en vez de estimarlo — libass y CSS no miden igual.
- Antes de renderizar todo, `--prueba`; un render de 25 min a 1080p desde
  1440p tarda ~30–45 min con 4 núcleos (`--preset veryfast` para ir rápido).
