---
name: New Card Creation Guide
description: Guia completo pra criar novas cartas — arte, animações, jokers, CardFrame, PixelLab. Consolidado do debugging visual que levou ao estado atual.
type: project
---

Tudo que aprendemos criando/polindo as cartas. Ler antes de adicionar nova carta
ou tocar no visual.

## Arquitetura rápida

```
CardDatabase:createCardInstance(cd)
  ↓
CardFrame.render(card)                    → canvas 96×144 (cacheado por ID)
  │
  ├─ Parchment base: PARCHMENT_LIGHT sólido cobrindo a carta toda
  ├─ parchment_texture.png overlay (alpha 0.85) — papel envelhecido contínuo
  ├─ renderStandard OR renderJoker:
  │   ├─ CardArtSlot (só ilustração — sem vignette/stains/gradientes)
  │   ├─ CardDecoration (sparks/embers/drips por bgPattern)
  │   ├─ CardBorder (7 filetes + knotwork_strip + corner_flourish +
  │   │              vertical_divider + edge_medallion + wear_overlay +
  │   │              bolts asimétricos + damage marks por seed)
  │   ├─ CardHeader (banner nome) / JokerHeader (tarot theme)
  │   ├─ CardCostBadge (top-left)
  │   ├─ CardRaritySeal (top-right) / JokerSeal
  │   └─ CardStatsFooter / JokerFooter (width total)
  ↓
Card:draw → CardAnimationLayer overlay:
  ├─ Rarity halo/glow (legendary/rare)
  ├─ bgPattern embers/drips/flash/ice
  ├─ IconAnimations.draw (sutil por categoria do ícone)
  └─ Joker ring rotativo
  ↓
HoloShader (rare/legendary) → CRTShader full-screen
```

## Adicionar nova carta — checklist

### 1. Dados em `src/data/cards/<class>.lua`
```lua
warrior_nova_carta = {
    id = "warrior_nova_carta",
    name = "Nome Curto PT-BR",
    type = "attack",          -- attack | defense | joker | effect
    cost = 2,
    attack = 10, defense = 0,
    class = "warrior",        -- warrior | mage | rogue | basic
    rarity = "common",        -- basic | common | uncommon | rare | legendary
    description = "...",
    image = "assets/jokers/joker1.png",  -- fallback só, CardFrame sobrescreve
    effects = { { type = "damage_bonus", value = 3 } },
}
```

### 2. Arte em `src/data/card_art.lua`
```lua
warrior_nova_carta = {
    icon       = "sword_short",   -- key em assets/sprites/icons/ OU PixelIcons.lua
    bg         = "fire",          -- key em assets/sprites/backgrounds/patterns/
    accent     = "BLOOD",         -- nome em Palette.lua
    decoration = "sparks",        -- sparks|dust|smoke|flash|blood_drips|embers|etc
    effect     = "glow",          -- nil|shine|glow|holo (auto pela rarity se nil)
},
```

Se não criar entrada, `CardArt.resolve` usa fallback `TYPE_DEFAULTS` + `CLASS_ICON_HINT`.

### 3. Se precisa de ícone novo — gera via PixelLab
```bash
# Template que funciona bem (grimório sépia):
# Use mcp__pixellab__create_map_object
# width=64 height=64 view=side outline=single-color shading=detailed detail=high
# Prompt sempre termina com:
# "dark fantasy grimoire illustration pixel art, inked engraving style,
# earthy desaturated palette (bone white, rust orange, deep blood crimson,
# tarnished dark steel, charcoal black, burnt sienna, aged gold, dark leather
# brown), NO neon colors, NO bright magenta or cyan, crisp 1px pure black
# outline, detailed shading with clear darks and mid-tones"
```
Salva em `assets/sprites/icons/<nome>.png`. `IconLoader` carrega auto — NADA
de código pra mudar.

### 4. Joker: gerar como MAP_OBJECT, NÃO character
⚠️ NÃO USE `create_character` pra jokers. Character gera humanoid chibi que
fica "pateta". Jokers devem ser máscaras / faces cósmicas / entidades místicas
estilo tarot.

**Template prompt jokers:**
```
"Imposing mystical [concept] portrait, ornate [descrição imponente],
radiating gold rays behind head, intricate gold ornamental engravings,
tarot card deity aesthetic, dark fantasy grimoire pixel art,
earthy desaturated palette with aged gold and charcoal,
NO neon colors, crisp 1px pure black outline, detailed engraving style,
centered portrait on transparent background"
```

Exemplos atuais funcionais:
- `joker_abyss` — cosmic deity face w/ sun rays + múltiplos olhos
- `joker_shield` — helmet divino c/ fendas de olhos brilhantes
- `joker_vampire` — face de conde vampiro w/ presas
- `joker_jester` — máscara arlequim sinistra

Dimensões: 64×64 high top-down. Salva como `assets/sprites/icons/joker_<name>.png`.
Em `card_art.lua`: `icon = "joker_abyss"`.

## Animações — SEMPRE procedurais, NUNCA generativas

### ❌ NÃO USE `/animate-with-text` PixelLab
Testamos. **Não preserva a arte original** — cada frame regera e o sprite muda
forma/cor. Nem com `image_guidance_scale=8.0` + `text_guidance_scale=2.0` fica
estável. Rejeitado como solução.

### ✅ USE `IconAnimations.lua` procedural sutil
Em `src/ui/card/IconAnimations.lua` o mapa `CATEGORY` associa `iconName` →
categoria de animação. Cada categoria é uma função em `Effects` que pinta
overlay POR CIMA do ícone estático (arte original 100% preservada).

