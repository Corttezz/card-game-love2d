---
name: code_notes/tools/test_replay.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_replay.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_replay.lua`

Origem: `tools/test_replay.lua` em `7dbdb60d` (3 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-18 (junto a `local TK = require("tools.testkit")`)

> tools/test_replay.lua
> Recomecar da tela de fim de run.
>
> O defeito (Set/2026, crash na cara do dono NO MOMENTO DA VITORIA):
>
> [Musica] musicBoss -> menuMusic (estado=victory, no=boss)
> Error: src/systems/RunManager.lua:29: Classe nao encontrada: nil
>
> Vencer e apertar ESPACO (ou perder e apertar R) chamava `startGame()` SEM
> classe, e `RunManager:startNewRun(nil)` da `error()`. Os dois caminhos
> estavam quebrados ha tempo e ninguem viu, porque teste nenhum chegava a
> tela de fim e apertava tecla — e vencer e justamente o evento mais raro de
> uma sessao de teste.
>
> Este teste nao consegue apertar tecla de verdade, mas cobre o CONTRATO que
> o caminho de recomeco tem que respeitar: startNewRun exige uma classe
> valida, e a classe da run que acabou tem que continuar disponivel depois do
> fim dela.

## L27 (em `M.run`, junto a `local RunManager = require("src.systems.RunManager")`)

> ===== A regra que o crash violava =====

## L35-37 (em `M.run`, junto a `local game = TK.newRunGame("mage")`)

> ===== A classe sobrevive ao fim da run =====
> E daqui que o recomeco tira o argumento. Se ela sumisse ao morrer ou
> vencer, o caminho cairia no nil de novo.

