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

2. En el Dashboard de Supabase, abre **SQL Editor** y ejecuta, en orden:
   1. [`supabase/schema.sql`](supabase/schema.sql) — tablas `books` y
      `reading_progress`.
   2. [`supabase/schema_kindle_features.sql`](supabase/schema_kindle_features.sql)
      — tablas de las funciones estilo Kindle: preferencias de lectura,
      marcadores, resaltados/notas, sesiones de lectura (estadísticas) y
      colecciones. Todas con Row Level Security, cada usuario solo ve sus
      propios datos.

3. En **Authentication → Providers**, confirma que el proveedor de
   correo/contraseña esté habilitado (viene activo por defecto).

## Ejecutar

```bash
flutter pub get
flutter run -d windows   # Windows
flutter run -d <device>  # Android (con un emulador o dispositivo conectado)
```

## Funciones estilo Kindle

- **Personalización de lectura**: tamaño y tipo de letra, interlineado y
  tema (claro/oscuro/sepia) — ícono de engranaje dentro del lector, se
  sincroniza entre dispositivos.
- **Marcadores**: guarda la posición actual con el ícono de marcador en la
  barra superior; consúltalos y salta a ellos desde el menú del lector o
  manteniendo presionado un libro en la biblioteca.
- **Resaltados y notas**: selecciona texto dentro del libro y elige
  "Resaltar" en el menú emergente para guardarlo con color y una nota
  opcional. Al ser un lector basado en párrafos (no en rango exacto de
  caracteres), el resaltado guarda el pasaje seleccionado como texto y su
  posición aproximada, no un subrayado visual permanente sobre el texto.
- **Búsqueda dentro del libro**: ícono de lupa en el lector — busca una
  palabra o frase y salta al capítulo donde aparece.
- **Estadísticas de lectura**: tiempo total leído, racha de días y tiempo
  estimado restante, accesible manteniendo presionado un libro en la
  biblioteca.
- **Texto a voz**: ícono de altavoz en el lector, lee el capítulo actual en
  voz alta usando el motor de voz del sistema operativo y avanza
  automáticamente de capítulo.
- **Diccionario**: selecciona una palabra dentro del libro y elige
  "Definir". Usa el servicio gratuito dictionaryapi.dev, por lo que solo
  cubre **inglés** y requiere conexión a internet.
- **Portadas y colecciones**: la biblioteca se muestra en cuadrícula con la
  portada de cada libro (si el EPUB la incluye); puedes crear colecciones y
  asignarles libros manteniendo presionada la portada.

## Estructura

```
lib/
  main.dart                        Inicializa Supabase y define el flujo auth → biblioteca
  models/                          Book, ReadingSettings, Bookmark, Highlight, BookCollection
  services/
    library_service.dart           Importar EPUB, hash, portada, upsert a Supabase
    progress_service.dart          Leer/guardar progreso de lectura
    settings_service.dart          Preferencias de lectura (fuente/tema)
    bookmarks_service.dart         Marcadores
    highlights_service.dart        Resaltados y notas
    stats_service.dart             Sesiones y estadísticas de lectura
    collections_service.dart       Colecciones de la biblioteca
    dictionary_service.dart        Definiciones vía dictionaryapi.dev
  screens/
    auth_screen.dart               Login / registro
    library_screen.dart            Biblioteca en cuadrícula con colecciones
    reader_screen.dart             Lector EPUB: progreso, marcadores, resaltados, búsqueda, TTS
    settings_screen.dart           Hoja de ajustes de apariencia
    bookmarks_screen.dart          Lista de marcadores
    highlights_screen.dart         Lista de resaltados/notas
    stats_screen.dart              Estadísticas de un libro
supabase/
  schema.sql                       Tablas base (books, reading_progress) + RLS
  schema_kindle_features.sql       Tablas de funciones Kindle + RLS
```
