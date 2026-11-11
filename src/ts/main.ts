// runemoire.com v3: a tela de título do jogo no navegador.
// A capela é desenhada como no jogo (components/Menu.lua): os 4 quadros da cena alternam a 10 fps (a chama das velas),
// brilho das velas, brasas, tremor quente e vinheta, em escala inteira nos pixels do aparelho.
// Nada é guardado no aparelho; som só com o visitante ligando.
type Data = { lang: string; unsubPath?: string; pool?: string[]; cardBase?: string; t: Record<string, string> };
const $ = <T extends Element = HTMLElement>(s: string, r: ParentNode = document) => r.querySelector(s) as T | null;
const $$ = <T extends Element = HTMLElement>(s: string, r: ParentNode = document) => Array.from(r.querySelectorAll(s)) as T[];
const D: Data = JSON.parse($('#rm-data')?.textContent || '{"t":{}}');
const root = document.documentElement;
root.classList.remove('no-js'); root.classList.add('js');
const osReduced = matchMedia('(prefers-reduced-motion: reduce)');
const reduced = () => osReduced.matches || document.body.classList.contains('reduced');

// ---------------- som (desligado por padrão) ----------------
const S = { music: false, sfx: false, a: null as HTMLAudioElement | null };
const sfx = (n: string) => { if (!S.sfx) return; const a = new Audio(`/media/v3/${n}.mp3`); a.volume = 0.5; a.play().catch(() => {}); };
function setMusic(on: boolean) {
  S.music = on;
  if (on) { if (!S.a) { S.a = new Audio('/media/v3/menu.mp3'); S.a.loop = true; S.a.volume = 0.35; } S.a.play().catch(() => {}); }
  else S.a?.pause();
}

// ---------------- a cena ----------------
const SEQ = ['menu', 'menu_normal', 'menu', 'menu_1', 'menu_2', 'menu_normal', 'menu'];
const imgs: Record<string, HTMLImageElement> = {};
const cv = $<HTMLCanvasElement>('#scene');
const ctx = cv?.getContext('2d', { alpha: false }) || null;
let k = 1, sx = 0, sy = 0, W = 0, H = 0, topColor = '#141018', bottomColor = '#141018';
let dark = document.body.classList.contains('dark') ? 1 : 0, darkTarget = dark;
type Ember = { x: number; y: number; vy: number; life: number; t: number; c: number };
const embers: Ember[] = [];
const CANDLES: [number, number][] = [[0.209, 0.44], [0.770, 0.44]];

function layout() {
  if (!cv || !ctx) return;
  const dpr = Math.min(window.devicePixelRatio || 1, 3);
  W = Math.round(innerWidth * dpr); H = Math.round(innerHeight * dpr);
  cv.width = W; cv.height = H;
  ctx.imageSmoothingEnabled = false;
  const portrait = innerWidth / innerHeight < 0.8;
  if (portrait) {
    // retrato: a capela mais perto (livro e altar no centro, velas cortadas nas bordas), apoiada embaixo
    k = Math.max(1, Math.floor(W / 195));
    sx = Math.round((W - 400 * k) / 2); sy = Math.round(H * 0.74 - 190 * k);
  } else {
    k = Math.max(1, Math.ceil(Math.max(W / 400, H / 256)));
    sx = Math.round((W - 400 * k) / 2); sy = Math.round((H - 256 * k) / 2);
  }
  // posição do livro e das velas na tela, para o CSS alinhar o menu e as cartas com a cena
  root.style.setProperty('--book-y', `${(sy + 150 * k) / dpr}px`);
  root.style.setProperty('--scene-top', `${Math.max(0, sy) / dpr}px`);
  root.style.setProperty('--px', `${k / dpr}px`);
  root.style.setProperty('--menu-top-p', `${(sy + 56 * k) / dpr}px`);
  root.style.setProperty('--cards-top-p', `${(sy - 12 * k) / dpr}px`);
  draw(performance.now(), true);
}

function noise(t: number, s: number) { return (Math.sin(t * 1.9 + s) * 0.5 + Math.sin(t * 3.7 + s * 2.1) * 0.3 + Math.sin(t * 7.3 + s * 0.7) * 0.2) * 0.5 + 0.5; }

