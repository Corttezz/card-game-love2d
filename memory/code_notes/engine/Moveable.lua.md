---
name: code_notes/engine/Moveable.lua
description: Comentários com decisão/regra/histórico colhidos de engine/Moveable.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `engine/Moveable.lua`

Origem: `engine/Moveable.lua` em `7dbdb60d` (21 de 40 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-35 (junto a `local Moveable = {}`)

> engine/Moveable.lua
> Mixin de "juice" + T/VT pra qualquer objeto visual. Inspirado em
> engine/moveable.lua do Balatro.
>
> DOIS PADRÕES distintos que este módulo provê:
>
> 1) T/VT (Target vs Visible Transform)
> Você muda T.x/y (onde quer estar); VT.x/y interpola suavemente por frame.
> O draw usa VT. Resultado: trocar posição vira animação automática.
>
> Implementação (Fase 1 — Balatro-style): damping exponencial via
> *velocity* (com momento + clamp), não tween posicional. Tornou-se padrão
> pra qualquer obj novo no projeto.
>
> Obs: Card legacy tem targetX/renderX próprio — não migrar agora pra evitar
> risco. Use TVT em NOVOS objetos (Button, Tooltip, ShopSlotWidget, etc.).
>
> 2) juice_up (bounce multiplicativo)
> Chama `Moveable.juice_up(obj, scale_mod, rot_mod)` quando algo ACONTECE
> (carta jogada, hit, mana gasto). scaleFactor()/rotOffset() compõem no draw.
>
> Uso típico (sem herança):
>
> Moveable.initJuice(self)
> Moveable.initTVT(self, x, y)
> ...
> function obj:update(dt)
> Moveable.updateJuice(self, dt)
> Moveable.updateTVT(self, dt)
> end
> function obj:draw()
> local s = self.VT.scale * Moveable.scaleFactor(self)
> local r = self.VT.r + Moveable.rotOffset(self)
> love.graphics.draw(..., self.VT.x, self.VT.y, r, s, s)
> end

## L53-56 (em `Moveable.initJuice`, junto a `function Moveable.juice_up(obj, scale_mod, rot_mod)`)

> Dispara um "kick" de juice. Sobrescreve juice anterior (não empilha).
> Padrão Balatro: sine wave 50.8/40.8 freq com cubic falloff em 0.4s fixos.
> scale_mod: 0.1 (sutil) — 0.5 (forte). Multiplicativo no draw via scaleFactor().
> rot_mod:   0.05–0.2 (radianos). Direção alterna entre kicks consecutivos.

## L59-61 (em `Moveable.juice_up`, junto a `if _G.gameSettings and _G.gameSettings.reducedMotion then`)

> Reduced motion (Balatro engine/moveable.lua:251 G.SETTINGS.reduced_motion):
> desliga TODO juice quando flag global ativa, pra acessibilidade ou
> preferência. Usuário marca em SettingsMenu → _G.gameSettings.reducedMotion.

## L77-78 (em `Moveable.juice_up`, junto a `if obj.VT and obj.VT.scale then`)

> Pre-shrink visual (Balatro): VT.scale começa "comprimido" pra dar pop ao
> soltar. Aplicado se obj tem VT; senão é no-op.

## L84-85 (em `Moveable.juice_up`, junto a `function Moveable.hop_up(obj, px, duration)`)

> ============ HOP + SWELL (game feel v2, Jul/2026) ============
> Canais independentes do juice de scale/rot — compõem no draw.

## L87-88 (em `Moveable.juice_up`, junto a `function Moveable.hop_up(obj, px, duration)`)

> HOP: pulinho vertical (meia-senoide sobe-e-volta). px = altura do pulo.
> Uso: carta de ataque "investe", joker "pula" no proc.

## L97-98 (em `Moveable.hop_up`, junto a `function Moveable.swell_up(obj, scale_add, duration)`)

> SWELL: crescida SEM oscilação (sobe rápido, assenta devagar). Diferente do
> juice_up que vibra — o swell "incha" (carta de defesa ganhando corpo).

## L107-109 (em `Moveable.swell_up`, junto a `function Moveable.shove_x(obj, px, duration)`)

