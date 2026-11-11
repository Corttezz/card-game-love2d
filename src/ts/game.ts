// A abertura e a tela de título do Runemoire, portadas do código do jogo, passo a passo:
//   src/scenes/IntroTube.lua  (o computador; a carta entra no drive, o tubo liga, o nome é datilografado, o clarão e o mergulho)
//   src/scenes/BootScene.lua  (a TV liga em tela cheia, CARREGANDO, a câmara com as cartas sugadas pelo selo)
//   src/ui/MenuBrand.lua      (o selo se acende raio por raio, o clarão, o RUNEMOIRE letra por letra)
//   components/Menu.lua       (a capela, velas, feixe de luz, fumaça, cartas, botões e OSD)
//   src/ui/CRTShader.lua + shaders/crt.glsl (o CRT do jogo: moldura de TV, curvatura, linhas, liga/desliga)
// Mesmos tempos, curvas, sons, sementes e shaders. Única adaptação pedida pelo Daniel: o computador começa DESLIGADO
// e só liga depois que a carta entra (no jogo o tubo já está ligado quando a página aparece).
import { Fx, rawBitmap } from './gl';
import { LoveRng, noise, PAL, AMBER, AMBER_DIM, rgba, rgb255, smooth, backOut, easeInOutCubic, easeOut3, clamp01, font, print, tinted } from './lib';
import crtSrc from '../shaders/crt.glsl';
import glowSrc from '../shaders/boot_seal_glow.glsl';
import twinkleSrc from '../shaders/boot_star_twinkle.glsl';
import vortexSrc from '../shaders/boot_moon_vortex.glsl';
import sealSrc from '../shaders/brand_seal.glsl';
import wordSrc from '../shaders/brand_word.glsl';
import fxSrc from '../shaders/brand_fx.glsl';

const PASS = `vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px) { return Texel(tex, uv) * color; }`;
type Ctx = CanvasRenderingContext2D;
type Img = HTMLImageElement | HTMLCanvasElement | ImageBitmap;
const TAU = Math.PI * 2;

export type Strings = { title: string; subtitle: string; loading: string; skip: string; hint: string; version: string;
  buttons: Record<string, string>; privacy: string; wish: string; osd: string };
export type Hooks = { sfx: (name: string, vol?: number, rate?: number) => void; music: (on: boolean) => void;
  onMenu: () => void; onDesk: () => void; onPhase?: (p: string) => void };

// ===================================================================== CRTShader.lua
class Crt {
  strength = 0.75; enabled = true; power = 1; dir = 1;
  anim: { from: number; to: number; dur: number; t: number; cb?: () => void; ease?: string } | null = null;
  glitchAmount = 0; glitchBandY = 0.5; glitchTimer = 3; glitchActive = 0;
  degradeAmount = 0; degradeTimer = 6; degradeActive = 0; degradeDur = 1; degradePeak = 1;
  setPower(p: number, dir?: number) { this.power = clamp01(p); if (dir) this.dir = dir; }
  private animate(to: number, dur: number, cb?: () => void) {
    if (!this.enabled) { this.power = to; cb?.(); return; }
    const off = to <= 0.01; this.dir = off ? -1 : 1;
    this.anim = { from: this.power, to, dur: Math.max(0.05, dur), t: 0, cb, ease: off ? 'outquad' : undefined };
  }
  powerOn(dur = 1.2, cb?: () => void) { this.animate(1, dur, cb); }
  powerOff(dur = 0.6, cb?: () => void) { this.animate(0, dur, cb); }
  blip() { if (!this.enabled) return; this.anim = { from: 1, to: 0.86, dur: 0.09, t: 0, cb: () => { this.anim = { from: 0.86, to: 1, dur: 0.14, t: 0 }; } }; }
  update(dt: number) {
    const R = Math.random;
    if (this.enabled && this.power > 0.99) {
      if (this.glitchActive > 0) {
        this.glitchActive -= dt; this.glitchAmount = clamp01(this.glitchActive / 0.08);
        if (this.glitchActive <= 0) { this.glitchAmount = 0; this.glitchTimer = 4 + R() * 5; }
      } else { this.glitchTimer -= dt; if (this.glitchTimer <= 0) { this.glitchActive = 0.1 + R() * 0.14; this.glitchBandY = 0.15 + R() * 0.7; this.glitchAmount = 1; } }
      if (this.degradeActive > 0) {
        this.degradeActive -= dt;
        const el = this.degradeDur - this.degradeActive;
        const env = Math.min(1, el / 0.12) * Math.min(1, Math.max(0, this.degradeActive) / 0.35);
        this.degradeAmount = this.degradePeak * clamp01(env);
        if (this.degradeActive <= 0) { this.degradeAmount = 0; this.degradeTimer = 8 + R() * 12; }
      } else {
        this.degradeTimer -= dt;
        if (this.degradeTimer <= 0) {
          this.degradeDur = 0.6 + R() * 1.4; this.degradeActive = this.degradeDur; this.degradePeak = 0.55 + R() * 0.45;
          if (this.glitchActive <= 0 && R() < 0.6) { this.glitchActive = 0.1 + R() * 0.14; this.glitchBandY = 0.15 + R() * 0.7; this.glitchAmount = 1; }
        }
      }
    } else { this.glitchAmount = 0; this.degradeAmount = 0; }
    const a = this.anim; if (!a) return;
    a.t += dt;
    const k = Math.min(1, a.t / a.dur);
    const e = a.ease === 'outquad' ? 1 - (1 - k) * (1 - k) : k;
    this.power = a.from + (a.to - a.from) * e;
    if (k >= 1) { this.anim = null; a.cb?.(); }
  }
  // CRTShader.screenToContent: ponto da tela -> ponto do conteúdo (a curvatura do tubo)
  screenToContent(x: number, y: number, w: number, h: number) {
    if (!this.enabled || this.strength < 0.01) return [x, y];
    const ar = w / h, ppx = (x / w - 0.5) * ar, ppy = y / h - 0.5, bz = 16 / h;
    const hex = 0.5 * ar - bz, hey = 0.5 - bz;
    const tx = (ppx / hex) * 0.5 + 0.5, ty = (ppy / hey) * 0.5 + 0.5;
    const cx = tx - 0.5, cy = ty - 0.5, r2 = cx * cx + cy * cy;
    const g = r2 * 1.6 + r2 * r2 * 9;
    return [(tx + cx * 0.068 * this.strength * g) * w, (ty + cy * 0.089 * this.strength * g) * h];
  }
  contentToScreen(x: number, y: number, w: number, h: number) {
    let sx = x, sy = y;
    for (let i = 0; i < 8; i++) { const [cx, cy] = this.screenToContent(sx, sy, w, h); sx -= cx - x; sy -= cy - y; }
    return [sx, sy];
  }
}

// ===================================================================== dados do jogo
const PC = { w: 640, h: 773, screen: { x: 106, y: 140, w: 427, h: 343 }, slot: { x: 330, y: 652, w: 232, h: 13 } }; // src/data/intro_computer.lua
const IT = { fadeIn: 0.35, tvPop: 0.45, typeAt: 0.8, gapSub: 0.35, hold: 0.9, insert: 1.1, insertHold: 0.35, dive: 1.0, cps: 22, ART_FRAC: 0.7, BEZEL_PX: 20, POWER: 1.2 };
const BD = {
  seal: { w: 113, h: 113, cx: 56, cy: 56, trevScale: 1.25 },
  tips: [[56, 0], [86.5, 25.5], [112, 56], [88, 88], [56, 112], [25.5, 86.5], [0, 56], [26, 26]],
  word: { w: 289, h: 48 }, cuts: [0, 32, 64, 96, 128, 160, 194, 224, 256, 289], gap: 7,
  palLit: [[0, 0, 0], [22, 10, 18], [62, 20, 18], [122, 74, 26], [172, 118, 42], [212, 160, 68], [240, 198, 108]],
  palUnlit: [[0, 0, 0], [14, 8, 14], [30, 12, 16], [48, 30, 22], [60, 38, 26], [74, 48, 30], [88, 58, 34]],
  palWarm: [[0, 0, 0], [70, 30, 22], [120, 50, 28], [196, 128, 52], [226, 168, 74], [246, 206, 118], [255, 230, 160]],
  palHot: [[0, 0, 0], [160, 96, 60], [200, 120, 70], [250, 214, 150], [255, 230, 176], [255, 242, 206], [255, 250, 232]],
};
const MT = { RAY0: 1.24, RAYSTEP: 0.125, CHARGE: 2.26, FLASH: 2.62, MOVE: 2.86, MOVE_END: 3.46, WORD0: 3.02, WORDSTEP: 0.075, SWEEP0: 4.15, BUTTONS: 3.95, BUTTON_STEP: 0.08, BUTTON_DUR: 0.3, BG_FADE: 0.8, ELECTRIC: 2.55, END: 6.5 };
const SWEEP_SPEED = 600 / 0.9, IDLE_SWEEP = [8, 12], IDLE_TWINKLE = [1.4, 3.2];
const BOUNCE = [-14, -10, -6, -2, 1, 3, 2, 1, 0, -1, 0];
const HOLD_TWINKLES = [[4.7, 1], [5.25, 4], [5.7, 7], [6.1, 3]];
const SPARK = [[255, 250, 232], [255, 222, 140], [232, 160, 64]];
const EMBER = [[255, 246, 214], [252, 208, 110], [230, 134, 48], [150, 52, 26], [84, 26, 22]];
const DUST = [96, 70, 92];
const BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]];
const SPARK_SIZES = [1, 2, 3, 3, 2, 1, 1];
const TREMBLE = [[1, 0], [0, 1], [-1, 0], [0, -1]];
const GOLD_D = [122, 74, 26], GOLD_M = [172, 118, 42], GOLD_L = [212, 160, 68];
const FXc = { moteFrom: 0.15, moteRim: 58, moteWarpAt: 0.3, moteWarp: 1.6, runeFrom: 0.2, runeTo: 1.6, rayLife: 0.4, streak: 0.1, trembleFrom: 0.25 };
const PULSE = { dur: 0.16, alpha: 0.18 };
const PHYS = { pullG: 2.6e6, pullPow: 1.25, drag: 0.35, captureR: 0.55, maxLife: 3.2, chiralCCW: 0.82, lifeMin: 1.05, lifeMax: 1.75 };
const MINI = { w: 56, h: 84 }, NUM_MINI = 34, SIGIL = [179, 40], SEAL_R = 30;
export const BUTTON_ORDER = ['play', 'collection', 'achievements', 'settings', 'quit'];

