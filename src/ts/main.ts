// runemoire.com v2: só o essencial. "Me avise", trailer ao clicar, contagem anônima de visitas. Nada guardado no aparelho.
type Data = { lang: string; unsubPath?: string; t: Record<string, string> };
const $ = <T extends Element = HTMLElement>(s: string, r: ParentNode = document) => r.querySelector(s) as T | null;
const D: Data = JSON.parse($('#rm-data')?.textContent || '{"t":{}}');

function notify() {
  const f = $<HTMLFormElement>('form.notify');
  if (!f) return;
  const msg = $('.msg', f)!;
  const btn = $<HTMLButtonElement>('button[type=submit]', f)!;
  f.addEventListener('submit', async (e) => {
    e.preventDefault();
    const fd = new FormData(f);
    const email = String(fd.get('email') || '').trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) { msg.className = 'msg err'; msg.textContent = D.t.notifyBad; $('input[type=email]', f)?.focus(); return; }
    msg.className = 'msg'; msg.textContent = D.t.sending; btn.disabled = true;
    try {
      const r = await fetch('/api/notify', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, lang: D.lang, website: fd.get('website'), variant: 'v2', source: 'hero' }) });
      const j = await r.json().catch(() => ({}));
      if (r.ok && j.ok) {
        msg.textContent = D.t.notifyOk + ' ';
        if (j.token) { const a = document.createElement('a'); a.href = `${D.unsubPath}?t=${encodeURIComponent(j.token)}`; a.textContent = D.t.unsubLink; msg.append(a); }
        f.reset();
      } else { msg.classList.add('err'); msg.textContent = r.status === 429 ? D.t.notifyRate : D.t.notifyBad; }
    } catch { msg.classList.add('err'); msg.textContent = D.t.notifyNet; }
    btn.disabled = false;
  });
}

function trailer() {
  const b = $<HTMLButtonElement>('.trailer .play');
  b?.addEventListener('click', () => {
    const v = document.createElement('video');
    v.src = b.dataset.src!; v.controls = true; v.autoplay = true; v.playsInline = true;
    v.setAttribute('aria-label', b.getAttribute('aria-label') || '');
    b.closest('.frame')!.replaceChildren(v); v.focus();
  });
}

// uma contagem por carregamento de página, sem identificador (o Worker ignora robôs e navegadores sem janela)
function countView() {
  const body = JSON.stringify({ variant: 'v2', lang: D.lang });
  if (navigator.sendBeacon) navigator.sendBeacon('/api/view', new Blob([body], { type: 'application/json' }));
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

notify(); trailer(); unsubscribe();
if ($('.top')) {
  // o castelo começa no quadro parado e só depois do load ganha a animação lenta do jogo
  const go = () => { document.documentElement.classList.add('anim'); countView(); };
  if (document.readyState === 'complete') setTimeout(go, 400); else addEventListener('load', () => setTimeout(go, 400), { once: true });
}
