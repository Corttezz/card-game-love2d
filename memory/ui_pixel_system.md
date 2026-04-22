---
name: UI Pixel Chrome Design System
description: Regras canônicas para botões, painéis, modais e texto pixelados fora das cartas. Fonte Press Start 2P bundled, paleta grimoire, primitivas PixelCanvas.
type: reference
---

# UI Pixel Chrome — design system

Chrome de UI (botões, menus, settings, topbar, modais, telas de fim de jogo). As cartas têm o próprio pipeline em `src/ui/card/`; tudo o que está **fora** das cartas segue as regras abaixo.

## 1. Fonte padrão

- Arquivo: `assets/fonts/pixel.ttf` (Press Start 2P, OFL).
- Loader único: `src/ui/FontManager.lua`. `getFont(size)` cacheia por tamanho e aplica `setFilter("nearest", "nearest")` (crítico — sem isso a fonte vira borrão).
- Se o TTF falhar ao carregar, FontManager cai no default LÖVE com aviso no console. O jogo não quebra.
- `src/ui/PixelFont.lua` delega pra FontManager e oferece tamanhos semânticos (`tiny=8`, `small=10`, `body=12`, `header=14`, `title=20`, `heading=28`) + `drawShadowed(text, x, y, size, color, shadowColor)` com offset 1px.
- **Nunca** usar `love.graphics.newFont(size)` direto — sempre pelo FontManager/PixelFont.
- Tamanhos recomendados pra Press Start 2P: 8, 10, 12, 14, 16, 20, 24. Tamanhos grandes ficam bem crunchy, perfeito.
- Substituir por outra TTF livre (ex: m6x11, Alagard, Dogicapixel): só jogar em `assets/fonts/pixel.ttf`. Zero código muda.

## 2. Paleta de estados — `src/ui/Palette.lua`

Aliases (seção "UI Chrome") — **sempre referenciar por nome, não hardcodar RGB**:

| Alias | Cor base | Uso |
|---|---|---|
| `BUTTON_FILL` | PARCHMENT_DARK | fundo do botão normal |
| `BUTTON_FILL_HOVER` | AGED_GOLD | fundo hover (inverte contraste) |
| `BUTTON_FILL_PRESSED` | PARCHMENT | fundo ao pressionar |
| `BUTTON_FILL_DISABLED` | STEEL | fundo desabilitado |
| `BUTTON_OUTLINE_HI` | AGED_GOLD_LIGHT | borda de volume claro |
| `BUTTON_OUTLINE_LO` | AGED_GOLD_DARK | borda de volume escuro |
| `BUTTON_OUTLINE_DISABLED` | STEEL_LIGHT | borda desabilitado |
| `BUTTON_TEXT` | PARCHMENT_LIGHT | texto normal |
| `BUTTON_TEXT_INVERT` | INK | texto em fundo gold (hover/pressed) |
| `BUTTON_TEXT_DISABLED` | STEEL_LIGHT | texto desabilitado |
| `BUTTON_SHADOW` | INK | sombra dither |
| `PANEL_FILL` | INK | fundo de modal/painel |
| `PANEL_OUTLINE` | AGED_GOLD | borda externa |
| `PANEL_OUTLINE_INNER` | AGED_GOLD_DARK | borda interna dupla |
| `PANEL_TEXT` | PARCHMENT_LIGHT | texto em painel |
| `PANEL_TEXT_DIM` | PARCHMENT | texto secundário |

## 3. `Button` — API e estados

Arquivo: `components/Button.lua` (reescrito pra pixel puro).

```lua
local btn = Button:new(x, y, w, h, text, onClick, color, fontSize)
btn:setIcon("gear", 2)       -- ícone à esquerda do texto (IconLoader.get)
btn:setVariant("invisible")  -- só hit area, não desenha (p/ hitboxes de cartas)
btn:setEnabled(true)
btn:update(dt)
btn:draw()
btn:mousepressed(x, y, 1)
btn:mousereleased(x, y, 1)
```

Estados (5):

| Estado | Fill | Outline | Texto | Offset |
|---|---|---|---|---|
| normal | BUTTON_FILL | BUTTON_OUTLINE_HI | BUTTON_TEXT | 0,0 |
| hover | BUTTON_FILL_HOVER | INK | BUTTON_TEXT_INVERT | 0,0 |
| pressed (+hover) | BUTTON_FILL_PRESSED | BUTTON_OUTLINE_LO | BUTTON_TEXT_INVERT | +1,+1 |
| disabled | BUTTON_FILL_DISABLED | BUTTON_OUTLINE_DISABLED | BUTTON_TEXT_DISABLED | 0,0 |
| invisible | skip draw | — | — | — (preserva hit rect) |

**Regras:**
- Posições sempre inteiras (`math.floor`).
- Nada de `scale` fracionário em hover (quebra grid pixel). Use shift +1,+1 em pressed.
- Sombra via `PixelCanvas.dither25` (2px strip à direita e abaixo), nunca alpha blend.
- Rivets 2×2 nos 4 cantos quando `w >= 10 and h >= 10`.
- Ícone opcional via `IconLoader.get(name)` com `scale` inteiro (1, 2, 3).

## 4. Primitivas permitidas — `src/ui/PixelCanvas.lua`

Tudo desenhado fora das cartas DEVE passar pelas primitivas abaixo (ou chamadas equivalentes de `love.graphics.rectangle("fill", ...)` com coords inteiras):

