const { chromium } = require('playwright');
(async () => {
  const dir = __dirname;
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1200, height: 1200 }, deviceScaleFactor: 1 });
  await p.goto('file://' + dir + '/carrusel.html');
  await p.evaluate(() => document.fonts.ready);
  await p.waitForTimeout(500);
  for (let i = 1; i <= 8; i++)
    await p.locator('#s' + i).screenshot({ path: `${dir}/slides/0${i}.png` });
  await b.close();
})();
