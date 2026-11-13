// Microsoft Clarity (projeto zd7sboppd4): só no domínio real, nunca em robôs/testes automatizados.
// Carrega depois do load (não atrasa a primeira pintura); consentv2 negado = sem cookies _clck/_clsk em runemoire.com (clarity.ms/bing.com ainda gravam os deles).
(function () {
  if (location.hostname !== 'runemoire.com' || navigator.webdriver) return;
  var go = function () {
    (function (c, l, a, r, i, t, y) {
      c[a] = c[a] || function () { (c[a].q = c[a].q || []).push(arguments); };
      t = l.createElement(r); t.async = 1; t.src = 'https://www.clarity.ms/tag/' + i;
      y = l.getElementsByTagName(r)[0]; y.parentNode.insertBefore(t, y);
    })(window, document, 'clarity', 'script', 'zd7sboppd4');
    window.clarity('consentv2', { ad_Storage: 'denied', analytics_Storage: 'denied' });
  };
  if (document.readyState === 'complete') go(); else addEventListener('load', go, { once: true });
})();
