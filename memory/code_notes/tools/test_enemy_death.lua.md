---
name: code_notes/tools/test_enemy_death.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_enemy_death.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_enemy_death.lua`

Origem: `tools/test_enemy_death.lua` em `7dbdb60d` (19 de 26 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-25 (junto a `local TK = require("tools.testkit")`)

> tools/test_enemy_death.lua
> TRAVA DO FIM DA LUTA (Set/2026).
>
> POR QUE ESTE TESTE EXISTE
> Duas queixas do dono jogando, que sao o mesmo assunto:
> 1. "em alguns cenarios, o mob nao esta tendo a animacao de morrer, cair no
> chao etc. Acho que e quando se buffa"
> 2. "a tela de vitoria ta aparecendo rapido demais, so aparece quando a
> gente tem a confirmacao que ele morreu"
>
> A causa de (1) nao era o buff: era a FONTE do golpe final. A morte so era
> encenada no caminho da carta de ATAQUE. Magia, pulso e evocacao de orbe,
> veneno e reflexo de espinhos zeravam a vida e a tela de espolios abria por
> cima de um inimigo em pe. A causa de (2) era o gate: a vitoria so esperava
> `isBlocking()`, nunca o relogio da morte.
>
> "Nao crashou" nao prova nada aqui. Cada bloco afere o TRACE de beats
> (CombatBeats grava a ordem executada) e o clip corrente do EnemyRenderer.
> Revertendo as correcoes, cai:
> * marcacao no Enemy (`_pendingDeath`)        -> 5 fontes sem morte
> * gate da vitoria (`isReadyForEndScreen`)    -> "vitoria espera a morte" cai
> * morte no beat do veneno                    -> a morte sai fora de ordem
>
> love . test_one test_enemy_death
> love . test_all

## L43-44 (em `countExact`, junto a `local function freshRenderer()`)

> Estado limpo de renderizacao: sem isto o clip "death" de um caso anterior
> ficaria de pe e o proximo bloco passaria sem ter animado nada (falso verde).

## L54-55 (em `animName`, junto a `local function assertDied(t, who, game)`)

> Um caso de "matou por X": roda `kill(game)` com o trace ligado e cobra os
> tres sinais da morte encenada.

## L70-72 (em `M.run`, junto a `do`)

> ========================================================================
> 1. CARTA DE ATAQUE (o unico caminho que ja funcionava — controle)
> ========================================================================

## L94-96 (em `card`, junto a `do`)

> ========================================================================
> 2. MAGIA (effect card) — carta que nao e do tipo "attack"
> ========================================================================

## L116-120 (em `effects`, junto a `do`)

> ========================================================================
> 3. PULSO DE ORBE (fim do turno do jogador — o "mago com as orbes")
> Era o caso mais descoberto: o proprio comentario do endTurn dizia
> "se o pulso matar, isPhaseCleared transiciona no proximo frame".
> ========================================================================

## L139-141 (em `g.player.orbs`, junto a `do`)

> ========================================================================
> 4. EVOCAR ORBE
> ========================================================================

## L161-164 (em `steps`, junto a `do`)

> ========================================================================
> 5. VENENO (DoT no fim do turno do inimigo) — aritmetica crua, fora do
> takeDamage: e por isso que a marcacao mora no Enemy e nao no caminho.
> ========================================================================

## L185-187 (em `steps`, junto a `t:eq("cadaver nao telegrafa o proximo golpe", g.enemy.nextIntent, "defend")`)

> O intent ficou como estava: `enemy.next_intent` nao rolou um golpe
> novo pra quem acabou de cair (o HUD chegava a piscar a intencao de
> um cadaver).

## L191-195 (em `steps`, junto a `do`)

> ========================================================================
> 6. ESPINHOS (reflexo no golpe do inimigo) — a leitura mais provavel do
> "quando se buffa": a carta de defesa ARMA um buff `thorn` no jogador
> e quem mata e o reflexo, nao a carta.
> ========================================================================

## L221-224 (em `effects`, junto a `do`)

> ========================================================================
> 7. REDE: morto sem marcacao nenhuma tambem cai na tela
> (fonte futura que mexa na vida por fora do Enemy)
> ========================================================================

## L238-242 (em `effects`, junto a `do`)

> ========================================================================
> 8. A VITORIA ESPERA A MORTE
> Queixa 2 do dono. O gate vive em Game:isReadyForEndScreen — e aqui
> que se prova que ele SEGURA, e nao so que existe.
> ========================================================================

## L300-306 (em `card`, junto a `do`)

> ========================================================================
> 8b. O RELOGIO DA MORTE VALE PRA VITORIA TAMBEM
> Este e o assert que separa o gate novo do antigo: antes, a vitoria
> so olhava `isBlocking()` e o `_deathPauseTimer` valia so pros
> espolios — a tela final entrava mais cedo que a tela de recompensa
> do inimigo comum, que e exatamente o "rapido demais" do dono.
> ========================================================================

## L322-324 (em `card`, junto a `do`)

> ========================================================================
> 9. INIMIGO COMUM: os espolios esperam a mesma coisa
> ========================================================================

## L337-339 (em `card`, junto a `local dt = 1 / 30`)

> Instante EXATO em que a vida zera: os espolios ja poderiam abrir
> (isPhaseCleared e so "health <= 0") e e justamente aqui que o gate
> tem que segurar — primeiro pela fila de beats, depois pelo relogio.

## L362-370 (em `card`, junto a `do`)

> ========================================================================
> 10. MORREU NO MEIO DA RESOLUCAO, COM O CHECKPOINT DA CENA RODANDO
> O TRAVAMENTO de Set/2026 ("matei o boss e o jogo parou, botoes
> cinzas"). Nenhum teste pegava porque nenhum rodava o checkpoint por
> frame da GameplayScene — e era a REPETICAO dele, entre AGENDAR e
> EXECUTAR o beat da morte, que enchia a fila de beats de 1,1s.
> Medido antes da correcao: 11 beats `enemy.death` numa jogada de 2
> cartas (~12s de fila morta); com mais cartas/procs, minutos.
> ========================================================================

## L378-380 (em `card`, junto a `local db = g.deckManager.cardDatabase`)

> Chuva de Meteoros: ataque + 3 canalizacoes de orbe na MESMA carta —
> a carta do log do dono. Os passos de orbe sao o que alonga a janela
> entre o agendamento da morte e a execucao dele.

## L422-427 (em `card`, junto a `do`)

> ========================================================================
> 11. A REDE: cadeia quebrada nao pode deixar o combate ativo pra sempre
> `isBlocking()` e o que segura o jogo INTEIRO. Se a cadeia morrer no
> meio (fila limpa por fora, elo nao empurrado), a sequencia tem que
> se encerrar e AVISAR — travar e muito pior que encerrar cedo.
> ========================================================================

## L444-445 (em `card`, junto a `CombatBeats.clear()`)

> SABOTAGEM: a fila some no meio (é o que `CombatBeats.clear` de uma
> batalha nova faz, e o que um elo esquecido causaria).

