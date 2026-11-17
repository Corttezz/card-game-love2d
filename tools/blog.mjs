// Blog do runemoire.com nos 5 idiomas: o post em inglês fica em content/posts/*.md e cada tradução em
// content/posts/<prefixo>/*.md (pt, es, fr, de), com `traducao_de: <slug en>`, publicada em /<prefixo>/blog/<slug>/.
// O build gera /blog/<slug>/ e o hub /blog/, com JSON-LD (Article, FAQPage quando há FAQ, BreadcrumbList),
// canonical própria e o formulário "Me avise" no fim (mesma tabela D1, source = blog:<slug>).
// Aceita as chaves do FLUXO-POSTS da SEO & Growth (titulo, descricao, palavra_chave, categoria, data, imagem,
// links_internos, cta) e os nomes em inglês. A amostra (content/sample) só entra com BLOG_SAMPLE=1, na prévia.
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { marked } from 'marked';
import { head, esc, OG, LANGS, home } from './page.mjs';

const R = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const CONFIG = JSON.parse(fs.readFileSync(path.join(R, 'src/data/config.json'), 'utf8'));
const S = CONFIG.site;
const EN = LANGS[0];
const SEAL = `${S}/img/brand/icon_512.png`;

// ---------------- leitura ----------------
function front(src, file) {
  const m = /^\uFEFF?---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/.exec(src);
  if (!m) throw new Error(`${file}: sem frontmatter (--- ... ---)`);
  const fm = {};
  for (const line of m[1].split(/\r?\n/)) {
    const k = /^([A-Za-z_][\w-]*)\s*:\s*(.*)$/.exec(line);
    if (!k) continue;
    let v = k[2].trim();
    if (v.startsWith('[')) { try { v = JSON.parse(v); } catch { v = v.slice(1, -1).split(',').map((x) => x.trim().replace(/^["']|["']$/g, '')).filter(Boolean); } }
    else if (/^".*"$/.test(v)) { try { v = JSON.parse(v); } catch { v = v.slice(1, -1); } }
    else if (/^'.*'$/.test(v)) v = v.slice(1, -1).replace(/''/g, "'");
    fm[k[1].toLowerCase()] = v;
  }
  return { fm, body: m[2] };
}

const pick = (fm, ...keys) => { for (const k of keys) if (fm[k] != null && fm[k] !== '') return fm[k]; return undefined; };
const FAQ_H2 = /^(faq|frequently asked questions|questions|perguntas frequentes|common questions|preguntas frecuentes|questions fréquentes|foire aux questions|häufige fragen|häufig gestellte fragen)(?![\p{L}])/iu;

// textos da interface do blog por idioma
export const BL = {
  en: { hub: 'Runemoire blog', hubTitle: 'Blog — Runemoire', hubDesc: 'The Runemoire blog: notes on the pixel-art roguelike deckbuilder, its cards, classes, bosses and the road to launch.', empty: 'The first pages of this blog are still being written. Leave your email below and the grimoire will write to you when Runemoire launches.', next: 'Read next', coverAlt: 'Runemoire: the title screen of the game', locale: 'en-US', crumbs: 'Breadcrumb' },
  pt_BR: { hub: 'Blog do Runemoire', hubTitle: 'Blog — Runemoire', hubDesc: 'O blog do Runemoire: notas sobre o roguelike deckbuilder em pixel art, suas cartas, classes, chefes e o caminho até o lançamento.', empty: 'As primeiras páginas deste blog ainda estão sendo escritas. Deixe seu e-mail abaixo e o grimório escreve para você quando o Runemoire for lançado.', next: 'Leia também', coverAlt: 'Runemoire: a tela de título do jogo', locale: 'pt-BR', crumbs: 'Navegação estrutural' },
  es: { hub: 'Blog de Runemoire', hubTitle: 'Blog — Runemoire', hubDesc: 'El blog de Runemoire: notas sobre el roguelike deckbuilder en pixel art, sus cartas, clases, jefes y el camino hasta el lanzamiento.', empty: 'Las primeras páginas de este blog aún se están escribiendo. Deja tu correo abajo y el grimorio te escribirá cuando Runemoire salga.', next: 'Sigue leyendo', coverAlt: 'Runemoire: la pantalla de título del juego', locale: 'es-ES', crumbs: 'Ruta de navegación' },
  fr: { hub: 'Blog de Runemoire', hubTitle: 'Blog — Runemoire', hubDesc: 'Le blog de Runemoire : notes sur le roguelike deckbuilder en pixel art, ses cartes, ses classes, ses boss et la route vers la sortie.', empty: 'Les premières pages de ce blog sont encore en cours d’écriture. Laissez votre e-mail ci-dessous et le grimoire vous écrira à la sortie de Runemoire.', next: 'À lire aussi', coverAlt: 'Runemoire : l’écran titre du jeu', locale: 'fr-FR', crumbs: 'Fil d’Ariane' },
  de: { hub: 'Runemoire-Blog', hubTitle: 'Blog — Runemoire', hubDesc: 'Der Runemoire-Blog: Notizen zum Pixel-Art-Roguelike-Deckbuilder, seinen Karten, Klassen, Bossen und dem Weg zum Release.', empty: 'Die ersten Seiten dieses Blogs werden noch geschrieben. Hinterlass unten deine E-Mail, und das Grimoire schreibt dir, wenn Runemoire erscheint.', next: 'Weiterlesen', coverAlt: 'Runemoire: der Titelbildschirm des Spiels', locale: 'de-DE', crumbs: 'Brotkrumen' },
};
export const blogHome = (l) => `${home(l)}blog/`;

// largura e altura de PNG/JPEG/WebP, para a capa ter width/height (evita a página pular ao carregar)
function imgSize(f) {
  const b = fs.readFileSync(f);
  if (b.readUInt32BE(0) === 0x89504e47) return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) };
  if (b.toString('ascii', 0, 4) === 'RIFF' && b.toString('ascii', 8, 12) === 'WEBP') {
    const k = b.toString('ascii', 12, 16);
    if (k === 'VP8X') return { w: 1 + b.readUIntLE(24, 3), h: 1 + b.readUIntLE(27, 3) };
    if (k === 'VP8 ') return { w: b.readUInt16LE(26) & 0x3fff, h: b.readUInt16LE(28) & 0x3fff };
    if (k === 'VP8L') { const v = b.readUInt32LE(21); return { w: 1 + (v & 0x3fff), h: 1 + ((v >> 14) & 0x3fff) }; }
  }
  if (b[0] === 0xff && b[1] === 0xd8) {
    for (let i = 2; i < b.length - 9;) {
      if (b[i] !== 0xff) { i++; continue; }
      const m = b[i + 1];
      if (m >= 0xc0 && m <= 0xcf && m !== 0xc4 && m !== 0xc8 && m !== 0xcc) return { w: b.readUInt16BE(i + 7), h: b.readUInt16BE(i + 5) };
      i += 2 + b.readUInt16BE(i + 2);
    }
  }
  return null;
}

function parsePost(file, l = EN) {
  const { fm, body } = front(fs.readFileSync(file, 'utf8'), path.basename(file));
  const slug = String(pick(fm, 'slug') || path.basename(file, '.md'));
  const date = String(pick(fm, 'date', 'data') || '');
  const p = {
    file, slug, date,
    updated: String(pick(fm, 'updated', 'atualizado', 'date', 'data') || ''),
    title: String(pick(fm, 'title', 'titulo', 'título') || ''),
    desc: String(pick(fm, 'meta', 'description', 'descricao', 'descrição') || ''),
    keyword: String(pick(fm, 'keyword', 'palavra_chave') || ''),
    category: String(pick(fm, 'category', 'categoria') || 'Runemoire'),
    links: [].concat(pick(fm, 'internal_links', 'links_internos', 'links') || []).map(String),
    cta: String(pick(fm, 'cta') || ''),
    lang: String(pick(fm, 'lang', 'idioma') || l.html),
    key: String(pick(fm, 'traducao_de', 'translation_of') || (l === EN ? slug : '')),
    l,
    url: `${blogHome(l)}${slug}/`,
  };
  const errs = [];
  if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(slug)) errs.push(`slug inválido "${slug}"`);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) errs.push(`data inválida "${date}" (AAAA-MM-DD)`);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(p.updated)) p.updated = date;
  if (!p.title) errs.push('sem title/titulo');
  if (!p.desc) errs.push('sem meta/descricao');
  const lg = p.lang.toLowerCase().replace('_', '-');
  if (lg !== l.html.toLowerCase() && lg !== l.code.toLowerCase().replace('_', '-') && !(l === EN && lg.startsWith('en'))) errs.push(`idioma "${p.lang}" numa pasta de ${l.html}`);
  if (!p.key) errs.push('tradução sem traducao_de (slug do post em inglês)');
  if (errs.length) throw new Error(`${path.basename(file)}: ${errs.join('; ')}`);

  // capa: "/caminho/arquivo.png | texto alternativo" vira a capa; texto sem caminho (sugestão) usa a arte do jogo
  const cv = String(pick(fm, 'cover', 'imagem', 'image') || '');
  const cm = /^(\/[^\s|]+)\s*(?:\|\s*(.+))?$/.exec(cv);
  p.cover = cm ? { src: cm[1], alt: (cm[2] || pick(fm, 'cover_alt', 'imagem_alt') || p.title).trim().replace(/^alt\s*:\s*/i, ''), w: null, h: null }
    : { src: OG, alt: (BL[l.code] || BL.en).coverAlt, w: 1200, h: 630 };
  if (cm && !fs.existsSync(path.join(R, 'public', cm[1]))) throw new Error(`${path.basename(file)}: capa ${cm[1]} não existe em public/`);
  if (cm) Object.assign(p.cover, imgSize(path.join(R, 'public', cm[1])) || {});

  // corpo: tira comentários (<!-- verificar: ... -->), o H1 vem do arquivo (ou do title)
  let md = body.replace(/<!--[\s\S]*?-->/g, '').trim();
  const h1 = /^#\s+(.+?)\s*#*\s*$/m.exec(md);
  p.h1 = h1 ? h1[1].trim() : p.title;
  if (h1) md = md.replace(h1[0], '').trim();

  // FAQ: o H2 "FAQ"/"Perguntas frequentes"; cada H3 (ou linha **pergunta?**) é uma pergunta e o texto até a próxima é a resposta
  p.faq = [];
  const tokens = marked.lexer(md);
  let inFaq = false, cur = null;
  for (const t of tokens) {
    if (t.type === 'heading' && t.depth <= 2) { inFaq = t.depth === 2 && FAQ_H2.test(t.text.trim()); cur = null; continue; }
    if (!inFaq) continue;
    const boldQ = t.type === 'paragraph' && /^\*\*(.+?)\*\*\s*$/.exec(t.raw.trim().split('\n')[0]);
    if ((t.type === 'heading' && t.depth === 3) || boldQ) {
      cur = { q: (boldQ ? boldQ[1] : t.text).trim(), a: [] };
      p.faq.push(cur);
      if (boldQ) { const rest = t.raw.trim().split('\n').slice(1).join('\n').trim(); if (rest) cur.a.push(rest); }
      continue;
    }
    if (cur && t.type !== 'space') cur.a.push(t.raw.trim());
  }
  p.faq = p.faq.filter((f) => f.a.length).map((f) => ({ q: f.q, a: plain(marked.parse(f.a.join('\n\n'))) }));
  p.html = marked.parse(md).replace(/<img /g, '<img loading="lazy" decoding="async" ');
  p.words = plain(p.html).split(/\s+/).filter(Boolean).length;
  return p;
}
const plain = (html) => html.replace(/<[^>]+>/g, ' ').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/\s+/g, ' ').trim();