export class Game {
  W = 0; H = 0; time = 0;
  cv: HTMLCanvasElement; ctx: Ctx; out: HTMLCanvasElement;
  fx: Fx | null = null; work: Fx | null = null; glOk = false;
  img: Record<string, Img> = {};
  crt = new Crt();
  mode: 'intro' | 'boot' | 'menu' = 'intro';
  reduced = false; crtOn = true;
  mouse = [0, 0];
  S: Strings; hooks: Hooks;
  constructor(cv: HTMLCanvasElement, out: HTMLCanvasElement, S: Strings, hooks: Hooks) {
    this.cv = cv; this.out = out; this.S = S; this.hooks = hooks;
    this.ctx = cv.getContext('2d', { alpha: false })!;
    this.brand = new Brand(this);
    this.menu = new MenuScene(this);
  }
  // ------------------------------------------------------------- carga
  load(name: string, url: string) {
    return new Promise<void>((res) => { const i = new Image(); i.onload = () => { this.img[name] = i; res(); }; i.onerror = () => res(); i.src = url; });
  }
  async loadIntro() { await this.load('computer', '/img/v3b/computer.png'); await this.load('back', '/img/v3b/back.png'); }
  async loadRest() {
    const L = (n: string) => this.load(n, `/img/v3b/${n}.png`);
    await Promise.all(['chamber', 'clouds', 'menu', 'menu_normal', 'menu_1', 'menu_2', 'smoke1', 'smoke2', 'smoke3', 'seal', 'wordmark'].map(L));
    const [sd, wg] = await Promise.all([rawBitmap('/img/v3b/raw/seal_data.png'), rawBitmap('/img/v3b/raw/wordmark_gold.png')]);
    this.img.sealData = sd; this.img.wordGold = wg;
    // tingidos como o setColor do LÖVE
    this.img.backShadow = tinted(this.img.back as HTMLImageElement, [0, 0, 0]);
    const tint = [1, 0.95, 0.85];
    for (const s of ['smoke1', 'smoke2', 'smoke3']) if (this.img[s]) this.img[s + 't'] = tinted(this.img[s] as HTMLImageElement, tint);
    this.menu.makeGlow();
  }
  initGL() {
    if (this.fx) return this.glOk;
    try {
      this.fx = new Fx(this.out, true);
      const wc = document.createElement('canvas'); wc.width = 4; wc.height = 4;
      this.work = new Fx(wc, true);
      this.fx.program('crt', crtSrc); this.fx.program('pass', PASS);
      this.work.program('crt', crtSrc);
      this.glOk = true;
    } catch (e) { console.warn('[runemoire] WebGL2 indisponível, sem shaders:', e); this.glOk = false; }
    return this.glOk;
  }
  initGLRest() {
    if (!this.glOk || !this.work) return;
    const w = this.work;
    try {
      w.program('glow', glowSrc); w.program('twinkle', twinkleSrc); w.program('vortex', vortexSrc);
      w.program('seal', sealSrc); w.program('word', wordSrc); w.program('fx', fxSrc);
      // paleta 7x4 (palUnlit, palLit, palWarm, palHot) e matriz de Bayer 4x4, como o MenuBrand.load
      const rows = [BD.palUnlit, BD.palLit, BD.palWarm, BD.palHot];
      const pd = new ImageData(7, 4);
      rows.forEach((r, y) => r.forEach((c, x) => { const i = (y * 7 + x) * 4; pd.data.set([c[0], c[1], c[2], 255], i); }));
      w.tex('pal', pd); const bd = new ImageData(4, 4);
      BAYER.forEach((r, y) => r.forEach((b, x) => { const v = Math.round(((b + 0.5) / 16) * 255); bd.data.set([v, v, v, 255], (y * 4 + x) * 4); }));
      w.tex('bayer', bd); w.repeat('bayer');
      for (const k of ['chamber', 'sealData', 'wordGold', 'wordmark']) if (this.img[k]) w.tex(k, this.img[k] as TexImageSource);
    } catch (e) { console.warn('[runemoire] shaders da abertura:', e); }
  }
  resize(w: number, h: number) {
    this.W = Math.max(1, Math.round(w)); this.H = Math.max(1, Math.round(h));
    for (const c of [this.cv, this.out]) { c.width = this.W; c.height = this.H; }
    this.intro.pageKey = '';
  }
  // ------------------------------------------------------------- som
  sfx(n: string, vol = 1, rate = 1) { this.hooks.sfx(n, vol, rate); }
  // ------------------------------------------------------------- o ciclo (passo fixo de 1/60 s, como as capturas do jogo)
  acc = 0; last = 0;
  frame(now: number) {
    const dt = this.last ? Math.min(0.25, (now - this.last) / 1000) : 1 / 60;
    this.last = now;
    this.acc += dt;
    let n = 0;
    while (this.acc >= 1 / 60 && n < 15) { this.step(1 / 60); this.acc -= 1 / 60; n++; }
    if (n === 15) this.acc = 0;
    this.draw();
  }
  step(dt: number) {
    this.time += dt;
    this.crt.update(dt);
    if (this.mode === 'intro') this.intro.update(dt);
    else if (this.mode === 'boot') this.boot.update(dt);
    if (this.mode === 'menu' || this.menu.visible) this.menu.update(dt);
  }
  press() {
    if (this.mode === 'intro') this.intro.press();
    else if (this.mode === 'boot') this.boot.skip();
    else if (this.mode === 'menu') this.menu.skipIntro();
  }
  draw() {
    const g = this.ctx, W = this.W, H = this.H;
    g.setTransform(1, 0, 0, 1, 0, 0); g.globalAlpha = 1; g.globalCompositeOperation = 'source-over'; g.imageSmoothingEnabled = false;
    g.fillStyle = '#000'; g.fillRect(0, 0, W, H);
    if (this.mode === 'intro') this.intro.draw(g);
    else if (this.mode === 'boot') this.boot.draw(g);
    else this.menu.draw(g);
    g.setTransform(1, 0, 0, 1, 0, 0); g.globalAlpha = 1;
    if (this.mode !== 'intro') this.present();
  }
  // CRTShader.endScene: a cena inteira passa pelo crt.glsl (com a moldura de TV) na resolução da janela
  present() {
    const fx = this.fx; if (!fx || !this.glOk) return;
    fx.begin(this.W, this.H);
    const t = fx.tex('scene', this.cv, false, true);
    const c = this.crt;
    if (this.crtOn && c.enabled) {
      fx.draw('crt', t, 0, 0, this.W, this.H, {
        time: this.time, resolution: [this.W, this.H], strength: c.strength, power: c.power, powerDir: c.dir,
        glitch: c.glitchAmount, glitchY: c.glitchBandY, degrade: c.degradeAmount, calmRect: [0, 0, 0, 0], calmRect2: [0, 0, 0, 0], caScale: 1,
      });
    } else fx.draw('pass', t, 0, 0, this.W, this.H);
  }
  // CRTShader.renderTube: o conteúdo do tubo pelo crt.glsl no tamanho do próprio tubo (power vem do tubo ligando)
  tubePass(src: HTMLCanvasElement, power: number) {
    const w = this.work; if (!w || !this.glOk) return null;
    w.begin(src.width, src.height);
    const t = w.tex('tube', src, false, true);
    w.draw('crt', t, 0, 0, src.width, src.height, { time: this.time, resolution: [src.width, src.height], strength: Math.max(0.6, this.crt.strength > 0.01 ? this.crt.strength : 0.75),
      power, powerDir: 1, glitch: 0, glitchY: 0.5, degrade: 0, calmRect: [0, 0, 0, 0], calmRect2: [0, 0, 0, 0], caScale: 1 });
    return w.canvas;
  }
  // um passe de shader sobre uma imagem desenhada em (x, y, w, h) da tela: devolve o canvas para o drawImage
  shaderPass(name: string, texKey: string, x: number, y: number, w: number, h: number, u: Record<string, any>, color = [1, 1, 1, 1], tw = this.W, th = this.H, src?: number[]) {
    const wk = this.work; if (!wk || !this.glOk || !wk.progs.has(name) || !wk.texs.has(texKey)) return null;
    wk.begin(tw, th);
    const extra: Record<string, any> = {};
    for (const [k, v] of Object.entries(u)) extra[k] = typeof v === 'string' ? wk.texs.get(v)!.t : v;
    wk.draw(name, wk.texs.get(texKey)!.t, x, y, w, h, extra, color, src);
    return wk.canvas;
  }

  // ===================================================================== CardBack.draw (verso com sombra recortada)
  cardBack(g: Ctx, x: number, y: number, w: number, h: number, o: { alpha?: number; scale?: number; rot?: number; lift?: number }) {
    const a = o.alpha ?? 1; if (a <= 0) return;
    const img = this.img.back as HTMLImageElement; if (!img) return;
    const iw = img.width, ih = img.height, scale = o.scale ?? 1;
    const sx = (w / iw) * scale, sy = (h / ih) * scale;
    const lift = o.lift ?? 0, totalLift = lift - 3;
    const dirX = Math.max(-1, Math.min(1, (x - this.W / 2) / (this.W / 2)));
    const offX = -dirX * 20, liftMag = Math.abs(lift) + 3, offY = 6 + liftMag * 0.5;
    const shA = Math.min(0.85, (0.5 + liftMag * 0.003) * a);
    g.save(); g.translate(x, y + totalLift); g.rotate(o.rot ?? 0); g.scale(sx, sy);
    g.imageSmoothingEnabled = false;
    if (this.img.backShadow) { g.globalAlpha = shA; g.drawImage(this.img.backShadow as HTMLCanvasElement, -iw / 2 + offX / sx, -ih / 2 + offY / sy); }
    g.globalAlpha = a; g.drawImage(img, -iw / 2, -ih / 2);
    g.restore(); g.globalAlpha = 1;
  }

