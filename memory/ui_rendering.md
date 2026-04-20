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

**HUD — `src/ui/HudManager.lua`:**
Orquestra `HudPlayerPanel` (canto inferior esquerdo, verde, HP/Armor/Mana) + `HudEnemyPanel` (canto inferior direito, vermelho, HP/Damage/Phase). Herdam de `HudPanel` (base com gradientes, glass effect, glow animado, partículas).
**Importante:** `HudManager:draw` salva/restaura `love.graphics.getColor/getFont/getLineWidth/getCanvas` explicitamente — cuidado ao modificar pois sem reset o HUD polui o estado dos gráficos subsequentes.

**Theme — `src/ui/Theme.lua`:**
Paleta fixa (`Theme.Colors`): PRIMARY/SECONDARY/ACCENT/SUCCESS/WARNING/ERROR/INFO + TEXT_* + UI_* + CARD_ATTACK/DEFENSE/JOKER + HEALTH_BAR/ARMOR_BAR/MANA_BAR. Funções úteis: `Theme.Utils.interpolateColor(c1, c2, t)`, `drawVerticalGradient`, `drawRoundedRectangle`, `drawTextWithShadow`.

**FontManager — `src/ui/FontManager.lua`:**
`FontManager.getFont(size)` — cache por tamanho.
`FontManager.getResponsiveFont(ratio, maxSize)` — `min(maxSize, height * ratio)`.
`FontManager.clearCache()` — chamar ao trocar resolução (fullscreen toggle, etc.). main.lua já faz isso na tecla F.

**VisualEffects — `src/ui/VisualEffects.lua`:**
Glass rectangles, animated borders, energy particles, text com glow, radial gradients. Usado por GameUI, CardRewardScreen.

**Backgrounds — `src/core/BackgroundConfig.lua`:**
Registro em `BackgroundConfig.BACKGROUNDS[KEY]` com `path`, `scaleMode` (cover/contain/stretch), `opacity`, `tint`. Atualmente só GAMEPLAY tem asset real (`assets/backgrounds/step1.png`); MENU e CARD_REWARD caem em fallback.

**Smoke — `src/systems/SmokeSystem.lua` + `src/config/SmokeConfig.lua`:**
Partículas sutis que sobem. 4 presets (default/subtle/atmospheric/intense) trocáveis em runtime via teclas 1-4 no gameplay.

**How to apply:** Nunca hard-code cores (use Theme.Colors) ou coordenadas (use Config.Utils). Ao criar novo widget, herde de HudPanel se for painel de info, ou siga Button.lua como referência para widget interativo.