let last = 0;
function draw(now: number, force = false) {
  if (!ctx) return;
  const t = now / 1000;
  const frame = reduced() ? 'menu' : SEQ[Math.floor(t * 10) % SEQ.length];
  const img = imgs[frame] || imgs.menu;
  ctx.fillStyle = topColor; ctx.fillRect(0, 0, W, H);
  if (sy > 0) {
    // acima da capela (retrato): a parede escura do topo da cena, sumindo no preto
    const g = ctx.createLinearGradient(0, 0, 0, sy + 2);
    g.addColorStop(0, '#0c0a10'); g.addColorStop(1, topColor);
    ctx.fillStyle = g; ctx.fillRect(0, 0, W, sy + 2);
  }
  const by = sy + 256 * k;
  if (by < H) {
    // abaixo do altar (retrato): a pedra da frente do altar sumindo no escuro
    const g2 = ctx.createLinearGradient(0, by - 2, 0, H);
    g2.addColorStop(0, bottomColor); g2.addColorStop(1, '#0c0a10');
    ctx.fillStyle = g2; ctx.fillRect(0, by - 2, W, H - by + 2);
  }
  if (img?.complete && img.naturalWidth) ctx.drawImage(img, sx, sy, 400 * k, 256 * k);
  const lit = 1 - dark;
  if (lit > 0.01) {
    ctx.globalCompositeOperation = 'lighter';
    CANDLES.forEach(([ax, ay], i) => {
      const x = sx + ax * 400 * k, y = sy + ay * 256 * k;
      const r = (34 + 6 * (reduced() ? 0.5 : noise(t, i * 5))) * k;
      const g = ctx.createRadialGradient(x, y, 0, x, y, r);
      g.addColorStop(0, `rgba(255,170,80,${0.22 * lit})`); g.addColorStop(1, 'rgba(255,140,60,0)');
      ctx.fillStyle = g; ctx.fillRect(x - r, y - r, r * 2, r * 2);
    });
    ctx.globalCompositeOperation = 'source-over';
    ctx.fillStyle = `rgba(255,178,87,${(0.03 + 0.028 * (reduced() ? 0.5 : noise(t * 0.8, 7.3))) * lit})`;
    ctx.fillRect(0, 0, W, H);
    if (!reduced()) {
      const dt = Math.min(0.05, (now - last) / 1000 || 0.016);
      if (Math.random() < 0.06) { const c = Math.floor(Math.random() * 2); embers.push({ x: CANDLES[c][0] * 400 + (Math.random() - 0.5) * 3, y: CANDLES[c][1] * 256 - 8, vy: 8 + Math.random() * 10, life: 1.4 + Math.random(), t: 0, c }); }
      for (let i = embers.length - 1; i >= 0; i--) {
        const e = embers[i]; e.t += dt; e.y -= e.vy * dt; e.x += Math.sin(e.t * 3 + e.c) * 0.08;
        if (e.t > e.life) { embers.splice(i, 1); continue; }
        ctx.fillStyle = `rgba(255,${150 + Math.floor(80 * (1 - e.t / e.life))},70,${(1 - e.t / e.life) * lit})`;
        ctx.fillRect(Math.round(sx + e.x * k), Math.round(sy + e.y * k), k, k);
      }
    }
  }
  const v = ctx.createRadialGradient(W / 2, H * 0.48, Math.min(W, H) * 0.25, W / 2, H * 0.5, Math.max(W, H) * 0.75);
  v.addColorStop(0, 'rgba(0,0,0,0)'); v.addColorStop(1, 'rgba(0,0,0,0.62)');
  ctx.fillStyle = v; ctx.fillRect(0, 0, W, H);
  if (dark > 0.001) { ctx.fillStyle = `rgba(4,3,6,${0.92 * dark})`; ctx.fillRect(0, 0, W, H); }
  last = now;
  void force;
}

let raf = 0, lastFrame = 0;
function loop(now: number) {
  raf = requestAnimationFrame(loop);
  if (now - lastFrame < 50 && Math.abs(dark - darkTarget) < 0.001) return; // ~20 fps basta para a vela
  dark += (darkTarget - dark) * 0.08; if (Math.abs(dark - darkTarget) < 0.002) dark = darkTarget;
  lastFrame = now; draw(now);
}
function start() {
  cancelAnimationFrame(raf);
  if (reduced() || document.hidden) { dark = darkTarget; draw(performance.now(), true); return; }
  raf = requestAnimationFrame(loop);
}

