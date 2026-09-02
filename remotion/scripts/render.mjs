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
import {copyFileSync, existsSync, linkSync, mkdirSync, readFileSync, statSync, symlinkSync} from 'node:fs';
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
  --composicion <id>   EditarVideo (por defecto), SinSilencios o UnirClips.
  --cortes <archivo>   Informe de scripts/silencios.mjs. Implica SinSilencios:
                       monta el video conservando solo los tramos con voz.
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

Sin silencios (con --cortes)
  --punch <n>          Cierra el plano en los tramos alternos para ocultar los
                       jump-cuts. 0.18 = 18 % (por defecto). 0 lo desactiva.
  --cambio-encuadre <seg>  Solo cambia de plano si el corte eliminó una pausa de
                       al menos estos segundos (0.8 por defecto). Evita cambiar
                       de encuadre en cada microcorte.
  --punto-x <%>        Hacia dónde cierra el plano (50 por defecto).
  --punto-y <%>        42 por defecto: algo por encima del centro, a la cara.
  --zoom <n>           Zoom sutil que disimula los cortes. 0 lo desactiva (0.03 por defecto).
  --rampa <seg>        Fundido de audio en cada empalme, evita chasquidos (0.02 por defecto).

Formato
  --ancho <px>         Por defecto, el del original.
  --alto <px>          Por defecto, el del original.
  --fps <n>            Por defecto, los del original.
  --ajuste <modo>      contener (por defecto) | cubrir
  --codec <codec>      h264 (por defecto), h265, vp8, vp9, prores, gif...
  --crf <n>            Calidad: más bajo = mejor. 18 por defecto.
  --concurrencia <n>   Procesos en paralelo.
  --frames <a>-<b>     Renderiza solo ese rango de fotogramas. Imprescindible
                       para probar el estilo sin esperar el render completo:
                       --frames 0-2700 son los primeros 90 s a 30 fps.

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

  const yaEsta = existsSync(destino) && statSync(destino).size === statSync(absoluta).size;

  if (!yaEsta) {
    // El material en bruto puede pesar decenas de GB (4K con audio PCM son
    // ~12 GB por cada 27 minutos), así que copiar es el último recurso.
    // Un enlace ocupa cero y Remotion lo sirve igual desde public/.
    const gb = statSync(absoluta).size / 1e9;

    try {
      // Enlace duro: instantáneo, pero solo dentro del mismo volumen.
      linkSync(absoluta, destino);
      console.log(`Enlazado (duro) ${basename(absoluta)} en public/entradas/`);
    } catch {
      try {
        // Enlace simbólico: cruza volúmenes, pero en Windows exige el modo
        // de desarrollador o permisos de administrador.
        symlinkSync(absoluta, destino);
        console.log(`Enlazado (simbólico) ${basename(absoluta)} en public/entradas/`);
      } catch {
        console.log(
          `No se pudo enlazar, copiando ${gb.toFixed(1)} GB a public/entradas/ ` +
            '(mueve el proyecto al mismo disco que el video para evitarlo)...',
        );
        copyFileSync(absoluta, destino);
      }
    }
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

/** Convierte el informe de scripts/silencios.mjs en props de SinSilencios. */
const propsDesdeCortes = (args) => {
  const informe = JSON.parse(readFileSync(String(args.cortes), 'utf-8'));

  if (!informe.segmentos?.length) {
    throw new Error('El informe de cortes no tiene segmentos.');
  }

  // Los fps salen del informe (fracción exacta de ffprobe), no de una
  // suposición: con material NTSC, 30 en vez de 29.97 desincroniza el final.
  const fps = numero(args.fps, informe.video?.fps ?? 30);

  return {
    fuente: prepararEntrada(informe.fuente),
    segmentos: informe.segmentos,
    fps,
    ancho: numero(args.ancho, 1920),
    alto: numero(args.alto, 1080),
    ajuste: String(args.ajuste ?? 'contener'),
    colorFondo: '#000000',
    volumen: numero(args.volumen, 1),
    rampaAudio: numero(args.rampa, 0.02),
    encuadreAlterno: numero(args.punch, 0.18) > 0,
    intensidadPunch: numero(args.punch, 0.18),
    umbralCambioEncuadre: numero(args['cambio-encuadre'], 0.8),
    puntoDeInteres: {x: numero(args['punto-x'], 50), y: numero(args['punto-y'], 42)},
    zoomSutil: numero(args.zoom, 0.03) > 0,
    intensidadZoom: numero(args.zoom, 0.03),
    marcaDeAgua: {
      texto: args.marca ? String(args.marca) : '',
      imagen: args['marca-imagen'] ? String(args['marca-imagen']) : '',
      posicion: String(args['marca-pos'] ?? 'abajo-derecha'),
      opacidad: 0.85,
      tamano: 36,
      color: '#ffffff',
    },
    subtitulos: args.subtitulos
      ? JSON.parse(readFileSync(String(args.subtitulos), 'utf-8'))
      : [],
    fundidoEntrada: numero(args.fundidos, 0.5),
    fundidoSalida: numero(args.fundidos, 0.8),
  };
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

  // --cortes implica SinSilencios: es el flujo habitual tras analizar el audio.
  const composicion = String(args.composicion ?? (args.cortes ? 'SinSilencios' : 'EditarVideo'));

  let props;
  if (args.cortes) {
    props = propsDesdeCortes(args);
  } else if (args.props) {
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

  if (composicion === 'SinSilencios' && !args.cortes && !args.props) {
    throw new Error('Para SinSilencios hay que pasar --cortes <informe.json> o --props <archivo.json>.');
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

  // Rango parcial: permite validar el estilo en un minuto en vez de en horas.
  let rango = null;
  if (args.frames) {
    const partes = String(args.frames).split('-').map(Number);
    if (partes.length !== 2 || partes.some(Number.isNaN)) {
      throw new Error('--frames espera un rango tipo 0-2700.');
    }
    rango = [partes[0], Math.min(partes[1], compo.durationInFrames - 1)];
    console.log(`Solo fotogramas ${rango[0]}-${rango[1]} de ${compo.durationInFrames}`);
  }

  await renderMedia({
    composition: compo,
    frameRange: rango,
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