export function loadPosts({ sample = false } = {}) {
  const dirs = [[path.join(R, 'content/posts'), EN]].concat(sample ? [[path.join(R, 'content/sample'), EN]] : [])
    .concat(LANGS.slice(1).map((l) => [path.join(R, 'content/posts', l.prefix), l]));
  const posts = [];
  for (const [d, l] of dirs) if (fs.existsSync(d)) for (const f of fs.readdirSync(d).filter((x) => x.endsWith('.md')).sort()) posts.push(parsePost(path.join(d, f), l));
  const seen = new Set();
  for (const p of posts) { if (seen.has(p.url)) throw new Error(`slug repetido: ${p.url}`); seen.add(p.url); }
  const en = new Set(posts.filter((p) => p.l === EN).map((p) => p.slug));
  for (const p of posts) if (p.l !== EN && !en.has(p.key)) throw new Error(`${p.url}: traducao_de "${p.key}" não é um post em inglês`);
  return posts.sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : a.slug.localeCompare(b.slug)));
}

// ---------------- páginas ----------------
const fmtDate = (d, l = EN) => new Date(d + 'T12:00:00Z').toLocaleDateString((BL[l.code] || BL.en).locale, { year: 'numeric', month: 'long', day: 'numeric', timeZone: 'UTC' });
const abs = (u) => (/^https?:/.test(u) ? u : S + u);
const ldTag = (o) => `<script type="application/ld+json">${JSON.stringify(o).replace(/</g, '\\u003c')}</script>`;
const crumbs = (items) => ({ '@type': 'BreadcrumbList', itemListElement: items.map(([name, url], i) => ({ '@type': 'ListItem', position: i + 1, name, item: abs(url) })) });
const publisher = { '@type': 'Organization', '@id': `${S}/#org`, name: 'DC Solutions', url: 'https://dcsolutions.app/', logo: { '@type': 'ImageObject', url: SEAL } };
const priv = (l) => `${home(l)}privacy/`;

