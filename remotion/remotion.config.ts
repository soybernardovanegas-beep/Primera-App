// Configuración del CLI de Remotion (`npx remotion studio`, `npx remotion render`).
// Ojo: este archivo NO lo lee el script programático `scripts/render.mjs`;
// ese resuelve el navegador por su cuenta usando el mismo helper.
import {Config} from '@remotion/cli/config';
import {resolverNavegador} from './scripts/navegador.mjs';

Config.setEntryPoint('src/index.ts');
Config.setPublicDir('public');

// Calidad / formato de salida por defecto.
Config.setVideoImageFormat('jpeg');
Config.setCodec('h264');
Config.setCrf(18);
Config.setOverwriteOutput(true);

// En Linux sin GPU el renderizador por software es el único que funciona
// de forma fiable dentro de un contenedor.
if (process.platform === 'linux') {
  Config.setChromiumOpenGlRenderer('swangle');
}

// Si hay un Chromium ya instalado, úsalo en vez de descargar uno.
const navegador = resolverNavegador();
if (navegador) {
  Config.setBrowserExecutable(navegador);
}
