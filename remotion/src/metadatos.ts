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
      fps: Math.round(estadisticas.averagePacketRate) || 30,
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
