---
name: code_notes/tools/screenshot_shop_diag.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_shop_diag.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_shop_diag.lua`

Origem: `tools/screenshot_shop_diag.lua` em `7dbdb60d` (6 de 12 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-31 (junto a `local M = {}`)

> tools/screenshot_shop_diag.lua
> Capturas da Loja (v4: balcão em 1:8) em ESTADOS, fiéis à escala de UI
> (janela falsificada + canvas, como o screenshot_uiscale):
> rest        repouso (a 1ª oferta nasce selecionada)
> hovercard   mouse sobre a 2ª carta (sai do cavalete na perpendicular, sem girar)
> hoverstrip  PRANCHA 1:1 de 8 quadros do hover da 2ª carta (4 entrando,
> 4 saindo) -> diag_hoverstrip_<W>x<H>_<loc>.png
> guides      repouso com LINHAS GUIA por cima (só na prova): vermelho =
> aresta do degrau, laranja = aresta da mesa, verde = reta dos
> pés, ciano = base de cada carta, amarelo = pontas do trilho,
> magenta = pés -> diag_guides_<W>x<H>_<loc>.png (tela inteira)
> stand       recorte 1:1 do cavalete da carta 2 (trilho/plaquinha/etiqueta)
> tilt        prancha do hover: repouso + mouse no centro e nos 4 cantos
> items       a fileira da mesa com o elixir e cada um dos 5 pacotes
> plates      prancha das duas opções da plaquinha de raridade (em cima:
> comum SEM placa; embaixo: todas com placa)
> hoverjoker  mouse sobre a bancada de coringa (MESMO sprite, levantado + contorno)
> selectjoker bancada selecionada: o pergaminho mostra o MESMO sprite
> hoverdice   mouse sobre o copo de dados (contorno + nome no hover)
> hoverrelic1..3  mouse sobre a 1ª/2ª/3ª relíquia da mesa (sombra projetada
> com o quadro animado; objeto que flutua sobe e a sombra se
> separa)
> hoverbell   mouse sobre o sino
> table       recorte 1:1 da MESA inteira em repouso (sombras de todos os
> objetos) -> diag_table_<W>x<H>_<loc>.png
>
> love . test_one screenshot_shop_diag pt_BR
> SHOP_SIZES=1280x720 love . test_one screenshot_shop_diag en
> SHOP_STATES=rest,hovercard love . test_one screenshot_shop_diag
>
> Saída: diag_<estado>_<W>x<H>_<loc>.png no save dir.

## L203-204 (em `crop`, junto a `local CRT = require("src.ui.CRTShader")`)

> através do tubo, no PIOR quadro (surto no pico): "crt" com a
> zona de leitura do pergaminho (v5), "crtnocalm" sem ela

## L248-251 (em `lifts`, junto a `local ShopLayout = require("src.ui.shop.ShopLayout")`)

> LINHAS GUIA (v4): vermelho = aresta do degrau (1:8), laranja =
> aresta da mesa, verde = reta dos pés dos objetos, ciano =
> base de cada carta, amarelo = pontas do trilho na grade,
> magenta = pé de cada objeto. Tela inteira.

## L297-298 (em `line`, junto a `local it = itemWhere(function(i) return i.kind == "card" and i.index == 2 end)`)

> recorte 1:1 (px reais) do cavalete da carta 2: trilho,
> batentes, plaquinha, etiqueta; sem nada por cima

## L309-311 (em `line`, junto a `local ShopLayout = require("src.ui.shop.ShopLayout")`)

> PRANCHA DO HOVER (v4): a carta 2 com o mouse em 5 pontos
> (centro + 4 cantos, mapeados pela homografia de REPOUSO)
> e o repouso na frente: o tilt 3D da mão por cima da pose

## L338-340 (em `pts`, junto a `local L = s.scene.L`)

> PRANCHA ELIXIR + 5 PACOTES na mesa (arte v4 na diagonal):
> a relíquia 1 vira o elixir e o pacote troca de id a cada
> quadro; recorte da fileira da mesa

