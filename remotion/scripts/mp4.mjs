// Comprobación de la estructura de un MP4, para detectar el problema que más
// tiempo cuesta diagnosticar al editar material de cámara.
//
// Un MP4 tiene el índice (`moov`) al principio o al final. Muchas cámaras y
// ffmpeg sin `+faststart` lo escriben AL FINAL. Remotion necesita el `moov`
// para decodificar cualquier fotograma, incluido el primero, así que con un
// archivo grande en un disco lento eso obliga a recorrer el archivo entero
// antes del primer frame: el render muere por timeout sin explicar por qué.

import {closeSync, openSync, readSync, statSync} from 'node:fs';

/**
 * Lee las cajas de primer nivel del MP4.
 * @returns {{tipo: string, offset: number, tamano: number}[]}
 */
export const atomosDeMp4 = (archivo) => {
  const fd = openSync(archivo, 'r');

  try {
    const total = statSync(archivo).size;
    const cabecera = Buffer.alloc(16);
    const atomos = [];
    let offset = 0;

    while (offset < total && atomos.length < 50) {
      const leidos = readSync(fd, cabecera, 0, 16, offset);
      if (leidos < 8) {
        break;
      }

      let tamano = cabecera.readUInt32BE(0);
      const tipo = cabecera.toString('ascii', 4, 8);

      // tamaño 1 significa que el real va en 64 bits justo después: los
      // archivos de más de 4 GB (como un 4K de 27 minutos) siempre lo usan.
      if (tamano === 1) {
        tamano = Number(cabecera.readBigUInt64BE(8));
      } else if (tamano === 0) {
        tamano = total - offset; // se extiende hasta el final
      }

      if (tamano < 8) {
        break;
      }

      atomos.push({tipo, offset, tamano});
      offset += tamano;
    }

    return atomos;
  } finally {
    closeSync(fd);
  }
};

/**
 * ¿Está el índice al principio? Devuelve null si el archivo no es un MP4
 * reconocible (por ejemplo un MKV), donde esta comprobación no aplica.
 */
export const comprobarFaststart = (archivo) => {
  const atomos = atomosDeMp4(archivo);

  const moov = atomos.find((a) => a.tipo === 'moov');
  const mdat = atomos.find((a) => a.tipo === 'mdat');

  if (!moov || !mdat) {
    return null;
  }

  return {
    listo: moov.offset < mdat.offset,
    offsetMoov: moov.offset,
    offsetMdat: mdat.offset,
    // Lo que hay que atravesar antes de poder decodificar el primer fotograma.
    bytesAntesDelIndice: moov.offset,
  };
};

/** Aviso listo para imprimir, o null si todo está bien. */
export const avisoFaststart = (archivo) => {
  let estado;

  try {
    estado = comprobarFaststart(archivo);
  } catch {
    return null; // no es un MP4 legible: que falle más adelante con su error
  }

  if (!estado || estado.listo) {
    return null;
  }

  const gb = (estado.bytesAntesDelIndice / 1e9).toFixed(1);

  return [
    '',
    `AVISO: el índice (moov) de este MP4 está AL FINAL, tras ${gb} GB de datos.`,
    'Remotion necesita el moov para decodificar cualquier fotograma, así que',
    'tendrá que recorrer todo el archivo antes del primero. En un disco lento',
    'eso hace que el render muera por timeout sin explicar la causa.',
    '',
    'Arréglalo sin recodificar (segundos, sin pérdida de calidad):',
    `  ffmpeg -i "${archivo}" -c copy -movflags +faststart "<salida>.mp4"`,
    '',
  ].join('\n');
};
