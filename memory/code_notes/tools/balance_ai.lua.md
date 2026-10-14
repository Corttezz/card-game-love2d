---
name: code_notes/tools/balance_ai.lua
description: Comentários com decisão/regra/histórico colhidos de tools/balance_ai.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/balance_ai.lua`

Origem: `tools/balance_ai.lua` em `7dbdb60d` (37 de 69 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-22 (junto a `local TagSystem   = require("src.systems.TagSystem")`)

> tools/balance_ai.lua
> CEREBRO v6 do piloto (Out/2026, frente de balanceamento).
>
> O v5 (tools/autoplay.lua) decidia o turno por PASSOS heuristicos em ordem
> fixa (lethal > scaling > cura > emergencia > dano > defesa > orbes > sobra).
> Cada passo era sensato isolado, mas a ORDEM decidia por ele: um turno em que
> valia mais aplicar Fraco do que socar, ou evocar em vez de canalizar, so
> acontecia se a heuristica certa estivesse na frente.
>
> O v6 troca a ordem fixa por BUSCA: enumera TODOS os subconjuntos jogaveis da
> mao dentro da mana, simula cada um com o pipeline do jogo (combos reais,
> coringas com largest-wins, Forca por golpe, Vulneravel amplificando o resto
> da leva, orbes canalizando/estourando/pulsando, espinhos, veneno tickando
> DEPOIS do golpe inimigo, Fraco reduzindo o golpe congelado) e escolhe o de
> maior VALOR.
>
> O VALOR fala uma lingua so: HP. O turno custa o HP que o golpe anunciado
> tira agora, e o que resta da luta custa o HP que o inimigo ainda vai tirar
> ate morrer: (vida restante do inimigo / dano por turno) x (dano liquido que
> ele causa por turno). Dano, Forca, veneno, Vulneravel e orbes reduzem o
> primeiro termo; Bloqueio, Fraco e Destreza reduzem o segundo; matar zera
> tudo. Sem pesos arbitrarios entre "atacar" e "defender" — a conta decide.

## L30-32 (em `AI`, junto a `local function hasEff(card, t)`)

> ============================================================
> helpers
> ============================================================

## L94-96 (em `hasJokerEffect`, junto a `function AI.cardValue(game, card, ctx, stat)`)

> Valor final de UMA carta ataque/defesa (espelho de Game:_resolveCardInCombat
> computeCardValue): efeitos proprios -> stat (por golpe; scaling = dobro) ->
> combos do conjunto -> coringas (largest-wins + flats) -> edition -> seal.

## L118-120 (em `AI.cardValue`, junto a `local pl = game and game.player`)

> Debuffs do INIMIGO no jogador (kit Out/2026): Fraco corta o ataque,
> Frágil corta a defesa — mesma conta (e mesma ordem: por último) do
> Game:_resolveCardInCombat.

## L132-135 (em `AI.cardValue`, junto a `local function playRank(c)`)

> Ordem de jogada dentro da leva: quem PREPARA vem antes de quem COLHE.
> debuff (Vulneravel/Fraco) > buff (Forca/Destreza/Foco/mana) > canalizar >
> resto (defesa, cura, compra) > ataques (maior primeiro: Eco dobra o 1o) >
> evocar.

## L163-165 (em `out`, junto a `local function allBattleCards(game)`)

> ============================================================
> Contexto de BATALHA: estimativas do deck que alimentam o "custo do resto"
> ============================================================

## L215-216 (em `prof`, junto a `maxBlock = (function()`)

> Bloqueio que o deck consegue por turno se PRIORIZAR defesa (limitado
> pelas cartas de defesa que chegam na mao e pela mana).

## L232 (em `AI.newBattle`, junto a `hitTurns = 0, incSum = 0, lostSum = 0,`)

> vazamento medido: HP perdido / golpe anunciado, nos turnos de ataque

## L237-240 (em `AI.newBattle`, junto a `function AI.leakOf(bctx, inc)`)

> Fracao do golpe medio que passa nos turnos futuros: estimada pelo bloqueio
> que o deck consegue (deck de muralha vaza pouco, deck de ataque vaza muito)
> e corrigida pelo que a batalha MEDIU. Uma constante unica (0.65) fazia o
> guerreiro de muralha correr atras de dano no A3+ em vez de segurar o golpe.

## L251 (em `AI.leakOf`, junto a `local function dptOf(bctx)`)

> dano por turno usado no custo do resto: blend do perfil com o medido

## L261-263 (em `dptOf`, junto a `local function avgIncoming(enemy)`)

> dano esperado por turno do inimigo (mistura de intents: 50% attack, 16%
> strong x1.6, 34% defend/buff) — so o FUTURO usa isto; o turno atual usa o
> intent congelado de verdade.

## L265-266 (em `avgIncoming`, junto a `if enemy.expectedDamagePerTurn then`)

> Kit do inimigo (Out/2026): media ponderada dos golpes dele — o kit
> define quanto cada criatura bate (multi-golpe, perfurante, carga).

## L274-276 (em `avgIncoming`, junto a `local function copyOrbs(list)`)

> ============================================================
> SIMULACAO de um conjunto (uma leva + fim do turno + golpe inimigo)
> ============================================================

## L284-294 (em `out`, junto a `local DAMAGE_KINDS = { attack = true, strong = true, multi = true }`)

> NÉVOA DE INTENÇÃO (Out/2026, src/systems/IntentVisibility.lua): o piloto
> DECIDE com o que o jogador VÊ. Devolve o golpe que vem como ele é
> conhecido: { perHit, hits, pierce, armor, known }.
> full       números congelados (Vulnerável congelado entra, como no HUD);
> type_only  o TIPO é conhecido: golpe de dano vira a média do kit
> (expectedDamagePerTurn) em 1 golpe; defender vira o bloqueio
> padrão; buff/cura/debuff/carga = 0 de dano; perfurante é tipo,
> então segue conhecido;
> hidden     média do kit, sem perfurante nem bloqueio.
> MEDIÇÃO (diag/incSum do autoplay) continua lendo o real — só a escolha de
> cartas passa por aqui. Sem kit (testes antigos) cai no contrato legado.

## L393 (em `ctx`, junto a `if game.selectedClass == "warrior" and not game._impetusFiredThisTurn then`)

> Impeto do guerreiro: decide ANTES de resolver (applyClassTurnPassives)

## L399 (em `ctx`, junto a `local toxin = math.max(1, (game.classPassiveTier and game:classPassiveTier() or 1)`)

> Toxinas do ladino (Out/2026): 2+ ataques no turno = +TOXIN_GROWTH na passiva

## L461 (em `ctx`, junto a `for _, ef in ipairs(c.effects or {}) do`)

> efeitos secundarios (ataque/defesa/efeito), na ordem dos dados

## L524-526 (em `ctx`, junto a `local th = AI.knownThreat(e, p)`)

> Intent CONGELADO do kit (Out/2026): golpes x dano por golpe,
> perfurante, bloqueio do proprio inimigo e debuffs no jogador — como
> o JOGADOR o conhece (névoa de intenção: AI.knownThreat).

## L547-548 (em `ctx`, junto a `if p.getDebuffStacks then`)

> Veneno/queimadura NO JOGADOR ticam no upkeep seguinte (ignoram o
> Bloqueio): o que ja esta nele + o que este golpe aplica.

## L568-570 (em `ctx`, junto a `function AI.score(game, set, S, bctx)`)

> ============================================================
> VALOR (em HP) de um resultado simulado
> ============================================================

## L582 (em `AI.score`, junto a `return 1e6 + S.hp - S.exhausts * 3 - #set * 0.01`)

> todos os lethais sao bons; prefere gastar menos recurso de uso unico

## L588-589 (em `AI.score`, junto a `local orbDpt, orbBlk, orbHeal = 0, 0, 0`)

> orbes: pulso por turno (raio/fogo) entra no dpt; o evoke eventual
> e a sombra crescendo descontam da vida

## L609-613 (em `AI.score`, junto a `local T`)

> TEMPO ATE MATAR, turno a turno. O DoT NAO e um desconto instantaneo
> da vida: veneno empilha stacks E duracao (Enemy:addStatusEffect), entao
> 12 stacks x 12 turnos "valem" 144 mas chegam 12 por turno. A 1a versao
> descontava tudo de uma vez, achava a luta ganha (T=0) e o ladino
> PASSAVA o turno com 5 de mana e 5 cartas na mao.

## L636-640 (em `AI.score`, junto a `local LEAK = AI.leakOf(bctx, inc)`)

> dano liquido por turno que o inimigo ainda causa
> Fracao do golpe medio que PASSA nos turnos futuros. Nao sai do perfil
> do deck: bloquear custa a MESMA mana que atacar, e a conta "dpt do
> ataque + bpt da defesa" contava a mana duas vezes (a 1a versao do v6
> achava a luta quase gratis e trocava dano por cura inutil).

## L666 (em `AI.score`, junto a `bonus = bonus + 0.05 * math.max(0, (e.health or 0) - S.eHp)`)

> desempate: entre planos de mesmo valor, o que causa mais dano AGORA

## L672-674 (em `AI.score`, junto a `local function playable(game)`)

> ============================================================
> BUSCA: melhor subconjunto da mao
> ============================================================

## L684-686 (em `out`, junto a `function AI.bestSet(game, bctx, opts)`)

> Enumera subconjuntos com custo <= mana (podando por custo). Limite de mao
> grande: a partir de 12 cartas, so as 12 de maior "valor bruto" entram na
> busca (2^12 = 4096 avaliacoes ja e o teto razoavel por leva).

## L689-690 (em `AI.bestSet`, junto a `if opts and opts.excludeMotor then`)

> orcamento de motor esgotado: carta de PURO ciclo sai da busca (senao
> uma Sosia que se paga vira loop infinito de "comprar e comprar")

## L739-746 (em `rec`, junto a `local LAMBDA = 5.5   -- pontos que 1 de mana rende numa carta media`)

> ============================================================
> DECK BUILDING: quanto uma carta VALE pra ESTE deck
> ============================================================
> Moeda: "pontos" da curva de poder da auditoria (tools/audit_cards.lua,
> ~1 ponto = 1 de dano imediato). Uma carta ocupa MANA e ocupa um ESPACO na
> mao: o que ela rende acima do que a mesma mana renderia "na media" e o
> SUPERAVIT. Entra no deck quem melhora a media do deck (deck enxuto compra
> a carta boa mais vezes — diluir e perder).

## L750-751 (em `rec`, junto a `local COMBO_TYPE_W = { attack = 0.25, defense = 0.2 }`)

> Combos simples (Out/2026): a Saraivada/Muralha pagam densidade de ATAQUE/
> DEFESA na mao, o Par paga COPIAS da mesma carta no deck.

## L808-809 (em `ctx`, junto a `function AI.cardWorth(game, cd, dctx, inDeck)`)

> Superavit da carta pra ESTE deck. `inDeck` = avaliando carta que ja esta
> no deck (nao conta a propria carta como "sinergia consigo mesma").

## L836-837 (em `AI.cardWorth`, junto a `local tw = COMBO_TYPE_W[cd.type]`)

> sinergia dos combos simples: densidade do tipo (Saraivada/Muralha) e
> copias da mesma carta (Par)

## L861-866 (em `AI.cardWorth`, junto a `function AI.wantsCard(game, cd, dctx, marginMul)`)

> Entra no deck? (recompensa/loja). Margem: deck pequeno aceita carta "media";
> deck grande so aceita quem MELHORA a media.
> `marginMul` (pipeline Out/2026): o piloto expert_fast usa a MESMA conta
> com margem maior — medido, a margem 1x deixa o deck em 16-19 cartas onde a
> simulacao (expert) para em 10-13, e e o tamanho do deck que separa as
> taxas de vitoria dos dois.

## L882 (em `AI.wantsCard`, junto a `function AI.worstCard(game, dctx)`)

> Pior carta do deck (alvo da tesoura). Nunca a ultima defesa.

## L903-904 (em `AI.worstCard`, junto a `local function isMotor(c)`)

> Carta de MOTOR: compra/mana que, jogada sozinha primeiro, revela a mao nova
> antes de decidir o resto.

## L910-911 (em `isMotor`, junto a `function AI.planLeva(game, bctx, opts)`)

> Decide a PROXIMA leva do turno. Retorna (picks, motivo) ou ({}, "") pra
> encerrar o turno.

## L918-919 (em `AI.planLeva`, junto a `local motor = {}`)

> motor primeiro: se o melhor plano compra/gera mana, joga SO o motor e
> replaneja com a mao nova (o resto do plano pode mudar).

