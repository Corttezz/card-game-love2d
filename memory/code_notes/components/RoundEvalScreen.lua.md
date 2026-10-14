---
name: code_notes/components/RoundEvalScreen.lua
description: Comentários com decisão/regra/histórico colhidos de components/RoundEvalScreen.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `components/RoundEvalScreen.lua`

Origem: `components/RoundEvalScreen.lua` em `7dbdb60d` (27 de 77 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-28 (junto a `local RoundEvalScreen = {}`)

> components/RoundEvalScreen.lua
> Tela de "Cash Out" pós-batalha estilo Balatro.
> Mapeamento direto de:
> /home/cortez/projects/balatro-source/functions/UI_definitions.lua:1612-1627 (UIBox)
> /home/cortez/projects/balatro-source/functions/common_events.lua:927-1095 (add_round_eval_row + animação coins)
> /home/cortez/projects/balatro-source/functions/state_events.lua:1135-1208 (G.FUNCS.evaluate_round)
>
> Layout (overlay sobre gameplay congelado):
> ┌────────────────── PAINEL CENTRAL ──────────────────┐
> │  AVALIAÇÃO DA RODADA  (DynaText pop-in cascade)     │
> ├──────────────────────────────────────────────────────┤
> │  Vitória              $$$$$       (5 coins)          │
> │  HP cheio             $$$         (3 coins)          │
> │  Juros                $$          (variable)         │
> ├──── separator ──────────────────────────────────────┤
> │             TOTAL: $N                                 │
> │       ┌────────────────────────────┐                 │
> │       │  RESGATAR: $N (orange)     │                 │
> │       └────────────────────────────┘                 │
> └──────────────────────────────────────────────────────┘
>
> Timeline:
> T=0     show() chamado. Painel slide-in do bottom (slideOffsetY: H → 0).
> T=0.5   Painel settled. jiggle 0.8 + sfx cardSelect.
> T=0.7+  Cada source aparece (label + coins anim) com stagger 0.5s.
> Cada coin individual: 0.10s delay, sfx coinPickup pitch random.
> T=last  Botão "RESGATAR: $N" pop-in laranja com flash.
> <click> earnGold + slide-out + onCashOut callback.

## L43-51 (em `RoundEvalScreen`, junto a `local FXQ = "round_eval_fx"`)

> Fila PRÓPRIA pros beats desta tela.
>
> Ela agendava TUDO na `base` — e esta tela abre no instante seguinte à
> vitória, que e justamente quando a base esta mais cheia com o rabo do
> combate (morte do inimigo, shakes, transicoes). Pela semantica do
> EventManager (memory/eventmanager_queues.md) um `parallel` na base e
> BLOCKABLE: ele nao roda enquanto houver evento bloqueante na frente. Ou
> seja, o cash out inteiro — inclusive o callback que leva pra loja — podia
> ficar preso atras do combate. Mesmo defeito que a saida da loja teve.

## L54 (em `RoundEvalScreen`, junto a `local PHASES = {`)

> Constantes da timeline (segundos). Padrão Balatro common_events.lua:1141+.

## L60 (em `PHASES`, junto a `BIG_THRESHOLD = 60,`)

> > 60 dollars: text único, senão coins individuais

## L85-86 (em `instance._rowCoins`, junto a `function RoundEvalScreen:show(game, sources, onCashOut)`)

> show(game, sources, onCashOut)
> sources = { { label="Vitória", dollars=5, color={r,g,b,a} }, ... }

## L150-151 (em `RoundEvalScreen:_buildDynaTexts`, junto a `text = I18n.t("round_eval.title", nil, "AVALIACAO DA RODADA"),`)

> i18n: o botao "Resgatar" ja era traduzido e o titulo nao, entao a
> tela saia bilingue em qualquer locale que nao fosse PT.

## L155-161 (em `RoundEvalScreen:_buildDynaTexts`, junto a `bump_phase = 0.42,`)

> MESMA correção do título do pacote (PackOpenScreen): o default
> bump_phase=200 defasa letras vizinhas em ~-1,06 rad e ESPALHA o
> texto — num frame parado lia "RUND E NAUSW E RTUNG", com duas
> letras no ar e o resto na linha. Fase pequena faz o salto VIAJAR
> pela palavra (ondulação), e a amplitude cai porque agora várias
> letras sobem ao mesmo tempo. Palavra longa alemã é o pior caso e
> foi onde o defeito ficou evidente.

## L212-216 (em `colours`, junto a `bump = false,`)

> SEM bump: este é o número que o jogador vai resgatar — INFORMAÇÃO,
> e informação quer linha de base estável. Com o bump ligado saía
> "GESA M T: $1 ³", com o algarismo pulando acima da linha bem na
> hora de ler o valor. Mesma decisão do subtítulo "Escolha N" do
> pacote. O pop_in continua: a ENTRADA pode ser animada, a leitura não.

## L250-251 (em `RoundEvalScreen:_scheduleTimeline`, junto a `local pitch = 0.95 + (i - 1) * 0.06`)

> F11.5: row entry usa coinTotalThud (chunky thump), pitch crescente
> por source pra dar sensação de cascade.

## L265-266 (em `RoundEvalScreen:_scheduleTimeline`, junto a `Sfx.play("coinClink", {`)

> F11.5: cada coin individual usa coinClink (warm wooden thock).
> Pitch random pra cada uma soar levemente diferente.

## L303-304 (em `RoundEvalScreen:_buildCashOutButton`, junto a `local btnW = 240`)

> Reduzido de 360×64 → 240×42 (F11.2). Estava grande demais e visualmente
> desproporcional ao painel.

## L321-323 (em `RoundEvalScreen:_onCashOutClick`, junto a `Sfx.play("coinTotalThud", { pitch = 1.2, volume = 0.85 })`)

> F12.2: cashOutChime já toca quando o botão Resgatar entra (signal "ready").
> Tocar de novo no click duplicava o som. Click usa coinTotalThud + flash
> + jiggle pra feedback distinto.

## L330-333 (em `RoundEvalScreen:_onCashOutClick`, junto a `local landAt = self:_launchCoins()`)

> MOEDAS VOANDO (pedido do dono: "animação da moeda sendo resgatada").
> Antes o ouro simplesmente aparecia no contador: o número do painel
> sumia e o da barra mudava, sem nada ligando um ao outro. Agora o valor
> VIAJA — sai de baixo do total e entra no cofre da TopBar.

## L336-339 (em `RoundEvalScreen:_onCashOutClick`, junto a `EventManager.parallel(landAt, function()`)

> O ouro entra quando a ÚLTIMA moeda pousa, não no clique. É o que faz a
> TopBar reagir (som + "+N" subindo) no instante em que o dinheiro
> chega, em vez de meio segundo antes das moedas — causalidade visível,
> mesma regra do dissolve que espera os procs do coringa.

## L356-358 (em `RoundEvalScreen:_onCashOutClick`, junto a `local COIN_FLY_DUR   = 0.42`)

> ============================================================================
> VOO DAS MOEDAS
> ============================================================================

## L364-365 (em `RoundEvalScreen:_onCashOutClick`, junto a `local _targetWarned = false`)

> Alvo: o bloco de ouro da TopBar. Pergunta a ELA em vez de repetir o número,
> senão mudar o layout da barra faz as moedas voarem pro vazio caladas.

## L375-378 (em `goldCounterPos`, junto a `if _G.audioSystem and not _targetWarned then`)

> Sem TopBar: acontece de verdade em tool/headless, e aí o centro do topo
> serve. Mas se sumir NO JOGO (alguém tirou o _G.topBar num refactor), as
> moedas passariam a voar pro lugar errado sem ninguém notar — então o
> caso anômalo avisa, e o esperado fica quieto.

## L392-393 (em `self._coins`, junto a `return 0.02`)

> reducedMotion tira o MOVIMENTO, não a informação nem o som: o ouro
> entra na hora e a TopBar anuncia igual.

## L412-414 (em `coin`, junto a `EventManager.parallelEase(coin, "y", ty, COIN_FLY_DUR, "ease_in", FXQ)`)

> Y com ease_in: a moeda sobe devagar e ACELERA no fim, o que dá
> o arco de sucção. Se as duas coordenadas usassem a mesma curva
> o voo sairia em linha reta, que lê como teleporte lento.

## L421-422 (em `coin`, junto a `Sfx.play("coinClink", {`)

> Clink no POUSO, pitch subindo pela fileira — o mesmo vocabulário
> que as moedas das linhas já usam na contagem acima.

## L433-434 (em `coin`, junto a `function RoundEvalScreen:_drawCoins()`)

> Desenhadas em SCREEN-SPACE, fora do slide do painel: elas saem DELE mas
> pertencem à tela, e têm que continuar visíveis depois que ele desliza.

## L446-447 (em `RoundEvalScreen:_drawCoins`, junto a `love.graphics.setColor(0.95, 0.80, 0.28, c.a)`)

> Sem o PNG: disco dourado. Uma moeda que some porque o ícone
> não resolveu seria o fallback silencioso de novo.

## L486 (em `RoundEvalScreen:draw`, junto a `local panelW = math.floor(sw * 0.55)`)

> Painel principal (Balatro pattern: dark bg, gold border, embossed).

## L540-541 (em `RoundEvalScreen:draw`, junto a `local scoreBlockH = 0`)

> F3: bloco de pontuação da batalha — total grande + recibo do que o
> jogador FEZ pra ganhar cada bônus (feedback: fórmula era críptica).

## L635 (em `RoundEvalScreen:draw`, junto a `if self.cashOutButton and self.cashOutReady then`)

> Botão Resgatar (FORA do slide — sempre na posição absoluta).

## L637 (em `RoundEvalScreen:draw`, junto a `local btn = self.cashOutButton`)

> Glow laranja ao redor do botão (Balatro G.C.ORANGE).

## L645-647 (em `RoundEvalScreen:draw`, junto a `self:_drawCoins()`)

> Moedas por último: elas atravessam a tela inteira, inclusive por cima
> do botão que acabou de ser clicado, e não podem acompanhar o slide do
> painel (o destino é a barra do topo, que está parada).

