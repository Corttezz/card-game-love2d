---
name: UI and Rendering
description: Card 3D hover/tilt Balatro-style, HudManager + HudPanels, Theme, FontManager cache, backgrounds configuráveis
type: project
originSessionId: e544765f-309d-4fc7-89e3-58b3dabfa059
---
**Renderização de cartas — `src/cards/base/Card.lua`:**

Tecnologia chave: efeito 3D estilo Balatro via transformações 2D simuladas.

1. `updateMouse(mx, my, dt, isHovered)` calcula posição normalizada `[-1, 1]`, `depthMultiplier` via distância ao centro, e atualiza: `offsetHoverX/Y`, `tiltX/Y`, `liftOffset`, `perspectiveRotation`, `shadowOffsetX/Y`, `shadowScale`, `targetScale`.
2. `draw(x, y, showPlayableBorder, isRewardCard)`:
   - Sombra dinâmica primeiro (alpha varia com lift).
   - Borda azul pulsante (3 linhas com fade) se `canPlayCard`.
   - `love.graphics.push/translate/rotate/pop` para aplicar `perspectiveRotation` no centro.
   - Escala dinâmica: `scaleX = currentScale * (1 + |tiltX| * 0.3)`.
   - Tooltip (CardInfoDisplay) no hover se não for reward (reward desenha sua própria descrição).

**Diferenças importantes de lift:**
- Cartas na **mão** descem no hover (`baseOffsetY = -DEPTH_OFFSET`, `liftOffset = +LIFT_AMOUNT`).
- Cartas de **reward** sobem no hover (flags opostas).
- **Jokers** ativos no topo usam `JokerCard.lua` (duplicata intencional do render, escala reduzida por `JOKER_SLOT_SCALE = 0.7`).

**Parâmetros (Config.Cards):**
- `BASE_SCALE=0.20`, `HOVER_SCALE=0.22`
- `DEPTH_OFFSET=15`, `LIFT_AMOUNT=25`
- `PERSPECTIVE_STRENGTH=0.25`, `TILT_RANGE=0.15`, `MOVE_RANGE=8`
- `SHADOW_*` vários
- `PLAYABLE_BORDER_COLOR={0.3, 0.6, 0.9, 0.8}` azul semi-transparente
- `RARITY_COLORS` common/uncommon/rare/legendary/basic

**HUD — redesign pós-fevereiro-2026 (STS + Balatro):**
`src/ui/HudManager.lua` orquestra TRÊS componentes flat:
- `src/ui/HudPlayerPanel.lua` — painel 200×72 bottom-left em cores sepia (`Palette.PARCHMENT_DARK` + `INK` outline + `AGED_GOLD_DARK` borda interna). HP grande estilo Balatro + barra fina 8px + badge `armor_shield.png` (PixelLab custom, aparece só quando armor > 0, com halo steel pulsante atrás + número sobreposto com outline preto 4-offset). Damage flash vermelho ao tomar dano.
- `src/ui/ManaOrb.lua` — orb circular r=44 bottom-right com fluido azul proporcional, moldura dourada, halo pulsante, flash de gasto/ganho. Número (26pt) empilhado com gap 3px sobre `/max` (14pt) pra não sobrepor.
- `src/ui/PlayerBuffPills.lua` — row horizontal acima do player panel, mostra pills de `player.strength`/`player.dexterity`/`player.buffs[]` com ícones PixelLab (`status_strength`, `status_dexterity`) + contador sempre visível + halo colorido pulsante. Hover dispara tooltip.

Stats do inimigo ficam **no sprite** via `src/ui/EnemyHud.lua` (NÃO é um HudPanel):
- `drawIntent` — box compacto acima do sprite com ícone PixelLab custom (`intent_attack.png` = monster claw sangrando; futuro `intent_defense.png` = gauntlets cruzados via `enemy.nextIntent`) + dano grande em vermelho blood; pulsa; ajusta por `weak`
- `drawHpBar` — barra 10px sob os pés do sprite, width ≈ spriteWidth + 40, HP `X/max` com outline preto 4-offset pra legibilidade
- `drawStatusEffects` — pills circulares r=16 (badge 32px) com halo colorido + ícone PixelLab custom (`status_poison`/`status_weak`/`status_vulnerable`/`status_strength`/`status_dexterity`); contador de stacks em círculo preto com outline INK no canto inf-dir; **hover em qualquer pill chama `StatusTooltip.show`**

**Tooltip system — `src/ui/StatusTooltip.lua`:**
Singleton global ephemeral-per-frame. Componentes chamam `StatusTooltip.show(name, mx, my, {stacks, duration})` durante `draw`; `main.lua` chama `StatusTooltip.draw()` no FIM do pipeline de gameplay (após combat animation + particles) pra ficar por cima de tudo. Resolve `status.<name>.name` e `status.<name>.desc` via I18n, com interpolação `{stacks}`/`{duration}`. Fallback: capitaliza o nome e deixa desc vazia. Smart positioning: default direita do mouse, espelha se sair da tela.

**i18n:** chaves `status.poison.{name,desc}` etc. em `src/i18n/locales/pt_BR.lua` e mirror `en.lua`. Cobertura: poison, weak, vulnerable, strength, dexterity, focus, burn.