  // ===================================================================== IntroTube.lua
  intro = new (class IntroTube {
    g: Game; phase: 'off' | 'insert' | 'power' | 'type' | 'hold' | 'flash' | 'dive' | 'done' = 'off';
    t = 0; insT = 0; insSfx = 0; powT = 0; holdT = 0; flashT = 0; diveT = 0;
    shownTitle = 0; shownSub = 0; acc = 0; pauseT = 0; letters = 0; doneTyping = false;
    content = document.createElement('canvas'); cctx = this.content.getContext('2d')!;
    page: HTMLCanvasElement | null = null; pageKey = '';
    constructor(g: Game) { this.g = g; }
    get title() { return this.g.S.title; } get sub() { return this.g.S.subtitle; }
    reset() { Object.assign(this, { phase: 'off', t: 0, insT: 0, insSfx: 0, powT: 0, holdT: 0, flashT: 0, diveT: 0, shownTitle: 0, shownSub: 0, acc: 0, pauseT: 0, letters: 0, doneTyping: false }); }
    geometry(W: number, H: number) {
      const d = PC;
      const k = Math.max(0.1, Math.min((H * IT.ART_FRAC) / d.h, (W * 0.62) / d.w));
      const aw = d.w * k, ah = d.h * k, ax = W / 2 - aw / 2, ay = H * 0.5 - ah / 2;
      const sx = ax + d.screen.x * k, sy = ay + d.screen.y * k, sw = d.screen.w * k, sh = d.screen.h * k;
      const tw = Math.max(8, Math.floor(sw)), th = Math.max(8, Math.floor(sh)), B = IT.BEZEL_PX;
      const sEndX = (W - 2 * B) / sw, sEndY = (H - 2 * B) / sh;
      return { art: k, ax, ay, aw, ah, sx, sy, sw, sh, tw, th, cx: sx + sw / 2, cy: sy + sh / 2, sEndX, sEndY,
        slot: { x: ax + d.slot.x * k, y: ay + d.slot.y * k, w: d.slot.w * k, h: d.slot.h * k } };
    }
    press() {
      if (this.phase === 'done') return;
      if (this.phase === 'off') { this.phase = 'insert'; this.insT = 0; this.g.hooks.onPhase?.('insert'); return; }
      this.finish();
    }
    finish() { if (this.phase === 'done') return; this.phase = 'done'; this.g.startBoot(); }
    blip() { this.g.sfx('blip_' + (1 + Math.floor(Math.random() * 6)), 0.32, 0.96 + Math.random() * 0.1); }
    typeStep(dt: number) {
      if (this.doneTyping) return;
      if (this.pauseT > 0) { this.pauseT -= dt; return; }
      this.acc += dt * IT.cps;
      const lt = [...this.title].length, ls = [...this.sub].length;
      while (this.acc >= 1) {
        this.acc -= 1;
        if (this.shownTitle < lt) {
          this.shownTitle++; this.letters++; if (this.letters % 2 === 1) this.blip();
          if (this.shownTitle === lt) { this.pauseT = IT.gapSub; this.acc = 0; return; }
        } else if (this.shownSub < ls) {
          this.shownSub++; const ch = [...this.sub][this.shownSub - 1];
          this.letters++; if (this.letters % 2 === 1) this.blip();
          if (ch === '.' || ch === '!' || ch === '?') { this.pauseT = 0.28; this.acc = 0; return; }
        } else { this.doneTyping = true; return; }
      }
    }
    update(dt: number) {
      if (this.phase === 'done') return;
      this.t += dt;
      const g = this.g;
      if (this.phase === 'insert') {
        this.insT += dt;
        if (this.insSfx === 0) { this.insSfx = 1; g.sfx('card-draw'); }
        if (this.insSfx === 1 && this.insT >= IT.insert * 0.78) { this.insSfx = 2; g.sfx('button-click'); }
        if (this.insT >= IT.insert) { this.phase = 'power'; this.powT = 0; g.sfx('boot-tv-power-on'); g.hooks.onPhase?.('power'); }
      } else if (this.phase === 'power') {
        this.powT += dt;
        if (this.powT >= IT.POWER) { this.phase = 'type'; g.hooks.onPhase?.('type'); }
      } else if (this.phase === 'type') {
        this.typeStep(dt);
        if (this.doneTyping) { this.phase = 'hold'; this.holdT = 0; }
      } else if (this.phase === 'hold') {
        this.holdT += dt; if (this.holdT >= IT.hold) { this.phase = 'flash'; this.flashT = 0; g.hooks.onPhase?.('flash'); }
      } else if (this.phase === 'flash') {
        this.flashT += dt; if (this.flashT >= IT.insertHold) { this.phase = 'dive'; this.diveT = 0; g.hooks.onPhase?.('dive'); }
      } else if (this.phase === 'dive') {
        this.diveT += dt; if (this.diveT >= IT.dive) this.finish();
      }
    }
    tubePower() { return this.phase === 'off' || this.phase === 'insert' ? 0 : this.phase === 'power' ? Math.min(1, this.powT / IT.POWER) : 1; }
    textAlpha() { if (this.phase === 'type' || this.phase === 'hold') return 1; if (this.phase === 'flash') return Math.max(0, 1 - this.flashT / IT.insertHold); return 0; }
    drawPage(g: Ctx, W: number, H: number) {
      const key = W + 'x' + H;
      if (this.pageKey !== key || !this.page) {
        this.pageKey = key;
        const cv = this.page || document.createElement('canvas'); cv.width = W; cv.height = H; this.page = cv;
        const x = cv.getContext('2d')!, id = x.createImageData(W, H), d = id.data;
        const P = PAL.PARCHMENT.map((v) => v * 255), D = PAL.PARCHMENT_DARK.map((v) => v * 255);
        const cell = Math.max(2, Math.floor(Math.min(W, H) / 240));
        for (let y = 0; y < H; y += cell) for (let xx = 0; xx < W; xx += cell) {
          const nx = (xx / W - 0.5) * 2, ny = (y / H - 0.5) * 2, dd = Math.sqrt(nx * nx + ny * ny);
          const v = Math.max(0, (dd - 0.55) / 0.75), step = Math.floor(v * 5) / 5, frac = v * 5 - Math.floor(v * 5);
          const lvl = step + (BAYER[(y / cell) % 4][(xx / cell) % 4] < frac * 16 ? 0.2 : 0);
          let gg = Math.sin(xx * 12.9898 + y * 78.233) * 43758.5453; gg -= Math.floor(gg);
          const a = Math.min(0.8, lvl * 0.55 + (gg > 0.93 ? 0.08 : 0));
          for (let yy = y; yy < Math.min(H, y + cell); yy++) for (let x2 = xx; x2 < Math.min(W, xx + cell); x2++) {
            const i = (yy * W + x2) * 4;
            d[i] = P[0] + (D[0] - P[0]) * a; d[i + 1] = P[1] + (D[1] - P[1]) * a; d[i + 2] = P[2] + (D[2] - P[2]) * a; d[i + 3] = 255;
          }
        }
        x.putImageData(id, 0, 0);
      }
      g.drawImage(this.page, 0, 0);
    }
    drawTubeContent(c: Ctx, tw: number, th: number, cw: number, ch: number) {
      const ink = PAL.INK, B = IT.BEZEL_PX;
      c.setTransform(1, 0, 0, 1, 0, 0);
      c.fillStyle = rgba([ink[0] * 0.55, ink[1] * 0.55, ink[2] * 0.6]); c.fillRect(0, 0, cw, ch);
      c.translate(B, B);
      for (let i = 3; i >= 1; i--) { const k = i / 3; c.fillStyle = `rgba(26,28,26,${0.22 * (1 - k) + 0.06})`; c.fillRect(tw * (0.5 - 0.5 * k), th * (0.5 - 0.5 * k), tw * k, th * k); }
      const ta = this.textAlpha();
      if (ta > 0.001) {
        const tA = [...this.title], sA = [...this.sub];
        const t1 = tA.slice(0, this.shownTitle).join(''), t2 = sA.slice(0, this.shownSub).join('');
        const cur = Math.floor(this.g.time * 2.2) % 2 === 0 ? '_' : '';
        const typingTitle = this.shownTitle < tA.length;
        const fT = font(c, Math.max(12, Math.floor(tw / 14)));
        const y1 = Math.floor(th * 0.4 - fT.h / 2);
        const w1 = c.measureText(t1).width, x1 = Math.floor((tw - w1) / 2);
        c.fillStyle = rgba(ink, 0.8 * ta); print(c, t1, x1 + 2, y1 + 2, fT.asc);
        c.fillStyle = rgba(PAL.PARCHMENT_LIGHT, ta); print(c, t1 + (typingTitle ? cur : ''), x1, y1, fT.asc);
        if (this.shownTitle >= tA.length) {
          const inner = tw - 2 * B - 28;
          let size = Math.max(8, Math.floor(tw / 30));
          font(c, size); while (size > 7 && c.measureText(this.sub).width > inner * 2) { size--; font(c, size); }
          const f2 = font(c, size);
          const wrap = (s: string) => { const out: string[] = []; let line = ''; for (const wd of s.split(' ')) { const tryL = line ? line + ' ' + wd : wd; if (c.measureText(tryL).width > inner && line) { out.push(line); line = wd; } else line = tryL; } if (line || !out.length) out.push(line); return out; };
          const full = wrap(this.sub);
          const showCur = this.shownSub < sA.length || this.doneTyping;
          const lines = wrap(t2 + (showCur ? cur : ''));
          c.fillStyle = rgba(PAL.PARCHMENT, ta);
          const y2 = y1 + fT.h + Math.floor(th * 0.06);
          lines.forEach((ln, i) => { if (i <= Math.max(full.length, 1)) print(c, ln, Math.floor((tw - c.measureText(ln).width) / 2), y2 + i * (f2.h + 4), f2.asc); });
        }
      }
      if (this.phase === 'flash') {
        const k = clamp01(1 - this.flashT / IT.insertHold);
        c.fillStyle = rgba(PAL.PARCHMENT_LIGHT, 0.85 * k); c.fillRect(0, 0, tw, th);
      }
    }
    drawInsertCard(g: Ctx, G: ReturnType<IntroTube['geometry']>, W: number, H: number, m: DOMMatrix) {
      if (!(this.phase === 'insert' || this.phase === 'power' || this.phase === 'type' || this.phase === 'hold' || this.phase === 'flash')) return;
      // no jogo a carta some no fim do clarão; aqui ela fica no drive enquanto o tubo liga e o nome aparece
      const u = easeInOutCubic(Math.min(1, this.phase === 'insert' ? this.insT / IT.insert : 1));
      const sl = G.slot, cw = Math.max(24, sl.w * 0.82), ch = cw * 1.5;
      const x0 = W + cw * 0.8, y0 = H + ch * 0.6, x1 = sl.x + sl.w / 2, y1 = sl.y - ch / 2 + ch * 0.05;
      const x = x0 + (x1 - x0) * u, y = y0 + (y1 - y0) * u, rot = -0.38 * (1 - u);
      g.save();
      g.setTransform(1, 0, 0, 1, 0, 0);
      g.beginPath(); g.rect(0, Math.floor(sl.y), W, Math.max(1, H - Math.floor(sl.y))); g.clip();
      g.setTransform(m);
      g.save(); g.translate(x + 8, y + 10); g.rotate(rot);
      g.fillStyle = rgba(PAL.INK, 0.35); g.beginPath(); g.roundRect(-cw / 2, -ch / 2, cw, ch, 4); g.fill(); g.restore();
      this.g.cardBack(g, x, y, cw, ch, { rot, alpha: 1 });
      g.restore();
    }
    draw(g: Ctx) {
      const { W, H } = this.g;
      const G = this.geometry(W, H);
      const fade = this.g.reduced ? 1 : Math.min(1, this.t / IT.fadeIn);
      const dive = this.phase === 'dive' ? easeInOutCubic(this.diveT / IT.dive) : 0;
      this.drawPage(g, W, H);
      if (dive > 0) { g.fillStyle = `rgba(0,0,0,${dive})`; g.fillRect(0, 0, W, H); }
      const pop = this.g.reduced ? 1 : 0.92 + 0.08 * backOut(Math.min(1, this.t / IT.tvPop));
      const B = IT.BEZEL_PX, tvAlpha = fade;
      const sxK = pop * (1 + (G.sEndX - 1) * dive), syK = pop * (1 + (G.sEndY - 1) * dive);
      const px = G.cx + (W / 2 - G.cx) * dive, py = G.cy + (H / 2 - G.cy) * dive;
      g.save();
      g.translate(px, py); g.scale(sxK, syK); g.translate(-G.cx, -G.cy);
      const m = g.getTransform();
      if (dive < 1) { g.fillStyle = rgba(PAL.INK, 0.4 * tvAlpha * (1 - dive)); g.beginPath(); g.roundRect(G.ax + 10, G.ay + 12, G.aw, G.ah, 6); g.fill(); }
      // o tubo: conteúdo num canvas próprio, passa pelo crt.glsl e entra no buraco da tela do computador
      const cw0 = dive > 0 ? W : G.tw + 2 * B, ch0 = dive > 0 ? H : G.th + 2 * B;
      if (this.content.width !== cw0 || this.content.height !== ch0) { this.content.width = cw0; this.content.height = ch0; }
      this.drawTubeContent(this.cctx, cw0 - 2 * B, ch0 - 2 * B, cw0, ch0);
      const tube = this.g.tubePass(this.content, this.tubePower());
      g.globalAlpha = tvAlpha; g.imageSmoothingEnabled = true;
      if (tube) g.drawImage(tube, B, B, cw0 - 2 * B, ch0 - 2 * B, G.sx, G.sy, G.sw, G.sh);
      else { g.fillStyle = this.tubePower() > 0.5 ? '#100c0a' : '#030303'; g.fillRect(G.sx, G.sy, G.sw, G.sh); }
      g.imageSmoothingEnabled = false;
      if (this.g.img.computer) g.drawImage(this.g.img.computer as HTMLImageElement, G.ax, G.ay, PC.w * G.art, PC.h * G.art);
      g.globalAlpha = 1;
      this.drawInsertCard(g, G, W, H, m);
      g.restore();
    }
  })(this);

