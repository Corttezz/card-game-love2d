# 🎨 Sistema de Arte Pixel — Grimório Sépia (Slay the Spire / MTG old-school)

Arte das cartas é **híbrida**:
- **Ilustração central** = PNG 64×64 gerado via **PixelLab.ai MCP** e carregado de `assets/sprites/icons/<name>.png`.
- **Moldura ornamentada** = desenhada em runtime no Love2D pelo compositor `CardFrame` + 7 componentes em `src/ui/card/components/`.
- **Padrão de fundo** = PNG 64×64 em `assets/sprites/backgrounds/patterns/<name>.png` aplicado como overlay atrás da ilustração (alpha 0.45).
- **Shaders** = CRT pós-processamento full-screen (sutil) + Holo foil em cartas rare/legendary.

## Visão macro

```
cardId
  ↓
CardArt.resolve(card)                  → { icon (IconLoader handle), bgPattern, accent, decoration, effect }
  ↓
CardFrame.render(card)                 → love.Canvas 96×144 (cacheado por ID)
  │
  ├─ CardArtSlot      · fundo pergaminho + pattern PNG overlay + ilustração 64×64 centrada
  ├─ CardDecoration   · sparks/dust/smoke/flash opcional sobre a arte
  ├─ CardBorder       · outline ink + borda tipo + cantos raridade
  ├─ CardHeader       · banner escuro com nome dourado
  ├─ CardCostBadge    · disco aço canto sup. esq.
  ├─ CardRaritySeal   · disco raridade canto sup. dir. (halo em legendary)
  └─ CardStatsFooter  · banner inferior: ATTACK/DEFENSE/PASSIVE/ACTION + valor
  ↓
Card:draw() → HoloShader (rare/legendary) → CRTShader → janela
```

Dimensões: canvas **96×144**, `Config.Cards.BASE_SCALE = 1.333` → ~128×192 na tela (integer-ish).

## Paleta grimório (em `src/ui/Palette.lua`)

| Alias | Hex | Uso |
|---|---|---|
| `PARCHMENT_LIGHT` | `#e8d5a0` | Topo do pergaminho |
| `PARCHMENT` | `#b8a068` | Fundo da art slot |
| `PARCHMENT_DARK` | `#6a4f24` | Sombra / borda interna |
| `INK` | `#1a0f08` | Outline / texto |
| `BLOOD` / `BLOOD_DARK` | `#8b1e1e` / `#4a1010` | Accent attack |
| `STEEL` / `STEEL_LIGHT` | `#4a5260` / `#8a94a0` | Accent defense |
| `AGED_GOLD` / `AGED_GOLD_LIGHT` | `#b08a3e` / `#d4b060` | Joker / legendary |
| `MOSS` | `#4a6030` | Effect / uncommon |
| `RUST` | `#8b4a1e` | Joker dark |

Regra: cartas usam **EXCLUSIVAMENTE** esses tons. Cores DR-Darkworld (MAGENTA/CYAN/PURPLE/...) continuam no Palette pra retrocompat, mas **não** devem ser usadas em novo código.

## Componentes

### Resolução de ícone — `IconLoader`
`IconLoader.get(name)` → handle `{ kind, size, draw }`. Preferência:
1. `assets/sprites/icons/<name>.png` (PNG 64×64 do PixelLab)
2. Matriz 16×16 em `src/ui/PixelIcons.lua` (fallback low-res)

### Overlay de fundo — `BackgroundLoader`
`BackgroundLoader.get(name)` → `love.Image` ou `nil`. Lê `assets/sprites/backgrounds/patterns/<name>.png`. Desenhado no `CardArtSlot` com alpha 0.45 (sutil, pra não competir com a ilustração).

### 7 Componentes do card — `src/ui/card/components/`
Cada um expõe uma `draw(...)` pequena. Adicionar novo componente = 1 arquivo + 1 linha em `CardFrame.lua`.