- `rect(x, y, w, h, color)` — retângulo sólido
- `rectOutline(x, y, w, h, color)` — outline 1px interior
- `rectFramed(x, y, w, h, fill, outline)` — atalho para os dois acima
- `hline(x, y, len, color)` / `vline(x, y, len, color)` — linhas 1px
- `pixel(x, y, color)` — 1 pixel
- `dither25(x, y, w, h, color)` / `dither50` — padrões dither
- `drawBitmap(matrix, ox, oy, palette?)` / `drawBitmapScaled(matrix, ox, oy, scale, palette?)`

**Proibido em chrome de UI:**
- `love.graphics.rectangle(..., rx, ry)` com cantos arredondados
- `love.graphics.setLineWidth(n)` com `n > 1` (o vetor anti-aliased vira borrão)
- Gradientes via `VisualEffects.Utils.drawLinearGradient` (grave qualquer gradiente como dither ou 2-3 retângulos)
- Alpha blending em sombras (`setColor(0,0,0,0.45)`)
- `setColor(hex_literal_rgb)` — sempre via `Palette.set(Palette.XYZ)`

## 5. Ícones de UI — 6 novos em matriz

Adicionados em `src/ui/PixelIcons.lua` (usam `Palette.INDEXED`: 1=VOID outline, 13=YELLOW=gold fill):

- `gear` — engrenagem de settings/topbar
- `x_close` — X de fechar modais
- `arrow_left` / `arrow_right` — navegação
- `play_triangle` — botão play
- `check` — toggle LIGADO

Acesso via `IconLoader.get(name)` → `handle.draw(x, y, scale)`. Auto-fallback: se `assets/sprites/icons/<name>.png` existir, substitui a matriz sem mudar código.

## 6. Callers hoje (chrome passou pelo pipeline)

| Arquivo | Uso |
|---|---|
| `components/Button.lua` | base do pipeline |
| `components/Menu.lua` | 4 botões (play/collection/gear/close) com ícones |
| `components/SettingsMenu.lua` | modal pixel (sem cantos arredondados), toggles com check/x |
| `components/ClassSelectionScreen.lua` | banner pixel, 3 class buttons com ícones de arma |
| `components/TopBar.lua` | fundo pixel + rivets, gear icon em vez de config.png |
| `components/CardRewardScreen.lua` | modal, offers e purchase confirmation 100% pixel |

**Fora do escopo atual** (próxima passada, ver `known_gaps.md`):
- `src/ui/HudPanel.lua` (legado — não é mais base de componentes ativos; `HudPlayerPanel.lua` foi reescrito flat em 2026-02 e `HudEnemyPanel.lua` foi removido. Enemy stats agora ancoradas no sprite via `EnemyHud.lua`).
- `src/ui/CardInfoDisplay.lua` (tooltip com alphas).
- `src/systems/MessageSystem.lua` (toasts).
- `src/ui/VisualEffects.lua` (helpers de gradient/glow — não usar em chrome).

## 7. Como adicionar um botão novo

```lua
local Button = require("components.Button")

local btn = Button:new(x, y, 180, 40, "SALVAR",
    function() print("clicked") end,
    nil,    -- accent color (opcional, não usado atualmente)
    12)     -- tamanho da fonte (múltiplo de 2 recomendado)
btn:setIcon("check", 1)
```

Pra um botão só com ícone (sem texto): passe `text = ""` e o ícone será centralizado.

Pra uma hitbox invisível (ex.: capturar clique sobre uma carta desenhada por outro sistema):
```lua
btn:setVariant("invisible")
```

## 8. Como adicionar um ícone novo

Opção A — matriz 16×16 em `src/ui/PixelIcons.lua`:
```lua
PixelIcons.my_icon = {
    {0,0,0,0, ... 16 cols},  -- 16 linhas total
    ...
}
```
Valores: 0 = transparente, 1..17 = índice `Palette.INDEXED`. Convenção: 1 = outline escuro, 13 = gold fill, 7 = metal claro, 17 = highlight branco puro.

Opção B — PNG em `assets/sprites/icons/<name>.png`:
`IconLoader.get("name")` prefere PNG se existir. Sem recompilar nada.

## 9. Verificação manual

1. `love .` no root.
2. Menu: fonte pixel crocante, botões com ícones, hover inverte fill/outline, press desloca 1px.
3. Settings: modal sem cantos arredondados, toggles mostram check/x, close tem x_close.
4. Class selection: banner pixel, 3 botões com ícones de arma, voltar com arrow_left.
5. Gameplay: TopBar com gear girando em hover, rivets dourados.
6. Card reward: modal pixel, compra/cancela com check/x, hitboxes invisíveis funcionam (clicar numa carta abre confirmação).

## 10. Troubleshooting

- **Fonte borrada** → conferir `setFilter("nearest", "nearest")` no FontManager. Checar se `assets/fonts/pixel.ttf` existe.
- **Botão desapareceu depois de `setVariant("invisible")`** → correto; o hit rect continua ativo. Pra debug, temporariamente comente o `return` em `Button:draw()` dentro do if variant=="invisible".
- **Cantos arredondados aparecendo** → grep `rectangle\(.*,.*,.*,.*,.*,.*,.*\)` (7 args) e substitua por `PixelCanvas.rect` + `rectOutline`.
- **Texto PT-BR sem acentos** → Press Start 2P tem Latin-1; confirmar encoding UTF-8 no arquivo. Se ainda falhar, pode trocar por m6x11 (suporta extended).
