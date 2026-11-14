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
import { loadPosts, renderPost, renderHub } from './blog.mjs';

const R = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const P = path.join(R, 'public');
const D = path.join(R, 'dist');
fs.mkdirSync(D, { recursive: true });
for (const f of fs.readdirSync(D)) fs.rmSync(path.join(D, f), { recursive: true, force: true });

const GAME = JSON.parse(fs.readFileSync(path.join(R, 'src/data/game.json'), 'utf8'));

// 1. só o que a v2 usa
const KEEP = [
  'favicon.ico', 'js/clarity.js', 'fonts/pixel.woff2', 'fonts/OFL.txt', 'img/og', 'img/blog', 'img/v3', 'img/v3b', 'img/gamecards', 'media/v3', 'media/v3b',
  'img/brand/icon_32.png', 'img/brand/icon_180.png', 'img/brand/icon_192.png', 'img/brand/icon_512.png',
  'media/runemoire-gameplay.mp4', 'media/runemoire-gameplay.jpg',
  ...['en', 'pt_BR'].flatMap((l) => ['03_road_battle', '06_road_fork', '05_shop'].flatMap((s) => [`img/shots/${l}/${s}.webp`, `img/shots/${l}/${s}_s.webp`])),
].map((p) => p.replace(/^\//, ''));
for (const rel of KEEP) {
  const src = path.join(P, rel);
  if (!fs.existsSync(src)) throw new Error('falta ' + rel);
  fs.cpSync(src, path.join(D, rel), { recursive: true });
}

// prévia: pasta local fora do git (PREVIEW_DIR, posta pelo tools/deploy_preview.sh), ex.: vídeos para o Daniel ver.
// Nunca entra na produção nem no sitemap; o Worker já manda X-Robots-Tag noindex na prévia.
if (process.env.PREVIEW_DIR) {
  const pv = path.resolve(R, process.env.PREVIEW_DIR);
  if (fs.existsSync(pv)) fs.cpSync(pv, D, { recursive: true });
}

// 2. JS e CSS
const res = await esbuild.build({
  entryPoints: { app: path.join(R, 'src/ts/main.ts'), site: path.join(R, 'src/css/index.css') },
  bundle: true, minify: !process.env.NOMINIFY, format: 'esm', target: ['es2020'], outdir: path.join(D, 'assets'), entryNames: '[name]-[hash]',
  metafile: true, loader: { '.glsl': 'text' }, external: ['/img/*', '/fonts/*'], legalComments: 'none',
});
const out = Object.keys(res.metafile.outputs).map((p) => '/' + path.relative(D, path.resolve(R, p)).replace(/\\/g, '/'));
const JS = out.find((p) => /app-.*\.js$/.test(p));
const CSS = out.find((p) => /site-.*\.css$/.test(p));

// 3. textos
const readT = (code) => JSON.parse(fs.readFileSync(path.join(R, `src/i18n/${code}.json`), 'utf8'));
const T = Object.fromEntries(LANGS.map((l) => [l.code, readT(l.code)]));
for (const l of LANGS) for (const k of Object.keys(T.en)) if (!(k in T[l.code])) { console.warn(`[i18n] ${l.code} sem "${k}"`); T[l.code][k] = T.en[k]; }

// 4. páginas
const CSSTEXT = fs.readFileSync(path.join(D, CSS.slice(1)), 'utf8').trim();
const ctx = { JS, CSS, GAME, CSSTEXT };
const write = (rel, html) => { const f = path.join(D, rel); fs.mkdirSync(path.dirname(f), { recursive: true }); fs.writeFileSync(f, html); };
for (const l of LANGS) {
  const base = l.prefix ? `${l.prefix}/` : '';
  write(`${base}index.html`, renderHome(T[l.code], l, ctx));
  write(`${base}privacy/index.html`, renderPrivacy(T[l.code], l, ctx));
  write(`${base}unsubscribe/index.html`, renderUnsub(T[l.code], l, ctx));
  write(`${base}404.html`, render404(T[l.code], l, ctx));
}
// blog (só inglês): posts de content/posts; a amostra de content/sample só na prévia (BLOG_SAMPLE=1)
const POSTS = loadPosts({ sample: process.env.BLOG_SAMPLE === '1' });
for (const p of POSTS) write(`blog/${p.slug}/index.html`, renderPost(p, T.en, ctx));
write('blog/index.html', renderHub(POSTS, T.en, ctx));
console.log('blog', POSTS.length, 'post(s):', POSTS.map((p) => p.slug).join(', ') || '(vazio)');
// IndexNow: o arquivo da chave fica na raiz (servido pelo Worker como os outros arquivos)
const CONF = JSON.parse(fs.readFileSync(path.join(R, 'src/data/config.json'), 'utf8'));
if (CONF.indexnowKey) write(`${CONF.indexnowKey}.txt`, CONF.indexnowKey);
const SITE = 'https://runemoire.com';
// lastmod real: a data do último commit que mexeu no conteúdo da página (nunca o horário do build)
const gitDay = (...paths) => { try { return execFileSync('git', ['log', '-1', '--format=%cs', '--', ...paths], { cwd: R, encoding: 'utf8' }).trim(); } catch { return ''; } };
const HOME_SRC = ['tools/page.mjs', 'src/css', 'src/ts', 'src/data'];
const locUrl = (l, s) => `${SITE}/${l.prefix ? l.prefix + '/' : ''}${s}`;
const xurl = (l, s) => {
  const mod = s ? gitDay('tools/page.mjs', `src/i18n/${l.code}.json`) : gitDay(...HOME_SRC, `src/i18n/${l.code}.json`);
  const alts = LANGS.map((x) => `<xhtml:link rel="alternate" hreflang="${x.html}" href="${locUrl(x, s)}"/>`).join('') + `<xhtml:link rel="alternate" hreflang="x-default" href="${locUrl(LANGS[0], s)}"/>`;
  return `  <url><loc>${locUrl(l, s)}</loc>${mod ? `<lastmod>${mod}</lastmod>` : ''}${alts}</url>`;
};
// blog: o hub só entra no sitemap quando há post; cada post com a data de atualização do frontmatter
const blogUrls = POSTS.length ? [`  <url><loc>${SITE}/blog/</loc><lastmod>${POSTS.map((p) => p.updated).sort().pop()}</lastmod></url>`,
  ...POSTS.map((p) => `  <url><loc>${SITE}/blog/${p.slug}/</loc><lastmod>${p.updated}</lastmod></url>`)] : [];
write('sitemap.xml', `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n${LANGS.flatMap((l) => ['', 'privacy/'].map((s) => xurl(l, s))).concat(blogUrls).join('\n')}\n</urlset>\n`);
// /llms.txt: resumo do jogo e das páginas principais para assistentes de IA (texto puro, inglês)
write('llms.txt', [
  '# Runemoire', '',
  '> Runemoire is a pixel-art roguelike deckbuilder for PC (Windows, Steam page coming soon) by Daniel Cortez / DC Solutions. Formerly known as Grimoire.', '',
  'Pick the Warrior, Mage or Rogue, walk a cursed road of six acts and fight with a deck you build along the way. Stack passive jokers into chain combos, read each enemy’s intent and break the signature curse of every boss, then push into Endless and climb Seals 1 to 10.', '',
  `Facts: 3 classes, 6 acts and biomes, 42 creatures, ${GAME.cardCounts?.total ?? 145} cards, 37 achievements, 5 languages (English, Brazilian Portuguese, Spanish, French, German). Release date and price: not announced.`, '',
  '## Key pages', '',
  `- [Home (English)](${SITE}/): the game's own title screen, with a text summary, the gameplay trailer and an FAQ below it`,
  ...LANGS.slice(1).map((l) => `- [Home (${l.self})](${SITE}/${l.prefix}/)`),
  `- [Gameplay trailer (MP4, 69 s)](${SITE}/media/runemoire-gameplay.mp4)`,
  `- [Privacy](${SITE}/privacy/): only the email left for the launch notice is stored; usage analytics with Microsoft Clarity (session recordings and heatmaps)`, '',
  '## Blog', '',
  `- [Blog hub](${SITE}/blog/)${POSTS.length ? '' : ': first posts coming soon'}`,
  ...POSTS.map((p) => `- [${p.title}](${SITE}/blog/${p.slug}/): ${p.desc}`), '',
  '## Contact', '',
  `- Press and questions: ${CONF.contact}`, '',
].join('\n'));
// /unsubscribe/ fica liberado no robots para o Google ler o noindex da página
write('robots.txt', `User-agent: *\nAllow: /\nSitemap: ${SITE}/sitemap.xml\n`);
write('site.webmanifest', JSON.stringify({ name: 'Runemoire', short_name: 'Runemoire', start_url: '/', display: 'standalone', background_color: '#0c0a10', theme_color: '#0c0a10', icons: [192, 512].map((s) => ({ src: `/img/brand/icon_${s}.png`, sizes: `${s}x${s}`, type: 'image/png' })) }));

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

// uma arte OG só (as 5 por idioma eram o mesmo arquivo) e o apple-touch-icon na raiz (cópia do selo de 180 px)
fs.copyFileSync(path.join(P, 'img/og/og_en.png'), path.join(D, 'img/og/og.png'));
for (const f of fs.readdirSync(path.join(D, 'img/og'))) if (f !== 'og.png') fs.rmSync(path.join(D, 'img/og', f));
fs.copyFileSync(path.join(P, 'img/brand/icon_180.png'), path.join(D, 'apple-touch-icon.png'));

// CSP: o CSS embutido entra no style-src pelo hash (o mesmo bloco em todas as páginas)
const styles = new Set();
(function scan(dir) {
  for (const f of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, f.name);
    if (f.isDirectory()) { if (!['img', 'media', 'fonts', 'assets'].includes(f.name)) scan(p); continue; }
    if (f.name.endsWith('.html')) for (const m of fs.readFileSync(p, 'utf8').matchAll(/<style>([\s\S]*?)<\/style>/g)) styles.add(m[1]);
  }
})(D);
const hashes = [...styles].map((c) => `'sha256-${crypto.createHash('sha256').update(c, 'utf8').digest('base64')}'`);
fs.writeFileSync(path.join(R, 'worker/csp.gen.js'), `// gerado por tools/build.mjs: hash do CSS embutido nas páginas (style-src da CSP)\nexport const STYLE_HASHES = ${JSON.stringify(hashes.join(' '))};\n`);
console.log('style hashes', hashes.length);

const size = (rel) => fs.statSync(path.join(D, rel.replace(/^\//, ''))).size;
const kb = (n) => (n / 1024).toFixed(1) + ' KB';
let total = 0; (function sum(d) { for (const f of fs.readdirSync(d, { withFileTypes: true })) { const p = path.join(d, f.name); if (f.isDirectory()) sum(p); else total += fs.statSync(p).size; } })(D);
console.log('JS', kb(size(JS)), '| CSS', kb(size(CSS)), '| index.html', kb(size('index.html')), '| dist', (total / 1048576).toFixed(1) + ' MB', '| webp', conv.size);
console.log('build ok', crypto.createHash('sha256').update(fs.readFileSync(path.join(D, 'index.html'))).digest('hex').slice(0, 12));
