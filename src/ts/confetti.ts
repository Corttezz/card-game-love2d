// Confete de cartas e runas (pixel art, gravidade simples). Desligado com movimento reduzido.
const SRC = ['fields', 'highlands', 'abyss', 'frost', 'marsh', 'dusk'].map((b) => `/img/gen/runes/rune_${b}.png`);
let imgs: HTMLImageElement[] = [];
export function confetti(x: number, y: number) {
  if (matchMedia('(prefers-reduced-motion: reduce)').matches || document.body.classList.contains('reduced')) return;
  const cv = document.getElementById('confetti') as HTMLCanvasElement | null;
  if (!cv) return;
  if (!imgs.length) imgs = SRC.map((s) => Object.assign(new Image(), { src: s }));
  const S = 2;
  cv.width = Math.ceil(innerWidth / S); cv.height = Math.ceil(innerHeight / S);
  const c = cv.getContext('2d')!; c.imageSmoothingEnabled = false;
  const cards = ['#e9d9b4', '#3d7bd6', '#e0a020', '#9b4ad6', '#c94a3a'];
  const ps = Array.from({ length: 70 }, (_, i) => ({
    x: x / S, y: y / S, vx: (Math.random() - 0.5) * 220, vy: -120 - Math.random() * 160, r: Math.random() * 6, vr: (Math.random() - 0.5) * 10,
    kind: i % 3 === 0 ? 'rune' : 'card', col: cards[i % cards.length], im: imgs[i % imgs.length],
  }));
  let last = performance.now(), t0 = last;
  cv.classList.add('on');
  const step = (now: number) => {
    const dt = Math.min(0.04, (now - last) / 1000); last = now;
    c.clearRect(0, 0, cv.width, cv.height);
    for (const p of ps) {
      p.vy += 360 * dt; p.vx *= 0.99; p.x += p.vx * dt; p.y += p.vy * dt; p.r += p.vr * dt;
      c.save(); c.translate(Math.round(p.x), Math.round(p.y));
      if (p.kind === 'rune' && p.im.complete && p.im.naturalWidth) c.drawImage(p.im, -8, -8, 16, 16);
      else { c.rotate(Math.round(p.r * 4) / 4); c.fillStyle = '#2a1d14'; c.fillRect(-4, -6, 8, 12); c.fillStyle = p.col; c.fillRect(-3, -5, 6, 10); }
      c.restore();
    }
    if (now - t0 < 2600) requestAnimationFrame(step); else { c.clearRect(0, 0, cv.width, cv.height); cv.classList.remove('on'); }
  };
  requestAnimationFrame(step);
}
