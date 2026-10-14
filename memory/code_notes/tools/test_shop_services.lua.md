---
name: code_notes/tools/test_shop_services.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_shop_services.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_shop_services.lua`

Origem: `tools/test_shop_services.lua` em `7dbdb60d` (27 de 41 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-40 (junto a `local TK = require("tools.testkit")`)

> tools/test_shop_services.lua
> SERVIÇOS DA LOJA (Set/2026): tesoura (remover), prensa (duplicar), bancada
> de coringa (+1 slot ativo) e grimório (+1 compra por turno).
>
> O QUE ESTA SUITE TRAVA (e por que cada trava existe)
>
> 1. CUSTO CRESCENTE + TETO. Serviço barato pra sempre é serviço que zera a
> decisão econômica: com remoção a $8 fixa o jogador compra todas e o
> deck vira uma faca. O custo tem que subir por compra NA MESMA RUN.
>
> 2. DISPONIBILIDADE É ESTADO, NÃO SORTE. A tesoura some quando o deck está
> no osso (RestScreen:doRemove recusa deixar o deck abaixo de 2 cartas —
> vender ali é vender algo que a tela seguinte nega), e os serviços com
> teto somem da vitrine quando o teto é batido. Sem isso a loja cobra por
> nada.
>
> 3. A TESOURA É FIXA NA PRATELEIRA. Com seis relíquias disputando as vagas,
> uma remoção sorteada apareceria em ~1 de cada 6 lojas e a mecânica
> viraria decoração. O teste prova que ela está em TODA vitrine de loja
> (e em NENHUMA recompensa pós-batalha, que não vende serviço).
>
> 4. O EFEITO ACONTECE DE VERDADE. Slot comprado tem que deixar um QUARTO
> coringa ficar ativo; compra extra tem que aparecer no draw do turno E
> na mão inicial da batalha. Esta é a lição do P3.2 (rebalance Jul/2026):
> três upgrades ficaram meses na vitrine aplicando só um toast.
>
> 5. PAGOU E NÃO LEVOU = ESTORNO. Os serviços de deck cobram ANTES de abrir
> o picker de carta, e o picker pode ser fechado no "Voltar". Sem estorno
> o ouro some e o slot fica carimbado VENDIDO. (A forja tinha esse buraco
> desde sempre; ele entra na mesma trava.)
>
> 6. O LEDGER SOBREVIVE AO SAVE. Slot de coringa e compra extra são
> permanentes: se `currentRun.services` não viajasse no save, fechar o
> jogo devolveria os coringas pra bancada.
>
> 7. A VITRINE DE 2 RELÍQUIAS AINDA CABE. `upgrades` foi de 1 pra 2; a
> fileira 2 da loja agora tem 4 células. A geometria é provada em vários
> tamanhos de janela, não olhada numa captura.
>
> love . test_one test_shop_services

## L77-79 (em `M.run`, junto a `local rm = RunManager:new()`)

> ========================================================================
> 1. CUSTO: cresce por compra e bate no teto
> ========================================================================

## L92 (em `M.run`, junto a `for _ = 1, 20 do rm:registerService("remove_card") end`)

> Teto: muitas compras não deixam o custo explodir.

## L106-108 (em `M.run`, junto a `local rm2 = RunManager:new()`)

> ========================================================================
> 2. DISPONIBILIDADE por estado da run
> ========================================================================

## L132-134 (em `M.run`, junto a `local game = TK.newRunGame("warrior")`)

> ========================================================================
> 3. VITRINE: tesoura fixa na loja, ausente na recompensa, sem repetida
> ========================================================================

## L148 (em `M.run`, junto a `t:eq("bancada de coringa aparece em TODA vitrine de loja", semBancada, 0)`)

> Out/2026 (queixa do dono: "nao consigo alcancar a bancada"): FIXA.

## L151-152 (em `M.run`, junto a `for _ = 1, Config.Offers.SERVICES.joker_slot.maxPerRun do`)

> Teto de compras batido: a bancada SOME e a vaga volta pro sorteio
> (a prateleira continua com 3 reliquias, nenhuma delas a bancada).

## L188 (em `M.run`, junto a `local ofertaTesoura`)

> Oferta montada carrega o que a tela precisa pra aplicar.

## L204-210 (em `M.run`, junto a `local rmPeso = RunManager:new()`)

> ========================================================================
> 3b. A VITRINE OLHA A RUN: coringa parado na bancada puxa a oferta
> ========================================================================
> Sem isso a bancada de coringa disputa a vaga rotativa em pé de igualdade
> com outras cinco relíquias e aparece em ~1 de cada 6 lojas — quem
> acumulou coringas pode terminar a corrida sem nunca ver a coisa que
> resolveria o problema dele.

## L218-219 (em `M.run`, junto a `t:truthy("bancada de coringa nunca pesa MENOS com coringa parado",`)

> Desde Out/2026 a bancada e FIXA (peso 0, fora do sorteio); o
> multiplicador de pressao continua valendo se ela voltar a rotacionar.

## L227-229 (em `M.run`, junto a `local gj = TK.newRunGame("warrior")`)

> ========================================================================
> 4. EFEITO REAL: slot de coringa e compra extra
> ========================================================================

## L273-284 (em `gd.hand`, junto a `local EconomySystem = require("src.systems.EconomySystem")`)

> ========================================================================
> 4b. COFRE: o teto dos juros sobe, e sobe de verdade
> ========================================================================
> Diferente das outras relíquias, esta REALIMENTA a fonte de ouro. As
> travas aqui são três:
> • o teto efetivo sai do LEDGER, não de um campo solto que alguém
> esqueceria de salvar;
> • calculateInterest (que a TopBar lê todo frame e o cash-out usa pra
> PAGAR) enxerga o teto novo — número prometido e número pago são o
> mesmo, que foi a razão de existir do calculateInterest;
> • o guarda-corpo do Config segura, pra que nenhum caminho futuro
> transforme juros em motor infinito.

## L289 (em `gd.hand`, junto a `gi.economySystem.currentGold = 500`)

> cofre farto: o teto é quem limita

## L305 (em `gd.hand`, junto a `gi.economySystem.currentGold = 10`)

> O teto NÃO dá dinheiro sozinho: continua limitado por floor(ouro/5).

## L310 (em `gd.hand`, junto a `local eco = EconomySystem:new()`)

> Guarda-corpo: nem 999 compras estouram o teto do teto.

## L334 (em `gd.hand`, junto a `t:truthy("cofre continua ofertavel depois de 2 compras",`)

> Sem teto de compras: o pedido foi "aumentar sempre".

## L356-358 (em `gd.hand`, junto a `local CardRewardScreen = require("components.CardRewardScreen")`)

> ========================================================================
> 5. ESTORNO: pagou, fechou o picker sem escolher, recebe de volta
> ========================================================================

## L366 (em `gd.hand`, junto a `tela.visible = false`)

> sem layout: o estorno nao pode depender de desenho

## L416 (em `oferta2`, junto a `_G.openCardPicker = function(_mode, onDone)`)

> A prensa (duplicar) muda o deck pra CIMA: a assinatura tem que enxergar.

## L431-432 (em `oferta3`, junto a `_G.openCardPicker = function(_mode, onDone)`)

> A forja não mexe no TAMANHO do deck, só no nível: a assinatura também
> tem que enxergar isso (senão toda forja usada seria estornada).

## L449-451 (em `oferta4`, junto a `local gs = TK.newRunGame("warrior")`)

> ========================================================================
> 6. LEDGER sobrevive ao save/load
> ========================================================================

## L466-468 (em `oferta4`, junto a `rmLoad.currentRun.maxJokerSlots = nil`)

> Antes do primeiro startGame não existe espelho em currentRun.maxJokerSlots:
> o teto ainda tem que contar as bancadas compradas, senão o jogador
> reabre o jogo com coringas rebaixados pra bancada.

## L475-479 (em `oferta4`, junto a `local Game = require("src.core.Game")`)

> O CAMINHO INTEIRO do Continuar: carregar a run e remontar o jogo tem
> que devolver o teto de juros comprado. O espelho vive no EconomySystem,
> que `startGame` reseta — é exatamente aqui que um teto comprado
> sumiria sem ninguém perceber (o jogador só veria "meus juros
> diminuíram" umas batalhas depois).

## L499-501 (em `oferta4`, junto a `local tela2 = CardRewardScreen:new(game.shopSystem)`)

> ========================================================================
> 7. GEOMETRIA: a vitrine de 2 relíquias cabe em qualquer janela
> ========================================================================

## L526-533 (em `love.graphics.getHeight`, junto a `local UpgradeTile = require("src.ui.UpgradeTile")`)

> ========================================================================
> 7b. ARTE: quem tem PNG usa o PNG; quem não tem, DIZ que não tem
> ========================================================================
> O grimório de compra extra reaproveita `card_draw_upgrade` — o id (e o
> PNG do livro) que existia desde sempre em assets/sprites/vouchers/ e
> ficou órfão quando o P3.2 tirou da vitrine o upgrade que só soltava
> toast. Reusar o id devolve arte E animação de graça; a trava garante
> que um rename futuro não volte a deixá-lo sem sprite em silêncio.

## L538-540 (em `love.graphics.getHeight`, junto a `local semArte = {}`)

> Débito de arte declarado: os demais serviços caem no selo ornamental do
> UpgradeTile (que nunca deixa buraco). Não é falha — é lista de pendência
> impressa no log, pra não virar "ninguém percebeu".

## L550-552 (em `semArte`, junto a `local I18n = require("src.i18n.I18n")`)

> ========================================================================
> 8. i18n: cada serviço tem texto nos 5 locales
> ========================================================================

