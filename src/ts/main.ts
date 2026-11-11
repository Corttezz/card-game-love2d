// Runemoire — o grimório vivo. Sem rastreador; só localStorage para lembrar bioma, som e runas achadas.
import { Weather, type Style } from './weather';
import { initTable } from './table';
import { chiptune, Ambient } from './audio';
import { confetti } from './confetti';

type Biome = {
  id: string; name: string; boss: string; castle: string; cw: number; bossImg: string; bossSpr: string; bw: number; bh: number; castleSpr: string;
  weather: Style; color: string; celestial: { kind: string; x: number; y: number; r: number; color: string }; music?: string;
};
type Creature = { name: string; lore: string; spr: string; w: number; h: number; where: string };
type Data = {
  lang: string; biomes: Biome[]; eclipse: Biome; t: Record<string, string>; table: unknown; simple?: boolean;
  shuffle?: { creatures: Creature[]; cards: string[] }; sfx?: Record<string, string>;
};

const $ = <T extends Element = HTMLElement>(s: string, r: ParentNode = document) => r.querySelector(s) as T | null;
const $$ = <T extends Element = HTMLElement>(s: string, r: ParentNode = document) => Array.from(r.querySelectorAll(s)) as T[];
const D: Data = JSON.parse($('#rm-data')?.textContent || '{}');
const store = {
  get: (k: string) => { try { return localStorage.getItem('rm.' + k); } catch { return null; } },
  set: (k: string, v: string) => { try { localStorage.setItem('rm.' + k, v); } catch { /* modo privado */ } },
};
const reduced = () => matchMedia('(prefers-reduced-motion: reduce)').matches || document.body.classList.contains('reduced');
const sfxUrl = (k: string) => D.sfx?.[k];

let toastT = 0;
function toast(msg: string, ms = 3200) {
  const el = $('#toast');
  if (!el) return;
  el.innerHTML = msg; el.classList.add('on');
  clearTimeout(toastT); toastT = window.setTimeout(() => el.classList.remove('on'), ms);
}

// ---------- som (só com opt-in) ----------
const ambient = new Ambient();
let soundOn = store.get('sound') === '1';
const playSfx = (k: string) => { const u = sfxUrl(k); if (u) ambient.sfx(u); };
function setSound(on: boolean) {
  soundOn = on; store.set('sound', on ? '1' : '0');
  const b = $('#sound');
  if (b) { b.setAttribute('aria-pressed', String(on)); b.setAttribute('aria-label', on ? D.t.soundOff : D.t.soundOn); b.title = on ? D.t.soundOff : D.t.soundOn; }
  if (on) ambient.play(current()?.music); else ambient.stop();
}

// ---------- tema = bioma ----------
let weather: Weather | null = null;
const all = () => [...D.biomes, D.eclipse];
const current = () => all().find((b) => b.id === document.documentElement.dataset.biome);
function setBiome(id: string, save = true) {
  const b = all().find((x) => x.id === id) || D.biomes[0];
  const root = document.documentElement;
  root.dataset.biome = b.id;
  if (save) store.set('biome', b.id);
  for (const r of $$('.rune[data-biome]')) r.setAttribute('aria-pressed', String(r.dataset.biome === b.id));
  const castle = $<HTMLImageElement>('#castle');
  if (castle) { castle.src = b.castle; castle.style.setProperty('--cw', b.cw + 'px'); castle.alt = D.t.castleAlt.replace('{biome}', b.name); }
  const ca = $('#castle-anim');
  if (ca) { ca.className = `spr castle-anim ${b.castleSpr} vis`; ca.style.setProperty('--cw', b.cw + 'px'); }
  const boss = $('#boss');
  if (boss) {
    boss.classList.add('hide');
    window.setTimeout(() => { boss.className = `spr boss-peek ${b.bossSpr} vis hide`; boss.style.setProperty('--bw', b.bw + 'px'); requestAnimationFrame(() => boss.classList.remove('hide')); }, reduced() ? 0 : 450);
  }
  const cel = $('#celestial');
  if (cel) {
    cel.className = 'celestial ' + b.celestial.kind;
    cel.style.setProperty('--cx', String(b.celestial.x)); cel.style.setProperty('--cy', String(b.celestial.y));
    cel.style.setProperty('--cr', String(b.celestial.r)); cel.style.setProperty('--celestial', b.celestial.color);
  }
  const lbl = $('#biome-name'); if (lbl) lbl.textContent = b.name;
  weather?.set(b.weather, b.color);
  if (soundOn) ambient.play(b.music);
  const meta = $<HTMLMetaElement>('meta[name="theme-color"]'); if (meta) meta.content = getComputedStyle(root).getPropertyValue('--sky-0').trim();
}
function initialBiome() {
  const saved = store.get('biome');
  if (saved && (saved !== 'eclipse' || store.get('eclipse') === '1')) return saved;
  const h = new Date().getHours(); // primeira visita: bioma pela hora local
  return h < 5 ? 'frost' : h < 10 ? 'fields' : h < 14 ? 'highlands' : h < 17 ? 'marsh' : h < 20 ? 'dusk' : 'abyss';
}

