---
name: code_notes/src/ui/IntentVeil.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/IntentVeil.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/IntentVeil.lua`

Origem: `src/ui/IntentVeil.lua` em `7dbdb60d` (4 de 12 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-18 (junto a `local IntentVeil = {}`)

> src/ui/IntentVeil.lua
> Véu de névoa desenhado SOBRE o box do intent quando a visibilidade não é
> cheia (src/systems/IntentVisibility.lua). É a metade de UI da leitura: a
> outra metade é o mundo (o WeatherEngine engrossa a nevasca pelo mesmo
> estado). O véu existe porque o "?" sozinho lê como bug de dado; com bruma
> correndo por cima, lê como clima.
>
> Estilo: bruma em PIXEL de arte (textura de ruído 64x32 em nearest, duas
> camadas correndo em sentidos opostos, quantizadas em passos de 2 px),
> tingida pela cor do bioma. Nada de gradiente liso.
>
> Transições: a opacidade persegue o alvo do nível (~0,25 s). Quando o véu
> CAI (carta de Revelar, clareira), um aro claro pisca uma vez — o jogador
> precisa ver que a leitura voltou, não só perceber depois.
>
> IntentVeil.draw(x, y, w, h, level, color, key)
> IntentVeil.alphaFor(level)        -- alvo por nível (fonte única)
> IntentVeil.reset()

## L71-73 (em `build`, junto a `local function stateFor(key, target)`)

> O estado NASCE no alvo: o véu de um anúncio já encoberto aparece inteiro
> no 1º quadro (capturas de um quadro só e a chegada do inimigo); só as
> TROCAS de nível são eased.

## L92-93 (em `IntentVeil.reset`, junto a `function IntentVeil.currentAlpha(key)`)

> Opacidade corrente do véu de `key` (0 = sem véu). Pra testes e pra quem
> quer saber se há névoa visível sobre o box.

## L116-117 (em `IntentVeil.draw`, junto a `love.graphics.push("all")`)

> recorta ao box (cantos arredondados do EnemyHud ficam por conta da
> margem de 2 px)

