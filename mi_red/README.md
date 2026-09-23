# Mi Red 💎

CRM para tu negocio de network marketing, pensado para el celular Android
(también compila para iOS). Tus datos viven en Supabase: no se pierden si
cambias de teléfono y puedes usar varios dispositivos.

## Pantallas

La barra inferior tiene **Inicio · CRM · (+) · Proceso · Más**.

- **Inicio**: tu día (recordatorios vencidos y de hoy, llamadas hechas),
  acceso a la Hora de Poder, ventas y puntos del mes, calidad de tu lista
  (Ideal / Potencial / Incierto) y tu embudo por etapa.
- **CRM**: meta "X de 20 contactos ideales", importar/exportar, filtros
  (temperatura, favoritos, etapa, etiqueta, origen), pestañas
  Total / Ideal 🦈 / Potencial 🐬 / Incierto 🦔 y búsqueda por nombre,
  teléfono o etiqueta. Mantén presionado un contacto (o toca el ícono ☑)
  para seleccionar varios y cambiarles la etapa, la temperatura o
  eliminarlos.
- **(+) Nuevo contacto**: nombre, teléfono, referido por, origen, etiquetas,
  enfoque y temperatura → **Comenzar Calificación** (4 preguntas):

  | Pregunta | Opciones (puntos) |
  |---|---|
  | Edad | 18–25 (2) · 26–45 (3) · 46+ (1) |
  | Credibilidad | Nula (1) · Parcial (3) · Total (5) |
  | Actitud y solvencia | No emprendedor sin/con solvencia (1/2) · Emprendedor sin/con solvencia (4/6) |
  | Comportamiento social | Erizo (1) · Ballena (2) · Delfín (4) · Tiburón (6) |

  Total sobre 20: **Ideal 🦈 15–20**, **Potencial 🐬 10–14**,
  **Incierto 🦔 9 o menos** (se cambia en `lib/models/qualification.dart`).
- **Proceso**: buscador, filtro Producto / Negocio / Ambos, guías
  (Objeciones, Prospección, Redes, Seguimiento), Hora de Poder,
  recordatorios **Vencidos** y **Próximos** con ✓ para completarlos, y las
  tarjetas de cada etapa con llamar, WA, Sugerir, No interesado,
  **Avanzar →**, favorito y eliminar. Los contactos pausados o descartados
  no aparecen aquí.
- **Ficha del contacto**: Modo Llamada en Vivo, teléfono con Llamar /
  WhatsApp / Sugerir, etiquetas, puntuación (y recalificar), etapa, enfoque
  de conversación, **recordatorios múltiples** (al completar uno aparece el
  siguiente; cada uno se puede enviar por WhatsApp, a Google Calendar o como
  archivo .ics, y tiene "Insertar Mi Porqué"), **Contactar después**
  (3, 6, 10 meses o 1 año), notas, **Su Porqué** (ingresos y salud),
  historial y compras. Las notas y el porqué se guardan solos.
- **Modo Llamada en Vivo**: el guion según el enfoque (producto o negocio,
  con tu porqué incluido), respuestas a objeciones y botones de resultado:
  - *No contestó* → recordatorio mañana a la misma hora.
  - *Agendó cita* → eliges fecha y hora, pasa a Presentación.
  - *Seguimiento* → recordatorio en 3 días, pasa a Seguimiento.
  - *No interesado* → pasa a No interesado.

  Cada resultado queda en el historial.
- **Hora de Poder**: cronómetro de 60 min con la pantalla siempre
  encendida y una fila de llamadas (primero los vencidos, luego mayor
  puntaje y los calientes). Cuenta tus llamadas y resultados.
- **Sugerir**: mensajes de WhatsApp listos según la etapa y el enfoque,
  usando el nombre y su porqué. Son plantillas (sin IA, sin costo) que puedes
  editar antes de enviar; están en `lib/content/message_templates.dart`.
- **Más**: mi perfil (nombre, **Mi Porqué**, meta de ideales), mi equipo
  (árbol de socios), ventas, guías y guiones (editables desde la app),
  contactos pausados/descartados, importar, exportar y cerrar sesión.

### Importar y exportar

- Acepta **.xlsx**, **.csv**, **.vcf** (contactos del teléfono o del
  iPhone) o pegar filas copiadas de Excel / Google Sheets.
