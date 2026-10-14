---
name: code_notes/tools/measure_lightpool.lua
description: Comentários com decisão/regra/histórico colhidos de tools/measure_lightpool.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/measure_lightpool.lua`

Origem: `tools/measure_lightpool.lua` em `7dbdb60d` (4 de 7 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-38 (junto a `local M = {}`)

> tools/measure_lightpool.lua
> ============================================================================
> P6' — A POÇA DE LUZ APARECE? (protocolo de DIFERENÇA POR PIXEL)
> ============================================================================
> Roda: love . measure_lightpool [bioma]      (default 4 = frost)
>
> POR QUE DIFERENÇA E NÃO BRILHO ABSOLUTO
> Medir "o pixel mais claro da região" é contaminável: o strip de montanhas
> tem NUVEM E SOL ASSADOS no PNG, e uma métrica de brilho absoluto acaba
> medindo a arte assada em vez do efeito (foi exatamente o que me enganou na
> calibração das nuvens — 3 valores de constante deram o mesmo número).
> Renderizando o MESMO frame duas vezes, com e sem luz, tudo que é assado é
> idêntico nos dois e SUBTRAI A ZERO. A diferença isola só a luz.
>
> CRITÉRIOS (fixados ANTES de rodar):
> SUCESSO  delta máximo >= 12/255 no chão junto ao emissor
> FALHA    energia de diferença DENTRO das silhuetas dos sprites — é o
> "gradiente colado em silhueta", o defeito banido no v7
> PISO     luma do ambiente >= 0.35 (MIN_AMBIENT_LUMA) em todo tod
>
> ⚠️ LIMITE CONHECIDO DESTE INSTRUMENTO (medido, não suposto)
> O critério de FALHA acima NÃO é confiável como detector de franja, e a
> razão é que o próprio toggle perturba outra coisa. Em LightEngine.lua:272
> o oclusor só entra no painter se `hit` (alguma luz toca o retângulo dele)
> OU se tem lift/flatColor; com debugNoLights a lista de luzes fica VAZIA,
> então `hit` é falso pra todo mundo e o conjunto de oclusores pintados MUDA
> entre os dois frames. Resultado: as árvores aparecem acesas na diff mesmo
> sem franja nenhuma.
> CONTROLE que fecha o caso: rodar em bioma NÃO alterado (`2` = highlands)
> dá o MESMO padrão — 34.8% da energia acima da crista, contra 25.7% do
> frost. É comportamento pré-existente do motor, não defeito introduzido.
> Portanto: use a diff pra provar que a POÇA EXISTE (é pra isso que ela
> serve e nisso ela é sólida — arte assada subtrai a zero). Pra caçar
> franja, compare o frame DE PRODUÇÃO antes/depois, com zoom 3× e em
> movimento (ritual de aceite do docs/plan/lighting-engine-v1.md).
>
> Salva no save-dir: lightpool_on.png, lightpool_off.png, lightpool_diff.png
> (a diff é amplificada 6x pra inspeção visual em zoom).

## L61-63 (em `renderFrame`, junto a `local function reportAmbient(bio)`)

> Luma do ambiente nos dois extremos do tod REAL de gameplay.
> A curva viva é GameplayScene.lua:657 → 0.62 + 0.38*prog, ou seja tod
> nunca desce de 0.62: `lightDay` puro só existe nas ferramentas.

## L105-106 (em `shots`, junto a `love.graphics.present()`)

> captureScreenshot resolve no fim do frame; mais um present garante
> que os dois ImageData existem antes do diff.

## L117-118 (em `shots`, junto a `local bandTop, bandGround = 0, 0`)

> energia de diferença por FAIXA de altura: a poça vive no CHÃO (abaixo
> da crista); diferença na faixa ALTA é luz sobre copa/silhueta = franja

