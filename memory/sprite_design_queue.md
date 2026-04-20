---
name: Sprite Design Queue (PixelLab.ai MCP)
description: Workflow e contrato visual usados para gerar 54 sprites (33 icons + 17 backgrounds + 4 jokers) via PixelLab.ai MCP. Paleta grimório sépia.
type: project
---

## ⚠️ STATUS: LEVA INICIAL CONCLUÍDA (2026-04-18)

**Gerados e aprovados:**
- 33 ícones (64×64) em `assets/sprites/icons/`
- 17 backgrounds (64×64, lineless) em `assets/sprites/backgrounds/patterns/`
- 4 jokers chibi (48px, 4-direções) em `assets/sprites/characters/joker_*_dir/rotations/`
- 1 style reference (`assets/sprites/_style_reference.png`) — espada ornamentada

**Contrato visual fixo** (reutilizar pra novas gerações):
- `view=side`, `outline=single color outline`, `shading=detailed shading`, `detail=high detail`, 64×64
- Para backgrounds: `view=high top-down`, `outline=lineless`, `shading=basic shading`, `detail=medium detail`
- Prompt **sempre termina com:** *"dark fantasy grimoire illustration pixel art, inked engraving style, earthy desaturated palette (bone white, rust orange, deep blood crimson, tarnished dark steel, charcoal black, burnt sienna, aged gold, dark leather brown), NO neon colors, NO bright magenta or cyan, crisp 1px pure black outline, detailed shading with clear darks and mid-tones, dramatic silhouette, moody upper-left lighting, limited 8-color palette, Slay the Spire and Magic the Gathering card art aesthetic"*

**Sprites a regerar se quiser refinar** (saíram bons mas não perfeitos):
- `dagger` — v2 ficou OK mas poderia ter mais sangue
- `fang` — corrigido na v2, check novamente
- `barrier` — conceito foi alinhado mas ainda parece mais amuleto
- `water_drop` — regen aplicada, cor desaturada OK

**Concurrency limit PixelLab:** ~6 jobs simultâneos. Se 7+ queued, algumas retornam 500 ao download (rate limit silencioso). Estratégia: queue em waves de 6, sleep 200s, download, repeat.

---

## Contexto legado (direção anterior — antes do pivô grimório)

**Setup MCP já feito** em `~/.claude.json` (scope project) — bearer token do PixelLab. O `pxcli-mcp` antigo foi removido. Restart do Claude Code é necessário pra as tools aparecerem.

**Diretórios de saída** (já criados):
- `assets/sprites/icons/` — 25 ícones de carta
- `assets/sprites/characters/` — jokers e personagens de classe
- `assets/sprites/tilesets/` — backgrounds tileados
- `assets/sprites/backgrounds/` — fundos grandes (menu, cenário)

## Tools do PixelLab que vamos usar

| Tool | Uso | Tempo | Output |
|---|---|---|---|
| `create_map_object` | **Ícones de carta** (sword, shield, potion) — top-down objects | Sync (~10s) | PNG inline ou URL |
| `create_character` | **Jokers** com multi-direção (skull_crowned, jester) | Async 2-5min (`character_id` + polling) | ZIP com rotações |
| `create_topdown_tileset` | **Backgrounds** de carta (stone, fire, ice, ...) via Wang tiles | Async 202 | Tileset com 16 tiles |
| `create_isometric_tile` | Tiles isométricos (se quisermos no futuro) | Async | PNG base64 + URL |
| `create_tiles_pro` | **Coerência**: força estilo via `style_images` | Sync | PNG |

## Estratégia de coerência visual (⚠️ importante)

PixelLab tem parâmetro `style_images`. Workflow:

1. **Passo 0 — Cria "style reference"**: gerar 1 sprite âncora com descrição detalhada (paleta + estilo). Ex: `create_map_object(description="dark fantasy sword, magenta and cyan highlights, 4-color palette, 1px black outline, Balatro-inspired pixel art style")`.
2. **Salvar** esse PNG como `assets/sprites/_style_reference.png`.
3. **Todos os subsequentes** passam esse arquivo como `style_images`. Garante paleta/stroke/shading consistentes.
4. Se o estilo sair diferente do desejado, regenerar âncora até ficar bom, depois cascatear.

## Prompts template (copy/paste)

Sempre terminar descrições com:
> "...dark fantasy, neon magenta/cyan accents, top-left light source, hard 1px black outline, pixel art, 4-6 color palette"

### Ícones de carta (create_map_object, 32×32)

