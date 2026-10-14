---
name: code_notes/src/entities/Player.lua
description: Comentários com decisão/regra/histórico colhidos de src/entities/Player.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/entities/Player.lua`

Origem: `src/entities/Player.lua` em `7dbdb60d` (15 de 21 blocos de comentário tinham marcador de decisão/regra/histórico).

## L6-8 (em `Player`, junto a `local DEFAULT_ORB_SLOTS = 3`)

> Slots de orb (Fase 2): orbs sao stackados por cartas de channel.
> Orb = { type="lightning"|"ice"|"dark"|"fire"|"holy", value=N }
> Ao evocar, aplica efeito e remove (FIFO: evoca o mais antigo).

## L21-23 (em `Player:new`, junto a `instance.strength = 0`)

> Estatisticas transientes (resetadas por batalha em resetTransientStats).
> Strength = bonus aditivo a todo ataque; Dexterity = bonus aditivo a toda defesa.
> Acumulam durante a batalha via cartas tipo "gain_strength".

## L31-32 (em `instance.orbs`, junto a `instance.buffs = {}`)

> Buffs genericos (nome + duracao em turnos). Diferente de orbs/strength,
> permitem efeitos narrativos (ex: "focus", "concentration") e expiram por turno.

## L35-39 (em `instance.buffs`, junto a `instance.debuffs = {}`)

> DEBUFFS que o INIMIGO aplica (Out/2026, src/data/enemies.lua):
> weak/frail/vulnerable/poison/burn. Lista separada de `buffs` porque o
> relógio é outro: buff decai no upkeep do jogador; debuff decai no FIM
> do turno do inimigo e PULA o turno em que foi aplicado (padrão StS
> "justApplied") — "Fraco 2" vale para os 2 próximos turnos do jogador.

## L45-47 (em `instance.debuffs`, junto a `function Player:takeDamage(damage, pierce)`)

> `pierce` = golpe que ATRAVESSA o Bloqueio (lança de gelo, raio rúnico).
> A Vulnerabilidade do jogador já vem aplicada no dano pelo Enemy
> (intentHitDamage) — aqui ela não entra de novo.

## L58-62 (em `Player:takeDamage`, junto a `local DOT_DEBUFF = { poison = true, burn = true }`)

> ===== Debuffs do inimigo =====
> DoT (poison/burn) soma PILHAS e fica com a MAIOR duração; weak/frail/
> vulnerable somam duração. Somar as duas coisas no DoT (como o Enemy faz)
> compunha: duas nuvens de peste = o dobro de dano pelo dobro de turnos — o
> Colosso do ato 5 matava o piloto pela soma, não pela leitura (bateria Out/2026).

## L114-116 (em `Player:decayDebuffs`, junto a `function Player:tickDebuffDots()`)

> Veneno/queimadura no JOGADOR: perda de vida que ignora o Bloqueio, no
> começo do turno dele. Devolve (veneno, queimadura) — dois números, nunca
> somados (mesma regra do Enemy:onTurnEnd).

## L125 (em `Player:tickDebuffDots`, junto a `function Player:applyWeakToAttack(dmg)`)

> Fraco: os ATAQUES do jogador causam 25% menos.

## L141-143 (em `Player:addArmor`, junto a `function Player:loseHealth(value)`)

> Perda de HP DIRETA (ignora armor). Usada por custos auto-infligidos
> (self_damage, damage_per_turn) — "pagar com sangue" não pode ser
> absorvido pela armadura, senão o custo é fictício (auditoria F0).

## L194-195 (em `Player:gainDexterity`, junto a `function Player:addOrb(orb)`)

> Adiciona um orb ao fim da fila. Se cheio, descarta o mais antigo (e retorna-o
> pro caller aplicar efeito "overflow evoke" no futuro, por ora ignoramos).

## L221-225 (em `Player:countOrbsByType`, junto a `local NON_CUMULATIVE_DURATION = { thorn = true }`)

> Buffs cuja DURACAO nao acumula: stackear dois deles soma a intensidade mas
> a janela continua sendo a mesma (o buff vale "ate o meu proximo turno").
> "thorn" (Espinhos, Set/2026) e o caso: duas Barreiras de Fogo no mesmo turno
> refletem mais, nao por mais turnos — somar duracao faria o reflexo sobreviver
> ao turno seguinte, que e exatamente o contrario do contrato StS.

## L228-229 (em `NON_CUMULATIVE_DURATION`, junto a `function Player:addBuff(name, duration, stacks)`)

> Adiciona/stack um buff nomeado. Se ja existe, soma duracao e stacks
> (excecao: NON_CUMULATIVE_DURATION mantem a maior duracao).

## L254-255 (em `Player:getBuffStacks`, junto a `function Player:onTurnStart()`)

> Chamado no inicio do turno do jogador. Decrementa duracao de buffs e
> remove expirados. Efeitos continuos ja foram aplicados (strength e stat, nao buff).

## L257-260 (em `Player:onTurnStart`, junto a `if not self.retainArmor then`)

> F1 gameplay-overhaul: BLOQUEIO ZERA todo turno (StS). Defesa vira
> decisão por turno em vez de poupança — o "banco de armor 50" que
> imunizava o jogador morreu aqui. Jokers futuros podem setar
> retainArmor pra manter uma fração.

## L273-274 (em `Player:onTurnStart`, junto a `function Player:resetTransientStats()`)

> Reseta stats transientes (fim de batalha). Strength/dexterity/orbs/buffs sao
> per-battle por default. Coisas permanentes (maxHealth, maxMana base) ficam.

