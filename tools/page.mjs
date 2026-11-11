// runemoire.com v2: uma página só, minimalista, celular primeiro (pedido do Daniel, 10/11/2026).
// Topo (logo do jogo, uma frase, um castelo do jogo, "Me avise"), trailer de gameplay ao clicar,
// três capturas reais do jogo, rodapé de uma linha. Textos do jogo vêm de src/data/game.json.
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const R = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const CONFIG = JSON.parse(fs.readFileSync(path.join(R, 'src/data/config.json'), 'utf8'));

export const LANGS = [
  { code: 'en', prefix: '', html: 'en', self: 'English', short: 'EN', og: 'en_US' },
  { code: 'pt_BR', prefix: 'pt', html: 'pt-BR', self: 'Português', short: 'PT', og: 'pt_BR' },
  { code: 'es', prefix: 'es', html: 'es', self: 'Español', short: 'ES', og: 'es_ES' },
  { code: 'fr', prefix: 'fr', html: 'fr', self: 'Français', short: 'FR', og: 'fr_FR' },
  { code: 'de', prefix: 'de', html: 'de', self: 'Deutsch', short: 'DE', og: 'de_DE' },
];
const home = (l) => (l.prefix ? `/${l.prefix}/` : '/');
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = (s, v = {}) => String(s ?? '').replace(/\{(\w+)\}/g, (m, k) => (k in v ? v[k] : m));
const loc = (o, l) => (o && typeof o === 'object' ? o[l.code] ?? o.en : o);

// as três telas reais (capturas do próprio jogo, steam/store/screenshots): combate, mapa e loja
const SHOTS = ['03_road_battle', '06_road_fork', '05_shop'];
const SHOT_ALT = {
  '03_road_battle': { en: 'Combat: cards in hand against an enemy on the road', pt_BR: 'Combate: cartas na mão contra um inimigo na estrada', es: 'Combate: cartas en la mano contra un enemigo en el camino', fr: 'Combat : des cartes en main face à un ennemi sur la route', de: 'Kampf: Karten auf der Hand gegen einen Gegner auf der Straße' },
  '06_road_fork': { en: 'The map: a fork in the road toward the castle', pt_BR: 'O mapa: uma bifurcação na estrada rumo ao castelo', es: 'El mapa: una bifurcación del camino hacia el castillo', fr: 'La carte : une bifurcation vers le château', de: 'Die Karte: eine Weggabelung zur Burg' },
  '05_shop': { en: 'The shop: cards and upgrades for sale', pt_BR: 'A loja: cartas e melhorias à venda', es: 'La tienda: cartas y mejoras a la venta', fr: 'La boutique : cartes et améliorations à vendre', de: 'Der Laden: Karten und Verbesserungen' },
};
export const CASTLE_BIOME = 'fields';

function head(t, l, ctx, { title, desc, path: p, noindex = false }) {
  const url = CONFIG.site + p;
  const alts = noindex ? '' : LANGS.map((x) => `<link rel="alternate" hreflang="${x.html}" href="${CONFIG.site}${home(x)}${p.replace(home(l), '')}">`).join('') +
    `<link rel="alternate" hreflang="x-default" href="${CONFIG.site}/${p.replace(home(l), '')}">`;
  return `<!doctype html><html lang="${l.html}"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${esc(title)}</title><meta name="description" content="${esc(desc)}">
${noindex ? '<meta name="robots" content="noindex">' : `<link rel="canonical" href="${url}">${alts}`}
<meta name="theme-color" content="#0b0a0d"><meta name="color-scheme" content="dark">
<meta property="og:type" content="website"><meta property="og:site_name" content="Runemoire"><meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(desc)}"><meta property="og:url" content="${url}"><meta property="og:image" content="${CONFIG.site}/img/og/og_${l.code}.png">
<meta property="og:image:width" content="1200"><meta property="og:image:height" content="630"><meta property="og:locale" content="${l.og}"><meta name="twitter:card" content="summary_large_image">
<link rel="icon" href="/favicon.ico" sizes="any"><link rel="icon" type="image/png" sizes="32x32" href="/img/brand/r_32.png"><link rel="apple-touch-icon" href="/img/brand/r_180.png">
${ctx.preload || ''}<link rel="stylesheet" href="${ctx.CSS}"><script type="module" src="${ctx.JS}"></script>`;
}

