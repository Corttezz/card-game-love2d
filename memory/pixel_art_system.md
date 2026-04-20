---
name: Pixel Art System
description: Pipeline PNG-first (PixelLab.ai) com compositor procedural em src/ui/card/. Paleta grimório sépia (zero neon). Decomposto em componentes pra escalar.
type: project
---

Arte em pixel no estilo **grimório/Slay the Spire/MTG antigo**:
1. **Ilustrações centrais** — 33 PNGs 64×64 em `assets/sprites/icons/*.png` gerados via PixelLab.ai MCP, mesmo contrato visual (paleta sépia desaturada, outline 1px preto).
2. **Compositor** — `src/ui/CardFrame.lua` orquestra 7 componentes em `src/ui/card/components/` que desenham frame ornamentado (96×144 canvas).
3. **Backgrounds** — 17 PNGs 64×64 em `assets/sprites/backgrounds/patterns/*.png` carregados pelo `BackgroundLoader` como overlay com alpha 0.45 atrás da ilustração.
4. **Jokers** — 4 characters multi-direção em `assets/sprites/characters/joker_*/rotations/`.
5. **Pós-processamento** — CRT shader + Holo shader (raro/lendário) iguais ao legado.

**Why:** O usuário pediu alinhamento com a vibe das cartas antigas (`assets/cards/*.png` — grimório sépia ornamental com ilustração dramática). Pivotamos da paleta DR-Darkworld Neon para **grimório sépia** e criamos `src/ui/card/` decomponentizado pra permitir escala (novos patterns/decorations/componentes = 1 arquivo).

## Estrutura final

```
src/ui/
├── Palette.lua                    # 16 cores DR-Darkworld + seção Grimoire (sepia/gold/blood/steel/moss/rust)
├── PixelCanvas.lua                # primitivas (rectOutline, drawBitmapScaled, dither25, hline, etc.)
├── PixelFont.lua                  # cache de fontes nearest-filter
├── PixelIcons.lua                 # 25 matrizes 16×16 (fallback de baixa-res quando PNG falta)
├── IconLoader.lua                 # resolve nome → PNG (assets/sprites/icons/) ou matriz
├── CardArt.lua                    # atlas cardId → {icon, bgPattern, accent, decoration, effect}
├── CardFrame.lua                  # orquestrador fino (~80 LOC): compõe os 7 componentes
└── card/                          # NOVO — decomposição do compositor
    ├── BackgroundLoader.lua       # carrega PNG de assets/sprites/backgrounds/patterns/ + cache
    └── components/
        ├── CardBorder.lua         # outline duplo + borda de tipo + rarity corners
        ├── CardHeader.lua         # banner escuro com nome dourado
        ├── CardCostBadge.lua      # disco azul-aço canto sup. esq.
        ├── CardRaritySeal.lua     # disco rarity canto sup. dir. (halo dourado em legendary)
        ├── CardArtSlot.lua        # fundo pergaminho + pattern overlay + ilustração central
        ├── CardDecoration.lua     # sparks/dust/smoke/flash (overlay opcional)
        └── CardStatsFooter.lua    # banner inferior com "ATTACK"/"DEFENSE"/... + valor

src/data/card_art.lua              # atlas por cardId
shaders/{crt,holo}.glsl            # idem
assets/sprites/
├── icons/*.png                    # 33 ilustrações 64×64
├── backgrounds/patterns/*.png     # 17 texturas 64×64
├── characters/joker_*/rotations/  # 4 jokers multi-direção
└── _style_reference.png           # espada âncora usada pra cascatear estilo
```

## Paleta grimório (novos aliases em Palette.lua)

- **PARCHMENT_LIGHT / PARCHMENT / PARCHMENT_DARK** — pergaminho envelhecido (fundo da carta)
- **INK** — preto profundo (outlines, texto)
- **BLOOD / BLOOD_DARK** — attack accent
- **STEEL / STEEL_LIGHT** — defense accent
- **AGED_GOLD / AGED_GOLD_LIGHT** — legendary, joker
- **MOSS** — effect/poison accent
- **RUST** — joker dark

Os nomes antigos (MAGENTA, CYAN, PURPLE, etc.) continuam existindo pra retrocompat, mas os aliases semânticos (`Palette.ATTACK`, `.DEFENSE`, `.JOKER`, `.EFFECT`, `.RARITY_*`) agora apontam pra tons sépia.

## Dimensões

