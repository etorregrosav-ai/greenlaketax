// GREEN LAKE — interacciones ligeras, sin dependencias

document.addEventListener('DOMContentLoaded', function () {
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
