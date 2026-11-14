// Worker do runemoire.com: www -> raiz (301), cabeçalhos de segurança, cache e a API do "Me avise".
import { STYLE_HASHES } from './csp.gen.js';
const CSP = [
  "default-src 'none'",
  "script-src 'self' https://static.cloudflareinsights.com https://www.clarity.ms https://scripts.clarity.ms",
  `style-src 'self' ${STYLE_HASHES}`.trim(),
  "img-src 'self' data: blob: https://*.clarity.ms https://c.bing.com",
  "media-src 'self'",
  "font-src 'self'",
  "connect-src 'self' https://cloudflareinsights.com https://*.clarity.ms https://c.bing.com",
  "manifest-src 'self'",
  "base-uri 'none'",
  "form-action 'self'",
  "frame-ancestors 'none'",
  'upgrade-insecure-requests',
].join('; ');

const SEG = {
  'Strict-Transport-Security': 'max-age=63072000; includeSubDomains',
  'Content-Security-Policy': CSP,
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Permissions-Policy': 'camera=(), microphone=(), geolocation=(), payment=(), usb=()',
  'Cross-Origin-Opener-Policy': 'same-origin',
  'X-Frame-Options': 'DENY',
};

const LANGS = ['en', 'pt_BR', 'es', 'fr', 'de'];
// Europa (UE/EEE, Reino Unido, Suíça): o Clarity pede aceite antes (public/js/clarity.js). Sem país conhecido (XX, T1 = Tor) também pede.
const CONSENT_CC = new Set(['AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'DE', 'GR', 'HU', 'IE', 'IT', 'LV', 'LT', 'LU',
  'MT', 'NL', 'PL', 'PT', 'RO', 'SK', 'SI', 'ES', 'SE', 'IS', 'LI', 'NO', 'GB', 'CH', 'XX', 'T1']);
// na prévia, ?cc=XX simula o país (teste); na produção vale só o país da Cloudflare
export function needsConsent(req, env) {
  const url = new URL(req.url);
  const test = env && env.PREVIEW === '1' ? url.searchParams.get('cc') : null;
  const cc = (test || (req.cf && req.cf.country) || req.headers.get('CF-IPCountry') || 'XX').toUpperCase();
  return CONSENT_CC.has(cc);
}
const BIOMES = ['fields', 'highlands', 'abyss', 'frost', 'marsh', 'dusk', 'eclipse'];
const VARIANTS = ['a', 'b', 'v2', 'v3', 'v3b', 'blog'];

// contador diário anônimo (sem IP, sem identificador): visitas por sessão e cadastros, por versão e idioma
async function bump(env, variant, lang, col) {
  if (env.PREVIEW === '1') return; // prévia não entra na contagem
  const day = new Date().toISOString().slice(0, 10);
  await env.DB.prepare(`INSERT INTO stats_daily (day, variant, lang, ${col}) VALUES (?1, ?2, ?3, 1) ON CONFLICT(day, variant, lang) DO UPDATE SET ${col} = ${col} + 1`)
    .bind(day, variant, lang).run();
}

