import {zColor, zTextarea} from '@remotion/zod-types';
import {z} from 'zod';

/** Dónde se coloca la marca de agua dentro del cuadro. */
export const POSICIONES = [
  'arriba-izquierda',
  'arriba-derecha',
  'abajo-izquierda',
  'abajo-derecha',
  'centro',
] as const;

export const esquemaSubtitulo = z.object({
  /** Segundo (del video ya recortado) en el que aparece. */
  desde: z.number().min(0),
  /** Segundo en el que desaparece. */
  hasta: z.number().min(0),
  texto: zTextarea(),
});

export const esquemaMarcaDeAgua = z.object({
  /** Texto de la marca. Vacío = sin marca de texto. */
  texto: z.string(),
  /** Archivo dentro de `public/` (p. ej. `logo.png`). Vacío = sin logo. */
  imagen: z.string(),
  posicion: z.enum(POSICIONES),
  opacidad: z.number().min(0).max(1),
  /** Tamaño de fuente del texto, en px sobre el alto del video. */
  tamano: z.number().min(1),
  color: zColor(),
});

export const esquemaIntro = z.object({
  /** Vacío = sin intro. */
  titulo: z.string(),
  subtitulo: z.string(),
  /** Duración en segundos. 0 = sin intro. */
  duracion: z.number().min(0),
  colorFondo: zColor(),
  colorTexto: zColor(),
});

export const esquemaEditarVideo = z.object({
  /** Archivo dentro de `public/` (p. ej. `entradas/video2.mp4`) o una URL http(s). */
  fuente: z.string(),
  /** Recorte: segundo inicial. */
  recorteDesde: z.number().min(0),
  /** Recorte: segundo final. null = hasta el final del original. */
  recorteHasta: z.number().min(0).nullable(),
  /** 1 = normal, 2 = el doble de rápido, 0.5 = cámara lenta. */
  velocidad: z.number().min(0.1).max(8),
  volumen: z.number().min(0).max(2),
  silenciar: z.boolean(),
  /** null = usar los del video original. */
  fps: z.number().min(1).max(120).nullable(),
  ancho: z.number().min(2).nullable(),
  alto: z.number().min(2).nullable(),
  /** `contener` deja barras negras; `cubrir` recorta para llenar el cuadro. */
  ajuste: z.enum(['contener', 'cubrir']),
  colorFondo: zColor(),
  intro: esquemaIntro,
  marcaDeAgua: esquemaMarcaDeAgua,
  subtitulos: z.array(esquemaSubtitulo),
  /** Fundido desde negro al empezar, en segundos. */
  fundidoEntrada: z.number().min(0),
  /** Fundido a negro al terminar, en segundos. */
  fundidoSalida: z.number().min(0),
});

export const esquemaClip = z.object({
  fuente: z.string(),
  desde: z.number().min(0),
  hasta: z.number().min(0).nullable(),
  silenciar: z.boolean(),
});

export const esquemaUnirClips = z.object({
  clips: z.array(esquemaClip),
  fps: z.number().min(1).max(120),
  ancho: z.number().min(2),
  alto: z.number().min(2),
  ajuste: z.enum(['contener', 'cubrir']),
  colorFondo: zColor(),
  /** Fundido a negro entre clip y clip, en segundos. 0 = corte seco. */
  fundidoEntreClips: z.number().min(0),
});

export const esquemaSegmento = z.object({
  /** Segundo del video ORIGINAL en el que empieza el tramo que se conserva. */
  desde: z.number().min(0),
  hasta: z.number().min(0),
});

export const esquemaSinSilencios = z.object({
  fuente: z.string(),
  /** Tramos a conservar, en tiempo del original. Los genera scripts/silencios.mjs. */
  segmentos: z.array(esquemaSegmento),
  fps: z.number().min(1).max(120),
  ancho: z.number().min(2),
  alto: z.number().min(2),
  ajuste: z.enum(['contener', 'cubrir']),
  colorFondo: zColor(),
  volumen: z.number().min(0).max(2),
  /**
   * Fundido de audio a cada lado de cada corte, en segundos. Sin esto, cortar
   * una onda por la mitad produce un chasquido audible en cada empalme.
   */
  rampaAudio: z.number().min(0).max(1),
  /** Zoom lento que alterna de sentido en cada tramo: disimula los saltos de corte. */
  zoomSutil: z.boolean(),
  /** Cuánto amplía el zoom. 0.03 = 3 %. Por encima de 0.08 se nota y marea. */
  intensidadZoom: z.number().min(0).max(0.3),
  marcaDeAgua: esquemaMarcaDeAgua,
  /** En segundos del video YA cortado. */
  subtitulos: z.array(esquemaSubtitulo),
  fundidoEntrada: z.number().min(0),
  fundidoSalida: z.number().min(0),
});

export type PropsSinSilencios = z.infer<typeof esquemaSinSilencios>;
export type Segmento = z.infer<typeof esquemaSegmento>;
export type PropsEditarVideo = z.infer<typeof esquemaEditarVideo>;
export type PropsUnirClips = z.infer<typeof esquemaUnirClips>;
export type Subtitulo = z.infer<typeof esquemaSubtitulo>;
export type MarcaDeAguaProps = z.infer<typeof esquemaMarcaDeAgua>;
export type IntroProps = z.infer<typeof esquemaIntro>;
