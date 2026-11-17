// runemoire.com v3: o site É a tela de título do jogo (Daniel, 11/11/2026, no modelo do inscryption.com).
// Uma cena só, sem rolagem: a capela do menu do jogo (camadas do próprio jogo, velas vivas), as duas cartas
// flutuando que viram, o selo e o logotipo, e o menu com os rótulos do jogo. Cada item abre um painel no estilo do jogo.
// Sem JS os itens do menu são âncoras (#play, #collection, ...) e os painéis abrem por :target.
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const R = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const CONFIG = JSON.parse(fs.readFileSync(path.join(R, 'src/data/config.json'), 'utf8'));
const UI = JSON.parse(fs.readFileSync(path.join(R, 'src/data/ui_game.json'), 'utf8'));
const BOOT = JSON.parse(fs.readFileSync(path.join(R, 'src/data/boot_i18n.json'), 'utf8'));

export const LANGS = [
  { code: 'en', prefix: '', html: 'en', self: 'English', short: 'EN', og: 'en_US' },
  { code: 'pt_BR', prefix: 'pt', html: 'pt-BR', self: 'Português', short: 'PT', og: 'pt_BR' },
  { code: 'es', prefix: 'es', html: 'es', self: 'Español', short: 'ES', og: 'es_ES' },
  { code: 'fr', prefix: 'fr', html: 'fr', self: 'Français', short: 'FR', og: 'fr_FR' },
  { code: 'de', prefix: 'de', html: 'de', self: 'Deutsch', short: 'DE', og: 'de_DE' },
];
export const home = (l) => (l.prefix ? `/${l.prefix}/` : '/');
export const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = (s, v = {}) => String(s ?? '').replace(/\{(\w+)\}/g, (m, k) => (k in v ? v[k] : m));
const loc = (o, l) => (o && typeof o === 'object' ? o[l.code] ?? o.en : o);
const ui = (l, k) => UI[l.code]?.[k] ?? UI.en[k];

// cartas renderizadas pelo próprio jogo (CardFrame, exportadas por tools/preview_cards em cada idioma)
export const CARD_POOL = fs.readdirSync(path.join(R, 'public/img/gamecards/en')).filter((f) => f.endsWith('.png')).map((f) => f.slice(0, -4)).sort();
const COLLECTION_CARDS = ['warrior_strike', 'mage_zap', 'rogue_executioner', 'joker_001'];
const SHOTS = ['03_road_battle', '06_road_fork', '05_shop'];
const SHOT_ALT = {
  '03_road_battle': { en: 'Combat on the road', pt_BR: 'Combate na estrada', es: 'Combate en el camino', fr: 'Combat sur la route', de: 'Kampf auf der Straße' },
  '06_road_fork': { en: 'The map: a fork in the road', pt_BR: 'O mapa: uma bifurcação', es: 'El mapa: una bifurcación', fr: 'La carte : une bifurcation', de: 'Die Karte: eine Weggabelung' },
  '05_shop': { en: 'The shop', pt_BR: 'A loja', es: 'La tienda', fr: 'La boutique', de: 'Der Laden' },
};
const cardSrc = (l, id) => `/img/gamecards/${l.code}/${id}.png`;

// o trailer de gameplay (o mesmo do painel Jogar, no site desde a v1): duração do arquivo e data de publicação
const TRAILER = { src: '/media/runemoire-gameplay.mp4', poster: '/media/runemoire-gameplay.jpg', uploadDate: '2026-11-10', duration: 'PT1M9S' };
export const OG = '/img/og/og.png'; // uma arte só nos 5 idiomas (eram 5 cópias idênticas)
const LANG_TAGS = LANGS.map((x) => x.html);
const cardName = (G, l, id) => { const c = (G.cards || []).find((x) => x.id === id); return c ? loc(c.name, l) : 'Runemoire'; };
// o CSS vai embutido no <head> (sem pedido bloqueante); o hash dele entra no style-src da CSP (worker/csp.gen.js)
const styleTag = (ctx) => (ctx.CSSTEXT != null ? `<style>${ctx.CSSTEXT}</style>` : `<link rel="stylesheet" href="${ctx.CSS}">`);

