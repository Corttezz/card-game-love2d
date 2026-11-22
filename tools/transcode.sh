#!/usr/bin/env bash
# Versões web dos trailers (cada arquivo < 25 MiB, limite dos static assets do Workers). Um ffmpeg por vez.
set -euo pipefail
SRC=/e/dev/projects/card-game-trailer/build/trailer
OUT=public/media
enc() { # in out vbitrate fps
  ffmpeg -y -v error -i "$1" -vf "scale=1280:720:flags=neighbor,fps=$4" -c:v libx264 -preset slow -b:v "$3" -pass 1 -an -f mp4 -passlogfile tools/out/x264 NUL
  ffmpeg -y -v error -i "$1" -vf "scale=1280:720:flags=neighbor,fps=$4" -c:v libx264 -preset slow -b:v "$3" -pass 2 -passlogfile tools/out/x264 -c:a aac -b:a 128k -movflags +faststart -pix_fmt yuv420p "$2"
}
mkdir -p tools/out
enc "$SRC/runemoire_gameplay_720p.mp4" "$OUT/runemoire-gameplay.mp4" 2100k 60
enc "$SRC/runemoire_trailer_c13c_720p.mp4" "$OUT/runemoire-trailer.mp4" 2000k 30
ffmpeg -y -v error -ss 8 -i "$SRC/runemoire_trailer_c13c_720p.mp4" -frames:v 1 -vf "scale=1280:720:flags=neighbor" -q:v 3 "$OUT/runemoire-trailer.jpg"
ffmpeg -y -v error -ss 12 -i "$SRC/runemoire_gameplay_720p.mp4" -frames:v 1 -vf "scale=1280:720:flags=neighbor" -q:v 3 "$OUT/runemoire-gameplay.jpg"
# trailer do site desde 21/11: corte 14 v7, do master 1080p (60 fps, 85,6 s; 2100k + 160k cabe nos 25 MiB)
enc2() { # in out
  ffmpeg -y -v error -i "$1" -vf "scale=1280:720:flags=lanczos" -c:v libx264 -preset slow -b:v 2100k -pass 1 -an -f mp4 -passlogfile tools/out/x264 NUL
  ffmpeg -y -v error -i "$1" -vf "scale=1280:720:flags=lanczos" -c:v libx264 -preset slow -b:v 2100k -pass 2 -passlogfile tools/out/x264 -c:a aac -b:a 160k -movflags +faststart -pix_fmt yuv420p "$2"
}
enc2 "$SRC/runemoire_trailer_c14v7_1080p.mp4" "$OUT/runemoire-trailer-c14v7.mp4"
ffmpeg -y -v error -ss 72 -i "$SRC/runemoire_trailer_c14v7_1080p.mp4" -frames:v 1 -vf "scale=1280:720:flags=lanczos" -q:v 3 "$OUT/runemoire-trailer-c14v7.jpg"
ls -la $OUT