function foot(t, l, p = '') {
  const langs = LANGS.map((x) => (x.code === l.code ? `<span aria-current="true">${x.short}</span>` : `<a href="${home(x)}${p}" lang="${x.html}" hreflang="${x.html}" title="${x.self}">${x.short}</a>`)).join(' ');
  return `<footer class="foot"><nav aria-label="${esc(t.langLabel)}">${langs}</nav><a href="${home(l)}privacy/">${esc(t.privacy)}</a><a href="mailto:${CONFIG.contact}">${esc(t.pressShort)}: ${CONFIG.contact}</a></footer>`;
}

export function renderHome(t, l, ctx) {
  const G = ctx.GAME;
  const B = G.biomes.find((b) => b.id === CASTLE_BIOME);
  const shots = (l.code === 'pt_BR' ? G.shots.pt_BR : G.shots.en).filter((s) => SHOTS.includes(s.id)).sort((a, b) => SHOTS.indexOf(a.id) - SHOTS.indexOf(b.id));
  const logo = G.brand.logo;
  const body = `<main id="main">
<header class="top">
<h1><img class="px logo" src="${logo.src}" width="${logo.w * 2}" height="${logo.h * 2}" alt="Runemoire"></h1>
<p class="line">${esc(loc(G.ui.subtitle, l))}</p>
<i class="castle" role="img" aria-label="${esc(fmt(t.castleAlt, { biome: loc(B.name, l) }))}"></i>
<form class="notify" method="post" action="/api/notify" novalidate>
<label class="sr" for="email">${esc(t.notifyLabel)}</label>
<input id="email" type="email" name="email" required autocomplete="email" inputmode="email" placeholder="${esc(t.notifyPlaceholder)}" aria-describedby="fine">
<div class="hp" aria-hidden="true"><label>Website <input type="text" name="website" tabindex="-1" autocomplete="off"></label></div>
<button type="submit">${esc(t.notifyLaunch)}</button>
<p class="msg" role="status" aria-live="polite"></p>
</form>
<p class="soon" id="fine">${esc(t.steamSoonLine)} · <a href="${home(l)}privacy/">${esc(t.privacy)}</a></p>
</header>
<section class="trailer" aria-label="${esc(t.trailerPlay)}">
<div class="frame"><img src="/media/runemoire-gameplay.jpg" width="1280" height="720" alt="" loading="lazy" decoding="async">
<button class="play" type="button" data-src="/media/runemoire-gameplay.mp4" aria-label="${esc(t.play)}: ${esc(t.trailerPlay)}"><span aria-hidden="true"></span></button></div>
</section>
<section class="shots" aria-label="${esc(t.galleryTitle)}">
${shots.map((s) => `<img src="${s.thumb}" srcset="${s.thumb} 960w, ${s.full} 1920w" sizes="(min-width: 1100px) 1040px, 100vw" width="1920" height="1080" alt="${esc(SHOT_ALT[s.id][l.code] || SHOT_ALT[s.id].en)}" loading="lazy" decoding="async">`).join('\n')}
</section>
</main>`;
  const client = { lang: l.code, unsubPath: home(l) + 'unsubscribe/', t: { sending: t.sending, notifyOk: t.notifyOk, notifyBad: t.notifyBad, notifyRate: t.notifyRate, notifyNet: t.notifyNet, unsubLink: t.unsubLink } };
  return head(t, l, ctx, { title: t.htmlTitle, desc: t.metaDesc, path: home(l) }) +
    `<script type="application/json" id="rm-data">${JSON.stringify(client).replace(/</g, '\\u003c')}</script>
<script type="application/ld+json">${JSON.stringify({ '@context': 'https://schema.org', '@type': 'VideoGame', name: 'Runemoire', alternateName: 'Grimoire', description: t.metaDesc, url: CONFIG.site + home(l), genre: ['Roguelike', 'Deckbuilder'], gamePlatform: 'PC', author: { '@type': 'Person', name: 'Daniel Cortez' } }).replace(/</g, '\\u003c')}</script>
</head><body>${body}${foot(t, l)}</body></html>`;
}