  // ===================================================================== BootScene.lua
  startBoot() {
    this.mode = 'boot';
    this.crt.enabled = this.crtOn;
    this.crt.setPower(0); this.crt.powerOn(1.8);
    this.sfx('boot-tv-power-on');
    this.boot.start();
    this.hooks.onPhase?.('boot');
  }
  boot = new (class Boot {
    g: Game; phase: 'loading' | 'splash' | 'done' = 'loading';
    loadingTime = 0; splashTime = 0; evT = 0; staticAlpha = 0; sealCharge = 0; flare = 0;
    rng = new LoveRng(1); seed = 1;
    ev: { at: number; fn: () => void }[] = []; eases: { o: any; k: string; from: number; to: number; dur: number; t: number; e: (u: number) => number }[] = [];
    cards: any[] = []; shards: any[] = []; absorbed = 0;
    tx = 0; ty = 0; s = 4;
    noise: HTMLCanvasElement[] = [];
    constructor(g: Game) { this.g = g; }
    start() { this.phase = 'loading'; this.loadingTime = 0; this.cards = []; this.shards = []; this.ev = []; this.eases = []; this.flare = 0; this.absorbed = 0; this.staticAlpha = 0; this.sealCharge = 0; this.seed = 1; this.rng.setSeed(this.seed); }
    rnd(a?: number, b?: number) { return a === undefined ? this.rng.random() : a + (b! - a) * this.rng.random(); }
    ease(o: any, k: string, to: number, dur: number, e = smooth) { this.eases.push({ o, k, from: o[k], to, dur, t: 0, e }); }
    anchor() { return [this.tx + SIGIL[0] * this.s, this.ty + SIGIL[1] * this.s]; }
    startSplash() {
      this.phase = 'splash'; this.splashTime = 0; this.evT = 0;
      this.staticAlpha = 0.85; this.ease(this, 'staticAlpha', 0, 0.55); this.ease(this, 'sealCharge', 1, 2.0);
      const at = (t: number, fn: () => void) => this.ev.push({ at: t, fn });
      at(1.5, () => this.g.sfx('boot-vortex'));
      at(1.75, () => this.g.sfx('boot-card-whoosh'));
      const reduced = this.g.reduced;
      const chir = this.rng.random() < 0.5 ? 1 : -1;
      let tSpawn = 1.8, lastSpawn = tSpawn;
      const n = reduced ? 0 : NUM_MINI;
      for (let i = 1; i <= n; i++) {
        if (i > 1) {
          let gap = -Math.log(1 - this.rng.random() * 0.98) * 0.07;
          if (this.rng.random() < 0.1) gap += this.rnd(0.18, 0.32);
          tSpawn += Math.min(0.45, gap);
        }
        lastSpawn = tSpawn;
        const angle0 = this.rnd(0, TAU), side = this.rng.random() < PHYS.chiralCCW ? chir : -chir;
        const tang = this.rnd(0.55, 1), speedK = this.rnd(0.75, 1.25), life = this.rnd(PHYS.lifeMin, PHYS.lifeMax);
        const envPow = this.rnd(1.3, 2.1), spinV = this.rnd(-2.6, 2.6), scale0 = this.rnd(0.82, 1.18), sizeK = this.rnd(0.9, 1.12);
        const pitch = 0.85 + this.rnd(0, 0.5);
        at(tSpawn, () => {
          const { W, H } = this.g; const [sx, sy] = this.anchor();
          const dx = Math.cos(angle0), dy = Math.sin(angle0), margin = 70;
          let tExit = Infinity;
          if (dx > 1e-6) tExit = Math.min(tExit, (W + margin - sx) / dx); else if (dx < -1e-6) tExit = Math.min(tExit, (-margin - sx) / dx);
          if (dy > 1e-6) tExit = Math.min(tExit, (H + margin - sy) / dy); else if (dy < -1e-6) tExit = Math.min(tExit, (-margin - sy) / dy);
          if (tExit === Infinity) tExit = Math.max(W, H) * 0.7;
          const r0 = tExit + 10, K = H / 768, v0 = (170 + 160 * speedK) * K;
          const tx = -dy * side, ty = dx * side, ix = -dx, iy = -dy;
          const mc = { x: sx + dx * r0, y: sy + dy * r0, vx: (tx * tang + ix * (1 - tang) * 0.8) * v0, vy: (ty * tang + iy * (1 - tang) * 0.8) * v0,
            r0, K, life, envPow, spin: this.rnd(0, TAU) * 0.15, spinV, scale0, sizeK, rot: 0, scale: 0, alpha: 0, fadeMul: 1, age: 0, trail: [] as any[], trailT: 0 };
          this.cards.push(mc); this.ease(mc, 'alpha', 1, 0.15);
          this.g.sfx('card-draw', 0.42, pitch);
        });
      }
      const tCascadeEnd = lastSpawn + 1.5;
      at(tCascadeEnd + 0.35, () => this.finish());
    }
    finish() { if (this.phase === 'done') return; this.phase = 'done'; this.cards = []; this.shards = []; this.flare = 0; this.g.startMenu(true); }
    skip() { this.ev = []; this.finish(); }
    update(dt: number) {
      if (this.phase === 'done') return;
      // EventManager.update antes da cena (como no love.update)
      this.evT += dt;
      for (const e of this.eases) { e.t += dt; e.o[e.k] = e.from + (e.to - e.from) * e.e(Math.min(1, e.t / e.dur)); }
      this.eases = this.eases.filter((e) => e.t < e.dur);
      if (this.phase === 'splash') {
        const due = this.ev.filter((e) => e.at <= this.evT); this.ev = this.ev.filter((e) => e.at > this.evT);
        for (const e of due) { e.fn(); if ((this.phase as string) === 'done') return; }
      }
      this.flare = Math.max(0, this.flare - dt * 1.6);
      if (this.phase === 'loading') {
        this.loadingTime += dt;
        if (this.loadingTime / 0.5 >= 1) this.startSplash();
        return;
      }
      this.splashTime += dt;
      const [sx, sy] = this.anchor(), moonR = SEAL_R * this.s, capR = moonR * PHYS.captureR;
      for (let i = this.cards.length - 1; i >= 0; i--) {
        const mc = this.cards[i];
        mc.age += dt;
        let ddx = sx - mc.x, ddy = sy - mc.y, r = Math.sqrt(ddx * ddx + ddy * ddy);
        const rr = Math.max(r, moonR * 0.6), a = (PHYS.pullG * mc.K * mc.K) / rr ** PHYS.pullPow;
        mc.vx += (ddx / Math.max(r, 1)) * a * dt; mc.vy += (ddy / Math.max(r, 1)) * a * dt;
        const dr = PHYS.drag * (1 + 2.5 * Math.max(0, 1 - r / (moonR * 3)));
        mc.vx *= Math.max(0, 1 - dr * dt); mc.vy *= Math.max(0, 1 - dr * dt);
        mc.x += mc.vx * dt; mc.y += mc.vy * dt;
        const u = Math.min(1, mc.age / mc.life), rEnv = mc.r0 * (1 - u ** mc.envPow);
        const ex = sx - mc.x, ey = sy - mc.y, rNow = Math.sqrt(ex * ex + ey * ey);
        if (rNow > rEnv && rNow > 1) {
          const k = rEnv / rNow; mc.x = sx - ex * k; mc.y = sy - ey * k;
          const nx = ex / rNow, ny = ey / rNow, vr = mc.vx * nx + mc.vy * ny;
          if (vr < 0) { mc.vx -= vr * nx; mc.vy -= vr * ny; }
        }
        r = rNow;
        mc.spinV *= Math.max(0, 1 - 0.9 * dt); mc.spin += mc.spinV * dt;
        mc.rot = Math.atan2(mc.vy, mc.vx) + Math.PI / 2 + mc.spin;
        let pop = Math.min(1, mc.age / 0.12); pop = pop * pop * (3 - 2 * pop);
        const rk = Math.min(1, r / (mc.r0 * 0.6));
        mc.scale = pop * mc.scale0 * (0.22 + 0.78 * rk ** 0.8);
        mc.fadeMul = r < moonR ? Math.max(0.15, r / moonR) : 1;
        mc.trailT += dt;
        if (mc.trailT >= 0.03) { mc.trailT = 0; mc.trail.unshift({ x: mc.x, y: mc.y, rot: mc.rot, scale: mc.scale }); if (mc.trail.length > 5) mc.trail.pop(); }
        if (r < capR || mc.age >= mc.life + 0.4 || mc.age >= PHYS.maxLife) {
          this.cards.splice(i, 1); this.absorbed++;
          this.flare = Math.min(1, this.flare + 0.3);
          const ns = Math.floor(this.rnd(4, 8));
          for (let j = 0; j < ns; j++) { const an = this.rnd(0, TAU), v = (this.rnd(40, 130) * this.s) / 4; this.shards.push({ x: sx, y: sy, vx: Math.cos(an) * v, vy: Math.sin(an) * v, age: 0, life: this.rnd(0.22, 0.45), tone: this.rnd() }); }
        }
      }
      for (let i = this.shards.length - 1; i >= 0; i--) {
        const sh = this.shards[i]; sh.age += dt; sh.x += sh.vx * dt; sh.y += sh.vy * dt; sh.vx *= 1 - 2.5 * dt; sh.vy *= 1 - 2.5 * dt;
        if (sh.age >= sh.life) this.shards.splice(i, 1);
      }
    }
    bgPass(g: Ctx, name: string, u: Record<string, any>, op: GlobalCompositeOperation) {
      const ch = this.g.img.chamber as HTMLImageElement; if (!ch) return;
      const c = this.g.shaderPass(name, 'chamber', this.tx, this.ty, ch.width * this.s, ch.height * this.s, u);
      if (!c) return;
      g.globalCompositeOperation = op; g.drawImage(c, 0, 0, this.g.W, this.g.H, 0, 0, this.g.W, this.g.H); g.globalCompositeOperation = 'source-over';
    }
    drawBackground(g: Ctx) {
      const { W, H, time } = this.g, ch = this.g.img.chamber as HTMLImageElement;
      if (!ch) return;
      const s = Math.max(W / ch.width, H / ch.height);
      this.tx = Math.floor((W - ch.width * s) / 2); this.ty = Math.floor((H - ch.height * s) / 2); this.s = s;
      g.drawImage(ch, this.tx, this.ty, ch.width * s, ch.height * s);
      const [gx, gy] = this.anchor();
      this.bgPass(g, 'twinkle', { t: time, moon_center: [gx, gy], moon_radius: SEAL_R * s, art_off: [this.tx, this.ty], art_scale: s, sky_limit: 84 }, 'lighter');
      if (this.phase === 'splash') {
        const st = this.sealCharge * 0.75 + 0.5 * this.flare;
        if (st >= 0.02) this.bgPass(g, 'vortex', { t: this.splashTime, moon_uv: [SIGIL[0] / ch.width, SIGIL[1] / ch.height], tex_size: [ch.width, ch.height], radius_px: SEAL_R, strength: Math.min(1, st) }, 'source-over');
      }
      const cl = this.g.img.clouds as HTMLImageElement;
      if (cl) {
        const layerW = cl.width * s;
        for (const L of [{ spd: 2.2, iy: -16, a: 0.75, flip: false }, { spd: 3.8, iy: -2, a: 0.45, flip: true }]) {
          const x0 = -((time * L.spd * s) % layerW), y = this.ty + L.iy * s;
          g.globalAlpha = L.a;
          for (let k = 0; k <= 1 + Math.ceil(W / layerW); k++) {
            const x = x0 + k * layerW;
            if (L.flip) { g.save(); g.translate(x + layerW, y); g.scale(-s, s); g.drawImage(cl, 0, 0); g.restore(); }
            else g.drawImage(cl, x, y, layerW, cl.height * s);
          }
        }
        g.globalAlpha = 1;
      }
      if (this.phase === 'splash') {
        const breath = 0.34 + 0.14 * Math.sin(time * 1.8), st = this.sealCharge * breath + 0.66 * this.flare;
        if (st >= 0.01) this.bgPass(g, 'glow', { center: [gx, gy], radius: SEAL_R * s, strength: Math.min(1, st) }, 'lighter');
      }
    }
    staticNoise(g: Ctx, alpha: number) {
      if (alpha <= 0.01 || !this.g.crt.enabled) return;
      if (!this.noise.length) for (let f = 0; f < 4; f++) {
        const c = document.createElement('canvas'); c.width = 160; c.height = 120; const x = c.getContext('2d')!, id = x.createImageData(160, 120);
        for (let i = 0; i < id.data.length; i += 4) { let v = Math.random(); v = v * v * 255; id.data[i] = id.data[i + 1] = id.data[i + 2] = v; id.data[i + 3] = 255; }
        x.putImageData(id, 0, 0); this.noise.push(c);
      }
      const { W, H, time } = this.g;
      g.globalAlpha = alpha; g.drawImage(this.noise[Math.floor(time * 12) % 4], 0, 0, W, H); g.globalAlpha = 1;
      const bandY = ((time * 0.35) % 1.3) - 0.15;
      if (bandY >= -0.1 && bandY <= 1.1) { g.fillStyle = `rgba(0,0,0,${0.35 * alpha})`; g.fillRect(0, bandY * H, W, H * 0.06); }
    }
    osdText(g: Ctx, s: string, x: number, y: number, alpha: number, size = 15) {
      if (alpha <= 0.02) return; const f = font(g, size);
      g.fillStyle = `rgba(0,0,0,${0.85 * alpha})`; print(g, s, x + 2, y + 2, f.asc);
      g.fillStyle = rgba(AMBER, 0.25 * alpha); print(g, s, x + 1, y, f.asc);
      g.fillStyle = rgba(AMBER, alpha); print(g, s, x, y, f.asc);
    }
    osdW(g: Ctx, s: string, size = 15) { font(g, size); return g.measureText(s).width; }
    draw(g: Ctx) {
      if (this.phase === 'done') return;
      const { W, H, time } = this.g;
      this.drawBackground(g);
      if (this.phase === 'loading') {
        const segs = 16, segW = 16, gap = 3, barW = segs * (segW + gap) - gap, x = Math.floor((W - barW) / 2), y = Math.floor(H * 0.62);
        const label = this.g.S.loading;
        this.osdText(g, label, Math.floor((W - this.osdW(g, label, 14)) / 2), y - 28, 1, 14);
        const filled = Math.floor(Math.min(1, this.loadingTime / 0.5) * segs + 0.5);
        for (let i = 1; i <= segs; i++) {
          const sx = x + (i - 1) * (segW + gap);
          g.fillStyle = 'rgba(0,0,0,0.7)'; g.fillRect(sx + 2, y + 2, segW, 14);
          if (i <= filled) { g.fillStyle = rgba(AMBER); g.fillRect(sx, y, segW, 14); g.fillStyle = 'rgba(255,255,255,0.3)'; g.fillRect(sx, y, segW, 2); }
          else { g.strokeStyle = rgba(AMBER_DIM, 0.55); g.lineWidth = 1; g.strokeRect(sx + 0.5, y + 0.5, segW - 1, 13); }
        }
        this.staticNoise(g, 0.25);
      } else {
        const ghostA = [0.26, 0.17, 0.11, 0.06, 0.035];
        for (const mc of this.cards) {
          const cw = MINI.w * mc.sizeK, ch = MINI.h * mc.sizeK;
          for (let gi = mc.trail.length - 1; gi >= 0; gi--) { const t = mc.trail[gi]; this.g.cardBack(g, t.x, t.y, cw, ch, { alpha: mc.alpha * mc.fadeMul * (ghostA[gi] ?? 0.03), scale: t.scale * 0.97, rot: t.rot }); }
          this.g.cardBack(g, mc.x, mc.y, cw, ch, { alpha: mc.alpha * mc.fadeMul, scale: mc.scale, rot: mc.rot });
        }
        const px = this.s;
        for (const sh of this.shards) {
          const k = sh.age / sh.life, c = sh.tone > 0.5 ? PAL.AGED_GOLD_LIGHT : PAL.PARCHMENT_LIGHT;
          g.fillStyle = rgba(c, (1 - k) * 0.95); g.fillRect(Math.floor(sh.x / px) * px, Math.floor(sh.y / px) * px, px, px);
        }
        this.staticNoise(g, this.staticAlpha);
        const f = font(g, 10), label = this.g.S.skip, pulse = 0.5 + Math.sin(time * 2) * 0.2;
        g.fillStyle = rgba(PAL.PARCHMENT_DARK, pulse); print(g, label, Math.floor((W - g.measureText(label).width) / 2), H - 28, f.asc);
      }
      this.osdText(g, 'AV-1', W - this.osdW(g, 'AV-1') - 26, 20, 0.9);
      const f9 = font(g, 9); g.fillStyle = rgba(PAL.PARCHMENT_DARK, 0.6); print(g, 'v' + this.g.S.version, 12, H - 22, f9.asc);
    }
  })(this);

