---
name: code_notes/src/core/WindowPlacement.lua
description: Comentários com decisão/regra/histórico colhidos de src/core/WindowPlacement.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/core/WindowPlacement.lua`

Origem: `src/core/WindowPlacement.lua` em `7dbdb60d` (5 de 6 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-17 (junto a `local WindowPlacement = {}`)

> src/core/WindowPlacement.lua
> Lembra em QUAL MONITOR (e onde) a janela estava e reabre la.
>
> Antes, o jogo abria sempre no monitor 1 (conf.lua `t.window.display = 1`):
> quem joga no segundo monitor arrastava a janela toda vez. Agora:
> * no encerramento (AppLoop.shutdown) gravamos em settings.lua:
> windowDisplay = indice do monitor (1..n)
> windowX, windowY = posicao da janela DENTRO desse monitor (so em
> modo janela — em tela cheia ficam os ultimos
> valores de janela, que e o que se quer ao sair
> da tela cheia num boot futuro)
> * no love.load, `restore` move a janela pro monitor salvo ANTES do
> setFullscreen/setMode (tela cheia "desktop" ocupa o monitor onde a
> janela esta). Monitor que nao existe mais (notebook sem o externo)
> cai no 1 — nunca abre fora da tela.
> As chaves sao extras no settings.lua: SaveManager.loadSettings preserva
> chave desconhecida, entao nao precisam de default.

## L28-29 (em `WindowPlacement.validDisplay`, junto a `function WindowPlacement.validPosition(settings, w, h, dw, dh)`)

> Posicao salva se a janela (w x h) cabe inteira no desktop (dw x dh) do
> monitor; senao nil (quem chama centraliza). Pura (testavel).

## L37-38 (em `WindowPlacement.validPosition`, junto a `function WindowPlacement.restore(settings)`)

> Boot: leva a janela pro monitor salvo. Devolve o indice do monitor em uso
> (o love.load mede o desktop DELE pra dimensionar a janela).

## L53-54 (em `WindowPlacement.restore`, junto a `function WindowPlacement.restorePosition(settings, display)`)

> Depois do setMode da janela (modo janela): aplica a posicao salva se
> couber no monitor; senao mantem o centralizado.

## L63-64 (em `WindowPlacement.restorePosition`, junto a `function WindowPlacement.remember(settings)`)

> Encerramento: grava monitor (+ posicao em modo janela) em `settings`.
> Devolve true se algo mudou (quem chama decide salvar).

