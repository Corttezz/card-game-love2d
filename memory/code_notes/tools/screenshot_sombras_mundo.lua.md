---
name: code_notes/tools/screenshot_sombras_mundo.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_sombras_mundo.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_sombras_mundo.lua`

Origem: `tools/screenshot_sombras_mundo.lua` em `7dbdb60d` (7 de 10 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-18 (junto a `local M = {}`)

> tools/screenshot_sombras_mundo.lua
> Capturas de PROVA das sombras do mundo (Out/2026, "a fogueira é um
> círculo e a sombra é o círculo inteiro depois dela"). Mesmo processo,
> mesmos casos antes e depois da mudança no ShadowEngine — a comparação
> é lado a lado, por caso.
>
> love . test_one screenshot_sombras_mundo antes
> love . test_one screenshot_sombras_mundo depois
>
> Casos (relógio congelado, RNG semeado, tod 0.5 = sombra média):
> rest<b>    fogueira do descanso plantada na estrada do bioma b (1..6)
> chest1     baú (marco baixo e largo)
> props<b>   campo do bioma b (pedras, tocos, moitas, árvores, luminárias)
> fork       encruzilhada com estandarte + loja + tenda (NÃO podem mudar)
> up_<id>    criatura apoiada em pé na estrada (rato, touro, lavrador)
> dead_<id>  cadáver da mesma criatura (clip death terminado)
> float      criatura flutuante (dusk_shade)
> Saída: sombras_<tag>_<caso>.png no save dir.

## L36-40 (em `M.run`, junto a `local T0 = 1000`)

> relógio REAL congelado: flicker das luminárias e balanço de pose leem
> love.timer.getTime; sem isso o par com/sem sombra difere no campo
> inteiro (lightmap) e a máscara da sombra vira ruído.
> (constante, não a hora real: assim duas rodadas — antes/depois de uma
> mudança no motor — saem byte a byte comparáveis)

## L66-69 (em `settle`, junto a `local ShadowEngine = require("engine.ShadowEngine")`)

> cada caso sai em DOIS quadros: com sombra e com o ShadowEngine mudo
> (sprite/queue/silhouette devolvem true sem desenhar — o fallback de
> elipse também não entra). A diferença entre os dois É a sombra, e é
> o que a prancha de revisão pinta por cima.

## L85-86 (em `ShadowEngine.silhouette`, junto a `shoot = function(name, bio, pre)`)

> pre: re-arma o que o draw CONSOME (WorldRoad.draw zera o callback
> do inimigo a cada quadro — sem re-armar, o 2º quadro do par sai vazio)

## L109 (em `shoot`, junto a `for bio = 1, 6 do`)

> 1) fogueira do descanso em cada bioma + baú

## L140-141 (em `WorldRoad._landmark`, junto a `for i, nodes in ipairs({`)

> 3b) encruzilhadas SEM props (só os marcos projetam): prova de que
> estandarte, loja, tenda, obelisco e totem ficam pixel a pixel iguais

## L200-202 (em `plant`, junto a `function M.dump()`)

> Modo auxiliar: despeja os sprites PROCEDURAIS dos props (makeShrine etc.)
> como PNG, pra classificar a pegada de cada tipo olhando a arte.
> love . test_one screenshot_sombras_mundo dump

