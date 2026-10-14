---
name: code_notes/src/systems/CombatBeats.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/CombatBeats.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/CombatBeats.lua`

Origem: `src/systems/CombatBeats.lua` em `7dbdb60d` (20 de 30 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-32 (junto a `local CombatBeats = {}`)

> src/systems/CombatBeats.lua
> O METRÔNOMO DO COMBATE.
>
> Pedido do dono (Set/2026): "muitas coisas só saem acontecendo e fica difícil
> de entender e acompanhar". O problema nunca foi falta de efeito visual — era
> falta de TEMPO e de ORDEM: dano, debuff no inimigo, proc de joker, pulso de
> orbe e compra de carta caíam todos no MESMO instante.
>
> A unidade aqui é o BEAT: um acontecimento que ocupa um instante só dele e
> SEGURA o próximo. Um beat = um evento BLOQUEANTE numa fila dedicada do
> _G.EventManager ("beats"). Como a fila é só nossa e todo evento dela é
> blocking, a ordem de push é a ordem de execução, sem state machine ad-hoc,
> sem love.timer e sem contador manual.
>
> CombatBeats.push("enemy.buff", function() ... end, "BUFF")
> CombatBeats.push("enemy.hit",  function() ... end, "HIT_SETTLE")
>
> REGRA DE ENCADEAMENTO (medida, não suposta — ver tools/test_beats.lua):
> push SEMPRE joga no FIM da fila, inclusive quando chamado de dentro de um
> beat em execução. Logo, uma sequência cujos passos só se conhecem em tempo
> de execução (a resolução de uma carta: quantos coringas ticam, quantos
> efeitos ela dispara) TEM que ser escrita como CADEIA — o beat corrente
> empurra os passos dele e, por último, o beat que inicia o próximo elo — e
> nunca pré-agendada em bloco. Pré-agendar carta 1 e carta 2 juntas faria os
> passos dinâmicos da carta 1 caírem DEPOIS da carta 2.
>
> SEM EventManager (headless/testes diretos) o push executa NA HORA: o
> comportamento antigo, síncrono, continua valendo pra quem chama a API do
> Game direto.
>
> Ver memory/eventmanager_queues.md (a fila "base" pertence ao fluxo de
> animação; "beats" é a espinha CAUSAL do combate).

## L38-41 (em `CombatBeats`, junto a `CombatBeats.HOLD = {`)

> ============================================================================
> TABELA DE TEMPOS — a ÚNICA. Afinar ritmo = mexer aqui, não caçar número solto.
> Cada valor em segundos, com o motivo de existir.
> ============================================================================

## L43-44 (em `CombatBeats.HOLD`, junto a `MICRO        = 0.10,`)

> Passo administrativo que precisa EXISTIR na ordem mas não pede ar
> (expirar armadura do inimigo, zerar flag de turno).

## L47-48 (em `CombatBeats.HOLD`, junto a `CARD_IMPACT  = 0.35,`)

> Carta no centro: tempo de LER a reação física dela. 0.35 vem do
> impactHold v3.1 (medido: abaixo disso o shake de tela mascara o hop).

## L51-52 (em `CombatBeats.HOLD`, junto a `JOKER_PROC   = 0.16,`)

> Tick de joker em cadeia (Balatro). 0.16 é o PROC_TICK do feel v1 —
> rápido o bastante pra virar "rajada", lento pra contar os jokers.

## L55-56 (em `CombatBeats.HOLD`, junto a `SIDE_EFFECT  = 0.28,`)

> Efeito secundário da carta (aplicar veneno, curar, ganhar Força):
> o número aparece e ASSENTA antes do próximo acontecer.

## L62-64 (em `CombatBeats.HOLD`, junto a `ORB          = 0.40,`)

> Orbe: canalizar, pulsar e evocar são LIDOS UM A UM (pedido explícito do
> dono). Mais ar que um efeito comum porque o jogador precisa associar o
> número ao orbe certo na fileira.

## L67-68 (em `CombatBeats.HOLD`, junto a `STATUS       = 0.55,`)

> Buff/debuff mudando o ESTADO de alguém — o caso que o dono citou por
> nome. É o beat mais longo da carta: mudança de estado vale pausa.

## L80 (em `CombatBeats.HOLD`, junto a `REFLECT      = 0.45,`)

> Espinhos: causa (o golpe) e efeito (o reflexo) precisam ser 2 momentos.

## L93-94 (em `CombatBeats.HOLD`, junto a `CombatBeats.speed = 1.0`)

> Multiplicador global de ritmo (1.0 = tabela acima). Ponto único pra afinar
> o jogo inteiro mais rápido/lento sem tocar nos valores relativos.

## L97-99 (em `CombatBeats.HOLD`, junto a `local warnedHold = {}`)

> NOTA reducedMotion: NÃO entra aqui de propósito. A flag tira MOVIMENTO
> (amplitude de hop/juice/bob, tratado em Moveable/Card), nunca INFORMAÇÃO
> nem ORDEM — os beats continuam iguais, os passos continuam em sequência.

## L108-109 (em `CombatBeats.hold`, junto a `if not warnedHold[h] then`)

> Fallback silencioso é proibido (CLAUDE.md §9): hold desconhecido AVISA
> (uma vez por nome — o mesmo beat roda a cada turno).

## L119-121 (em `CombatBeats.hold`, junto a `CombatBeats.tracing = false`)

> ============================================================================
> TRACE — a ordem executada, pra teste e pra debug.
> ============================================================================

## L148-151 (em `CombatBeats.indexOf`, junto a `function CombatBeats.mark(label)`)

> Registra um acontecimento no trace SEM criar um beat. Para o evento
> CONDICIONAL que reaproveita o instante do beat corrente (ver extendCurrent):
> ele aconteceu de verdade e precisa aparecer na ordem — só não pediu uma
> entrada própria na fila.

## L162-164 (em `CombatBeats.traceString`, junto a `local function em()`)

> ============================================================================
> API
> ============================================================================

## L172-173 (em `em`, junto a `function CombatBeats.push(label, fn, hold)`)

> Empurra UM beat. `hold` = segundos que a fila fica travada DEPOIS de fn rodar
> (nome da tabela HOLD ou número). Sem EventManager roda na hora.

## L181-182 (em `CombatBeats.push`, junto a `local ev`)

> trigger="before": roda fn no primeiro handle e SEGURA a fila por `delay`.
> É exatamente a semântica de beat (o engine já tinha; ver engine/Event.lua).

## L198-203 (em `func`, junto a `function CombatBeats.extendCurrent(hold)`)

> Estende o beat QUE ESTÁ RODANDO AGORA. Existe pro passo CONDICIONAL: um beat
> de checagem barata (hold MICRO) que, quando o evento raro de fato acontece,
> reivindica o tempo do evento ("se o inimigo enfureceu AGORA, segure").
> Sem isso a alternativa seria dar ar morto ao caso comum (o evento não
> acontece na maioria dos turnos) ou pular o instante no caso raro.
> No-op fora de um beat.

## L211-214 (em `CombatBeats.extendCurrent`, junto a `function CombatBeats.pushUntil(label, startFn, isDone, timeout, hold)`)

> Beat que ESPERA uma condição (ex: o golpe do inimigo aterrissar no apex da
> investida, que é animação e não tem hora fixa). startFn roda uma vez; a fila
> só destrava quando isDone() virar true — ou no timeout (rede de segurança
> contra travar o turno se a animação nunca terminar).

## L253-255 (em `CombatBeats.pushAll`, junto a `function CombatBeats.step(sink, label, fn, hold)`)

> Helper dos coletores: se houver sink, ENFILEIRA o passo; senão executa já.
> É assim que EffectSystem/Game viram "sequenciáveis" sem duplicar código —
> quem chama a API direto (testes, autoplay) continua vendo efeito síncrono.