function notifyForm(t, l, source) {
  return `<section class="cta" id="notify" aria-labelledby="notify-t"><h2 id="notify-t">${esc(t.notifyTitle)}</h2><p>${esc(t.achDesc)}</p>
<form class="notify" method="post" action="/api/notify" novalidate data-source="${esc(source)}" data-variant="blog" data-clarity-mask="true"><label class="sr" for="email">${esc(t.notifyLabel)}</label>
<input id="email" type="email" name="email" required autocomplete="email" inputmode="email" placeholder="${esc(t.notifyPlaceholder)}">
<div class="hp" aria-hidden="true"><label>Website <input type="text" name="website" tabindex="-1" autocomplete="off"></label></div>
<button class="mbtn sel" type="submit">${esc(t.notifyLaunch)}</button><p class="msg" role="status" aria-live="polite"></p></form>
<p class="fine"><a href="${priv(l)}">${esc(t.privacy)}</a></p></section>`;
}

// alts: [[lang, caminho]] da mesma página nos idiomas (hreflang + x-default em inglês + seletor de idioma no rodapé)
function shell(t, l, ctx, { title, desc, pathname, noindex = false, ogType = 'website', ogImage = OG, ld = [], body, alts = [] }) {
  const client = { lang: l.code, unsubPath: `${home(l)}unsubscribe/`, boot: {}, t: { sending: t.sending, notifyOk: t.notifyOk, notifyBad: t.notifyBad, notifyRate: t.notifyRate, notifyNet: t.notifyNet, unsubLink: t.unsubLink } };
  const enAlt = alts.find(([x]) => x === EN);
  const altLinks = noindex || !alts.length ? '' : alts.map(([x, u]) => `<link rel="alternate" hreflang="${x.html}" href="${S}${u}">`).join('') + (enAlt ? `<link rel="alternate" hreflang="x-default" href="${S}${enAlt[1]}">` : '');
  const langs = alts.length > 1 ? `\n<p class="fine langs">${alts.map(([x, u]) => `<a href="${u}" lang="${x.html}" hreflang="${x.html}"${x === l ? ' aria-current="page"' : ''}>${x.self}</a>`).join(' · ')}</p>` : '';
  return head(t, l, ctx, { title, desc, path: pathname, noindex, preload: false, alts: false, ogType, ogImage, extra: altLinks }) +
    `<script type="application/json" id="rm-data">${JSON.stringify(client).replace(/</g, '\\u003c')}</script>
${ld.map(ldTag).join('\n')}
</head><body class="simple blog"><noscript><iframe src="https://www.googletagmanager.com/ns.html?id=GTM-5NVWLLNZ" height="0" width="0" style="display:none;visibility:hidden" title="GTM"></iframe></noscript><main id="main"><div class="frame9 page prose">
<a class="home" href="${home(l)}"><img class="px" src="/img/v3/wordmark.png" width="289" height="48" alt="Runemoire"></a>
${body}
<p class="fine foot"><a href="${home(l)}">Runemoire</a> · <a href="${blogHome(l)}">Blog</a> · <a href="${priv(l)}">${esc(t.privacy)}</a> · <a href="https://dcsolutions.app/">DC Solutions</a></p>${langs}
</div></main></body></html>`;
}

