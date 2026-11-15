// Google Tag Manager (GTM-5NVWLLNZ; GA4 G-LY30QRD5G2 configurado dentro do contêiner pelo SEO & Growth), com Consent Mode v2.
// Default ANTES do contêiner: Europa (UE/EEE, Reino Unido, Suíça; o Worker marca <html data-consent="eu">) fica tudo negado
// até o "Aceitar" do banner (public/js/clarity.js chama window.rmConsentGrant), e o contêiner nem carrega antes disso
// (modo básico: nenhum ping ao Google antes do aceite; quem recusa não manda nada). O resto do mundo, concedido.
// O contêiner carrega depois do load (não mexe na primeira pintura nem na abertura). Só no domínio real, nunca em robôs/testes;
// na prévia (workers.dev) só com ?cc= (teste). Nada de e-mail ou dado pessoal no dataLayer.
(function () {
  var host = location.hostname;
  var test = /\.workers\.dev$/.test(host) && /[?&]cc=/.test(location.search);
  if ((host !== 'runemoire.com' && !test) || navigator.webdriver) return;
  var w = window;
  w.dataLayer = w.dataLayer || [];
  var gtag = function () { w.dataLayer.push(arguments); };
  w.gtag = gtag;
  var all = function (v) { return { ad_storage: v, analytics_storage: v, ad_user_data: v, ad_personalization: v }; };
  var eu = document.documentElement.getAttribute('data-consent') === 'eu';
  var saved = null;
  try { saved = localStorage.getItem('rm_consent'); } catch (e) { saved = null; }
  if (eu) {
    var d = all('denied');
    d.wait_for_update = 500;
    gtag('consent', 'default', d);
    gtag('set', 'ads_data_redaction', true);
    if (saved === 'yes') gtag('consent', 'update', all('granted'));
  } else {
    gtag('consent', 'default', all('granted'));
  }
  var loaded = false;
  var go = function () {
    if (loaded) return;
    loaded = true;
    w.dataLayer.push({ 'gtm.start': new Date().getTime(), event: 'gtm.js' });
    var s = document.createElement('script');
    s.async = true;
    s.src = 'https://www.googletagmanager.com/gtm.js?id=GTM-5NVWLLNZ';
    document.head.appendChild(s);
  };
  var later = function () { if (document.readyState === 'complete') go(); else addEventListener('load', go, { once: true }); };
  w.rmConsentGrant = function () { gtag('consent', 'update', all('granted')); later(); };
  if (!eu || saved === 'yes') later();
})();
