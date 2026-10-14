---
name: code_notes/tools/test_weather.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_weather.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_weather.lua`

Origem: `tools/test_weather.lua` em `7dbdb60d` (15 de 35 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-16 (junto a `local TK = require("tools.testkit")`)

> tools/test_weather.lua
> Travas do WeatherEngine (clima com profundidade do WorldRoad, Out/2026):
>
> 1. Todo bioma do jogo tem clima declarado (tipo conhecido, cores).
> 2. Densidade limitada pelo preset e nada vira NaN em 2 min simulados.
> 3. PAINTER: o lote sai ordenado do fundo pra frente e o WorldRoad
> desenha TODAS as partículas montadas no frame (nenhuma sobra fora
> das fatias de profundidade) — em várias fatias, não numa camada só.
> 4. Multiply-only: tempestade + raio nunca levam o ambiente acima de 1
> e o clarão nunca escurece além da tempestade.
> 5. Fotossensibilidade: ≥5 s entre raios e ≤3 acendimentos por segundo.
> 6. reducedMotion: sem raio/clarão, densidade cortada.
> 7. Troca de bioma: o clima velho some sozinho (frente de tempo, sem pop).
> 8. Fonte: flush dentro das fatias da grama, zero stencil.
>
> Roda via: love . test_one test_weather

## L53 (em `frame`, junto a `for bio = 1, 6 do`)

> 2 + 3. densidade, sanidade e painter em todos os biomas

## L73-76 (em `frame`, junto a `if i > 1 and i <= WeatherEngine.built()`)

> só o LOTE MONTADO (1..built) tem ordem garantida: folha que a
> rajada arranca DURANTE o draw (emitLeaf, sorteio do RNG global
> do mundo) entra no fim da lista e só é ordenada no frame
> seguinte — era a falha dependente de ordem da suíte (Out/2026)

## L83-84 (em `frame`, junto a `WeatherEngine.emitLeaf(0.1, WorldRoad._camZ + 3, 0.6, 0.3, { 0.5, 0.6, 0.2 })`)

> regressão: folha arrancada no meio do frame não quebra o lote
> montado nem a ordem do frame seguinte

## L126-127 (em `frame`, junto a `WeatherEngine.update(1 / 30, { biomeId = "highlands", camZ = 5.5, time = 501.5 })`)

> (o 1º update pode já ter disparado um raio; 1.5 s depois ele acabou
> e o próximo só vem ≥5 s depois — o ambiente medido é só tempestade)

## L239 (em `_G.gameSettings`, junto a `do`)

> 10. v2: densidade pela chegada ao castelo; tempestade só no fim

## L261 (em `settle`, junto a `WorldRoad.clearCache(); WorldRoad.setBiome(2); frame(2)`)

> raio nunca no começo do ato (60 s de colinas no progresso 0.3)

## L337 (em `st`, junto a `local byFam, repeatOk, nBeds = {}, true, 0`)

> camas: a mesma variante nunca começa duas vezes seguidas na família

## L352 (em `st`, junto a `local prev, okT = nil, true`)

> trovão: 30 raios seguidos, nunca o mesmo arquivo duas vezes

## L370 (em `st`, junto a `local missing = {}`)

> todo nome citado nas tabelas existe em audio/sfx/weather/

## L390 (em `check`, junto a `t:eq("estrada (batalha)", PA.placeFor("playing", {}), "road")`)

> decisão pura

## L447 (em `run`, junto a `WA.watchdog(1 / 30)`)

> como o love.update faz todo frame

## L496 (em `run`, junto a `local missing = {}`)

> todo som citado existe

## L513 (em `defs`, junto a `do`)

> 14. AMBIENTE BAIXO (dono: "muito alto"): knob único + grupo próprio

## L519-520 (em `defs`, junto a `local function db(x) return 20 * math.log10(x) end`)

> nível efetivo da cama (arquivos normalizados a −22 dB médio) contra
> o PICO da música do ato (−3.5 dB no arquivo × volume 0.6 × grupo 0.3)

