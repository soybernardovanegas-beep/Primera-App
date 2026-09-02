# Edición de video automatizada con Remotion

Proyecto independiente de la app Flutter. Sirve para **editar videos por
código**: recortar, acelerar, silenciar, poner intro, marca de agua,
subtítulos, fundidos y unir clips, todo repetible desde la línea de comandos.

Remotion renderiza el video dibujando cada frame en un Chromium headless y
codificándolo con su propio ffmpeg: no hace falta instalar ffmpeg en el
sistema.

## Instalación

```bash
cd remotion
npm install
```

La primera vez, genera el video de muestra para poder probar sin aportar
material propio:

```bash
npm run muestra     # crea public/entradas/muestra.mp4 (8 s, 1280x720)
```

## Editor visual

```bash
npm run studio
```

Abre `http://localhost:3000`. En el panel derecho puedes cambiar cualquier
prop (recorte, título, subtítulos…) y ver el resultado al instante. El botón
de render de la interfaz exporta el archivo final.

## Render automático

Todo se maneja con `scripts/render.mjs`:

```bash
npm run render -- --ayuda
```

Ejemplos:

```bash
# Recortar del segundo 5 al 42, con intro, marca de agua y fundidos
npm run render -- --entrada "D:/videos NMR/video 2.mp4" \
  --desde 5 --hasta 42 --titulo "Video 2" --subtitulo "NMR" \
  --marca "@nmr" --fundidos 0.6

# Acelerar al doble y quitar el audio
npm run render -- --entrada entradas/muestra.mp4 --velocidad 2 --sin-audio

# Reencuadrar a vertical 1080x1920 recortando para llenar el cuadro
npm run render -- --entrada entradas/muestra.mp4 --ancho 1080 --alto 1920 --ajuste cubrir

# Toda la configuración desde un JSON
npm run render -- --props ejemplos/edicion.json --salida salidas/final.mp4

# Unir varios clips
npm run render -- --composicion UnirClips --props ejemplos/union.json
```

El video de entrada puede estar en cualquier parte del disco: si está fuera
de `public/`, el script lo copia a `public/entradas/` (Remotion solo puede
leer archivos servidos desde ahí). También acepta URLs `http(s)`.

Las salidas van a `salidas/` por defecto.

## Cómo está organizado

| Ruta | Qué es |
| --- | --- |
| `src/Root.tsx` | Registro de las composiciones y sus valores por defecto |
| `src/esquemas.ts` | Esquemas zod de las props: definen también el formulario del Studio |
| `src/metadatos.ts` | Lee duración, tamaño y fps del video de origen (mediabunny) |
| `src/composiciones/EditarVideo.tsx` | Edición de un video: recorte, velocidad, intro, subtítulos, marca, fundidos |
| `src/composiciones/UnirClips.tsx` | Concatena varios clips con fundido entre ellos |
| `src/composiciones/Prueba.tsx` | Animación sin dependencias, para comprobar que el render funciona |
| `scripts/render.mjs` | CLI de render programático |
| `scripts/navegador.mjs` | Localiza el Chromium a usar |
| `ejemplos/` | JSON de ejemplo con props completas |
| `public/entradas/` | Videos de origen (no se versionan) |
| `salidas/` | Resultados (no se versionan) |

El tamaño, los fps y la duración de la composición **no están fijados a
mano**: `calculateMetadata` lee el archivo de origen y los deduce del recorte
pedido. Por eso `--ancho`, `--alto` y `--fps` son opcionales.

## Props de `EditarVideo`

| Prop | Tipo | Qué hace |
| --- | --- | --- |
| `fuente` | string | Archivo dentro de `public/` o URL http(s) |
| `recorteDesde` / `recorteHasta` | número / null | Recorte en segundos; `null` = hasta el final |
| `velocidad` | número | 1 normal, 2 doble, 0.5 cámara lenta |
| `volumen`, `silenciar` | número, bool | Audio |
| `fps`, `ancho`, `alto` | número / null | `null` = tomar los del original |
| `ajuste` | `contener` \| `cubrir` | Barras negras o recorte al reencuadrar |
| `intro` | objeto | `titulo`, `subtitulo`, `duracion`, colores. Título vacío = sin intro |
| `marcaDeAgua` | objeto | `texto`, `imagen`, `posicion`, `opacidad`, `tamano`, `color` |
| `subtitulos` | lista | `[{desde, hasta, texto}]` en segundos del video **ya recortado** |
| `fundidoEntrada` / `fundidoSalida` | número | Fundido desde/hacia negro, en segundos |

## El navegador que usa el render

Remotion normalmente descarga su propio Chrome Headless Shell desde
`remotion.media` la primera vez. En un equipo normal con internet eso pasa
solo y no hay que hacer nada.

Si esa descarga está bloqueada por la red, `scripts/navegador.mjs` busca un
Chromium ya instalado (Playwright, Chrome del sistema…) y lo usa en su lugar.
También puedes forzarlo:

```bash
export REMOTION_BROWSER_EXECUTABLE=/ruta/a/chrome
```

## Licencia de Remotion

Remotion es gratis para personas individuales y para empresas de hasta 3
personas. A partir de ahí requiere una licencia de empresa:
https://remotion.dev/license
