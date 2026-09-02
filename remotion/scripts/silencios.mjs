#!/usr/bin/env node
// Detecta qué tramos del video tienen voz y cuáles son silencio, y produce la
// lista de segmentos que hay que conservar.
//
//   node scripts/silencios.mjs --entrada "D:/videos NMR/video 2/C0093.MP4" --json analisis/cortes.json
//
// El ffmpeg de Remotion es una build reducida (sin `lavfi` ni `silencedetect`
// utilizable), así que el análisis se hace aquí: se extrae el audio a WAV y se
// mide la energía por ventanas.

import {mkdirSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {ffmpeg, ffprobe} from './ffmpeg.mjs';

/** Milisegundos que dura cada ventana de análisis. */
const VENTANA_MS = 20;
const TASA = 16000;

export const OPCIONES_POR_DEFECTO = {
  /** Umbral absoluto en dBFS. Por debajo de esto se considera silencio. */
  umbral: -35,
  /** Margen sobre el ruido de fondo medido, en dB. */
  margenRuido: 8,
  /** Solo se recortan los silencios más largos que esto (segundos). */
  pausaMaxima: 0.6,
  /** Aire que se deja antes y después de cada tramo con voz (segundos). */
  margenAntes: 0.15,
  margenDespues: 0.25,
  /** Los tramos más cortos que esto se descartan (evita cortes epilépticos). */
  minimoSegmento: 0.35,
};

/** Extrae el audio a WAV mono 16 kHz y devuelve las muestras como Int16Array. */
export const extraerAudio = (entrada) => {
  const temporal = join(tmpdir(), `remotion-audio-${process.pid}.wav`);

  ffmpeg([
    '-loglevel', 'error',
    '-i', entrada,
    '-vn',
    '-acodec', 'pcm_s16le',
    '-ac', '1',
    '-ar', String(TASA),
    '-y', temporal,
  ]);

  const bruto = readFileSync(temporal);
  rmSync(temporal, {force: true});

  // Localizar el chunk `data`: no siempre está en el offset 44 (puede haber
  // chunks LIST/INFO antes).
  let posicion = 12;
  while (posicion < bruto.length - 8) {
    const id = bruto.toString('ascii', posicion, posicion + 4);
    const tamano = bruto.readUInt32LE(posicion + 4);

    if (id === 'data') {
      const inicio = posicion + 8;
      const fin = Math.min(inicio + tamano, bruto.length);
      const bytes = fin - inicio - ((fin - inicio) % 2);
      return new Int16Array(bruto.buffer, bruto.byteOffset + inicio, bytes / 2);
    }

    posicion += 8 + tamano + (tamano % 2);
  }

  throw new Error('El WAV extraído no tiene chunk `data`. ¿El video tiene pista de audio?');
};

/** Energía en dBFS de cada ventana. */
export const energiaPorVentana = (muestras) => {
  const porVentana = Math.round((TASA * VENTANA_MS) / 1000);
  const total = Math.floor(muestras.length / porVentana);
  const dB = new Float32Array(total);

  for (let v = 0; v < total; v++) {
    let suma = 0;
    const desde = v * porVentana;

    for (let i = desde; i < desde + porVentana; i++) {
      const s = muestras[i] / 32768;
      suma += s * s;
    }

    const rms = Math.sqrt(suma / porVentana);
    // -100 dB como suelo, para no obtener -Infinity en silencio digital.
    dB[v] = rms > 0 ? Math.max(-100, 20 * Math.log10(rms)) : -100;
  }

  return dB;
};

/** Ruido de fondo: percentil 10 de la energía, más robusto que el mínimo. */
export const ruidoDeFondo = (dB) => {
  const ordenado = Float32Array.from(dB).sort();
  return ordenado[Math.floor(ordenado.length * 0.1)] ?? -100;
};

/**
 * Convierte la energía por ventana en la lista de tramos a conservar.
 * @returns {{desde: number, hasta: number}[]} en segundos
 */
export const detectarSegmentos = (dB, opciones = {}) => {
  const op = {...OPCIONES_POR_DEFECTO, ...opciones};
  const segundosPorVentana = VENTANA_MS / 1000;

  const ruido = ruidoDeFondo(dB);
  // Un umbral fijo falla con grabaciones muy limpias o muy ruidosas; se toma
  // el más exigente entre el absoluto y el relativo al ruido medido.
  const umbral = Math.max(op.umbral, ruido + op.margenRuido);

  // 1. Ventanas con voz.
  const bruto = [];
  let inicio = null;

  for (let v = 0; v < dB.length; v++) {
    const hayVoz = dB[v] > umbral;

    if (hayVoz && inicio === null) {
      inicio = v;
    } else if (!hayVoz && inicio !== null) {
      bruto.push({desde: inicio * segundosPorVentana, hasta: v * segundosPorVentana});
      inicio = null;
    }
  }

  if (inicio !== null) {
    bruto.push({desde: inicio * segundosPorVentana, hasta: dB.length * segundosPorVentana});
  }

  // 2. Unir tramos separados por pausas cortas: una pausa natural entre frases
  //    no se recorta, solo los silencios largos.
  const unidos = [];
  for (const tramo of bruto) {
    const anterior = unidos[unidos.length - 1];

    if (anterior && tramo.desde - anterior.hasta < op.pausaMaxima) {
      anterior.hasta = tramo.hasta;
    } else {
      unidos.push({...tramo});
    }
  }

  // 3. Dar aire a cada lado para no cortar el ataque ni la caída de la voz.
  const duracionTotal = dB.length * segundosPorVentana;
  const conMargen = unidos.map((t) => ({
    desde: Math.max(0, t.desde - op.margenAntes),
    hasta: Math.min(duracionTotal, t.hasta + op.margenDespues),
  }));

  // 4. El margen puede haber solapado tramos: volver a unirlos.
  const finales = [];
  for (const tramo of conMargen) {
    const anterior = finales[finales.length - 1];

    if (anterior && tramo.desde <= anterior.hasta) {
      anterior.hasta = Math.max(anterior.hasta, tramo.hasta);
    } else {
      finales.push({...tramo});
    }
  }

  // 5. Descartar restos demasiado breves.
  return finales.filter((t) => t.hasta - t.desde >= op.minimoSegmento);
};

/** Analiza un archivo y devuelve el informe completo. */
export const analizarSilencios = (entrada, opciones = {}) => {
  const datos = ffprobe(entrada);
  const video = datos.streams.find((s) => s.codec_type === 'video');
  const audio = datos.streams.find((s) => s.codec_type === 'audio');

  if (!audio) {
    throw new Error(`"${entrada}" no tiene pista de audio: no hay silencios que detectar.`);
  }

  const muestras = extraerAudio(entrada);
  const dB = energiaPorVentana(muestras);
  const segmentos = detectarSegmentos(dB, opciones);

  const duracionOriginal = Number(datos.format.duration);
  const duracionFinal = segmentos.reduce((s, t) => s + (t.hasta - t.desde), 0);

  // r_frame_rate viene como fracción exacta ("30000/1001"), que es la única
  // forma fiable de conservar las cadencias NTSC.
  const [num, den] = (video?.r_frame_rate ?? '30/1').split('/').map(Number);

  return {
    fuente: entrada,
    duracionOriginal,
    duracionFinal,
    recortado: duracionOriginal - duracionFinal,
    segmentos,
    video: video
      ? {ancho: video.width, alto: video.height, fps: num / den, codec: video.codec_name}
      : null,
    audio: {codec: audio.codec_name, canales: audio.channels, tasa: Number(audio.sample_rate)},
    ruidoDeFondo: Number(ruidoDeFondo(dB).toFixed(1)),
    opciones: {...OPCIONES_POR_DEFECTO, ...opciones},
  };
};

const comoTiempo = (s) => {
  const m = Math.floor(s / 60);
  return `${m}:${String(Math.floor(s % 60)).padStart(2, '0')}`;
};

const leerArgumentos = (argv) => {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    if (!argv[i].startsWith('--')) continue;
    const clave = argv[i].slice(2);
    const siguiente = argv[i + 1];
    if (siguiente === undefined || siguiente.startsWith('--')) {
      args[clave] = true;
    } else {
      args[clave] = siguiente;
      i++;
    }
  }
  return args;
};

