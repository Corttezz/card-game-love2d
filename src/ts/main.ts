// runemoire.com v3b: a abertura do jogo, igual à do jogo (src/ts/game.ts porta IntroTube, BootScene, MenuBrand, Menu e o crt.glsl).
// O computador começa desligado; clicar na tela (ou qualquer tecla) insere a carta e liga tudo. Segundo clique/tecla pula, como no jogo.
// Por cima do canvas ficam só alvos transparentes e acessíveis (menu, cartas, rodapé) e os painéis. Nada é guardado no aparelho.
import { Game, BUTTON_ORDER, type Strings } from './game';

type Data = { lang: string; nf?: boolean; unsubPath?: string; pool?: string[]; cardBase?: string; boot: Strings; t: Record<string, string> };
const $ = <T extends Element = HTMLElement>(s: string, r: ParentNode = document) => r.querySelector(s) as T | null;
const $$ = <T extends Element = HTMLElement>(s: string, r: ParentNode = document) => Array.from(r.querySelectorAll(s)) as T[];
const D: Data = JSON.parse($('#rm-data')?.textContent || '{"t":{},"boot":{}}');
const root = document.documentElement;
root.classList.remove('no-js'); root.classList.add('js');
const osReduced = matchMedia('(prefers-reduced-motion: reduce)');

// ---------------- som: efeitos do jogo ligados (o clique libera o áudio); música só nas Opções ----------------
const SND = { music: false, sfx: true, a: null as HTMLAudioElement | null, menuOn: false };
function sfx(n: string, vol = 1, rate = 1) {
  if (!SND.sfx) return;
  const a = new Audio(`/media/v3b/${n}.mp3`); a.volume = Math.min(1, 0.6 * vol); a.playbackRate = rate; (a as any).preservesPitch = false;
  a.play().catch(() => {});
}
function music(on: boolean) {
  SND.menuOn = on;
  if (on && SND.music) { if (!SND.a) { SND.a = new Audio('/media/v3/menu.mp3'); SND.a.loop = true; SND.a.volume = 0.35; } SND.a.play().catch(() => {}); }
  else SND.a?.pause();
}

// ---------------- o jogo ----------------
// páginas simples (privacidade, sair da lista) não têm a cena: o jogo nem começa
const HAS = !!$('#cv');
const cv = $<HTMLCanvasElement>('#cv') || document.createElement('canvas'), out = $<HTMLCanvasElement>('#crt') || document.createElement('canvas');
const main = $('#title'), hit = $<HTMLButtonElement>('#screenhit');
const game = new Game(cv, out, D.boot, {
  sfx, music,
  onPhase: (p) => {
    ((window as any).__rmPhases ||= []).push(p);
    if (p === 'insert') root.classList.add('started');
    if (p === 'boot' && game.glOk) root.classList.add('on-crt');
  },
  onMenu: () => { ((window as any).__rmPhases ||= []).push('menu'); root.classList.add('started'); if (game.glOk) root.classList.add('on-crt'); },
  onDesk: () => { root.classList.remove('on-crt', 'started', 'in-menu'); main?.setAttribute('inert', ''); hit?.focus({ preventScroll: true }); },
});
game.reduced = osReduced.matches;
(window as any).__rm = game; // para os testes (tools/e2e.mjs) e as capturas lado a lado
// ?manual: o relógio não anda sozinho; as capturas avançam o jogo em passos de 1/60 s (como a ferramenta do jogo)
const MANUAL = new URLSearchParams(location.search).has('manual');

function resize() { game.resize(innerWidth, innerHeight); wake(); }
resize();
addEventListener('resize', resize);
addEventListener('pointermove', (e) => { game.mouse = [e.clientX, e.clientY]; }, { passive: true });
game.mouse = [innerWidth / 2, innerHeight / 2];

