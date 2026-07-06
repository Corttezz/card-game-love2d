---
name: research_libs_pixellab
description: Pesquisa Jul/2026 — capacidades novas do PixelLab MCP e libs LÖVE2D avaliadas (vereditos adotar/avaliar/ignorar)
type: reference
---

# Pesquisa: PixelLab MCP + libs LÖVE2D (Jul/2026)

## PixelLab MCP — abordagens ainda não usadas no projeto

1. **create_topdown_tileset (Wang, 16 tiles)** — transições de terreno
   seamless: `lower_description="green grass"`, `upper_description="dirt
   path"`, `transition_size` 0=dura/0.25/0.5, `view="low top-down"` (RPG).
   Resolve a emenda estrada↔grama do Passo 5 do plano v6 sem hack de rects.
   Encadeável via `lower/upper_base_tile_id` pra manter consistência.
2. **create_map_object com background_image + inpainting** — gera o prop
   JÁ DENTRO de um recorte da cena (path/base64; oval/rectangle/mask),
   casando paleta e luz automaticamente. Limites: 400×400 basic,
   192×192 inpainting; width/height auto-detectados do background.
   Uso: flores/pedras/poças no domo, lanterna na estrada.
3. **animate_object** — anima props de cenário por descrição livre
   ("flickering flames", "waving flag", "swaying tree"); mode='v3'.
   Uso: fogueira do rest, bandeiras do castelo, lanterna.
4. **create_tiles_pro** — variações de tile (square/iso/hex) com
   `style_images` (única tool com style matching explícito).
5. **create_ui_asset / create_font** — painéis de HUD e fonte pixel
   no estilo do jogo (fora do escopo cenário, mas mapeado).
6. Consistência de estilo: character → `create_character_state` com
   `use_color_palette_from_reference=True`; map_object → via
   background_image. Máx canvas geral: 400px (por isso strips são 400×N).

## Libs LÖVE2D — vereditos (código VERIFICADO pra stencil)

- **ADOTAR: moonshine** (vrld) — chain composável de pós (glow, godsray,
  vignette, chromasep...); zero stencil; dormant-mas-padrão (718★).
  Alternativa: copiar só a arquitetura de chain (~150 LOC).
- **ADOTAR: flux** (rxi) — tween de 1 linha `flux.to(obj,d,{x=..})`;
  congelada-porque-pronta. Papel distinto do EventManager (interpolação
  vs orquestração); convenção: um dono por campo animado.
- **ADOTAR: anim8** (kikito) — spritesheet/grid pros frames PixelLab
  (mata frame-stepping manual do EnemyRenderer/WorldRoad).
- **AVALIAR: batteries** (1bardesign, ativa Mai/2026) — só mathx/vec2/
  intersect/pool; NÃO usar timer/pubsub (duplicam EventManager); pinnar
  commit. | **hump.camera** (fork HDictus) — só se WorldRoad precisar
  de pan/zoom real. | **shove** (2025) — layers+resolução; usa stencil
  OPT-IN (shove.lua:276,551 — só em layer masks; proibir masks se
  adotar). | **Slab** (ativa 2026) — GUI immediate só pra painéis de
  debug/tuning. | **lurker** (rxi) — hot-reload de Lua em dev.
- **IGNORAR: light_world.lua e lighter** — AMBAS usam
  love.graphics.stencil no caminho principal (init.lua:145 / init.lua:349,
  confirmado no source) → crash NVIDIA. Iluminação 2D = caseira com
  canvas add→multiply (sem lib segura no ecossistema).
- **IGNORAR: SUIT/Helium/FlexLöve** (UI própria tem identidade),
  **push** (resize próprio cobre), **STALKER-X** (arquivada 2019; só
  vendorizar algoritmo de shake/deadzone como referência).

Fontes completas no transcript da sessão de Jul/2026; ranking web:
awesome-love2d, fóruns love2d.org t=83993/t=84591.
