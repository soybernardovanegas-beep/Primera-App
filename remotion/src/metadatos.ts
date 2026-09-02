import {ALL_FORMATS, Input, UrlSource} from 'mediabunny';
import {staticFile} from 'remotion';

export type MetadatosVideo = {
  duracionEnSegundos: number;
  ancho: number;
  alto: number;
  fps: number;
};

/**
 * Convierte lo que el usuario escribe en `fuente` a una URL que el navegador
 * de Remotion puede cargar: una URL http(s) se usa tal cual, cualquier otra
 * cosa se busca dentro de `public/`.
 */
export const resolverFuente = (fuente: string): string => {
  if (/^(https?:|data:|blob:)/.test(fuente)) {
    return fuente;
  }

  return staticFile(fuente.replace(/^\/+/, ''));
};

/**
 * Cadencias estándar, con su valor exacto. Las de origen NTSC (29.97, 23.976,
 * 59.94) no son números redondos: son x1000/1001. Redondearlas a 30 o 24
 * parece inofensivo, pero acumula deriva — en un video de 27 minutos, usar 30
 * en lugar de 29.97 desplaza el final 1,6 s y desincroniza los subtítulos.
 */
const CADENCIAS = [24000 / 1001, 24, 25, 30000 / 1001, 30, 48, 50, 60000 / 1001, 60, 120];

/** Ajusta los fps medidos a la cadencia estándar más cercana, sin redondear. */
export const ajustarCadencia = (medidos: number): number => {
  // Hay que quedarse con la MÁS cercana, no con la primera dentro del margen:
  // 29.97 y 30 conviven en la lista y un material de 30 exactos no debe caer a 29.97.
  const cercana = CADENCIAS.reduce((mejor, c) =>
    Math.abs(c - medidos) < Math.abs(mejor - medidos) ? c : mejor,
  );

  return Math.abs(cercana - medidos) < 0.2 ? cercana : medidos;
};

/** H.264 solo admite dimensiones pares. */
export const aPar = (n: number): number => {
  const entero = Math.round(n);
  return entero % 2 === 0 ? entero : entero + 1;
};

/**
 * Lee duración, dimensiones y fps del video de origen. Se ejecuta dentro de
 * `calculateMetadata`, es decir en el navegador, tanto en el Studio como al
 * renderizar.
 */
export const leerMetadatos = async (src: string): Promise<MetadatosVideo> => {
  try {
    const entrada = new Input({source: new UrlSource(src), formats: ALL_FORMATS});

    const pista = await entrada.getPrimaryVideoTrack();
    const duracion =
      (await entrada.getDurationFromMetadata()) ?? (await entrada.computeDuration());

    if (!pista) {
      // Solo audio (o un contenedor sin pista de video): valores razonables.
      return {duracionEnSegundos: duracion, ancho: 1920, alto: 1080, fps: 30};
    }

    // Muestrea unos pocos paquetes para estimar los fps sin leer el archivo entero.
    const estadisticas = await pista.computePacketStats(100);

    return {
      duracionEnSegundos: duracion,
      ancho: pista.displayWidth,
      alto: pista.displayHeight,
      fps: ajustarCadencia(estadisticas.averagePacketRate) || 30,
    };
  } catch (error) {
    // Sin estos datos no se puede saber cuánto dura la composición, así que no
    // hay valor por defecto razonable: mejor fallar, pero diciendo qué hacer.
    const nombre = src.split('/').pop() ?? src;

    throw new Error(
      `No pude leer el video "${nombre}".\n` +
        '- Si es una ruta, el archivo tiene que estar dentro de la carpeta public/ ' +
        '(el script de render copia ahí los que estén fuera).\n' +
        '- Si acabas de clonar el proyecto y aún no hay ningún video, genera el de ' +
        'muestra con: npm run muestra\n' +
        `Detalle: ${error instanceof Error ? error.message : String(error)}`,
    );
  }
};
