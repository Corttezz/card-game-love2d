// Peças do LÖVE que o porte precisa para ficar igual ao jogo: o gerador aleatório (Xorshift64* com wangHash64,
// love.math.newRandomGenerator), o ruído simplex (love.math.noise), as cores da Palette e as curvas do jogo.
const M64 = (1n << 64n) - 1n;
function wangHash64(k: bigint) {
  k = (~k + (k << 21n)) & M64;
  k = k ^ (k >> 24n);
  k = (k + (k << 3n) + (k << 8n)) & M64;
  k = k ^ (k >> 14n);
  k = (k + (k << 2n) + (k << 4n)) & M64;
  k = k ^ (k >> 28n);
  k = (k + (k << 31n)) & M64;
  return k;
}
export class LoveRng {
  s = 0n;
  constructor(seed = 1) { this.setSeed(seed); }
  setSeed(seed: number) { this.s = wangHash64(BigInt(Math.floor(seed)) & M64); if (this.s === 0n) this.s = 1n; }
  private next() {
    let x = this.s;
    x ^= x >> 12n; x ^= (x << 25n) & M64; x ^= x >> 27n;
    this.s = x;
    return (x * 2685821657736338717n) & M64;
  }
  random(): number;
  random(a: number, b: number): number;
  random(a?: number, b?: number) {
    const r = this.next();
    const u = Number(r >> 12n) / 4503599627370496; // como o LÖVE: 52 bits de mantissa, [0,1)
    if (a === undefined) return u;
    return Math.floor(u * (b! - a + 1)) + a;
  }
}

// love.math.noise(x, y) = SimplexNoise1234::noise(x, y) * 0.5 + 0.5 (tabela de permutação de Perlin)
const P0 = [151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225, 140, 36, 103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148, 247, 120, 234, 75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32, 57, 177, 33, 88, 237, 149, 56, 87, 174, 20, 125, 136, 171, 168, 68, 175, 74, 165, 71, 134, 139, 48, 27, 166, 77, 146, 158, 231, 83, 111, 229, 122, 60, 211, 133, 230, 220, 105, 92, 41, 55, 46, 245, 40, 244, 102, 143, 54, 65, 25, 63, 161, 1, 216, 80, 73, 209, 76, 132, 187, 208, 89, 18, 169, 200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109, 198, 173, 186, 3, 64, 52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126, 255, 82, 85, 212, 207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183, 170, 213, 119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43, 172, 9, 129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112, 104, 218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162, 241, 81, 51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31, 181, 199, 106, 157, 184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205, 93, 222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180];
const PERM = new Uint8Array(512); for (let i = 0; i < 512; i++) PERM[i] = P0[i & 255];
const grad2 = (h: number, x: number, y: number) => { h &= 7; const u = h < 4 ? x : y, v = h < 4 ? y : x; return ((h & 1) ? -u : u) + ((h & 2) ? -2 * v : 2 * v); };
export function noise(x: number, y: number) {
  const F2 = 0.366025403, G2 = 0.211324865;
  const s = (x + y) * F2, i = Math.floor(x + s), j = Math.floor(y + s);
  const t = (i + j) * G2, x0 = x - (i - t), y0 = y - (j - t);
  const i1 = x0 > y0 ? 1 : 0, j1 = x0 > y0 ? 0 : 1;
  const x1 = x0 - i1 + G2, y1 = y0 - j1 + G2, x2 = x0 - 1 + 2 * G2, y2 = y0 - 1 + 2 * G2;
  const ii = i & 255, jj = j & 255;
  let n0 = 0, n1 = 0, n2 = 0;
  let t0 = 0.5 - x0 * x0 - y0 * y0; if (t0 >= 0) { t0 *= t0; n0 = t0 * t0 * grad2(PERM[ii + PERM[jj]], x0, y0); }
  let t1 = 0.5 - x1 * x1 - y1 * y1; if (t1 >= 0) { t1 *= t1; n1 = t1 * t1 * grad2(PERM[ii + i1 + PERM[jj + j1]], x1, y1); }
  let t2 = 0.5 - x2 * x2 - y2 * y2; if (t2 >= 0) { t2 *= t2; n2 = t2 * t2 * grad2(PERM[ii + 1 + PERM[jj + 1]], x2, y2); }
  return 40 * (n0 + n1 + n2) * 0.5 + 0.5;
}

