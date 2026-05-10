---
name: Particles Unified
description: ParticlesManager + Particles (port do Balatro). CardParticles e ParticleSystem.Manager são shims. SmokeSystem segue independente.
type: project
---
`engine/Particles.lua` + `engine/ParticlesManager.lua`. Port adaptado de `balatro-source/engine/particles.lua` (sem herança Moveable; standalone).

**Por que mudou (Abril/2026):** havia 3 sistemas fragmentados com pools próprios — `ParticleSystem.Manager` (genérico, NUNCA recebia emitters spawnados), `CardParticles` (atachado a cartas), `SmokeSystem` (atmosférico). Sem reuso, sem unificação. ParticleSystem.Manager era código morto.

**Arquitetura agora:**
- `Particles` — classe de emissor config-driven. Suporta:
  - Spawn em `fill` (rect aleatório) ou centro
  - `attach = target` (segue `target.x/.y` a cada frame; respeita `target.image/currentScale` pra bbox)
  - `pulse_max` (one-shot vs contínuo), `vel_variation`, `colours` (lista), `texture` opcional (sprite em vez de retângulo)
  - `:fade(duration)`, `:stop()`, `:remove()`, `:isDead()`
  - `layer` (z-order opcional)
- `ParticlesManager` — registry global. `spawn(x, y, w, h, config)` cria + registra; `update(dt)` e `draw()` ticam tudo. Cleanup automático de instâncias dead.

**Tick centralizado:** `main.lua:love.update` chama `CardParticles.update(dt)` que delega ao ParticlesManager. `main.lua:love.draw` chama `CardParticles.draw()` no fim do frame (dentro do CRT scene + screen shake). **Não chame `ParticlesManager.update/draw` em scenes** — geraria double-tick. GameplayScene/CombatSequence foram limpos disso.

**Compat shims (mantidos pra não quebrar call sites):**
- `src/systems/CardParticles.lua` (~50 LOC): `CardParticles.emit(card, cfg)` cria Particles com `attach=card`, retorna instância (suporta `:fade/:stop`). API legada (`update/draw/clear/activeCount`) preservada.
- `src/systems/ParticleSystem.lua`: `ParticleSystem.Manager` virou alias com métodos no-op-equivalentes pro ParticlesManager (back-compat). `ParticleSystem.Presets` (JOKER_ACTIVATED/CARD_PLAYED/HOVER_EFFECT/DAMAGE_EFFECT) agora **spawnam direto** e retornam a instância — não precisa `addEmitter`.

**SmokeSystem fica como está:** `src/systems/SmokeSystem.lua` tem físicas atmosféricas únicas (vento, drift vertical, sin-wave wobble baseado em age). Refatorar adiciona risco sem grande payoff. Tem seu próprio update/draw e roda paralelo ao manager unificado.

**How to apply:**
- Burst genérico em coordenada: `ParticleSystem.Presets.DAMAGE_EFFECT(x, y)` (ou outro preset).
- Custom no-preset: `ParticlesManager.spawn(x, y, w, h, { ... })`.
- Atachado a carta: `CardParticles.emit(card, { ... })`.
- Texturizado: passar `texture = love.graphics.newImage(...)` no config.
- Para tinge run-time de preset (ex: defesa azul): preset retorna instância, mute `instance.colours = {{r,g,b,1}}` antes de spawnar partículas suficientes.
