#!/bin/bash
# animate_icon.sh - anima um ícone estático via PixelLab /animate-with-text.
# Uso: ./scripts/animate_icon.sh <icon_name> "<description>" "<action>" [n_frames]
# Ex:  ./scripts/animate_icon.sh dagger "rogue assassin curved dagger" "blood dripping slowly from blade tip" 4
#
# Requer: ICON em assets/sprites/icons/<name>.png
# Output: assets/sprites/icons_anim/<name>/frame_000.png ... frame_N-1.png
#         e metadata.json com info da geração.

set -euo pipefail

if [[ $# -lt 3 ]]; then
    echo "Uso: $0 <icon_name> \"<description>\" \"<action>\" [n_frames]" >&2
    exit 1
fi

NAME="$1"
DESC="$2"
ACTION="$3"
N_FRAMES="${4:-4}"
# Valores ultra-conservadores: quase idêntico ao original com microvaiação
IMG_GUIDANCE="${IMG_GUIDANCE:-8.0}"    # Alto = preserva reference
TEXT_GUIDANCE="${TEXT_GUIDANCE:-2.0}"  # Baixo = menos interferência do texto
INIT_STRENGTH="${INIT_STRENGTH:-650}"  # Força da init_image (default 300)

# Bearer token (do MCP config do user)
TOKEN="89fc4637-1de8-41f9-b0db-3ecbda2d65b2"

SRC="assets/sprites/icons/${NAME}.png"
OUT_DIR="assets/sprites/icons_anim/${NAME}"

if [[ ! -f "$SRC" ]]; then
    echo "ERRO: $SRC não encontrado" >&2
    exit 2
fi

mkdir -p "$OUT_DIR"

# Base64 da imagem (sem prefixo data:)
BASE64=$(base64 -w 0 "$SRC")

# Payload simples: apenas reference_image + image_guidance_scale alto
PAYLOAD=$(jq -n \
    --arg desc "$DESC" \
    --arg action "$ACTION" \
    --arg b64 "$BASE64" \
    --argjson n "$N_FRAMES" \
    --argjson igs "$IMG_GUIDANCE" \
    --argjson tgs "$TEXT_GUIDANCE" \
    '{
        image_size: {width: 64, height: 64},
        description: $desc,
        action: $action,
        reference_image: {type: "base64", base64: $b64},
        n_frames: $n,
        view: "side",
        image_guidance_scale: $igs,
        text_guidance_scale: $tgs
    }')

echo "[animate] Chamando /animate-with-text pra ${NAME} (${N_FRAMES} frames)..."
RESPONSE=$(curl --fail -sS \
    -X POST "https://api.pixellab.ai/v1/animate-with-text" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

# Salva metadata e frames
echo "$RESPONSE" | jq '{usage, n_images: (.images | length)}' > "$OUT_DIR/metadata.json"
echo "[animate] Metadata: $(cat $OUT_DIR/metadata.json)"

# Extrai cada frame
N=$(echo "$RESPONSE" | jq '.images | length')
for ((i=0; i<N; i++)); do
    FRAME_B64=$(echo "$RESPONSE" | jq -r ".images[$i].base64")
    # Remove prefixo data: se tiver
    FRAME_B64="${FRAME_B64#data:image/png;base64,}"
    printf -v IDX "%03d" "$i"
    echo "$FRAME_B64" | base64 -d > "$OUT_DIR/frame_${IDX}.png"
    SZ=$(stat -c %s "$OUT_DIR/frame_${IDX}.png")
    echo "[animate] frame_${IDX}.png (${SZ}B)"
done

echo "[animate] OK: $N frames salvos em $OUT_DIR"
