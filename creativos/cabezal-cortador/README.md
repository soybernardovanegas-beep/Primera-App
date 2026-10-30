# Creativos: cabezal cortador de lámina para taladro

7 videos 9:16 para Meta Ads (6 ángulos + uno de tijera), con columna lateral de oferta:
$99.900 · Envío a toda Colombia · 2 x $169.900 (ahorras $29.900) · Pagas al recibir · No incluye taladro.

## Reconstruir

```bash
./descargar.sh            # baja los 11 clips de Drive a ./raw
python3 -I build.py       # genera out/AD1..AD7 (sin voz)
```

- `ads.json`: por video, gancho, tramos (clip, inicio, duración) y subtítulo de cada tramo.
- `build.py`: recorta/normaliza los clips, pone gancho, subtítulos, columna de oferta y cierre.
  Si un video tiene `"audio": "<ruta.wav>"` en `ads.json`, lo usa como pista de audio.

## Voz (pendiente)

Locución con Gemini TTS (secreto `x-goog-api-key` para `generativelanguage.googleapis.com`
configurado en el entorno). Texto de la voz = gancho + subtítulos de cada video, en español de Colombia.
Ajustar la duración de cada tramo a la voz o la voz a los tramos, y volver a correr `build.py`.

## Notas de cumplimiento

- Los clips fuente son de otros creadores/competencia: se quitó su audio y se recortaron subtítulos,
  logos (Squadra, Todo Útil, SATA) y el sello "AI" del clip dropkiller-1632….
- AD3 no muestra tiempos: no hay grabación cronometrada real.
- AD4 no usa "Primera vez que lo uso": sería un testimonio inventado.
