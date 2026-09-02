# Estado del proyecto de edición — video 2 (NMR)

Documento para retomar el trabajo sin tener que reconstruir el contexto.
Actualízalo cuando cambie algo importante.

## Material

Un solo clip, en `D:\videos NMR\video 2\C0093.MP4`:

| | |
| --- | --- |
| Resolución | 3840x2160 (4K UHD, horizontal 16:9) |
| Cadencia | 29.970 fps (NTSC — **no** son 30) |
| Duración | 26:45 (1605 s ≈ 48.102 fotogramas) |
| Video | H.264 |
| Audio | PCM s16be, 2 canales, 48 kHz |
| Tamaño | ~12-30 GB (por eso se enlaza, nunca se copia) |

El proyecto está clonado en `D:\videos NMR\edicion` — **mismo volumen que el
video a propósito**, para que el enlace duro funcione y no haya que copiar
decenas de GB.

## Decisiones tomadas

1. **Salida horizontal 1080p** (1920x1080), no 4K. A 4K el render de 48.102
   fotogramas llevaría entre 4 y 13 horas.
2. **Solo quitar silencios.** Sin recorte de contenido, sin juicio editorial
   sobre qué sobra.
3. **Encuadre alterno** para ocultar los jump-cuts. Es gratis: con origen 4K y
   salida 1080p se puede cerrar el plano hasta 2x sin perder nitidez.

## Análisis del audio (medido sobre el archivo real)

- Ruido de fondo: **-35.3 dBFS**. Umbral adaptativo efectivo: **-27.3 dBFS**.
- Resultado: 26:45 -> **23:11**, se recortan 3:33 (13,3 %).
- **321 tramos / 320 empalmes: un corte cada 4,3 s.**
- Huecos eliminados: mín 0,20 s · media 0,66 s · máx 3,22 s.

El mínimo de 0,20 s es correcto, no un fallo: solo se cortan huecos > 0,6 s y
se devuelven 0,15 + 0,25 s de aire, así que `0,6 - 0,4 = 0,2`.

Nota: una medición previa con otra herramienta dio un suelo de ruido de
-30,7 dB y un barrido que a -23 dB daba 151 cortes. Las dos mediciones usan
métodos distintos (aquí: RMS en ventanas de 20 ms sobre mono 16 kHz). La
diferencia importa: 320 cortes es una edición bastante más picada que 151.

## Qué está construido y verificado

- Detección de silencios con umbral adaptativo al ruido real de la grabación.
- Composición `SinSilencios`: monta los tramos con rampa de audio en cada
  empalme (sin ella se oye un chasquido en cada uno de los 320 cortes).
- Encuadre alterno que **solo cambia en cortes que eliminaron una pausa real**
  (`--cambio-encuadre`, 0,8 s por defecto).
- `--frames a-b` para validar el estilo en 90 s en vez de en horas.
- Cadencia NTSC exacta y enlace duro en vez de copia.

## Cuello de botella del hardware (importante)

El primer intento de render falló: `delayRender()` agotó los 28 s esperando el
**primer** fotograma.

Causa: el original es un 4K H.264 de ~12 GB y `D:` es un disco **mecánico**
(Seagate ST1000LM035, 5400 rpm). Cada salto obliga a decodificar desde el
keyframe anterior, y con 321 tramos el render salta constantemente.
(`C:` es SSD NVMe pero solo tiene ~6 GB libres, así que no es alternativa.)

**Causa raíz real (encontrada después):** el átomo `moov` del MP4 estaba AL
FINAL del archivo. Remotion necesita el `moov` para decodificar cualquier
fotograma, incluido el primero, así que tenía que recorrer los 12 GB enteros
desde el HDD antes del frame 0. Por eso fallaba en `time=0.16` y no más
adelante — el diagnóstico inicial ("saltos en disco lento") era incompleto.

Se arregla sin recodificar, en segundos:

```bash
ffmpeg -i entrada.mp4 -c copy -movflags +faststart salida.mp4
```

El proyecto ahora **avisa solo** de esto antes de analizar o renderizar
(`scripts/mp4.mjs`), porque sin el aviso el síntoma es un timeout sin causa
aparente tras minutos de espera.

Aparte de eso, editar sobre un **intermedio** con keyframes densos sigue
mereciendo la pena por velocidad de render. Pero el
intermedio **no puede ser 1080p**: la salida es 1080p y el encuadre alterno
cierra el plano un 18 %, así que necesita 1920 x 1.18 = **2266 px** de origen.
Con un proxy 1080p los tramos cerrados se verían blandos y los abiertos
nítidos, alternando — peor que los jump-cuts que se querían tapar.