async function view(req, env) {
  if (req.method !== 'POST') return json({ ok: false, error: 'method' }, 405);
  const ip = req.headers.get('CF-Connecting-IP') || 'local';
  if (env.NOTIFY_LIMIT) { const { success } = await env.NOTIFY_LIMIT.limit({ key: 'view:' + ip }); if (!success) return json({ ok: true }); }
  let b = {};
  try { b = JSON.parse(await req.text()); } catch { /* sendBeacon vazio */ }
  if (!VARIANTS.includes(b.variant) || !LANGS.includes(b.lang)) return json({ ok: false, error: 'bad' }, 400);
  // navegador sem janela e Lighthouse (testes, capturas, robôs) não contam como visita
  const ua = req.headers.get('User-Agent') || '';
  if (/HeadlessChrome|Chrome-Lighthouse|bot|crawler|spider/i.test(ua)) return json({ ok: true, counted: false });
  await bump(env, b.variant, b.lang, 'views');
  return json({ ok: true });
}
const EMAIL = /^[^\s@<>"']{1,64}@[^\s@<>"']{1,190}\.[A-Za-z]{2,24}$/;

function json(obj, status = 200) {
  const r = new Response(JSON.stringify(obj), { status, headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' } });
  for (const [k, v] of Object.entries(SEG)) r.headers.set(k, v);
  return r;
}

async function body(req) {
  const ct = req.headers.get('Content-Type') || '';
  if (ct.includes('application/json')) return await req.json().catch(() => ({}));
  if (ct.includes('form')) return Object.fromEntries(await req.formData().catch(() => new FormData()));
  return {};
}

function token() {
  const b = new Uint8Array(18);
  crypto.getRandomValues(b);
  return btoa(String.fromCharCode(...b)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

// origem da primeira visita (padrão de UTM): só texto simples e curto; o resto vira null
const UTM_KEYS = ['utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term', 'fbclid'];
export function cleanUtm(u) {
  const o = u && typeof u === 'object' ? u : {};
  return UTM_KEYS.map((k) => {
    const v = typeof o[k] === 'string' ? o[k].trim() : '';
    return /^[A-Za-z0-9._~+%-]+$/.test(v) && v.length <= (k === 'fbclid' ? 255 : 120) ? v : null;
  });
}

async function notify(req, env) {
  if (req.method !== 'POST') return json({ ok: false, error: 'method' }, 405);
  const ip = req.headers.get('CF-Connecting-IP') || 'local';
  if (env.NOTIFY_LIMIT) {
    const { success } = await env.NOTIFY_LIMIT.limit({ key: 'notify:' + ip });
    if (!success) return json({ ok: false, error: 'rate' }, 429);
  }
  const b = await body(req);
  // honeypot: humano não vê o campo "website"; robô preenche. Resposta igual à de sucesso, sem gravar.
  if (b.website) return json({ ok: true });
  const email = String(b.email || '').trim().toLowerCase();
  const lang = LANGS.includes(b.lang) ? b.lang : 'en';
  if (email.length > 254 || !EMAIL.test(email)) return json({ ok: false, error: 'email' }, 400);
  const t = token();
  const now = new Date().toISOString();
  const biome = BIOMES.includes(b.biome) ? b.biome : null;
  const variant = VARIANTS.includes(b.variant) ? b.variant : null;
  // origem: os pontos da home ou o post do blog (blog:<slug>, blog:hub)
  const source = ['hero', 'final', 'achievements'].includes(b.source) || /^blog:[a-z0-9-]{1,80}$/.test(String(b.source || '')) ? b.source : null;
  // e-mail novo: grava e devolve o link de saída. Já cadastrado: só confirma, sem devolver o token
  // (senão qualquer um tiraria qualquer e-mail da lista); a pessoa sai pelo link original ou pelo contato.
  const r = await env.DB.prepare('INSERT INTO notify (email, lang, created_at, token, biome, variant, source, utm_source, utm_medium, utm_campaign, utm_content, utm_term, fbclid) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13) ON CONFLICT(email) DO NOTHING')
    .bind(email, lang, now, t, biome, variant, source, ...cleanUtm(b.utm)).run();
  // e-mails @example.com (domínio reservado, usado nos testes) não entram na contagem
  if (r.meta?.changes && !email.endsWith('@example.com')) await bump(env, variant || 'none', lang, 'signups');
  return json({ ok: true, token: r.meta?.changes ? t : null });
}

async function unsubscribe(req, env) {
  if (req.method !== 'POST') return json({ ok: false, error: 'method' }, 405);
  const b = await body(req);
  const t = String(b.token || '');
  if (!/^[A-Za-z0-9_-]{20,40}$/.test(t)) return json({ ok: false, error: 'token' }, 400);
  const r = await env.DB.prepare('DELETE FROM notify WHERE token = ?1').bind(t).run();
  return json({ ok: true, removed: r.meta?.changes || 0 });
}

const PREFIX = { pt: 'pt', es: 'es', fr: 'fr', de: 'de' };

// Range de um intervalo (bytes=a-b, a-, -n): os assets do Worker sempre devolvem o arquivo inteiro, e o Safari
// do iPhone só toca vídeo com 206. Áudio e vídeo (<= 25 MiB por arquivo) são lidos inteiros para saber o tamanho,
// porque a resposta dos assets não traz Content-Length; o resto passa direto.
async function byteRange(req, r) {
  const headers = new Headers(r.headers);
  const media = /^(video|audio)\//i.test(headers.get('Content-Type') || '');
  if (!media) return new Response(r.body, { status: 200, headers });
  headers.set('Accept-Ranges', 'bytes');
  const h = req.headers.get('Range');
  const m = h && /^bytes=(\d*)-(\d*)$/.exec(h.trim());
  if (!m || (m[1] === '' && m[2] === '')) return new Response(r.body, { status: 200, headers });
  const buf = await r.arrayBuffer();
  const size = buf.byteLength;
  let start, end;
  if (m[1] === '') { start = Math.max(0, size - Number(m[2])); end = size - 1; }
  else { start = Number(m[1]); end = m[2] === '' ? size - 1 : Math.min(Number(m[2]), size - 1); }
  if (start >= size || start > end) {
    headers.set('Content-Range', `bytes */${size}`);
    headers.delete('Content-Length');
    return new Response(null, { status: 416, headers });
  }
  headers.set('Content-Range', `bytes ${start}-${end}/${size}`);
  headers.set('Content-Length', String(end - start + 1));
  return new Response(req.method === 'HEAD' ? null : buf.slice(start, end + 1), { status: 206, headers });
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    // sempre HTTPS na raiz: http://, www e http://www vão direto para https://runemoire.com (um salto só)
    if (env.FORCE_HTTPS !== '0' && (url.hostname === 'www.runemoire.com' || (url.protocol === 'http:' && url.hostname === 'runemoire.com'))) {
      if (url.hostname === 'www.runemoire.com') url.hostname = 'runemoire.com';
      url.protocol = 'https:';
      return Response.redirect(url.toString(), 301);
    }
    // a prévia em workers.dev também só em HTTPS (o host já manda noindex e canonical para o domínio)
    if (url.protocol === 'http:' && url.hostname.endsWith('.workers.dev')) { url.protocol = 'https:'; return Response.redirect(url.toString(), 301); }
    const p = url.pathname;
    // /index.html e /pt/index.html vão direto para a pasta, num salto só e permanente
    if (/(^|\/)index\.html$/.test(p)) { url.pathname = p.replace(/index\.html$/, '').replace(/\/{2,}/g, '/') || '/'; return Response.redirect(url.toString(), 301); }
    if (p === '/api/notify') return notify(req, env);
    if (p === '/api/unsubscribe') return unsubscribe(req, env);
    if (p === '/api/view') return view(req, env);
    if (p.startsWith('/api/')) return json({ ok: false, error: 'not_found' }, 404);

    let r = await env.ASSETS.fetch(req);
    let status = r.status;
    // a barra final (auto-trailing-slash) vem como 307 dos assets: vira 301, com destino absoluto e sem barra dupla
    if (status === 307 || status === 308) {
      const to = new URL(r.headers.get('Location') || '/', url);
      to.pathname = to.pathname.replace(/\/{2,}/g, '/');
      const red = new Response(null, { status: 301, headers: { Location: to.toString() } });
      for (const [k, v] of Object.entries(SEG)) red.headers.set(k, v);
      return red;
    }
    if (status === 404) {
      const seg = p.split('/')[1];
      const nf = PREFIX[seg] ? `/${seg}/404` : '/404';
      r = await env.ASSETS.fetch(new Request(new URL(nf, url), req));
      status = 404;
    }
    const res = status === 200 ? await byteRange(req, r) : new Response(r.body, { status, headers: r.headers });
    for (const [k, v] of Object.entries(SEG)) res.headers.set(k, v);
    const ct = res.headers.get('Content-Type') || '';
    if (/^text\/(html|plain)/i.test(ct) && !/charset/i.test(ct)) res.headers.set('Content-Type', ct.split(';')[0] + '; charset=utf-8');
    if (env.PREVIEW === '1') res.headers.set('X-Robots-Tag', 'noindex, nofollow');
    if (p.startsWith('/assets/')) res.headers.set('Cache-Control', 'public, max-age=31536000, immutable');
    else if (/^\/(img|media|fonts)\//.test(p)) res.headers.set('Cache-Control', 'public, max-age=2592000, stale-while-revalidate=604800');
    else if (/\.(png|svg|ico|xml|txt|webmanifest|js|css)$/.test(p)) res.headers.set('Cache-Control', 'public, max-age=86400');
    else res.headers.set('Cache-Control', 'public, max-age=0, must-revalidate');
    // 404 nunca fica um dia no cache (um arquivo novo, como /llms.txt, aparece no próximo minuto)
    if (status === 404) res.headers.set('Cache-Control', 'public, max-age=60');
    if (/^text\/html/i.test(res.headers.get('Content-Type') || '') && needsConsent(req, env)) {
      return new HTMLRewriter().on('html', { element(e) { e.setAttribute('data-consent', 'eu'); } }).transform(res);
    }
    return res;
  },
};
