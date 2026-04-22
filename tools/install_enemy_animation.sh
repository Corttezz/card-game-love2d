#!/usr/bin/env bash
# tools/install_enemy_animation.sh
#
# Instala uma animação gerada via pixellab MCP (animate_character) para um
# inimigo específico do jogo. Converte o layout do ZIP do pixellab
# (animations/<folder>/<dir>/frame_NNN.png) para o layout que o SpriteAnimation.lua
# espera (enemies/<id>/animations/<anim>/<dir>/N.png).
#
# Uso:
#   ./tools/install_enemy_animation.sh <UUID> <enemy_id> <anim_name> [folder_pattern]
#
# Exemplos:
#   # Instala a única animação disponível (ou a 1ª por ordem)
#   ./tools/install_enemy_animation.sh 81ed1ec7-... grave_slime idle
#
#   # Quando há múltiplas animações no ZIP, especifique o folder pattern.
#   # O pixellab nomeia a pasta com o template_id: "taking_a_punch-<hash>",
#   # "falling_back_death-<hash>", etc. "animating-<hash>" é o genérico (idle).
#   ./tools/install_enemy_animation.sh 81ed1ec7-... grave_slime hurt  "taking_a_punch-*"
#   ./tools/install_enemy_animation.sh 81ed1ec7-... grave_slime death "falling_back_death-*"
#   ./tools/install_enemy_animation.sh 81ed1ec7-... grave_slime idle  "animating-*"
#
# Tip: rode sem o 4º arg primeiro — o script lista as pastas disponíveis
#      se nenhum pattern for passado e houver >1 animação.

set -e

UUID=${1:?UUID do character (ex: 81ed1ec7-...)}
ENEMY_ID=${2:?Nome do inimigo no jogo (ex: grave_slime)}
ANIM_NAME=${3:?Nome da animação no jogo (idle | hurt | death)}
FOLDER_PATTERN=${4:-}

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEST="$ROOT/assets/sprites/characters/enemies/$ENEMY_ID"
TMP=$(mktemp -d)

echo "[install] download ZIP do character $UUID"
curl -sS --fail -o "$TMP/char.zip" "https://api.pixellab.ai/mcp/characters/$UUID/download"
unzip -oq "$TMP/char.zip" -d "$TMP/extract"

# Rotações estáticas: só copia south.png (única direção que o jogo renderiza).
# Anteriormente copiava 4 dirs (east/west/north/south); cleanup 2026-04-21
# removeu as 3 não usadas. Se precisar de rotação no futuro, override este loop.
mkdir -p "$DEST"
SRC="$TMP/extract/rotations/south.png"
DST="$DEST/south.png"
if [ -f "$SRC" ] && [ ! -f "$DST" ]; then
  cp "$SRC" "$DST"
  echo "[install] rotação south.png instalada"
fi

# Identifica a pasta da animação
AVAILABLE_FOLDERS=$(ls -d "$TMP/extract"/animations/*/ 2>/dev/null | xargs -n1 basename)
if [ -z "$AVAILABLE_FOLDERS" ]; then
  echo "[install] ERRO: ZIP não tem nenhuma pasta em animations/"
  exit 1
fi

if [ -n "$FOLDER_PATTERN" ]; then
  # Pattern explícito
  ANIM_SRC=$(ls -d "$TMP/extract"/animations/$FOLDER_PATTERN 2>/dev/null | head -1)
  if [ -z "$ANIM_SRC" ]; then
    echo "[install] ERRO: nenhuma pasta casa com pattern '$FOLDER_PATTERN'"
    echo "[install] Pastas disponíveis:"
    echo "$AVAILABLE_FOLDERS" | sed 's/^/    /'
    exit 1
  fi
else
  # Sem pattern: se só tem 1 pasta, usa essa. Se tem mais, aborta e lista.
  COUNT=$(echo "$AVAILABLE_FOLDERS" | wc -l)
  if [ "$COUNT" -gt 1 ]; then
    echo "[install] ERRO: há $COUNT pastas de animação no ZIP."
    echo "[install] Especifique o 4º argumento (folder_pattern)."
    echo "[install] Pastas disponíveis:"
    echo "$AVAILABLE_FOLDERS" | sed 's/^/    /'
    echo "[install] Sugestão: use 'taking_a_punch-*' pra hurt, 'falling_back_death-*' pra death, 'animating-*' pra idle."
    exit 1
  fi
  ANIM_SRC="$TMP/extract/animations/$AVAILABLE_FOLDERS"
fi

echo "[install] usando pasta: $(basename "$ANIM_SRC")"

# Apenas direção south é instalada (única que o jogo renderiza). Se a animação
# foi gerada com directions=["south"] no animate_character, vai ter só essa
# pasta no ZIP — perfeito. Se foi gerada com 4 dirs, ignoramos as outras 3.
OUT="$DEST/animations/$ANIM_NAME/south"
mkdir -p "$OUT"
if [ ! -d "$ANIM_SRC/south" ]; then
  echo "[install] ERRO: direção south ausente no ZIP"
  exit 1
fi
rm -f "$OUT"/*.png
i=0
for frame in $(ls "$ANIM_SRC/south"/frame_*.png 2>/dev/null | sort); do
  cp "$frame" "$OUT/$i.png"
  i=$((i+1))
done
echo "[install] $ANIM_NAME/south: $i frames"

rm -rf "$TMP"
echo "[install] OK — $ENEMY_ID/$ANIM_NAME pronto"
