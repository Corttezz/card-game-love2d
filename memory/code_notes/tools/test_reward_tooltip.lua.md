---
name: code_notes/tools/test_reward_tooltip.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_reward_tooltip.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_reward_tooltip.lua`

Origem: `tools/test_reward_tooltip.lua` em `7dbdb60d` (2 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-15 (junto a `local TK = require("tools.testkit")`)

> tools/test_reward_tooltip.lua
> Trava do tooltip da carta nos ESPÓLIOS (dono, 13/Out/2026: "não pode ficar
> o tooltip assim" — o painel subia por cima da barra superior e o nome da
> carta ficava escondido atrás dela).
>
> O que garante, em 4 tamanhos de janela (janela falsificada, UiScale=1):
> • hover numa carta de espólio abre o tooltip canônico (CardInfoDisplay)
> no passe final da tela, AO LADO da carta;
> • o painel nunca sobe acima da barra superior (TopBar.height + 6);
> • o painel não cobre a carta em hover e fica inteiro dentro da janela;
> • só UM tooltip por quadro (o da carta em hover);
> • com uma oferta SELECIONADA o tooltip some e a pendência não atravessa
> quadros.
>
> love . test_one test_reward_tooltip

## L79-80 (em `insts`, junto a `local CardInfoDisplay = require("src.ui.CardInfoDisplay")`)

> espião: quantos tooltips cada quadro desenha (qualquer
> CardInfoDisplay — o da tela ou o da instância)

