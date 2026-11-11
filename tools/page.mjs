// Páginas do runemoire.com, montadas no build (HTML pronto para ler e indexar sem JS).
// Todo nome e número do jogo vem de src/data/game.json (extraído do código do jogo).
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const R = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const CONFIG = JSON.parse(fs.readFileSync(path.join(R, 'src/data/config.json'), 'utf8'));

export const LANGS = [
  { code: 'en', prefix: '', html: 'en', self: 'English', og: 'en_US' },
  { code: 'pt_BR', prefix: 'pt', html: 'pt-BR', self: 'Português (Brasil)', og: 'pt_BR' },
  { code: 'es', prefix: 'es', html: 'es', self: 'Español', og: 'es_ES' },
  { code: 'fr', prefix: 'fr', html: 'fr', self: 'Français', og: 'fr_FR' },
  { code: 'de', prefix: 'de', html: 'de', self: 'Deutsch', og: 'de_DE' },
];
const home = (l) => (l.prefix ? `/${l.prefix}/` : '/');

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = (s, v = {}) => String(s ?? '').replace(/\{(\w+)\}/g, (m, k) => (k in v ? v[k] : m));
const loc = (o, l) => (o && typeof o === 'object' ? o[l.code] ?? o.en : o);
const px = (img, k, cls = 'px', alt = '', extra = '') =>
  `<img class="${cls}" src="${img.src}" width="${img.w * k}" height="${img.h * k}" alt="${esc(alt)}" ${extra}>`;

