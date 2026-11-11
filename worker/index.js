// Worker do runemoire.com: www -> raiz (301), cabeçalhos de segurança, cache e a API do "Me avise".
const CSP = [
  "default-src 'none'",
  "script-src 'self'",
  "style-src 'self'",
  "img-src 'self' data: blob:",
  "media-src 'self'",
  "font-src 'self'",
  "connect-src 'self'",
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
  const r = await env.DB.prepare(
    'INSERT INTO notify (email, lang, created_at, token) VALUES (?1, ?2, ?3, ?4) ON CONFLICT(email) DO UPDATE SET lang = excluded.lang RETURNING token',
  ).bind(email, lang, now, t).first();
  return json({ ok: true, token: r?.token || t });
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

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (url.hostname === 'www.runemoire.com') {
      url.hostname = 'runemoire.com';
      return Response.redirect(url.toString(), 301);
    }
    const p = url.pathname;
    if (p === '/api/notify') return notify(req, env);
    if (p === '/api/unsubscribe') return unsubscribe(req, env);
    if (p.startsWith('/api/')) return json({ ok: false, error: 'not_found' }, 404);

    let r = await env.ASSETS.fetch(req);
    let status = r.status;
    if (status === 404) {
      const seg = p.split('/')[1];
      const nf = PREFIX[seg] ? `/${seg}/404` : '/404';
      r = await env.ASSETS.fetch(new Request(new URL(nf, url), req));
      status = 404;
    }
    const res = new Response(r.body, { status, headers: r.headers });
    for (const [k, v] of Object.entries(SEG)) res.headers.set(k, v);
    if (p.startsWith('/assets/') || p.startsWith('/media/')) res.headers.set('Cache-Control', 'public, max-age=2592000, immutable');
    else if (/\.(png|svg|ico|xml|txt|webmanifest)$/.test(p)) res.headers.set('Cache-Control', 'public, max-age=86400');
    else res.headers.set('Cache-Control', 'public, max-age=0, must-revalidate');
    return res;
  },
};