// ---------- abertura (o tomo) ----------
function opening() {
  const el = $('#opening');
  if (!el) return;
  const force = location.hash === '#tome';
  if (store.get('opened') === '1' && !force) { el.remove(); return; }
  el.hidden = false;
  document.body.classList.add('locked');
  const go = (withSound: boolean) => {
    store.set('opened', '1');
    if (withSound) { setSound(true); playSfx('menu-open'); }
    el.classList.add('is-open');
    window.setTimeout(() => el.classList.add('is-leaving'), reduced() ? 0 : 1100);
    window.setTimeout(() => {
      el.remove(); document.body.classList.remove('locked');
      $('#main')?.focus({ preventScroll: true });
      if (force) history.replaceState(null, '', location.pathname);
    }, reduced() ? 0 : 1800);
  };
  $('#open-sound')?.addEventListener('click', () => go(true));
  $('#open-silent')?.addEventListener('click', () => go(false));
  el.addEventListener('keydown', (e) => { if (e.key === 'Escape') go(false); });
  $<HTMLButtonElement>('#open-silent')?.focus();
}

// ---------- "Me avise" ----------
function notifyForms() {
  for (const f of $$<HTMLFormElement>('form.notify')) {
    f.addEventListener('submit', async (e) => {
      e.preventDefault();
      const msg = $('.msg', f)!; const btn = $<HTMLButtonElement>('button[type=submit]', f)!;
      const fd = new FormData(f);
      const email = String(fd.get('email') || '').trim();
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) { msg.className = 'msg err'; msg.textContent = D.t.notifyBad; $('input[type=email]', f)?.focus(); return; }
      msg.className = 'msg'; msg.textContent = D.t.sending; btn.disabled = true;
      try {
        const r = await fetch('/api/notify', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, lang: D.lang, website: fd.get('website') }) });
        const j = await r.json().catch(() => ({}));
        if (r.ok && j.ok) {
          msg.textContent = D.t.notifyOk + ' ';
          if (j.token) { const a = document.createElement('a'); a.href = `${D.t.unsubPath}?t=${encodeURIComponent(j.token)}`; a.textContent = D.t.unsubLink; msg.append(a); }
          f.reset(); playSfx('joker-tick');
        } else { msg.classList.add('err'); msg.textContent = r.status === 429 ? D.t.notifyRate : D.t.notifyBad; }
      } catch { msg.classList.add('err'); msg.textContent = D.t.notifyNet; }
      btn.disabled = false;
    });
  }
}

// ---------- trailers: vídeo só sob demanda ----------
function trailers() {
  for (const b of $$<HTMLButtonElement>('.tv .play')) {
    b.addEventListener('click', () => {
      const shot = b.closest('.shot')!;
      const v = document.createElement('video');
      v.src = b.dataset.src!; v.controls = true; v.autoplay = true; v.playsInline = true; v.preload = 'auto';
      v.setAttribute('aria-label', b.dataset.label || '');
      shot.replaceChildren(v); v.focus();
      ambient.duck(true); v.addEventListener('pause', () => ambient.duck(false)); v.addEventListener('ended', () => ambient.duck(false));
    });
  }
  const crt = $<HTMLButtonElement>('#crt');
  crt?.addEventListener('click', () => {
    const on = !document.body.classList.contains('crt');
    document.body.classList.toggle('crt', on); crt.setAttribute('aria-pressed', String(on));
  });
}

