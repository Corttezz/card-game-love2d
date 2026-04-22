# HUD de Batalha — Arquitetura

## Visão geral

Redesign STS + Balatro (fev/2026): painéis de canto com gradientes foram substituídos por chrome minimalista.
O HUD se divide em **três blocos**, cada um com propósito e localização espacial clara:

1. **HudPlayerPanel** — stats do jogador, canto inferior esquerdo (flat sepia).
2. **ManaOrb** — mana do jogador, canto inferior direito, estilo Balatro.
3. **EnemyHud** — HP / intent / status effects **ancorados no sprite do inimigo** (Slay the Spire).

Não há mais "painel de inimigo" no canto da tela. O que o jogador precisa saber sobre o inimigo fica *no inimigo*.

## Arquitetura

```
HudManager              ← src/ui/HudManager.lua
├── HudPlayerPanel      ← src/ui/HudPlayerPanel.lua  (bottom-left)
└── ManaOrb             ← src/ui/ManaOrb.lua          (bottom-right)

EnemyHud                ← src/ui/EnemyHud.lua
                           (não é HudPanel; desenhado direto em main.lua
                            logo após EnemyRenderer.draw)
```

## Fluxo de draw em `main.lua` (gameplay)

```
1. Background
2. TopBar                                      (gold, deck, settings)
3. drawJokersAsCards()                         (Balatro jokers no topo)
4. bbox = EnemyRenderer.draw(game, cx, cy)     (sprite animado + partículas)
5. EnemyHud.draw(game, bbox, cx, cy)           (HP bar, intent, status pills)
6. GameUI:draw(game)
   └── HudManager:draw(game)
       ├── HudPlayerPanel:draw(game.player)
       └── ManaOrb:draw(game.player)
7. Cartas na mão
8. Botão Jogar
9. Animação de combate (overlay)
10. CRT shader (opcional)
```

## Componentes

### HudPlayerPanel (`src/ui/HudPlayerPanel.lua`)

- **Tamanho:** 200×72 px (fixo; antes era 28%×18% responsivo = ~280×140).
- **Paleta:** `Palette.PARCHMENT_DARK` bg + `Palette.INK` outline + `Palette.AGED_GOLD_DARK` borda interna (consistente com cartas/UI sepia do resto do jogo).
- **Layout:**
  - Label "HERÓI" dourado no topo (11pt).
  - HP grande (24pt) com `hp` principal + `/max` menor ao lado.
  - Barra HP fina (8px) abaixo — vermelho `BLOOD`, vira `HP_BAR_LOW` laranja quando `hp < 30%`.
  - Badge armor circular `STEEL` à direita, visível só quando `armor > 0`, halo pulsante (sin(t*3)).
- **Damage flash:** overlay vermelho 0.35 α quando `player.health` cai; decai em 3/s.

### ManaOrb (`src/ui/ManaOrb.lua`)

- **Formato:** círculo r=40 no canto inferior direito.
- **Visual:** fundo escuro `{0.05, 0.08, 0.18}` + círculo interno azul `{0.20, 0.42, 0.92}` cujo raio é `r * (0.55 + 0.25 * mana%)` — quanto mais mana, mais "cheio". Highlight lunar branco pequeno no quadrante sup-esq pra dar volume 3D.
- **Moldura:** `AGED_GOLD_DARK` outline 3px + `AGED_GOLD` interno 1px + `INK` 2px externo.
- **Halo pulsante:** `{0.30, 0.55, 0.95, 0.25}` respirando em `sin(t*2.5)`. Fica 0.35 intensidade quando `mana==0` (lembra ao jogador que acabou).
- **Flash:** vermelho 0.5 α quando mana cai (gasto, decai 4/s), azul-verde 0.35 quando sobe (ganho, decai 2/s).
- **Tipografia:** número atual 32pt bold com outline preto 6-offset (legível sobre azul) + `/max` 18pt azul claro abaixo, centralizados verticalmente como bloco.

### EnemyHud (`src/ui/EnemyHud.lua`)

Renderiza **três sub-elementos** ancorados no sprite do inimigo:

**`drawIntent(enemy, cx, topY)` — acima do sprite:**
- Box compacto horizontal: ícone espada 24px (via IconLoader) + número de dano à direita em vermelho blood (22pt).
- Pulsa em `sin(t*3) * 0.08` de alpha vermelho — telegrafia ataque iminente.
- Ajusta automaticamente por `enemy:hasStatus("weak")` → dano × 0.75.

**`drawHpBar(enemy, cx, groundY, spriteWidth)` — sob o sprite:**
- Width adaptativa: `max(160, min(260, spriteWidth + 40))`.
- Altura 10px, track escura + fill vermelho `BLOOD` + highlight 3px no topo + outline `INK`.
- Número `HP / max` acima da barra (13pt) com outline preto 4-offset — legível sobre qualquer background do ato.

**`drawStatusEffects(enemy, cx, groundY)` — abaixo do HP bar:**
- Pills circulares r=16 (badge 32×32), spacing 8px, centralizadas em `cx`.
- Cada pill tem halo colorido exterior + fundo escuro + outline colorido + ícone central (22px).
- Mapeamento `name → icon`:
  - `poison` → `potion_red` (verde)
  - `weak` → `skull` (roxo)
  - `vulnerable` → `eye` (laranja)
  - `burn` → `flame` (vermelho)
  - `strength` → `sword_short` (vermelho escuro)
- Fallback: inicial maiúscula da letra colorida no centro.
- Stacks > 1: contador em círculo preto no canto inf-dir do badge (8px radius, outline `INK`).

## EnemyRenderer (integração)

`EnemyRenderer.draw(game, cx, cy)` agora retorna:
```lua
{ cx = cx, topY = drawY, bottomY = cy, width = iw*scale, height = ih*scale }
```
ou `false` se o sprite ainda não está em disco (no-op gracioso).

`EnemyHud.draw` aceita esse table e usa as coordenadas pra ancorar seus três sub-elementos. Se `bbox == false`, cai em fallback com posição default.

## Regra ouro: icons PNG de 64×64

O projeto tem ícones em duas origens:
- **Matrix** (fallback, 16×16) — `scale = 1` desenha 16px, scale=2 desenha 32px etc.
- **PNG** (`assets/sprites/icons/*.png`, **64×64**) — precisa scale **fracional** se o target < 64.

Usar sempre:
```lua
local scale
if iconH <= target then
    scale = math.max(1, math.floor(target / iconH))
else
    scale = target / iconH    -- fracional (nearest filter mantém pixel sharp)
end
```

Sem isso, `math.floor(20/64) = 0 → max(1, 0) = 1` e o icon desenha 64×64 raw, cobrindo todo o badge.

## Preview tool

`tools/preview_battle_hud.lua` renderiza um frame simulado de batalha em PNG pra iterar o visual sem precisar jogar:

```bash
love . preview_battle_hud
# saída: ~/.local/share/love/card-game/preview_battle_hud.png
```

Fake state editável no próprio arquivo (HP, mana, armor, status effects do inimigo).

## Arquivos legados

- `src/ui/HudPanel.lua` — classe base antiga com gradientes de 20 passos, glass overlay, glow multi-camada. Não é usada por nenhum componente ativo depois do redesign. Mantida por enquanto pra não quebrar imports que eventualmente existam, mas pode ser removida em limpeza futura.
- `src/ui/HudEnemyPanel.lua` — **removido**. Toda a informação que ele exibia agora está em `EnemyHud`.
