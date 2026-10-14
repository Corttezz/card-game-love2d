---
name: code_notes/tools/test_boss_visuals.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_boss_visuals.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_boss_visuals.lua`

Origem: `tools/test_boss_visuals.lua` em `7dbdb60d` (5 de 9 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-14 (junto a `local TK = require("tools.testkit")`)

> tools/test_boss_visuals.lua
> Trava do VISUAL DOS CHEFES (Out/2026 — "o boss 2 é meio estático
> flutuando, não intimida"; "o boss 1 não tem nada de especial"; "o boss 4
> tá meio torto"). Ver memory/boss_visuals.md.
>
> love . test_one test_boss_visuals
>
> (a) idle de chefe é LOOP assado de >= 8 quadros, mesmo canvas, e MEXE
> (os idles antigos de 4 quadros eram chuvisco de regeração)
> (b) o idle nasce do quadro base: quadro 0 do idle ≈ quadro 0 do hurt/death
> (identidade do chefe não deriva ao apanhar/morrer)
> (c) todo chefe tem aura com brilho PEQUENO e sem contorno; o emissor emite; a morte
> esvai; reducedMotion para o movimento
> (d) winter_monarch centra pelo EIXO DO CORPO, não pelo bbox

## L89-92 (em `datas`, junto a `t:truthy(string.format("%s: idle MEXE (pico %.1f%%)", id, maxD * 100),`)

> mexe (> 1.5% dos pixels no quadro mais distante do base) e NÃO é
> chuvisco de regeração: entre quadros VIZINHOS os idles antigos
> mudavam 37-46%; o assado fica em 11-22% (tronco inteiro subindo
> 1px já muda muito pixel de textura)

## L112-113 (em `datas`, junto a `t:falsy(id .. ": aura sem contorno colorido", a.rim)`)

> contorno colorido foi REJEITADO pelo dono ("a arte já tem o
> contorno dela") e brilho grande lê como bola de luz

## L122-126 (em `datas`, junto a `local savedGS = _G.gameSettings`)

> emissor emite, morte esvai, reducedMotion congela
> DETERMINÍSTICO (flake no test_all, Out/2026): o emissor é Poisson no
> RNG global e para com reducedMotion — outra suíte da bateria pode ter
> deixado _G.gameSettings com reducedMotion ligado ou o RNG num ponto
> qualquer. Fixa os dois aqui e restaura no fim.

## L147-148 (em `_G.gameSettings`, junto a `local wm = EnemyPoses.BY_ID.winter_monarch`)

> (d) eixo do monarca: dentro do conteúdo e à ESQUERDA do centro do bbox
> (o cajado à esquerda e a capa à direita puxavam o bbox pra direita)