```
sword_short:  "short iron sword with orange hilt, gleaming blade with white highlight, fantasy RPG item, top-down view, 32x32"
sword_great:  "massive two-handed greatsword, gold hilt, steel blade, diagonal pose"
dagger:       "sharp curved rogue dagger, bloody edge, black handle"
axe:          "dwarven battle axe, wooden shaft, gold-trimmed blade"
claw:         "3 sharp beast claws, black and red, dripping blood"
fang:         "vampiric fangs dripping red blood"
bolt:         "crackling yellow lightning bolt with white core glow"
fireball:     "glowing orange fireball with magenta-red flames and yellow center"
shield_round: "round medieval shield, blue steel with gold boss and rim"
shield_kite:  "knight kite shield with crusader red cross, silver border"
armor_plate:  "ornate steel chest plate with gold trim"
barrier:      "magical translucent cyan energy shield"
helm:         "iron full helm with T-shaped visor slit"
crystal:      "floating purple magic crystal, multi-faceted, glowing"
rune:         "ancient stone rune tablet with golden glowing symbols"
orb:          "swirling purple arcane orb with inner light"
skull:        "grinning skeleton skull, empty eye sockets"
skull_crowned: "royal skull wearing a golden crown with gems"
eye:          "mystical all-seeing eye with purple iris"
mask:         "carnival jester mask, half purple half gold"
jester_hat:   "three-pointed jester hat with magenta and gold bells"
potion_red:   "cork-sealed potion bottle with swirling red liquid, heart icon"
potion_blue:  "potion bottle with glowing cyan magical liquid"
gem:          "cut purple gemstone with white sparkle highlight"
coin:         "stack of golden coins with dollar sign"
scroll:       "rolled parchment scroll with runic text"
snowflake:    "crystalline six-pointed snowflake, cyan and white"
water_drop:   "single blue water drop with highlight"
flame:        "dancing orange and yellow flame tongue"
heart:        "red pixel heart with white shine"
star:         "5-pointed yellow star with white core"
moon:         "crescent moon, golden yellow"
```

### Jokers (create_character, 48×48)

Jokers precisam de mais personalidade. Usar `body_type="humanoid"`, `size=48`, `proportions="chibi"`:

```
joker_abyss:     "god of the abyss, dark purple robed figure with glowing cyan eyes and floating tentacles, chibi proportions"
joker_shield:    "guardian deity with massive golden shield, blue armor, chibi"
joker_vampire:   "vampire lord with red cape, pale skin, dripping fangs, chibi"
joker_jester:    "court jester with tri-pointed magenta hat, gold bells, wide grin"
```

### Backgrounds de carta (create_topdown_tileset, 16×16 Wang tiles → 60×62 assembled)

Terrain descriptions por pattern:

```
stone:    "cracked dark dungeon stone bricks with moss"
blood:    "splattered red blood on black obsidian"
metal:    "riveted blue steel plates with highlights"
fire:     "molten lava and orange embers"
ice:      "crystalline frozen blue ice"
arcane:   "glowing purple runes on dark marble"
void:     "deep space with purple nebula and stars"
wind:     "cyan wind currents on dark background"
```

### Full-screen backgrounds (create_map_object, large size)

```
casino_table: "dark green felt casino table texture, seamless tileable"
night_sky:    "dark fantasy night sky with purple nebula and golden stars"
```

## Fluxo passo-a-passo (próxima sessão)

1. **Restart Claude Code** no diretório `/home/cortez/projects/card-game-love2d/`
2. Verificar tools disponíveis via `mcp__pixellab__*` (ToolSearch se não aparecerem direto)
3. Gerar **style reference**: `create_map_object(description="...")` — manualmente até ficar bom
4. Salvar como `assets/sprites/_style_reference.png` via `save_sprite.sh`
5. **Batch 1 — 10 ícones principais** (sword_short, shield_round, skull, bolt, fireball, potion_red, potion_blue, dagger, heart, crystal) com `style_images=_style_reference.png`
6. Salvar cada um em `assets/sprites/icons/<name>.png` — IconLoader já pega sem code change
7. `love .` pra visual check
8. **Batch 2 — 15 restantes**
9. **Batch 3 — 4 jokers** (async, aguardar)
10. **Batch 4 — 8 backgrounds** (tileset async)
11. Atualizar `CardFrame.Patterns` pra usar PNGs em vez de procedural quando disponíveis

## Contingências

- **Insufficient credits (HTTP 402):** parar, avisar user, sugerir recarga.
- **Output ruim:** usar `delete_*` e tentar com prompt refinado.
- **Estilo inconsistente:** refazer style reference, regerar batch problemático.
- **API off:** fallback pras matrizes PixelIcons existentes (já funcional).

## Helper scripts

- `scripts/save_sprite.sh <base64> <path>` — decodifica PNG base64 pra arquivo.
- Se vier URL: `curl -sSL <url> -o <path>` direto.

## Custo mental

Não sei o pricing exato. API docs só mencionam "USD credits". Pelo token que o user deu, assumo que tem crédito. Gerar ~60 sprites em batches e monitorar saldo.
