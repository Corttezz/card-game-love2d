---
name: code_notes/tools/check_sfx.lua
description: Comentários com decisão/regra/histórico colhidos de tools/check_sfx.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/check_sfx.lua`

Origem: `tools/check_sfx.lua` em `7dbdb60d` (4 de 5 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-26 (junto a `local M = {}`)

> tools/check_sfx.lua
> Mede o ENVELOPE de um SFX: duração, pico, e em quanto tempo a energia cai.
> Existe porque validar som gerado por IA olhando só o header do MP3 não diz
> nada sobre o que importa no design. Caso concreto (Set/2026): `forgeStrike`
> é tocado TRÊS vezes com ~0.28s de espaçamento — se a cauda for longa, as
> três se somam e viram lama. O header não revela isso; o envelope revela.
>
> Uso:
> love . check_sfx                      -- todos os audio/sfx/*.mp3
> love . check_sfx forge                -- só os que casam com "forge"
>
> Lê: pico absoluto, RMS, e o tempo até a energia cair a 50%/10%/1% do pico
> (decay times). Para percussivo seco, t10 curto é o que se quer.
>
> ATENÇÃO — `ataque` NÃO é o início do som. É o instante do PICO.
> Um `ataque` de 0,10s pode ser (a) 100ms de silêncio antes do evento, ou
> (b) um envelope legítimo que sobe até o pico. A coluna não distingue, e
> essa ambiguidade quase fez descartar um arquivo bom (`event-choice-seal`,
> Set/2026: ataque 0,10s, mas onset audível em 0,01s — o carimbo dispara
> junto com o clique e só atinge o pico 90ms depois).
>
> Quem responde "o som começa QUANDO?" é `tools/sfx_envelope.lua`, que
> desenha a curva janela a janela e imprime o onset audível:
> love . sfx_envelope <substring>
> Regra prática: este tool diz QUANTO; o sfx_envelope diz ONDE. Som que
> responde a clique precisa de ONSET ~0; ambiente pode ter swell à vontade.

## L64-65 (em `analyze`, junto a `local peakIdx = 1`)

> Índice do pico e quanto tempo leva pra cair abaixo de cada limiar
> DEPOIS do pico (é o decay que interessa, não o ataque).

## L74 (em `decayTo`, junto a `return nil`)

> nunca cai até esse nível dentro do arquivo

## L86-88 (em `M.run`, junto a `local files = {}`)

> Varre audio/sfx E as subpastas (joker-sig/ mora lá). Sem isso os sons
> assinatura de coringa ficavam invisíveis pro checador — e foi justamente
> um deles (warrior_standard_bearer) que o dono apontou como alto demais.