const hex = (h: string) => [parseInt(h.slice(1, 3), 16) / 255, parseInt(h.slice(3, 5), 16) / 255, parseInt(h.slice(5, 7), 16) / 255];
export const PAL = {
  PARCHMENT_LIGHT: hex('#e8d5a0'), PARCHMENT: hex('#b8a068'), PARCHMENT_DARK: hex('#6a4f24'), INK: hex('#1a0f08'),
  AGED_GOLD: hex('#b08a3e'), AGED_GOLD_LIGHT: hex('#d4b060'),
};
export const AMBER = [1.0, 0.72, 0.22], AMBER_DIM = [0.5, 0.34, 0.1];
export const rgba = (c: number[], a = 1) => `rgba(${Math.round(Math.min(1, c[0]) * 255)},${Math.round(Math.min(1, c[1]) * 255)},${Math.round(Math.min(1, c[2]) * 255)},${Math.max(0, Math.min(1, a))})`;
export const rgb255 = (c: number[], a = 1) => `rgba(${c[0]},${c[1]},${c[2]},${a})`;

export const clamp01 = (u: number) => Math.max(0, Math.min(1, u));
export const smooth = (u: number) => { u = clamp01(u); return u * u * (3 - 2 * u); };
export const backOut = (u: number) => { u = clamp01(u); const c1 = 1.70158, c3 = 2.70158; return 1 + c3 * (u - 1) ** 3 + c1 * (u - 1) ** 2; };
export const easeInOutCubic = (t: number) => { t = clamp01(t); return t < 0.5 ? 4 * t * t * t : 1 - (-2 * t + 2) ** 3 / 2; };
export const easeOut3 = (u: number) => 1 - (1 - clamp01(u)) ** 3;

// fonte do jogo (assets/fonts/pixel.ttf) como no FontManager: print(x, y) com y no topo da linha
const metr = new Map<number, { asc: number; h: number }>();
export function font(ctx: CanvasRenderingContext2D, size: number) {
  size = Math.max(1, Math.floor(size));
  ctx.font = `${size}px Runic`;
  let m = metr.get(size);
  if (!m) {
    const mm = ctx.measureText('Mg');
    const asc = mm.fontBoundingBoxAscent ?? size * 0.8, desc = mm.fontBoundingBoxDescent ?? size * 0.2;
    m = { asc, h: asc + desc };
    if (document.fonts?.check?.(`${size}px Runic`)) metr.set(size, m);
  }
  ctx.textBaseline = 'alphabetic';
  return m;
}
export function print(ctx: CanvasRenderingContext2D, s: string, x: number, y: number, asc: number) { ctx.fillText(s, Math.round(x), Math.round(y + asc)); }

// imagem tingida como setColor(r, g, b) do LÖVE antes de desenhar (multiplica a cor, mantém o alfa)
export function tinted(img: CanvasImageSource & { width: number; height: number }, c: number[]) {
  const cv = document.createElement('canvas'); cv.width = img.width; cv.height = img.height;
  const x = cv.getContext('2d')!; x.drawImage(img, 0, 0);
  x.globalCompositeOperation = 'source-in';
  if (c[0] === 0 && c[1] === 0 && c[2] === 0) { x.fillStyle = '#000'; x.fillRect(0, 0, cv.width, cv.height); return cv; }
  x.globalCompositeOperation = 'multiply'; x.fillStyle = rgba(c); x.fillRect(0, 0, cv.width, cv.height);
  x.globalCompositeOperation = 'destination-in'; x.drawImage(img, 0, 0);
  return cv;
}
