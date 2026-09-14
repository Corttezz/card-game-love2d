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

**Timings:** o VOO tem os seus em `self.timings` (preFlight/flightDuration/
dissolveTime); o RITMO da resolução mora TODO em `CombatBeats.HOLD`
(src/systems/CombatBeats.lua) — tabela única e comentada, com
`CombatBeats.speed` como multiplicador global. O antigo `PROC_TICK`/`procHold`
morreu: a próxima carta espera a anterior TERMINAR, não um tempo estimado
(`predictJokerProcs` não pauta mais nada).

**DUAS LINHAS DO TEMPO (Set/2026):** o voo é agendado em tempo absoluto na fila
`base` (animação); a RESOLUÇÃO é uma cadeia de BEATS na fila `beats` — um
acontecimento por instante, cada um segurando o próximo. Ver
[`memory/combat_beats.md`](combat_beats.md) pra cadeia completa e a regra de
encadeamento (push vai sempre pro FIM da fila).

**Contrato crítico — `isBlocking()`:** retorna true enquanto a sequência está
ativa **OU há beats pendentes** (`CombatBeats.isBusy()`). `updateGame`/
`GameplayScene` **não disparam** enemy turn, game over, victory ou nextPhase
enquanto estiver true. **Nunca pule essa checagem.** Corolário Set/2026: o ramo
`turnStage == "acting"` do GameplayScene precisa checar `game._enemyActing`
junto — durante a cadeia do inimigo o gate de cima fica fechado e, sem a flag,
o banner do JOGADOR subia antes do golpe sair.

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

**How to apply:** efeito puramente VISUAL (shake, slow motion, dissolve,
materialize) entra como `scheduleAt(...)` na fila base do `startCombat`.
Acontecimento de JOGO (algo que o jogador precisa ler antes do próximo) entra
como `CombatBeats.push(label, fn, HOLD)` na cadeia — nunca em paralelo. Não recriar uma `CombatAnimationSystem` paralela. Para ajustar timing, mexa nos campos `self.cardFly`/`cardInterval`/etc no construtor de `CombatSequence`.