  // ===================================================================== Menu
  brand: Brand; menu: MenuScene;
  startMenu(full: boolean) {
    this.mode = 'menu';
    this.menu.enterWithIntro(full && !this.reduced);
    this.hooks.onMenu();
  }
  // Sair: CRTShader.powerOff(1.2) e volta à mesa com o computador desligado
  quit() {
    if (this.mode !== 'menu') return;
    this.crt.powerOff(1.2, () => { this.toDesk(); });
  }
  toDesk() {
    this.mode = 'intro'; this.menu.visible = false; this.intro.reset(); this.crt.setPower(1, 1);
    this.hooks.music(false); this.hooks.onDesk();
  }
  // movimento reduzido: o jogo pula a abertura (sem cartas, sem a vinheta do selo) e entra direto
  skipAll() { this.intro.phase = 'done'; this.mode = 'menu'; this.crt.enabled = this.crtOn; this.crt.setPower(1, 1); this.crt.anim = null; this.menu.enterWithIntro(false); this.menu.settle(); this.hooks.onMenu(); }
}

// ===================================================================== MenuBrand.lua
class Brand {
  g: Game; mode: 'static' | 'idle' | 'sting' = 'static'; clock = 0; sweeps: number[] = []; twinkles: number[][] = [];
  rng = new LoveRng(7); burst: any[] = []; converge: any[] = []; motes: any[] = []; raySparks: any[] = []; embers: any[] = []; emberT0 = Infinity;
  nextSweep = 0; nextTwinkle = 0; alphaMul = 1; L: any; G: any;
  constructor(g: Game) {
    this.g = g; const r = () => this.rng.random();
    for (let i = 0; i < 46; i++) { const a = r() * TAU, s = 70 + r() * 160; this.burst.push({ vx: Math.cos(a) * s, vy: Math.sin(a) * s * 0.9, life: 0.6 + r() * 1.1, big: r() < 0.3 }); }
    for (let i = 0; i < 28; i++) this.converge.push({ a: r() * TAU, r0: 110 + r() * 80, t0: MT.CHARGE - 0.1 + r() * 0.2 });
    for (let i = 0; i < 96; i++) this.motes.push({ a0: r() * TAU, spin: r() < 0.5 ? -1 : 1, ts: FXc.moteFrom + r() * 1.6, period: 0.8 + r() * 0.6, r0: 150 + r() * 100, big: r() < 0.35 });
    for (let i = 0; i < 48; i++) this.raySparks.push({ da: (r() - 0.5) * 1.6, v: 40 + r() * 70, life: 0.18 + r() * 0.2 });
    for (let i = 0; i < 16; i++) this.embers.push({ x0: -50 + r() * (BD.word.w + 100), yn: r(), vy: -22 + r() * 13, ph: r() * 6.28, amp: 2 + r() * 5, t0: r() * 2.6, life: 1.8 + r() * 1.6, fl: 4 + r() * 5 });
  }
  rand(lo: number, hi: number) { return lo + this.rng.random() * (hi - lo); }
  static buttonColumn(vh: number) { const sp = Math.min(80, vh * 0.092), h = Math.min(60, vh * 0.08); return [vh * 0.975 - 4 * sp - h, sp, h]; }
  static layout(vw: number, vh: number) {
    const W = vw, H = vh, [y0, spacing] = Brand.buttonColumn(vh), topV = vh * 0.025;
    const region = y0 - spacing - vh * 0.02 - topV;
    const sw = BD.seal.w, sh = BD.seal.h, ww = BD.word.w, wh = BD.word.h, gap = BD.gap;
    let P = Math.max(1, Math.floor((W * 0.46) / ww)), Ps = 0;
    for (;;) {
      for (let s = P; s >= Math.max(1, P - 2); s--) if ((sh + gap) * s + wh * P <= region) { Ps = s; break; }
      if (Ps || P === 1) break;
      P--;
    }
    Ps = Ps || 1;
    const total = (sh + gap) * Ps + wh * P, top = Math.floor(topV + Math.max(0, region - total) / 2 + 0.5), ox = Math.floor((W - ww * P) / 2 + 0.5);
    return { P, Ps, ox, oy: top + (sh + gap) * Ps, W, H, top, total, sealPX: Math.floor(ox + (ww * P - sw * Ps) / 2 + 0.5), sealPY: top, wordX: 0, wordY: 0 };
  }
  isPlaying() { return this.mode === 'sting'; }
  stingTime() { return this.mode === 'sting' ? this.clock : Infinity; }
  toIdle() {
    this.mode = 'idle'; this.sweeps = []; this.twinkles = [];
    this.nextSweep = this.clock + this.rand(IDLE_SWEEP[0], IDLE_SWEEP[1]); this.nextTwinkle = this.clock + this.rand(IDLE_TWINKLE[0], IDLE_TWINKLE[1]);
    if (this.emberT0 === Infinity) this.emberT0 = this.clock;
  }
  startSting() {
    this.mode = 'sting'; this.clock = 0; this.emberT0 = MT.MOVE; this.sweeps = [MT.SWEEP0]; this.twinkles = [];
    for (let k = 0; k <= 7; k++) this.twinkles.push([MT.RAY0 + k * MT.RAYSTEP + 0.1, k + 1]);
    for (const h of HOLD_TWINKLES) this.twinkles.push([h[0], h[1]]);
  }
  startShort() { this.clock = 0; this.emberT0 = Infinity; this.toIdle(); this.sweeps = [0.35]; }
  finish() { if (this.mode !== 'sting') return; this.clock = MT.END; this.toIdle(); }
  update(dt: number, reduced: boolean) {
    if (reduced) { if (this.mode === 'sting') this.finish(); return; }
    this.clock += dt;
    if (this.mode === 'sting') { if (this.clock >= MT.END) this.toIdle(); return; }
    if (this.mode === 'static') this.toIdle();
    if (this.clock >= this.nextSweep) { this.sweeps.push(this.clock); this.nextSweep = this.clock + this.rand(IDLE_SWEEP[0], IDLE_SWEEP[1]); }
    if (this.clock >= this.nextTwinkle) { this.twinkles.push([this.clock, this.rng.random(1, 8)]); this.nextTwinkle = this.clock + this.rand(IDLE_TWINKLE[0], IDLE_TWINKLE[1]); }
    this.sweeps = this.sweeps.filter((s) => this.clock - s <= 2);
    this.twinkles = this.twinkles.filter((t) => this.clock - t[0] <= 1);
  }
  sweepP() {
    const FROM = -60, TO = BD.word.w + BD.word.h * 0.55 + 20;
    for (const s0 of this.sweeps) { const p = FROM + (this.clock - s0) * SWEEP_SPEED; if (this.clock >= s0 && p <= TO) return p; }
    return null;
  }
  static stingScale(L: any) {
    let Ps = Math.max(1, Math.floor((L.H * 0.42) / BD.seal.h + 0.5));
    while (Ps > 1 && BD.seal.h * Ps > L.H * 0.62) Ps--;
    return Math.max(Ps, L.Ps);
  }
  sealGeom(L: any) {
    const t = this.clock, w = BD.seal.w, h = BD.seal.h, sting = this.mode === 'sting';
    const Ps = sting ? Brand.stingScale(L) : L.Ps;
    const sox = Math.floor((L.W - w * Ps) / 2 + 0.5), soy = Math.floor((L.H - h * Ps) / 2 + 0.5) - 4 * Ps;
    const u = sting ? easeOut3((t - MT.MOVE) / (MT.MOVE_END - MT.MOVE)) : 1;
    const s = Ps - Math.floor((Ps - L.Ps) * u + 0.5);
    const c0x = sox + (w * Ps) / 2, c0y = soy + (h * Ps) / 2, c1x = L.sealPX + (w * L.Ps) / 2, c1y = L.sealPY + (h * L.Ps) / 2;
    const ccx = c0x + (c1x - c0x) * u, ccy = c0y + (c1y - c0y) * u;
    const G: any = { x: Math.floor(ccx - (w * s) / 2 + 0.5), y: Math.floor(ccy - (h * s) / 2 + 0.5), s, jx: 0, jy: 0, Ps, sox, soy };
    if (u >= 1) { G.x = L.sealPX; G.y = L.sealPY; }
    const t0 = MT.CHARGE - FXc.trembleFrom;
    if (sting && t >= t0 && t < MT.FLASH) {
      const d = t - t0, D = MT.FLASH - t0, phase = 6 * d + (54 * d * d * d) / (3 * D * D), k = Math.floor(phase) % 4;
      G.jx = TREMBLE[k][0]; G.jy = TREMBLE[k][1];
    }
    return G;
  }
  px(g: Ctx, x: number, y: number, c: number[]) { g.fillStyle = rgb255(c, this.alphaMul); g.fillRect(Math.floor(x + 0.5), Math.floor(y + 0.5), 1, 1); }
  sparkle(g: Ctx, x: number, y: number, age: number) {
    const f = Math.floor((age * 60) / 3); if (f < 0 || f >= SPARK_SIZES.length) return;
    const s = SPARK_SIZES[f]; x = Math.floor(x + 0.5); y = Math.floor(y + 0.5);
    this.px(g, x, y, SPARK[0]);
    for (let i = 1; i <= s; i++) { const c = s > 1 ? SPARK[Math.min(3, i) - 1] : SPARK[1]; this.px(g, x + i, y, c); this.px(g, x - i, y, c); this.px(g, x, y + i, c); this.px(g, x, y - i, c); }
    if (s === 3) { this.px(g, x + 1, y + 1, SPARK[2]); this.px(g, x - 1, y + 1, SPARK[2]); this.px(g, x + 1, y - 1, SPARK[2]); this.px(g, x - 1, y - 1, SPARK[2]); }
  }
  emberColor(u: number) { return EMBER[Math.min(EMBER.length, Math.floor(u * EMBER.length) + 1) - 1]; }
  moteWarp(t: number) { const d = t - (MT.CHARGE - FXc.moteWarpAt); return d <= 0 ? t : t + FXc.moteWarp * d * d; }
  drawMotes(g: Ctx, t: number, cx: number, cy: number) {
    if (t < FXc.moteFrom || t >= MT.FLASH) return;
    const wt = this.moteWarp(t);
    for (const m of this.motes) {
      if (t < m.ts) continue;
      const tau = wt - this.moteWarp(m.ts), q = tau / m.period, cyc = Math.floor(q), u = q - cyc;
      const r = FXc.moteRim + (m.r0 - FXc.moteRim) * (1 - u) ** 1.4, a = m.a0 + cyc * 2.4 + m.spin * u * 2.6;
      const c = u > 0.8 ? SPARK[1] : u > 0.5 ? EMBER[2] : EMBER[3];
      this.px(g, cx + Math.cos(a) * r, cy + Math.sin(a) * r, c);
      if (m.big && u > 0.45) { const a2 = a - m.spin * 0.06; this.px(g, cx + Math.cos(a2) * (r + 2), cy + Math.sin(a2) * (r + 2), EMBER[3]); }
    }
  }
  hash(x: number) { const v = Math.sin(x * 12.9898) * 43758.5453; return v - Math.floor(v); }
  drawRunes(g: Ctx, t: number, cx: number, cy: number) {
    if (t < FXc.runeFrom || t >= FXc.runeTo) return;
    const env = Math.min(1, (t - FXc.runeFrom) / 0.25, (FXc.runeTo - t) / 0.3), tick = Math.floor(t * 14);
    for (let a = 1; a <= 3; a++) {
      if (this.hash(tick + a * 7) <= 0.12) continue;
      const R = 62 + a * 4, dir = a % 2 === 0 ? -1 : 1, start = a * 2.1 + dir * t * (0.7 + 0.2 * a), n = Math.floor((0.8 * R) / 2);
      for (let i = 0; i <= n; i++) {
        if (((i * 7) % 16) / 16 >= env) continue;
        const ang = start + (i * 2) / R, ca = Math.cos(ang), sa = Math.sin(ang);
        if (i % 6 === 3) { this.px(g, cx + ca * (R + 2), cy + sa * (R + 2), GOLD_L); this.px(g, cx + ca * (R + 1), cy + sa * (R + 1), GOLD_M); this.px(g, cx + ca * (R - 1), cy + sa * (R - 1), GOLD_D); }
        else if (i % 3 !== 2) this.px(g, cx + ca * R, cy + sa * R, i % 6 < 2 ? GOLD_M : GOLD_D);
      }
    }
  }
  drawRayIgnition(g: Ctx, t: number, cx: number, cy: number) {
    for (let k = 0; k <= 7; k++) {
      const age = t - (MT.RAY0 + k * MT.RAYSTEP);
      if (age < 0 || age >= FXc.rayLife) continue;
      const th = -Math.PI / 2 + (k * Math.PI) / 4, ux = Math.cos(th), uy = Math.sin(th), tip = BD.tips[k];
      const L = Math.sqrt((tip[0] - cx) ** 2 + (tip[1] - cy) ** 2);
      if (age < FXc.streak + 0.06) {
        const head = 12 + (L - 12) * Math.min(1, age / FXc.streak), fade = age > FXc.streak ? 4 : 10;
        for (let d = head - fade; d <= head; d += 2) if (d >= 12 && d <= L) this.px(g, cx + ux * d, cy + uy * d, d > head - 3 ? SPARK[1] : SPARK[2]);
      }
      for (let j = 0; j < 6; j++) {
        const sp = this.raySparks[k * 6 + j];
        if (age < sp.life) {
          const f = (1 - Math.exp(-3 * age)) / 3, ang = th + sp.da;
          const c = age < sp.life * 0.35 ? SPARK[0] : age < sp.life * 0.7 ? SPARK[2] : EMBER[3];
          this.px(g, tip[0] + Math.cos(ang) * sp.v * f, tip[1] + Math.sin(ang) * sp.v * f + 14 * age * age, c);
        }
      }
    }
  }
  // brand_fx.glsl: renderizado em uma célula por pixel do jogo e ampliado (o shader é constante dentro de cada célula)
  fxPass(g: Ctx, L: any, G: any, under: boolean, bgAmt: number, cx: number, cy: number) {
    const t = this.clock, tf = t - MT.FLASH, Ps = G.Ps;
    const u: Record<string, any> = { bayer: 'bayer', center: [cx, cy], bgCenter: [(L.W / 2 - G.sox) / Ps, (L.H * 0.44 - G.soy) / Ps], screenN: [L.W / Ps, L.H / Ps] };
    const ring = (n: string, cn: string, on: boolean, R = 0, th = 0, dens = 0, c = [0, 0, 0]) => { u[n] = on ? [R, th, dens, 1] : [0, 0, 0, 0]; u[cn] = [c[0] / 255, c[1] / 255, c[2] / 255]; };
    if (under) {
      u.bgAmt = bgAmt; const on = t >= 0.06 && t < 0.72, uu = easeOut3((t - 0.06) / 0.66);
      ring('ringA', 'colA', on, 150 - 100 * uu, 1.0, 0.15 + 0.6 * uu, [150, 104, 52]); ring('ringB', 'colB', false);
      if (bgAmt <= 0 && !on) return;
    } else {
      u.bgAmt = 0; const on1 = tf >= 0 && tf < 0.62, uu = tf / 0.62;
      const cols = [SPARK[0], SPARK[1], SPARK[2], EMBER[3]];
      ring('ringA', 'colA', on1, 10 + 320 * easeOut3(uu), 1.5 - 0.5 * uu, 1.05 - uu, cols[Math.min(3, Math.floor(uu * 4))]);
      const on2 = on1 && tf > 0.06, u2 = (tf - 0.06) / 0.56;
      ring('ringB', 'colB', on2, 6 + 220 * easeOut3(u2), 1.0, 0.7 - 0.7 * u2, EMBER[2]);
      if (!on1) return;
    }
    const nx0 = Math.floor(-G.sox / Ps) - 1, ny0 = Math.floor(-G.soy / Ps) - 1;
    const Nx = Math.ceil(L.W / Ps) + 3, Ny = Math.ceil(L.H / Ps) + 3;
    u.cell = 1; u.gridOrigin = [-nx0, -ny0];
    const c = this.g.shaderPass('fx', 'pal', 0, 0, Nx, Ny, u, [1, 1, 1, 1], Nx, Ny);
    if (!c) return;
    g.save(); g.setTransform(1, 0, 0, 1, 0, 0); g.imageSmoothingEnabled = false;
    g.drawImage(c, 0, 0, Nx, Ny, G.sox + nx0 * Ps, G.soy + ny0 * Ps, Nx * Ps, Ny * Ps); g.restore();
  }
  drawWord(g: Ctx, L: any, t: number, sweepP: number | null, reduced: boolean) {
    const word = this.g.img.wordmark as HTMLImageElement; if (!word) return;
    const quads = BD.cuts.length - 1, last = MT.WORD0 + (quads - 1) * MT.WORDSTEP + (BOUNCE.length * 2) / 60;
    const P = L.P;
    const shaded = (x: number, y: number, a: number, b: number, u: Record<string, any>) => {
      const c = this.g.shaderPass('word', 'wordmark', 0, 0, b - a, BD.word.h, { goldMask: 'wordGold', texSize: [BD.word.w, BD.word.h], ...u }, [1, 1, 1, this.alphaMul], b - a, BD.word.h, [a / BD.word.w, 0, b / BD.word.w, 1]);
      if (!c) { g.globalAlpha = this.alphaMul; g.drawImage(word, a, 0, b - a, BD.word.h, x, y, b - a, BD.word.h); g.globalAlpha = 1; return; }
      g.drawImage(c, 0, 0, b - a, BD.word.h, x, y, b - a, BD.word.h);
    };
    if (this.mode !== 'sting' || t >= last) {
      if (sweepP !== null && !reduced) shaded(L.wordX, L.wordY, 0, BD.word.w, { origin: [L.wordX, L.wordY], sweepP, whiteMix: 0, boost: 0 });
      else { g.globalAlpha = this.alphaMul; g.drawImage(word, L.wordX, L.wordY); g.globalAlpha = 1; }
      return;
    }
    for (let i = 0; i < quads; i++) {
      const t0 = MT.WORD0 + i * MT.WORDSTEP, f = Math.floor(((t - t0) * 60) / 2);
      if (f < 0) continue;
      const dy = BOUNCE[f] ?? 0, a = BD.cuts[i], b = BD.cuts[i + 1];
      shaded(L.wordX + a, L.wordY + dy, a, b, { origin: [L.wordX, L.wordY + dy], sweepP: sweepP ?? -10000, whiteMix: f < 2 ? 0.65 : 0, boost: f >= 2 && f < 4 ? 1 : 0 });
      if (f >= 4 && f < 9) {
        const base = L.wordY + BD.word.h - 2, k = f - 4, w = b - a;
        for (const s of [-1, 1]) for (let j = 0; j <= 1; j++) {
          const x = L.wordX + a + Math.floor(w / 2) + s * (Math.floor(w / 2) + 1 + k * 2 + j * 2);
          this.px(g, x, base - Math.floor(k / 2) - j, k > 2 ? EMBER[4] : DUST);
        }
      }
    }
    void P;
  }
  draw(g: Ctx, alpha: number, bgAmt: number, reduced: boolean) {
    const W = this.g.W, H = this.g.H;
    const L = Brand.layout(W, H); this.L = L;
    const t = this.clock, sting = this.mode === 'sting' && !reduced;
    this.alphaMul = alpha;
    const G = this.sealGeom(L);
    if (!sting) { G.x = L.sealPX; G.y = L.sealPY; G.s = L.Ps; G.jx = 0; G.jy = 0; }
    this.G = G;
    const cx = BD.seal.cx, cy = BD.seal.cy;
    const lastLetter = MT.WORD0 + (BD.cuts.length - 2) * MT.WORDSTEP + 4 / 60;
    const shake = sting && t - lastLetter >= 0 && t - lastLetter < 3 / 60 ? L.P : 0;
    g.imageSmoothingEnabled = false;
    if (sting) {
      this.fxPass(g, L, G, true, bgAmt, cx, cy);
      g.save(); g.translate(G.sox, G.soy); g.scale(G.Ps, G.Ps);
      this.drawMotes(g, t, cx, cy); this.drawRunes(g, t, cx, cy);
      if (t >= MT.CHARGE && t < MT.FLASH) for (const c of this.converge) {
        const u = (t - c.t0) / (MT.FLASH - c.t0);
        if (u >= 0 && u < 1) { const rr = c.r0 * (1 - u * u), ca = Math.cos(c.a), sa = Math.sin(c.a); this.px(g, cx + ca * rr, cy + sa * rr, u > 0.6 ? SPARK[1] : SPARK[2]); this.px(g, cx + ca * (rr + 3), cy + sa * (rr + 3), EMBER[3]); }
      }
      g.restore();
    }
    const sweepP = reduced ? null : this.sweepP();
    const animSeal = sting && t < MT.FLASH + 0.4;
    let sealDone = false;
    if (animSeal || sweepP !== null) {
      const c = this.g.shaderPass('seal', 'sealData', 0, 0, BD.seal.w, BD.seal.h, {
        T: animSeal ? t : 99, pal: 'pal', trevScale: BD.seal.trevScale, texSize: [BD.seal.w, BD.seal.h], tRay0: MT.RAY0, tRayStep: MT.RAYSTEP, tCharge: MT.CHARGE, tFlash: MT.FLASH,
        origin: [(L.sealPX - L.ox) / L.P, (L.sealPY - L.oy) / L.P], pxScale: L.Ps / L.P, sweepP: sweepP ?? -10000 }, [1, 1, 1, alpha], BD.seal.w, BD.seal.h);
      if (c) { g.drawImage(c, 0, 0, BD.seal.w, BD.seal.h, G.x + G.jx * G.s, G.y + shake + G.jy * G.s, BD.seal.w * G.s, BD.seal.h * G.s); sealDone = true; }
    }
    if (!sealDone && (!sting || t >= MT.FLASH) && this.g.img.seal) { g.globalAlpha = alpha; g.drawImage(this.g.img.seal as HTMLImageElement, G.x, G.y + shake, BD.seal.w * G.s, BD.seal.h * G.s); g.globalAlpha = 1; }
    g.save(); g.translate(G.x, G.y + shake); g.scale(G.s, G.s);
    if (!reduced) for (const tw of this.twinkles) { const tip = BD.tips[tw[1] - 1]; this.sparkle(g, tip[0], tip[1], t - tw[0]); }
    if (sting && t < MT.FLASH) this.drawRayIgnition(g, t, cx, cy);
    g.restore();
    g.save(); g.translate(L.ox, L.oy + shake); g.scale(L.P, L.P);
    if (!sting || t >= MT.WORD0 - 0.01) this.drawWord(g, L, t, sweepP, reduced);
    if (!reduced && t >= this.emberT0) {
      const sealTop = (L.sealPY - L.oy) / L.P, yA = sealTop + ((BD.seal.h * L.Ps) / L.P) * 0.6, yB = BD.word.h + 20;
      for (const e of this.embers) {
        let te = t - this.emberT0 - e.t0;
        if (te < 0) continue;
        te = te % (e.life + 0.4);
        if (te <= e.life && Math.sin(e.ph + te * e.fl) >= -0.6) {
          const u = te / e.life;
          this.px(g, e.x0 + Math.sin(e.ph + te * 1.7) * e.amp, yA + e.yn * (yB - yA) + e.vy * te, this.emberColor(0.25 + u * 0.75));
        }
      }
    }
    g.restore();
    if (sting) {
      const tf = t - MT.FLASH;
      const ccx = (G.x + cx * G.s - G.sox) / G.Ps, ccy = (G.y + cy * G.s - G.soy) / G.Ps;
      this.fxPass(g, L, G, false, 0, ccx, ccy);
      g.save(); g.translate(G.sox, G.soy); g.scale(G.Ps, G.Ps);
      if (tf >= 0) for (const b of this.burst) {
        if (tf > b.life) continue;
        const f = (1 - Math.exp(-2.2 * tf)) / 2.2, x = cx + b.vx * f, y = cy + b.vy * f + 26 * tf * tf, c = this.emberColor(tf / b.life);
        this.px(g, x, y, c);
        if (b.big && tf < b.life * 0.5) { this.px(g, x + 1, y, c); this.px(g, x, y + 1, c); this.px(g, x + 1, y + 1, c); }
      }
      g.restore();
      if (tf >= 0 && tf < PULSE.dur) {
        const a = PULSE.alpha * (1 - tf / PULSE.dur) ** 2;
        g.globalCompositeOperation = 'lighter'; g.fillStyle = `rgba(255,240,209,${a})`; g.fillRect(0, 0, W, H); g.globalCompositeOperation = 'source-over';
      }
    }
    this.alphaMul = 1;
  }
}

