// Green Lake /admin — notificaciones y confirmaciones propias del panel,
// para no depender de alert()/confirm() nativos del navegador.

function ensureToastStack() {
  let stack = document.getElementById("toast-stack");
  if (!stack) {
    stack = document.createElement("div");
    stack.id = "toast-stack";
    document.body.appendChild(stack);
  }
  return stack;
}

function toast(message, type) {
  const stack = ensureToastStack();
  const el = document.createElement("div");
  el.className = "toast" + (type === "error" ? " toast-error" : "");

  const icon = type === "error"
    ? '<svg class="toast-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 8v5M12 16h.01"/></svg>'
    : '<svg class="toast-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="m8 12 3 3 5-6"/></svg>';

  el.innerHTML = icon + '<span class="toast-text"></span><button class="toast-close" aria-label="Cerrar">&times;</button>';
  el.querySelector(".toast-text").textContent = message;
  stack.appendChild(el);

  const remove = () => {
    el.classList.add("leaving");
    setTimeout(() => el.remove(), 260);
  };
  el.querySelector(".toast-close").addEventListener("click", remove);
  const timer = setTimeout(remove, 5200);
  el.addEventListener("mouseenter", () => clearTimeout(timer));
}

// Genera y descarga un CSV a partir de cabeceras + filas (arrays de strings).
function downloadCSV(filename, headers, rows) {
  const escapeCell = (val) => {
    const str = val === null || val === undefined ? "" : String(val);
    return /[",\n;]/.test(str) ? '"' + str.replace(/"/g, '""') + '"' : str;
  };
  const lines = [headers, ...rows].map((row) => row.map(escapeCell).join(";"));
  const csv = "﻿" + lines.join("\r\n"); // BOM para que Excel detecte UTF-8 correctamente

  const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function confirmDialog(message, options) {
  const opts = options || {};
  const title = opts.title || "Confirmar";
  const confirmLabel = opts.confirmLabel || "Confirmar";
  const cancelLabel = opts.cancelLabel || "Cancelar";

  return new Promise((resolve) => {
    const overlay = document.createElement("div");
    overlay.id = "confirm-overlay";
    overlay.innerHTML =
      '<div class="confirm-card">' +
        '<h3></h3><p></p>' +
        '<div class="form-actions">' +
          '<button class="btn btn-primary" id="confirm-ok"></button>' +
          '<button class="btn btn-outline" id="confirm-cancel"></button>' +
        '</div>' +
      '</div>';
    overlay.querySelector("h3").textContent = title;
    overlay.querySelector("p").textContent = message;
    overlay.querySelector("#confirm-ok").textContent = confirmLabel;
    overlay.querySelector("#confirm-cancel").textContent = cancelLabel;
    document.body.appendChild(overlay);

    function cleanup(result) {
      document.removeEventListener("keydown", onKey);
      overlay.remove();
      resolve(result);
    }
    function onKey(e) {
      if (e.key === "Escape") cleanup(false);
      if (e.key === "Enter") cleanup(true);
    }

    overlay.querySelector("#confirm-ok").addEventListener("click", () => cleanup(true));
    overlay.querySelector("#confirm-cancel").addEventListener("click", () => cleanup(false));
    overlay.addEventListener("click", (e) => { if (e.target === overlay) cleanup(false); });
    document.addEventListener("keydown", onKey);
    overlay.querySelector("#confirm-ok").focus();
  });
}
