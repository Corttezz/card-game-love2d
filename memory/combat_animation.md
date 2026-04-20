---
name: Combat Animation System
description: Balatro-style: cartas voam ao centro e são processadas sequencialmente; isBlocking() pausa Game loop
type: project
originSessionId: e544765f-309d-4fc7-89e3-58b3dabfa059
---
`src/systems/CombatAnimationSystem.lua` (~490 LOC).

**Fases (currentPhase):**
1. `idle` — sistema parado.
2. `cards_flying` — cartas voam da mão para o centro (intervalo `cardInterval=0.2s`, easing out-quart).
3. `processing` — cada carta é processada individualmente via callback `onCardProcessed(card)`. Aqui é que `Game:processCardInCombat` roda (aplica dano, defesa, joker, efeito).
4. `damage_dealing` — exibe números flutuantes coloridos (vermelho = dano, azul = bloqueio, amarelo = nome).
5. `complete` — fade out, dispara `onComplete` callback (`Game:onCombatAnimationComplete` limpa seleção e muda turno).

**Timings (self.timings):** `cardFly=0.6`, `cardProcess=0.8`, `damageShow=0.6`, `cardInterval=0.2`.

**Contrato crítico:** `isBlocking()` retorna true durante a animação. `updateGame` em main.lua **não dispara** enemy turn, game over, victory ou nextPhase enquanto estiver true. **Nunca pule essa checagem.**

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

**Áudio:** o sistema usa `_G.audioSystem:playSound("swordSound"|"armorSound")` durante processing. Fallback local cache via `pcall(love.audio.newSource, ...)` se o global não estiver disponível.

**How to apply:** Para adicionar novo efeito visual em combate (ex: screen shake, slow motion), adicione em `CombatAnimationSystem:update(dt)` gerenciado por estado, não em `Game.lua`. Para ajustar timing, mexa em `self.timings`.
