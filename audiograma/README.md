# Audio a vídeo

App en Flutter para Android y Windows que convierte un audio (MP3, M4A,
WAV, OGG…) en un vídeo MP4: una imagen de fondo con una onda de sonido
animada que se mueve al ritmo del audio, el formato típico de "audiograma"
para pódcast y redes sociales.

Todo se procesa **en el dispositivo** con FFmpeg
([`ffmpeg_kit_flutter_new_min_gpl`](https://pub.dev/packages/ffmpeg_kit_flutter_new_min_gpl)):
no necesita internet, cuentas ni servidores, y el audio no sale del
teléfono o la computadora.

## Cómo se usa

1. **Audio**: elige el archivo. La app muestra su duración.
2. **Imagen de fondo** (opcional): se escala y se recorta al centro para
   llenar el formato. Sin imagen, se usa un fondo oscuro liso.
3. **Formato**: vertical 9:16 (TikTok, Reels, Shorts), cuadrado 1:1 o
   horizontal 16:9 (YouTube). Siempre en 1080p a 30 fps.
4. **Onda**: estilo (centrada, líneas o trazo) y color.
5. **Generar vídeo**: muestra el progreso y se puede cancelar. Al terminar,
   **Guardar** abre el diálogo para elegir dónde guardar el MP4 y
   **Compartir** lo manda directo a otra app (WhatsApp, Instagram, etc.).

La vista previa reproduce la misma composición del vídeo final con una
onda de ejemplo; la onda real se genera a partir del audio.

## Ejecutar

```bash
cd audiograma
flutter pub get
flutter run -d <dispositivo-android>
flutter run -d windows
```

- Android: requiere Android 7.0 (API 24) o superior.
- Windows: la primera compilación descarga las librerías de FFmpeg
  precompiladas, así que tarda un poco más y necesita internet esa vez.

## Detalles del vídeo

- Vídeo H.264 (`libx264`, CRF 23) + audio AAC 192 kbps, en MP4 con
  `faststart` para que empiece a reproducirse antes de descargarse completo.
- La duración del vídeo es exactamente la del audio.
- La onda se dibuja en el tercio inferior sobre una franja semitransparente,
  para que se vea bien sobre cualquier imagen.

**Licencia**: el paquete `_min_gpl` incluye x264, que es GPL. Para uso
personal no importa; si algún día distribuyes la app públicamente, la app
también tendría que publicarse bajo GPL (o cambiar a
`ffmpeg_kit_flutter_new_min` y otro códec de vídeo).

## Pruebas

```bash
flutter test
```

`test/ffmpeg_command_test.dart` revisa los argumentos de FFmpeg y, si hay un
`ffmpeg` instalado en el sistema, genera vídeos reales en los tres formatos
(con y sin imagen) y comprueba resolución y duración.

## Estructura

```
lib/
  main.dart                       Arranque y tema
  models/video_options.dart       Formatos, estilos/colores de onda y opciones del vídeo
  services/ffmpeg_command.dart    Arma los argumentos y el grafo de filtros de FFmpeg
  services/video_renderer.dart    Ejecuta FFmpeg/FFprobe: duración, progreso, cancelar
  widgets/video_preview.dart      Vista previa de la composición
  screens/editor_screen.dart      Pantalla única: elegir, generar, guardar, compartir
```