// sibs: o mesmo post nos outros idiomas (mesma chave traducao_de)
export function renderPost(p, t, ctx, sibs = [p]) {
  const l = p.l, B = BL[l.code] || BL.en, url = p.url;
  const inBody = (u) => p.html.includes(`href="${u}"`) || p.html.includes(`href="${S}${u}"`);
  const next = p.links.filter((u) => u.startsWith('/') && !inBody(u));
  const ld = [
    { '@context': 'https://schema.org', '@type': 'Article', '@id': `${S}${url}#article`, headline: p.title, description: p.desc, image: [abs(p.cover.src)],
      datePublished: p.date, dateModified: p.updated, inLanguage: l.html, articleSection: p.category, ...(p.keyword ? { keywords: p.keyword } : {}), wordCount: p.words,
      author: { '@type': 'Person', name: 'Daniel Cortez', url: `${S}/` }, publisher, mainEntityOfPage: { '@type': 'WebPage', '@id': S + url },
      about: { '@type': 'VideoGame', '@id': `${S}/#game`, name: 'Runemoire' } },
    { '@context': 'https://schema.org', ...crumbs([['Runemoire', home(l)], ['Blog', blogHome(l)], [p.title, url]]) },
  ];
  if (p.faq.length) ld.push({ '@context': 'https://schema.org', '@type': 'FAQPage', inLanguage: l.html, mainEntity: p.faq.map((f) => ({ '@type': 'Question', name: f.q, acceptedAnswer: { '@type': 'Answer', text: f.a } })) });
  const cover = `<img class="cover" src="${p.cover.src}"${p.cover.w ? ` width="${p.cover.w}" height="${p.cover.h}"` : ''} alt="${esc(p.cover.alt)}" fetchpriority="high">`;
  const body = `<nav class="crumbs" aria-label="${esc(B.crumbs)}"><a href="${home(l)}">Runemoire</a> › <a href="${blogHome(l)}">Blog</a> › <span aria-current="page">${esc(p.category)}</span></nav>
<article><h1>${esc(p.h1)}</h1><p class="meta"><time datetime="${p.date}">${fmtDate(p.date, l)}</time> · ${esc(p.category)}</p>
${cover}
${p.html}
${next.length ? `<h2>${esc(B.next)}</h2><ul>${next.map((u) => `<li><a href="${esc(u)}">${esc(u)}</a></li>`).join('')}</ul>` : ''}
</article>
${notifyForm(t, l, `blog:${p.slug}`)}`;
  const alts = LANGS.map((x) => sibs.find((s) => s.l === x)).filter(Boolean).map((s) => [s.l, s.url]);
  return shell(t, l, ctx, { title: `${p.title}`, desc: p.desc, pathname: url, ogType: 'article', ogImage: p.cover.src, ld, body, alts });
}