// ---------- herói: vídeo de gameplay mudo em loop, depois do primeiro paint ----------
function heroLoop() {
  const box = $('.hero .loop');
  if (!box || reduced() || innerWidth < 720) return;
  const conn = (navigator as unknown as { connection?: { saveData?: boolean } }).connection;
  if (conn?.saveData) return;
  const start = () => {
    const v = document.createElement('video');
    v.muted = true; v.loop = true; v.playsInline = true; v.autoplay = true; v.preload = 'auto';
    v.poster = box.dataset.poster!; v.src = box.dataset.src!; v.setAttribute('aria-hidden', 'true'); v.tabIndex = -1;
    box.append(v);
    v.defaultPlaybackRate = 0.6; v.playbackRate = 0.6;
    v.addEventListener('playing', () => box.classList.add('on'), { once: true });
    v.play().catch(() => {});
  };
  if (document.readyState === 'complete') setTimeout(start, 600); else addEventListener('load', () => setTimeout(start, 600), { once: true });
}

// ---------- bestiário (abas = atos, a página vira) ----------
function bestiary() {
  const tabs = $$<HTMLButtonElement>('.acts [role=tab]');
  const show = (i: number, focus = false) => {
    tabs.forEach((t, j) => { t.setAttribute('aria-selected', String(i === j)); t.tabIndex = i === j ? 0 : -1; });
    for (const p of $$<HTMLElement>('.spread [role=tabpanel]')) p.hidden = p.id !== tabs[i].getAttribute('aria-controls');
    const leaf = $(`#${tabs[i].getAttribute('aria-controls')} .leaf`);
    if (leaf && !reduced()) { leaf.classList.remove('turn'); void (leaf as HTMLElement).offsetWidth; leaf.classList.add('turn'); }
    if (focus) tabs[i].focus();
    playSfx('card-draw');
  };
  tabs.forEach((t, i) => {
    t.addEventListener('click', () => show(i));
    t.addEventListener('keydown', (e) => {
      const k = e.key; let n = -1;
      if (k === 'ArrowRight') n = (i + 1) % tabs.length; else if (k === 'ArrowLeft') n = (i - 1 + tabs.length) % tabs.length; else if (k === 'Home') n = 0; else if (k === 'End') n = tabs.length - 1;
      if (n >= 0) { e.preventDefault(); show(n, true); }
    });
  });
}

// ---------- cartas: filtro por raridade, tilt e holo ----------
function cards() {
  const btns = $$<HTMLButtonElement>('.filters button[data-r]');
  for (const b of btns) b.addEventListener('click', () => {
    for (const x of btns) x.setAttribute('aria-pressed', String(x === b));
    const r = b.dataset.r!;
    for (const c of $$<HTMLElement>('.gallery-cards .card')) c.hidden = r !== 'all' && c.dataset.rarity !== r;
  });
  tilt($$('.gallery-cards .card'));
}
export function tilt(els: HTMLElement[]) {
  if (reduced() || matchMedia('(hover: none)').matches) return;
  for (const el of els) {
    el.addEventListener('pointermove', (e) => {
      const r = el.getBoundingClientRect();
      const x = (e.clientX - r.left) / r.width - 0.5, y = (e.clientY - r.top) / r.height - 0.5;
      el.style.setProperty('--ry', (x * 18).toFixed(1) + 'deg'); el.style.setProperty('--rx', (-y * 18).toFixed(1) + 'deg');
      el.style.setProperty('--ha', Math.round((x + y) * 180) + 'deg');
    });
    el.addEventListener('pointerleave', () => { el.style.removeProperty('--rx'); el.style.removeProperty('--ry'); });
  }
}

