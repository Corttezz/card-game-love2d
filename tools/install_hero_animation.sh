#!/usr/bin/env bash
# tools/install_hero_animation.sh
#
# Instala sprite + animação de um HERÓI de classe (gerado via pixellab MCP)
# no layout que SpriteAnimation.lua espera (ids "heroes/<classe>"):
#   assets/sprites/characters/heroes/<classe>/south.png
#   assets/sprites/characters/heroes/<classe>/animations/<anim>/south/N.png
#
# Uso:
#   ./tools/install_hero_animation.sh <UUID> <classe> <anim_name> [folder_pattern]
# Ex:
#   ./tools/install_hero_animation.sh f9c9fb9b-... warrior idle "breathing_idle-*"
#
# Espelho de install_enemy_animation.sh (pipeline em memory/enemy_pipeline.md).

set -e

UUID=${1:?UUID do character}
HERO_ID=${2:?Classe (warrior | mage | rogue)}
ANIM_NAME=${3:?Nome da animação no jogo (idle)}
FOLDER_PATTERN=${4:-}

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEST="$ROOT/assets/sprites/characters/heroes/$HERO_ID"
TMP=$(mktemp -d)

echo "[install] download ZIP do character $UUID"
curl -sS --fail -o "$TMP/char.zip" "https://api.pixellab.ai/mcp/characters/$UUID/download"
unzip -oq "$TMP/char.zip" -d "$TMP/extract"

mkdir -p "$DEST"

# Layout real do ZIP (verificado Jul/2026): <Nome_Do_Char>/rotations/*.png
# + <Nome_Do_Char>/animations/<anim>/<dir>/frame_NNN.png
ROT_DIR=$(find "$TMP/extract" -type d -name rotations | head -1)
for dir in south east west north; do
    if [ -f "$ROT_DIR/$dir.png" ]; then cp "$ROT_DIR/$dir.png" "$DEST/$dir.png"; fi
done

# Pasta da animação no ZIP
ANIM_ROOT=$(find "$TMP/extract" -type d -name animations | head -1)
if [ -z "$ANIM_ROOT" ] || [ ! -d "$ANIM_ROOT" ]; then
    echo "[install] ZIP sem animations/ — só rotações instaladas"
    ls "$DEST"
    exit 0
fi

if [ -n "$FOLDER_PATTERN" ]; then
    SRC_ANIM=$(find "$ANIM_ROOT" -maxdepth 1 -type d -name "$FOLDER_PATTERN" | head -1)
else
    COUNT=$(find "$ANIM_ROOT" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
    if [ "$COUNT" -gt 1 ]; then
        echo "[install] múltiplas animações no ZIP — especifique o 4º arg:"
        find "$ANIM_ROOT" -maxdepth 1 -mindepth 1 -type d -exec basename {} \;
        exit 1
    fi
    SRC_ANIM=$(find "$ANIM_ROOT" -maxdepth 1 -mindepth 1 -type d | head -1)
fi
[ -n "$SRC_ANIM" ] || { echo "[install] animação não encontrada"; exit 1; }

echo "[install] usando $(basename "$SRC_ANIM") -> $ANIM_NAME"
for dir in south east west north; do
    SRC_DIR="$SRC_ANIM/$dir"
    [ -d "$SRC_DIR" ] || continue
    OUT="$DEST/animations/$ANIM_NAME/$dir"
    mkdir -p "$OUT"
    i=0
    for f in $(ls "$SRC_DIR"/*.png | sort); do
        cp "$f" "$OUT/$i.png"
        i=$((i + 1))
    done
    echo "[install] $dir: $i frames"
done

rm -rf "$TMP"
echo "[install] OK -> $DEST"
