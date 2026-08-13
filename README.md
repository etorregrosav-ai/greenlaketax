# Green Lake — sitio web

Sitio estático (HTML + CSS + JS vanilla, sin build tool) para Green Lake, asesoría fiscal y tributaria en España.

## Estructura

```
/assets/css/style.css   Sistema de diseño ("Green Lake"): paleta, tipografía, componentes
/assets/js/main.js      Menú móvil, acordeón de FAQs
/es/                    Sitio en español (idioma por defecto)
/en/                    Sitio en inglés
/index.html             Redirige a /es/index.html
/vercel.json            Redirección de "/" en Vercel
```

## Ver en local

```
python3 -m http.server 8000
```

Y abrir `http://localhost:8000/es/index.html`.

## Desplegar en Vercel (sin CLI, vía web)

Node.js no se pudo instalar en esta máquina (fallo reproducible compilando una dependencia), así que el despliegue se hace desde el dashboard de Vercel, sin CLI:

1. Entra en [vercel.com/new](https://vercel.com/new) con tu cuenta.
2. Elige la opción de subir una carpeta directamente (o arrastra la carpeta del proyecto sobre la página).
3. Selecciona la carpeta raíz de este proyecto (`greenlaketax/`) — no hace falta indicar framework ni build command, es HTML estático.
4. Despliega. Vercel te da una URL `*.vercel.app` al momento.

No requiere configuración adicional: es un sitio estático, Vercel lo sirve tal cual (incluye `vercel.json` con la redirección de "/" a "/es/index.html").

Si más adelante se instala Node y la CLI de Vercel, también sirve `vercel --prod` desde esta carpeta.

### Apuntar el dominio greenlaketax.com

1. En el dashboard de Vercel, añade `www.greenlaketax.com` (y `greenlaketax.com`) como dominio del proyecto.
2. Vercel indicará los registros DNS a configurar (normalmente un `CNAME` para `www` y un registro `A` para el dominio raíz).
3. Cambia esos registros en el proveedor DNS actual (donde esté gestionado el dominio, hoy apuntando a Google Sites).
4. Espera la propagación (unos minutos a 24-48h) — Vercel emite el certificado SSL automáticamente.

## Formulario de contacto

Las páginas de contacto (`/es/contacto.html`, `/en/contact.html`) usan [Formspree](https://formspree.io) (plan gratuito, sin backend propio):

1. Crea una cuenta y un formulario nuevo en formspree.io.
2. Sustituye `YOUR_FORM_ID` en el atributo `action` del `<form>` de ambas páginas por el ID real del formulario.

## Contenido

Todo el contenido de servicios (Inmuebles, Empresas, Trabajar en España, Ley Beckham) y FAQs procede de la web original en Google Sites — no se ha inventado ningún dato, precio o servicio. El único dato de contacto disponible en origen es el email `greenlaketaxservices@gmail.com`; no había teléfono, dirección física ni nombres de equipo publicados.

## Créditos de assets

- **Logo (ciervo):** silueta original de Matt Todd / Openclipart (2010), dominio público (CC0 1.0), vía [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Deer_Matt_Todd_01.svg). Adaptada de relleno sólido a trazo de línea. Uso comercial permitido sin atribución.
- **Imagen de cabecera (lago):** generada por el usuario con Gemini.

<!-- deploy check 2026-08-13T19:08:28Z -->
