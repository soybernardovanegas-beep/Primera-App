# Recordatorios

App para Android que te avisa de lo que tú quieras, a la hora que tú quieras,
y te muestra los próximos recordatorios en un **widget de la pantalla de
inicio**. Todo se guarda en el teléfono: no necesita cuenta ni internet.

## Qué hace

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
