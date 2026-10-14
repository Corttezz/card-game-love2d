---
name: code_notes/src/ui/DynaText.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/DynaText.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/DynaText.lua`

Origem: `src/ui/DynaText.lua` em `7dbdb60d` (5 de 22 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-31 (junto a `local DynaText = {}`)

> src/ui/DynaText.lua
> Texto Balatro-style: cada letra com offset/rot animado individualmente.
> Port de engine/text.lua:DynaText do Balatro source (não copia matemática
> exata — refeito pra ficar copyright-safe e usar fontes love2d).
>
> Features:
> • pop_in: cascata de entrada das letras (delay por índice).
> • bump:   cada letra oscila Y em sin(rate * time + 200*k).
> • float:  oscilação sustentada (mais sutil que bump).
> • rotate: cada letra recebe pequena rotação alternada (idle wobble).
> • pulse:  scale pulse ocasional (chamado externamente).
> • quiver: tremor aleatório (medo/glitch).
> • colours: ciclo entre cores (alterna por letra ou ao longo do tempo).
>
> Uso:
> local dt = DynaText.new({
> text = "Pacote Padrão",
> fontSize = 22,
> bump = true, bump_phase = 0.42, bump_amount = 0.45,
> rotate = true, pop_in = 0.4,
> colours = { {1,0.85,0.2,1} },
> shadow = true,
> })
>
> ATENÇÃO ao `bump`: ligar sem `bump_phase` cai no default histórico 200, que
> ESPALHA as letras (ver a nota em bump_phase abaixo). Título quer 0.42; texto
> que o jogador LÊ pra decidir (número, total, contador) não quer bump nenhum
> — informação pede linha de base estável. `tools/test_dynatext_bump.lua`
> falha se algum consumidor ligar bump sem declarar a fase.
> dt:update(dt)        -- avança timer interno
> dt:draw(x, y)        -- renderiza centralizado em (x, y)

## L39-56 (em `DynaText`, junto a `function DynaText.new(config)`)

> Cria uma instância. Config opcional aceita:
> text         (string)              — obrigatório
> fontSize     (number)               default 16
> bump         (bool)                 default false   — oscilação Y forte
> bump_rate    (number)               default 2.666
> bump_amount  (number)               default 1.0     — pico = 14px * amount
> bump_phase   (number, rad)          default 200     — defasagem entre letras
> vizinhas; pequeno (~0.4)
> = onda, 200 = espalhado
> float        (bool)                 default false   — oscilação Y sutil sustentada
> rotate       (bool)                 default false   — wobble de rotação
> pop_in       (number, segundos)     default 0       — duração da cascata; 0 = sem pop_in
> pop_in_rate  (number)               default 3       — multiplica velocidade da cascata
> spacing      (number)               default 1       — px extras entre letras
> colours      (array de {r,g,b,a})   default {{1,1,1,1}}  — ciclo
> colour_cycle (number, seg)          default 0       — 0 = primeira cor sempre
> shadow       (bool)                 default false   — sombra preta atrás
> align        ("left"|"center"|"right") default "center"

## L64-69 (em `DynaText.new`, junto a `d.bump_phase = config.bump_phase or 200`)

> Defasagem de fase entre letras VIZINHAS, em radianos. O default 200 e o
> valor historico: 200 rad da 5.22 rad em modulo 2pi, ou seja ~-1.06 rad
> de salto entre vizinhas, o que ESPALHA as letras em vez de propagar uma
> onda -- num frame parado o texto parece quebrado. Um valor pequeno
> (~0.4) faz o salto viajar pela palavra como ondulacao. Mantido em 200
> por default pra nao mexer em quem ja estava afinado no olho.

## L118-119 (em `DynaText:setText`, junto a `local function utf8codes(s)`)

> Itera codepoints UTF-8: retorna { ch1, ch2, ... } onde cada ch é uma string
> 1-codepoint (multi-byte preservado). Necessário pra acentos PT-BR (ã, é, ó).

## L199-203 (em `DynaText:draw`, junto a `local sinWave = (5 + self.bump_rate) * math.sin(self.bump_rate * self.timer + self.bump_phase * i) - 3 - self.`)

> Cada letra defasada por bump_phase*k. Curva:
> max(0, (5+rate)*sin(rate*t + bump_phase*k) - 3 - rate)
> O max(0, ...) faz a letra ficar em "0" parte do tempo (~81% do
> ciclo) e pular pra cima episodicamente. bump_phase controla se
> isso vira ONDA (valor pequeno) ou ESPALHAMENTO (default 200).

