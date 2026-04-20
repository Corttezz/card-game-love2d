#!/bin/bash
# Helper: decodifica PNG base64 em arquivo. Uso:
#   save_sprite.sh <base64-string> <output-path>
# Exemplo:
#   save_sprite.sh "iVBORw0KGgo..." assets/sprites/icons/sword_short.png
#
# Se o MCP retornar PNG via URL em vez de base64, use curl -o direto.

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Uso: $0 <base64_png> <output_path>" >&2
    exit 1
fi

B64="$1"
OUT="$2"

mkdir -p "$(dirname "$OUT")"

# Remove possível prefixo "data:image/png;base64,"
B64="${B64#data:image/png;base64,}"

echo "$B64" | base64 -d > "$OUT"

if [[ -s "$OUT" ]]; then
    SIZE=$(stat -c %s "$OUT")
    echo "OK: $OUT ($SIZE bytes)"
else
    echo "ERRO: output vazio" >&2
    rm -f "$OUT"
    exit 2
fi
