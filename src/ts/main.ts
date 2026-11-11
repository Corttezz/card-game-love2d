// runemoire.com v3: a tela de título do jogo no navegador.
// A capela é desenhada como no jogo (components/Menu.lua): os 4 quadros da cena alternam a 10 fps (a chama das velas),
// brilho das velas, brasas, tremor quente e vinheta, em escala inteira nos pixels do aparelho.
// Nada é guardado no aparelho; som só com o visitante ligando.
type Data = { lang: string; unsubPath?: string; pool?: string[]; cardBase?: string; sceneTop?: string; sceneBottom?: string; t: Record<string, string> };
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
// cores da borda de cima e de baixo da cena, medidas no build (tools/build.mjs) no PNG do jogo: sem ler pixels no navegador
let k = 1, sx = 0, sy = 0, W = 0, H = 0, topColor = D.sceneTop || '#141018', bottomColor = D.sceneBottom || '#141018';
let dark = document.body.classList.contains('dark') ? 1 : 0, darkTarget = dark;
type Ember = { x: number; y: number; vy: number; life: number; t: number; c: number };
const embers: Ember[] = [];
const CANDLES: [number, number][] = [[0.209, 0.44], [0.770, 0.44]];

// O canvas tem o tamanho da cena em pixels DO JOGO (cw x ch) e o navegador o amplia k vezes, sem suavizar:
// mesma pixel art, k² menos trabalho por quadro do que desenhar na resolução do aparelho.
let cw = 0, ch = 0, ox = 0, oy = 0;
const tv = $('#tv');
// tamanho da tela em px de CSS (a tela pode estar dentro do monitor, em tamanho virtual, ou em tela cheia)
const tvSize = () => ({ w: tv?.clientWidth || innerWidth, h: tv?.clientHeight || innerHeight });
function layout() {
  if (!cv || !ctx) return;
  const dpr = Math.min(window.devicePixelRatio || 1, 3);
  const { w: TW, h: TH } = tvSize();
  W = Math.round(TW * dpr); H = Math.round(TH * dpr);
  const portrait = TW / TH < 0.8;
  // retrato: ~234 px da cena na largura: as duas velas ficam cortadas nas bordas (velas em x 84 e 308 da cena)
  k = portrait ? Math.max(1, Math.floor(W / 234)) : Math.max(1, Math.ceil(Math.max(W / 400, H / 256)));
  cw = Math.ceil(W / k); ch = Math.ceil(H / k);
  cv.width = cw; cv.height = ch;
  cv.style.width = `${(cw * k) / dpr}px`; cv.style.height = `${(ch * k) / dpr}px`;
  ctx.imageSmoothingEnabled = false;
  ox = Math.round((cw - 400) / 2);
  // retrato: a capela apoiada embaixo (sobra uma faixa para a linha da Steam); paisagem: centrada
  oy = portrait ? Math.round(ch - 256 - (44 * dpr) / k) : Math.round((ch - 256) / 2);
  sx = ox * k; sy = oy * k;
  const st = tv?.style || root.style;
  const menuTop = (sy + 22 * k) / dpr;
  st.setProperty('--menu-top-p', `${menuTop}px`);
  placeCards(portrait, TW, TH, menuTop);
  draw(performance.now());
}

// as cartas flutuantes nunca cruzam o menu: no retrato ficam centradas na faixa livre entre o logotipo e o menu,
// num tamanho inteiro (verso 96 ou 64 px); sem espaço, somem. Na paisagem, 192 ou 144 px a 30% da altura (como no jogo).
function placeCards(portrait: boolean, TW: number, TH: number, menuTop: number) {
  const st = tv?.style; if (!st) return;
  const cards = $$<HTMLElement>('.hang');
  if (!cards.length) return;
  let w = 0, top = 0;
  if (portrait) {
    const brand = $('.brand');
    const bottom = brand ? brand.offsetTop + brand.offsetHeight : 160;
    const band = menuTop - bottom - 20;
    w = band >= 156 ? 96 : band >= 108 ? 64 : 0;
    top = bottom + 10 + Math.max(0, (band - w * 1.5) / 2);
  } else if (TH <= 520) {
    w = 64; top = TH * 0.22;
  } else {
    w = TW >= 1100 && TH >= 760 ? 192 : 144;
    top = TH * 0.30 - w * 0.75;
  }
  cards.forEach((c) => (c.hidden = w === 0));
  st.setProperty('--card-w', `${w}px`);
  st.setProperty('--card-top', `${Math.round(top)}px`);
}

function noise(t: number, s: number) { return (Math.sin(t * 1.9 + s) * 0.5 + Math.sin(t * 3.7 + s * 2.1) * 0.3 + Math.sin(t * 7.3 + s * 0.7) * 0.2) * 0.5 + 0.5; }

