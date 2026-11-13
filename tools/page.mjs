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
<link rel="icon" href="/favicon.ico" sizes="any"><link rel="icon" type="image/png" sizes="32x32" href="/img/brand/seal_32.png"><link rel="apple-touch-icon" href="/img/brand/seal_180.png">
<link rel="manifest" href="/site.webmanifest">
${preload ? '<link rel="preload" href="/img/v3b/computer.png" as="image" fetchpriority="high">' : ''}<link rel="preload" href="/fonts/pixel.woff2" as="font" type="font/woff2" crossorigin>
${styleTag(ctx)}${script ? `<script type="module" src="${ctx.JS}"></script>` : ''}`;
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
<form class="notify" method="post" action="/api/notify" novalidate><label class="sr" for="email">${esc(t.notifyLabel)}</label>
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
</head><body class="crt">${body}</body></html>`;
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
<p class="fine">${dc} · <a href="/blog/">Blog</a> · <a href="${home(l)}privacy/">${esc(t.privacy)}</a> · <a href="mailto:${CONFIG.contact}">${CONFIG.contact}</a></p>
<p class="fine langs">${langs}</p>
</div></main>`;
}

function simple(t, l, ctx, { title, path: p, body, noindex = true, desc = t.metaDesc, script = true, foot = '' }) {
  const client = { lang: l.code, t: { unsubOk: t.unsubOk, unsubNone: t.unsubNone, unsubBad: t.unsubBad, sending: t.sending } };
  return head(t, l, ctx, { title: `${title} — Runemoire`, desc, path: p, noindex, script, preload: false }) +
    (script ? `<script type="application/json" id="rm-data">${JSON.stringify(client).replace(/</g, '\\u003c')}</script>` : '') +
    `\n</head><body class="simple"><main id="main"><div class="frame9 page"><a class="home" href="${home(l)}"><img class="px" src="/img/v3/wordmark.png" width="289" height="48" alt="Runemoire"></a>${body}
<a class="back" href="${home(l)}">${esc(ui(l, 'settings.back'))}</a>${foot}</div></main></body></html>`;
}

// descrição própria de cada página de privacidade (não repete a da home)
const PRIV_DESC = {
  en: 'Runemoire privacy: the site keeps only the email you leave for the launch notice. No cookies, no ads, no trackers.',
  pt_BR: 'Privacidade do Runemoire: o site guarda só o e-mail que você deixa para o aviso de lançamento. Sem cookies, sem anúncios, sem rastreadores.',
  es: 'Privacidad de Runemoire: el sitio solo guarda el correo que dejas para el aviso de lanzamiento. Sin cookies, sin anuncios, sin rastreadores.',
  fr: 'Confidentialité de Runemoire : le site ne garde que l\u2019e-mail laissé pour l\u2019avis de sortie. Pas de cookies, pas de publicité, pas de traceurs.',
  de: 'Datenschutz bei Runemoire: Die Seite speichert nur die E-Mail, die du für die Release-Nachricht hinterlässt. Keine Cookies, keine Werbung, keine Tracker.',
};

export function renderPrivacy(t, l, ctx) {
  const P = PRIVACY[l.code] || PRIVACY.en;
  const body = `<article class="prose"><h1>${esc(t.privTitle)}</h1>${P.map((x) => (x.startsWith('#') ? `<h2>${esc(x.slice(1))}</h2>` : `<p>${fmt(esc(x), { contact: `<a href="mailto:${CONFIG.contact}">${CONFIG.contact}</a>` })}</p>`)).join('')}</article>`;
  const foot = `<p class="fine langs">${LANGS.map((x) => `<a href="${home(x)}privacy/" lang="${x.html}" hreflang="${x.html}"${x.code === l.code ? ' aria-current="page"' : ''}>${x.self}</a>`).join(' · ')}</p>`;
  return simple(t, l, ctx, { title: t.privTitle, path: home(l) + 'privacy/', body, noindex: false, desc: PRIV_DESC[l.code] || PRIV_DESC.en, script: false, foot });
}

export function renderUnsub(t, l, ctx) {
  const body = `<article class="prose"><h1>${esc(t.unsubTitle)}</h1><form id="unsub"><button class="mbtn sel" type="submit">${esc(t.unsubBtn)}</button><p class="msg" role="status" aria-live="polite"></p></form></article>`;
  return simple(t, l, ctx, { title: t.unsubTitle, path: home(l) + 'unsubscribe/', body });
}

// 404: o computador da abertura, desligado, com a frase e o caminho de volta
export function render404(t, l, ctx) {
  const B = BOOT.t[l.code] || BOOT.t.en;
  return head(t, l, ctx, { title: `${t.nfTitle} — Runemoire`, desc: t.metaDesc, path: home(l) + '404', noindex: true }) +
    `<script type="application/json" id="rm-data">${JSON.stringify({ lang: l.code, nf: true, boot: { ...B, version: BOOT.version, hint: t.nf404, privacy: '', wish: '', osd: '', buttons: {} }, t: {} })}</script>
