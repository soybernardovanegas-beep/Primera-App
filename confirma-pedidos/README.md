# Confirma Pedidos

App web instalable (PWA) para confirmar pedidos contraentrega:

1. **Pegas** los datos del pedido (de Dropi, Shopify/Releasit, un chat, como vengan; uno o varios a la vez).
2. La app saca **nombre, celular, dirección, barrio, ciudad, departamento, cantidad y total**
   (si no viene el total, lo calcula con tus precios x1 / x2 / x3).
3. **Guardar contacto** descarga un `.vcf`; al abrirlo el celular muestra el contacto listo y tocas *Guardar*.
   Con varios pedidos, "Guardar todos" los mete en un solo archivo.
4. **Confirmar por WhatsApp** abre WhatsApp Business con el chat del cliente y el mensaje ya escrito; solo tocas *Enviar*.

Todo queda en el celular (historial y ajustes en el navegador). No hay servidor ni base de datos.

## Formatos que entiende

Con etiquetas (`Nombre:`, `Teléfono:`/`Cel:`/`WhatsApp:`, `Dirección:`, `Barrio:`, `Ciudad:`,
`Departamento:`, `Cantidad:`, `Total:`, `Notas:`, con o sin emojis) o sin etiquetas
(nombre, celular, dirección y ciudad en líneas separadas). Varios pedidos se separan con una línea
en blanco o `---`. Todo se puede corregir a mano antes de enviar.

## Ajustes

Negocio, producto, precios, cómo se nombra el contacto (`{nombre_completo} (XOLVETA)`) y el mensaje
de confirmación con variables `{nombre} {direccion} {ciudad} {total}`, etc.
La casilla *Abrir directo en WhatsApp Business* hace que en Android se abra la app Business y no la normal.

## Cómo usarla en el celular

Necesita estar publicada en una dirección `https://`. Lo más fácil:

- **Netlify Drop** (gratis, 1 minuto): entra a app.netlify.com/drop y arrastra esta carpeta.
- **GitHub Pages**: copia esta carpeta a `docs/` en la rama principal y activa Pages desde `/docs`.

Luego ábrela en Chrome del celular → menú ⋮ → **Agregar a pantalla principal**. Una vez instalada,
también aparece en el menú **Compartir** de Android: compartes el texto del pedido desde otra app
y se procesa solo.

## Límites (y cómo superarlos)

- **El contacto no se guarda 100 % en silencio**: el navegador no puede escribir en la agenda;
  toca un "Guardar". Para que sea totalmente automático hay dos caminos: una app nativa Android
  (Flutter + permiso de contactos) o guardarlo en Google Contacts por API, que se sincroniza solo al celular.
- **El mensaje no se envía solo**: WhatsApp exige que toques *Enviar*. El envío automático requiere la
  **API oficial de WhatsApp Business (Cloud API de Meta)**: verificación del negocio, plantilla aprobada
  y un costo por conversación iniciada por la empresa.