// sprite animado em CSS steps(): a classe sai do sprites.css gerado no build
export const sprKey = (src) => 'sp-' + src.replace(/^\/img\//, '').replace(/\.png$/, '').replace(/[^a-z0-9]+/gi, '-');
export function spritesCss(GAME) {
  const all = new Map();
  const add = (s) => s && s.frames && all.set(s.src, s);
  for (const b of GAME.biomes) { add(b.castleAnim); add(b.boss.idle); add(b.boss.token); for (const e of b.enemies) add(e.idle); }
  for (const c of GAME.cards) add(c.icon);
  let css = '';
  for (const s of all.values()) {
    const dur = (s.frames / (s.fps || 8)).toFixed(3);
    css += `.${sprKey(s.src)}{--fw:${s.w}px;--fh:${s.h}px;--fn:${s.frames};--dur:${dur}s}.vis .${sprKey(s.src)},.${sprKey(s.src)}.vis{background-image:url(${s.src})}\n`;
  }
  return css;
}
const spr = (s, k, cls = '', label = '') =>
  `<i class="spr ${sprKey(s.src)} ${cls}" data-k="${k}" ${label ? `role="img" aria-label="${esc(label)}"` : 'aria-hidden="true"'}></i>`;

// temas: cada bioma vira variáveis CSS (cores do biomes.lua do jogo)
export function themesCss(GAME) {
  const mix = (a, b, t) => {
    const h = (x) => [1, 3, 5].map((i) => parseInt(x.slice(i, i + 2), 16));
    const [A, B] = [h(a), h(b)];
    return '#' + A.map((v, i) => Math.round(v + (B[i] - v) * t).toString(16).padStart(2, '0')).join('');
  };
  let css = '';
  for (const b of GAME.biomes) {
    const p = b.palette;
    const stops = [0, 0.18, 0.38, 0.58, 0.78, 1].map((t, i) => `--sky-${i}:${mix(p.skyTop, p.skyHorizon, t)}`).join(';');
    css += `:root[data-biome="${b.id}"]{${stops};--accent:${p.accent};--hills-far:${p.hillsFar};--hills-near:${p.hillsNear};--ground:${p.grassA};--cloud:${p.cloud};--fog:${p.fog};` +
      `--mtn:url(${b.mtn.src});--mtn-front:url(${(b.mtnFront || b.mtn).src});--cursor:url(/img/gen/cursors/cursor_${b.id}.png) 1 1,auto;--cursor-hand:url(/img/gen/cursors/cursor_${b.id}.png) 1 1,pointer}\n`;
  }
  css += `:root[data-biome="eclipse"]{--sky-0:#05040a;--sky-1:#0d0918;--sky-2:#1a1030;--sky-3:#2a1640;--sky-4:#3b1d4a;--sky-5:#56284f;--accent:#f4e3a1;--hills-far:#120c1c;--hills-near:#0b0712;--ground:#140d1c;--cloud:#3b2f4f;--fog:#2a1640;` +
    `--mtn:url(${GAME.biomes[5].mtn.src});--mtn-front:url(${(GAME.biomes[5].mtnFront || GAME.biomes[5].mtn).src});--cursor:url(/img/gen/cursors/cursor_dusk.png) 1 1,auto;--cursor-hand:url(/img/gen/cursors/cursor_dusk.png) 1 1,pointer}\n` +
    `:root[data-biome="eclipse"] .hero .hills,:root[data-biome="eclipse"] .hero .castle{filter:brightness(.35) saturate(.4) hue-rotate(220deg)}\n`;
  return css;
}

function head(t, l, ctx, T, { title, desc, path: p, noindex = false, alts = true }) {
  const url = CONFIG.site + p;
  const og = `${CONFIG.site}/img/og/og_${l.code}.png`;
  const alt = alts ? LANGS.map((x) => `<link rel="alternate" hreflang="${x.html}" href="${CONFIG.site}${home(x)}${p.replace(home(l), '')}">`).join('') +
    `<link rel="alternate" hreflang="x-default" href="${CONFIG.site}/${p.replace(home(l), '')}">` : '';
  return `<!doctype html><html lang="${l.html}" data-biome="fields"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${esc(title)}</title><meta name="description" content="${esc(desc)}">
${noindex ? '<meta name="robots" content="noindex">' : `<link rel="canonical" href="${url}">${alt}`}
<meta name="theme-color" content="#211f29"><meta name="color-scheme" content="dark">
<meta property="og:type" content="website"><meta property="og:site_name" content="Runemoire"><meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(desc)}"><meta property="og:url" content="${url}"><meta property="og:image" content="${og}">
<meta property="og:image:width" content="1200"><meta property="og:image:height" content="630"><meta property="og:locale" content="${l.og}">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" href="/favicon.ico" sizes="any"><link rel="icon" type="image/png" sizes="32x32" href="/img/brand/r_32.png">
<link rel="apple-touch-icon" href="/img/brand/r_180.png"><link rel="manifest" href="/site.webmanifest">
<link rel="preload" href="/fonts/pixel.woff2" as="font" type="font/woff2" crossorigin>
<link rel="stylesheet" href="${ctx.CSS}">
<script type="module" src="${ctx.JS}"></script>`;
}

function bar(t, l, GAME, current = 'home') {
  const runes = GAME.biomes.map((b) => `<button class="rune" type="button" data-biome="${b.id}" aria-pressed="false" title="${esc(loc(b.name, l))}" aria-label="${esc(loc(b.name, l))}"><img class="px" src="/img/gen/runes/rune_${b.id}.png" width="32" height="32" alt=""></button>`).join('') +
    `<button class="rune" type="button" data-biome="eclipse" aria-pressed="false" hidden title="${esc(t.eclipseName)}" aria-label="${esc(t.eclipseName)}"><img class="px" src="/img/gen/runes/rune_eclipse.png" width="32" height="32" alt=""></button>`;
  const nav = [['intro', t.navIntro], ['trailers', t.navTrailers], ['play', t.navPlay], ['classes', t.navClasses], ['bestiary', t.navBestiary], ['cards', t.navCards], ['beyond', t.navBeyond], ['faq', t.navFaq], ['press', t.navPress]];
  const h = home(l);
  const langs = LANGS.map((x) => `<option value="${home(x)}"${x.code === l.code ? ' selected' : ''} lang="${x.html}">${x.self}</option>`).join('');
  return `<a class="skip" href="#main">${esc(t.skip)}</a>
<header class="bar"><a class="brand" href="${h}"><img class="px" src="/img/brand/r_32.png" width="32" height="32" alt=""><span>RUNEMOIRE</span></a>
<nav aria-label="${esc(t.navIntro)}">${nav.map(([id, n]) => `<a href="${current === 'home' ? '' : h}#${id}">${esc(n)}</a>`).join('')}</nav>
<div class="tools"><div class="runes" role="group" aria-label="${esc(t.themeLabel)}">${runes}</div>
<button class="iconbtn" id="motion" type="button" aria-pressed="false" title="${esc(t.motionLabel)}"><span aria-hidden="true">≋</span><span class="sr">${esc(t.motionLabel)}</span></button>
<button class="iconbtn" id="sound" type="button" aria-pressed="false" aria-label="${esc(t.soundOn)}" title="${esc(t.soundOn)}"><span aria-hidden="true">♪</span></button>
<label class="sr" for="lang">${esc(t.langLabel)}</label><select class="langsel" id="lang">${langs}</select></div></header>`;
}

function foot(t, l, GAME) {
  const h = home(l);
  return `<footer class="foot"><div class="wrap cols">
<div><img class="px seal" src="${GAME.brand.seal.src}" width="64" height="64" alt="${esc(t.footSeal)}"><p>${esc(loc(GAME.ui.subtitle, l))}</p>
<button class="secret-rune" type="button" data-secret="5" aria-label="${esc(t.rune)}"><img class="px" src="/img/gen/runes/rune_eclipse.png" width="20" height="20" alt=""></button></div>
<div><h2>${esc(t.footGame)}</h2><ul><li><a href="${h}#trailers">${esc(t.navTrailers)}</a></li><li><a href="${h}#bestiary">${esc(t.navBestiary)}</a></li><li><a href="${h}#press">${esc(t.navPress)}</a></li><li><a href="mailto:${CONFIG.contact}">${CONFIG.contact}</a></li></ul></div>
<div><h2>${esc(t.footSite)}</h2><ul><li><a href="${h}privacy/">${esc(t.privacy)}</a></li><li><a href="${h}#tome" id="replay">${esc(t.replay)}</a></li>
${LANGS.map((x) => `<li><a href="${home(x)}" lang="${x.html}" hreflang="${x.html}">${x.self}</a></li>`).join('')}</ul></div>
</div><div class="wrap legal"><p>${esc(t.credits)} ${esc(t.rights)}</p><p class="fontnote">Font: Grimoire Pixel, a modified Press Start 2P — <a href="/fonts/OFL.txt">SIL Open Font License 1.1</a>.</p></div></footer>
<div class="toast" id="toast" role="status" aria-live="polite"></div>`;
}

const steamBtn = (t, where) => `<a class="btn steam" ${CONFIG.steamUrl ? `href="${CONFIG.steamUrl}"` : `aria-disabled="true" role="link" tabindex="0"`} data-confetti data-where="${where}"><svg class="steam-ico" viewBox="0 0 16 16" aria-hidden="true"><path d="M8 1a7 7 0 0 0-7 6.5l3.8 1.6a2 2 0 0 1 1.2-.4h.1L7.8 6v-.1a2.7 2.7 0 1 1 2.7 2.7h-.1L8 10.3a2 2 0 0 1-4 .3L1.3 9.5A7 7 0 1 0 8 1Zm-2.2 11a1.5 1.5 0 0 1-1.4-.9l.9.4a1.1 1.1 0 1 0 .9-2l-.9-.4a1.5 1.5 0 1 1 .5 2.9Zm4.7-4.2a1.8 1.8 0 1 1 0-3.6 1.8 1.8 0 0 1 0 3.6Z" fill="currentColor"/></svg><span>${esc(t.wishlistSteam)}</span><small>${esc(t.soon)}</small></a>`;

function notifyForm(t, l, id) {
  const h = home(l);
  return `<form class="notify" method="post" action="/api/notify" novalidate>
<h2 class="sr" id="${id}-t">${esc(t.notifyTitle)}</h2>
<label class="sr" for="${id}-e">${esc(t.notifyLabel)}</label>
<input id="${id}-e" type="email" name="email" required autocomplete="email" inputmode="email" placeholder="${esc(t.notifyPlaceholder)}" aria-describedby="${id}-f">
<div class="hp" aria-hidden="true"><label>Website <input type="text" name="website" tabindex="-1" autocomplete="off"></label></div>
<button class="btn" type="submit">${esc(t.notifyBtn)}</button>
<p class="msg" role="status" aria-live="polite"></p>
<p class="fine" id="${id}-f">${fmt(t.notifyFine, { privacy: h + 'privacy/' })}</p></form>`;
}

const pageHead = (t, id, kicker, title, epi, lead) => `<div class="head"><span class="kicker">${esc(kicker)}</span><h2 id="${id}-h">${esc(title)}</h2>
<p class="epi">${esc(epi)}</p>${lead ? `<p class="lead">${esc(lead)}</p>` : ''}<img class="px divider" src="/img/gen/ui/divider.png" alt="" width="320" height="24"></div>`;

const cardHtml = (c, l, t, { button = false, extra = '' } = {}) => {
  const tag = button ? 'button' : 'article';
  const fx = c.rarity === 'legendary' ? ' holo' : c.rarity === 'rare' ? ' glow' : '';
  const val = c.atk ? `<span class="val">⚔ ${c.atk}</span>` : c.def ? `<span class="val">⛨ ${c.def}</span>` : '';
  return `<${tag} class="card${fx}" data-rarity="${c.rarity}" data-id="${c.id}"${button ? ' type="button" aria-pressed="false"' : ''}${extra}>
<span class="face"><span class="cost" aria-label="${esc(t.mana)} ${c.cost}"><span>${c.cost}</span></span>${button ? '<span class="order"></span>' : ''}
<span class="name">${esc(loc(c.name, l))}</span><i class="art spr ${sprKey(c.icon.src)}" aria-hidden="true"></i>${val}
<span class="desc">${esc(loc(c.desc, l))}</span><span class="kind">${esc(t['rarity_' + c.rarity])}</span></span></${tag}>`;
};

export function renderHome(t, l, ctx, T) {
  const G = ctx.GAME;
  const B = G.biomes;
  const h = home(l);
  const other = LANGS.find((x) => x.code === 'pt_BR');
  const vars = {
    classes: G.classes.length, acts: B.length, first: loc(B[0].name, l), last: loc(B[5].actTitle, l),
    combos: G.combos.map((c) => loc(c.name, l)).join(', '), mechanics: B.map((b) => loc(b.boss.mechanic, l)).join(', '),
    cards: G.cardCounts.total, seals: G.seals.length, contact: CONFIG.contact,
  };
  const feats = [['featChoose', 'featChooseT'], ['featCross', 'featCrossT'], ['featChain', 'featChainT'], ['featBreak', 'featBreakT'], ['featCollect', 'featCollectT'], ['featClimb', 'featClimbT']];
  const runeIds = B.map((b) => b.id);

  // dados para o JS (temas, mini-mesa, embaralhar)
  const client = {
    lang: l.code,
    biomes: B.map((b) => ({
      id: b.id, name: loc(b.name, l), boss: loc(b.boss.name, l), castle: b.castle.src, cw: b.castle.w, bossImg: b.boss.idle.src,
      bossSpr: sprKey(b.boss.idle.src), bw: b.boss.idle.w, bh: b.boss.idle.h, castleSpr: sprKey(b.castleAnim.src),
      weather: b.weather, color: b.palette.ambient?.color || '#fff', celestial: b.palette.celestial, music: b.music,
    })),
    eclipse: { id: 'eclipse', name: t.eclipseName, boss: loc(B[5].boss.name, l), castle: B[5].castle.src, cw: B[5].castle.w, bossImg: B[5].boss.idle.src, bossSpr: sprKey(B[5].boss.idle.src), bw: B[5].boss.idle.w, bh: B[5].boss.idle.h, castleSpr: sprKey(B[5].castleAnim.src), weather: 'eclipse', color: '#f4e3a1', celestial: { kind: 'eclipse', x: 0.5, y: 0.22, r: 22, color: '#f4e3a1' }, music: B[5].music },
    t: {
      soundOn: t.soundOn, soundOff: t.soundOff, castleAlt: t.castleAlt, sending: t.sending, notifyOk: t.notifyOk, notifyBad: t.notifyBad, notifyRate: t.notifyRate,
      notifyNet: t.notifyNet, unsubLink: t.unsubLink, unsubPath: h + 'unsubscribe/', runeFound: t.runeFound, eclipseUnlocked: t.eclipseUnlocked, eclipseLink: t.eclipseLink,
      konamiOn: t.konamiOn, konamiOff: t.konamiOff, consoleMsg: t.consoleMsg, win: t.win, lose: t.lose, tableTake: t.tableTake, tableDeal: t.tableDeal, tableBlocked: t.tableBlocked,
      tableLoseHint: t.tableLoseHint, combo: loc(G.ui.combo, l), shuffleCard: t.shuffleCard, shuffleCreature: t.shuffleCreature, loreTitle: t.loreTitle, mana: t.mana, steamSoon: t.steamSoon,
    },
    table: tableData(G, l, t),
    shuffle: {
      creatures: B.flatMap((b) => [b.boss, ...b.enemies].map((e) => ({ name: loc(e.name, l), lore: loc(e.lore, l), spr: sprKey(e.idle.src), w: e.idle.w, h: e.idle.h, where: loc(b.name, l) }))).filter((x) => x.lore),
      cards: G.cards.map((c) => c.id),
    },
    sfx: G.sfx,
  };

  const hero = `<section class="hero vis" id="top" aria-labelledby="hero-h">
<div class="sky-fx" aria-hidden="true"><div class="celestial" id="celestial"></div><div class="clouds"></div></div>
<div class="backdrop" aria-hidden="true"></div><div class="loop" aria-hidden="true" data-src="/media/hero-loop.mp4" data-poster="/media/hero-loop.jpg"></div><div class="ground" aria-hidden="true"></div>
<div class="stage"><i class="spr boss-peek" id="boss" aria-hidden="true"></i><img class="px castle" id="castle" src="${B[0].castle.src}" width="${B[0].castle.w}" height="${B[0].castle.h}" alt="${esc(fmt(t.castleAlt, { biome: loc(B[0].name, l) }))}" fetchpriority="high"><i class="spr castle-anim" id="castle-anim" aria-hidden="true"></i></div>
<canvas class="weather px" id="weather" aria-hidden="true"></canvas>
<div class="copy"><h1 id="hero-h"><img class="px" src="${G.brand.wordmark.src}" width="${G.brand.wordmark.w * 2}" height="${G.brand.wordmark.h * 2}" alt="Runemoire"></h1>
<p class="tagline">${esc(loc(G.ui.subtitle, l))}</p>
<p class="biome-now">${esc(t.biomeNow)} <b id="biome-name">${esc(loc(B[0].name, l))}</b></p>
<div class="ctas">${steamBtn(t, 'top')}</div>${notifyForm(t, l, 'n1')}</div>
<a class="scroll" href="#intro">${esc(t.scroll)} ↓</a></section>`;

  const intro = `<section class="page" id="intro" aria-labelledby="intro-h"><div class="wrap">
${pageHead(t, 'intro', t.introKicker, t.introTitle, t.epiIntro)}
<div class="intro-grid"><div class="parch dict">
<p class="lead"><dfn>${esc(t.dictWord)}</dfn> <span class="pron">${esc(t.dictPron)}</span> <i>${esc(t.dictPos)}</i></p>
<p>${esc(t.dictDef)}</p><p class="ety">${esc(t.dictEty)}</p>
<button class="secret-rune s1" type="button" data-secret="1" aria-label="${esc(t.rune)}"><img class="px" src="/img/gen/runes/rune_${runeIds[0]}.png" width="20" height="20" alt=""></button></div>
<ul class="feats">${feats.map(([v, x], i) => `<li><img class="px" src="/img/gen/runes/rune_${runeIds[i]}.png" width="32" height="32" alt=""><span><b>${esc(t[v])}</b> ${esc(fmt(t[x], vars))}</span></li>`).join('')}</ul></div>
<div class="shuffle-row"><button class="btn ghost" id="shuffle" type="button" aria-describedby="shuffle-h">${esc(t.shuffle)}</button><p id="shuffle-h">${esc(t.shuffleHint)}</p></div>
<div class="shuffle-out" id="shuffle-out" aria-live="polite"></div></div></section>`;

  const trailers = `<section class="page" id="trailers" aria-labelledby="trailers-h"><div class="wrap">
${pageHead(t, 'trailers', t.trailersKicker, t.trailersTitle, t.epiTrailers, t.trailersLead)}
<div class="screens">
${[['trailer', t.trailerCine], ['gameplay', t.trailerPlay]].map(([f, label]) => `<figure class="tv"><div class="shot"><img src="/media/runemoire-${f}.jpg" width="1280" height="720" alt="" loading="lazy" decoding="async">
<button class="play" type="button" data-src="/media/runemoire-${f}.mp4" data-label="${esc(label)}" aria-label="${esc(t.play)}: ${esc(label)}"><span>${esc(t.play)}</span></button></div>
<figcaption><span>${esc(label)}</span>${f === 'trailer' ? `<button class="iconbtn" id="crt" type="button" aria-pressed="false" title="${esc(t.crtLabel)}">${esc(t.crt)}</button>` : ''}</figcaption></figure>`).join('')}
</div><button class="secret-rune s2" type="button" data-secret="2" aria-label="${esc(t.rune)}"><img class="px" src="/img/gen/runes/rune_${runeIds[1]}.png" width="20" height="20" alt=""></button></div></section>`;

  const play = `<section class="page" id="play" aria-labelledby="play-h"><div class="wrap">
${pageHead(t, 'play', t.playKicker, t.playTitle, t.epiPlay, t.playLead)}
<div class="table-wrap"><div class="table" id="table" data-ready="0">
<div class="foe"><div class="intent" id="intent"><img class="px" src="/img/icons/intent_attack.png" width="32" height="32" alt="${esc(t.intent)}"><span id="intent-v"></span></div>
<i class="spr sprite" id="foe-spr" aria-hidden="true"></i><div class="bar-hp" id="foe-hp"><i class="preview"></i><i class="cur"></i><b></b></div><span class="foe-name" id="foe-name"></span></div>
<div><div class="lane" id="lane" aria-label="${esc(t.playCards)}"></div><p class="combo-callout" id="callout" aria-live="polite"></p></div>
<div><div class="hud"><span class="mana" id="mana" aria-label="${esc(t.mana)}"></span><span id="you-block"></span>
<span class="table-actions"><button class="btn ghost" type="button" id="t-reset">${esc(t.reset)}</button><button class="btn" type="button" id="t-end">${esc(t.endTurn)}</button></span></div>
<div class="hand" id="hand" role="group" aria-label="${esc(t.playCards)}"></div><p class="log" id="t-log" aria-live="polite"></p></div></div>
<p class="table-help">${esc(fmt(t.tableHelp, { mana: 3 }))} <small>${esc(t.tableNote)}</small></p>
<ul class="combo-rules">${G.combos.map((c) => `<li><b>${esc(loc(c.name, l))}</b> ${comboRule(c, l)}</li>`).join('')}</ul></div></div></section>`;

  const classes = `<section class="page" id="classes" aria-labelledby="classes-h"><div class="wrap">
${pageHead(t, 'classes', t.classesKicker, t.classesTitle, t.epiClasses, t.classesLead)}
<div class="classes">${G.classes.map((c) => `<article class="parch klass"><div class="portrait"><img class="px emblem" src="${c.emblem.src}" width="${c.emblem.w * 2}" height="${c.emblem.h * 2}" alt="${esc(loc(c.name, l))}" loading="lazy"></div>
<h3>${esc(loc(c.name, l))}</h3><p>${esc(loc(c.desc, l))}.</p><p><b>${esc(t.passive)} · ${esc(loc(c.passiveName, l))}:</b> ${esc(loc(c.passiveDesc, l))}</p>
<p class="deckline"><b>${esc(t.starterDeck)}:</b></p><div class="deck">${c.starter.map((s) => `<span>${esc(loc(s.name, l))}</span>`).join('')}</div><p class="small">${esc(fmt(t.classCards, { n: c.cardCount }))}</p></article>`).join('')}</div></div></section>`;

  const bestiary = `<section class="page" id="bestiary" aria-labelledby="bestiary-h"><div class="wrap">
${pageHead(t, 'bestiary', t.bestiaryKicker, t.bestiaryTitle, t.epiBestiary, t.bestiaryLead)}
<div class="bestiary"><div class="acts" role="tablist" aria-label="${esc(t.bestiaryTitle)}">${B.map((b, i) => `<button role="tab" type="button" id="tab-${b.id}" aria-controls="act-${b.id}" aria-selected="${i === 0}" tabindex="${i === 0 ? 0 : -1}"><img class="px" src="/img/gen/runes/rune_${b.id}.png" width="24" height="24" alt="">${esc(fmt(t.act, { n: b.act }))}</button>`).join('')}</div>
<div class="spread">${B.map((b, i) => `<div role="tabpanel" id="act-${b.id}" aria-labelledby="tab-${b.id}" ${i ? 'hidden' : ''} data-biome-page="${b.id}">
<div class="leaf"><div class="parch side l"><h3>${esc(fmt(t.act, { n: b.act }))} · ${esc(loc(b.actTitle, l))} <small>— ${esc(loc(b.name, l))}</small></h3>
<div class="boss-stage b-${b.id}"><img class="px bg" src="${b.hall.src}" width="${b.hall.w}" height="${b.hall.h}" alt="" loading="lazy" decoding="async">${spr(b.boss.idle, 2, 'bs', loc(b.boss.name, l))}<div class="fog"></div></div></div>
<div class="parch side r"><p class="kicker">${esc(t.boss)}</p><h3 class="bossname">${esc(loc(b.boss.name, l))}</h3><p class="epithet">${esc(loc(b.boss.epithet, l))}</p>
<div class="mech"><div class="sig">${b.boss.token.frames ? spr(b.boss.token, 1, 'token') : `<img class="px" src="${b.boss.token.src}" width="48" height="48" alt="">`}<p><b>${esc(t.signature)} · ${esc(loc(b.boss.mechanic, l))}.</b> ${esc(loc(b.boss.signature, l))}</p></div>
<p class="lore">${esc(loc(b.boss.lore, l))}</p>
${b.fog ? `<p class="fogbadge"><b>?</b> ${esc(loc(G.ui.fogName, l))}: ${esc(loc(G.ui.fogDesc, l))}</p>` : ''}</div>
<p class="kicker">${esc(t.roster)}</p><div class="roster">${b.enemies.map((e) => `<figure>${spr(e.idle, 1, 'en', loc(e.name, l))}<figcaption>${esc(loc(e.name, l))}</figcaption></figure>`).join('')}</div>
${i === 5 ? `<button class="secret-rune s3" type="button" data-secret="3" aria-label="${esc(t.rune)}"><img class="px" src="/img/gen/runes/rune_${runeIds[2]}.png" width="20" height="20" alt=""></button>` : ''}</div></div></div>`).join('')}</div></div></div></section>`;

  const regular = G.cards.filter((c) => c.type !== 'joker');
  const order = { legendary: 0, rare: 1, uncommon: 2, common: 3 };
  regular.sort((a, b) => order[a.rarity] - order[b.rarity] || a.cost - b.cost);
  const cards = `<section class="page" id="cards" aria-labelledby="cards-h"><div class="wrap">
${pageHead(t, 'cards', t.cardsKicker, t.cardsTitle, t.epiCards, t.cardsLead)}
<div class="filters" role="group" aria-label="${esc(t.cardsTitle)}"><button type="button" data-r="all" aria-pressed="true">${esc(t.all)}</button>${['legendary', 'rare', 'uncommon', 'common'].map((r) => `<button type="button" data-r="${r}" aria-pressed="false">${esc(t['rarity_' + r])}</button>`).join('')}
<button class="secret-rune s4" type="button" data-secret="4" aria-label="${esc(t.rune)}"><img class="px" src="/img/gen/runes/rune_${runeIds[3]}.png" width="20" height="20" alt=""></button></div>
<div class="gallery-cards lazyvis">${regular.map((c) => cardHtml(c, l, t)).join('')}</div>
<div class="jokers"><div class="parch"><h3>${esc(t.jokersBoss)}</h3><p>${esc(t.jokersBossLead)}</p><div class="jk lazyvis">${G.jokersBoss.map((j) => `<figure title="${esc(loc(j.desc, l))}">${spr(j.icon, 1, 'jicon')}<figcaption>${esc(loc(j.name, l))}</figcaption></figure>`).join('')}</div></div>
<div class="parch"><h3>${esc(t.jokersCounter)}</h3><p>${esc(t.jokersCounterLead)}</p><div class="jk lazyvis">${G.jokersCounter.map((j) => `<figure title="${esc(loc(j.desc, l))}">${spr(j.icon, 1, 'jicon')}<figcaption>${esc(loc(j.name, l))}</figcaption></figure>`).join('')}</div></div></div></div></section>`;

  const beyond = `<section class="page" id="beyond" aria-labelledby="beyond-h"><div class="wrap">
${pageHead(t, 'beyond', t.beyondKicker, t.beyondTitle, t.epiBeyond, t.beyondLead)}
<div class="beyond"><div class="parch"><h3>${esc(loc(G.ui.endless, l))}</h3><p>${esc(t.endlessLead)}</p><h3>${esc(t.curses)}</h3><p>${esc(t.cursesLead)}</p>
<ul class="curses">${G.curses.map((c) => `<li><b>${esc(loc(c.name, l))}</b> — ${esc(loc(c.desc, l))}</li>`).join('')}</ul></div>
<div><h3>${esc(loc(G.ui.sealsTitle, l))}</h3><p class="dim">${esc(t.sealsLead)}</p><ol class="ladder">${G.seals.map((s) => `<li><span class="n">${s.n}</span><span><b>${esc(loc(s.name, l))}</b><span>${esc(loc(s.desc, l))}</span></span></li>`).join('')}</ol></div></div></div></section>`;

  const shotsL = l.code === 'pt_BR' ? G.shots.pt_BR : G.shots.en;
  const gallery = `<section class="page" id="gallery" aria-labelledby="gallery-h"><div class="wrap">
${pageHead(t, 'gallery', t.galleryKicker, t.galleryTitle, t.epiGallery, t.galleryLead)}
<div class="shots">${shotsL.map((s, i) => `<button type="button" data-full="${s.full}"><img src="${s.thumb}" width="960" height="540" alt="${esc(`Runemoire — ${i + 1}`)}" loading="lazy" decoding="async"></button>`).join('')}</div>
<dialog class="lightbox" id="lightbox"><form method="dialog"><button aria-label="${esc(t.close)}">×</button></form><img alt=""></dialog></div></section>`;

  const faq = `<section class="page" id="faq" aria-labelledby="faq-h"><div class="wrap narrow">
${pageHead(t, 'faq', t.faqKicker, t.faqTitle, t.epiFaq)}
<div class="faq">${t.faq.map(([q, a]) => `<details class="parch"><summary>${esc(q)}</summary><p>${esc(fmt(a, { contact: CONFIG.contact }))}</p></details>`).join('')}</div></div></section>`;

  const mb = (n) => (n / 1048576).toFixed(1).replace('.', l.code === 'en' ? '.' : ',') + ' MB';
  const press = `<section class="page" id="press" aria-labelledby="press-h"><div class="wrap">
${pageHead(t, 'press', t.pressKicker, t.pressTitle, t.epiPress, t.pressLead)}
<div class="press"><div class="parch"><h3>${esc(t.pressAbout)}</h3><p>${esc(t.pressAboutText)}</p><dl class="facts">
<dt>${esc(t.factTitle)}</dt><dd>Runemoire</dd><dt>${esc(t.factGenre)}</dt><dd>${esc(t.factGenreV)}</dd><dt>${esc(t.factDev)}</dt><dd>Daniel Cortez / DC Solutions</dd>
<dt>${esc(t.factPlatforms)}</dt><dd>${esc(t.factPlatformsV)}</dd><dt>${esc(t.factLangs)}</dt><dd>${LANGS.map((x) => x.self).join(', ')}</dd>
<dt>${esc(t.factRelease)}</dt><dd>${esc(t.factReleaseV)}</dd><dt>${esc(t.factContact)}</dt><dd><a href="mailto:${CONFIG.contact}">${CONFIG.contact}</a></dd></dl></div>
<div class="parch"><h3>${esc(t.downloads)}</h3><ul class="dl">
<li><a href="${G.presskit.src}" download><span>${esc(t.pressZip)}<br><small>${esc(t.pressZipNote)}</small></span><small>ZIP · ${mb(G.presskit.bytes)}</small></a></li>
<li><a href="/media/runemoire-trailer.mp4" download><span>${esc(t.pressVideo)}</span><small>MP4</small></a></li>
<li><a href="/media/runemoire-gameplay.mp4" download><span>${esc(t.pressGameplay)}</span><small>MP4</small></a></li>
<li><a href="${G.brand.logo.src}" download="runemoire_logo.png"><span>Logo (PNG)</span><small>PNG</small></a></li></ul></div></div></div></section>`;

  const final = `<section class="page final" id="final" aria-labelledby="final-h"><div class="wrap">
<div class="head"><h2 id="final-h">${esc(t.finalTitle)}</h2><p class="lead">${esc(t.finalLead)}</p></div>
<div class="ctas">${steamBtn(t, 'bottom')}</div>${notifyForm(t, l, 'n2')}</div></section>`;

  const opening = `<div class="opening" id="opening" hidden role="dialog" aria-modal="true" aria-labelledby="open-h">
<div class="scene"><img class="px base" src="${G.scene.menu.src}" width="400" height="256" alt="">
<img class="px tome" src="/img/gen/tome_closed.png" width="342" height="231" alt=""><div class="glow"></div></div>
<div class="ask"><h2 id="open-h"><img class="px" src="${G.brand.logo.src}" width="${G.brand.logo.w}" height="${G.brand.logo.h}" alt="Runemoire"></h2>
<p>${esc(t.openTitle)}. ${esc(t.openLead)}</p><div class="row"><button class="btn" id="open-sound" type="button">♪ ${esc(t.openSound)}</button><button class="btn ghost" id="open-silent" type="button">${esc(t.openSilent)}</button></div></div><div class="fade"></div></div>`;

  const hint = l.code === 'en' ? `<div class="langhint" id="langhint" data-for="pt" hidden lang="pt-BR"><span>${esc(fmt(T.pt_BR.langHint, { lang: '' }).replace(/\s*\.?$/, ''))} <a href="/pt/" hreflang="pt-BR">${other.self}</a>.</span><button type="button" aria-label="${esc(T.pt_BR.dismiss)}">×</button></div>` : '';

  return head(t, l, ctx, T, { title: t.htmlTitle, desc: t.metaDesc, path: h }) +
    `<script type="application/json" id="rm-data">${JSON.stringify(client).replace(/</g, '\\u003c')}</script>
<script type="application/ld+json">${JSON.stringify({ '@context': 'https://schema.org', '@type': 'VideoGame', name: 'Runemoire', alternateName: 'Grimoire', description: t.metaDesc, url: CONFIG.site + h, genre: ['Roguelike', 'Deckbuilder'], gamePlatform: 'PC', inLanguage: LANGS.map((x) => x.html), author: { '@type': 'Person', name: 'Daniel Cortez' }, publisher: { '@type': 'Organization', name: 'DC Solutions' }, image: `${CONFIG.site}/img/og/og_${l.code}.png` }).replace(/</g, '\\u003c')}</script>
</head><body>${opening}${bar(t, l, G)}<main id="main" tabindex="-1">${hero}<div class="book">${intro}${trailers}${play}${classes}${bestiary}${cards}${beyond}${gallery}${faq}${press}${final}</div></main>${foot(t, l, G)}${hint}
<canvas class="confetti" id="confetti" aria-hidden="true"></canvas></body></html>`;
}

function comboRule(c, l) {
  // regra exata do ComboSystem.lua: bônus = passo × min(cartas anteriores, teto)
  const step = c.step, cap = c.cap, max = step * cap;
  const unit = { volley: { en: 'damage', pt_BR: 'de dano', es: 'de daño', fr: 'dégâts', de: 'Schaden' }, wall: { en: 'Block', pt_BR: 'de Bloqueio', es: 'de Bloqueo', fr: 'de Blocage', de: 'Block' }, pair: { en: '', pt_BR: '', es: '', fr: '', de: '' } }[c.id];
  const T = {
    volley: { en: `+${step} damage for each attack played before it this turn (up to +${max}).`, pt_BR: `+${step} de dano para cada ataque jogado antes dele no turno (até +${max}).`, es: `+${step} de daño por cada ataque jugado antes en el turno (hasta +${max}).`, fr: `+${step} dégâts pour chaque attaque jouée avant elle ce tour (jusqu'à +${max}).`, de: `+${step} Schaden für jeden Angriff, der in diesem Zug davor gespielt wurde (bis +${max}).` },
    wall: { en: `+${step} Block for each defense played before it this turn (up to +${max}).`, pt_BR: `+${step} de Bloqueio para cada defesa jogada antes dela no turno (até +${max}).`, es: `+${step} de Bloqueo por cada defensa jugada antes en el turno (hasta +${max}).`, fr: `+${step} de Blocage pour chaque défense jouée avant elle ce tour (jusqu'à +${max}).`, de: `+${step} Block für jede Verteidigung, die in diesem Zug davor gespielt wurde (bis +${max}).` },
    pair: { en: `+${step} for each copy of the same card played before it (up to +${max}).`, pt_BR: `+${step} para cada cópia da mesma carta jogada antes dela (até +${max}).`, es: `+${step} por cada copia de la misma carta jugada antes (hasta +${max}).`, fr: `+${step} pour chaque copie de la même carte jouée avant elle (jusqu'à +${max}).`, de: `+${step} für jede Kopie derselben Karte, die davor gespielt wurde (bis +${max}).` },
  };
  void unit;
  return esc(T[c.id][l.code] || T[c.id].en);
}

function tableData(G, l, t) {
  // Mão de demonstração com cartas reais do Guerreiro; números do inimigo são de demonstração (o aviso fica na página).
  const pick = (id) => G.cards.find((c) => c.id === id);
  const hand = ['warrior_strike', 'warrior_quick_strike', 'warrior_defend', 'warrior_strike'].map((id) => {
    const c = pick(id);
    return { id: c.id, name: loc(c.name, l), desc: loc(c.desc, l), cost: c.cost, type: c.type, atk: c.atk, def: c.def, combo: (c.tags || []).includes('combo'), rarity: c.rarity, spr: sprKey(c.icon.src) };
  });
  const foe = G.biomes[0].enemies.find((e) => e.id === 'cursed_scarecrow') || G.biomes[0].enemies[0];
  return { mana: 3, hand, foe: { name: loc(foe.name, l), spr: sprKey(foe.idle.src), hp: 36, intent: 9 }, combos: G.combos.map((c) => ({ id: c.id, name: loc(c.name, l), step: c.step, cap: c.cap })), comboTag: t.comboTag, block: loc(G.ui.block, l), damage: loc(G.ui.damage, l) };
}

function simple(t, l, ctx, T, { title, path: p, body, noindex = true }) {
  return head(t, l, ctx, T, { title: `${title} — Runemoire`, desc: t.metaDesc, path: p, noindex, alts: !noindex }) +
    `<script type="application/json" id="rm-data">${JSON.stringify({ lang: l.code, biomes: [], eclipse: null, t: { unsubOk: t.unsubOk, unsubNone: t.unsubNone, unsubBad: t.unsubBad, sending: t.sending }, simple: true }).replace(/</g, '\\u003c')}</script>
</head><body class="simple-page"><a class="skip" href="#main">${esc(t.skip)}</a><main id="main" class="simple vis"><div class="wrap">${body}</div></main>${foot(t, l, ctx.GAME)}</body></html>`;
}

export function renderPrivacy(t, l, ctx, T) {
  const P = PRIVACY[l.code] || PRIVACY.en;
  const body = `<article class="parch prose"><h1>${esc(t.privTitle)}</h1>${P.map((x) => (x.startsWith('#') ? `<h2>${esc(x.slice(1))}</h2>` : `<p>${fmt(esc(x), { contact: `<a href="mailto:${CONFIG.contact}">${CONFIG.contact}</a>` })}</p>`)).join('')}
<p><a href="${home(l)}">← Runemoire</a></p></article>`;
  return simple(t, l, ctx, T, { title: t.privTitle, path: home(l) + 'privacy/', body, noindex: false });
}

export function renderUnsub(t, l, ctx, T) {
  const body = `<article class="parch prose"><h1>${esc(t.unsubTitle)}</h1><form id="unsub" class="unsub"><button class="btn" type="submit">${esc(t.unsubBtn)}</button><p class="msg" role="status" aria-live="polite"></p></form>
<p><a href="${home(l)}">← Runemoire</a></p></article>`;
  return simple(t, l, ctx, T, { title: t.unsubTitle, path: home(l) + 'unsubscribe/', body });
}

export function render404(t, l, ctx, T) {
  const body = `<article class="parch prose nf"><img class="px torn" src="/img/gen/page_torn.png" alt=""><h1>${esc(t.nfTitle)}</h1><p>${esc(t.nfText)}</p><p><a class="btn" href="${home(l)}">${esc(t.nfBack)}</a></p></article>`;
  return simple(t, l, ctx, T, { title: t.nfTitle, path: home(l) + '404', body });
}

export function renderEclipse(t, l, ctx, T) {
  const B = ctx.GAME.biomes[5];
  const body = `<article class="parch prose lorepage"><h1>${esc(t.eclipseTitle)}</h1>
${LANGS.map((x) => `<blockquote class="lore" lang="${x.html}"><p>${esc(loc(B.boss.lore, x))}</p><footer>— ${esc(loc(B.boss.name, x))}, ${esc(loc(B.boss.epithet, x))}</footer></blockquote>`).join('')}
<img class="px wall" src="/img/gen/eclipse_wallpaper.png" width="688" height="384" alt="">
<p><a class="btn" href="/img/eclipse_wallpaper_3x.png" download>${esc(t.eclipseWall)}</a> <a href="/">${esc(t.eclipseBack)}</a></p></article>`;
  return simple(t, l, ctx, T, { title: t.eclipseTitle, path: '/eclipse/', body }).replace('<html lang="en" data-biome="fields">', '<html lang="en" data-biome="eclipse">');
}

const PRIVACY = {
  en: ['#What we collect', 'Only if you sign up for the launch notice: your email address, the language of the page and the date. Nothing else. No cookies, no ads, no third-party trackers.', '#Why', 'To send you one email when Runemoire launches. We will not sell or share your address.', '#Where it is stored', 'In a Cloudflare D1 database in the account of the developer. Cloudflare processes requests to keep the site online and safe.', '#Your rights (LGPD / GDPR)', 'You can leave the list at any time with the link shown after you sign up, or by writing to {contact}. We erase your email on request and after the launch email is sent.', '#On your device', 'The site remembers your chosen biome, sound and motion settings and the runes you found, in your browser\'s local storage. It never leaves your device.', '#Contact', '{contact}'],
  pt_BR: ['#O que coletamos', 'Só se você pedir o aviso de lançamento: seu e-mail, o idioma da página e a data. Mais nada. Sem cookies, sem anúncios, sem rastreadores de terceiros.', '#Para quê', 'Para mandar um e-mail quando o Runemoire for lançado. Não vendemos nem compartilhamos seu endereço.', '#Onde fica guardado', 'Num banco Cloudflare D1, na conta do desenvolvedor. A Cloudflare processa as requisições para manter o site no ar e seguro.', '#Seus direitos (LGPD / GDPR)', 'Você pode sair da lista quando quiser, pelo link que aparece depois do cadastro, ou escrevendo para {contact}. Apagamos seu e-mail a pedido e depois do e-mail de lançamento.', '#No seu aparelho', 'O site lembra o bioma, o som e o movimento que você escolheu e as runas que achou, no armazenamento local do navegador. Isso nunca sai do seu aparelho.', '#Contato', '{contact}'],
  es: ['#Qué recopilamos', 'Solo si pides el aviso de lanzamiento: tu correo, el idioma de la página y la fecha. Nada más. Sin cookies, sin anuncios, sin rastreadores de terceros.', '#Para qué', 'Para enviarte un correo cuando Runemoire salga. No vendemos ni compartimos tu dirección.', '#Dónde se guarda', 'En una base de datos Cloudflare D1, en la cuenta del desarrollador. Cloudflare procesa las solicitudes para mantener el sitio en línea y seguro.', '#Tus derechos (RGPD)', 'Puedes salir de la lista cuando quieras con el enlace que aparece tras registrarte, o escribiendo a {contact}. Borramos tu correo a petición y después del correo de lanzamiento.', '#En tu dispositivo', 'El sitio recuerda el bioma, el sonido y el movimiento que elegiste y las runas que encontraste, en el almacenamiento local del navegador. Nunca sale de tu dispositivo.', '#Contacto', '{contact}'],
  fr: ['#Ce que nous collectons', 'Seulement si tu demandes l\'avis de sortie : ton e-mail, la langue de la page et la date. Rien d\'autre. Pas de cookies, pas de publicité, pas de traceurs tiers.', '#Pourquoi', 'Pour t\'envoyer un e-mail à la sortie de Runemoire. Nous ne vendons ni ne partageons ton adresse.', '#Où c\'est stocké', 'Dans une base Cloudflare D1, sur le compte du développeur. Cloudflare traite les requêtes pour garder le site en ligne et sûr.', '#Tes droits (RGPD)', 'Tu peux quitter la liste à tout moment avec le lien affiché après l\'inscription, ou en écrivant à {contact}. Nous effaçons ton e-mail sur demande et après l\'e-mail de sortie.', '#Sur ton appareil', 'Le site retient le biome, le son et le mouvement choisis et les runes trouvées, dans le stockage local du navigateur. Rien ne quitte ton appareil.', '#Contact', '{contact}'],
  de: ['#Was wir erheben', 'Nur wenn du dich für die Release-Nachricht einträgst: deine E-Mail-Adresse, die Sprache der Seite und das Datum. Sonst nichts. Keine Cookies, keine Werbung, keine Tracker von Dritten.', '#Wozu', 'Um dir eine E-Mail zu schicken, wenn Runemoire erscheint. Wir verkaufen oder teilen deine Adresse nicht.', '#Wo es gespeichert wird', 'In einer Cloudflare-D1-Datenbank im Konto des Entwicklers. Cloudflare verarbeitet Anfragen, um die Seite online und sicher zu halten.', '#Deine Rechte (DSGVO)', 'Du kannst die Liste jederzeit über den Link nach der Anmeldung verlassen oder an {contact} schreiben. Wir löschen deine E-Mail auf Wunsch und nach der Release-E-Mail.', '#Auf deinem Gerät', 'Die Seite merkt sich gewähltes Biom, Ton- und Bewegungseinstellungen und gefundene Runen im lokalen Speicher deines Browsers. Nichts davon verlässt dein Gerät.', '#Kontakt', '{contact}'],
};