</head><body class="crt nf"><h1 class="sr">${esc(t.nfTitle)}</h1><canvas id="cv" aria-hidden="true"></canvas><canvas id="crt" aria-hidden="true"></canvas>
<p class="hint" id="hint">${esc(t.nf404)}</p><a class="nfback" href="${home(l)}">${esc(t.nfBack)}</a></body></html>`;
}

const PRIVACY = {
  en: ['#What we collect', 'Only if you ask to be notified: your email address, the language of the page and the date. Nothing else. No cookies, no ads, no trackers.', '#Why', 'To send you one email when Runemoire launches. We will not sell or share your address.', '#Where it is stored', 'In a Cloudflare D1 database in the developer\u2019s account. Cloudflare processes requests to keep the site online and safe.', '#Visit statistics', 'We count visits with Cloudflare Web Analytics, which sets no cookies and does not identify you, and keep anonymous daily totals of page loads and sign-ups per language, with no IP address and no identifier. This site stores nothing on your device.', '#Your rights (LGPD / GDPR)', 'You can leave the list at any time with the link shown after you sign up, or by writing to {contact}. We erase your email on request and after the launch email is sent.', '#Contact', '{contact}'],
  pt_BR: ['#O que coletamos', 'Só se você pedir o aviso: seu e-mail, o idioma da página e a data. Mais nada. Sem cookies, sem anúncios, sem rastreadores.', '#Para quê', 'Para mandar um e-mail quando o Runemoire for lançado. Não vendemos nem compartilhamos seu endereço.', '#Onde fica guardado', 'Num banco Cloudflare D1, na conta do desenvolvedor. A Cloudflare processa as requisições para manter o site no ar e seguro.', '#Estatísticas de visita', 'Contamos as visitas com o Cloudflare Web Analytics, que não usa cookies e não identifica você, e guardamos totais diários anônimos de carregamentos da página e cadastros por idioma, sem IP e sem identificador. Este site não guarda nada no seu aparelho.', '#Seus direitos (LGPD / GDPR)', 'Você pode sair da lista quando quiser, pelo link que aparece depois do cadastro, ou escrevendo para {contact}. Apagamos seu e-mail a pedido e depois do e-mail de lançamento.', '#Contato', '{contact}'],
  es: ['#Qué recopilamos', 'Solo si pides el aviso: tu correo, el idioma de la página y la fecha. Nada más. Sin cookies, sin anuncios, sin rastreadores.', '#Para qué', 'Para enviarte un correo cuando Runemoire salga. No vendemos ni compartimos tu dirección.', '#Dónde se guarda', 'En una base de datos Cloudflare D1, en la cuenta del desarrollador. Cloudflare procesa las solicitudes para mantener el sitio en línea y seguro.', '#Estadísticas de visitas', 'Contamos las visitas con Cloudflare Web Analytics, que no usa cookies ni te identifica, y guardamos totales diarios anónimos de cargas de página y registros por idioma, sin IP ni identificador. Este sitio no guarda nada en tu dispositivo.', '#Tus derechos (RGPD)', 'Puedes salir de la lista cuando quieras con el enlace que aparece tras registrarte, o escribiendo a {contact}. Borramos tu correo a petición y después del correo de lanzamiento.', '#Contacto', '{contact}'],
  fr: ['#Ce que nous collectons', 'Seulement si vous demandez l\u2019avis : votre e-mail, la langue de la page et la date. Rien d\u2019autre. Pas de cookies, pas de publicité, pas de traceurs.', '#Pourquoi', 'Pour vous envoyer un e-mail à la sortie de Runemoire. Nous ne vendons ni ne partageons votre adresse.', '#Où c\u2019est stocké', 'Dans une base Cloudflare D1, sur le compte du développeur. Cloudflare traite les requêtes pour garder le site en ligne et sûr.', '#Statistiques de visite', 'Nous comptons les visites avec Cloudflare Web Analytics, sans cookies et sans identifier personne, et gardons des totaux quotidiens anonymes de chargements de page et d\u2019inscriptions par langue, sans adresse IP ni identifiant. Ce site ne stocke rien sur votre appareil.', '#Vos droits (RGPD)', 'Vous pouvez quitter la liste à tout moment avec le lien affiché après l\u2019inscription, ou en écrivant à {contact}. Nous effaçons votre e-mail sur demande et après l\u2019e-mail de sortie.', '#Contact', '{contact}'],
  de: ['#Was wir erheben', 'Nur wenn du benachrichtigt werden willst: deine E-Mail-Adresse, die Sprache der Seite und das Datum. Sonst nichts. Keine Cookies, keine Werbung, keine Tracker.', '#Wozu', 'Um dir eine E-Mail zu schicken, wenn Runemoire erscheint. Wir verkaufen oder teilen deine Adresse nicht.', '#Wo es gespeichert wird', 'In einer Cloudflare-D1-Datenbank im Konto des Entwicklers. Cloudflare verarbeitet Anfragen, um die Seite online und sicher zu halten.', '#Besuchsstatistik', 'Wir zählen Besuche mit Cloudflare Web Analytics, ohne Cookies und ohne dich zu identifizieren, und speichern anonyme Tagessummen von Seitenaufrufen und Anmeldungen pro Sprache, ohne IP-Adresse und ohne Kennung. Diese Seite speichert nichts auf deinem Gerät.', '#Deine Rechte (DSGVO)', 'Du kannst die Liste jederzeit über den Link nach der Anmeldung verlassen oder an {contact} schreiben. Wir löschen deine E-Mail auf Wunsch und nach der Release-E-Mail.', '#Kontakt', '{contact}'],
};
