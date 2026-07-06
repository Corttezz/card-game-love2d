#!/usr/bin/env bash
# Helper: generate a single SFX via ElevenLabs sound-generation API.
# Usage: gen_sfx.sh <filename> <duration> <influence> <prompt>
# Requires ELEVENLABS_API_KEY env var.
set -euo pipefail

FILE="$1"
DURATION="$2"
INFLUENCE="$3"
PROMPT="$4"

OUT_DIR="$(cd "$(dirname "$0")/.." && pwd)/audio/sfx"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/$FILE"

PAYLOAD=$(cat <<JSON
{"text":"$PROMPT","duration_seconds":$DURATION,"prompt_influence":$INFLUENCE}
JSON
)

HTTP=$(curl -sS -w "%{http_code}" -o "$OUT" \
  -X POST "https://api.elevenlabs.io/v1/sound-generation" \
  -H "xi-api-key: $ELEVENLABS_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

SIZE=$(stat -c %s "$OUT" 2>/dev/null || echo 0)

if [[ "$HTTP" == "200" && "$SIZE" -gt 1000 ]]; then
  printf "OK  %-28s %7d bytes  %ss @%s\n" "$FILE" "$SIZE" "$DURATION" "$INFLUENCE"
else
  printf "ERR %-28s HTTP=%s size=%d\n" "$FILE" "$HTTP" "$SIZE"
  head -c 300 "$OUT"
  echo
  exit 1
fi