// Ejecución directa desde la terminal.
if (process.argv[1] && import.meta.url.endsWith(process.argv[1].split(/[\\/]/).pop())) {
  const args = leerArgumentos(process.argv.slice(2));

  if (!args.entrada) {
    console.error('Falta --entrada <archivo de video>.');
    process.exit(1);
  }

  const opciones = {};
  for (const clave of [
    'umbral',
    'margenRuido',
    'pausaMaxima',
    'margenAntes',
    'margenDespues',
    'minimoSegmento',
  ]) {
    if (args[clave] !== undefined) opciones[clave] = Number(args[clave]);
  }

  const informe = analizarSilencios(resolve(String(args.entrada)), opciones);

  console.log(`\nArchivo:  ${informe.fuente}`);
  if (informe.video) {
    console.log(
      `Video:    ${informe.video.ancho}x${informe.video.alto} @ ` +
        `${informe.video.fps.toFixed(3)} fps (${informe.video.codec})`,
    );
  }
  console.log(
    `Audio:    ${informe.audio.codec} ${informe.audio.canales}ch ${informe.audio.tasa} Hz  ` +
      `(ruido de fondo ${informe.ruidoDeFondo} dBFS)`,
  );
  console.log(`\nDuración original:  ${comoTiempo(informe.duracionOriginal)}`);
  console.log(`Duración sin silencios: ${comoTiempo(informe.duracionFinal)}`);
  console.log(
    `Se recortan: ${comoTiempo(informe.recortado)} ` +
      `(${((informe.recortado / informe.duracionOriginal) * 100).toFixed(1)}%) ` +
      `en ${informe.segmentos.length} tramos`,
  );

  // Distribución de los huecos y coste visual de cada umbral de reencuadre.
  // Es la información que decide si el cambio de plano alterno va a quedar
  // elegante o mareante, y solo se puede saber con los datos reales.
  const huecos = informe.segmentos
    .slice(1)
    .map((s, i) => s.desde - informe.segmentos[i].hasta);

  if (huecos.length) {
    const media = huecos.reduce((a, b) => a + b, 0) / huecos.length;
    console.log(
      `\nHuecos eliminados: mín ${Math.min(...huecos).toFixed(2)} s · ` +
        `media ${media.toFixed(2)} s · máx ${Math.max(...huecos).toFixed(2)} s`,
    );

    console.log('\nCambios de plano según --cambio-encuadre:');
    for (const umbral of [0, 0.5, 0.8, 1.2, 1.6, 2, 2.5]) {
      const cambios = huecos.filter((h) => h >= umbral).length;
      const cada = cambios > 0 ? informe.duracionFinal / cambios : Infinity;
      const nota =
        cada >= 8 && cada <= 20 ? '  <- ritmo recomendado' : '';
      console.log(
        `  ${umbral.toFixed(1)} s -> ${String(cambios).padStart(4)} cambios ` +
          `(uno cada ${cada === Infinity ? '—' : cada.toFixed(1) + ' s'})${nota}`,
      );
    }
  }

  if (args.json) {
    const destino = resolve(String(args.json));
    mkdirSync(dirname(destino), {recursive: true});
    writeFileSync(destino, JSON.stringify(informe, null, 2));
    console.log(`\nInforme guardado en ${destino}`);
  }
}
