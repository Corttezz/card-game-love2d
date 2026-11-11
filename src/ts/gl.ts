// Executa os shaders do jogo (LÖVE GLSL, em src/shaders, copiados sem mudar) em WebGL2.
// Só traduz a moldura do LÖVE: extern -> uniform, Image -> sampler2D, Texel -> texture, number -> float,
// effect(color, tex, uv, screen_px) chamado por um main() com a coordenada de tela de cima para baixo, como no LÖVE.
// pow(x, 2.0) vira x*x (no LÖVE/OpenGL de mesa o driver faz isso; no ANGLE pow de base negativa daria NaN).
export type U = number | number[] | Float32Array | WebGLTexture;

const VS = `#version 300 es
in vec2 aPos;
uniform vec4 uRect; uniform vec2 uView; uniform vec4 uSrc;
out vec2 vUv;
void main() { vec2 p = uRect.xy + aPos * uRect.zw; vUv = mix(uSrc.xy, uSrc.zw, aPos);
  gl_Position = vec4(p.x / uView.x * 2.0 - 1.0, 1.0 - p.y / uView.y * 2.0, 0.0, 1.0); }`;

function fixPow(s: string): string {
  let out = '', i = 0;
  for (;;) {
    const j = s.indexOf('pow(', i);
    if (j < 0) return out + s.slice(i);
    if (j > 0 && /[A-Za-z0-9_]/.test(s[j - 1])) { out += s.slice(i, j + 4); i = j + 4; continue; }
    let d = 0, k = j + 4, comma = -1;
    for (; k < s.length; k++) {
      const c = s[k];
      if (c === '(') d++;
      else if (c === ')') { if (d === 0) break; d--; }
      else if (c === ',' && d === 0) comma = k;
    }
    const a = s.slice(j + 4, comma), b = s.slice(comma + 1, k);
    out += s.slice(i, j) + (b.trim() === '2.0' ? `_sq(${fixPow(a)})` : `pow(${fixPow(a)},${b})`);
    i = k + 1;
  }
}

function fsWrap(src: string) {
  return `#version 300 es
precision highp float;
#define extern uniform
#define number float
#define Image sampler2D
#define Texel texture
uniform sampler2D MainTex; uniform vec4 uColor; uniform vec2 uView; uniform float uOffY;
in vec2 vUv; out vec4 fragColor;
float _sq(float x) { return x * x; } vec2 _sq(vec2 x) { return x * x; } vec3 _sq(vec3 x) { return x * x; }
${fixPow(src)}
void main() { vec4 c = effect(uColor, MainTex, vUv, vec2(gl_FragCoord.x, uView.y - (gl_FragCoord.y - uOffY))); fragColor = vec4(c.rgb * c.a, c.a); }`;
}

type Prog = { p: WebGLProgram; loc: Map<string, WebGLUniformLocation | null>; types: Map<string, number> };

