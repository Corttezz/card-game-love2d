// Microsoft Clarity (projeto zd7sboppd4): só no domínio real, nunca em robôs/testes automatizados.
// Carrega depois do load (não atrasa a primeira pintura). COM cookies _clck/_clsk (Daniel, 13/11/2026: ligar as páginas da mesma pessoa);
// o texto vai mascarado (projeto em "Rígido") e os formulários levam data-clarity-mask. Nunca chamar identify/set com dado pessoal.
// Europa (UE/EEE, Reino Unido, Suíça; Daniel, 14/11/2026): o Worker marca <html data-consent="eu"> pelo país (CF-IPCountry).
// Para esses visitantes o Clarity só carrega depois do "Aceitar"; quem recusa não é gravado. A escolha fica no localStorage
// (rm_consent = yes/no), não em cookie. O resto do mundo segue como antes. Na prévia (workers.dev) só roda com ?cc= (teste).
// Origem da visita (padrão de UTM, 14/11/2026): utm_* e fbclid da primeira chegada ficam no localStorage (rm_utm) e vão
// com o cadastro do "Me avise". Primeira origem vence: visita depois, com ou sem UTM, não sobrescreve. Não vai ao Clarity.
(function () {
  try {
    if (localStorage.getItem('rm_utm')) return;
    var q = new URLSearchParams(location.search), o = {}, n = 0;
    ['utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term', 'fbclid'].forEach(function (k) {
      var v = (q.get(k) || '').trim().slice(0, k === 'fbclid' ? 255 : 120);
      if (v) { o[k] = v; n++; }
    });
    if (n) { o.at = new Date().toISOString(); localStorage.setItem('rm_utm', JSON.stringify(o)); }
  } catch (e) {}
})();
(function () {
  var host = location.hostname;
  var test = /\.workers\.dev$/.test(host) && /[?&]cc=/.test(location.search);
  if ((host !== 'runemoire.com' && !test) || navigator.webdriver) return;
  var go = function () {
    (function (c, l, a, r, i, t, y) {
      c[a] = c[a] || function () { (c[a].q = c[a].q || []).push(arguments); };
      t = l.createElement(r); t.async = 1; t.src = 'https://www.clarity.ms/tag/' + i;
      y = l.getElementsByTagName(r)[0]; y.parentNode.insertBefore(t, y);
    })(window, document, 'clarity', 'script', 'zd7sboppd4');
  };
  var later = function (fn) { if (document.readyState === 'complete') fn(); else addEventListener('load', fn, { once: true }); };
  if (document.documentElement.getAttribute('data-consent') !== 'eu') { later(go); return; }
  var KEY = 'rm_consent', saved = null;
  try { saved = localStorage.getItem(KEY); } catch (e) { saved = null; }
  if (saved === 'yes') { later(go); return; }
  if (saved === 'no') return;
  var seg = location.pathname.split('/')[1];
  var lang = { pt: 'pt', es: 'es', fr: 'fr', de: 'de' }[seg] || 'en';
  var T = {
    en: ['We use Microsoft Clarity, with cookies, to see how this site is used. Nothing is recorded unless you accept.', 'Accept', 'Decline', 'Privacy'],
    pt: ['Usamos o Microsoft Clarity, com cookies, para ver como o site é usado. Nada é gravado se você não aceitar.', 'Aceitar', 'Recusar', 'Privacidade'],
    es: ['Usamos Microsoft Clarity, con cookies, para ver cómo se usa el sitio. No se graba nada si no aceptas.', 'Aceptar', 'Rechazar', 'Privacidad'],
    fr: ['Nous utilisons Microsoft Clarity, avec cookies, pour voir comment le site est utilisé. Rien n’est enregistré sans votre accord.', 'Accepter', 'Refuser', 'Confidentialité'],
    de: ['Wir nutzen Microsoft Clarity mit Cookies, um zu sehen, wie die Seite genutzt wird. Ohne deine Zustimmung wird nichts aufgezeichnet.', 'Akzeptieren', 'Ablehnen', 'Datenschutz'],
  }[lang];
  var show = function () {
    var box = document.createElement('div');
    box.className = 'consent';
    box.setAttribute('role', 'dialog');
    box.setAttribute('aria-label', T[3]);
    box.setAttribute('aria-describedby', 'consent-text');
    var p = document.createElement('p');
    p.id = 'consent-text';
    p.textContent = T[0] + ' ';
    var a = document.createElement('a');
    a.href = (lang === 'en' ? '/' : '/' + lang + '/') + 'privacy/';
    a.textContent = T[3];
    p.appendChild(a);
    var row = document.createElement('div');
    row.className = 'consent-row';
    var no = document.createElement('button');
    no.type = 'button'; no.className = 'consent-no'; no.textContent = T[2];
    var yes = document.createElement('button');
    yes.type = 'button'; yes.className = 'consent-yes'; yes.textContent = T[1];
    row.appendChild(no); row.appendChild(yes);
    box.appendChild(p); box.appendChild(row);
    var close = function (v) {
      try { localStorage.setItem(KEY, v); } catch (e) {}
      box.remove();
      if (v === 'yes') go();
    };
    yes.addEventListener('click', function () { close('yes'); });
    no.addEventListener('click', function () { close('no'); });
    document.body.appendChild(box);
  };
  if (document.body) show(); else addEventListener('DOMContentLoaded', show, { once: true });
})();