> SHOVE: empurrão HORIZONTAL de aparada (game feel v3.3 — a defesa "apara
> o golpe": checa pro lado, segura um instante e volta com um TIQUE de
> mola). px pode ser negativo (lado). Sem dir, alterna a cada uso.

## L123-126 (em `Moveable.shove_x`, junto a `function Moveable.shoveOffset(obj)`)

> Offset X atual do shove. Envelope de APARADA: estala pro lado (14%),
> SEGURA deslocada (até 42% — tempo de LER o desvio), e volta de MOLA
> amortecida — cruza o centro e dá um tique no lado oposto antes de
> assentar (o "tique e volta" pedido).

## L147-150 (em `Moveable.shoveOffset`, junto a `function Moveable.hopOffset(obj)`)

> Offset Y atual do hop (negativo = pra cima). Some no offset vertical do draw.
> v3.2: envelope CHUNKY (feedback do dono "se mexe é mt pouco") — meia-senoide
> suave lê como flutuação invisível; o olho precisa de ESTALO + PAUSA:
> sobe num estalo (12%), SEGURA no alto (até 45%), cai rápido, QUICA no fim.

## L179-180 (em `Moveable.swellFactor`, junto a `local env`)

> v3.2: incha num ESTALO (8%), SEGURA inchada (até 55% — leitura), e só
> então desinfla. O decay suave desde o início lia como "nada mexeu".

## L193 (em `Moveable.swellFactor`, junto a `function Moveable.updateJuice(obj, dt)`)

> Atualiza decay. Chame em update(dt). Sine wave * cubic falloff (padrão Balatro).

## L197-198 (em `Moveable.updateJuice`, junto a `if j.hop_duration and j.hop_timer and j.hop_timer < j.hop_duration then`)

> Hop/swell tickam SEMPRE (independentes do timer do juice scale/rot —
> o early-return abaixo não pode congelá-los no meio do movimento).

## L219 (em `Moveable.updateJuice`, junto a `local falloff_scale = (1 - progress) ^ 3`)

> Falloff cúbico (1-progress)^3 — padrão Balatro pra scale.

## L223-224 (em `Moveable.updateJuice`, junto a `j.scale = j.scale_amt * math.sin(50.8 * j.timer) * falloff_scale`)

> Sine waves de alta frequência (50.8 / 40.8 rad/s no Balatro). Em love2d
> usamos timer absoluto, mesma ideia.

## L229-230 (em `Moveable.updateJuice`, junto a `function Moveable.scaleFactor(obj)`)

> Fator de escala atual do juice. Use no draw multiplicando seu scale base.
> Curva: oscilação Balatro ao redor de 1.0 com decay cúbico.

## L244 (em `Moveable.rotOffset`, junto a `function Moveable.initTVT(obj, x, y, scale, rot)`)

> ============ T vs VT (velocity-based damping, padrão Balatro) ============

## L254-256 (em `Moveable.initTVT`, junto a `local DAMP_XY    = 50`)

> Damping exponencial constants (Balatro): rates per second.
> xy=50, scale=60 (mais lento que xy), r=190 (mais rápido que xy).
> Velocidade máxima default 70*dt*60 → 4200 px/s a 60fps. Override via obj.MAX_VEL.

## L262-263 (em `Moveable.initTVT`, junto a `function Moveable.updateTVT(obj, dt)`)

> Atualiza VT em direção a T usando velocity-based exponential damping.
> Inclui hover/drag scale modifiers se obj.zoom=true e obj.states existir.

## L291-292 (em `Moveable.updateTVT`, junto a `local des_scale = obj.T.scale`)

> Scale desejado: T.scale + hover/drag (se obj.zoom). Juice é multiplicado no
> draw via scaleFactor() — não compor aqui.

## L317-319 (em `Moveable.updateTVT`, junto a `function Moveable.simpleEaseTVT(obj, dt, k)`)

> Tween posicional simples (sem velocity). Mantido pra casos que não querem
> momento/overshoot (ex: tooltip que precisa "encaixar" instantaneamente).
> k controla rigidez: 8=flutuante, 16=tátil, 24=snappy.