// hubs: { lang -> posts } para o hreflang só entre hubs com post
export function renderHub(posts, t, ctx, l = EN, hubs = null) {
  const B = BL[l.code] || BL.en;
  const empty = !posts.length;
  const list = empty
    ? `<p>${esc(B.empty)}</p>`
    : `<ul class="posts">${posts.map((p) => `<li><a href="${p.url}"><h2>${esc(p.title)}</h2></a><p class="meta"><time datetime="${p.date}">${fmtDate(p.date, l)}</time> · ${esc(p.category)}</p><p>${esc(p.desc)}</p></li>`).join('')}</ul>`;
  const ld = empty ? [] : [
    { '@context': 'https://schema.org', '@type': 'Blog', '@id': `${S}${blogHome(l)}#blog`, name: B.hub, url: `${S}${blogHome(l)}`, inLanguage: l.html, publisher,
      blogPost: posts.map((p) => ({ '@type': 'BlogPosting', headline: p.title, url: `${S}${p.url}`, datePublished: p.date, inLanguage: l.html })) },
    { '@context': 'https://schema.org', ...crumbs([['Runemoire', home(l)], ['Blog', blogHome(l)]]) },
  ];
  const body = `<nav class="crumbs" aria-label="${esc(B.crumbs)}"><a href="${home(l)}">Runemoire</a> › <span aria-current="page">Blog</span></nav>
<h1>${esc(B.hub)}</h1>
${list}
${notifyForm(t, l, 'blog:hub')}`;
  const alts = LANGS.filter((x) => !hubs || hubs[x.code]?.length).map((x) => [x, blogHome(x)]);
  // vazio: fora do índice e do sitemap até o primeiro post
  return shell(t, l, ctx, { title: B.hubTitle, desc: B.hubDesc, pathname: blogHome(l), noindex: empty, ld, body, alts });
}
