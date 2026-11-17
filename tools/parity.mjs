// Paridade de idiomas (Daniel, 17/11/2026: "todas as opções de tudo na LP para todos os idiomas, e todos os artigos
// em todos os idiomas"). Lê o dist/ já montado e compara cada idioma com o inglês: itens do menu, painéis, seções e
// rodapé da home, páginas, seções da privacidade, textos do i18n, posts do blog (cada post en tem tradução, com as
// mesmas seções e perguntas) e URLs no sitemap. Qualquer idioma com menos que o en derruba o build.
// uso: node tools/parity.mjs [dist]  (o build.mjs chama sozinho no fim)
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { LANGS } from './page.mjs';

const R = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const count = (s, re) => (s.match(re) || []).length;
const between = (s, a, b) => { const i = s.indexOf(a); if (i < 0) return ''; const j = s.indexOf(b, i); return s.slice(i, j < 0 ? undefined : j); };

function pages(dir, base = '') {
  const out = [];
  if (!fs.existsSync(dir)) return out;
  for (const f of fs.readdirSync(dir, { withFileTypes: true })) {
    const rel = base ? `${base}/${f.name}` : f.name;
    if (f.isDirectory()) { if (!['img', 'media', 'fonts', 'assets', 'js', ...LANGS.map((l) => l.prefix).filter(Boolean)].includes(f.name)) out.push(...pages(path.join(dir, f.name), rel)); }
    else if (f.name.endsWith('.html')) out.push(rel);
  }
  return out;
}

export function measure(D, ignore = []) {
  const sitemap = fs.readFileSync(path.join(D, 'sitemap.xml'), 'utf8');
  const locs = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => new URL(m[1]).pathname).filter((u) => !u.includes('/blog/sample-'));
  const T = Object.fromEntries(LANGS.map((l) => [l.code, JSON.parse(fs.readFileSync(path.join(R, `src/i18n/${l.code}.json`), 'utf8'))]));
  const rows = {};
  for (const l of LANGS) {
    const root = l.prefix ? path.join(D, l.prefix) : D;
    const pre = l.prefix ? `/${l.prefix}/` : '/';
    const home = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
    const about = between(home, '<main class="about"', '</main>');
    const priv = fs.readFileSync(path.join(root, 'privacy/index.html'), 'utf8');
    const all = pages(root).filter((p) => (!p.startsWith('blog/') || p === 'blog/index.html') && !ignore.includes(p.split('/')[0]));
    const posts = pages(path.join(root, 'blog')).filter((p) => p !== 'index.html' && !p.startsWith('sample-')); // a amostra (só na prévia) não conta
    const art = Object.fromEntries(posts.map((p) => {
      const h = fs.readFileSync(path.join(root, 'blog', p), 'utf8');
      const a = between(h, '<article>', '</article>');
      const key = (h.match(/hreflang="en" href="[^"]*\/blog\/([^/"]+)\//) || [])[1] || p.split('/')[0];
      return [key, { url: `${pre}blog/${p.replace(/index\.html$/, '')}`, h2: count(a, /<h2[\s>]/g), h3: count(a, /<h3[\s>]/g), faq: count(h, /"@type":"Question"/g), tables: count(a, /<tr>/g) }];
    }));
    rows[l.code] = {
      menu: count(between(home, '<nav class="menu"', '</nav>'), /class="mbtn"/g),
      panels: count(home, /class="panel"/g),
      sections: count(about, /<h[23][\s>]/g),
      footer: count(between(about, '<p class="fine">', '</div>'), /<a /g),
      pages: all.length,
      pageList: all.sort(),
      privSections: count(priv, /<h2[\s>]/g),
      i18n: Object.keys(T.en).filter((k) => k in T[l.code]).length,
      articles: posts.length,
      art,
      sitemap: locs.filter((u) => (l.prefix ? u.startsWith(pre) : !LANGS.some((x) => x.prefix && u.startsWith(`/${x.prefix}/`)))).length,
    };
  }
  return rows;
}

// ignore: pastas de topo que só existem na prévia (PREVIEW_DIR), fora da comparação
export function check(D = path.join(R, 'dist'), { print = true, ignore = [] } = {}) {
  const rows = measure(D, ignore);
  const en = rows.en;
  const errs = [];
  const KEYS = ['menu', 'panels', 'sections', 'footer', 'pages', 'privSections', 'i18n', 'articles', 'sitemap'];
  for (const l of LANGS.slice(1)) {
    const r = rows[l.code];
    for (const k of KEYS) if (r[k] < en[k]) errs.push(`${l.short}: ${k} ${r[k]} < en ${en[k]}`);
    for (const p of en.pageList) if (!r.pageList.includes(p)) errs.push(`${l.short}: falta a página ${p}`);
    for (const [key, a] of Object.entries(en.art)) {
      const b = r.art[key];
      if (!b) { errs.push(`${l.short}: falta a tradução do post ${key}`); continue; }
      for (const k of ['h2', 'h3', 'faq', 'tables']) if (b[k] < a[k]) errs.push(`${l.short}: post ${key} com ${k} ${b[k]} < en ${a[k]}`);
    }
  }
  if (print) {
    const head = ['', ...KEYS];
    console.log('paridade ' + head.join(' | '));
    for (const l of LANGS) console.log(`paridade ${l.short} | ${KEYS.map((k) => rows[l.code][k]).join(' | ')}`);
  }
  if (errs.length) throw new Error('paridade de idiomas falhou:\n  ' + errs.join('\n  '));
  if (print) console.log('paridade ok: nenhum idioma com menos que o en');
  return rows;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { check(process.argv[2] ? path.resolve(process.argv[2]) : undefined); } catch (e) { console.error(e.message); process.exit(1); }
}