export function head(t, l, ctx, { title, desc, path: p, noindex = false, script = true, preload = true, alts: withAlts = true, ogType = 'website', ogImage = OG, extra = '' }) {
  const url = CONFIG.site + p;
  const alts = noindex || !withAlts ? '' : LANGS.map((x) => `<link rel="alternate" hreflang="${x.html}" href="${CONFIG.site}${home(x)}${p.replace(home(l), '')}">`).join('') +
    `<link rel="alternate" hreflang="x-default" href="${CONFIG.site}/${p.replace(home(l), '')}">`;
  return `<!doctype html><html lang="${l.html}" class="no-js"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${esc(title)}</title><meta name="description" content="${esc(desc)}">
${noindex ? '<meta name="robots" content="noindex">' : `<link rel="canonical" href="${url}">${alts}`}
<meta name="theme-color" content="#0c0a10"><meta name="color-scheme" content="dark">
<meta property="og:type" content="${ogType}"><meta property="og:site_name" content="Runemoire"><meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(desc)}"><meta property="og:url" content="${url}"><meta property="og:image" content="${/^https?:/.test(ogImage) ? ogImage : CONFIG.site + ogImage}">${extra}
<meta property="og:image:width" content="1200"><meta property="og:image:height" content="630"><meta property="og:locale" content="${l.og}"><meta name="twitter:card" content="summary_large_image">
<link rel="icon" href="/favicon.ico" sizes="any"><link rel="icon" type="image/png" sizes="32x32" href="/img/brand/icon_32.png"><link rel="apple-touch-icon" href="/img/brand/icon_180.png">
<link rel="manifest" href="/site.webmanifest">
${preload ? '<link rel="preload" href="/img/v3b/computer.png" as="image" fetchpriority="high">' : ''}<link rel="preload" href="/fonts/pixel.woff2" as="font" type="font/woff2" crossorigin>
${styleTag(ctx)}<script src="/js/gtm.js?v=1" async></script><script src="/js/clarity.js?v=8" async></script>${script ? `<script type="module" src="${ctx.JS}"></script>` : ''}`;
}

const panel = (id, title, body, t, l, extra = '') => `<section class="panel" id="${id}" role="dialog" aria-modal="true" aria-labelledby="${id}-t"${extra}>
<div class="frame9"><h2 id="${id}-t">${esc(title)}</h2><div class="pbody">${body}</div>
<a class="back" href="#" data-close>${esc(ui(l, 'settings.back'))}</a></div></section>`;

export function renderHome(t, l, ctx) {
  const G = ctx.GAME;
  const shots = (l.code === 'pt_BR' ? G.shots.pt_BR : G.shots.en).filter((s) => SHOTS.includes(s.id)).sort((a, b) => SHOTS.indexOf(a.id) - SHOTS.indexOf(b.id));
  const items = [['play', 'menu.play'], ['collection', 'menu.collection'], ['achievements', 'menu.achievements'], ['settings', 'menu.settings'], ['quit', 'menu.quit']];
  const langs = LANGS.map((x) => `<a href="${home(x)}#settings" lang="${x.html}" hreflang="${x.html}"${x.code === l.code ? ' aria-current="true"' : ''}>${x.self}</a>`).join('');
  const toggle = (id, label, on = false) => `<div class="opt"><span id="${id}-l">${esc(label)}</span><button class="sw" type="button" id="${id}" role="switch" aria-checked="${on}" aria-labelledby="${id}-l"><span class="on">${esc(t.onLabel)}</span><span class="off">${esc(t.offLabel)}</span></button></div>`;
  const B = BOOT.t[l.code] || BOOT.t.en;
  // a abertura do jogo é desenhada em canvas (porte do código do jogo); por cima ficam só elementos transparentes e acessíveis
  const body = `<canvas id="cv" aria-hidden="true"></canvas><canvas id="crt" aria-hidden="true"></canvas>
<button class="screenhit" id="screenhit" type="button" aria-label="${esc(t.enterLabel)}"></button>
<p class="hint" id="hint" aria-hidden="true">${esc(t.enterHint)}</p>
<div class="title" id="title" inert>
<nav class="menu" aria-label="Menu">${items.map(([id, k]) => `<a class="mbtn" href="#${id}" data-open="${id}">${esc(ui(l, k))}</a>`).join('')}</nav>
<button class="hang" type="button" data-i="0" aria-label="${esc(t.flipCard)}" aria-pressed="false"></button><button class="hang" type="button" data-i="1" aria-label="${esc(t.flipCard)}" aria-pressed="false"></button>
<a class="corner" id="priv" href="${home(l)}privacy/">${esc(t.privacy)}</a>
</div>
${panel('play', t.trailerPlay, `<div class="vid"><img src="/media/runemoire-gameplay.jpg" width="1280" height="720" alt="${esc(t.trailerPlay)}" loading="lazy" decoding="async"><button class="vplay" type="button" data-src="/media/runemoire-gameplay.mp4" aria-label="${esc(t.play)}: ${esc(t.trailerPlay)}"><span></span></button></div>`, t, l)}
${panel('collection', ui(l, 'collection.title'), `<p class="sub">${esc(t.cardsTitle)}</p><div class="cards">${COLLECTION_CARDS.map((id) => `<img class="px" src="${cardSrc(l, id)}" width="192" height="288" alt="${esc(cardName(G, l, id))}" loading="lazy" decoding="async">`).join('')}</div>
<p class="sub">${esc(t.screensTitle)}</p><div class="screens">${shots.map((s) => `<img src="${s.thumb}" width="960" height="540" alt="${esc(SHOT_ALT[s.id][l.code] || SHOT_ALT[s.id].en)}" loading="lazy" decoding="async">`).join('')}</div>`, t, l)}
${panel('achievements', ui(l, 'menu.achievements'), `<div class="ach"><img class="px icon" id="ach-icon" src="/img/v3/ach_locked.png" data-on="/img/v3/ach.png" width="128" height="128" alt=""><div><h3>${esc(t.achName)}</h3><p>${esc(t.achDesc)}</p></div></div>
<p class="prompt">${esc(t.achPrompt)}</p>
<form class="notify" method="post" action="/api/notify" novalidate data-clarity-mask="true"><label class="sr" for="email">${esc(t.notifyLabel)}</label>
<input id="email" type="email" name="email" required autocomplete="email" inputmode="email" placeholder="${esc(t.notifyPlaceholder)}">
<div class="hp" aria-hidden="true"><label>Website <input type="text" name="website" tabindex="-1" autocomplete="off"></label></div>
<button class="mbtn sel" type="submit">${esc(t.notifyLaunch)}</button><p class="msg" role="status" aria-live="polite"></p></form>
<p class="fine"><a href="${home(l)}privacy/">${esc(t.privacy)}</a></p>`, t, l)}
${panel('settings', ui(l, 'settings.title'), `<div class="opt"><span>${esc(ui(l, 'settings.language'))}</span><span class="langs">${langs}</span></div>
${toggle('opt-music', ui(l, 'settings.music'))}${toggle('opt-sfx', ui(l, 'settings.sfx'), true)}${toggle('opt-crt', ui(l, 'settings.crt_shader'), true)}${toggle('opt-motion', ui(l, 'settings.reduced_motion'))}
<p class="fine"><a href="${home(l)}privacy/">${esc(t.privacy)}</a> · ${esc(t.pressShort)}: <a href="mailto:${CONFIG.contact}">${CONFIG.contact}</a></p>`, t, l)}
<div class="toast" id="toast" role="status" aria-live="polite" hidden><img class="px" src="/img/v3/ach.png" width="64" height="64" alt=""><div><b>${esc(ui(l, 'achievements.toast_label'))}</b><strong>${esc(t.achName)}</strong><span>${esc(t.achDesc)}</span></div></div>
${about(t, l, G)}`;
  const client = { lang: l.code, unsubPath: home(l) + 'unsubscribe/', pool: CARD_POOL, cardBase: `/img/gamecards/${l.code}/`,
    boot: { ...B, version: BOOT.version, hint: t.enterHint, privacy: t.privacy, wish: t.wishSoon, osd: 'AV-1  RUNEMOIRE', buttons: Object.fromEntries(items.map(([id, k]) => [id, ui(l, k)])) },
    t: { sending: t.sending, notifyOk: t.notifyOk, notifyBad: t.notifyBad, notifyRate: t.notifyRate, notifyNet: t.notifyNet, unsubLink: t.unsubLink } };
  return head(t, l, ctx, { title: t.htmlTitle, desc: t.metaDesc, path: home(l) }) +
    `<script type="application/json" id="rm-data">${JSON.stringify(client).replace(/</g, '\\u003c')}</script>
<script type="application/ld+json">${JSON.stringify(ld(t, l)).replace(/</g, '\\u003c')}</script>
</head><body class="crt"><noscript><iframe src="https://www.googletagmanager.com/ns.html?id=GTM-5NVWLLNZ" height="0" width="0" style="display:none;visibility:hidden" title="GTM"></iframe></noscript>${body}</body></html>`;
}