// ---------- embaralhar: carta, criatura ou fragmento de lore ao acaso ----------
function shuffle() {
  const btn = $('#shuffle'), out = $('#shuffle-out');
  if (!btn || !out || !D.shuffle) return;
  btn.addEventListener('click', () => {
    out.classList.add('vis');
    const S = D.shuffle!;
    if (Math.random() < 0.4) {
      const id = S.cards[Math.floor(Math.random() * S.cards.length)];
      const src = $(`.gallery-cards .card[data-id="${id}"]`) || $(`.card[data-id="${id}"]`);
      const k = src ? (src.cloneNode(true) as HTMLElement) : null;
      out.replaceChildren();
      const p = document.createElement('p'); p.className = 'kicker'; p.textContent = D.t.shuffleCard;
      if (k) { k.removeAttribute('id'); k.hidden = false; out.append(p, k); tilt([k]); }
    } else {
      const c = S.creatures[Math.floor(Math.random() * S.creatures.length)];
      out.innerHTML = `<div class="parch frag"><p class="kicker"></p><i class="spr ${c.spr} vis" aria-hidden="true"></i><h3></h3><p class="lore"></p></div>`;
      ($('.kicker', out) as HTMLElement).textContent = `${D.t.loreTitle} · ${c.where}`;
      ($('h3', out) as HTMLElement).textContent = c.name;
      ($('.lore', out) as HTMLElement).textContent = c.lore;
    }
    playSfx('card-draw');
  });
}

// ---------- galeria ----------
function lightbox() {
  const dlg = $<HTMLDialogElement>('#lightbox');
  if (!dlg) return;
  const im = $<HTMLImageElement>('img', dlg)!;
  for (const b of $$<HTMLButtonElement>('.shots button')) b.addEventListener('click', () => { im.src = b.dataset.full!; im.alt = $('img', b)?.getAttribute('alt') || ''; dlg.showModal(); });
  dlg.addEventListener('click', (e) => { if (e.target === dlg) dlg.close(); });
}

// ---------- sprites só carregam quando a página chega perto da tela ----------
function lazyVis() {
  const els = $$('.page, .lazyvis');
  if (!('IntersectionObserver' in window)) { els.forEach((e) => e.classList.add('vis')); return; }
  const io = new IntersectionObserver((es) => { for (const e of es) if (e.isIntersecting) { e.target.classList.add('vis'); io.unobserve(e.target); } }, { rootMargin: '600px 0px' });
  els.forEach((e) => io.observe(e));
}

// ---------- segredos ----------
function secrets() {
  const found = new Set((store.get('runes') || '').split(',').filter(Boolean));
  const unlock = () => { const e = $('.rune[data-biome=eclipse]'); if (e) e.hidden = false; };
  if (store.get('eclipse') === '1') unlock();
  for (const b of $$<HTMLButtonElement>('.secret-rune')) {
    const id = b.dataset.secret!;
    if (found.has(id)) b.classList.add('found');
    b.addEventListener('click', () => {
      if (found.has(id)) return;
      found.add(id); store.set('runes', [...found].join(',')); b.classList.add('found');
      playSfx('joker-tick');
      const r = b.getBoundingClientRect(); confetti(r.left, r.top);
      if (found.size >= 5) {
        store.set('eclipse', '1'); unlock(); setBiome('eclipse');
        toast(D.t.eclipseUnlocked.replace('{link}', `<a href="/eclipse/">${D.t.eclipseLink}</a>`), 10000);
      } else toast(D.t.runeFound.replace('{n}', String(found.size)));
    });
  }
  const K = ['ArrowUp', 'ArrowUp', 'ArrowDown', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'ArrowLeft', 'ArrowRight', 'b', 'a'];
  let i = 0;
  addEventListener('keydown', (e) => {
    const k = e.key.length === 1 ? e.key.toLowerCase() : e.key;
    i = k === K[i] ? i + 1 : k === K[0] ? 1 : 0;
    if (i === K.length) {
      i = 0;
      const on = document.body.classList.toggle('crt-all');
      toast(on ? D.t.konamiOn : D.t.konamiOff);
      if (on) chiptune();
    }
  });
  console.log('%cRUNEMOIRE', 'font: 28px monospace; color: #e8b85a; text-shadow: 2px 2px 0 #2a1d14');
  console.log(`%c${D.t.consoleMsg}`, 'font: 13px monospace; color: #c9b99b');
}

