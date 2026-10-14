---
name: code_notes/conf.lua
description: Comentários com decisão/regra/histórico colhidos de conf.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `conf.lua`

Origem: `conf.lua` em `7dbdb60d` (4 de 44 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-3 (junto a `local okRelease, Release = pcall(require, "src.core.Release")`)

> DEV x RELEASE vem de src/core/Release.lua (flag unica: build_info.lua, que
> so o tools/build_release.py escreve). conf.lua roda antes dos modulos
> love.*, e o Release nao toca nenhum no carregamento.

## L11-12 (em `love.conf`, junto a `t.identity = Release and Release.identity() or (os.getenv("CARDGAME_IDENTITY") or "card-game")`)

> Save dir: DEV "card-game" (historico), RELEASE "Grimoire".
> CARDGAME_IDENTITY sobrepoe (frentes paralelas/smoke nao pisam no save real).

## L15 (em `love.conf`, junto a `t.console = not (Release and Release.isRelease())`)

> Console so em DEV: o executavel publicado nao abre janela preta junto.

## L40-51 (em `love.conf`, junto a `if os.getenv("CARDGAME_HEADLESS") == "1" and not (Release and Release.isRelease()) then`)

> SIMULACAO SEM JANELA (Out/2026, pipeline de balanceamento): o dono viu
> "varias janelas do Grimoire" abrindo durante as baterias paralelas.
> Com CARDGAME_HEADLESS=1 (tools/balance.py seta; `love . balance_sim`
> aceita tambem) a janela nasce com 1x1, sem borda e fora de qualquer
> monitor; tools/headless_window.lua (balance_sim.setup) ainda a esconde
> via user32 pra sumir da barra de tarefas. Nao da pra tirar a janela de
> vez (t.window = nil): o jogo e os tools criam canvas/imagem, que exigem
> contexto grafico. O que importa e que NADA fica visivel.
> (love.window.minimize() no load NAO serve: o SDL re-mostra a janela e
> ela volta pra barra de tarefas — medido.)
> So em DEV: no pacote a variavel de ambiente do jogador nao pode sumir
> com a janela (o dispatcher de tools nem existe la).