export class Fx {
  gl: WebGL2RenderingContext;
  canvas: HTMLCanvasElement;
  progs = new Map<string, Prog>();
  texs = new Map<string, { t: WebGLTexture; w: number; h: number }>();
  vw = 1; vh = 1;
  constructor(canvas: HTMLCanvasElement, preserve = false) {
    const gl = canvas.getContext('webgl2', { alpha: true, premultipliedAlpha: true, antialias: false, preserveDrawingBuffer: preserve, depth: false, stencil: false });
    if (!gl) throw new Error('webgl2');
    this.gl = gl; this.canvas = canvas;
    const b = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, b);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([0, 0, 1, 0, 0, 1, 1, 1]), gl.STATIC_DRAW);
    gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false);
    gl.pixelStorei(gl.UNPACK_COLORSPACE_CONVERSION_WEBGL, gl.NONE);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);
  }
  // compila sem travar a página: com KHR_parallel_shader_compile o driver compila em segundo plano e ready() só confere
  pending = new Map<string, { p: WebGLProgram; vs: WebGLShader; fs: WebGLShader }>();
  par: any = null;
  program(name: string, src: string) {
    if (this.progs.has(name) || this.pending.has(name)) return;
    const gl = this.gl;
    if (this.par === null) this.par = gl.getExtension('KHR_parallel_shader_compile') || false;
    const sh = (type: number, s: string) => { const o = gl.createShader(type)!; gl.shaderSource(o, s); gl.compileShader(o); return o; };
    const p = gl.createProgram()!;
    const vs = sh(gl.VERTEX_SHADER, VS), fs = sh(gl.FRAGMENT_SHADER, fsWrap(src));
    gl.attachShader(p, vs); gl.attachShader(p, fs);
    gl.bindAttribLocation(p, 0, 'aPos'); gl.linkProgram(p);
    this.pending.set(name, { p, vs, fs });
  }
  ready(name: string) {
    if (this.progs.has(name)) return true;
    const e = this.pending.get(name); if (!e) return false;
    const gl = this.gl;
    if (this.par && !gl.getProgramParameter(e.p, this.par.COMPLETION_STATUS_KHR)) return false;
    this.pending.delete(name);
    if (!gl.getProgramParameter(e.p, gl.LINK_STATUS)) {
      console.warn('[runemoire] shader', name, gl.getShaderInfoLog(e.fs) || gl.getProgramInfoLog(e.p));
      return false;
    }
    const p = e.p;
    const types = new Map<string, number>();
    const n = gl.getProgramParameter(p, gl.ACTIVE_UNIFORMS);
    for (let i = 0; i < n; i++) { const u = gl.getActiveUniform(p, i)!; types.set(u.name.replace(/\[0\]$/, ''), u.type); }
    this.progs.set(name, { p, loc: new Map(), types });
    return true;
  }
  // textura de uma imagem/canvas; update = reenviar os pixels (canvas que muda a cada quadro)
  tex(key: string, src: TexImageSource, nearest = true, update = false) {
    const gl = this.gl;
    let e = this.texs.get(key);
    if (e && !update) return e.t;
    if (!e) {
      const t = gl.createTexture()!;
      gl.bindTexture(gl.TEXTURE_2D, t);
      const f = nearest ? gl.NEAREST : gl.LINEAR;
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, f); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, f);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
      e = { t, w: 0, h: 0 }; this.texs.set(key, e);
    }
    gl.bindTexture(gl.TEXTURE_2D, e.t);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, src);
    return e.t;
  }
  repeat(key: string) {
    const gl = this.gl, e = this.texs.get(key); if (!e) return;
    gl.bindTexture(gl.TEXTURE_2D, e.t);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
  }
  // prepara um alvo de w x h no canto de cima à esquerda do canvas (o canvas cresce se precisar)
  begin(w: number, h: number) {
    const gl = this.gl, c = this.canvas;
    w = Math.max(1, Math.ceil(w)); h = Math.max(1, Math.ceil(h));
    if (c.width < w || c.height < h) { c.width = Math.max(c.width, w); c.height = Math.max(c.height, h); }
    this.vw = w; this.vh = h;
    gl.viewport(0, c.height - h, w, h);
    gl.enable(gl.SCISSOR_TEST); gl.scissor(0, c.height - h, w, h);
    gl.clearColor(0, 0, 0, 0); gl.clear(gl.COLOR_BUFFER_BIT);
  }
  // desenha a textura no retângulo (x, y, w, h) do alvo com o shader e os uniforms dados
  draw(name: string, tex: WebGLTexture, x: number, y: number, w: number, h: number, u: Record<string, U> = {}, color = [1, 1, 1, 1], src = [0, 0, 1, 1]) {
    const gl = this.gl, P = this.progs.get(name)!;
    gl.useProgram(P.p);
    const set = (k: string, v: U) => {
      let l = P.loc.get(k);
      if (l === undefined) { l = gl.getUniformLocation(P.p, k); P.loc.set(k, l); }
      if (!l) return;
      const ty = P.types.get(k);
      if (ty === gl.SAMPLER_2D) return;
      const a = typeof v === 'number' ? [v] : (v as number[]);
      if (ty === gl.FLOAT) gl.uniform1f(l, a[0]);
      else if (ty === gl.FLOAT_VEC2) gl.uniform2f(l, a[0], a[1]);
      else if (ty === gl.FLOAT_VEC3) gl.uniform3f(l, a[0], a[1], a[2]);
      else if (ty === gl.FLOAT_VEC4) gl.uniform4f(l, a[0], a[1], a[2], a[3]);
    };
    set('uRect', [x, y, w, h]); set('uView', [this.vw, this.vh]); set('uOffY', this.canvas.height - this.vh); set('uSrc', src); set('uColor', color);
    let unit = 0;
    const bindTex = (k: string, t: WebGLTexture) => {
      let l = P.loc.get(k);
      if (l === undefined) { l = gl.getUniformLocation(P.p, k); P.loc.set(k, l); }
      if (!l) return;
      gl.activeTexture(gl.TEXTURE0 + unit); gl.bindTexture(gl.TEXTURE_2D, t); gl.uniform1i(l, unit); unit++;
    };
    bindTex('MainTex', tex);
    for (const [k, v] of Object.entries(u)) {
      if (v instanceof WebGLTexture) bindTex(k, v); else set(k, v);
    }
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
  }
}

// carrega uma imagem como ImageBitmap sem pré-multiplicar o alfa (texturas de dados do selo)
export async function rawBitmap(url: string) {
  const r = await fetch(url);
  return createImageBitmap(await r.blob(), { premultiplyAlpha: 'none', colorSpaceConversion: 'none' });
}
