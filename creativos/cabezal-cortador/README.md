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

## Voz

```bash
python3 -I voz.py         # Gemini TTS -> voz/<name>.wav, ajusta tramos y pone "audio" en ads.json
python3 -I build.py
```

- Modelo `gemini-3.1-flash-tts-preview`, voz `Puck`, español de Colombia, tono vendedor. Sin música.
- Texto = gancho + subtítulos de cada video (cifras dichas en palabras: "ciento sesenta y nueve mil novecientos").
- Una sola petición por video (la cuota gratis de TTS es de pocas peticiones al día); la locución se corta
  por las pausas entre líneas y cada tramo dura lo que su frase + 0,3 s. El cierre (3,5 s) va sin voz.
- `gemini-2.5-flash-preview-tts` permite 10 peticiones/día en el plan gratis; `gemini-3.8-flash-tts`
  lee en voz alta las instrucciones de estilo, por eso no se usa.
- Las locuciones finales están versionadas en `voz/` para no tener que regenerarlas.

## Notas de cumplimiento

- Los clips fuente son de otros creadores/competencia: se quitó su audio y se recortaron subtítulos,
  logos (Squadra, Todo Útil, SATA) y el sello "AI" del clip dropkiller-1632….
- AD3 no muestra tiempos: no hay grabación cronometrada real.
- AD4 no usa "Primera vez que lo uso": sería un testimonio inventado.
