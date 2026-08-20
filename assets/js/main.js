// GREEN LAKE — interacciones ligeras, sin dependencias

document.addEventListener('DOMContentLoaded', function () {
  // Banner de sugerencia de idioma (según idioma del navegador vs. idioma de la página)
  try {
    var currentLang = document.documentElement.lang;
    var otherLang = currentLang === 'es' ? 'en' : 'es';
    var browserLang = (navigator.language || (navigator.languages && navigator.languages[0]) || '').toLowerCase();
    var prefersOther = browserLang.indexOf(otherLang) === 0 && browserLang.indexOf(currentLang) !== 0;
    var dismissed = localStorage.getItem('glLangBannerDismissed') === '1';
    var altLink = document.querySelector('link[hreflang="' + otherLang + '"]');

    if (prefersOther && !dismissed && altLink) {
      var copy = otherLang === 'en'
        ? { text: 'This page is also available in English.', cta: 'Switch to English' }
        : { text: 'Esta página también está disponible en español.', cta: 'Cambiar a español' };

      var banner = document.createElement('div');
      banner.className = 'lang-banner';
      banner.innerHTML =
        '<span>' + copy.text + ' <a href="' + altLink.getAttribute('href') + '">' + copy.cta + '</a></span>' +
        '<button type="button" aria-label="Cerrar">&times;</button>';
      document.body.insertBefore(banner, document.body.firstChild);

      banner.querySelector('button').addEventListener('click', function () {
        localStorage.setItem('glLangBannerDismissed', '1');
        banner.remove();
      });
    }
  } catch (e) { /* localStorage puede fallar en modo privado — no bloquear el resto de la página */ }


  // Menú móvil
  var header = document.querySelector('.site-header');
  var toggle = document.querySelector('.nav-toggle');
  if (toggle && header) {
    toggle.addEventListener('click', function () {
      var open = header.classList.toggle('menu-open');
      toggle.classList.toggle('open', open);
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
    document.querySelectorAll('.nav-links a').forEach(function (link) {
      link.addEventListener('click', function () {
        header.classList.remove('menu-open');
        toggle.classList.remove('open');
      });
    });
  }

  // Acordeón de FAQs
  document.querySelectorAll('.faq-item').forEach(function (item) {
    var q = item.querySelector('.faq-q');
    var a = item.querySelector('.faq-a');
    if (!q || !a) return;
    q.addEventListener('click', function () {
      var isOpen = item.classList.contains('open');
      document.querySelectorAll('.faq-item.open').forEach(function (other) {
        if (other !== item) {
          other.classList.remove('open');
          other.querySelector('.faq-a').style.maxHeight = null;
          other.querySelector('.faq-q').setAttribute('aria-expanded', 'false');
        }
      });
      item.classList.toggle('open', !isOpen);
      q.setAttribute('aria-expanded', (!isOpen).toString());
      a.style.maxHeight = !isOpen ? a.scrollHeight + 'px' : null;
    });
  });

  // Formulario de contacto en dos pasos
  var topicStep = document.getElementById('topic-step');
  var formStep = document.getElementById('form-step');
  if (topicStep && formStep) {
    var subjectField = formStep.querySelector('input[name="asunto"], input[name="subject"]');
    var topicValueEl = formStep.querySelector('.selected-topic-value');
    topicStep.querySelectorAll('.topic-card').forEach(function (card) {
      card.addEventListener('click', function () {
        var topic = card.getAttribute('data-topic');
        if (subjectField) subjectField.value = topic;
        if (topicValueEl) topicValueEl.textContent = topic;
        topicStep.classList.add('hidden');
        formStep.classList.remove('hidden');
        var firstField = formStep.querySelector('input[type="text"], input[type="email"]');
        if (firstField) firstField.focus();
      });
    });
    var backLink = document.getElementById('back-to-topics');
    if (backLink) {
      backLink.addEventListener('click', function () {
        formStep.classList.add('hidden');
        topicStep.classList.remove('hidden');
      });
    }
  }

  // Header con sombra al hacer scroll
  var lastY = window.scrollY;
  window.addEventListener('scroll', function () {
    if (!header) return;
    header.style.boxShadow = window.scrollY > 8 ? '0 4px 20px rgba(14,36,30,0.06)' : 'none';
    lastY = window.scrollY;
  });
});
