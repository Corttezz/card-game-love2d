---
name: code_notes/src/systems/CardParticles.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/CardParticles.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/CardParticles.lua`

Origem: `src/systems/CardParticles.lua` em `7dbdb60d` (3 de 5 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-7 (junto a `local ParticlesManager = require("engine.ParticlesManager")`)

> src/systems/CardParticles.lua
> Thin compat shim sobre ParticlesManager. Mantém a API legacy
> (CardParticles.emit / .update / .draw / .clear / .activeCount) para call sites
> existentes, mas internamente delega tudo ao ParticlesManager unificado.
>
> A ideia: card-attached emitters não são uma categoria especial — são apenas
> Particles com `attach = card`. ParticlesManager.update/draw cuidam do tick.

## L13-14 (em `CardParticles`, junto a `function CardParticles.emit(card, cfg)`)

> Cria emissor seguindo uma carta. cfg compatível com a API antiga
> (timer/lifespan/scale/speed/colours/fill/max/pulse_max/vel_variation).

## L40-41 (em `CardParticles.emit`, junto a `function CardParticles.update(dt) ParticlesManager.update(dt) end`)

> update/draw centralizados no ParticlesManager. Chamadas do main.lua
> continuam funcionando sem mudança.

