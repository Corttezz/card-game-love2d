---
name: code_notes/src/systems/ScribeDice.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/ScribeDice.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/ScribeDice.lua`

Origem: `src/systems/ScribeDice.lua` em `7dbdb60d` (10 de 12 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-31 (junto a `local Config = require("src.core.Config")`)

> src/systems/ScribeDice.lua
> DADOS DO ESCRIBA (Out/2026): a aposta opcional da loja. LÓGICA PURA —
> a tela é components/ScribeDiceScreen.lua, os números são
> Config.Economy.DICE.
>
> O QUE É
> Dois dados de osso. O jogador escolhe a APOSTA (Baixo 2-6 / Sete / Alto
> 8-12) e o VALOR (três fichas que crescem por ato), paga e lança. Uma
> jogada por visita à loja.
>
> POR QUE ESTE DESENHO (e não outro)
> • Probabilidade LEGÍVEL: a soma de 2d6 é a distribuição que todo jogador
> de tabuleiro já conhece, e cada aposta mostra a chance em % escrita
> na ficha. Nada de odds escondidas.
> • EV ~justo (Baixo/Alto 15/36 × 2,5 = 1,04; Sete 6/36 × 6 = 1,00): a
> aposta não é imposto disfarçado nem mina de ouro. O que ela VENDE é
> VARIÂNCIA — e variância tem valor real quando falta pouco pra uma
> compra ("tenho $22, a bancada custa $30"). É uma decisão, não um
> botão de ganhar dinheiro.
> • NÃO É FARMÁVEL: uma jogada por loja (a loja é nó do mapa, então o teto
> é o número de lojas da corrida) e a ficha maior é limitada por ato.
> • NÃO É SAVE-SCUMÁVEL: os dados saem do stream "shop" do Rng da run e
> o resultado é gravado no save NO MESMO FRAME do lançamento, antes de
> a animação revelar qualquer coisa. Fechar o jogo no meio da rolagem e
> voltar mostra a mesa já usada, com o mesmo resultado.
>
> ESTADO (viaja no save): currentRun.scribeDice = {
> key   = chave do nó da loja (dois nós nunca colidem),
> used  = true depois do lançamento,
> bet, stake, dice = {a, b}, sum, won, payout }
> Estado de OUTRO nó é resíduo e é descartado ao consultar.

## L46 (em `cfg`, junto a `ScribeDice.BET_IDS = { "low", "seven", "high" }`)

> Ordem = ordem da tela (esquerda → direita).

## L49-50 (em `ScribeDice.BET_IDS`, junto a `local RANGES = {`)

> Faixas de soma de cada aposta. A chance é CONTADA (36 combinações), não
> escrita à mão: um número na ficha que não bate com a regra é mentira de UI.

## L84-85 (em `ScribeDice.payoutMult`, junto a `function ScribeDice.expectedValue(betId)`)

> Valor esperado por $1 apostado (1,0 = justo). Exposto pro teste travar o
> desenho: se alguém mexer no pagamento e a aposta virar mina, fica vermelho.

## L90-91 (em `ScribeDice.expectedValue`, junto a `function ScribeDice.payout(betId, stake)`)

> Quanto volta pro bolso numa vitória com `stake` (inteiro, arredonda pra
> baixo — a casa nunca paga centavo).

## L96-97 (em `ScribeDice.payout`, junto a `function ScribeDice.stakes(act)`)

> As três fichas do ato: base × (1 + POR_ATO × (ato-1)), arredondadas pra
> PAR (×2,5 de um par é sempre inteiro — a ficha nunca paga $12,50).

## L111-112 (em `out`, junto a `function ScribeDice.nodeKey(run)`)

> Chave do nó: mesma ideia da vitrine no save (CardRewardScreen) —
> ato + andar + quantos nós já foram escolhidos.

## L118-119 (em `ScribeDice.nodeKey`, junto a `function ScribeDice.state(run)`)

> Estado do nó ATUAL (nil se não houve jogada aqui). Resíduo de outro nó é
> apagado — senão a mesa da loja anterior apareceria "usada" na próxima.

## L135 (em `ScribeDice.isUsed`, junto a `function ScribeDice.canRoll(run, economy, betId, stake)`)

> Pode lançar? Devolve (ok, motivo). Motivos viram chave i18n na tela.

## L150-151 (em `ScribeDice.canRoll`, junto a `function ScribeDice.roll(run, economy, betId, stake)`)

> O LANÇAMENTO. Cobra, sorteia (stream "shop"), paga, marca o nó como usado
> e devolve o estado. Quem chama grava o checkpoint NA HORA (a tela faz).

