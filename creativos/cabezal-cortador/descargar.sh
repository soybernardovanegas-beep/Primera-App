#!/usr/bin/env bash
# Descarga los clips de la carpeta pública de Drive a ./raw (el conector de Drive no ve esta carpeta).
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p raw
curl -sSL -o raw/folder.html "https://drive.google.com/embeddedfolderview?id=17D3F9wJw7AHHoKki9L-Tgr3E9p2YHhyR"
paste <(grep -oE 'file/d/[A-Za-z0-9_-]+' raw/folder.html | cut -d/ -f3) \
      <(grep -oE 'flip-entry-title">[^<]+' raw/folder.html | cut -d'>' -f2) |
while IFS=$'\t' read -r id n; do
  curl -sSL -o "raw/$n" "https://drive.usercontent.google.com/download?id=$id&export=download&confirm=t"
done
ls -la raw