// dados estruturados: o jogo, a editora, o site e o trailer (sem preço nem avaliação até existirem)
function ld(t, l) {
  const S = CONFIG.site, org = { '@id': `${S}/#org` }, vid = `${S}/#trailer`;
  return { '@context': 'https://schema.org', '@graph': [
    { '@type': 'VideoGame', '@id': `${S}/#game`, name: 'Runemoire', alternateName: 'Grimoire', description: t.metaDesc, url: S + home(l), image: S + OG,
      inLanguage: LANG_TAGS, genre: ['Roguelike', 'Deckbuilder'], gamePlatform: 'PC', operatingSystem: 'Windows', applicationCategory: 'Game',
      author: { '@type': 'Person', name: 'Daniel Cortez' }, publisher: org, trailer: { '@id': vid } },
    { '@type': 'Organization', '@id': `${S}/#org`, name: 'DC Solutions', url: 'https://dcsolutions.app/' },
    { '@type': 'WebSite', '@id': `${S}/#website`, name: 'Runemoire', url: `${S}/`, inLanguage: LANG_TAGS, publisher: org },
    { '@type': 'VideoObject', '@id': vid, name: `Runemoire: ${t.trailerPlay}`, description: t.metaDesc, thumbnailUrl: S + TRAILER.poster,
      uploadDate: TRAILER.uploadDate, contentUrl: S + TRAILER.src, duration: TRAILER.duration },
  ] };
}

