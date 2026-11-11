// Monta dist/ da v2 (minimalista): uma página por idioma, privacidade, saída da lista e 404.
// Copia SÓ os arquivos que a página usa (lista abaixo), gera o CSS do castelo a partir dos dados do jogo
// e passa a pixel art para WebP sem perda. uso: node tools/build.mjs
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { execFileSync } from 'child_process';
import { fileURLToPath } from 'url';
import * as esbuild from 'esbuild';
import { LANGS, renderHome, renderPrivacy, render404, renderUnsub } from './page.mjs';

const R = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const P = path.join(R, 'public');
const D = path.join(R, 'dist');
fs.mkdirSync(D, { recursive: true });
for (const f of fs.readdirSync(D)) fs.rmSync(path.join(D, f), { recursive: true, force: true });

const GAME = JSON.parse(fs.readFileSync(path.join(R, 'src/data/game.json'), 'utf8'));

// 1. só o que a v2 usa
const KEEP = [
  'favicon.ico', 'fonts/pixel.woff2', 'fonts/OFL.txt', 'img/og', 'img/v3', 'img/gamecards', 'media/v3',
  'img/brand/seal_32.png', 'img/brand/seal_180.png', 'img/brand/seal_192.png', 'img/brand/seal_512.png',
  'media/runemoire-gameplay.mp4', 'media/runemoire-gameplay.jpg',
  ...['en', 'pt_BR'].flatMap((l) => ['03_road_battle', '06_road_fork', '05_shop'].flatMap((s) => [`img/shots/${l}/${s}.webp`, `img/shots/${l}/${s}_s.webp`])),
].map((p) => p.replace(/^\//, ''));
for (const rel of KEEP) {
  const src = path.join(P, rel);
  if (!fs.existsSync(src)) throw new Error('falta ' + rel);
  fs.cpSync(src, path.join(D, rel), { recursive: true });
}

// 2. JS e CSS
const res = await esbuild.build({
  entryPoints: { app: path.join(R, 'src/ts/main.ts'), site: path.join(R, 'src/css/index.css') },
  bundle: true, minify: !process.env.NOMINIFY, format: 'esm', target: ['es2020'], outdir: path.join(D, 'assets'), entryNames: '[name]-[hash]',
  metafile: true, external: ['/img/*', '/fonts/*'], legalComments: 'none',
});
const out = Object.keys(res.metafile.outputs).map((p) => '/' + path.relative(D, path.resolve(R, p)).replace(/\\/g, '/'));
const JS = out.find((p) => /app-.*\.js$/.test(p));
const CSS = out.find((p) => /site-.*\.css$/.test(p));

// 3. textos
const readT = (code) => JSON.parse(fs.readFileSync(path.join(R, `src/i18n/${code}.json`), 'utf8'));
const T = Object.fromEntries(LANGS.map((l) => [l.code, readT(l.code)]));
for (const l of LANGS) for (const k of Object.keys(T.en)) if (!(k in T[l.code])) { console.warn(`[i18n] ${l.code} sem "${k}"`); T[l.code][k] = T.en[k]; }

// 4. páginas
const ctx = { JS, CSS, GAME };
const write = (rel, html) => { const f = path.join(D, rel); fs.mkdirSync(path.dirname(f), { recursive: true }); fs.writeFileSync(f, html); };
for (const l of LANGS) {
  const base = l.prefix ? `${l.prefix}/` : '';
  write(`${base}index.html`, renderHome(T[l.code], l, ctx));
  write(`${base}privacy/index.html`, renderPrivacy(T[l.code], l, ctx));
  write(`${base}unsubscribe/index.html`, renderUnsub(T[l.code], l, ctx));
  write(`${base}404.html`, render404(T[l.code], l, ctx));
}
const SITE = 'https://runemoire.com';
write('sitemap.xml', `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${LANGS.flatMap((l) => ['', 'privacy/'].map((s) => `  <url><loc>${SITE}/${l.prefix ? l.prefix + '/' : ''}${s}</loc></url>`)).join('\n')}\n</urlset>\n`);
write('robots.txt', `User-agent: *\nAllow: /\nDisallow: /unsubscribe/\nDisallow: /*/unsubscribe/\nSitemap: ${SITE}/sitemap.xml\n`);
write('site.webmanifest', JSON.stringify({ name: 'Runemoire', short_name: 'Runemoire', start_url: '/', display: 'standalone', background_color: '#0b0a0d', theme_color: '#0b0a0d', icons: [192, 512].map((s) => ({ src: `/img/brand/seal_${s}.png`, sizes: `${s}x${s}`, type: 'image/png' })) }));

// 5. pixel art em WebP sem perda e troca das referências
const conv = new Set(execFileSync('python', ['-X', 'utf8', path.join(R, 'tools/webp.py'), D], { encoding: 'utf8' }).split(/\r?\n/).map((x) => x.trim()).filter(Boolean));
(function walk(dir) {
  for (const f of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, f.name);
    if (f.isDirectory()) { if (!['img', 'media', 'fonts'].includes(f.name)) walk(p); continue; }
    if (!/\.(html|css|js)$/.test(f.name)) continue;
    const s = fs.readFileSync(p, 'utf8');
    const o = s.replace(/\/img\/[A-Za-z0-9_\-/]+\.png/g, (u) => (conv.has(u) ? u.slice(0, -4) + '.webp' : u));
    if (o !== s) fs.writeFileSync(p, o);
  }
})(D);

const size = (rel) => fs.statSync(path.join(D, rel.replace(/^\//, ''))).size;
const kb = (n) => (n / 1024).toFixed(1) + ' KB';
let total = 0; (function sum(d) { for (const f of fs.readdirSync(d, { withFileTypes: true })) { const p = path.join(d, f.name); if (f.isDirectory()) sum(p); else total += fs.statSync(p).size; } })(D);
console.log('JS', kb(size(JS)), '| CSS', kb(size(CSS)), '| index.html', kb(size('index.html')), '| dist', (total / 1048576).toFixed(1) + ' MB', '| webp', conv.size);
console.log('build ok', crypto.createHash('sha256').update(fs.readFileSync(path.join(D, 'index.html'))).digest('hex').slice(0, 12));
