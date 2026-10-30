// render_layer.mjs <outDir> <frame0> <frame1>: the type layer as PNG with alpha, one sample per frame (pixel type: no motion blur).
// Frames without ink are skipped (compose.py treats a missing file as an empty layer). Serve the film at FILM_URL first.
import fs from 'fs';
import { launch, openFilm } from 'file:///C:/Users/corte/.claude/skills/scenario-kinetic-film/scripts/browser.mjs';
const [OUT, F0, F1] = process.argv.slice(2);
fs.mkdirSync(OUT, { recursive: true });
const b = await launch();
const { pg, errs } = await openFilm(b, 1);
const fps = await pg.evaluate(() => window.__film.fps);
const cdp = await pg.context().newCDPSession(pg);
await cdp.send('Emulation.setDefaultBackgroundColorOverride', { color: { r: 0, g: 0, b: 0, a: 0 } });
let n = 0;
for (let k = +F0; k < +F1; k++) {
  const t = k / fps;
  if (!(await pg.evaluate(t => window.__inkAt(t), t))) continue;
  await pg.evaluate(t => new Promise(r => { window.__frameT = t; window.__seek(t); requestAnimationFrame(() => r()); }), t);
  const { data } = await cdp.send('Page.captureScreenshot', { format: 'png', clip: { x: 0, y: 0, width: 1920, height: 1080, scale: 1 } });
  fs.writeFileSync(`${OUT}/f_${String(k).padStart(5, '0')}.png`, Buffer.from(data, 'base64'));
  n++;
}
if (errs.length) process.stderr.write('PAGE ERRORS ' + JSON.stringify(errs.slice(0, 5)) + '\n');
console.log(`layer ${F0}-${F1}: ${n} frames with ink`);
await Promise.race([b.close(), new Promise(r => setTimeout(r, 4000))]);
process.exit(0);
