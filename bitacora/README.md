# Bitácora

App de agenda semanal para Android e iOS: pendientes por día, notas libres
y búsqueda, todo sincronizado entre dispositivos con Supabase (usa el mismo
proyecto de Supabase que el lector EPUB de este repositorio).

## Configuración

1. Copia `.env.example` a `.env` y coloca tu URL y llave pública de
   Supabase:

   ```
   SUPABASE_URL=https://tu-proyecto.supabase.co
   SUPABASE_ANON_KEY=tu-clave-publica
   ```

2. En el SQL Editor de Supabase, ejecuta [`supabase/schema.sql`](supabase/schema.sql).
   Crea las tablas `agenda_items` y `agenda_notes` con Row Level Security.
   Si ya ejecutaste los scripts del lector EPUB en el mismo proyecto, esto
   solo agrega las tablas nuevas, no toca las existentes.

## Ejecutar

```bash
flutter pub get
flutter run -d <dispositivo-android>
```

### Sobre iOS

El proyecto ya incluye el target de iOS (carpeta `ios/`) y el ícono
generado para ambas plataformas, pero **compilar y ejecutar en iOS requiere
una Mac con Xcode instalado** — no es posible hacerlo desde Windows/Linux.
Opciones para probarlo en iPhone:

- Abrir este proyecto en una Mac y correr `flutter run -d <iphone>`.
- Usar un servicio de build en la nube para Flutter (Codemagic, Ionic
  Appflow, etc.) que compile el `.ipa` sin necesitar una Mac propia.

## Ícono y nombre

- Nombre de la app: **Bitácora**.
- Ícono fuente en `assets/icon/icon.png` (1024×1024), generado a partir de
  ahí para todas las resoluciones de Android e iOS con el paquete
  `flutter_launcher_icons`. Si cambias la imagen, vuelve a correr:
  ```bash
  dart run flutter_launcher_icons
  ```

## Estructura

```
lib/
  main.dart                    Inicializa Supabase, fechas en español y el flujo auth → agenda
  models/agenda_item.dart      Modelo de pendiente
  services/agenda_service.dart Pendientes por rango de fechas, búsqueda
  services/notes_service.dart  Notas libres (una por usuario)
  screens/auth_screen.dart     Login / registro
  screens/week_screen.dart     Vista semanal con los 7 días
  screens/day_screen.dart      Pendientes de un día (agregar/tachar/eliminar)
  screens/notes_screen.dart    Notas libres con autoguardado
  screens/search_screen.dart   Búsqueda de pendientes por texto
supabase/schema.sql            Tablas + políticas RLS para ejecutar en Supabase
```