- Columnas: **Nombre** (obligatoria), Teléfono, Referido, Origen,
  Etiquetas (también reconoce Ciudad, Correo, Notas). Si no hay
  encabezados, se asume ese orden.
- Antes de guardar muestra una vista previa y desmarca los posibles
  duplicados (mismo teléfono o mismo nombre).
- **Exportar** genera un CSV que abre en Excel y se puede volver a
  importar. Sirve para traer tus contactos de otra app: exporta desde allá e
  importa aquí.

### WhatsApp y teléfonos

A los números de 10 dígitos se les agrega automáticamente el **57**
(Colombia) para WhatsApp. Si el número empieza con `+` se respeta tal cual.
Si escribiste una nota en el campo del teléfono (p. ej. "está en
Instagram"), la app no intenta llamar.

## Configuración

1. Copia `.env.example` a `.env` y coloca tu URL y llave pública de
   Supabase (puede ser el mismo proyecto del lector EPUB y Bitácora):

   ```
   SUPABASE_URL=https://tu-proyecto.supabase.co
   SUPABASE_ANON_KEY=tu-clave-publica
   ```

2. En el **SQL Editor** de Supabase ejecuta, en orden:
   1. [`supabase/schema.sql`](supabase/schema.sql): contactos,
      interacciones y ventas.
   2. [`supabase/schema_v2.sql`](supabase/schema_v2.sql): calificación,
      recordatorios, perfil y guías. Si ya usabas la versión anterior, pasa
      tus "próximo seguimiento" a recordatorios. No borra datos y se puede
      ejecutar más de una vez.

## Instalar en tu Android

Con el teléfono conectado por USB (y la depuración USB activada en
*Opciones de desarrollador*):

```bash
flutter pub get
flutter run -d <dispositivo-android>
```

O genera un APK para instalarlo sin cable:

```bash
flutter build apk --release
```

El archivo queda en `build/app/outputs/flutter-apk/app-release.apk`. Pásalo
al teléfono y ábrelo; Android te pedirá permitir instalar apps de origen
desconocido. La primera vez, acepta el permiso de **notificaciones** para
recibir los avisos de tus recordatorios.

## Estructura

```
lib/
  main.dart                        Supabase, tema oscuro/dorado, avisos, auth → app
  content/guides.dart              Textos de guías y guiones (editables en la app)
  content/message_templates.dart   Plantillas de "Sugerir"
  models/contact.dart              Contacto, etapas, enfoque, temperatura, "Avanzar"
  models/qualification.dart        Las 4 preguntas, puntos y categorías
  models/reminder.dart             Recordatorios y el vigente por contacto
  models/profile.dart              Tu nombre, tu porqué y tu meta
  models/interaction.dart          Llamadas, WhatsApp, reuniones...
  models/sale.dart                 Ventas con monto y puntos
  services/crm_service.dart        Todas las consultas a Supabase
  services/notification_service.dart  Avisos programados en el teléfono
  services/import_export.dart      Lectura de CSV/Excel/vCard y exportación
  services/calendar_links.dart     Google Calendar, .ics y compartir archivos
  widgets/common.dart              Componentes y colores compartidos
  widgets/sheets.dart              Nuevo recordatorio, Sugerir, enviar a calendario
  widgets/bulk.dart                Acciones sobre varios contactos
  screens/home_shell.dart          Barra inferior con el botón (+)
  screens/home_screen.dart         Inicio
  screens/crm_screen.dart          CRM
  screens/process_screen.dart      Proceso de negocios
  screens/more_screen.dart         Más (y contactos pausados)
  screens/contact_form_screen.dart Nuevo / editar contacto
  screens/qualification_screen.dart Cuestionario de calificación
  screens/contact_detail_screen.dart Ficha del contacto
  screens/call_mode_screen.dart    Modo Llamada en Vivo
  screens/power_hour_screen.dart   Hora de Poder
  screens/guides_screen.dart       Guías (ver y editar)
  screens/import_screen.dart       Importar contactos
  screens/profile_screen.dart      Mi perfil
  screens/team_screen.dart         Árbol de tu equipo
  screens/sales_screen.dart        Ventas por mes
supabase/schema.sql, schema_v2.sql Tablas y políticas RLS
test/                              Pruebas de modelos, calificación e importación
```
