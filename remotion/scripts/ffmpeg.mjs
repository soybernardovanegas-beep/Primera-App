// Localiza el ffmpeg/ffprobe que Remotion ya trae consigo, para no obligar a
// instalar ffmpeg en el sistema ni depender de `npx` (que en Windows es un
// .cmd y complica el spawn).
//
// Ojo: es una build reducida. No trae `lavfi` ni el muxer `s16le`, pero sí
// decodifica y escribe WAV, que es lo que necesita el análisis de audio.

import {execFileSync} from 'node:child_process';
import {existsSync, readdirSync} from 'node:fs';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const RAIZ = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const DIR_REMOTION = join(RAIZ, 'node_modules', '@remotion');

/** @param {'ffmpeg' | 'ffprobe'} cual */
export const rutaBinario = (cual) => {
  const sufijo = process.platform === 'win32' ? '.exe' : '';

  if (existsSync(DIR_REMOTION)) {
    const compositores = readdirSync(DIR_REMOTION).filter((d) => d.startsWith('compositor-'));

    for (const compositor of compositores) {
      const ruta = join(DIR_REMOTION, compositor, `${cual}${sufijo}`);
      if (existsSync(ruta)) {
        return ruta;
      }
    }
  }

  // Último recurso: el del sistema, si lo hay.
  return cual;
};

/**
 * Ejecuta ffmpeg y devuelve stderr (donde ffmpeg escribe la información).
 * @param {string[]} argumentos
 */
export const ffmpeg = (argumentos) => {
  try {
    return execFileSync(rutaBinario('ffmpeg'), ['-hide_banner', ...argumentos], {
      encoding: 'utf-8',
      stdio: ['ignore', 'pipe', 'pipe'],
      maxBuffer: 64 * 1024 * 1024,
    });
  } catch (error) {
    const detalle = error.stderr ?? error.message;
    throw new Error(`ffmpeg falló:\n${detalle}`);
  }
};

/** Devuelve el JSON de ffprobe con streams y formato. */
export const ffprobe = (archivo) => {
  const salida = execFileSync(
    rutaBinario('ffprobe'),
    [
      '-hide_banner',
      '-loglevel', 'error',
      '-print_format', 'json',
      '-show_format',
      '-show_streams',
      archivo,
    ],
    {encoding: 'utf-8', maxBuffer: 64 * 1024 * 1024},
  );

  return JSON.parse(salida);
};
