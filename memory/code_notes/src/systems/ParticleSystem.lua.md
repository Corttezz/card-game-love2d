---
name: code_notes/src/systems/ParticleSystem.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/ParticleSystem.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/ParticleSystem.lua`

Origem: `src/systems/ParticleSystem.lua` em `7dbdb60d` (2 de 6 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-15 (junto a `local ParticlesManager = require("engine.ParticlesManager")`)

> src/systems/ParticleSystem.lua
> Compat layer + presets sobre o ParticlesManager unificado.
>
> Antes deste refactor, este arquivo continha sua própria classe Emitter +
> ParticleManager (singleton em ParticleSystem.Manager) que NUNCA recebia
> emitters spawnados — ficava só atualizando uma lista vazia em GameUI.
> Removido. Os Presets agora retornam instâncias Particles vivas no
> ParticlesManager global.
>
> USO:
> local p = ParticleSystem.Presets.JOKER_ACTIVATED(x, y)  -- spawna
> p:fade(0.4)                                             -- ou :remove()
>
> ParticleSystem.Manager.update/draw são alias pro ParticlesManager pra back-compat
> com call sites antigos em GameUI.lua etc.

## L27-28 (em `clear`, junto a `ParticleSystem.Presets = {`)

> Presets comuns. Cada um retorna a instância Particles spawnada (chamável
> com :fade(duration) ou :remove() pelo caller).