function simple(t, l, ctx, { title, path: p, body, noindex = true, sub = '' }) {
  const client = { lang: l.code, t: { unsubOk: t.unsubOk, unsubNone: t.unsubNone, unsubBad: t.unsubBad, sending: t.sending } };
  return head(t, l, ctx, { title: `${title} — Runemoire`, desc: t.metaDesc, path: p, noindex }) +
    `<script type="application/json" id="rm-data">${JSON.stringify(client).replace(/</g, '\\u003c')}</script>
</head><body class="simple"><main id="main"><a class="back" href="${home(l)}"><img class="px" src="${ctx.GAME.brand.wordmark.src}" width="${ctx.GAME.brand.wordmark.w}" height="${ctx.GAME.brand.wordmark.h}" alt="Runemoire"></a>${body}</main>${foot(t, l, sub)}</body></html>`;
}

export function renderPrivacy(t, l, ctx) {
  const P = PRIVACY[l.code] || PRIVACY.en;
  const body = `<article class="prose"><h1>${esc(t.privTitle)}</h1>${P.map((x) => (x.startsWith('#') ? `<h2>${esc(x.slice(1))}</h2>` : `<p>${fmt(esc(x), { contact: `<a href="mailto:${CONFIG.contact}">${CONFIG.contact}</a>` })}</p>`)).join('')}</article>`;
  return simple(t, l, ctx, { title: t.privTitle, path: home(l) + 'privacy/', body, noindex: false, sub: 'privacy/' });
}

export function renderUnsub(t, l, ctx) {
  const body = `<article class="prose"><h1>${esc(t.unsubTitle)}</h1><form id="unsub"><button type="submit">${esc(t.unsubBtn)}</button><p class="msg" role="status" aria-live="polite"></p></form></article>`;
  return simple(t, l, ctx, { title: t.unsubTitle, path: home(l) + 'unsubscribe/', body });
}

export function render404(t, l, ctx) {
  const body = `<article class="prose nf"><h1>${esc(t.nfTitle)}</h1><p>${esc(t.nfText)}</p><p><a href="${home(l)}">${esc(t.nfBack)}</a></p></article>`;
  return simple(t, l, ctx, { title: t.nfTitle, path: home(l) + '404', body });
}

