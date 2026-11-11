// Som do site: só toca depois que o visitante liga (abertura "com som" ou o botão de som).
export class Ambient {
  private a: HTMLAudioElement | null = null;
  private src = '';
  private vol = 0.45;
  private ducked = false;
  play(src?: string) {
    if (!src) { this.stop(); return; }
    if (this.a && this.src === src) { this.a.play().catch(() => {}); return; }
    const old = this.a;
    const a = new Audio(src); a.loop = true; a.volume = 0; a.preload = 'auto';
    this.a = a; this.src = src;
    a.play().then(() => this.fade(a, this.ducked ? 0.08 : this.vol)).catch(() => {});
    if (old) this.fade(old, 0, () => old.pause());
  }
  stop() { const a = this.a; this.a = null; this.src = ''; if (a) this.fade(a, 0, () => a.pause()); }
  duck(on: boolean) { this.ducked = on; if (this.a) this.fade(this.a, on ? 0 : this.vol, on ? () => this.a?.pause() : undefined); if (!on && this.a) this.a.play().catch(() => {}); }
  sfx(src: string) {
    let on = false;
    try { on = localStorage.getItem('rm.sound') === '1'; } catch { /* modo privado */ }
    if (!on) return; // sem opt-in, sem som
    const s = new Audio(src); s.volume = 0.6; s.play().catch(() => {});
  }
  private fade(a: HTMLAudioElement, to: number, done?: () => void) {
    const from = a.volume, t0 = performance.now(), dur = 700;
    const step = (t: number) => {
      const k = Math.min(1, (t - t0) / dur);
      a.volume = Math.max(0, Math.min(1, from + (to - from) * k));
      if (k < 1) requestAnimationFrame(step); else done?.();
    };
    requestAnimationFrame(step);
  }
}

// Código Konami: uma frase 8-bit em onda quadrada, gerada na hora (nenhum arquivo baixado).
export function chiptune() {
  const AC = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
  if (!AC) return;
  const ac = new AC();
  const notes = [69, 72, 76, 74, 72, 69, 67, 69, 64, 0, 69, 72, 76, 79, 77, 76, 74, 72, 74, 76];
  const step = 0.14;
  const g = ac.createGain(); g.gain.value = 0.06; g.connect(ac.destination);
  notes.forEach((n, i) => {
    if (!n) return;
    const o = ac.createOscillator(); o.type = 'square';
    o.frequency.value = 440 * Math.pow(2, (n - 69) / 12);
    const e = ac.createGain(); e.gain.setValueAtTime(1, ac.currentTime + i * step); e.gain.exponentialRampToValueAtTime(0.01, ac.currentTime + i * step + step * 0.95);
    o.connect(e); e.connect(g); o.start(ac.currentTime + i * step); o.stop(ac.currentTime + i * step + step);
    // baixo em quintas
    const b = ac.createOscillator(); b.type = 'triangle'; b.frequency.value = 440 * Math.pow(2, (n - 81) / 12);
    const eb = ac.createGain(); eb.gain.value = 0.7; b.connect(eb); eb.connect(g); b.start(ac.currentTime + i * step); b.stop(ac.currentTime + i * step + step * 0.9);
  });
  setTimeout(() => ac.close(), (notes.length * step + 1) * 1000);
}
