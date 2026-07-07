---
name: luminaire_engine
description: LuminaireEngine v1 — motor de props decorativos emissores de luz (lanternas, braseiros, fogueiras); catálogo por bioma com 2-3 tipos, âncora de chama por conteúdo, cadência mínima de spawn
type: project
---

# LuminaireEngine v1 — props emissores de luz (Jul/2026)

**Pedido:** "motor específico para elementos decorativos que emitem luz...
reaproveitando as luzes, 2-3 adaptações por bioma, aumentar o rate, trocar
a arte feita à mão por pixel art... tem que pertencer ao bioma".

## Arquitetura (`engine/LuminaireEngine.lua`)
O motor NÃO desenha o sprite (painter do WorldRoad, REGRA DE PROFUNDIDADE).
Ele é dono de:
- **CATÁLOGO por bioma** — 18 luminárias (6 biomas × 3): fields lantern/
  firepit/shrine · highlands brazier(fogo AZUL arcano)/runestone/lantern
  (ferro, chão, size 0.9) · abyss brazier/torch/fissure · frost brazier
  (fogo quente = contraste)/crystal/lantern · marsh lantern(VERDE bruxaria)/
  mushroom/totem · dusk lantern/firepit/shrine. Campos: size, lane, anchor,
  light{color,radiusK,coreK,intensity,flicker}, embers{color,count}, weight.
- **LUZ** — submit no LightEngine (micro na chama + poça dither no chão,
  POOL_MIN_T=0.42). Flickers: fire/pulse nativos; **wisp** (respiração
  lenta, fogo-fátuo) e **shimmer** (cintilação rasa de cristal) modulados
  no motor via noise ANTES do submit.
- **ÂNCORA POR CONTEÚDO** — `anchor(bid,kind,variant,path)` escaneia o PNG:
  chama = centróide dos pixels ≥88% do pico de luminância; offX/footPad das
  margens do canvas (lição dos monstros). Cache por chave. Fallback:
  anchor do catálogo (arte procedural).
- **BRASAS** — `drawEmbers` determinístico (função pura do tempo, hash por
  seed — doutrina GrassField), desenhado pelo WorldRoad logo após o sprite
  (mesmo slot de profundidade). Só tipos com fogo vivo; sh<14px não desenha.

## Integração WorldRoad
- `kindSize(kind,bid)` e lane vêm do catálogo (KIND_SIZE/KIND_LANE são
  fallback dos kinds não-luminária).
- **Rate** ("hoje custa aparecer uma"): (1) `kindMult` — luminária ×1.0 no
  sorteio (não leva a pena ×0.5 dos props raros; árvore segue ×3.5);
  (2) **CADÊNCIA MÍNIMA** em rollProp — >12 unidades de mundo sem emissor
  → próximo prop VIRA luminária (sorteio pelos weights do catálogo),
  `WorldRoad._lastLumZ`. Resultado: 2-4 visíveis por tela em todo bioma.
- Sombra: props já passam por `ShadowEngine.queue` (footPad da âncora).
- Fallback procedural: `makeLuminaireGeneric` (pedestal na paleta do bioma
  + glow 3 degraus na cor do catálogo) pra kind novo sem PNG.
- Config.Lighting.LANTERN/BRAZIER/POOL_MIN_T **removidos** (migraram).

## Assets (PixelLab map objects, `assets/sprites/world/<bid>_<kind>_0.png`)
- 18 gerados com `create_map_object` view=side, selective outline,
  detailed shading, descrição na linguagem do bioma + "dark moody pixel art".
- **API força canvas QUADRADO** (36×72 vira 36×36!) — poste alto = pedir
  72×72 com "full post visible from ground to top"; margens laterais são
  absorvidas pelo offX/footPad do scan de conteúdo.
- Download: `curl -sL -H "Authorization: Bearer <token de ~/.claude.json>"
  https://api.pixellab.ai/mcp/map-objects/<id>/download` (curl solta o
  header no redirect S3 — o 403 antigo era o header seguindo o redirect).

## Custo
Bench travel 15.61 ms/frame (com o jogo do usuário rodando em paralelo —
re-medir ocioso; orçamento 16.6). Anchor scan é 1× por (bid,kind,variant).

## Pendências/afinações futuras
- Variantes _1/_2 por kind (hoje tudo variant 0).
- Chama ANIMADA por spritesheet (hoje glow assado + flicker de luz).
- fields_lantern standalone (b63b61ef) ficou sem uso — regen 19703fde é o
  poste oficial.
