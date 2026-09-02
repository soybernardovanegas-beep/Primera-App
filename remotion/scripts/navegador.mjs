// Resuelve qué binario de Chrome/Chromium debe usar Remotion para renderizar.
//
// Remotion normalmente descarga su propio "Chrome Headless Shell" desde
// remotion.media. En entornos con la salida de red restringida esa descarga
// falla, así que aquí buscamos un Chromium ya presente en la máquina.
// Si no encontramos ninguno devolvemos null y Remotion hace lo de siempre
// (descargarlo), que es lo que ocurrirá en un equipo normal con internet.

import {existsSync, readdirSync} from 'node:fs';
import {join} from 'node:path';

const RAIZ_PLAYWRIGHT = process.env.PLAYWRIGHT_BROWSERS_PATH || '/opt/pw-browsers';

const rutasFijas = () =>
  [
    process.env.REMOTION_BROWSER_EXECUTABLE,
    process.env.CHROME_PATH,
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
    '/usr/bin/google-chrome',
    '/usr/bin/google-chrome-stable',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
  ].filter(Boolean);

// Chromium instalado por Playwright: /opt/pw-browsers/<carpeta>/chrome-linux/<binario>
const rutasPlaywright = () => {
  if (!existsSync(RAIZ_PLAYWRIGHT)) {
    return [];
  }

  const carpetas = readdirSync(RAIZ_PLAYWRIGHT)
    // El headless shell va primero: es justo lo que Remotion espera.
    .sort((a, b) => Number(b.startsWith('chromium_headless_shell')) - Number(a.startsWith('chromium_headless_shell')));

  return carpetas.flatMap((carpeta) => [
    join(RAIZ_PLAYWRIGHT, carpeta, 'chrome-linux', 'headless_shell'),
    join(RAIZ_PLAYWRIGHT, carpeta, 'chrome-linux', 'chrome'),
    join(RAIZ_PLAYWRIGHT, carpeta, 'chrome-mac', 'Chromium.app', 'Contents', 'MacOS', 'Chromium'),
    join(RAIZ_PLAYWRIGHT, carpeta, 'chrome-win', 'chrome.exe'),
  ]);
};

/**
 * @returns {string | null} ruta al ejecutable, o null para que Remotion use el suyo
 */
export const resolverNavegador = () => {
  for (const ruta of [...rutasFijas(), ...rutasPlaywright()]) {
    if (existsSync(ruta)) {
      return ruta;
    }
  }

  return null;
};
