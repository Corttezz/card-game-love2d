---
name: code_notes/tools/instant_engine.lua
description: Comentários com decisão/regra/histórico colhidos de tools/instant_engine.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/instant_engine.lua`

Origem: `tools/instant_engine.lua` em `7dbdb60d` (6 de 8 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-37 (junto a `local Instant = {}`)

> tools/instant_engine.lua
> RELOGIO INSTANTANEO do simulador (Out/2026, frente de balanceamento).
>
> O jogo e dirigido por filas de eventos temporais (_G.EventManager): a
> resolucao de cada carta e o turno do inimigo sao CADEIAS de beats
> (src/systems/CombatBeats.lua), cada um segurando o proximo por 0,1-0,55 s.
> O piloto (tools/autoplay.lua) avancava esse relogio em passos de 1/30 s —
> um turno de ~2,4 s de jogo custava ~70 iteracoes de EventManager.update e,
> somando as centenas de batalhas que a simulacao de deck rejoga, era um
> terco do tempo de uma bateria.
>
> Aqui o relogio anda por SALTOS: cada iteracao avanca DT segundos de uma
> vez e repete ate nao sobrar nada pendente. A REGRA nao muda — e o mesmo
> EventManager, os mesmos beats, na mesma ordem causal:
> * um evento "before"/"after" com hold <= DT completa na mesma passada e o
> EventManager ja processa o proximo elo da cadeia na MESMA passada
> (table.remove + indice parado), entao uma cadeia inteira drena de uma
> vez;
> * o unico beat que espera algo de fora e a investida do inimigo
> (CombatBeats.pushUntil: o dano cai no APEX da animacao, em
> EnemyRenderer.update). Por isso cada iteracao tambem avanca o
> EnemyRenderer, o Enemy e o CombatSequence — exatamente o que o pump do
> piloto ja fazia, so que com dt grande.
>
> DT precisa ficar ABAIXO do timeout do pushUntil (2,5 s): o `timer` do
> evento soma dt ANTES de testar a condicao, e um salto >= 2,5 s faria o beat
> "enemy.attack" expirar por timeout na primeira passada, ANTES do apex — o
> golpe cairia fora de ordem (depois dos espinhos, do veneno, ate do upkeep
> que zera a armadura). Com DT = 1,0 s o apex (0,34 s) chega na primeira
> EnemyRenderer.update e a condicao fecha na iteracao seguinte.
>
> Nada que roda ENTRE os beats no jogo real mexe em regra: EnemyRenderer so
> dispara o callback do apex, Enemy:update so decrementa cooldown/ticker de
> exibicao, CombatSequence:update so anima cartas voando. A prova nao e este
> comentario: e tools/test_instant_parity.lua, que joga as mesmas seeds pelo
> relogio de 1/30 e pelo relogio instantaneo e exige traco identico (vida,
> escudo, mana, intent, mao e estado dos streams do Rng, turno a turno).

## L41-43 (em `Instant`, junto a `Instant.DT = 1.0`)

> Salto do relogio por iteracao. Maior que qualquer HOLD da tabela de beats
> (0,55) e que a investida inteira do inimigo (0,76); menor que o timeout do
> pushUntil (2,5). Ver cabecalho.

## L46-49 (em `Instant`, junto a `Instant.MAX_ITERS = 400`)

> Teto de iteracoes por dreno. Uma cadeia de turno tem ~10-30 elos que
> precisam de passada propria (um por golpe multi-hit, um por hold > DT);
> 400 saltos = 400 s de jogo. Estourar isso e BUG de cadeia (fila que nunca
> esvazia) e e anunciado, nunca engolido.

## L66-67 (em `tickWorld`, junto a `function Instant.drain(game)`)

> Avanca o mundo ate a fila esvaziar e o combate deixar de bloquear.
> Devolve o numero de iteracoes gastas.

## L92-94 (em `Instant.drain`, junto a `function Instant.makePump(drainPresentation)`)

> Substituto do `pump(game, secs)` do piloto: ignora `secs` (o tempo de
> espera era so animacao) e drena. Mantem o dreno de apresentacao do piloto
> por fora (quem instala passa o `drainPresentation`).

## L102 (em `Instant.makePump`, junto a `function Instant.install(Autoplay)`)

> Liga o relogio instantaneo no piloto. Idempotente.