let last = 0, vign: CanvasGradient | null = null, vignKey = '';
function draw(now: number) {
  if (!ctx) return;
  const t = now / 1000;
  const frame = reduced() ? 'menu' : SEQ[Math.floor(t * 10) % SEQ.length];
  const img = imgs[frame] || imgs.menu;
  ctx.fillStyle = topColor; ctx.fillRect(0, 0, cw, ch);
  if (oy > 0) {
    // acima da capela (retrato): a parede do topo da cena sumindo no escuro
    const g = ctx.createLinearGradient(0, 0, 0, oy + 1);
    g.addColorStop(0, '#0c0a10'); g.addColorStop(1, topColor);
    ctx.fillStyle = g; ctx.fillRect(0, 0, cw, oy + 1);
  }
  const by = oy + 256;
  if (by < ch) {
    // abaixo do altar (retrato): a pedra da frente do altar sumindo no escuro
    const g2 = ctx.createLinearGradient(0, by - 1, 0, ch);
    g2.addColorStop(0, bottomColor); g2.addColorStop(1, '#0c0a10');
    ctx.fillStyle = g2; ctx.fillRect(0, by - 1, cw, ch - by + 1);
  }
  if (img?.complete && img.naturalWidth) ctx.drawImage(img, ox, oy);
  if (oy > 0) {
    // retrato: o alto da capela some no escuro (sem emenda dura)
    const f = ctx.createLinearGradient(0, oy, 0, oy + 24);
    f.addColorStop(0, topColor); f.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = f; ctx.fillRect(0, oy, cw, 24);
  }
  const lit = 1 - dark;
  if (lit > 0.01) {
    // o feixe de luz da janela alta da capela (Menu:_drawLightShaft)
    const cx = ox + 200, g = ctx.createLinearGradient(0, oy, 0, oy + 200);
    g.addColorStop(0, `rgba(255,214,150,${0.10 * lit})`); g.addColorStop(1, 'rgba(255,214,150,0)');
    ctx.globalCompositeOperation = 'lighter'; ctx.fillStyle = g;
    ctx.beginPath(); ctx.moveTo(cx - 14, oy); ctx.lineTo(cx + 14, oy); ctx.lineTo(cx + 46, oy + 200); ctx.lineTo(cx - 46, oy + 200); ctx.closePath(); ctx.fill();
    ctx.globalCompositeOperation = 'source-over';
  }
  if (dark > 0.01) {
    // velas apagadas: as chamas somem antes do resto escurecer
    ctx.fillStyle = `rgba(6,4,8,${Math.min(1, dark * 1.8)})`;
    CANDLES.forEach(([ax, ay]) => ctx.fillRect(Math.round(ox + ax * 400 - 7), Math.round(oy + ay * 256 - 22), 14, 22));
  }
  if (lit > 0.01) {
    ctx.globalCompositeOperation = 'lighter';
    CANDLES.forEach(([ax, ay], i) => {
      const x = ox + ax * 400, y = oy + ay * 256;
      const r = 34 + 6 * (reduced() ? 0.5 : noise(t, i * 5));
      const g = ctx.createRadialGradient(x, y, 0, x, y, r);
      g.addColorStop(0, `rgba(255,170,80,${0.22 * lit})`); g.addColorStop(1, 'rgba(255,140,60,0)');
      ctx.fillStyle = g; ctx.fillRect(x - r, y - r, r * 2, r * 2);
    });
    ctx.globalCompositeOperation = 'source-over';
    ctx.fillStyle = `rgba(255,178,87,${(0.03 + 0.028 * (reduced() ? 0.5 : noise(t * 0.8, 7.3))) * lit})`;
    ctx.fillRect(0, 0, cw, ch);
    if (!reduced()) {
      const dt = Math.min(0.12, (now - last) / 1000 || 0.1);
      if (Math.random() < 0.12) { const c = Math.floor(Math.random() * 2); embers.push({ x: CANDLES[c][0] * 400 + (Math.random() - 0.5) * 3, y: CANDLES[c][1] * 256 - 8, vy: 8 + Math.random() * 10, life: 1.4 + Math.random(), t: 0, c }); }
      for (let i = embers.length - 1; i >= 0; i--) {
        const e = embers[i]; e.t += dt; e.y -= e.vy * dt; e.x += Math.sin(e.t * 3 + e.c) * 0.15;
        if (e.t > e.life) { embers.splice(i, 1); continue; }
        ctx.fillStyle = `rgba(255,${150 + Math.floor(80 * (1 - e.t / e.life))},70,${(1 - e.t / e.life) * lit})`;
        ctx.fillRect(Math.round(ox + e.x), Math.round(oy + e.y), 1, 1);
      }
    }
  }
  const key = `${cw}x${ch}`;
  if (!vign || vignKey !== key) {
    vign = ctx.createRadialGradient(cw / 2, ch * 0.48, Math.min(cw, ch) * 0.25, cw / 2, ch * 0.5, Math.max(cw, ch) * 0.75);
    vign.addColorStop(0, 'rgba(0,0,0,0)'); vign.addColorStop(1, 'rgba(0,0,0,0.62)'); vignKey = key;
  }
  ctx.fillStyle = vign; ctx.fillRect(0, 0, cw, ch);
  if (dark > 0.001) { ctx.fillStyle = `rgba(4,3,6,${0.92 * dark})`; ctx.fillRect(0, 0, cw, ch); }
  last = now;
}

