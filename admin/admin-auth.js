// Green Lake /admin — comprobación de sesión compartida por las páginas protegidas.
// Requiere que config.js y el script de supabase-js ya estén cargados antes que este archivo.

const supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function requireSession() {
  const { data: { session } } = await supabaseClient.auth.getSession();
  if (!session) {
    window.location.href = "login.html";
    return null;
  }
  const emailEl = document.getElementById("user-email");
  if (emailEl) emailEl.textContent = session.user.email;
  return session;
}

function wireSignOut() {
  const btn = document.querySelector(".signout");
  if (!btn) return;
  btn.addEventListener("click", async () => {
    await supabaseClient.auth.signOut();
    window.location.href = "login.html";
  });
}

document.addEventListener("DOMContentLoaded", wireSignOut);
