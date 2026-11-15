# Cierres con precio nuevo — XOLVETA cabezal cortador

Misma configuración que `creativos/cabezal-cortador/voz.py` (rama claude/jolly-ride-q2f97s):
Gemini TTS `gemini-3.1-flash-tts-preview`, voz `Puck`, mismo prompt de estilo, cierre acelerado `atempo=1.12`.
Posproceso: recorte de silencios, loudnorm -16 LUFS (TP -1.5), 44.1 kHz mono, MP3 192 kbps.

| Archivo | Trato | Duración (x1.12) | `sin-acelerar/` |
|---|---|---|---|
| cierre-AD12.mp3 | usted | 9,46 s | 10,58 s |
| cierre-AD13.mp3 | tú | 10,00 s | 11,18 s |
| cierre-AD14.mp3 | tú (= AD13) | 10,00 s | 11,18 s |
| cierre-AD16.mp3 | tú (= AD13) | 10,00 s | 11,18 s |
| cierre-AD15.mp3 | usted, regalo | 11,36 s | 12,72 s |