let raf = 0, lastFrame = 0;
function loop(now: number) {
  raf = requestAnimationFrame(loop);
  if (now - lastFrame < 100 && Math.abs(dark - darkTarget) < 0.001) return; // 10 fps: o ritmo da chama no jogo (BG_FPS = 10)
  dark += (darkTarget - dark) * 0.08; if (Math.abs(dark - darkTarget) < 0.002) dark = darkTarget;
  lastFrame = now; draw(now);
}
function start() {
  cancelAnimationFrame(raf);
  if (reduced() || document.hidden) { dark = darkTarget; draw(performance.now()); return; }
  raf = requestAnimationFrame(loop);
}

function loadScene() {
  if (!cv) return;
  let n = 0;
  for (const f of ['menu', 'menu_normal', 'menu_1', 'menu_2']) {
    const im = new Image(); im.src = `/img/v3/${f}.webp`; imgs[f] = im;
    im.onload = () => {
      if (f === 'menu') layout();
      if (++n === 4) { if (document.readyState === 'complete') start(); else addEventListener('load', start, { once: true }); }
    };
  }
  addEventListener('resize', layout);
  if (tv && 'ResizeObserver' in window) new ResizeObserver(() => layout()).observe(tv);
  document.addEventListener('visibilitychange', start);
  layout();
}

