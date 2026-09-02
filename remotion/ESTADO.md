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
