// Clima do herói, por bioma: folhas, chuva com raio, brasas, neve, esporos, morcegos (e poeira de luz do jogo).
// Pixel art: tudo desenhado em grade inteira, sem suavização. Para quando o herói sai da tela ou a aba some.
export type Style = 'leaf' | 'rain' | 'ember' | 'snow' | 'spore' | 'bats' | 'eclipse';

type P = { x: number; y: number; vx: number; vy: number; t: number; k: number; life: number };

const img = (src: string) => { const i = new Image(); i.src = src; return i; };

export class Weather {
  private ctx: CanvasRenderingContext2D;
  private ps: P[] = [];
  private style: Style = 'leaf';
  private color = '#fff';
  private raf = 0;
  private last = 0;
  private flash = 0;
  private nextBolt = 4;
  private visible = true;
  private scale = 2;
  private sprites: Record<string, HTMLImageElement[]> = {};
  constructor(private cv: HTMLCanvasElement) {
    this.ctx = cv.getContext('2d')!;
    const io = new IntersectionObserver(([e]) => { this.visible = e.isIntersecting; this.kick(); });
    io.observe(cv);
    document.addEventListener('visibilitychange', () => this.kick());
    addEventListener('resize', () => this.resize());
    this.resize();
  }
  load(base: string) {
    const L = (n: string, c: number) => Array.from({ length: c }, (_, i) => img(`${base}/${n}_${i}.png`));
    this.sprites = { leaf: L('leaf', 3), snow: L('snowflake', 2), spore: L('spore', 2), bat: L('bat', 4), ember: [img(`${base}/ember.png`)], rain: [img(`${base}/raindrop.png`)] };
  }
  private resize() {
    const r = this.cv.getBoundingClientRect();
    this.scale = r.width >= 900 ? 3 : 2;
    // canvas na resolução "lógica" da pixel art; o CSS estica com pixelated
    this.cv.width = Math.max(1, Math.round(r.width / this.scale));
    this.cv.height = Math.max(1, Math.round(r.height / this.scale));
    this.ctx.imageSmoothingEnabled = false;
  }
  set(style: Style, color: string) {
    this.style = style; this.color = color; this.ps = []; this.flash = 0;
    const n = { leaf: 26, rain: 110, ember: 46, snow: 70, spore: 36, bats: 7, eclipse: 40 }[style];
    for (let i = 0; i < n; i++) this.ps.push(this.spawn(true));
    this.kick();
  }
  private spawn(anywhere = false): P {
    const W = this.cv.width, H = this.cv.height, s = this.style;
    const p: P = { x: Math.random() * W, y: anywhere ? Math.random() * H : -10, vx: 0, vy: 0, t: Math.random() * 10, k: Math.floor(Math.random() * 3), life: 1 };
    if (s === 'leaf') { p.vx = 6 + Math.random() * 10; p.vy = 8 + Math.random() * 10; }
    if (s === 'rain') { p.vx = -18; p.vy = 150 + Math.random() * 60; }
    if (s === 'snow') { p.vx = -3 + Math.random() * 6; p.vy = 6 + Math.random() * 10; }
    if (s === 'ember' || s === 'eclipse') { p.y = anywhere ? Math.random() * H : H + 4; p.vx = -4 + Math.random() * 8; p.vy = -(8 + Math.random() * 16); p.life = Math.random(); }
    if (s === 'spore') { p.y = anywhere ? Math.random() * H : H * (0.4 + Math.random() * 0.6); p.vx = -2 + Math.random() * 4; p.vy = -(2 + Math.random() * 5); p.life = Math.random(); }
    if (s === 'bats') { p.x = anywhere ? Math.random() * W : -20; p.y = H * (0.08 + Math.random() * 0.4); p.vx = 22 + Math.random() * 18; p.vy = 0; }
    return p;
  }
  private kick() {
    const run = this.visible && !document.hidden && !matchMedia('(prefers-reduced-motion: reduce)').matches && !document.body.classList.contains('reduced');
    cancelAnimationFrame(this.raf);
    if (run) { this.last = performance.now(); this.raf = requestAnimationFrame((t) => this.frame(t)); }
    else this.draw(0); // um quadro parado, para o céu não ficar vazio
  }
  private frame(now: number) {
    const dt = Math.min(0.05, (now - this.last) / 1000); this.last = now;
    this.draw(dt);
    this.raf = requestAnimationFrame((t) => this.frame(t));
  }
  private draw(dt: number) {
    const c = this.ctx, W = this.cv.width, H = this.cv.height, s = this.style;
    c.clearRect(0, 0, W, H);
    if (s === 'rain') {
      this.nextBolt -= dt;
      if (this.nextBolt <= 0) { this.flash = 1; this.nextBolt = 5 + Math.random() * 7; this.bolt(); }
      if (this.flash > 0) { c.fillStyle = `rgba(200,210,255,${this.flash * 0.35})`; c.fillRect(0, 0, W, H); this.flash = Math.max(0, this.flash - dt * 2.5); if (this.boltPath && this.flash > 0.55) this.drawBolt(); }
    }
    for (const p of this.ps) {
      p.t += dt; p.x += p.vx * dt; p.y += p.vy * dt;
      if (s === 'leaf') p.x += Math.sin(p.t * 2 + p.k) * 0.4;
      if (s === 'snow') p.x += Math.sin(p.t + p.k) * 0.2;
      if (s === 'spore') p.x += Math.sin(p.t * 1.5 + p.k) * 0.15;
      const out = p.y > H + 12 || p.y < -14 || p.x > W + 24 || p.x < -24;
      if (out) Object.assign(p, this.spawn());
      const x = Math.round(p.x), y = Math.round(p.y);
      const spr = this.sprites;
      if (s === 'leaf') this.blit(spr.leaf?.[p.k % 3], x, y) || this.dot(x, y, 2, this.color);
      else if (s === 'rain') this.blit(spr.rain?.[0], x, y) || (c.fillStyle = '#9fb3e6aa', c.fillRect(x, y, 1, 5));
      else if (s === 'snow') this.blit(spr.snow?.[p.k % 2], x, y) || this.dot(x, y, 1 + (p.k % 2), '#eef4ff');
      else if (s === 'ember' || s === 'eclipse') { c.globalAlpha = 0.5 + 0.5 * Math.abs(Math.sin(p.t * 3 + p.k)); this.blit(s === 'ember' ? spr.ember?.[0] : undefined, x, y) || this.dot(x, y, 1 + (p.k % 2), this.color); c.globalAlpha = 1; }
      else if (s === 'spore') { c.globalAlpha = 0.45 + 0.55 * Math.abs(Math.sin(p.t * 2 + p.k)); this.blit(spr.spore?.[p.k % 2], x, y) || this.dot(x, y, 2, this.color); c.globalAlpha = 1; }
      else if (s === 'bats') { const f = Math.floor(p.t * 10) % 4; this.blit(spr.bat?.[f], x, y + Math.round(Math.sin(p.t * 3 + p.k) * 3)) || this.dot(x, y, 3, '#1a1020'); }
    }
  }
  private boltPath: [number, number][] | null = null;
  private bolt() {
    const W = this.cv.width, H = this.cv.height;
    let x = Math.round(W * (0.15 + Math.random() * 0.7)), y = 0;
    const pts: [number, number][] = [[x, y]];
    while (y < H * 0.55) { y += 4 + Math.floor(Math.random() * 6); x += Math.floor(Math.random() * 7) - 3; pts.push([x, y]); }
    this.boltPath = pts;
  }
  private drawBolt() {
    const c = this.ctx; c.fillStyle = '#f4f6ff';
    for (let i = 1; i < this.boltPath!.length; i++) {
      const [x0, y0] = this.boltPath![i - 1], [x1, y1] = this.boltPath![i];
      const n = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0));
      for (let j = 0; j <= n; j++) c.fillRect(Math.round(x0 + ((x1 - x0) * j) / n), Math.round(y0 + ((y1 - y0) * j) / n), 1, 1);
    }
  }
  private blit(im: HTMLImageElement | undefined, x: number, y: number) {
    if (!im || !im.complete || !im.naturalWidth) return false;
    this.ctx.drawImage(im, x, y); return true;
  }
  private dot(x: number, y: number, r: number, col: string) { this.ctx.fillStyle = col; this.ctx.fillRect(x, y, r, r); return true; }
}
