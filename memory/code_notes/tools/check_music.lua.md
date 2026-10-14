---
name: code_notes/tools/check_music.lua
description: Comentários com decisão/regra/histórico colhidos de tools/check_music.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/check_music.lua`

Origem: `tools/check_music.lua` em `7dbdb60d` (3 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-14 (junto a `local M = {}`)

> tools/check_music.lua
> Percorre os contextos do jogo e diz QUAL faixa tocaria em cada um, usando o
> caminho REAL: AudioManager de verdade, `MusicDirector.registerTracks` de
> verdade, `MusicDirector.apply` de verdade.
>
> Existe porque `tools/test_music.lua` testa só a decisão (`pick`, que é pura)
> e a suíte nunca executa `love.update` — ou seja, nada na suíte exercita o
> registro, o `resolve` com fallback, nem o `playMusic`. Foi assim que um
> `local` a mais no topo do main.lua passou verde em 35 suites e derrubou o
> jogo no boot ("more than 60 upvalues").
>
> Roda com o MASTER EM ZERO: valida sem tocar som na máquina de ninguém.
>
> love . check_music

## L73-75 (em `M.run`, junto a `if now ~= audio.currentMusic then`)

> A faixa que o diretor diz estar tocando tem que ser a que o
> AudioManager realmente pegou. Divergir aqui significa que o
> playMusic falhou em silencio.

## L81 (em `M.run`, junto a `local wanted = MD.pick(c[1], c[2], c[3])`)

> Contexto caindo em fallback é legítimo, mas tem que aparecer.

