// Microsoft Clarity (projeto zd7sboppd4): só no domínio real, nunca em robôs/testes automatizados.
// Carrega depois do load (não atrasa a primeira pintura) e roda sem cookies (consentv2 negado): a privacidade promete nada no aparelho.
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
