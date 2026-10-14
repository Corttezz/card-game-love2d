---
name: code_notes/engine/Particles.lua
description: Comentários com decisão/regra/histórico colhidos de engine/Particles.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `engine/Particles.lua`

Origem: `engine/Particles.lua` em `7dbdb60d` (5 de 15 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-30 (junto a `local Utils = require("engine.Utils")`)

> engine/Particles.lua
> Emissor de partículas unificado, inspirado em
> balatro-source/engine/particles.lua. Substitui o trio anterior:
> ParticleSystem.Manager / CardParticles.Emitter / (smoke continua independente).
>
> Diferenças vs Balatro:
> Não herda Moveable. Posição própria + opção de `attach` (target com .x/.y).
> Suporte a textura sprite opcional (Balatro só desenhava retângulos).
> API standalone (sem G.E_MANAGER, G.TIMERS, G.SETTINGS.paused).
>
> USO:
> local p = Particles:new(cx, cy, w, h, {
> fill = true,                       -- spawn em rect; false = no centro
> attach = card,                     -- opcional: segue card.x/card.y
> timer = 0.03,                      -- intervalo de spawn (s)
> lifespan = 0.6,
> scale = 0.3,
> speed = 80,
> colours = { {1,0.5,0,1}, {1,0.2,0,1} },
> texture = nil,                     -- love.Image opcional
> max = 200,                         -- pool máximo
> pulse_max = nil,                   -- nil = contínuo; N = one-shot
> vel_variation = 1,                 -- 0..1 (1 = velocidade plena)
> gravity = 0,                       -- px/s² em vy (negativo = sobe: fogo/fumaça)
> layer = 0,                         -- z-order (maior = mais por cima)
> })
> p:fade(0.3)   -- inicia fade-out em 0.3s
> p:remove()    -- mata imediatamente
>
> Auto-cleanup: instâncias removidas saem do ParticlesManager no próximo update.

## L80-82 (em `particles`, junto a `local function syncAttach(self)`)

> Atualiza a posição se há `attach`. Recolhe x/y, w/h direto do target
> (interpretamos `card.x/card.y` como canto superior-esquerdo no projeto;
> se attach.image existe, calcula bbox).

## L107-110 (em `Particles:update`, junto a `if self.dead and #self.particles == 0 then return end`)

> Só early-return quando totalmente morto (dead E pool vazia). Sem isso,
> quando syncAttach seta dead=true (attach._removed), o NEXT frame congelava
> as partículas existentes — paravam de envelhecer e o fade_alpha travava
> mid-fade, deixando partículas semi-transparentes presas na tela pra sempre.

## L120-121 (em `Particles:update`, junto a `local canSpawn = (self.pulse_max == nil or self.pulsed < self.pulse_max)`)

> Spawn novas partículas: enquanto não atingiu pulse_max, pool não cheio
> e ainda não estourou fade.

## L180-181 (em `Particles:update`, junto a `if (self.fade_alpha >= 1 and #self.particles == 0)`)

> Pronta pra remover quando: (a) dead manual, ou (b) fade completo + pool vazio,
> ou (c) attach morreu + pool vazio.