// o texto da página, visível, DEPOIS da cena (a primeira pintura continua a abertura aprovada; rolando, aparece o livro)
const FAQ_KEEP = [0, 2, 3, 4, 6]; // as perguntas da v1 que não falam de seções que não existem mais
function about(t, l, G) {
  const faq = (Array.isArray(t.faq) ? t.faq : []).filter((_, i) => FAQ_KEEP.includes(i))
    .map(([q, a]) => `<h3>${esc(q)}</h3><p>${fmt(esc(a), { contact: `<a href="mailto:${CONFIG.contact}">${CONFIG.contact}</a>` })}</p>`).join('');
  const dc = esc(t.credits).includes('DC Solutions') ? esc(t.credits).replace('DC Solutions', '<a href="https://dcsolutions.app/">DC Solutions</a>') : `${esc(t.credits)} <a href="https://dcsolutions.app/">DC Solutions</a>`;
  const langs = LANGS.map((x) => `<a href="${home(x)}" lang="${x.html}" hreflang="${x.html}"${x.code === l.code ? ' aria-current="page"' : ''}>${x.self}</a>`).join(' · ');
  return `<main class="about" id="main"><div class="frame9 page prose">
<h1><img class="px" src="/img/v3/wordmark.png" width="289" height="48" alt="Runemoire" loading="lazy" decoding="async"></h1>
<p class="sub">${esc(loc(G.ui.subtitle, l))}</p>
<p>${esc(t.tagline)}</p><p>${esc(t.pressAboutText)}</p><p><i>${esc(t.dictDef)}</i></p>
<p class="state"><b>${esc(t.factPlatforms)}:</b> ${esc(t.factPlatformsV)}<br><b>${esc(t.factRelease)}:</b> ${esc(t.factReleaseV)}<br>${esc(t.wishSoon)}</p>
<p><a class="mbtn sel" href="#achievements" data-open="achievements">${esc(t.notifyLaunch)}</a></p>
<h2>${esc(t.trailerPlay)}</h2>
<video controls preload="none" playsinline poster="${TRAILER.poster}" width="1280" height="720" aria-label="${esc(t.trailerPlay)}"><source src="${TRAILER.src}" type="video/mp4"></video>
<h2>${esc(t.faqTitle)}</h2>${faq}
<p class="fine">${dc} · <a href="${home(l)}blog/">Blog</a> · <a href="${home(l)}privacy/">${esc(t.privacy)}</a> · <a href="mailto:${CONFIG.contact}">${CONFIG.contact}</a></p>
<p class="fine langs">${langs}</p>
</div></main>`;
}

function simple(t, l, ctx, { title, path: p, body, noindex = true, desc = t.metaDesc, script = true, foot = '' }) {
  const client = { lang: l.code, t: { unsubOk: t.unsubOk, unsubNone: t.unsubNone, unsubBad: t.unsubBad, sending: t.sending } };
  return head(t, l, ctx, { title: `${title} — Runemoire`, desc, path: p, noindex, script, preload: false }) +
    (script ? `<script type="application/json" id="rm-data">${JSON.stringify(client).replace(/</g, '\\u003c')}</script>` : '') +
    `\n</head><body class="simple"><noscript><iframe src="https://www.googletagmanager.com/ns.html?id=GTM-5NVWLLNZ" height="0" width="0" style="display:none;visibility:hidden" title="GTM"></iframe></noscript><main id="main"><div class="frame9 page"><a class="home" href="${home(l)}"><img class="px" src="/img/v3/wordmark.png" width="289" height="48" alt="Runemoire"></a>${body}
<a class="back" href="${home(l)}">${esc(ui(l, 'settings.back'))}</a>${foot}</div></main></body></html>`;
}

// descrição própria de cada página de privacidade (não repete a da home)
const PRIV_DESC = {
  en: 'Runemoire privacy: the site keeps only the email you leave for the launch notice. No ads; usage analytics with Microsoft Clarity and Google Analytics.',
  pt_BR: 'Privacidade do Runemoire: o site guarda só o e-mail que você deixa para o aviso de lançamento. Sem anúncios; análise de uso com o Microsoft Clarity e o Google Analytics.',
  es: 'Privacidad de Runemoire: el sitio solo guarda el correo que dejas para el aviso de lanzamiento. Sin anuncios; análisis de uso con Microsoft Clarity y Google Analytics.',
  fr: 'Confidentialité de Runemoire : le site ne garde que l\u2019e-mail laissé pour l\u2019avis de sortie. Pas de publicité ; analyse d’usage avec Microsoft Clarity et Google Analytics.',
  de: 'Datenschutz bei Runemoire: Die Seite speichert nur die E-Mail, die du für die Release-Nachricht hinterlässt. Keine Werbung; Nutzungsanalyse mit Microsoft Clarity und Google Analytics.',
};

const PRIV_UPDATED = { en: 'Last updated: 15 November 2026', pt_BR: 'Última atualização: 15 de novembro de 2026', es: 'Última actualización: 15 de noviembre de 2026', fr: 'Dernière mise à jour : 15 novembre 2026', de: 'Zuletzt aktualisiert: 15. November 2026' };

