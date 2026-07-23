# Lector EPUB

App de lectura de EPUB en Flutter para Android y Windows, con progreso de
lectura sincronizado entre dispositivos vía Supabase.

## Cómo funciona la sincronización

- Cada libro se identifica por el **hash SHA-256** de su archivo, no por su
  nombre. Así, si importas el mismo EPUB por separado en Android y en
  Windows, ambos se reconocen como el mismo libro sin necesidad de subir el
  archivo en sí a la nube (evita costos de almacenamiento y no requiere
  volver a alojar el contenido con derechos de autor).
- Lo que sí viaja por Supabase es: título/autor del libro y tu **posición de
  lectura** (un EPUB CFI) más el porcentaje avanzado. Al abrir un libro se
  restaura automáticamente la última posición guardada, sin importar en qué
  dispositivo la dejaste.

## Configuración

1. Copia `.env.example` a `.env` y coloca tu URL y llave pública (anon /
   publishable) de Supabase:

   ```
   SUPABASE_URL=https://tu-proyecto.supabase.co
   SUPABASE_ANON_KEY=tu-clave-publica
   ```

   `.env` está en `.gitignore`: nunca se sube al repositorio.

2. En el Dashboard de Supabase, abre **SQL Editor** y ejecuta el contenido
   de [`supabase/schema.sql`](supabase/schema.sql). Esto crea las tablas
   `books` y `reading_progress` con Row Level Security, de modo que cada
   usuario solo puede leer/escribir sus propios datos.

3. En **Authentication → Providers**, confirma que el proveedor de
   correo/contraseña esté habilitado (viene activo por defecto).

## Ejecutar

```bash
flutter pub get
flutter run -d windows   # Windows
flutter run -d <device>  # Android (con un emulador o dispositivo conectado)
```

## Estructura

```
lib/
  main.dart                  Inicializa Supabase y define el flujo auth → biblioteca
  models/book.dart            Modelo de libro
  services/library_service.dart    Importar EPUB, hash, upsert a Supabase
  services/progress_service.dart   Leer/guardar progreso de lectura
  screens/auth_screen.dart         Login / registro
  screens/library_screen.dart      Biblioteca del usuario
  screens/reader_screen.dart       Lector EPUB con guardado de progreso
supabase/schema.sql          Esquema SQL + políticas RLS para ejecutar en Supabase
```