function loadScene() {
  if (!cv) return;
  let n = 0;
  for (const f of ['menu', 'menu_normal', 'menu_1', 'menu_2']) {
    const im = new Image(); im.src = `/img/v3/${f}.png`; imgs[f] = im;
    im.onload = () => {
      if (f === 'menu') {
        const c = document.createElement('canvas'); c.width = 400; c.height = 4; const x = c.getContext('2d')!;
        x.drawImage(im, 0, 0); const d = x.getImageData(0, 0, 400, 4).data; let r = 0, g = 0, b = 0;
        for (let i = 0; i < d.length; i += 4) { r += d[i]; g += d[i + 1]; b += d[i + 2]; }
        const m = d.length / 4; topColor = `rgb(${Math.round(r / m)},${Math.round(g / m)},${Math.round(b / m)})`;
        x.clearRect(0, 0, 400, 4); x.drawImage(im, 0, -252); const e = x.getImageData(0, 0, 400, 4).data; r = g = b = 0;
        for (let i = 0; i < e.length; i += 4) { r += e[i]; g += e[i + 1]; b += e[i + 2]; }
        bottomColor = `rgb(${Math.round(r / m)},${Math.round(g / m)},${Math.round(b / m)})`;
        layout();
      }
      if (++n === 4) start();
    };
  }
  addEventListener('resize', layout);
  document.addEventListener('visibilitychange', start);
  layout();
}

// ---------------- menu, painéis, sair ----------------
const panels = $$<HTMLElement>('.panel');
let lastOpener: HTMLElement | null = null;
function openPanel(id: string, opener?: HTMLElement | null) {
  if (id === 'quit') { quit(true); return; }
  const p = document.getElementById(id);
  if (!p || !p.classList.contains('panel')) return;
  panels.forEach((x) => x.classList.toggle('open', x === p));
  document.body.classList.add('panel-open');
  lastOpener = opener || null;
  const h = $('h2', p) as HTMLElement | null; const fr = $('.frame9', p) as HTMLElement | null;
  if (fr) fr.scrollTop = 0;
  if (h) { h.tabIndex = -1; h.focus({ preventScroll: true }); }
  sfx('menu-open');
}
function closePanel() {
  if (!panels.some((p) => p.classList.contains('open'))) return;
  panels.forEach((p) => p.classList.remove('open'));
  document.body.classList.remove('panel-open');
  $$<HTMLVideoElement>('.panel video').forEach((v) => v.pause());
  lastOpener?.focus();
  sfx('menu-close');
}
function quit(on: boolean) {
  darkTarget = on ? 1 : 0;
  document.body.classList.toggle('quitting', on);
  const q = $('#quit');
  if (on) { q?.classList.add('show'); setTimeout(() => ($('.seal-btn') as HTMLElement | null)?.focus(), 400); sfx('menu-close'); }
  else { q?.classList.remove('show'); ($('.mbtn[data-open="quit"]') as HTMLElement | null)?.focus(); sfx('menu-open'); }
  if (reduced()) { dark = darkTarget; draw(performance.now(), true); }
}
function menu() {
  const items = $$<HTMLAnchorElement>('.menu .mbtn');
  const select = (a: HTMLElement) => { items.forEach((x) => x.toggleAttribute('data-sel', x === a)); };
  items.forEach((a) => {
    a.addEventListener('mouseenter', () => { if (!a.hasAttribute('data-sel')) sfx('menu-hover'); select(a); });
    a.addEventListener('focus', () => select(a));
    a.addEventListener('click', (e) => { e.preventDefault(); sfx('button-click'); openPanel(a.dataset.open!, a); });
  });
  addEventListener('keydown', (e) => {
    if (e.key === 'Escape') { if (document.body.classList.contains('quitting')) quit(false); else closePanel(); return; }
    if (document.body.classList.contains('panel-open') || document.body.classList.contains('quitting')) return;
    const i = items.findIndex((x) => x.hasAttribute('data-sel'));
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault();
      const n = items[(i + (e.key === 'ArrowDown' ? 1 : -1) + items.length) % items.length];
      select(n); n.focus(); sfx('menu-hover');
    }
  });
  $$('[data-close]').forEach((b) => b.addEventListener('click', (e) => { e.preventDefault(); closePanel(); }));
  panels.forEach((p) => p.addEventListener('click', (e) => { if (e.target === p) closePanel(); }));
  // foco preso no painel aberto
  addEventListener('keydown', (e) => {
    if (e.key !== 'Tab') return;
    const p = panels.find((x) => x.classList.contains('open'));
    if (!p) return;
    const f = $$<HTMLElement>('a[href], button, input:not([tabindex="-1"]), video', p).filter((x) => x.offsetParent !== null);
    if (!f.length) return;
    const first = f[0], lastEl = f[f.length - 1];
    if (e.shiftKey && document.activeElement === first) { e.preventDefault(); lastEl.focus(); }
    else if (!e.shiftKey && document.activeElement === lastEl) { e.preventDefault(); first.focus(); }
  });
  $('.seal-btn')?.addEventListener('click', () => { if (document.body.classList.contains('nf')) location.href = ($('.nfback') as HTMLAnchorElement)?.href || '/'; else quit(false); });
  if (location.hash && location.hash.length > 1) openPanel(location.hash.slice(1));
}