// ===================================================================== components/Menu.lua
class MenuScene {
  g: Game; visible = false; osdTimer = 99; candleFlare = 0; sting = false; stingFx = { electric: false, impact: false };
  alphaBg = 1; alphaTitle = 1; alphaButtons: Record<string, number> = {}; offY: Record<string, number> = {};
  hover = ''; hoverScale: Record<string, number> = {}; motes: any[] = []; embers: any[] = []; emberTimer = 0;
  parX = 0; parY = 0; tf: any = null; glowA: HTMLCanvasElement | null = null; glowB: HTMLCanvasElement | null = null;
  cards = [{ ax: 0.16, ay: 0.3, phase: 0, freqY: 0.7, freqR: 0.5, flip: 0, flipTo: 0, face: null as HTMLImageElement | null },
    { ax: 0.84, ay: 0.3, phase: 1.7, freqY: 0.5, freqR: 0.6, flip: 0, flipTo: 0, face: null as HTMLImageElement | null }];
  constructor(g: Game) {
    this.g = g;
    for (let i = 1; i <= 26; i++) this.motes.push({ ax: Math.random(), ay: Math.random(), speed: 0.004 + Math.random() * 0.01, drift: (Math.random() - 0.5) * 0.006, phase: Math.random() * TAU, size: 1 + (Math.random() < 0.5 ? 1 : 2), shaft: i <= 16 });
    for (const b of BUTTON_ORDER) { this.alphaButtons[b] = 1; this.offY[b] = 0; this.hoverScale[b] = 1; }
  }
  makeGlow() {
    const N = 128, c = document.createElement('canvas'); c.width = c.height = N; const x = c.getContext('2d')!, id = x.createImageData(N, N);
    for (let py = 0; py < N; py++) for (let pxx = 0; pxx < N; pxx++) {
      const dx = (pxx - N / 2) / (N / 2), dy = (py - N / 2) / (N / 2), v = Math.max(0, 1 - Math.sqrt(dx * dx + dy * dy)) ** 2, i = (py * N + pxx) * 4;
      id.data.set([255, 255, 255, Math.round(v * 255)], i);
    }
    x.putImageData(id, 0, 0);
    this.glowA = tinted(c, [1, 0.55, 0.18]); this.glowB = tinted(c, [1, 0.82, 0.45]);
  }
  get reduced() { return this.g.reduced; }
  clock() { return this.reduced ? 0 : this.g.time; }
  enterWithIntro(full: boolean) {
    this.visible = true; this.osdTimer = 0; this.candleFlare = 1;
    if (full) {
      this.sting = true; this.stingFx = { electric: false, impact: false };
      this.g.brand.startSting(); this.applyStingTimeline();
      this.g.hooks.music(true);
      return;
    }
    this.sting = false; this.g.brand.startShort(); this.settle(); this.g.hooks.music(true);
  }
  settle() { this.alphaBg = 1; this.alphaTitle = 1; for (const b of BUTTON_ORDER) { this.alphaButtons[b] = 1; this.offY[b] = 0; } }
  isIntroPlaying() { return this.sting && this.g.brand.isPlaying(); }
  skipIntro() { if (!this.isIntroPlaying()) return false; this.g.brand.finish(); this.sting = false; this.settle(); return true; }
  applyStingTimeline() {
    if (!this.sting) return;
    const t = this.g.brand.stingTime();
    if (t === Infinity) { this.sting = false; this.settle(); return; }
    this.alphaBg = smooth((t - MT.FLASH) / MT.BG_FADE); this.alphaTitle = 1;
    BUTTON_ORDER.forEach((name, i) => { const u = (t - MT.BUTTONS - i * MT.BUTTON_STEP) / MT.BUTTON_DUR; this.alphaButtons[name] = smooth(u); this.offY[name] = 12 * (1 - backOut(u)); });
    if (!this.stingFx.electric && t >= MT.ELECTRIC) { this.stingFx.electric = true; this.g.sfx('boot-electric', 0.45); }
    if (!this.stingFx.impact && t >= MT.FLASH) { this.stingFx.impact = true; this.g.sfx('boot-impact', 0.6); }
  }
  buttonsReady() { return BUTTON_ORDER.every((b) => this.alphaButtons[b] > 0.1); }
  buttonRects() {
    // largura como no jogo (min(250, 25% da largura)); no celular em pé o jogo cortaria os rótulos ("CON..."), então o site usa 62%
    const { W, H } = this.g, [startY, spacing, bh] = Brand.buttonColumn(H), bw = Math.min(250, W * (W / H < 0.8 ? 0.62 : 0.25));
    return BUTTON_ORDER.map((name, i) => ({ name, x: W / 2 - bw / 2, y: startY + spacing * i, w: bw, h: bh, size: name === 'play' ? 24 : 20 }));
  }
  cardRects() {
    const { W, H } = this.g, cw = Math.floor(W * 0.12), ch = Math.floor(cw * 1.5);
    return this.cards.map((c) => ({ x: W * c.ax - cw / 2, y: H * c.ay - ch / 2 - 14, w: cw, h: ch + 28 }));
  }
  update(dt: number) {
    this.g.brand.update(dt, this.reduced);
    if (this.sting) this.applyStingTimeline();
    const k = 1 - Math.exp(-14 * dt);
    for (const b of BUTTON_ORDER) this.hoverScale[b] += ((this.hover === b ? 1.05 : 1) - this.hoverScale[b]) * k;
    for (const c of this.cards) { const d = c.flipTo - c.flip; c.flip += Math.sign(d) * Math.min(Math.abs(d), dt / 0.55); }
    this.osdTimer += dt;
    this.candleFlare = Math.max(0, this.candleFlare - dt * 0.9);
    if (this.reduced) { this.embers = []; this.parX = this.parY = 0; return; }
    const tf = this.tf;
    for (const m of this.motes) {
      m.ay -= m.speed * dt * 10; m.ax += m.drift * dt * 10;
      if (m.shaft && tf) {
        const [x0, hw] = this.shaftBounds(tf, m.ay);
        if (m.ay < 0.03) { m.ay = 0.72; m.ax = x0 + (Math.random() - 0.5) * 2 * hw; }
        if (m.ax < x0 - hw) { m.ax = x0 - hw; m.drift = Math.abs(m.drift); } else if (m.ax > x0 + hw) { m.ax = x0 + hw; m.drift = -Math.abs(m.drift); }
      } else {
        if (m.ay < -0.02) { m.ay = 1.02; m.ax = Math.random(); }
        if (m.ax < -0.02) m.ax = 1.02; else if (m.ax > 1.02) m.ax = -0.02;
      }
    }
    const { W, H } = this.g, tx = Math.max(-1, Math.min(1, (this.g.mouse[0] / W - 0.5) * 2)), ty = Math.max(-1, Math.min(1, (this.g.mouse[1] / H - 0.5) * 2)), kk = Math.min(1, dt * 4);
    this.parX += (tx - this.parX) * kk; this.parY += (ty - this.parY) * kk;
    this.emberTimer -= dt;
    const flare = this.candleFlare;
    if (this.emberTimer <= 0 && this.embers.length < (flare > 0.3 ? 18 : 10)) {
      this.emberTimer = (0.28 + Math.random() * 0.5) * (1 - 0.6 * flare);
      this.embers.push({ candle: Math.random() < 0.5 ? 0 : 1, offX: (Math.random() - 0.5) * 10, t: 0, life: 1.4 + Math.random() * 1.2, sway: Math.random() * TAU });
    }
    for (let i = this.embers.length - 1; i >= 0; i--) { const e = this.embers[i]; e.t += dt; if (e.t >= e.life) this.embers.splice(i, 1); }
  }
  shaftBounds(tf: any, ay: number) {
    const W = this.g.W, k = clamp01((ay - 0.04) / (0.72 - 0.04));
    const sway = this.reduced ? 0 : (noise(this.clock() * 0.35, 3.1) - 0.5) * 0.02 * k;
    return [(tf.ox + (0.5 + sway) * tf.dw) / W, ((0.012 + (0.17 - 0.012) * k) * tf.dw) / W];
  }
  draw(g: Ctx) {
    if (!this.visible) return;
    this.drawBackground(g); this.drawMotes(g); this.drawEmbers(g); this.drawVignette(g); this.drawCards(g);
    if (this.alphaTitle > 0.02) this.g.brand.draw(g, this.alphaTitle, this.sting ? 1 - this.alphaBg : 0, this.reduced);
    for (const r of this.buttonRects()) {
      if ((this.alphaButtons[r.name] ?? 1) <= 0.1) continue;
      this.drawButton(g, r, this.offY[r.name] || 0);
    }
    this.drawFooter(g); this.drawOsd(g);
  }
  drawBackground(g: Ctx) {
    const { W, H } = this.g, t = this.clock(), a = this.alphaBg;
    const seq = ['menu', 'menu_normal', 'menu', 'menu_1', 'menu_2', 'menu_normal', 'menu'];
    const img = (this.g.img[seq[Math.floor(t * 10) % 7]] || this.g.img.menu) as HTMLImageElement;
    if (!img) return;
    const iw = img.width, ih = img.height, s = Math.max(W / iw, H / ih) * 1.07, dw = iw * s, dh = ih * s;
    const slX = (dw - W) / 2, slY = (dh - H) / 2;
    const offX = Math.max(-slX, Math.min(slX, this.parX * -14)), offY = Math.max(-slY, Math.min(slY, this.parY * -8));
    const ox = (W - dw) / 2 + offX, oy = (H - dh) / 2 + offY;
    g.imageSmoothingEnabled = false; g.drawImage(img, ox, oy, dw, dh);
    g.fillStyle = rgba(PAL.INK, 0.3); g.fillRect(0, 0, W, H);
    const tf = { scale: s, ox, oy, dw, dh }; this.tf = tf;
    // Menu:_drawPageFlutter
    if (!this.reduced) {
      const n = noise(Math.floor(t * 8) * 0.37, 5.5), lift = n > 0.8 ? 2 : n > 0.7 ? 1 : 0;
      if (lift) { const sx = dw / iw; g.globalAlpha = a; g.drawImage(this.g.img.menu as HTMLImageElement, 250, 168, 42, 20, Math.floor(ox + 250 * sx), Math.floor(oy + (168 - lift) * (dh / ih)), 42 * sx, 20 * (dh / ih)); g.globalAlpha = 1; }
    }
    // Menu:_drawCandleGlow
    g.globalCompositeOperation = 'lighter';
    [[0.209, 0.44, 0], [0.77, 0.44, 3.7]].forEach(([xr, yr, ph]) => {
      const x = ox + xr * dw, y = oy + yr * dh, fl = this.candleFlare;
      const flick = (0.7 + 0.3 * noise(t * 5.5, ph)) * (1 + 0.6 * fl), r = dw * 0.075 * (0.92 + 0.14 * noise(t * 2.8, ph + 9)) * (1 + 0.35 * fl);
      if (this.glowA) { g.globalAlpha = Math.min(1, 0.26 * flick * a); g.drawImage(this.glowA, x - r, y - r, r * 2, r * 2); }
      if (this.glowB) { g.globalAlpha = Math.min(1, 0.3 * flick * a); g.drawImage(this.glowB, x - r / 2, y - r / 2, r, r); }
    });
    g.globalAlpha = 1;
    // Menu:_drawLightShaft
    const breath = this.reduced ? 0.5 : 0.5 + 0.5 * noise(t * 0.8, 11.7), pxs = dh / 256, yt = Math.floor(0.04 * 256), yb = Math.floor(0.72 * 256);
    for (let step = 1; step <= 3; step++) {
      const shrink = 1 - (step - 1) * 0.33, al = (0.03 + 0.012 * breath + 0.03 * this.candleFlare) * a;
      g.fillStyle = `rgba(255,219,140,${al})`;
      for (let iy = yt; iy <= yb; iy += 2) {
        const [x0, hw] = this.shaftBounds(tf, iy / 256), half = Math.max(1, Math.floor((hw * W * shrink) / pxs)), cxp = Math.floor((x0 * W) / pxs);
        const y0 = Math.floor(oy + iy * pxs), y1 = Math.floor(oy + (iy + 2) * pxs);
        g.fillRect((cxp - half) * pxs, y0, half * 2 * pxs, y1 - y0);
      }
    }
    g.globalCompositeOperation = 'source-over';
    const flick = 0.03 + 0.028 * noise(t * 1.9, 7.3);
    g.fillStyle = `rgba(255,179,87,${flick * a})`; g.fillRect(0, 0, W, H);
    // Menu:_drawSmokeLayer
    const par = this.parX * -26, ts = t + 400;
    [{ i: 'smoke1t', yr: 0.8, sp: 9, sc: 0.55, al: 0.09, seed: 0 }, { i: 'smoke2t', yr: 0.88, sp: 14, sc: 0.7, al: 0.12, seed: 400 }, { i: 'smoke3t', yr: 0.7, sp: 6, sc: 0.45, al: 0.06, seed: 800 }].forEach((w) => {
      const im = this.g.img[w.i] as HTMLCanvasElement; if (!im) return;
      const sc = (W * w.sc) / im.width, span = W + im.width * sc, x = ((ts * w.sp + w.seed) % span) - im.width * sc + par, y = H * w.yr + Math.sin(ts * 0.35 + w.seed) * 12;
      g.globalAlpha = w.al * a; g.imageSmoothingEnabled = true; g.drawImage(im, x, y - (im.height * sc) / 2, im.width * sc, im.height * sc); g.imageSmoothingEnabled = false;
    });
    g.globalAlpha = 1;
    if (a < 1) { g.fillStyle = `rgba(0,0,0,${1 - a})`; g.fillRect(0, 0, W, H); }
  }
  drawMotes(g: Ctx) {
    const a = this.alphaBg; if (a <= 0.05) return;
    const { W, H } = this.g, t = this.clock();
    for (const m of this.motes) { let tw = 0.25 + 0.2 * Math.sin(t * 1.7 + m.phase); if (m.shaft) tw += 0.18; g.fillStyle = rgba(PAL.AGED_GOLD_LIGHT, tw * a); g.fillRect(Math.floor(m.ax * W), Math.floor(m.ay * H), m.size, m.size); }
  }
  drawEmbers(g: Ctx) {
    const tf = this.tf; if (!tf || this.reduced) return;
    const a0 = this.alphaBg; if (a0 <= 0.05) return;
    const A = [[0.209, 0.44], [0.77, 0.44]];
    for (const e of this.embers) {
      const an = A[e.candle], k = e.t / e.life;
      const x = tf.ox + an[0] * tf.dw + e.offX + Math.sin(e.t * 3 + e.sway) * 6 * k, y = tf.oy + an[1] * tf.dh - k * 70;
      g.fillStyle = rgba([1, 0.85 - 0.45 * k, 0.3 - 0.2 * k], (1 - k) * 0.8 * a0);
      const s = k < 0.15 ? 2 : 1; g.fillRect(Math.floor(x), Math.floor(y), s, s);
    }
  }
  drawVignette(g: Ctx) {
    const { W, H } = this.g, t = this.clock(), breath = this.reduced ? 0.5 : 0.5 + 0.5 * Math.sin(t * (TAU / 7));
    const base = (0.1 + 0.06 * breath) * this.alphaBg, inset = Math.floor(Math.min(W, H) * 0.045);
    for (let step = 0; step <= 2; step++) {
      const a = base * (1 - step * 0.33), d = inset * step;
      g.fillStyle = `rgba(0,0,0,${a})`;
      g.fillRect(d, d, W - d * 2, inset); g.fillRect(d, H - d - inset, W - d * 2, inset);
      g.fillRect(d, d + inset, inset, H - d * 2 - inset * 2); g.fillRect(W - d - inset, d + inset, inset, H - d * 2 - inset * 2);
    }
  }
  // Menu:_drawFloatingCards. No site, clicar vira a carta e mostra uma carta real do jogo (renderizada pelo próprio jogo)
  drawCards(g: Ctx) {
    const { W, H } = this.g, t = this.clock(), a = this.alphaBg; if (a <= 0.05) return;
    const cw = Math.floor(W * 0.12), ch = Math.floor(cw * 1.5);
    for (const c of this.cards) {
      const cx = W * c.ax, cy = H * c.ay + Math.sin(t * c.freqY + c.phase) * 14, rot = Math.sin(t * c.freqR + c.phase) * 0.1;
      const f = c.flip, sxf = Math.abs(Math.cos(f * Math.PI));
      if (f < 0.5 || !c.face) {
        g.save(); g.translate(cx, cy); g.scale(Math.max(0.02, sxf), 1); g.translate(-cx, -cy);
        this.g.cardBack(g, cx, cy, cw, ch, { alpha: 0.95 * a, rot }); g.restore();
      } else {
        g.save(); g.translate(cx, cy - 3); g.rotate(rot); g.scale(Math.max(0.02, sxf), 1);
        g.globalAlpha = 0.95 * a; g.imageSmoothingEnabled = false; g.drawImage(c.face, -cw / 2, -ch / 2, cw, ch); g.restore(); g.globalAlpha = 1;
      }
    }
  }
  drawButton(g: Ctx, r: { name: string; x: number; y: number; w: number; h: number; size: number }, offY: number) {
    const hovered = this.hover === r.name, s = this.hoverScale[r.name] || 1;
    let { x, y } = r; const { w, h } = r; y += offY;
    g.save();
    if (s !== 1) { g.translate(x + w / 2, y + h / 2); g.scale(s, s); g.translate(-(x + w / 2), -(y + h / 2)); }
    if (hovered) {
      g.fillStyle = 'rgba(0,0,0,0.45)'; g.fillRect(x + 3, y + 3, w, h);
      g.fillStyle = rgba([1, 0.82, 0.38]); g.fillRect(x, y, w, Math.floor(h / 2));
      g.fillStyle = rgba([0.86, 0.55, 0.12]); g.fillRect(x, y + Math.floor(h / 2), w, Math.ceil(h / 2));
      g.strokeStyle = rgba([0.1, 0.07, 0.04], 0.9); g.lineWidth = 1; g.strokeRect(x + 0.5, y + 0.5, w - 1, h - 1);
    } else {
      g.fillStyle = 'rgba(13,10,8,0.55)'; g.fillRect(x, y, w, h);
      g.fillStyle = rgba([AMBER[0] * 0.6, AMBER[1] * 0.6, AMBER[2] * 0.6], 0.85); g.fillRect(x, y, 3, h);
      g.fillStyle = rgba([AMBER[0] * 0.5, AMBER[1] * 0.5, AMBER[2] * 0.5], 0.45); g.fillRect(x, y + h - 1, w, 1);
    }
    let text = this.g.S.buttons[r.name] || r.name, size = r.size;
    const maxW = w - 36;
    font(g, size); while (size > 8 && g.measureText(text).width > maxW) { size--; font(g, size); }
    if (g.measureText(text).width > maxW) { while (text.length > 1 && g.measureText(text + '...').width > maxW) text = text.slice(0, -1); text += '...'; }
    const f = font(g, size), ty = y + Math.floor((h - f.h) / 2);
    if (hovered) { g.fillStyle = rgba([0.12, 0.08, 0.04]); print(g, text, x + 18, ty, f.asc); }
    else { g.fillStyle = 'rgba(0,0,0,0.8)'; print(g, text, x + 19, ty + 1, f.asc); g.fillStyle = rgba([0.92, 0.86, 0.72]); print(g, text, x + 18, ty, f.asc); }
    g.restore();
    if (hovered) this.buttonCrtFx(g, x, y, w, h);
  }
  buttonCrtFx(g: Ctx, x: number, y: number, w: number, h: number) {
    const t = this.g.time, still = this.reduced;
    if (this.g.crt.enabled && this.g.crtOn) {
      const bandH = 10, sweepY = y - bandH + ((t * (h + bandH)) / 0.9) % (h + bandH);
      g.save(); g.beginPath(); g.rect(x, y, w, h); g.clip();
      g.fillStyle = 'rgba(255,255,235,0.10)'; g.fillRect(x, sweepY, w, bandH);
      g.fillStyle = 'rgba(255,255,235,0.05)'; g.fillRect(x, sweepY - 4, w, bandH + 8); g.restore();
    }
    const span = w + 24, gx = x - 12 + (still ? 0 : Math.floor(((t * 160) % span) / 4) * 4), gy = y - 1;
    g.fillStyle = 'rgba(255,247,217,0.95)'; g.fillRect(gx, gy, 4, 2);
    g.fillStyle = 'rgba(255,230,140,0.55)'; g.fillRect(gx - 8, gy, 8, 1); g.fillRect(gx + 4, gy, 4, 1);
    const pulse = 0.35 + 0.2 * Math.sin(t * 5); g.lineWidth = 1;
    g.strokeStyle = `rgba(242,199,82,${pulse * 0.5})`; g.strokeRect(x - 1.5, y - 1.5, w + 3, h + 3);
    g.strokeStyle = `rgba(242,199,82,${pulse * 0.22})`; g.strokeRect(x - 3.5, y - 3.5, w + 7, h + 7);
    if (still || Math.floor(t * 2.4) % 2 === 0) {
      const ax = x - 18, ay = y + h / 2;
      g.fillStyle = 'rgba(0,0,0,0.7)'; g.beginPath(); g.moveTo(ax + 1, ay - 5); g.lineTo(ax + 1, ay + 7); g.lineTo(ax + 11, ay + 1); g.fill();
      g.fillStyle = rgba(AMBER, 0.95); g.beginPath(); g.moveTo(ax, ay - 6); g.lineTo(ax, ay + 6); g.lineTo(ax + 10, ay); g.fill();
    }
  }
  // rodapé no lugar e no estilo do jogo (_drawVersionFooter / _drawProfilePlaque): privacidade à esquerda, Steam à direita
  footer = { priv: [0, 0, 0, 0], wish: [0, 0, 0, 0] };
  drawFooter(g: Ctx) {
    const a = this.alphaBg * 0.9; if (a <= 0.05) return;
    const { W, H } = this.g, f = font(g, 10), y = H - 24;
    const p = this.g.S.privacy, wsh = this.g.S.wish, pw = g.measureText(p).width, ww = g.measureText(wsh).width;
    const put = (s: string, x: number) => { g.fillStyle = `rgba(0,0,0,${0.75 * a})`; print(g, s, x + 1, y + 1, f.asc); g.fillStyle = rgba(PAL.PARCHMENT, a); print(g, s, x, y, f.asc); };
    put(p, 26); put(wsh, W - 26 - ww);
    this.footer = { priv: [26, y, pw, f.h], wish: [W - 26 - ww, y, ww, f.h] };
  }
  drawOsd(g: Ctx) {
    const t = this.osdTimer; let a = 1; if (t > 3.5) a = Math.max(0, 1 - (t - 3.5) / 0.8);
    a *= this.alphaBg; if (a <= 0.02) return;
    const B = this.g.boot, W = this.g.W, tag = this.g.S.osd;
    B.osdText(g, tag, W - B.osdW(g, tag) - 26, 20, a);
    const d = new Date(), clock = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
    B.osdText(g, clock, W - B.osdW(g, clock) - 26, 44, a * 0.85);
  }
}
