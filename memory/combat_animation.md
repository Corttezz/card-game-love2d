---
name: Combat Animation System
description: CombatSequence (não CombatAnimationSystem) orquestra animação de combate via EventManager — cartas voam, são processadas, dano flutua. isBlocking() pausa Game loop.
type: project
originSessionId: e544765f-309d-4fc7-89e3-58b3dabfa059
---

**Arquivo vivo:** `src/systems/CombatSequence.lua` (~180 LOC). Substituiu o antigo `CombatAnimationSystem` (deletado em Fase 7 do redesign — não recriar). O nome do campo em `Game` ficou `game.combatAnimationSystem` por compatibilidade com `main.lua` e `GameUI`, mas a classe é `CombatSequence`.

**Mecânica:** em vez de state machine com `currentPhase`, agora usa o `EventManager` global pra encadear etapas via `EventManager.after(delay, fn)` e `EventManager.ease(...)`. Mais reusável, menos código.

**Fluxo:**
1. `startCombat(selectedCards, onComplete, onCardProcessed)` é chamado de `Game:playSelectedCards`.
2. Para cada carta: agenda `after(i * cardInterval)` para voar, `after(... + cardFly)` para chamar `onCardProcessed(card)` (que roda `Game:processCardInCombat`), e `after(... + cardProcess)` para spawn de número de dano flutuante.
3. Após a última carta + buffer, dispara `onComplete()`.

**Timings (atualmente hardcoded em CombatSequence):** `cardFly≈0.6s`, `cardProcess≈0.8s`, `damageShow≈0.6s`, `cardInterval≈0.2s`.

**Contrato crítico — `isBlocking()`:** retorna true enquanto há eventos pendentes na fila do combate. `updateGame` em `main.lua` **não dispara** enemy turn, game over, victory ou nextPhase enquanto estiver true. **Nunca pule essa checagem.**

**Integração:**
```lua
-- Game.lua
self.combatAnimationSystem:startCombat(
    self.selectedCards,
    function() self:onCombatAnimationComplete() end,
    function(card) return self:processCardInCombat(card) end
)
```

**Importante:** `Game:playSelectedCards` remove as cartas da mão **antes** de iniciar a animação (evita clique duplo). Se mexer aqui, preserve essa ordem.

**Áudio:** usa `Sfx.play("swordSound"|"armorSound")` durante processing.

**How to apply:** para adicionar novo efeito visual em combate (screen shake, slow motion, dissolve, materialize) agende um `EventManager.after(...)` no momento certo do `startCombat`. Não recriar uma `CombatAnimationSystem` paralela. Para ajustar timing, mexa nos campos `self.cardFly`/`cardInterval`/etc no construtor de `CombatSequence`.
