#!/usr/bin/env bash
# tools/install_scene.sh
#
# Baixa uma scene gerada via pixellab MCP (create_map_object com dimensões
# 400×256) e instala em assets/sprites/scenes/<scene_name>.png pra ser usada
# automaticamente pelo SceneLayer.
#
# Uso:
#   ./tools/install_scene.sh <object_uuid> <scene_name>
#
# Exemplo (ato 1):
#   ./tools/install_scene.sh <uuid_do_create_map_object> catacumbs
#
# Depois disso, em src/ui/SceneLayer.lua o ACT_CONFIGS[1].scenePng = "catacumbs"
# já tá apontando pra esse nome, então o cenário ativa automaticamente.
#
# Pra scenes de outras telas (menu, victory, etc.), use o <scene_name> correto
# que o componente procura.

set -e

UUID=${1:?UUID do map object gerado via pixellab (ex: 90e6021d-...)}
SCENE_NAME=${2:?Nome da scene no jogo (ex: catacumbs, stone_tower, abyss)}

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEST="$ROOT/assets/sprites/scenes/$SCENE_NAME.png"

echo "[install-scene] download scene $SCENE_NAME (uuid=$UUID)"
curl -sS --fail -o "$DEST" \
  "https://api.pixellab.ai/mcp/map-objects/$UUID/download"

# Validação básica (deve ter pelo menos 2KB; menos que isso geralmente é erro)
SIZE=$(stat -c%s "$DEST" 2>/dev/null || stat -f%z "$DEST")
if [ "$SIZE" -lt 2048 ]; then
  echo "[install-scene] ERRO: arquivo baixado tem $SIZE bytes (provavelmente inválido)"
  rm -f "$DEST"
  exit 1
fi

echo "[install-scene] OK — $DEST ($SIZE bytes)"
echo "[install-scene] Teste: love . (SceneLayer usa scenes/$SCENE_NAME.png automaticamente se ACT_CONFIGS apontar pra ele)"
