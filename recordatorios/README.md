# Recordatorios

App para Android con un **diario de 90 días** (la intención de la mañana y la
cuenta de la noche) y **recordatorios** a la hora que tú quieras, con un
widget en la pantalla de inicio. Todo se guarda en el teléfono: no necesita
cuenta ni internet.

La barra de abajo tiene cuatro pestañas: **Hoy · Progreso · Historial ·
Avisos**.

## Diario de 90 días

- **Hoy**: el día del programa ("Día 5 / 90"), la fecha de inicio (toca
  "cambiar fecha de inicio" para ajustarla), la pregunta del día y las
  tarjetas **Mañana — la intención** y **Noche — la cuenta**, con su estado
  (pendiente / completado), tu racha y tu alcance total.
- **Recordatorio del día**: cada día llega una notificación con una pregunta
  de reflexión (5:00 p. m. por defecto; toca el recuadro para cambiar la
  hora).
- **Mañana**: personas a mover hoy (contactar / presentar / seguir), evento,
  meta de prospectos, a quién invitar, energía de inicio, compromisos de la
  mañana y la una cosa que no puede fallar. "Sellar la intención".
- **Noche**: a quién moviste (contacté / presenté / seguí, que alimenta los
  contadores), prospectos nuevos, lo que hiciste, a quién sigues mañana,
  compromisos cumplidos, si el equipo se movió sin ti, energía de cierre,
  miedo y afirmación contraria, y si sumaste a alguien. "Cerrar la cuenta".
- **Progreso**: totales de los 90 días, racha de días completos, gráfica de
  energía de inicio vs. cierre y porcentaje de cumplimiento de compromisos.
- **Historial**: cada día registrado; tócalo para revisarlo o completarlo.
- Todo se guarda solo (guardado automático).

Los compromisos, eventos, frases y preguntas del día están en
[`lib/diary/content.dart`](lib/diary/content.dart) por si quieres cambiarlos.

## Recordatorios (pestaña Avisos)

- **Crear recordatorios** con título, nota opcional y hora.
- **Repetición**: una sola vez (en una fecha), todos los días, o ciertos
  días de la semana (p. ej. lunes, miércoles y viernes).
- **Notificación a la hora exacta**, aunque la app esté cerrada. Se vuelven
  a programar solas si reinicias el teléfono.
- **Widget de pantalla de inicio** con los próximos 6 recordatorios
  ("Hoy 18:30", "Mañana 08:00"...). Se actualiza solo a la hora de cada
  recordatorio y a medianoche. Tocarlo abre la app.
- Activar/desactivar un recordatorio con el interruptor, tocarlo para
  editarlo y deslizarlo a la izquierda para borrarlo (con "Deshacer").

## Ejecutar

```bash
cd recordatorios
flutter pub get
flutter run -d <dispositivo-android>
```

O instala el APK que genera GitHub Actions: en la pestaña **Actions** del
repositorio abre la última ejecución de "Recordatorios APK" y descarga el
artefacto `recordatorios-apk`. Al instalarlo, Android te pedirá permitir
"instalar apps de origen desconocido".

## Poner el widget en la pantalla de inicio

- Desde la app: botón <kbd>📱+</kbd> de la barra superior (en launchers que
  lo permiten).
- O a mano: mantén presionado un espacio vacío de la pantalla de inicio →
  **Widgets** → **Recordatorios** → arrástralo.

## Si un aviso no llega

- Acepta el permiso de notificaciones la primera vez que abres la app (si
  lo negaste, la app muestra un aviso con el botón "Permitir").
- Algunos fabricantes (Xiaomi, Huawei, Samsung, Oppo…) cierran apps en
  segundo plano para ahorrar batería. Si los avisos llegan tarde o no
  llegan, ve a **Ajustes → Apps → Recordatorios → Batería** y elige
  "Sin restricciones".