| Componente | Área | Parâmetros principais |
|---|---|---|
| `CardBorder` | Full 96×144 | `type, rarity` |
| `CardHeader` | y=0-13 | `cardName` |
| `CardCostBadge` | (1,1) 11×11 | `cost` |
| `CardRaritySeal` | (w-12,1) 11×11 | `rarity` |
| `CardArtSlot` | (4,17) 88×107 | `{ icon, bgPattern, accent }` |
| `CardDecoration` | Sobre art slot | `name, accent` |
| `CardStatsFooter` | y=127-142 | `card` (usa type + attack/defense) |

## Assets gerados (leva inicial)

**33 ícones 64×64** em `assets/sprites/icons/`:
sword_short, sword_great, dagger, axe, claw, fang, shield_round, shield_kite, armor_plate, helm, bolt, fireball, crystal, rune, orb, barrier, snowflake, water_drop, flame, heart, skull, skull_crowned, eye, mask, jester_hat, potion_red, potion_blue, gem, coin, scroll, star, moon, question.

**17 backgrounds 64×64** em `assets/sprites/backgrounds/patterns/`:
stone, blood, metal, rage, fire, wind, void, abyss, ghost, impact, wave, storm, arcane, ice, soft, poison, shadow.

**4 jokers** (chibi, 4-direções) em `assets/sprites/characters/joker_{abyss,shield,vampire,jester}_dir/rotations/`.

**Âncora** — `assets/sprites/_style_reference.png` (espada 64×64).

## Como adicionar

### Carta nova
1. Dados em `src/data/cards/<class>.lua`.
2. Arte em `src/data/card_art.lua`:
   ```lua
   warrior_minha_carta = {
     icon = "sword_great",      -- PNG em icons/
     bg = "fire",                -- PNG em backgrounds/patterns/
     accent = "BLOOD",           -- nome em Palette
     decoration = "sparks",      -- opcional
     -- effect = nil -- auto pela raridade
   },
   ```

### Ícone/pattern/joker novo (PixelLab)
Gere com o contrato documentado em [`../memory/sprite_design_queue.md`](../../memory/sprite_design_queue.md). Salve em `assets/sprites/icons/<name>.png` (ou `.../patterns/` para backgrounds). Zero code change — `IconLoader`/`BackgroundLoader` acham automaticamente.

### Decoração nova
Edite `CardDecoration.lua`, adicione `registry.minha_deco = function(x, y, w, h, accent) ... end`. Use em `card_art.lua`.

### Componente novo
Crie `src/ui/card/components/MeuComponente.lua` com `draw(...)`. Importe e invoque em `CardFrame.render`.

## Shaders

### `CRTShader.lua` + `shaders/crt.glsl`
Pós-processo sutil (strength default 0.45):
- Wave horizontal fraco
- Chromatic aberration sutil
- Scanlines
- Flicker leve
- Vignette radial
- Noise granular

Ajustes:
```lua
CRTShader.setStrength(0.0)     -- desliga
CRTShader.setStrength(0.8)     -- forte (quase Balatro)
CRTShader.toggle()
```

### `HoloShader.lua` + `shaders/holo.glsl`
Foil rainbow diagonal em `rare` (glow 0.35) e `legendary` (holo 0.75). Aplicado automaticamente em `Card:draw` via `instance.visualEffect`.

## Performance

- `CardFrame.render` cacheado por `card.id`. ~68 IDs ≈ 6 MB de canvases.
- `IconLoader` / `BackgroundLoader` cacheiam por nome. PNG carregado uma vez.
- Shaders carregados em `main.lua:love.load`.

## Compatibilidade

- LÖVE 11.5 (testado em WSL2).
- Nenhuma dependência externa além do que já estava no repo.
- PixelLab.ai MCP usado **offline do runtime** — é apenas uma pipeline de geração de assets.

## Referências

- [Pixel art system notes](../../memory/pixel_art_system.md)
- [Sprite generation workflow](../../memory/sprite_design_queue.md)
- Cartas antigas (referência visual): `assets/cards/*.png`
- Balatro CRT shader port: <https://gist.github.com/mar1lusk1/4677e482375bff4a01956107aef35699>