// o loop dorme enquanto o computador desligado está parado (o jogo já não redesenha nesse estado) e acorda no clique,
// tecla, mudança de tamanho, volta da aba ou fim da carga dos shaders
let raf = 0, sleeping = false;
function loop(now: number) {
  if (MANUAL) game.draw(); else game.frame(now);
  syncDom();
  if (!MANUAL && game.stillKey) { sleeping = true; return; }
  raf = requestAnimationFrame(loop);
}
function start() { sleeping = false; cancelAnimationFrame(raf); raf = requestAnimationFrame(loop); }
function wake() { if (sleeping && !document.hidden) { game.last = 0; start(); } }
// aba oculta: o loop para (sem trabalho de fundo); volta ao aparecer
document.addEventListener('visibilitychange', () => { if (document.hidden) cancelAnimationFrame(raf); else if (HAS && raf) { game.last = 0; start(); } });

// ---------------- carga: o computador primeiro; shaders e o resto depois da carga (fora do caminho da primeira pintura) ----------------
let restP: Promise<void> | null = null;
function loadRest() {
  if (!restP) restP = game.loadRest().then(() => { game.initGL(); game.initGLRest(); wake(); });
  return restP;
}
if (HAS) game.loadIntro().then(() => { start(); });
if (HAS) addEventListener('load', () => {
  const go = () => { game.initGL(); loadRest(); };
  // a página parada não precisa de shader: o resto carrega depois, sem disputar a primeira pintura (o clique antecipa)
  setTimeout(() => { if ('requestIdleCallback' in window) (window as any).requestIdleCallback(go, { timeout: 2000 }); else go(); }, 3000);
}, { once: true });

(window as any).__rmReady = () => loadRest();
(window as any).__rmPress = () => press();
async function press() {
  if (D.nf || !HAS) return;
  wake();
  if (game.mode === 'intro' && game.intro.phase === 'off') {
    game.initGL();
    if (game.reduced) { await loadRest(); game.skipAll(); return; }
    loadRest();
  }
  game.press();
}
hit?.addEventListener('click', () => { press(); });
addEventListener('keydown', (e) => {
  if (!HAS || e.altKey || e.ctrlKey || e.metaKey || e.key === 'Tab') return;
  if (document.body.classList.contains('panel-open')) return;
  // lendo o texto de baixo da cena: as teclas rolam a página normalmente
  if (scrollY >= innerHeight / 2) return;
  const intro = game.mode !== 'menu' || game.menu.isIntroPlaying();
  if (intro) { e.preventDefault(); press(); return; }
  // na tela de título o Espaço não rola para o texto (no jogo ele não faz nada); botões e campos seguem normais
  const tag = (document.activeElement as HTMLElement | null)?.tagName || '';
  if (e.key === ' ' && !['BUTTON', 'INPUT', 'SELECT', 'TEXTAREA'].includes(tag)) e.preventDefault();
});

// ---------------- alvos transparentes sobre o que o jogo desenha ----------------
const mbtns = $$<HTMLAnchorElement>('.menu .mbtn'), hangs = $$<HTMLButtonElement>('.hang'), priv = $<HTMLAnchorElement>('#priv');
let menuLive = false, lastKey = '';
function place(el: HTMLElement, x: number, y: number, w: number, h: number, min = 0) {
  // o jogo desenha no conteúdo; o CRT curva a imagem: o alvo vai para onde o retângulo aparece na tela (sem WebGL não há curva)
  const bent = game.crtOn && game.glOk;
  let [ax, ay] = bent ? game.crt.contentToScreen(x, y, game.W, game.H) : [x, y];
  let [bx, by] = bent ? game.crt.contentToScreen(x + w, y + h, game.W, game.H) : [x + w, y + h];
  if (bx - ax < min) { const c = (ax + bx) / 2; ax = c - min / 2; bx = c + min / 2; }
  if (by - ay < min) { const c = (ay + by) / 2; ay = c - min / 2; by = c + min / 2; }
  el.style.left = `${ax}px`; el.style.top = `${ay}px`; el.style.width = `${bx - ax}px`; el.style.height = `${by - ay}px`;
}
function syncDom() {
  const live = game.mode === 'menu' && !game.menu.isIntroPlaying() && game.menu.buttonsReady();
  if (live !== menuLive) {
    menuLive = live;
    root.classList.toggle('in-menu', live);
    if (live) { main?.removeAttribute('inert'); if (document.activeElement === hit) (document.activeElement as HTMLElement).blur(); }
    else main?.setAttribute('inert', '');
  }
  if (!live) return;
  const key = `${game.W}x${game.H}:${game.crtOn}:${game.glOk}`;
  if (key === lastKey) return;
  lastKey = key;
  game.menu.buttonRects().forEach((r, i) => mbtns[i] && place(mbtns[i], r.x, r.y, r.w, r.h));
  game.menu.cardRects().forEach((r, i) => hangs[i] && place(hangs[i], r.x, r.y, r.w, r.h, 48));
  const f = game.menu.footer.priv;
  if (priv && f[2]) place(priv, f[0] - 6, f[1] - 6, f[2] + 12, f[3] + 12);
}