// ---------------- menu, painéis, sair ----------------
const panels = $$<HTMLElement>('.panel');
// fundo inerte quando um painel ou o Sair está aberto: o teclado não alcança o que não se vê
const BG = () => $$<HTMLElement>('#main, .hang, .corner, .osd');
const setInert = (els: HTMLElement[], on: boolean) => els.forEach((e) => { if (on) e.setAttribute('inert', ''); else e.removeAttribute('inert'); });
setInert($$('#quit:not([data-static])'), true);
let lastOpener: HTMLElement | null = null;
function openPanel(id: string, opener?: HTMLElement | null) {
  if (id === 'quit') { quit(true); return; }
  const p = document.getElementById(id);
  if (!p || !p.classList.contains('panel')) return;
  panels.forEach((x) => x.classList.toggle('open', x === p));
  document.body.classList.add('panel-open');
  setInert(BG(), true);
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
  setInert(BG(), false);
  $$<HTMLVideoElement>('.panel video').forEach((v) => v.pause());
  lastOpener?.focus();
  sfx('menu-close');
}
// ---------------- o computador da abertura do jogo: mesa, ligar, mergulhar, desligar ----------------
// arte do jogo: assets/sprites/intro/computer.png (640x773), tela em x 106, y 140, 427x343 (src/data/intro_computer.lua)
const PC = { w: 640, h: 773, sx: 106, sy: 140, sw: 427, sh: 343 };
const VW = 1120, VH = 900; // tamanho virtual da tela dentro do monitor (mesma proporção da tela do computador)
const pcEl = $('#computer'), hint = $('#hint'), hit = $<HTMLButtonElement>('#screenhit');
let mode: 'desk' | 'dive' | 'full' = 'full';
let screenRect = { x: 0, y: 0, w: 0, h: 0 };
const setMode = (m: typeof mode) => { mode = m; root.classList.remove('mode-desk', 'mode-dive', 'mode-full'); root.classList.add('mode-' + m); };
function deskGeometry() {
  if (!pcEl) return;
  const vw = innerWidth, vh = innerHeight;
  const c = Math.min((vh * 0.86) / PC.h, (vw * 0.94) / PC.w);
  const w = PC.w * c, h = PC.h * c, x = (vw - w) / 2, y = Math.max(8, (vh - h) / 2 - 14);
  const st = root.style;
  st.setProperty('--pc-x', `${x}px`); st.setProperty('--pc-y', `${y}px`); st.setProperty('--pc-w', `${w}px`); st.setProperty('--pc-h', `${h}px`);
  st.setProperty('--pc-ox', `${((PC.sx + PC.sw / 2) / PC.w) * 100}%`); st.setProperty('--pc-oy', `${((PC.sy + PC.sh / 2) / PC.h) * 100}%`);
  st.setProperty('--glow-y', `${((y + (PC.sy + PC.sh / 2) * c) / vh) * 100}%`);
  st.setProperty('--hint-y', `${vh - (y + h) > 40 ? y + h + 10 : y + h * 0.71}px`);
  // a tela do jogo, em tamanho virtual, encaixada no buraco da tela do computador (a moldura cobre 2 px de borda)
  screenRect = { x: x + (PC.sx - 2) * c, y: y + (PC.sy - 2) * c, w: (PC.sw + 4) * c, h: (PC.sh + 4) * c };
  if (mode === 'desk' && tv) {
    tv.style.width = `${VW}px`; tv.style.height = `${VH}px`;
    tv.style.transform = `translate(${screenRect.x}px, ${screenRect.y}px) scale(${screenRect.w / VW}, ${screenRect.h / VH})`;
  }
}
function toDesk(off: boolean) {
  setMode('desk');
  if (tv) { tv.classList.toggle('off', off); tv.classList.remove('dive', 'off-anim'); setInert([tv], true); }
  if (pcEl) { pcEl.style.transform = ''; pcEl.style.opacity = ''; }
  if (hint) hint.textContent = (off ? hint.dataset.off : hint.dataset.on) || '';
  if (hit) hit.setAttribute('aria-label', (off ? hint?.dataset.off : hint?.dataset.on) || '');
  deskGeometry(); layout();
}
function powerOn() {
  if (!tv) return;
  tv.classList.remove('off'); tv.classList.remove('on-anim'); void tv.offsetWidth; tv.classList.add('on-anim');
  sfx('boot-tv-power-on');
  if (hint) hint.textContent = hint.dataset.on || '';
  if (hit) hit.setAttribute('aria-label', hint?.dataset.on || '');
  setTimeout(() => tv.classList.remove('on-anim'), 950);
}
// mergulho: a tela sai do monitor e ocupa a janela, como a câmera entrando no tubo na abertura do jogo (IntroTube)
function dive() {
  if (!tv || mode !== 'desk') return;
  if (tv.classList.contains('off')) { powerOn(); return; }
  const r = screenRect;
  setMode('dive');
  tv.style.width = ''; tv.style.height = '';
  tv.style.transform = `translate(${r.x}px, ${r.y}px) scale(${r.w / innerWidth}, ${r.h / innerHeight})`;
  layout();
  void tv.offsetWidth;
  tv.classList.add('dive');
  tv.style.transform = 'none';
  if (pcEl) { pcEl.style.transform = `scale(${(innerWidth / r.w) * 1.6})`; pcEl.style.opacity = '0'; }
  sfx('boot-card-whoosh');
  const done = () => {
    tv.classList.remove('dive'); tv.style.transform = '';
    setMode('full'); setInert([tv], false);
    ($('.menu .mbtn[data-sel]') as HTMLElement | null)?.focus({ preventScroll: true });
  };
  if (reduced()) done(); else setTimeout(done, 920);
}
// sair: a TV desliga como no jogo (CRTShader.powerOff: a imagem vira uma linha e some) e volta para a mesa, com a tela apagada
function quit(on: boolean) {
  if (document.body.classList.contains('nf') || !tv) {
    darkTarget = on ? 1 : 0; if (reduced()) { dark = darkTarget; draw(performance.now()); }
    return;
  }
  if (!on) return;
  closePanel();
  sfx('menu-close');
  tv.classList.add('off-anim');
  setTimeout(() => { toDesk(true); hit?.focus({ preventScroll: true }); }, reduced() ? 0 : 560);
}
function desk() {
  if (!tv || !pcEl) { setMode('full'); return; }
  addEventListener('resize', () => { deskGeometry(); if (mode === 'desk') layout(); });
  hit?.addEventListener('click', () => { sfx('button-click'); dive(); });
  // link direto para um painel (#play, #collection...) entra direto na tela cheia
  if (location.hash && location.hash.length > 1) { setMode('full'); return; }
  toDesk(true);
  setTimeout(powerOn, reduced() ? 0 : 450);
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
    if (e.key === 'Escape') { closePanel(); return; }
    if (mode !== 'full') return;
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
    b.closest('.vid')!.replaceChildren(v); v.focus();
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

desk(); loadScene(); menu(); hangingCards(); settings(); notify(); trailer(); clock(); unsubscribe();
if ($('.title')) addEventListener('load', () => setTimeout(() => {
  if (navigator.sendBeacon) navigator.sendBeacon('/api/view', new Blob([JSON.stringify({ variant: 'v3', lang: D.lang })], { type: 'application/json' }));
}, 500), { once: true });
