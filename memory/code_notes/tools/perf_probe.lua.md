---
name: code_notes/tools/perf_probe.lua
description: Comentários com decisão/regra/histórico colhidos de tools/perf_probe.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/perf_probe.lua`

Origem: `tools/perf_probe.lua` em `7dbdb60d` (7 de 14 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-15 (junto a `local M = {}`)

> tools/perf_probe.lua
> Sonda de CUSTO DE FRAME das cenas pesadas (revisão de lançamento, Out/2026).
> Mede, por bioma do WorldRoad, o tempo de CPU de update+draw e as
> estatísticas do renderer (draw calls, trocas de canvas/shader, memória de
> textura). Não é teste (não falha): é instrumento — rode antes/depois de
> mexer em cena. A trava de regressão é tools/test_perf_budget.lua.
>
> love . test_one perf_probe                  (janela atual)
> love . test_one perf_probe 1920x1080        (tamanho pedido)
> love . test_one perf_probe profile          (+ jit.profile por linha)
> love . test_one perf_probe 1920x1080:phases (+ ms por fase do draw)
>
> Leitura: >16.6 ms de CPU = abaixo de 60 fps só de CPU; draw calls na casa
> dos milhares em GPU integrada é o primeiro suspeito de queda de fps.
> Máquina compartilhada = ruído: compare MEDIANA/p95, não média/pior.

## L26-28 (em `measure`, junto a `local samples, first = {}, nil`)

> Mede só o TRABALHO do frame (update+draw+flush), fora do present —
> o present espera o vsync e mascararia tudo em ~16.6 ms. O 1º frame
> (carga de assets do bioma) sai separado: é o "engasgo" da troca de ato.

## L52-53 (em `M.run`, junto a `local size, mode = nil, nil`)

> arg: "1920x1080", "phases", "profile" ou combinado "1920x1080:phases"
> (o dispatcher test_one repassa um único argumento)

## L68-69 (em `M.run`, junto a `if mode == "jitv" then`)

> jitv: registra TODO abort/flush de trace desde o início (blacklist é
> histórico — abortos repetidos no MESMO ponto viram interpretador)

## L97-98 (em `frame`, junto a `local swProf, swCounts, swTotal`)

> "switch": perfil por amostragem SÓ dos 1ºs frames de cada troca de
> bioma (onde mora o engasgo) — top linhas acumuladas nas 5 trocas

## L109-112 (em `firsts`, junto a `local worst = 0`)

> 1º frame do bioma SEM aquecimento: é o engasgo da troca de
> ato. Os 3 primeiros frames saem separados (o pior deles é o
> número que importa); depois a troca de bioma (crossfade de
> 2.2s) corre e o regime estável é medido sozinho.

## L237-238 (em `keys`, junto a `if mode == "jitv" then`)

> Diagnóstico do JIT: traces abortados (NYI) nos laços quentes do draw.
> Laço que escreve FFI e NÃO compila fica mais lento que chamada C.

