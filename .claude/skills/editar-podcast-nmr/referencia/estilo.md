# Guía de estilo NMR (medida sobre el episodio publicado)

Medidas tomadas de `entregas/NMR_episodio_parte*_de_5.mp4` y
`entregas/shorts/*.mp4` (rama `claude/charming-dijkstra-qz6wir`). Coordenadas
en píxeles del cuadro de salida.

## Marca

| | |
| --- | --- |
| Verde acento | `#3BDC84` |
| Verde oscuro (cajas) | `#0B2A1C` |
| Fondo portada/panel | `#03140F` con brillo radial `#0B3A1F` |
| Tipografía | Montserrat (Black para titulares, ExtraBold para listas, Bold espaciada para etiquetas, SemiBold subtítulos, Medium textos) |
| Etiquetas | MAYÚSCULAS con mucho espaciado (tracking), en verde |
| Barra | línea verde que crece desde el centro bajo cada titular |

Fuentes estáticas en `fuentes/` (generadas del Montserrat variable de Google
Fonts, licencia OFL en `LICENCIA-FUENTES.txt`).

## Horizontal 1920×1080

| Elemento | Posición | Detalles |
| --- | --- | --- |
| Marca | barra 64–70 × 50–80, texto desde x=82, y=65 | "NETWORK MARKETING" blanco 88 % + "REAL" verde |
| Título clave | centro x=960, y=858; barra 180×6 en y=917; sub en y=953 | Black, halo oscuro difuso; sustituye al subtítulo |
| Dato centrado | velo negro ~65 %; etiqueta y=467, cifra y=605, barra 220×8 y=708 | cifra Black con contorno oscuro |
| Dato abajo | etiqueta y=727, cifra y=845, barra y=917, texto y=952 | sin velo |
| Pregunta | velo; texto y=605; barra 220×8 y=688 | Black ~1040 px de ancho |
| Panel | degradado verde desde la izquierda hasta x≈950; etiqueta x=150 y=348; titular 2 líneas desde y=390 | opcional línea ascendente animada |
| Lista | barra vertical x=108–113 desde y=220; etiqueta y=229; título y=262; ítems desde y=435 cada 70 px (nº en x=150, texto en x=226) | anteriores atenuados |
| Portada / cierre | "PODCAST" y=331, "NETWORK MARKETING" y=455, "REAL" y=575, barra 260×8 y=686, subtítulo y=772 | fundido a negro antes |
| Suscríbete | caja 110–750 × 880–984 + barra verde 10 px | "SUSCRÍBETE" + "Y ACTIVA LA CAMPANITA" verde |
| Subtítulos | centrados, base en y≈1022 | SemiBold, frase corta, sombra suave |

## Vertical 1080×1920 (shorts)

| Elemento | Posición |
| --- | --- |
| Marca | centrada, y=127 |
| Gancho | 2 líneas en y=360 (blanca) y y=462 (verde) sobre resplandor verde oscuro, primeros ~3 s |
| Título de sección | y=474, barra 130×7 en y=527 |
| Subtítulos | y=1345, Black mayúsculas, contorno negro, grupos de ≤ 3 palabras, palabra activa en verde |
| Cierre | "EPISODIO COMPLETO EN EL CANAL" y=1640 + barra 240×5 en y=1692, últimos 3,5 s |

## Entregas anteriores (referencia)

- Episodio: 1920×1080, 29,97 fps, H.264 ~5 Mb/s, AAC 48 kHz, en 5 partes de
  ~2 min (< 100 MB cada una para poder subirlas a GitHub).
- Shorts: 1080×1920, 35–52 s: `short1_misma_compania`, `short2_formula_del_exito`,
  `short3_el_miedo_nunca_se_va`.
- Miniatura: dos fotogramas de referencia (serio y sonriendo).