Fluxo em `main.lua`: `bbox = EnemyRenderer.draw(game, cx, cy)` → `EnemyHud.draw(game, bbox, cx, cy)`. `HudManager:draw` só desenha player panel + mana orb.

**Regra ouro pra icons PNG:** se source > target, scale fracional (`target/iconH`). Nearest filter mantém pixel sharp. Nunca `math.floor(24/64)=0 → max(1,0)=1` que draw 64×64 raw.

**Preview:** `love . preview_battle_hud` gera PNG em `~/.local/share/love/card-game/preview_battle_hud.png`. Ver `tools/preview_battle_hud.lua`.

**Importante:** `HudManager:draw` salva/restaura `love.graphics.getColor/getFont/getLineWidth/getCanvas` explicitamente — cuidado ao modificar pois sem reset o HUD polui o estado dos gráficos subsequentes.

**HudPanel legado REMOVIDO:** `src/ui/HudPanel.lua` foi deletado no refactor de Abril/2026 junto com `VisualEffects.lua`. Não reintroduzir — novos painéis devem usar Palette diretamente.

**StatusPill component:** `src/ui/StatusPill.lua` é fonte única de `COLORS` e `ICONS` pra status effects. `EnemyHud.drawStatusEffects` e `PlayerBuffPills:draw` delegam pra `StatusPill.drawRow()`. Pill config: size, spacing, animTime, pulseHalo (buffs pulsam, debuffs não), showStacksAlways (buffs sempre mostram valor).

**Sfx helper:** `src/systems/Sfx.lua` substitui todo `if _G.audioSystem then _G.audioSystem:playSound("x") end` por `Sfx.play("x")`. `AudioSystem:playSound` já é no-op se áudio não disponível (WSL2, etc.).

**FontManager.drawWithOutline:** helper pra texto com outline preto offset (padrão 4-offset ou 8-offset com diagonais). Usado em EnemyHud, HudPlayerPanel, ManaOrb.

**IconLoader.computeScale(iconH, targetSize):** regra canônica de scale (inteiro quando source ≤ target, fracional caso contrário). Evita o bug recorrente de `math.floor(24/64)=0 → scale=1 → draw 64×64 raw`.

**Theme — `src/ui/Theme.lua`:**
Paleta fixa (`Theme.Colors`): PRIMARY/SECONDARY/ACCENT/SUCCESS/WARNING/ERROR/INFO + TEXT_* + UI_* + CARD_ATTACK/DEFENSE/JOKER + HEALTH_BAR/ARMOR_BAR/MANA_BAR. Funções úteis: `Theme.Utils.interpolateColor(c1, c2, t)`, `drawVerticalGradient`, `drawRoundedRectangle`, `drawTextWithShadow`.

**FontManager — `src/ui/FontManager.lua`:**
`FontManager.getFont(size)` — cache por tamanho.
`FontManager.getResponsiveFont(ratio, maxSize)` — `min(maxSize, height * ratio)`.
`FontManager.clearCache()` — chamar ao trocar resolução (fullscreen toggle, etc.). main.lua já faz isso na tecla F.

**VisualEffects — REMOVIDO** (abr/2026): `src/ui/VisualEffects.lua` foi deletado no refactor de code review. Era imported mas nunca chamado. Se precisar de gradient/glow novo, usar `love.graphics` direto com Palette.

**Backgrounds — `src/core/BackgroundConfig.lua`:**
Registro em `BackgroundConfig.BACKGROUNDS[KEY]` com `path`, `scaleMode` (cover/contain/stretch), `opacity`, `tint`. Atualmente só GAMEPLAY tem asset real (`assets/backgrounds/step1.png`); MENU e CARD_REWARD caem em fallback.

**Smoke — `src/systems/SmokeSystem.lua` + `src/config/SmokeConfig.lua`:**
Partículas sutis que sobem. 4 presets (default/subtle/atmospheric/intense) trocáveis em runtime via teclas 1-4 no gameplay.

**How to apply:** Nunca hard-code cores (use Theme.Colors) ou coordenadas (use Config.Utils). Ao criar novo widget, herde de HudPanel se for painel de info, ou siga Button.lua como referência para widget interativo.

## Armadilhas de render descobertas no UI Overhaul (Jul/2026)

- **Fonte pixel: glifo "6" em tamanho 10 rasteriza como "G"** (não-integer
  scale do TTF). Preços e números: use `FontManager.getFont(11)` ou maior.
- **CardBack/dissolve deixa o shader ativo**: depois de desenhar carta com
  `dissolve > 0`, chame `love.graphics.setShader()` antes de desenhar texto —
  senão as letras saem "corroídas" e escuras (bug pego no título do BootScene).
- **`_G.HEADLESS_TOOL`**: setado por main.lua para QUALQUER tool de linha de
  comando (`screenshot_*`, `smoke_*`, `preview_*`, `demo_*`, validate). Sistemas
  com persistência FORA da run (ex.: `engine/ProfileStats.lua`) devem no-op no
  save quando essa flag existe — capturas de validação não podem poluir o
  perfil real do jogador.
- **Loja (CardRewardScreen)**: toda oferta tem `offer._slot` FIXO atribuído em
  show()/reroll. Draw/hover/selection SEMPRE derivam posição de `_slot` (ou de
  `inst.shopOffer`), nunca de índice compactado de array — indexar
  `shopOffers[i]` contra `cardInstances[i]` foi a raiz de 3 bugs pós-compra.