// ---------------- menu, painéis ----------------
const panels = $$<HTMLElement>('.panel');
let lastOpener: HTMLElement | null = null;
function openPanel(id: string, opener?: HTMLElement | null) {
  if (id === 'quit') { closePanel(); game.quit(); return; }
  const p = document.getElementById(id);
  if (!p || !p.classList.contains('panel')) return;
  panels.forEach((x) => x.classList.toggle('open', x === p));
  document.body.classList.add('panel-open');
  main?.setAttribute('inert', '');
  lastOpener = opener || null;
  const h = $('h2', p) as HTMLElement | null, fr = $('.frame9', p) as HTMLElement | null;
  if (fr) fr.scrollTop = 0;
  if (h) { h.tabIndex = -1; h.focus({ preventScroll: true }); }
  sfx('button-click');
}
function closePanel() {
  if (!panels.some((p) => p.classList.contains('open'))) return;
  panels.forEach((p) => p.classList.remove('open'));
  document.body.classList.remove('panel-open');
  if (menuLive) main?.removeAttribute('inert');
  $$<HTMLVideoElement>('.panel video').forEach((v) => v.pause());
  lastOpener?.focus();
}
function menu() {
  mbtns.forEach((a, i) => {
    const name = BUTTON_ORDER[i];
    a.addEventListener('mouseenter', () => { game.menu.hover = name; });
    a.addEventListener('mouseleave', () => { if (game.menu.hover === name) game.menu.hover = ''; });
    a.addEventListener('focus', () => { game.menu.hover = name; });
    a.addEventListener('blur', () => { if (game.menu.hover === name) game.menu.hover = ''; });
    a.addEventListener('click', (e) => { e.preventDefault(); sfx('button-click'); openPanel(a.dataset.open!, a); });
  });
  addEventListener('keydown', (e) => {
    if (e.key === 'Escape') { closePanel(); return; }
    if (!menuLive || document.body.classList.contains('panel-open')) return;
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault();
      const i = Math.max(0, mbtns.indexOf(document.activeElement as HTMLAnchorElement));
      mbtns[(i + (e.key === 'ArrowDown' ? 1 : -1) + mbtns.length) % mbtns.length].focus();
    }
  });
  // o botão "Me avise" do texto depois da cena abre o mesmo painel
  $$<HTMLAnchorElement>('.about [data-open]').forEach((a) => a.addEventListener('click', (e) => { e.preventDefault(); openPanel(a.dataset.open!, a); }));
  $$('[data-close]').forEach((b) => b.addEventListener('click', (e) => { e.preventDefault(); closePanel(); }));
  panels.forEach((p) => p.addEventListener('click', (e) => { if (e.target === p) closePanel(); }));
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
  // link direto para um painel (#play, #settings...): a tela de título já aberta, sem a abertura
  const h = location.hash.slice(1);
  if (h && document.getElementById(h)?.classList.contains('panel')) {
    loadRest().then(() => { game.skipAll(); setTimeout(() => openPanel(h), 50); });
  }
}

// ---------------- as duas cartas: clicar vira e mostra uma carta real do jogo ----------------
function hangingCards() {
  const pool = D.pool || [];
  let lastId = '';
  hangs.forEach((b) => b.addEventListener('click', () => {
    const c = game.menu.cards[Number(b.dataset.i)];
    const on = c.flipTo < 0.5;
    if (on && pool.length) {
      let id = pool[Math.floor(Math.random() * pool.length)];
      if (id === lastId && pool.length > 1) id = pool[(pool.indexOf(id) + 1) % pool.length];
      lastId = id;
      const im = new Image(); im.src = `${D.cardBase}${id}.png`; im.onload = () => { c.face = im; };
    }
    c.flipTo = on ? 1 : 0;
    b.setAttribute('aria-pressed', String(on)); sfx('card-draw');
  }));
}