export function renderPrivacy(t, l, ctx) {
  const P = PRIVACY[l.code] || PRIVACY.en;
  const body = `<article class="prose"><h1>${esc(t.privTitle)}</h1><p class="fine">${esc(PRIV_UPDATED[l.code] || PRIV_UPDATED.en)}</p>${P.map((x) => (x.startsWith('#') ? `<h2>${esc(x.slice(1))}</h2>` : `<p>${fmt(esc(x), { contact: `<a href="mailto:${CONFIG.contact}">${CONFIG.contact}</a>`, ms: '<a href="https://privacy.microsoft.com/privacystatement" rel="noopener">Microsoft</a>', google: '<a href="https://policies.google.com/privacy" rel="noopener">Google</a>', adsset: '<a href="https://adssettings.google.com" rel="noopener">adssettings.google.com</a>' })}</p>`)).join('')}</article>`;
  const foot = `<p class="fine langs">${LANGS.map((x) => `<a href="${home(x)}privacy/" lang="${x.html}" hreflang="${x.html}"${x.code === l.code ? ' aria-current="page"' : ''}>${x.self}</a>`).join(' · ')}</p>`;
  return simple(t, l, ctx, { title: t.privTitle, path: home(l) + 'privacy/', body, noindex: false, desc: PRIV_DESC[l.code] || PRIV_DESC.en, script: false, foot });
}

export function renderUnsub(t, l, ctx) {
  const body = `<article class="prose"><h1>${esc(t.unsubTitle)}</h1><form id="unsub" data-clarity-mask="true"><button class="mbtn sel" type="submit">${esc(t.unsubBtn)}</button><p class="msg" role="status" aria-live="polite"></p></form></article>`;
  return simple(t, l, ctx, { title: t.unsubTitle, path: home(l) + 'unsubscribe/', body });
}

// 404: o computador da abertura, desligado, com a frase e o caminho de volta
export function render404(t, l, ctx) {
  const B = BOOT.t[l.code] || BOOT.t.en;
  return head(t, l, ctx, { title: `${t.nfTitle} — Runemoire`, desc: t.metaDesc, path: home(l) + '404', noindex: true }) +
    `<script type="application/json" id="rm-data">${JSON.stringify({ lang: l.code, nf: true, boot: { ...B, version: BOOT.version, hint: t.nf404, privacy: '', wish: '', osd: '', buttons: {} }, t: {} })}</script>
</head><body class="crt nf"><noscript><iframe src="https://www.googletagmanager.com/ns.html?id=GTM-5NVWLLNZ" height="0" width="0" style="display:none;visibility:hidden" title="GTM"></iframe></noscript><h1 class="sr">${esc(t.nfTitle)}</h1><canvas id="cv" aria-hidden="true"></canvas><canvas id="crt" aria-hidden="true"></canvas>
<p class="hint" id="hint">${esc(t.nf404)}</p><a class="nfback" href="${home(l)}">${esc(t.nfBack)}</a></body></html>`;
}

