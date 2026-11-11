// Monta dist/: uma página por idioma (HTML pronto no servidor, sem depender de JS para ler),
// JS e CSS empacotados com hash, assets copiados, sitemap, robots, 404, privacidade e a página secreta.
// uso: node tools/build.mjs
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { fileURLToPath } from 'url';
import * as esbuild from 'esbuild';
import { LANGS, renderHome, renderPrivacy, render404, renderUnsub, renderEclipse, themesCss, spritesCss, gateCode } from './page.mjs';
import { execFileSync } from 'child_process';

const R = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const D = path.join(R, 'dist');
fs.mkdirSync(D, { recursive: true });
for (const f of fs.readdirSync(D)) fs.rmSync(path.join(D, f), { recursive: true, force: true });

// 1. assets estáticos
fs.cpSync(path.join(R, 'public'), D, { recursive: true });
// arte nova (PixelLab) em art/gen -> /img/gen
if (fs.existsSync(path.join(R, 'art/gen'))) fs.cpSync(path.join(R, 'art/gen'), path.join(D, 'img/gen'), { recursive: true, filter: (f) => !f.endsWith('.md') });

// 2. CSS gerado dos dados do jogo (temas por bioma e sprites animados) e depois JS e CSS com hash no nome
const GAME0 = JSON.parse(fs.readFileSync(path.join(R, 'src/data/game.json'), 'utf8'));
const GEN = '/* gerado por tools/build.mjs a partir de src/data/game.json */\n';
fs.writeFileSync(path.join(R, 'src/css/themes.css'), GEN + themesCss(GAME0));
fs.writeFileSync(path.join(R, 'src/css/sprites.css'), GEN + spritesCss(GAME0));
fs.writeFileSync(path.join(D, 'site.webmanifest'), JSON.stringify({ name: 'Runemoire', short_name: 'Runemoire', start_url: '/', display: 'standalone', background_color: '#120f16', theme_color: '#211f29', icons: [192, 512].map((s) => ({ src: `/img/brand/r_${s}.png`, sizes: `${s}x${s}`, type: 'image/png' })) }));
const res = await esbuild.build({
  entryPoints: { app: path.join(R, 'src/ts/main.ts'), site: path.join(R, 'src/css/index.css') },
  bundle: true, minify: true, format: 'esm', target: ['es2020'],
  outdir: path.join(D, 'assets'), entryNames: '[name]-[hash]', metafile: true,
  external: ['/img/*', '/fonts/*'], loader: { '.png': 'file' }, legalComments: 'none',
});
const out = Object.keys(res.metafile.outputs).map((p) => '/' + path.relative(D, path.resolve(R, p)).replace(/\\/g, '/'));
const JS = out.find((p) => /app-.*\.js$/.test(p));
const CSS = out.find((p) => /site-.*\.css$/.test(p));

// 3. dados do jogo e textos
const GAME = JSON.parse(fs.readFileSync(path.join(R, 'src/data/game.json'), 'utf8'));
const readT = (c) => { const f = path.join(R, `src/i18n/${c}.json`); if (fs.existsSync(f)) return JSON.parse(fs.readFileSync(f, 'utf8')); console.warn(`[i18n] falta ${c}.json`); return {}; };
const T = Object.fromEntries(LANGS.map((l) => [l.code, readT(l.code)]));
for (const l of LANGS) {
  // chave faltando num idioma: cai no inglês, e o build avisa
  for (const k of Object.keys(T.en)) if (!(k in T[l.code])) { console.warn(`[i18n] ${l.code} sem "${k}"`); T[l.code][k] = T.en[k]; }
}
const ctx = { JS, CSS, GAME, GATE: gateCode(GAME) };

const write = (rel, html) => {
  const f = path.join(D, rel);
  fs.mkdirSync(path.dirname(f), { recursive: true });
  fs.writeFileSync(f, html);
};
for (const l of LANGS) {
  const base = l.prefix ? `${l.prefix}/` : '';
  write(`${base}index.html`, renderHome(T[l.code], l, ctx, T));
  write(`${base}privacy/index.html`, renderPrivacy(T[l.code], l, ctx, T));
  write(`${base}unsubscribe/index.html`, renderUnsub(T[l.code], l, ctx, T));
  write(`${base}404.html`, render404(T[l.code], l, ctx, T));
}
write('eclipse/index.html', renderEclipse(T.en, LANGS[0], ctx, T));

// 4. sitemap e robots
const SITE = 'https://runemoire.com';
const urls = LANGS.flatMap((l) => ['', 'privacy/'].map((s) => `${SITE}/${l.prefix ? l.prefix + '/' : ''}${s}`));
write('sitemap.xml', `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls.map((u) => `  <url><loc>${u}</loc></url>`).join('\n')}\n</urlset>\n`);
write('robots.txt', `User-agent: *\nAllow: /\nDisallow: /eclipse/\nDisallow: /unsubscribe/\nSitemap: ${SITE}/sitemap.xml\n`);

// 5. pixel art em WebP sem perda: converte e troca as referências nos HTML, CSS e JS gerados
const conv = execFileSync('python', ['-X', 'utf8', path.join(R, 'tools/webp.py'), D], { encoding: 'utf8' }).split(/\r?\n/).map((x) => x.trim()).filter(Boolean);
const swap = new Set(conv);
const texts = [];
(function walk(dir) { for (const f of fs.readdirSync(dir, { withFileTypes: true })) { const p = path.join(dir, f.name); if (f.isDirectory()) { if (f.name !== 'img' && f.name !== 'media') walk(p); } else if (/\.(html|css|js)$/.test(f.name)) texts.push(p); } })(D);
for (const f of texts) {
  const src = fs.readFileSync(f, 'utf8');
  const out = src.replace(/\/img\/[A-Za-z0-9_\-/]+\.png/g, (u) => (swap.has(u) ? u.slice(0, -4) + '.webp' : u));
  if (out !== src) fs.writeFileSync(f, out);
}
console.log('webp:', conv.length, 'imagens');

// hash do script inline (gate), já com os caminhos finais, para a CSP do Worker
const gateFinal = fs.readFileSync(path.join(D, 'index.html'), 'utf8').match(/<script>(\(function[\s\S]*?)<\/script>/)[1];
const GATE_HASH = 'sha256-' + crypto.createHash('sha256').update(gateFinal).digest('base64');
fs.writeFileSync(path.join(R, 'worker/gate-hash.js'), `// gerado por tools/build.mjs\nexport const GATE_HASH = '${GATE_HASH}';\n`);
for (const l of LANGS) {
  const f = path.join(D, l.prefix ? l.prefix + '/index.html' : 'index.html');
  const g2 = fs.readFileSync(f, 'utf8').match(/<script>(\(function[\s\S]*?)<\/script>/)[1];
  if (g2 !== gateFinal) throw new Error('gate diferente em ' + f);
}

// 6. relatório de peso: carga inicial = HTML + CSS + JS + imagens do primeiro quadro
const size = (rel) => fs.statSync(path.join(D, rel.replace(/^\//, ''))).size;
const kb = (n) => (n / 1024).toFixed(1) + ' KB';
console.log('JS', JS, kb(size(JS)), '| CSS', CSS, kb(size(CSS)), '| index.html', kb(size('index.html')));
const hash = crypto.createHash('sha256').update(fs.readFileSync(path.join(D, 'index.html'))).digest('hex').slice(0, 12);
console.log('build ok', hash);