// ---------------- opções ----------------
function settings() {
  const sw = (id: string, fn: (on: boolean) => void) => {
    const b = document.getElementById(id);
    b?.addEventListener('click', () => { const on = b.getAttribute('aria-checked') !== 'true'; b.setAttribute('aria-checked', String(on)); fn(on); sfx('button-click'); });
  };
  sw('opt-music', (on) => { SND.music = on; music(SND.menuOn); });
  sw('opt-sfx', (on) => { SND.sfx = on; });
  sw('opt-crt', (on) => { game.crtOn = on; game.crt.enabled = on; lastKey = ''; });
  const m = document.getElementById('opt-motion');
  if (m && osReduced.matches) m.setAttribute('aria-checked', 'true');
  sw('opt-motion', (on) => { game.reduced = on; document.body.classList.toggle('reduced', on); });
}

// ---------------- conquista: o "Me avise" ----------------
// generate_lead no dataLayer (GTM): id do evento (UUID, gravado com o cadastro para o Pixel/CAPI deduplicarem), origem do
// formulário e as UTMs da primeira visita. NUNCA e-mail ou outro dado pessoal. Só no cadastro novo (o repetido não grava linha).
function uuid(): string {
  if (crypto.randomUUID) return crypto.randomUUID();
  const b = crypto.getRandomValues(new Uint8Array(16)); b[6] = (b[6] & 15) | 64; b[8] = (b[8] & 63) | 128;
  const h = [...b].map((x) => x.toString(16).padStart(2, '0')).join('');
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
}
function leadEvent(eventId: string, source: string, variant: string, utm: Record<string, string> | null) {
  const ev: Record<string, string> = { event: 'generate_lead', event_id: eventId, lead_source: source, form_variant: variant, language: D.lang };
  for (const k of ['utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term']) if (utm && typeof utm[k] === 'string') ev[k] = utm[k];
  const w = window as any;
  (w.dataLayer = w.dataLayer || []).push(ev);
}
// origem da primeira visita, guardada por public/js/clarity.js
function firstTouch(): Record<string, string> | null {
  try { const o = JSON.parse(localStorage.getItem('rm_utm') || 'null'); return o && typeof o === 'object' ? o : null; } catch { return null; }
}
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
    const eventId = uuid(), utm = firstTouch(), variant = f.dataset.variant || 'v3b', source = f.dataset.source || 'achievements';
    try {
      const r = await fetch('/api/notify', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, lang: D.lang, website: fd.get('website'), variant, source, utm, event_id: eventId }) });
      const j = await r.json().catch(() => ({}));
      if (r.ok && j.ok) {
        msg.textContent = D.t.notifyOk + ' ';
        if (j.token) leadEvent(eventId, source, variant, utm);
        if (j.token) { const a = document.createElement('a'); a.href = `${D.unsubPath}?t=${encodeURIComponent(j.token)}`; a.textContent = D.t.unsubLink; msg.append(a); }
        f.reset();
        const icon = $<HTMLImageElement>('#ach-icon'); if (icon) icon.src = icon.dataset.on!;
        const toast = $('#toast');
        if (toast) { toast.hidden = false; toast.classList.remove('in'); void toast.offsetWidth; toast.classList.add('in'); setTimeout(() => { toast.classList.remove('in'); setTimeout(() => (toast.hidden = true), 600); }, 4800); }
        if (HAS) sfx('button-click');
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
    if (SND.a) SND.a.pause();
  });
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

setTimeout(() => { menu(); hangingCards(); settings(); notify(); trailer(); unsubscribe(); }, 0);
if ($('.title')) addEventListener('load', () => setTimeout(() => {
  if (navigator.sendBeacon) navigator.sendBeacon('/api/view', new Blob([JSON.stringify({ variant: 'v3b', lang: D.lang })], { type: 'application/json' }));
}, 500), { once: true });
