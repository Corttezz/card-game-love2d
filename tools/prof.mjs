// Perfil de CPU do carregamento (celular emulado, CPU 4x mais lenta), para achar tarefa longa. uso: node tools/prof.mjs [url]
import { chromium } from 'playwright-core';
const url = process.argv[2] || 'http://127.0.0.1:8788/';
const b = await chromium.launch({ executablePath: 'C:/Users/corte/AppData/Local/ms-playwright/chromium_headless_shell-1254/chrome-headless-shell-win64/chrome-headless-shell.exe' });
const c = await b.newContext({ viewport: { width: 412, height: 823 }, deviceScaleFactor: 1.75, isMobile: true });
const p = await c.newPage();
const s = await c.newCDPSession(p);
await s.send('Emulation.setCPUThrottlingRate', { rate: 4 });
await s.send('Profiler.enable');
await s.send('Profiler.setSamplingInterval', { interval: 200 });
await s.send('Profiler.start');
await p.goto(url, { waitUntil: 'load' });
await p.waitForTimeout(3000);
const { profile } = await s.send('Profiler.stop');
const self = new Map();
const byId = new Map(profile.nodes.map((n) => [n.id, n]));
profile.samples.forEach((id, i) => {
  const n = byId.get(id);
  const key = `${n.callFrame.functionName || '(anon)'} ${n.callFrame.url.split('/').pop()}:${n.callFrame.lineNumber}`;
  self.set(key, (self.get(key) || 0) + (profile.timeDeltas[i] || 0));
});
console.log([...self.entries()].sort((a, b2) => b2[1] - a[1]).slice(0, 14).map(([k2, v]) => `${(v / 1000).toFixed(0)}ms ${k2}`).join('\n'));
await b.close();