- Canvas por carta: **96×144 pixels** lógicos
- `Config.Cards.BASE_SCALE = 1.333` → 128×192 na tela (mesmo espaço do layout legado)
- Ilustração central: 64×64 centralizada na área de arte (88×107)
- Header: 14px | Footer: 16px

## Pipeline

1. `CardDatabase:createCardInstance(cd)` monta instância, chama `CardFrame.render(instance)` → `love.Canvas 96×144` vira `instance.image`.
2. `CardArt.resolve(instance)` retorna `{icon, bgPattern, accent, decoration, effect}`. `effect` vira `instance.visualEffect` (usado pelo HoloShader).
3. `Card:draw` aplica HoloShader em `visualEffect == "holo"|"glow"`.
4. `main.lua` envelopa tudo no CRTShader.

## Como estender

- **Adicionar ilustração nova** — gere PNG 64×64 via PixelLab (veja `memory/sprite_design_queue.md` pro contrato de prompt) e salve em `assets/sprites/icons/<name>.png`. Mapeie em `src/data/card_art.lua`.
- **Novo pattern de background** — gere PNG 64×64 `outline=lineless` em `assets/sprites/backgrounds/patterns/<name>.png`. Use o nome em `card_art.lua` campo `bg`.
- **Nova decoration** — adicione função em `CardDecoration.registry` (assinatura `(x, y, w, h, accent)`).
- **Novo componente** — crie arquivo em `src/ui/card/components/`, importe e invoque em `CardFrame.render`.

## Regras invioláveis

- Paleta sépia: **NUNCA** adicione neon magenta/cyan ao desenhar carta. Use `Palette.BLOOD/STEEL/AGED_GOLD/MOSS`.
- Nearest filter obrigatório em tudo (já é default via `PixelCanvas.enableNearest()` + `setFilter("nearest")` em cada loader).
- Outlines 1px sempre em `Palette.INK` para consistência.
- Contrato de prompt PixelLab: `"dark fantasy grimoire illustration pixel art, earthy desaturated palette, NO neon colors, crisp 1px pure black outline, detailed shading"` — sempre ao final.

## Status atual

- ✅ Game boot limpo com os 33 PNGs + 17 backgrounds + 4 jokers
- ✅ Componentes decompostos, CardFrame.lua reduzido de 475 → 80 LOC
- ✅ BASE_SCALE 1.333 mantém layout visual igual ao antigo
- ⚠️ `src/ui/PixelIcons.lua` tem matrizes antigas que não batem mais com o estilo sépia — mantidas só como último fallback. Todas as cartas já têm PNG, então raramente executam.
- ⚠️ Decorações `sparks/dust/smoke/flash` foram portadas para `CardDecoration.lua` mas com cores sépia em vez de neon.

## Performance

- CardFrame.render cacheado por `card.id`. ~68 IDs ≈ 6 MB de canvas.
- BackgroundLoader cacheia cada pattern uma vez.
- IconLoader cacheia handles (image ou matrix).

## UI chrome (fora de cartas)

A chrome de UI (botões, menus, settings, topbar, modais) tem o próprio design system documentado em **[`memory/ui_pixel_system.md`](ui_pixel_system.md)**. Resumo:

- Fonte: `assets/fonts/pixel.ttf` (Press Start 2P, OFL) carregada pelo FontManager com nearest filter. Substitui a fonte TTF default antiga. PixelFont delega pra FontManager (mantendo API de tamanhos semânticos).
- Button.lua: reescrito 100% pixel (PixelCanvas.rect + rectOutline + dither25 shadow). 5 estados: normal/hover/pressed/disabled/invisible. API extendida com `setIcon(name, scale)` e `setVariant("invisible")`.
- Paleta semântica: `Palette.BUTTON_FILL/FILL_HOVER/FILL_PRESSED/FILL_DISABLED`, `BUTTON_OUTLINE_HI/LO`, `BUTTON_TEXT/TEXT_INVERT/TEXT_DISABLED`, `PANEL_FILL/OUTLINE/OUTLINE_INNER`. Nunca hardcodar RGB em chrome.
- 6 ícones novos em `PixelIcons.lua` (matriz 16×16): `gear`, `x_close`, `arrow_left`, `arrow_right`, `play_triangle`, `check`. Auto-fallback PNG via IconLoader.
- Proibido em chrome: `rectangle(..., rx, ry)`, gradientes, alpha blending de sombra, `setLineWidth > 1`.
- HUD (HudPanel/HudPlayerPanel/HudEnemyPanel/CardInfoDisplay) ainda não foi convertido — ver `known_gaps.md` item 10.
