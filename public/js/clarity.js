// Microsoft Clarity (projeto zd7sboppd4): só no domínio real, nunca em robôs/testes automatizados.
// Carrega depois do load (não atrasa a primeira pintura). COM cookies _clck/_clsk (Daniel, 13/11/2026: ligar as páginas da mesma pessoa);
// o texto vai mascarado (projeto em "Rígido") e os formulários levam data-clarity-mask. Nunca chamar identify/set com dado pessoal.
(function () {
  if (location.hostname !== 'runemoire.com' || navigator.webdriver) return;
  var go = function () {
    (function (c, l, a, r, i, t, y) {
      c[a] = c[a] || function () { (c[a].q = c[a].q || []).push(arguments); };
      t = l.createElement(r); t.async = 1; t.src = 'https://www.clarity.ms/tag/' + i;
      y = l.getElementsByTagName(r)[0]; y.parentNode.insertBefore(t, y);
    })(window, document, 'clarity', 'script', 'zd7sboppd4');
  };
  if (document.readyState === 'complete') go(); else addEventListener('load', go, { once: true });
})();