// ---------------- as duas cartas que flutuam e viram ----------------
function hangingCards() {
  const pool = D.pool || [];
  let lastId = '';
  $$<HTMLButtonElement>('.hang').forEach((b) => b.addEventListener('click', () => {
    const on = b.getAttribute('aria-pressed') !== 'true';
    if (on && pool.length) {
      let id = pool[Math.floor(Math.random() * pool.length)];
      if (id === lastId && pool.length > 1) id = pool[(pool.indexOf(id) + 1) % pool.length];
      lastId = id;
      ($('.f', b) as HTMLImageElement).src = `${D.cardBase}${id}.png`;
    }
    b.setAttribute('aria-pressed', String(on)); sfx('card-discovered');
  }));
}

// ---------------- opções ----------------
function settings() {
  const sw = (id: string, fn: (on: boolean) => void) => {
    const b = document.getElementById(id);
    b?.addEventListener('click', () => { const on = b.getAttribute('aria-checked') !== 'true'; b.setAttribute('aria-checked', String(on)); fn(on); sfx('button-click'); });
  };
  sw('opt-music', setMusic);
  sw('opt-sfx', (on) => { S.sfx = on; });
  sw('opt-crt', (on) => document.body.classList.toggle('crt', on));
  const m = document.getElementById('opt-motion');
  if (m && osReduced.matches) m.setAttribute('aria-checked', 'true');
  sw('opt-motion', (on) => { document.body.classList.toggle('reduced', on); start(); });
}

// ---------------- conquista: o "Me avise" ----------------
function notify() {
  const f = $<HTMLFormElement>('form.notify');
  if (!f) return;
  const msg = $('.msg', f)!, btn = $<HTMLButtonElement>('button[type=submit]', f)!;
  f.addEventListener('submit', async (e) => {
    e.preventDefault();
    const fd = new FormData(f);
    const email = String(fd.get('email') || '').trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) { msg.className = 'msg err'; msg.textContent = D.t.notifyBad; $('input[type=email]', f)?.focus(); return; }
    msg.className = 'msg'; msg.textContent = D.t.sending; btn.disabled = true;
    try {
      const r = await fetch('/api/notify', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, lang: D.lang, website: fd.get('website'), variant: 'v3', source: 'hero' }) });
      const j = await r.json().catch(() => ({}));
      if (r.ok && j.ok) {
        msg.textContent = D.t.notifyOk + ' ';
        if (j.token) { const a = document.createElement('a'); a.href = `${D.unsubPath}?t=${encodeURIComponent(j.token)}`; a.textContent = D.t.unsubLink; msg.append(a); }
        f.reset();
        const icon = $<HTMLImageElement>('#ach-icon'); if (icon) icon.src = icon.dataset.on!;
        const toast = $('#toast');
        if (toast) { toast.hidden = false; toast.classList.remove('in'); void toast.offsetWidth; toast.classList.add('in'); setTimeout(() => { toast.classList.remove('in'); setTimeout(() => (toast.hidden = true), 600); }, 4800); }
        sfx('card-discovered');
      } else { msg.classList.add('err'); msg.textContent = r.status === 429 ? D.t.notifyRate : D.t.notifyBad; }
    } catch { msg.classList.add('err'); msg.textContent = D.t.notifyNet; }
    btn.disabled = false;
  });
}

function trailer() {
  const b = $<HTMLButtonElement>('.vplay');
  b?.addEventListener('click', () => {
    const v = document.createElement('video');
    v.src = b.dataset.src!; v.controls = true; v.autoplay = true; v.playsInline = true;
    v.setAttribute('aria-label', b.getAttribute('aria-label') || '');
    b.closest('.tv')!.replaceChildren(v); v.focus();
    if (S.a) S.a.pause();
  });
}

function clock() {
  const el = $('#clock');
  if (!el) return;
  const tick = () => { const d = new Date(); el.textContent = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; };
  tick(); setInterval(tick, 20000);
}

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

loadScene(); menu(); hangingCards(); settings(); notify(); trailer(); clock(); unsubscribe();
if ($('.title')) addEventListener('load', () => setTimeout(() => {
  if (navigator.sendBeacon) navigator.sendBeacon('/api/view', new Blob([JSON.stringify({ variant: 'v3', lang: D.lang })], { type: 'application/json' }));
}, 500), { once: true });
