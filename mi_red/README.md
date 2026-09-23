# Mi Red

CRM para tu negocio de network marketing, pensado para usarse desde el
celular Android (también compila para iOS). Guarda tus datos en Supabase, así
que no se pierden si cambias de teléfono y puedes usar varios dispositivos.

## Qué hace

- **Hoy**: seguimientos del día y atrasados (con botón directo a WhatsApp),
  ventas y puntos del mes, contactos nuevos, número de socios y tu embudo
  por etapa.
- **Contactos**: tu lista de prospectos, clientes y socios con búsqueda y
  filtro por etapa (Nuevo → Contactado → Presentación → Seguimiento →
  Cliente / Socio, o No interesado). Cada ficha tiene:
  - Llamar y abrir WhatsApp con un toque.
  - Cambio de etapa con un toque.
  - Próximo seguimiento: mañana, en 3 días, en 1 semana o fecha a elegir.
  - Historial de interacciones (llamada, WhatsApp, reunión, presentación).
  - Sus compras y el total que te ha comprado.
- **Equipo**: árbol de tu red. Cuando un contacto pasa a *Socio* y le
  indicas quién lo patrocinó, se acomoda debajo de esa persona.
- **Ventas**: pedidos por mes con monto, puntos (PV) y a quién se vendió.
  Al registrar una venta a un prospecto, pasa automáticamente a *Cliente*.

## Configuración

1. Copia `.env.example` a `.env` y coloca tu URL y llave pública de
   Supabase (puedes usar el mismo proyecto del lector EPUB y Bitácora):

   ```
   SUPABASE_URL=https://tu-proyecto.supabase.co
   SUPABASE_ANON_KEY=tu-clave-publica
   ```

2. En el SQL Editor de Supabase, ejecuta [`supabase/schema.sql`](supabase/schema.sql).
   Crea las tablas `crm_contacts`, `crm_interactions` y `crm_sales` con Row
   Level Security (cada usuario solo ve sus propios datos). No modifica las
   tablas de las otras apps.

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
al teléfono (Drive, WhatsApp, cable) y ábrelo; Android te pedirá permitir
instalar apps de origen desconocido.

## Notas

- Los teléfonos deben incluir la **clave de país** (p. ej. `52` México,
  `57` Colombia, `1` EE. UU.) para que el botón de WhatsApp funcione.
- El símbolo de moneda es `$`; se cambia en `lib/widgets/common.dart`.
- Ícono fuente en `assets/icon/icon.png`. Si lo cambias, vuelve a correr
  `dart run flutter_launcher_icons`.

## Estructura

```
lib/
  main.dart                         Inicializa Supabase y el flujo auth → app
  models/contact.dart               Contacto, etapas del embudo e interés
  models/interaction.dart           Interacciones (llamada, WhatsApp, ...)
  models/sale.dart                  Venta con monto y puntos
  services/crm_service.dart         Todas las consultas a Supabase
  widgets/common.dart               Avatar, chip de etapa, llamar/WhatsApp
  screens/auth_screen.dart          Login / registro
  screens/home_shell.dart           Navegación inferior (Hoy/Contactos/Equipo/Ventas)
  screens/dashboard_screen.dart     Resumen del día
  screens/contacts_screen.dart      Lista con búsqueda y filtros
  screens/contact_detail_screen.dart Ficha, seguimiento e historial
  screens/contact_form_screen.dart  Alta / edición de contacto
  screens/team_screen.dart          Árbol de socios
  screens/sales_screen.dart         Ventas por mes y formulario de venta
supabase/schema.sql                 Tablas + políticas RLS
test/contact_test.dart              Pruebas de modelos
```