Intermedio correcto: **2560x1440** (permite hasta 1.33x sin pérdida).

```bash
ffmpeg -i "D:/videos NMR/video 2/C0093.MP4" \
  -vf scale=2560:1440 -c:v libx264 -preset veryfast -crf 18 -g 15 \
  -c:a copy \
  "D:/videos NMR/edicion/remotion/public/entradas/C0093_1440.mp4"
```

- `-g 15` (keyframe cada 0,5 s) hace los saltos mucho más baratos.
- `-c:a copy` conserva el PCM original, así el análisis de silencios da
  exactamente los mismos números que sobre el archivo original.

**Tamaño real: ~8 GB** (38 Mbps de video + 0,3 GB de PCM), no los ~3 GB que
se estimaron al principio. Hace falta espacio en `D:` para original (12 GB) +
intermedio (8 GB) + salida (~1,5 GB) ≈ **21,5 GB**.

Que pese 8 GB no invalida el intermedio: lo que arregla el cuello de botella
no es el tamaño sino el coste de cada salto, que baja ~9x (60 fotogramas 4K
por salto pasan a 15 fotogramas 1440p). El caudal nunca fue el problema: a
38 Mbps con `--concurrencia 2` se piden 9,5 MB/s y el disco da 80-100 MB/s.

### Verificar cuando termine el transcode

1. El análisis debe seguir leyendo **29.970 fps**. Si dice 30, algo alteró la
   cadencia y los subtítulos derivarían 1,6 s.
2. El análisis debe reproducir **321 tramos y 3:33 recortados**. Si difiere,
   el audio no se copió intacto.

Al renderizar sobre disco mecánico: `--concurrencia 2` o `3` (más procesos
compiten por el cabezal y va más lento) y `--timeout 120000`.

## Coste de render: Remotion vs ffmpeg (medido)

En el equipo del usuario Remotion rinde **~1 fotograma/segundo** (Chrome
headless + compositor por software, sin GPU, disco mecánico): 41.720
fotogramas ≈ **11-12 horas**.

Se midió la alternativa en ffmpeg con **321 tramos reales**, 720p, 4 núcleos:

| Montaje | Tiempo | Ritmo |
| --- | --- | --- |
| `filter_complex` con deriva (`zoompan`) | 35,6 s | 1,18x tiempo real |
| `filter_complex` sin deriva | 22,6 s | 1,86x tiempo real |
| Trocear y concatenar | 36,3 s | — |

Y escala **linealmente**: 464 ms/tramo con 60 tramos, 403 ms/tramo con 321.
No se degrada con muchos tramos, así que trocear-y-concatenar no aporta nada
sobre la pasada única (se comprobó porque era el riesgo esperado).

Extrapolado a 1080p desde el intermedio 1440p: **~30-45 min sin deriva**,
~50-70 min con ella. Es decir, 15-20x más rápido que Remotion.

**La deriva del zoom (`zoompan`) cuesta 1,6x** y es el elemento que menos
aporta: lo que disimula los cortes es el punch alterno, no la deriva. En la
ruta ffmpeg conviene renunciar a ella.

## Pendiente

1. **Renderizar la prueba de 90 s y juzgarla.** Es el siguiente paso.
   Decidir ahí: `--punch`, `--cambio-encuadre`, `--punto-x/y`, y si 320 cortes
   es demasiado picado (subir `--margenRuido` lo hace más conservador).
2. **Subtítulos.** Sin resolver y sin probar. Requieren transcripción
   (Whisper). No prometido: falta verificar descarga del modelo y cuánto
   tarda sobre 27 minutos de audio con solo ~15 dB de separación voz/ruido.
3. **Render final** de los 23 minutos, ya con los parámetros validados.

## Comandos

```bash
cd D:\videos NMR\edicion\remotion
git pull

# Analizar (imprime la tabla de cambios de plano por umbral)
npm run silencios -- --entrada "D:/videos NMR/video 2/C0093.MP4" --json analisis/cortes.json

# Prueba de 90 s
npm run render -- --cortes analisis/cortes.json --ancho 1920 --alto 1080 \
  --punch 0.18 --cambio-encuadre 0.8 --frames 0-2700 --salida salidas/prueba90.mp4

# Render final (sin --frames). Lanzarlo cuando la prueba convenza.
npm run render -- --cortes analisis/cortes.json --ancho 1920 --alto 1080 \
  --punch 0.18 --cambio-encuadre 0.8 --salida salidas/video2-final.mp4
```

Conviene **commitear `analisis/cortes.json`**: son los tramos exactos, y así
cualquier sesión puede analizarlos sin volver a procesar el archivo.
