---
name: code_notes/tools/boss_rooms.lua
description: Comentários com decisão/regra/histórico colhidos de tools/boss_rooms.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/boss_rooms.lua`

Origem: `tools/boss_rooms.lua` em `7dbdb60d` (9 de 14 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-17 (junto a `local M = {}`)

> tools/boss_rooms.lua
> Galeria INTERATIVA das salas de chefe: cada ato com o chefe dele dentro,
> pelo caminho real de desenho (GameplayScene.draw), já depois da cerimônia
> da porta. Mesma montagem do screenshot_enemy_scene, mas ao vivo.
>
> love . boss_rooms [ato|shots]
> BOSS_ROOMS_SIZE=1920x1080 love . boss_rooms shots   (tamanho da janela:
> o cover-fit corta a arte diferente em 4:3 e em 16:9 — confira os dois)
> BOSS_ROOMS_VIRTUAL=2560x1440 ... shots  (tela maior que o monitor)
> BOSS_ROOMS_SEQ=6 ... shots   (+6 quadros seguidos por sala: animação)
>
> 1-6 / ← →  troca de ato (sala + chefe)
> I          ENTRADA do chefe (salão vazio → cinemática, com som e trilha)
> K          MORTE pelo pipeline real (câmera lenta, rajada, corpo no salão)
> H          animação de dano     J  remonta a sala
> Enter/Espaço  pula a cinemática     ESC  sai
> Com som: o main.lua despacha este tool DEPOIS de registrar os sons.

## L40 (em `M.run`, junto a `local sw, sh = (os.getenv("BOSS_ROOMS_SIZE") or ""):match("^(%d+)x(%d+)$")`)

> UM setMode só, antes de montar (setMode repetido dentro de tool trava)

## L44-46 (em `M.run`, junto a `local vw, vh = (os.getenv("BOSS_ROOMS_VIRTUAL") or ""):match("^(%d+)x(%d+)$")`)

> BOSS_ROOMS_VIRTUAL=2560x1440: tela FALSIFICADA maior que o monitor
> (setMode acima do desktop trava). Desenha num canvas desse tamanho com
> getWidth/getHeight mentindo e a captura sai do canvas.

## L69-73 (em `mount`, junto a `_G.EventManager.clear()`)

> Linha do tempo NOVA pra cada sala. A fila de eventos é global e
> sobrevive ao Game antigo: trocar de ato antes da mão terminar de
> materializar (ou depois de H/K) deixava eventos órfãos da sala
> anterior na frente, e as cartas da mão nova nasciam invisíveis
> (dissolve=1) — "a mão só aparece no ato 1".

## L104-106 (em `run.currentNode`, junto a `local code = require("src.systems.MusicDirector").pick("playing", run, "boss", true)`)

> Trilha do chefe (a do ato; no 6 a faixa do eclipse): o despacho
> deste tool no main.lua é DEPOIS do registro dos sons justamente
> pra entrada (I) e morte (K) tocarem com som e música de verdade.

## L125-126 (em `love.update`, junto a `require("src.ui.BossCinematic").update(dt, _G.game, { inHall = true })`)

> cinemática do chefe (I = entrada, K = morte): relógio dela ANTES do
> EnemyRenderer (câmera lenta = escala do dt dele)

## L167-168 (em `drawFrame`, junto a `if shots and seqLeft > 0 and frames >= 4 then`)

> BOSS_ROOMS_SEQ=n: além do quadro principal, n quadros seguidos
> (a cada 4 frames) pra conferir animação — boss_room_<ato>_<k>.png

## L185 (em `drawFrame`, junto a `if a >= total then love.event.quit() else pendingKey = tostring(a + 1) end`)

> troca pelo MESMO caminho da tecla (é ele que o dono usa)

## L208-209 (em `love.keypressed`, junto a `local g = _G.game`)

> MORTE pelo pipeline real (beat enemy.death → _onEnemyDeath →
> clip + cinemática de morte no salão)