const PRIVACY = {
  en: ['#What we collect', 'If you ask to be notified: your email address, the language of the page and the date. Usage analytics are described below. No ads.', '#Why', 'To send you one email when Runemoire launches. We will not sell or share your address.', '#Where it is stored', 'In a Cloudflare D1 database in the developer\u2019s account. Cloudflare processes requests to keep the site online and safe.', '#Visit statistics', 'We count visits with Cloudflare Web Analytics, which sets no cookies and does not identify you, and keep anonymous daily totals of page loads and sign-ups per language, with no IP address and no identifier. We also use Microsoft Clarity across the whole site, including the sign-up and unsubscribe forms, to understand how it is used: heatmaps and recordings of the browsing, with the page text and form fields masked. Clarity sets its own cookies on runemoire.com (_clck, which links your visits for up to a year, and _clsk, which links the pages of one visit), keeps a technical key in your browser’s storage, and Microsoft sets cookies on its own domains (clarity.ms, bing.com). Clarity is run by {ms} under its privacy statement. Visitors from the EU/EEA, the UK and Switzerland are asked first: Clarity only loads after you click “Accept”, and nothing is recorded if you decline (the choice is kept in your browser’s storage, not in a cookie).', '#Google Analytics and Tag Manager', 'We use Google Tag Manager to load Google Analytics 4, which measures visits, where they come from (including utm_* campaign parameters) and sign-ups to the launch notice, without your email. Google Analytics sets cookies on runemoire.com (_ga, which tells browsers apart for up to two years, and _ga_<id>, which keeps the state of the visit). Google runs these services under the {google} privacy policy. Visitors from the EU/EEA, the UK and Switzerland are asked first: Google Tag Manager and Google Analytics only load after you click “Accept”; if you decline, nothing is sent to Google and no cookie is set.', '#Google Ads', 'Google Tag Manager also loads the Google Ads tag (Google LLC), which we use to measure whether an ad led to a sign-up (conversion measurement) and to show our ads to people who visited the site (remarketing audiences). We do not send your email or phone number to Google Ads. It sets the _gcl_au cookie on runemoire.com (up to about 90 days), and Google sets its own advertising cookies on google.com and doubleclick.net, kept for the periods in Google’s policy. How to refuse: in the EU/EEA, the UK and Switzerland the banner asks first, and no Google tag (Analytics or Ads) loads until you click “Accept”, so if you decline nothing is sent to Google; anywhere, you can turn off personalised ads at {adsset} and block or delete cookies in your browser. Google processes this data in the United States and other countries; see the {google} privacy policy.', '#Your rights (LGPD / GDPR)', 'You can leave the list at any time with the link shown after you sign up, or by writing to {contact}. We erase your email on request and after the launch email is sent.', '#Contact', '{contact}'],
  pt_BR: ['#O que coletamos', 'Se você pedir o aviso: seu e-mail, o idioma da página e a data. A análise de uso está descrita abaixo. Sem anúncios.', '#Para quê', 'Para mandar um e-mail quando o Runemoire for lançado. Não vendemos nem compartilhamos seu endereço.', '#Onde fica guardado', 'Num banco Cloudflare D1, na conta do desenvolvedor. A Cloudflare processa as requisições para manter o site no ar e seguro.', '#Estatísticas de visita', 'Contamos as visitas com o Cloudflare Web Analytics, que não usa cookies e não identifica você, e guardamos totais diários anônimos de carregamentos da página e cadastros por idioma, sem IP e sem identificador. Também usamos o Microsoft Clarity em todo o site, inclusive nos formulários de cadastro e de saída da lista, para entender o uso: mapas de calor e gravação da navegação, com o texto da página e os campos de formulário mascarados. O Clarity grava cookies próprios em runemoire.com (_clck, que liga suas visitas por até um ano, e _clsk, que liga as páginas de uma mesma visita), guarda uma chave técnica no armazenamento do navegador, e a Microsoft grava cookies nos domínios dela (clarity.ms, bing.com). O Clarity é operado pela {ms}, conforme a declaração de privacidade dela. Para visitantes da UE/EEE, do Reino Unido e da Suíça, perguntamos antes: o Clarity só carrega depois de “Aceitar”, e nada é gravado se você recusar (a escolha fica no armazenamento do navegador, não em cookie).', '#Google Analytics e Tag Manager', 'Usamos o Google Tag Manager para carregar o Google Analytics 4, que mede as visitas, de onde elas vêm (inclusive os parâmetros de campanha utm_*) e os cadastros no aviso de lançamento, sem o seu e-mail. O Google Analytics grava cookies em runemoire.com (_ga, que distingue navegadores por até dois anos, e _ga_<id>, que guarda o estado da visita). O Google opera esses serviços conforme a política de privacidade do {google}. Para visitantes da UE/EEE, do Reino Unido e da Suíça, perguntamos antes: o Google Tag Manager e o Google Analytics só carregam depois de “Aceitar”; se você recusar, nada vai para o Google e nenhum cookie é gravado.', '#Google Ads', 'O Google Tag Manager também carrega a tag do Google Ads (Google LLC), que usamos para medir se um anúncio levou a um cadastro (medição de conversões) e para mostrar nossos anúncios a quem já visitou o site (públicos de remarketing). Não enviamos seu e-mail nem seu telefone ao Google Ads. Ela grava o cookie _gcl_au em runemoire.com (até cerca de 90 dias), e o Google grava cookies de publicidade próprios em google.com e doubleclick.net, guardados pelos prazos da política do Google. Como recusar: na UE/EEE, no Reino Unido e na Suíça o banner pergunta antes, e nenhuma tag do Google (Analytics ou Ads) carrega até você clicar em “Aceitar”, então, se você recusar, nada vai para o Google; em qualquer lugar, você pode desligar os anúncios personalizados em {adsset} e bloquear ou apagar cookies no navegador. O Google trata esses dados nos Estados Unidos e em outros países (transferência internacional); veja a política de privacidade do {google}.', '#Seus direitos (LGPD / GDPR)', 'Você pode sair da lista quando quiser, pelo link que aparece depois do cadastro, ou escrevendo para {contact}. Apagamos seu e-mail a pedido e depois do e-mail de lançamento.', '#Contato', '{contact}'],
  es: ['#Qué recopilamos', 'Si pides el aviso: tu correo, el idioma de la página y la fecha. El análisis de uso se describe más abajo. Sin anuncios.', '#Para qué', 'Para enviarte un correo cuando Runemoire salga. No vendemos ni compartimos tu dirección.', '#Dónde se guarda', 'En una base de datos Cloudflare D1, en la cuenta del desarrollador. Cloudflare procesa las solicitudes para mantener el sitio en línea y seguro.', '#Estadísticas de visitas', 'Contamos las visitas con Cloudflare Web Analytics, que no usa cookies ni te identifica, y guardamos totales diarios anónimos de cargas de página y registros por idioma, sin IP ni identificador. También usamos Microsoft Clarity en todo el sitio, incluidos los formularios de registro y de baja, para entender el uso: mapas de calor y grabaciones de la navegación, con el texto de la página y los campos de formulario ocultos. Clarity crea sus propias cookies en runemoire.com (_clck, que une tus visitas hasta un año, y _clsk, que une las páginas de una misma visita), guarda una clave técnica en el almacenamiento del navegador, y Microsoft crea cookies en sus propios dominios (clarity.ms, bing.com). Clarity lo opera {ms}, según su declaración de privacidad. A los visitantes de la UE/EEE, el Reino Unido y Suiza les preguntamos antes: Clarity solo se carga después de «Aceptar», y no se graba nada si lo rechazas (la elección se guarda en el almacenamiento del navegador, no en una cookie).', '#Google Analytics y Tag Manager', 'Usamos Google Tag Manager para cargar Google Analytics 4, que mide las visitas, de dónde vienen (incluidos los parámetros de campaña utm_*) y los registros al aviso de lanzamiento, sin tu correo. Google Analytics crea cookies en runemoire.com (_ga, que distingue navegadores hasta dos años, y _ga_<id>, que guarda el estado de la visita). Google opera estos servicios según la política de privacidad de {google}. A los visitantes de la UE/EEE, el Reino Unido y Suiza les preguntamos antes: Google Tag Manager y Google Analytics solo se cargan después de «Aceptar»; si lo rechazas, no se envía nada a Google ni se crea ninguna cookie.', '#Google Ads', 'Google Tag Manager también carga la etiqueta de Google Ads (Google LLC), que usamos para medir si un anuncio llevó a un registro (medición de conversiones) y para mostrar nuestros anuncios a quienes ya visitaron el sitio (audiencias de remarketing). No enviamos tu correo ni tu teléfono a Google Ads. Crea la cookie _gcl_au en runemoire.com (hasta unos 90 días), y Google crea sus propias cookies publicitarias en google.com y doubleclick.net, que se guardan durante los plazos de la política de Google. Cómo rechazarlo: en la UE/EEE, el Reino Unido y Suiza el banner pregunta antes, y ninguna etiqueta de Google (Analytics o Ads) se carga hasta que haces clic en «Aceptar», así que si lo rechazas no se envía nada a Google; en cualquier lugar, puedes desactivar los anuncios personalizados en {adsset} y bloquear o borrar las cookies en tu navegador. Google trata estos datos en Estados Unidos y otros países (transferencia internacional); consulta la política de privacidad de {google}.', '#Tus derechos (RGPD)', 'Puedes salir de la lista cuando quieras con el enlace que aparece tras registrarte, o escribiendo a {contact}. Borramos tu correo a petición y después del correo de lanzamiento.', '#Contacto', '{contact}'],
  fr: ['#Ce que nous collectons', 'Si vous demandez l\u2019avis : votre e-mail, la langue de la page et la date. L\u2019analyse d\u2019usage est décrite plus bas. Pas de publicité.', '#Pourquoi', 'Pour vous envoyer un e-mail à la sortie de Runemoire. Nous ne vendons ni ne partageons votre adresse.', '#Où c\u2019est stocké', 'Dans une base Cloudflare D1, sur le compte du développeur. Cloudflare traite les requêtes pour garder le site en ligne et sûr.', '#Statistiques de visite', 'Nous comptons les visites avec Cloudflare Web Analytics, sans cookies et sans identifier personne, et gardons des totaux quotidiens anonymes de chargements de page et d\u2019inscriptions par langue, sans adresse IP ni identifiant. Nous utilisons aussi Microsoft Clarity sur tout le site, y compris les formulaires d’inscription et de désinscription, pour comprendre l’usage : cartes de chaleur et enregistrements de la navigation, avec le texte de la page et les champs de formulaire masqués. Clarity dépose ses propres cookies sur runemoire.com (_clck, qui relie vos visites jusqu’à un an, et _clsk, qui relie les pages d’une même visite), garde une clé technique dans le stockage du navigateur, et Microsoft dépose des cookies sur ses propres domaines (clarity.ms, bing.com). Clarity est exploité par {ms}, selon sa déclaration de confidentialité. Pour les visiteurs de l’UE/EEE, du Royaume-Uni et de la Suisse, nous demandons d’abord : Clarity ne se charge qu’après « Accepter », et rien n’est enregistré si vous refusez (le choix est gardé dans le stockage du navigateur, pas dans un cookie).', '#Google Analytics et Tag Manager', 'Nous utilisons Google Tag Manager pour charger Google Analytics 4, qui mesure les visites, leur provenance (y compris les paramètres de campagne utm_*) et les inscriptions à l’avis de sortie, sans votre e-mail. Google Analytics dépose des cookies sur runemoire.com (_ga, qui distingue les navigateurs jusqu’à deux ans, et _ga_<id>, qui garde l’état de la visite). Google exploite ces services selon la politique de confidentialité de {google}. Pour les visiteurs de l’UE/EEE, du Royaume-Uni et de la Suisse, nous demandons d’abord : Google Tag Manager et Google Analytics ne se chargent qu’après « Accepter » ; si vous refusez, rien n’est envoyé à Google et aucun cookie n’est déposé.', '#Google Ads', 'Google Tag Manager charge aussi la balise Google Ads (Google LLC), que nous utilisons pour mesurer si une annonce a mené à une inscription (mesure des conversions) et pour montrer nos annonces aux personnes qui ont visité le site (audiences de remarketing). Nous n’envoyons ni votre e-mail ni votre téléphone à Google Ads. Elle dépose le cookie _gcl_au sur runemoire.com (jusqu’à environ 90 jours), et Google dépose ses propres cookies publicitaires sur google.com et doubleclick.net, conservés selon les durées de la politique de Google. Comment refuser : dans l’UE/EEE, au Royaume-Uni et en Suisse, le bandeau demande d’abord, et aucune balise Google (Analytics ou Ads) ne se charge avant « Accepter » ; si vous refusez, rien n’est envoyé à Google. Partout, vous pouvez désactiver les annonces personnalisées sur {adsset} et bloquer ou supprimer les cookies dans votre navigateur. Google traite ces données aux États-Unis et dans d’autres pays (transfert international) ; voir la politique de confidentialité de {google}.', '#Vos droits (RGPD)', 'Vous pouvez quitter la liste à tout moment avec le lien affiché après l\u2019inscription, ou en écrivant à {contact}. Nous effaçons votre e-mail sur demande et après l\u2019e-mail de sortie.', '#Contact', '{contact}'],
  de: ['#Was wir erheben', 'Wenn du benachrichtigt werden willst: deine E-Mail-Adresse, die Sprache der Seite und das Datum. Die Nutzungsanalyse ist unten beschrieben. Keine Werbung.', '#Wozu', 'Um dir eine E-Mail zu schicken, wenn Runemoire erscheint. Wir verkaufen oder teilen deine Adresse nicht.', '#Wo es gespeichert wird', 'In einer Cloudflare-D1-Datenbank im Konto des Entwicklers. Cloudflare verarbeitet Anfragen, um die Seite online und sicher zu halten.', '#Besuchsstatistik', 'Wir zählen Besuche mit Cloudflare Web Analytics, ohne Cookies und ohne dich zu identifizieren, und speichern anonyme Tagessummen von Seitenaufrufen und Anmeldungen pro Sprache, ohne IP-Adresse und ohne Kennung. Außerdem nutzen wir Microsoft Clarity auf der ganzen Seite, auch in den Formularen zum An- und Abmelden, um die Nutzung zu verstehen: Heatmaps und Aufzeichnungen der Navigation, wobei Seitentext und Formularfelder maskiert werden. Clarity setzt eigene Cookies auf runemoire.com (_clck, das deine Besuche bis zu einem Jahr verknüpft, und _clsk, das die Seiten eines Besuchs verknüpft), speichert einen technischen Schlüssel im Browserspeicher, und Microsoft setzt Cookies auf seinen eigenen Domains (clarity.ms, bing.com). Clarity wird von {ms} gemäß deren Datenschutzerklärung betrieben. Besucher aus der EU/dem EWR, dem Vereinigten Königreich und der Schweiz fragen wir vorher: Clarity lädt erst nach „Akzeptieren“, und bei Ablehnung wird nichts aufgezeichnet (die Wahl liegt im Browserspeicher, nicht in einem Cookie).', '#Google Analytics und Tag Manager', 'Wir nutzen den Google Tag Manager, um Google Analytics 4 zu laden. Es misst Besuche, ihre Herkunft (einschließlich der Kampagnenparameter utm_*) und Anmeldungen zur Release-Nachricht, ohne deine E-Mail. Google Analytics setzt Cookies auf runemoire.com (_ga, das Browser bis zu zwei Jahre unterscheidet, und _ga_<id>, das den Stand des Besuchs speichert). Google betreibt diese Dienste gemäß der Datenschutzerklärung von {google}. Besucher aus der EU/dem EWR, dem Vereinigten Königreich und der Schweiz fragen wir vorher: Google Tag Manager und Google Analytics laden erst nach „Akzeptieren“; bei Ablehnung wird nichts an Google gesendet und kein Cookie gesetzt.', '#Google Ads', 'Der Google Tag Manager lädt außerdem das Google-Ads-Tag (Google LLC). Wir nutzen es, um zu messen, ob eine Anzeige zu einer Anmeldung geführt hat (Conversion-Messung), und um unsere Anzeigen Menschen zu zeigen, die die Seite besucht haben (Remarketing-Zielgruppen). Wir senden weder deine E-Mail noch deine Telefonnummer an Google Ads. Es setzt das Cookie _gcl_au auf runemoire.com (bis zu etwa 90 Tage), und Google setzt eigene Werbe-Cookies auf google.com und doubleclick.net, die gemäß den Fristen in Googles Richtlinie gespeichert werden. So lehnst du ab: In der EU/dem EWR, dem Vereinigten Königreich und der Schweiz fragt das Banner vorher, und kein Google-Tag (Analytics oder Ads) lädt, bevor du auf „Akzeptieren“ klickst; bei Ablehnung wird nichts an Google gesendet. Überall kannst du personalisierte Werbung unter {adsset} abschalten und Cookies im Browser blockieren oder löschen. Google verarbeitet diese Daten in den USA und anderen Ländern (internationale Übermittlung); siehe die Datenschutzerklärung von {google}.', '#Deine Rechte (DSGVO)', 'Du kannst die Liste jederzeit über den Link nach der Anmeldung verlassen oder an {contact} schreiben. Wir löschen deine E-Mail auf Wunsch und nach der Release-E-Mail.', '#Kontakt', '{contact}'],
};
