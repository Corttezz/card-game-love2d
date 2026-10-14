---
name: code_notes/src/ui/EndTransition.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/EndTransition.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/EndTransition.lua`

Origem: `src/ui/EndTransition.lua` em `7dbdb60d` (3 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-24 (junto a `local EndTransition = {}`)

> src/ui/EndTransition.lua
> A transição de FIM DE RUN (morte / vitória): desliga a TV, troca de tela,
> religa. Com uma TRAVA DE REENTRADA, que é a razão deste módulo existir.
>
> O BUG QUE ISTO MATA (Set/2026, relatado pelo dono: "ao morrer no jogo a tela
> fica preta e não tem como voltar pro menu, só fechando o jogo"):
>
> O fim de run é disparado por uma CONDIÇÃO, não por um evento.
> `GameplayScene.update` chama a transição sempre que `game:checkGameOver()`
> é verdadeiro — e morte não deixa de ser verdadeira no frame seguinte. Cada
> chamada substituía o `powerAnim` do CRTShader por um novo, com o cronômetro
> zerado. A 60 fps isso reiniciava o desligamento 60 vezes por segundo: o
> callback que troca `currentState` nunca chegava ao fim, a TV ficava
> desligada para sempre e nenhuma tecla respondia, porque o estado continuava
> sendo "playing".
>
> A lição geral, que vale para qualquer efeito com callback no projeto:
> **animação disparada por condição precisa de trava; animação disparada por
> evento não.** Quem dispara todo frame tem que perguntar "já estou fazendo
> isso?" antes de começar de novo.
>
> Mora num módulo (e não inline no main.lua) porque o guard precisava ser
> TESTÁVEL — dentro do closure de `love.load` nenhum teste o alcança, e foi
> justamente um caminho sem teste que deixou o defeito chegar ao dono.

## L31-36 (em `EndTransition`, junto a `function EndTransition.start(name, fadeOut, apply)`)

> start(name, fadeOut, apply)
> name    : "gameOver" | "victory"
> fadeOut : função(duração, callback) — normalmente CRTShader.powerOff
> apply   : função(name) — troca o estado e religa a TV
> Devolve true se ESTA chamada iniciou a transição; false se foi ignorada por
> já haver uma em curso.

## L47-49 (em `EndTransition.start`, junto a `function EndTransition.clear() pendingTo = nil end`)

> Sair de gameOver/victory (voltar ao menu, recomeçar) limpa a transição.
> Sem isto, uma transição que ficasse de pé travaria a PRÓXIMA morte — o
> mesmo sintoma, uma run depois, e muito mais difícil de relacionar à causa.