// ---------- CTA da Steam (a página ainda não existe: confete e aviso) ----------
function steam() {
  for (const a of $$<HTMLAnchorElement>('[data-confetti]')) {
    const fire = (e: Event) => {
      const r = a.getBoundingClientRect(); confetti(r.left + r.width / 2, r.top);
      if (a.getAttribute('aria-disabled') === 'true') { e.preventDefault(); toast(D.t.steamSoon); }
    };
    a.addEventListener('click', fire);
    a.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); fire(e); } });
  }
}

function langHint() {
  const el = $('#langhint');
  if (!el || store.get('langhint') === '0') return;
  const want = (navigator.languages || [navigator.language]).map((l) => l.toLowerCase());
  if (D.lang === 'en' && want.some((l) => l.startsWith(el.dataset.for!))) el.hidden = false;
  $('button', el)?.addEventListener('click', () => { el.hidden = true; store.set('langhint', '0'); });
}

// ---------- páginas simples ----------
function unsubscribe() {
  const f = $<HTMLFormElement>('#unsub');
  if (!f) return;
  const tok = new URLSearchParams(location.search).get('t') || '';
  const msg = $('.msg', f)!;
  f.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!tok) { msg.textContent = D.t.unsubBad; return; }
    msg.textContent = D.t.sending;
    const r = await fetch('/api/unsubscribe', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ token: tok }) }).catch(() => null);
    const j = r ? await r.json().catch(() => ({})) : {};
    msg.textContent = r && r.ok && j.removed ? D.t.unsubOk : r && r.ok ? D.t.unsubNone : D.t.unsubBad;
  });
}

function controls() {
  $('#sound')?.addEventListener('click', () => setSound(!soundOn));
  $('#sound')?.setAttribute('aria-pressed', String(soundOn));
  const rm = $<HTMLButtonElement>('#motion');
  const apply = (on: boolean) => {
    document.body.classList.toggle('reduced', on); rm?.setAttribute('aria-pressed', String(on));
    const c = current(); if (weather && c) weather.set(c.weather, c.color);
  };
  if (store.get('reduced') === '1') apply(true);
  rm?.addEventListener('click', () => { const on = !document.body.classList.contains('reduced'); store.set('reduced', on ? '1' : '0'); apply(on); });
  $('#replay')?.addEventListener('click', (e) => { e.preventDefault(); store.set('opened', '0'); location.href = (location.pathname.match(/^\/(pt|es|fr|de)\//)?.[0] || '/') + '#tome'; if (location.hash === '#tome') location.reload(); });
  $<HTMLSelectElement>('#lang')?.addEventListener('change', (e) => { location.href = (e.target as HTMLSelectElement).value + location.hash; });
}

function boot() {
  controls();
  if (D.simple) { unsubscribe(); document.documentElement.dataset.biome = document.documentElement.dataset.biome === 'eclipse' ? 'eclipse' : (store.get('biome') && store.get('biome') !== 'eclipse' ? store.get('biome')! : 'dusk'); return; }
  const cv = $<HTMLCanvasElement>('#weather');
  if (cv) { weather = new Weather(cv); weather.load('/img/gen/fx'); }
  for (const r of $$<HTMLButtonElement>('.rune[data-biome]')) r.addEventListener('click', () => { setBiome(r.dataset.biome!); playSfx('button-click'); });
  setBiome(initialBiome(), false);
  opening(); notifyForms(); trailers(); heroLoop(); bestiary(); cards(); shuffle(); lightbox(); lazyVis(); secrets(); steam(); langHint();
  initTable(D.table as never, D.t, { sfx: (s) => ambient.sfx(s), tilt, confetti, sfxMap: D.sfx });
  if (soundOn) addEventListener('pointerdown', () => ambient.play(current()?.music), { once: true });
}
boot();