**Regras de sutileza** (pra não ficar chamativo):
- Alpha máximo **0.35** em qualquer pintura
- Pixels únicos (1×1 ou 2×2), não blocos grandes
- Cycles longos (3-6s entre ocorrências)
- Use `setBlendMode("add", "alphamultiply")` pra glow discreto

Categorias existentes:
- `weapon_shine` (swords/axe/shields): brilho diagonal 1px @ 6s
- `blood_drip` (dagger/claw/fang): 1px vermelho caindo @ 5s
- `sparkle` (crystal/gem/rune/star/coin): 2 pontos alternando alpha 0.35
- `magic_swirl` (orb): partículas orbitando
- `flicker` (fireball/flame): 1 ember subindo
- `soft_pulse` (heart/skull/moon/eye/bolt/joker_shield/joker_jester): glow 0.18 oscilando
- `shimmer` (snowflake/water_drop): 1 pixel claro piscando
- `bubble` (potions): 1 bolhinha subindo
- `deity_eyes` (joker_abyss/joker_vampire): 2 olhos com glow pulsante alternado

Adicionar nova categoria: 1 entrada em `CATEGORY` + 1 função em `Effects`.

## Borders — componentes e assets

### PNGs usados (`assets/sprites/ui/`)
Todos gerados via PixelLab `create_map_object`. Tema grimório sépia.

| Arquivo | Tamanho | Uso |
|---|---|---|
| `parchment_texture.png` | 96×144 | Textura de papel envelhecido (alpha 0.85) |
| `corner_flourish.png` | 32×32 | 4 cantos da carta (rotação 0/90/180/270°) |
| `vertical_divider.png` | 32×64 | 2 laterais, altura variável por seed |
| `knotwork_strip.png` | 96×32 | Topo + base (flip vertical) |
| `edge_medallion.png` | 32×32 | Meio das 4 bordas |
| `wear_overlay.png` | 96×144 | Desgaste global alpha 0.20 |
| `stat_sword.png` / `stat_shield.png` / `stat_hourglass.png` / `stat_star.png` | 32×32 | Glifos do footer |

### Aging asimétrico
`CardBorder` usa `card.id` como **seed determinístico**. Cada carta gera
(sempre igual pra mesma ID):
- Bolts em 1-2 posições por lado
- Cracks INK em posições diferentes
- Chunks faltando em posições diferentes
- Tarnish esparso
- Vertical divider em altura variável

Resultado: **nenhuma carta fica idêntica a outra** — cada uma tem padrão único
de desgaste.

## Texto — bold multi-pass

Fontes `PixelFont.get(N)` mas pra ficar LEGÍVEL em pixel low-res:
```lua
-- Outline preto 8-direções + fill dourado (relevo metálico)
love.graphics.setColor(0, 0, 0, 1)
for dx = -1, 1 do
    for dy = -1, 1 do
        if not (dx == 0 and dy == 0) then
            love.graphics.print(txt, x + dx, y + dy)
        end
    end
end
love.graphics.setColor(Palette.AGED_GOLD_LIGHT)
love.graphics.print(txt, x, y)
```

Tamanhos usados:
- Nome no header: **fonte 12** (banner altura 18px)
- Label footer: **fonte 10** (banner altura 20px)
- Valor stat: **fonte 12**

## Layout atual

- `CardFrame.HEIGHT = 144`, `WIDTH = 96`
- `CardHeader.HEIGHT = 18`
- `CardStatsFooter.HEIGHT = 20` — **width total** (sem inset lateral)
- Art slot: (5, 20, 86, 103)
- Ícone centralizado com scale inteiro (ícone 64×64 → scale 1 → 64×64)

## Iterar visualmente

**Preview tool:** `love . preview_cards` → gera PNGs em
`~/.local/share/love/card-game/preview_*.png`. 10 cartas representativas.
Copia pra `tools/preview_out/` pra versionar. Eu posso ler esses PNGs
diretamente.

Script: `tools/preview_cards.lua`.

## Anti-patterns (NÃO FAZER)

- ❌ CardArtSlot com gradiente escuro / vignette / frame inner — criava "quadrado"
  flutuante que o user odiou
- ❌ Pattern overlay com alpha alto no art slot — criava retângulo visível do bg
  pattern (metal/fire/etc)
- ❌ `love.graphics.setBlendMode("multiply", "premultiplied")` com PNG não-PMA —
  apaga tudo que foi desenhado antes
- ❌ `/animate-with-text` pra items — gera frames inconsistentes
- ❌ `create_character` pra joker — vira chibi humanoid pateta
- ❌ Símbolos neon (magenta/cyan vivos) — fogem do tema grimório sépia
- ❌ Texto sem outline 8-direções em low-res — ilegível

## Links úteis

- Script de animação: `scripts/animate_icon.sh` + `scripts/animate_all_icons.sh`
  (mantidos mas não usar — ver "animate-with-text" rejeitado acima)
- Preview tool: `tools/preview_cards.lua`
- Sprite queue memory: [`sprite_design_queue.md`](sprite_design_queue.md)
- Pixel art system overview: [`pixel_art_system.md`](pixel_art_system.md)

## Coringa novo? Proc visual é OBRIGATÓRIO

Todo efeito de coringa precisa TICAR no slot no momento em que trabalha
(pulinho + popup + som). Efeito de tipo novo = implementar em EffectSystem
E chamar `pushJokerProc` no branch (cadeia no combate, direto no
turn_start). Contrato completo + checklist + tabela de cobertura:
[`joker_proc_fx.md`](joker_proc_fx.md). Regressão: `love . smoke_ui_turn`
(seção 7).
