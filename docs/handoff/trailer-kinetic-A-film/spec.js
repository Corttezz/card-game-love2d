// spec.js: Grimoire trailer A (grimoire_kinetic_hook30). The re-recorded takes are composed underneath by compose.py from B_edl.json;
// this film is only the type layer: Grimoire Pixel at integer scale, stepped at 15 fps, on a transparent stage.
// Times are seconds of the trimmed trailer (EDL time minus TRIM). Every word lands on a measured grave.
import { Scene } from './blocks.js';

await document.fonts.load('8px GrimoirePixel');

const TRIM = 0, STEP = 1 / 15;
const COL = { cream: '#F4E9CF', gold: '#E9B949', hot: '#FFF6DA', ink: '#140B12' };
const SCREEN = { x: 148, y: 56, w: 1624, h: 912 };
const CX = SCREEN.x + SCREEN.w / 2;

// phrases: lines of words; each word has its EDL time. u = size of one font pixel in screen pixels.
export const PHRASES = [
  { out: 3.30, cx: 1130, lines: [
    { y: 140, u: 20, words: [['PLAY.', 1.45]] } ] },
  { out: 6.95, cx: 1130, lines: [
    { y: 140, u: 20, words: [['BREAK.', 3.48, 'gold']] } ] },
  { out: 10.40, lines: [
    { y: 380, u: 16, words: [['SIX ACTS.', 7.18, 'gold']] },
    { y: 560, u: 12, words: [['ONE ROAD', 8.82]] },
    { y: 676, u: 12, words: [['TO THE CASTLE.', 8.82]] } ] },
  { out: 13.40, lines: [
    { y: 690, u: 12, words: [['YOUR CARDS', 10.51]] },
    { y: 806, u: 12, words: [['DECIDE', 10.81, 'gold']] },
    { y: 922, u: 10, words: [['WHAT SURVIVES.', 11.19]] } ] },
  { out: 22.20, lines: [
    { y: 640, u: 12, words: [['EVERY BOSS', 18.82]] },
    { y: 756, u: 12, words: [['IS A PUZZLE.', 19.73, 'gold']] } ] },
  { out: 32.3, lines: [
    { y: 812, u: 10, words: [['WISHLIST ON STEAM.', 29.17]] } ] },
].map(p => ({ out: p.out - TRIM, cx: p.cx || CX, lines: p.lines.map(l => ({ ...l, words: l.words.map(([text, t, col]) => ({ text, t: t - TRIM, col: col || 'cream' })) })) }));

// glyph bitmaps from the font at its native 8 px grid (thresholded: no anti-aliasing survives)
const glyphCache = new Map();
function bitmap(text) {
  if (glyphCache.has(text)) return glyphCache.get(text);
  const Q = 4, w = (text.length * 8 + 8) * Q, h = 16 * Q, c = document.createElement('canvas');
  c.width = w; c.height = h;
  const x = c.getContext('2d');
  x.font = `${8 * Q}px GrimoirePixel`; x.textBaseline = 'alphabetic'; x.fillStyle = '#fff';
  x.fillText(text, 4 * Q, 12 * Q);
  const d = x.getImageData(0, 0, w, h).data, on = [];
  for (let j = 0; j < 16; j++) for (let i = 0; i < text.length * 8 + 8; i++)
    if (d[((j * Q + Q / 2) * w + i * Q + Q / 2) * 4 + 3] >= 128) on.push([i - 4, j - 5]);
  const b = { on, cols: text.length * 8 };
  glyphCache.set(text, b);
  return b;
}
const hash = (i, j, s) => { let h = (i * 374761393 + j * 668265263 + s * 2246822519) >>> 0; h = ((h ^ (h >>> 13)) * 1274126177) >>> 0; return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };

// layout: words of a line sit where the finished line puts them (a word never jumps when the next one lands)
for (const p of PHRASES) for (const l of p.lines) {
  const full = l.words.map(w => w.text).join(' ');
  let col = 0;
  const x0 = Math.round(p.cx - full.length * 8 * l.u / 2);
  for (const w of l.words) { w.x = x0 + col * 8 * l.u; w.cx = w.x + w.text.length * 4 * l.u; col += w.text.length + 1; }
}

