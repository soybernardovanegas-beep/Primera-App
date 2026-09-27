# Publicar Mi Red en Google Play

Guía para dejar la app lista para la tienda: seguridad, transparencia de
datos y control de las publicaciones. Lo que ya está hecho en la app está
marcado con ✅; lo que haces tú en Play Console, con 👉.

## 1. Crea apps seguras

### Ya incluido en la app ✅
- Todo viaja cifrado por HTTPS; la base de datos tiene seguridad a nivel de
  fila (cada usuario solo ve lo suyo).
- La app solo lleva la llave **publishable** de Supabase (nunca la secreta).
- Los respaldos automáticos de Android están desactivados: la sesión no se
  copia a la nube ni a otro teléfono (`allowBackup=false` y
  `data_extraction_rules.xml`).
- El código de la versión publicada va **ofuscado** y los números de versión
  suben solos en cada compilación de GitHub Actions.
- Permisos mínimos: internet, notificaciones y reprogramar avisos al
  reiniciar. No pide contactos, ubicación, cámara, micrófono ni fotos.

### 👉 Llave de firma (una sola vez)
Google Play exige que la app esté firmada con tu propia llave.

1. En tu computadora (PowerShell), crea la llave. `keytool` viene con Java o
   con Android Studio:
   ```
   keytool -genkey -v -keystore mi-red-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   Te pedirá una contraseña y tus datos. **Guarda el archivo `.jks` y la
   contraseña en un lugar seguro** (por ejemplo, Google Drive privado y un
   gestor de contraseñas). Si los pierdes, no podrás actualizar la app.
   Nunca los subas al repositorio.
2. Conviértela a texto para GitHub:
   ```
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("mi-red-upload.jks")) | Set-Clipboard
   ```
3. En GitHub → repositorio → **Settings → Secrets and variables → Actions →
   New repository secret**, crea:

   | Nombre | Valor |
   |---|---|
   | `ANDROID_KEYSTORE_BASE64` | lo que quedó copiado en el paso 2 |
   | `ANDROID_KEYSTORE_PASSWORD` | la contraseña de la llave |
   | `ANDROID_KEY_ALIAS` | `upload` |
   | `ANDROID_KEY_PASSWORD` | la misma contraseña |

Desde la siguiente compilación, GitHub Actions genera además el archivo
**`mi-red-aab`** (App Bundle), que es el que se sube a Google Play. Al
crear la app en Play Console acepta **Firma de apps de Google Play**:
Google guarda la llave final y tu llave queda solo como "llave de subida".

### 👉 API de Play Integrity
Sirve para que el servidor compruebe que quien usa la app es la versión
original instalada desde Google Play en un teléfono real (y no una copia
modificada o un bot). Se activa en dos partes:

1. **Play Console** → tu app → **Protección de la app / Integridad de la
   app** → vincula un proyecto de Google Cloud y activa la API de Play
   Integrity.
2. **En la app y en Supabase** (esto lo programo yo cuando tengas el paso 1):
   la app pide un "veredicto" a Google al iniciar sesión y una función de
   Supabase lo verifica con una cuenta de servicio de Google Cloud. Si el
   veredicto no es válido, se rechaza el acceso.

Para hacerlo necesito que me pases el **número del proyecto de Google Cloud**
(no es secreto) y que crees la cuenta de servicio siguiendo los pasos que te
daré en ese momento. Mientras la app no esté publicada en Play, la
verificación no puede funcionar, por eso se deja para ese momento.

## 2. Sé transparente con los datos

### Ya incluido en la app ✅
- **Política de privacidad** dentro de la app (Más → Privacidad y datos) y
  aviso al registrarse. El texto está en
  [`assets/legal/politica_privacidad.md`](assets/legal/politica_privacidad.md).
- **Borrar datos** y **eliminar la cuenta** desde la app (requisito de
  Google Play para apps con cuentas). Requiere ejecutar
  [`supabase/schema_v3.sql`](supabase/schema_v3.sql) en el SQL Editor.
- **Exportar contactos** a CSV.

### 👉 Publica la política de privacidad en una URL
Google Play pide un enlace público:
1. Abre `assets/legal/politica_privacidad.md`, reemplaza
   **[TU CORREO DE CONTACTO]** por un correo de soporte y copia el texto.
2. Pégalo en un documento de Google Docs → **Archivo → Compartir →
   Publicar en la Web** → copia el enlace.
3. Ese enlace va en Play Console → **Contenido de la app → Política de
   privacidad**. Usa el mismo enlace para **Eliminación de la cuenta**
   (la política explica cómo pedirla sin la app).

### 👉 Formulario de Seguridad de los datos
Play Console → **Contenido de la app → Seguridad de los datos**. Respuestas
para Mi Red tal como está hoy:

| Pregunta | Respuesta |
|---|---|
| ¿Recopila o comparte datos del usuario? | **Sí** |
| ¿Todos los datos se encriptan en tránsito? | **Sí** |
| ¿Los usuarios pueden solicitar que se borren sus datos? | **Sí** (en la app y por correo) |
| ¿Se comparten datos con terceros? | **No** (Supabase es un proveedor de servicio que procesa en tu nombre; no cuenta como "compartir") |

Tipos de datos **recopilados** (todos: *no se comparten*, *no efímeros*,
*obligatorio* solo el correo, finalidad **Funcionalidad de la app** y, para
el correo, también **Administración de la cuenta**):

| Categoría | Tipo | Por qué |
|---|---|---|
| Información personal | Dirección de correo electrónico | Cuenta de usuario |
| Información personal | Nombre | Tu nombre en el perfil (opcional) |
| Información personal | Números de teléfono, otra información | Datos de tus contactos que tú ingresas |
| Información financiera | Historial de compras | Ventas que registras |
| Mensajes / contenido | Otro contenido generado por el usuario | Notas, "porqué", historial, guías |

No marques: ubicación, contactos del teléfono, fotos, audio, archivos,
calendario, identificadores de dispositivo ni publicidad. Si en el futuro
se agrega algo (por ejemplo, analíticas o Play Integrity), hay que
actualizar este formulario.

### 👉 Otras secciones de "Contenido de la app"
- **Anuncios:** la app no tiene anuncios.
- **Acceso a la app:** Google revisa la app por dentro; crea un usuario de
  prueba en Supabase (Authentication → Add user, con *Auto Confirm User*)
  y pon ese correo y contraseña en esta sección.
- **Público objetivo:** mayores de 18 años.
- **Clasificación del contenido:** completa el cuestionario (categoría
  Productividad / Negocios; sin violencia ni contenido sensible).

## 3. Cumple las políticas y mantén el control

### 👉 Mantente al día con las políticas
- Revisa la **Bandeja de entrada** de Play Console y la página **Estado de
  las políticas**: ahí llegan los avisos con fecha límite.
- En Play Console → **Configuración → Preferencias de correo**, activa los
  correos de **Políticas y programas**.
- Una vez al año Google sube el nivel de API mínimo (*target SDK*). Cuando
  llegue ese aviso, pídeme actualizar Flutter y volver a compilar.
- Cada vez que cambie qué datos usa la app, actualiza la política de
  privacidad y el formulario de Seguridad de los datos.

### 👉 Publicación administrada
Así decides tú **cuándo** sale cada versión, aunque Google ya la haya
aprobado:
1. Play Console → tu app → **Descripción general de la publicación**.
2. En **Publicación administrada**, toca **Administrar** y actívala.
3. Sube la versión como siempre (**Producción → Crear versión**, subes el
   `app-release.aab` y envías a revisión).
4. Cuando Google la apruebe, quedará **lista para publicar**. Vuelve a
   *Descripción general de la publicación* y toca **Publicar cambios** en
   el momento que elijas.

Consejo: publica primero en **Prueba interna** (tú y hasta 100 testers)
antes de producción. Así revisas cada versión en tu teléfono sin que
nadie más la vea.

## Resumen de pasos

1. [ ] Ejecutar `supabase/schema_v3.sql` en Supabase.
2. [ ] Crear la llave de firma y los 4 secretos en GitHub.
3. [ ] Crear cuenta de desarrollador en Google Play (pago único de 25 USD).
4. [ ] Publicar la política de privacidad y pegar el enlace en Play Console.
5. [ ] Completar Seguridad de los datos, Acceso a la app, Público objetivo y
       Clasificación del contenido.
6. [ ] Activar la Publicación administrada.
7. [ ] Subir `app-release.aab` a Prueba interna y luego a Producción.
8. [ ] Vincular Google Cloud y activar Play Integrity; avisarme para
       programar la verificación.
