---
name: code_notes/src/ui/HandDeal.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/HandDeal.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/HandDeal.lua`

Origem: `src/ui/HandDeal.lua` em `7dbdb60d` (4 de 12 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-28 (junto a `local HandDeal = {}`)

> src/ui/HandDeal.lua
> CORTINA DA MÃO + DISTRIBUIÇÃO das cartas (Out/2026, bug do dono: "a mão,
> os botões e o HUD aparecem no meio da porta do castelo e da entrada do
> chefe").
>
> Regra: enquanto a cena está em CUTSCENE (viagem na estrada, cerimônia da
> porta, salão à espera do chefe, entrada/morte do chefe, quicada de chegada)
> a mão, os botões, o quadro de coringas e a prévia NÃO existem na tela. No
> salão o HUD (painel do herói, mana, HUD do inimigo) também espera. Quando
> a cortina sobe, as cartas são DISTRIBUÍDAS uma a uma a partir da pilha do
> deck (materialize + som, escalonadas), e SÓ DEPOIS da última carta entram
> botões e HUD. É a ordem de um jogo de mesa: o oponente senta, as cartas
> são dadas, aí você joga.
>
> Quem decide se a cortina está abaixada é o GameplayScene (ele conhece a
> viagem, a porta e a cinemática); este módulo só guarda o estado, toca a
> distribuição e responde às perguntas do draw/input:
> setCurtain(down, game, { hud = bool })  todo frame, antes do update
> update(dt, game)                        toca a distribuição
> hidesHand()   mão inteira some (cortina)
> holds(card)   a carta ainda não foi dada (fica na pilha, invisível)
> hidesUI()     botões/coringas/prévia esperam (cortina OU distribuindo)
> hidesHud()    HUD espera (só no modo hud — salão)
> isBusy()      cortina ou distribuição em curso (input da mão fechado,
> narrador do tutorial espera)
>
> Linha do tempo própria (dt acumulado): sem EventManager a carta aparece
> de uma vez no instante dela (testes/autoplay); com ele, materializa.

## L53-57 (em `held`, junto a `local function beginDeal(game)`)

> Começa a distribuição: toda carta da mão volta pra pilha (invisível) e
> sai de lá uma por vez no update. Sem luta (inimigo morto atrás da
> cortina — a morte do chefe — espólios a caminho) a MESA FICA FECHADA:
> não se dá carta pra um cadáver, e a mão/botões não voltam por cima do
> corpo no salão; a próxima cortina (andar novo) reabre.

## L88-89 (em `deal`, junto a `local function release(c, n)`)

> Dá a carta `c`: sai da pilha, materializa (ou aparece, sem EventManager),
> som de compra com pitch subindo a cada carta.

## L147-148 (em `HandDeal.isClosed`, junto a `function HandDeal.visibleCount(game)`)

> Quantas cartas da mão estão VISÍVEIS (nem cortina, nem na pilha). Pros
> testes e pras ferramentas de captura.

