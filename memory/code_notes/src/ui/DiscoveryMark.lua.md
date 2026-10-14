---
name: code_notes/src/ui/DiscoveryMark.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/DiscoveryMark.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/DiscoveryMark.lua`

Origem: `src/ui/DiscoveryMark.lua` em `7dbdb60d` (7 de 25 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-21 (junto a `local Palette = require("src.ui.Palette")`)

> src/ui/DiscoveryMark.lua
> Carta INÉDITA na vitrine (pedido do dono, Out/2026: "quando aparecer uma
> carta que ainda não descobrimos, um efeito diferente, bem legal, nada
> brega"). Três peças, todas em coordenadas da CARTA (96x144) pra falar o
> mesmo dialeto pixel da moldura:
>
> * VARREDURA de luz — faixa diagonal em degraus que atravessa a carta uma
> vez quando ela aparece (shaders/discovery_sweep.glsl, mesmo warp do
> hover) e repassa fraca de tempos em tempos enquanto está na vitrine.
> * MARCADOR "NOVA" — fita de grimório presa na borda de cima, como
> marcador de página saindo do livro. FICA enquanto a oferta existe.
> * CHIME — audio/sfx/card-discovered.mp3, um por revelação (vários juntos
> sobem de tom em vez de empilhar).
>
> Quem é inédita: UnlockSystem.markDiscovered devolve true na virada — a
> oferta guarda isso (`offer.isNew` → `card.isNewDiscovery`). A descoberta
> vira no SORTEIO, então o selo não depende de "ainda não descoberta" no
> instante do desenho (já seria falso).
>
> reducedMotion: sem varredura e sem o carimbo descendo — o marcador fica
> (remove MOVIMENTO, nunca INFORMAÇÃO). O chime toca igual.

## L36-37 (em `DiscoveryMark`, junto a `local revealedAt = {}`)

> Primeira revelação por CHAVE (id da carta): a vitrine recria instâncias
> (compra, resize) e o efeito não pode recomeçar a cada recriação.

## L57 (em `DiscoveryMark.chime`, junto a `if _G.audioSystem and _G.audioSystem.sources and not DiscoveryMark._warned then`)

> sem áudio nenhum o Sfx já é no-op; aviso só se o som em si sumiu

## L95-96 (em `TINT`, junto a `function DiscoveryMark.sweepAt(t, w, h, once)`)

> Força da faixa no instante t (0 = apagada) e sua posição na diagonal.
> once: só a travessia de entrada (Coleção).

## L114-115 (em `DiscoveryMark.sweepAt`, junto a `function DiscoveryMark.drawSweep(image, x, y, sx, t, alpha, once, warp)`)

> Faixa de luz sobre `image` em (x, y) — coords do transform corrente.
> warp opcional: { mouseUV, hover, time } pra acompanhar o tilt.

## L144-148 (em `setc`, junto a `function DiscoveryMark.drawBadge(x, y, w, t, alpha)`)

> Marcador "NOVA" em coords da carta: (x, y) = canto sup-esq da carta, w =
> largura dela. Sai da borda de cima pra fora INTEIRO e só toca 1 px da
> linha da moldura, como fita presa entre as páginas. (Entrava 3 px e, na
> escala da tela de espólios, isso virava a fita em cima do nome da carta:
> dono, 13/Out, "tudo tampando ali em cima".)

## L211-213 (em `DiscoveryMark.drawOnCard`, junto a `DiscoveryMark.PULSE_DUR = 1.1`)

> Coleção: entrada descoberta desde a última visita pulsa UMA vez — a
> varredura de entrada e um aro dourado que acende e apaga. Sem selo: na
> Coleção a carta já é do jogador. Devolve false quando terminou.

