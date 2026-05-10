---
name: PixelLab Queue — Booster Pack Sleeves + Cinematic Assets
description: Prompts e workflow pra gerar arte dos packs. ✅ 5 sleeves gerados via HTTP bypass (Apr/26 2026). Workflow validado e reutilizável.
type: project
---

# Queue PixelLab — Pack Opening (Fase 5/6/7 polish)

✅ **STATUS: 5 sleeves gerados (2026-04-26)** via HTTP bypass quando MCP não estava
carregado na sessão. Script `tools/pixellab_generate_packs.py` valida a abordagem
e fica como referência reutilizável.

## ⚠️ Bypass HTTP quando MCP não aparece nas tools

O servidor PixelLab MCP é configurado em `~/.claude.json` (project-scoped pra
`/home/cortez/projects/card-game-love2d`) com URL `https://api.pixellab.ai/mcp`
e bearer token. Quando uma sessão Claude Code não carrega o MCP (ex: se foi
iniciada antes do restart), as tools `mcp__pixellab__*` ficam indisponíveis
mas **o endpoint HTTP responde normalmente**.

Solução: chamar via JSON-RPC HTTP direto (urllib/curl). Headers:
```
Authorization: Bearer <token-do-claude.json>
Content-Type: application/json
Accept: application/json, text/event-stream
```

Resposta vem como streaming `event: message\ndata: {jsonrpc...}` — parsear linhas
prefixadas com `data:`.

Workflow padrão:
1. `tools/call` com `name: create_map_object` (ou create_character, etc)
2. Resposta inclui `Object ID: <uuid>` no texto
3. Aguardar 60s (PixelLab leva 30-90s por job)
4. `tools/call` com `name: get_map_object, arguments: {object_id: <uuid>}`
5. Resposta tem `content` array com type=image (base64) ou text com URL
6. Salvar PNG em `assets/sprites/<categoria>/<id>.png`

Script de referência: `tools/pixellab_generate_packs.py` (Python stdlib only,
sem dependências externas).

**Regra:** se MCP não aparecer ao precisar gerar arte, NÃO assumir que está
indisponível. Tentar HTTP direto via script primeiro.

## Style reference base

Reusar `assets/sprites/_style_reference.png` (espada ornamentada já existente) como
`style_images` em todos os jobs abaixo pra coerência.

## 1. Pack sleeves (5 sprites)

Localização: `assets/sprites/packs/<id>.png` — **128×192 cada** (proporção de carta
2:3, mais alto que ícones porque é o "envelope" da carta).

Tool: `create_map_object`, `view=side`, `outline=single color outline`, `shading=detailed shading`,
`detail=high detail`, `size=128x192`.

| ID | Prompt (concatenar sufixo do contrato visual) |
|---|---|
| `pack_standard.png` | "ornate sealed parchment envelope tied with red wax seal, scrollwork edges, cracked aged leather binding, slight glint highlight" |
| `pack_buffoon.png` | "jester hat marked sealed leather pouch, twin bells dangling, red and yellow trim, sinister grin embossed on front" |
| `pack_arcana.png` | "mystical tarot card sleeve with golden eye sigil, indigo background, occult symbols at corners, faint purple glow" |
| `pack_celestial.png` | "celestial parchment envelope with constellation stars and moon phase glyphs, deep navy with silver foil accents, ringed planet emblem center" |
| `pack_spectral.png` | "ghostly translucent envelope, pale green wisp glow leaking from edges, ethereal skull silhouette, frayed cloth wrapping" |

**Sufixo obrigatório** (todo prompt termina com isso, ver `sprite_design_queue.md`):
> "dark fantasy grimoire illustration pixel art, inked engraving style, earthy desaturated palette (bone white, rust orange, deep blood crimson, tarnished dark steel, charcoal black, burnt sienna, aged gold, dark leather brown), NO neon colors, NO bright magenta or cyan, crisp 1px pure black outline, detailed shading with clear darks and mid-tones, dramatic silhouette, moody upper-left lighting, limited 8-color palette, Slay the Spire and Magic the Gathering card art aesthetic"

## 2. Pack name banner (1 sprite, opcional)

Localização: `assets/sprites/ui/pack_banner.png` — **256×64**.

Faixa decorativa de pergaminho que fica no topo do pack open screen com o nome do
pack ("Standard Pack", "Buffoon Pack" etc). Substitui texto puro por algo mais
ornamentado.

Prompt:
> "horizontal aged parchment banner with curled edges, ornate scrollwork at both ends, blank center for text, ribbon ties, [contrato visual]"

## 3. Sleeve "tear" / "rip" effect (1-2 sprites animados)

Quando o pack explode, queremos ver pedaços de papel rasgado caindo. Pode ser:
- 4 frames de paper-tear sprite sheet (ou)
- 1 sprite estático + partículas via CardParticles com palette ajustada

Prompt:
> "torn parchment shred fragments, jagged edges, charred corners, pixel art, 4 small fragments arranged"

## 4. Choose pip / counter (opcional)

Quando "Choose 1" mostra, podia ser um disco ornamentado dourado em vez de número
puro. 32×32.

Prompt:
> "ornate gold coin disc with embossed numeral, beveled edge, slight tarnish patina, [contrato]"

---

## Como executar quando MCP reconectar

```
# Pseudocode pra cada item da tabela:
mcp__pixellab__create_map_object({
    description = "<prompt>",
    width = 128, height = 192,
    view = "side",
    outline = "single color outline",
    shading = "detailed shading",
    detail = "high detail",
    style_images = ["assets/sprites/_style_reference.png"],
})
# Salvar PNG em assets/sprites/packs/<id>.png
```

Concurrency: max 6 jobs simultâneos. Se queue >6, faz waves de 6 com sleep 200s entre.

## Wiring no código (depois da geração)

1. `src/data/booster_packs.lua` (criar) → cada pack-type tem `sleeve_image = "assets/sprites/packs/pack_X.png"`.
2. `BoosterPackSystem.expandPackRecord` retorna o sleeve_image junto.
3. `PackOpenScreen` (refatorada) carrega imagem via `ImageCache.get(pack.sleeve_image)`,
   desenha como Card "selada" no centro, chama `:explode()` antes do materialize.

Sem esses sprites o pack opening vai continuar genérico mesmo com layout reformulado —
**sleeve art é o elemento visual mais importante** pra distinguir os 5 tipos visualmente.