const PRIVACY = {
  en: ['#What we collect', 'Only if you ask to be notified: your email address, the language of the page and the date. Nothing else. No cookies, no ads, no trackers.', '#Why', 'To send you one email when Runemoire launches. We will not sell or share your address.', '#Where it is stored', 'In a Cloudflare D1 database in the developer\u2019s account. Cloudflare processes requests to keep the site online and safe.', '#Visit statistics', 'We count visits with Cloudflare Web Analytics, which sets no cookies and does not identify you, and keep anonymous daily totals of page loads and sign-ups per language, with no IP address and no identifier. This site stores nothing on your device.', '#Your rights (LGPD / GDPR)', 'You can leave the list at any time with the link shown after you sign up, or by writing to {contact}. We erase your email on request and after the launch email is sent.', '#Contact', '{contact}'],
  pt_BR: ['#O que coletamos', 'Só se você pedir o aviso: seu e-mail, o idioma da página e a data. Mais nada. Sem cookies, sem anúncios, sem rastreadores.', '#Para quê', 'Para mandar um e-mail quando o Runemoire for lançado. Não vendemos nem compartilhamos seu endereço.', '#Onde fica guardado', 'Num banco Cloudflare D1, na conta do desenvolvedor. A Cloudflare processa as requisições para manter o site no ar e seguro.', '#Estatísticas de visita', 'Contamos as visitas com o Cloudflare Web Analytics, que não usa cookies e não identifica você, e guardamos totais diários anônimos de carregamentos da página e cadastros por idioma, sem IP e sem identificador. Este site não guarda nada no seu aparelho.', '#Seus direitos (LGPD / GDPR)', 'Você pode sair da lista quando quiser, pelo link que aparece depois do cadastro, ou escrevendo para {contact}. Apagamos seu e-mail a pedido e depois do e-mail de lançamento.', '#Contato', '{contact}'],
  es: ['#Qué recopilamos', 'Solo si pides el aviso: tu correo, el idioma de la página y la fecha. Nada más. Sin cookies, sin anuncios, sin rastreadores.', '#Para qué', 'Para enviarte un correo cuando Runemoire salga. No vendemos ni compartimos tu dirección.', '#Dónde se guarda', 'En una base de datos Cloudflare D1, en la cuenta del desarrollador. Cloudflare procesa las solicitudes para mantener el sitio en línea y seguro.', '#Estadísticas de visitas', 'Contamos las visitas con Cloudflare Web Analytics, que no usa cookies ni te identifica, y guardamos totales diarios anónimos de cargas de página y registros por idioma, sin IP ni identificador. Este sitio no guarda nada en tu dispositivo.', '#Tus derechos (RGPD)', 'Puedes salir de la lista cuando quieras con el enlace que aparece tras registrarte, o escribiendo a {contact}. Borramos tu correo a petición y después del correo de lanzamiento.', '#Contacto', '{contact}'],
  fr: ['#Ce que nous collectons', 'Seulement si vous demandez l\u2019avis : votre e-mail, la langue de la page et la date. Rien d\u2019autre. Pas de cookies, pas de publicité, pas de traceurs.', '#Pourquoi', 'Pour vous envoyer un e-mail à la sortie de Runemoire. Nous ne vendons ni ne partageons votre adresse.', '#Où c\u2019est stocké', 'Dans une base Cloudflare D1, sur le compte du développeur. Cloudflare traite les requêtes pour garder le site en ligne et sûr.', '#Statistiques de visite', 'Nous comptons les visites avec Cloudflare Web Analytics, sans cookies et sans identifier personne, et gardons des totaux quotidiens anonymes de chargements de page et d\u2019inscriptions par langue, sans adresse IP ni identifiant. Ce site ne stocke rien sur votre appareil.', '#Vos droits (RGPD)', 'Vous pouvez quitter la liste à tout moment avec le lien affiché après l\u2019inscription, ou en écrivant à {contact}. Nous effaçons votre e-mail sur demande et après l\u2019e-mail de sortie.', '#Contact', '{contact}'],
  de: ['#Was wir erheben', 'Nur wenn du benachrichtigt werden willst: deine E-Mail-Adresse, die Sprache der Seite und das Datum. Sonst nichts. Keine Cookies, keine Werbung, keine Tracker.', '#Wozu', 'Um dir eine E-Mail zu schicken, wenn Runemoire erscheint. Wir verkaufen oder teilen deine Adresse nicht.', '#Wo es gespeichert wird', 'In einer Cloudflare-D1-Datenbank im Konto des Entwicklers. Cloudflare verarbeitet Anfragen, um die Seite online und sicher zu halten.', '#Besuchsstatistik', 'Wir zählen Besuche mit Cloudflare Web Analytics, ohne Cookies und ohne dich zu identifizieren, und speichern anonyme Tagessummen von Seitenaufrufen und Anmeldungen pro Sprache, ohne IP-Adresse und ohne Kennung. Diese Seite speichert nichts auf deinem Gerät.', '#Deine Rechte (DSGVO)', 'Du kannst die Liste jederzeit über den Link nach der Anmeldung verlassen oder an {contact} schreiben. Wir löschen deine E-Mail auf Wunsch und nach der Release-E-Mail.', '#Kontakt', '{contact}'],
};
