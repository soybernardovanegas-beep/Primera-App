#!/usr/bin/env node
// Render automático: empaqueta el proyecto, resuelve la composición con las
// props que le pases y genera el archivo de salida.
//
//   node scripts/render.mjs --entrada "D:/videos NMR/video 2.mp4" --salida salidas/video2.mp4 \
//        --desde 5 --hasta 42 --titulo "NMR" --marca "@nmr" --fundidos 1
//
//   node scripts/render.mjs --props ejemplos/edicion.json
//
// Ejecuta `node scripts/render.mjs --ayuda` para ver todas las opciones.

import {bundle} from '@remotion/bundler';
import {renderMedia, selectComposition} from '@remotion/renderer';
import {copyFileSync, existsSync, mkdirSync, readFileSync, statSync} from 'node:fs';
import {basename, dirname, isAbsolute, join, relative, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {resolverNavegador} from './navegador.mjs';

const RAIZ = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const DIR_PUBLICO = join(RAIZ, 'public');
const DIR_ENTRADAS = join(DIR_PUBLICO, 'entradas');
const DIR_SALIDAS = join(RAIZ, 'salidas');

const AYUDA = `
Render automático con Remotion

  node scripts/render.mjs [opciones]

Opciones principales
  --entrada <ruta>     Video de origen. Puede ser una ruta de tu disco o una URL http(s).
                       Si está fuera de public/, se copia a public/entradas/.
  --salida <ruta>      Archivo de salida (por defecto salidas/<nombre>-editado.mp4).
  --composicion <id>   EditarVideo (por defecto) o UnirClips.
  --props <archivo>    JSON con las props completas. Lo que pases por bandera lo sobreescribe.

Edición
  --desde <seg>        Recorte: segundo inicial (por defecto 0).
  --hasta <seg>        Recorte: segundo final (por defecto, el final del video).
  --velocidad <n>      1 = normal, 2 = doble, 0.5 = cámara lenta.
  --volumen <n>        0 a 2.
  --sin-audio          Silencia el video.
  --titulo <texto>     Añade una intro con este título.
  --subtitulo <texto>  Subtítulo de la intro.
  --intro <seg>        Duración de la intro (por defecto 2).
  --marca <texto>      Marca de agua de texto.
  --marca-imagen <f>   Logo (archivo dentro de public/).
  --marca-pos <p>      arriba-izquierda | arriba-derecha | abajo-izquierda | abajo-derecha | centro
  --subtitulos <f>     JSON con [{"desde":0,"hasta":3,"texto":"..."}].
  --fundidos <seg>     Fundido de entrada y de salida.

Formato
  --ancho <px>         Por defecto, el del original.
  --alto <px>          Por defecto, el del original.
  --fps <n>            Por defecto, los del original.
  --ajuste <modo>      contener (por defecto) | cubrir
  --codec <codec>      h264 (por defecto), h265, vp8, vp9, prores, gif...
  --crf <n>            Calidad: más bajo = mejor. 18 por defecto.
  --concurrencia <n>   Procesos en paralelo.

  --ayuda              Muestra esta ayuda.
`;

/** Convierte `--clave valor` y `--bandera` en un objeto. */
const leerArgumentos = (argv) => {
  const args = {};

  for (let i = 0; i < argv.length; i++) {
    const actual = argv[i];
    if (!actual.startsWith('--')) {
      continue;
    }

    const clave = actual.slice(2);
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

const numero = (valor, porDefecto) => {
  if (valor === undefined) {
    return porDefecto;
  }

  const n = Number(valor);
  if (Number.isNaN(n)) {
    throw new Error(`Se esperaba un número y llegó "${valor}".`);
  }

  return n;
};

const esUrl = (ruta) => /^https?:\/\//.test(ruta);

/**
 * Remotion solo puede leer archivos servidos desde `public/`. Si el video está
 * en otro sitio del disco lo copiamos ahí y devolvemos la ruta relativa.
 */
const prepararEntrada = (entrada) => {
  if (esUrl(entrada)) {
    return entrada;
  }

  // Si ya es una ruta relativa a public/ (como las que llevan los JSON de
  // ejemplo), se deja tal cual: no hay nada que copiar.
  if (!isAbsolute(entrada) && existsSync(join(DIR_PUBLICO, entrada))) {
    return entrada.split('\\').join('/');
  }

  const absoluta = isAbsolute(entrada) ? entrada : resolve(process.cwd(), entrada);

  if (!existsSync(absoluta)) {
    throw new Error(`No encuentro el video de entrada: ${absoluta}`);
  }

  const dentroDePublico = relative(DIR_PUBLICO, absoluta);
  if (!dentroDePublico.startsWith('..') && !isAbsolute(dentroDePublico)) {
    return dentroDePublico.split('\\').join('/');
  }

  mkdirSync(DIR_ENTRADAS, {recursive: true});
  const destino = join(DIR_ENTRADAS, basename(absoluta));

  const yaCopiado =
    existsSync(destino) && statSync(destino).size === statSync(absoluta).size;

  if (!yaCopiado) {
    console.log(`Copiando ${absoluta} -> public/entradas/${basename(absoluta)}`);
    copyFileSync(absoluta, destino);
  }

  return `entradas/${basename(absoluta)}`;
};

const propsDesdeArgumentos = (args, base) => {
  const props = structuredClone(base);

  if (args.entrada) {
    props.fuente = prepararEntrada(String(args.entrada));
  }

  props.recorteDesde = numero(args.desde, props.recorteDesde);
  props.recorteHasta = args.hasta === undefined ? props.recorteHasta : numero(args.hasta);
  props.velocidad = numero(args.velocidad, props.velocidad);
  props.volumen = numero(args.volumen, props.volumen);
  props.silenciar = args['sin-audio'] === true ? true : props.silenciar;
  props.fps = args.fps === undefined ? props.fps : numero(args.fps);
  props.ancho = args.ancho === undefined ? props.ancho : numero(args.ancho);
  props.alto = args.alto === undefined ? props.alto : numero(args.alto);

  if (args.ajuste) {
    props.ajuste = String(args.ajuste);
  }

  if (args.titulo) {
    props.intro.titulo = String(args.titulo);
  }

  if (args.subtitulo) {
    props.intro.subtitulo = String(args.subtitulo);
  }

  props.intro.duracion = numero(args.intro, props.intro.duracion);

  if (args.marca) {
    props.marcaDeAgua.texto = String(args.marca);
  }

  if (args['marca-imagen']) {
    props.marcaDeAgua.imagen = String(args['marca-imagen']);
  }

  if (args['marca-pos']) {
    props.marcaDeAgua.posicion = String(args['marca-pos']);
  }

  if (args.subtitulos) {
    props.subtitulos = JSON.parse(readFileSync(String(args.subtitulos), 'utf-8'));
  }

  if (args.fundidos !== undefined) {
    props.fundidoEntrada = numero(args.fundidos);
    props.fundidoSalida = numero(args.fundidos);
  }

  return props;
};

const PROPS_BASE = {
  fuente: '',
  recorteDesde: 0,
  recorteHasta: null,
  velocidad: 1,
  volumen: 1,
  silenciar: false,
  fps: null,
  ancho: null,
  alto: null,
  ajuste: 'contener',
  colorFondo: '#000000',
  intro: {titulo: '', subtitulo: '', duracion: 2, colorFondo: '#0f172a', colorTexto: '#ffffff'},
  marcaDeAgua: {
    texto: '',
    imagen: '',
    posicion: 'abajo-derecha',
    opacidad: 0.85,
    tamano: 36,
    color: '#ffffff',
  },
  subtitulos: [],
  fundidoEntrada: 0,
  fundidoSalida: 0,
};

const nombreDeSalida = (props, composicion) => {
  const base = esUrl(props.fuente ?? '')
    ? composicion
    : basename(String(props.fuente ?? composicion)).replace(/\.[^.]+$/, '') || composicion;

  return join(DIR_SALIDAS, `${base}-editado.mp4`);
};

const principal = async () => {
  const args = leerArgumentos(process.argv.slice(2));

  if (args.ayuda || args.help || args.h) {
    console.log(AYUDA);
    return;
  }

  const composicion = String(args.composicion ?? 'EditarVideo');

  let props;
  if (args.props) {
    const desdeArchivo = JSON.parse(readFileSync(String(args.props), 'utf-8'));
    props =
      composicion === 'EditarVideo'
        ? propsDesdeArgumentos(args, {...PROPS_BASE, ...desdeArchivo})
        : desdeArchivo;
  } else if (composicion === 'EditarVideo') {
    props = propsDesdeArgumentos(args, PROPS_BASE);
  } else {
    throw new Error('Para UnirClips hay que pasar las props con --props <archivo.json>.');
  }

  if (composicion === 'EditarVideo' && !props.fuente) {
    throw new Error('Falta --entrada (o "fuente" dentro del JSON de --props).');
  }

  if (composicion === 'UnirClips') {
    props.clips = props.clips.map((clip) => ({...clip, fuente: prepararEntrada(clip.fuente)}));
  }

  const salida = args.salida
    ? resolve(process.cwd(), String(args.salida))
    : nombreDeSalida(props, composicion);

  mkdirSync(dirname(salida), {recursive: true});

  const navegador = resolverNavegador();
  if (navegador) {
    console.log(`Navegador: ${navegador}`);
  }

  console.log('Empaquetando el proyecto...');
  const serveUrl = await bundle({
    entryPoint: join(RAIZ, 'src', 'index.ts'),
    publicDir: DIR_PUBLICO,
    onProgress: (porcentaje) => {
      process.stdout.write(`\r  bundle ${porcentaje}%   `);
    },
  });
  process.stdout.write('\n');

  console.log('Leyendo el video de origen...');
  const compo = await selectComposition({
    serveUrl,
    id: composicion,
    inputProps: props,
    browserExecutable: navegador ?? undefined,
    chromiumOptions: process.platform === 'linux' ? {gl: 'swangle'} : {},
  });

  console.log(
    `Renderizando ${compo.width}x${compo.height} @ ${compo.fps}fps, ` +
      `${compo.durationInFrames} frames (${(compo.durationInFrames / compo.fps).toFixed(1)} s)`,
  );

  await renderMedia({
    composition: compo,
    serveUrl,
    codec: String(args.codec ?? 'h264'),
    crf: numero(args.crf, 18),
    outputLocation: salida,
    inputProps: props,
    browserExecutable: navegador ?? undefined,
    chromiumOptions: process.platform === 'linux' ? {gl: 'swangle'} : {},
    concurrency: args.concurrencia === undefined ? null : numero(args.concurrencia),
    overwrite: true,
    onProgress: ({progress}) => {
      process.stdout.write(`\r  render ${Math.round(progress * 100)}%   `);
    },
  });

  process.stdout.write('\n');
  console.log(`Listo: ${salida}`);
};

principal().catch((error) => {
  console.error(`\nError: ${error.message}`);
  process.exitCode = 1;
});