export class PixelType extends Scene {
  build() {
    this.noGrid = true;
    this.dsf = window.devicePixelRatio || 1;
    this.c = document.createElement('canvas');
    this.c.width = 1920 * this.dsf; this.c.height = 1080 * this.dsf;
    Object.assign(this.c.style, { position: 'absolute', left: 0, top: 0, width: '1920px', height: '1080px', imageRendering: 'pixelated' });
    this.root.appendChild(this.c);
    this.x = this.c.getContext('2d');
    window.__inkAt = t => PHRASES.some(p => t >= p.lines[0].words[0].t - 1e-6 && t < p.out);
  }
  cam() { return { x: 0, y: 0, s: 1, r: 0 }; }
  update(t) {
    const x = this.x;
    x.setTransform(1, 0, 0, 1, 0, 0); x.clearRect(0, 0, this.c.width, this.c.height);
    x.setTransform(this.dsf, 0, 0, this.dsf, 0, 0);
    for (const p of PHRASES) {
      const first = p.lines[0].words[0].t;
      if (t < first - 1e-6 || t >= p.out) continue;
      // rune dissolve over the last 4 steps before the phrase leaves
      const left = Math.floor((p.out - t) / STEP);
      const gone = p.out >= 32.3 - 1e-6 ? 0 : left < 4 ? (4 - left) / 4 : 0;
      // the whole phrase kicks one font pixel sideways on each word that lands, for two steps
      let kx = 0;
      for (const l of p.lines) for (const w of l.words) {
        const s = Math.floor((t - w.t) / STEP + 1e-6);
        if (s >= 0 && s < 2) kx = (s === 0 ? 1 : -1) * Math.round(l.u / 2);
      }
      for (const l of p.lines) for (const w of l.words) {
        const s = Math.floor((t - w.t) / STEP + 1e-6);
        if (s < 0) continue;
        const u = s === 0 ? l.u + 3 : s === 1 ? l.u + 1 : l.u;
        const col = s === 0 ? COL.hot : COL[w.col];
        this.word(w, u, l.y + l.u * 3.5, col, gone, kx);
      }
    }
  }
  // one word: shadow, ink outline, face; cells drop out by hash when the phrase dissolves
  word(w, u, cy, col, gone, kx) {
    const x = this.x, b = bitmap(w.text);
    const x0 = Math.round(w.cx - b.cols * u / 2) + kx, y0 = Math.round(cy - 3.5 * u);
    const alive = ([i, j]) => !gone || hash(i, j, w.text.length) >= gone;
    const cells = b.on.filter(alive);
    const set = new Set(cells.map(([i, j]) => i + ',' + j));
    const ring = new Map();
    for (const [i, j] of cells) for (let a = -1; a <= 1; a++) for (let c = -1; c <= 1; c++) {
      const k = (i + a) + ',' + (j + c);
      if (!set.has(k)) ring.set(k, [i + a, j + c]);
    }
    x.fillStyle = COL.ink;
    for (const [i, j] of [...ring.values(), ...cells]) x.fillRect(x0 + (i + 1) * u, y0 + (j + 1) * u, u, u);
    for (const [i, j] of ring.values()) x.fillRect(x0 + i * u, y0 + j * u, u, u);
    x.fillStyle = col;
    for (const [i, j] of cells) x.fillRect(x0 + i * u, y0 + j * u, u, u);
  }
}

export default {
  title: 'grimoire_kinetic_hook30',
  bpm: 95.6, beats: 32.3 * 95.6 / 60, fps: 60,
  palette: { bg: '#140B12', paper: '#F4E9CF', accent: '#E9B949', hot: '#FFF6DA', ink: '#140B12' },
  hud: false,
  sounds: {},
  cues: [],
  scenes: [[PixelType, 0, 32.3 * 95.6 / 60, {}]],
  captions: [],
};
