-- src/systems/CombatBeats.lua
-- O METRÔNOMO DO COMBATE.
--
-- Pedido do dono (Set/2026): "muitas coisas só saem acontecendo e fica difícil
-- de entender e acompanhar". O problema nunca foi falta de efeito visual — era
-- falta de TEMPO e de ORDEM: dano, debuff no inimigo, proc de joker, pulso de
-- orbe e compra de carta caíam todos no MESMO instante.
--
-- A unidade aqui é o BEAT: um acontecimento que ocupa um instante só dele e
-- SEGURA o próximo. Um beat = um evento BLOQUEANTE numa fila dedicada do
-- _G.EventManager ("beats"). Como a fila é só nossa e todo evento dela é
-- blocking, a ordem de push é a ordem de execução, sem state machine ad-hoc,
-- sem love.timer e sem contador manual.
--
--   CombatBeats.push("enemy.buff", function() ... end, "BUFF")
--   CombatBeats.push("enemy.hit",  function() ... end, "HIT_SETTLE")
--
-- REGRA DE ENCADEAMENTO (medida, não suposta — ver tools/test_beats.lua):
-- push SEMPRE joga no FIM da fila, inclusive quando chamado de dentro de um
-- beat em execução. Logo, uma sequência cujos passos só se conhecem em tempo
-- de execução (a resolução de uma carta: quantos coringas ticam, quantos
-- efeitos ela dispara) TEM que ser escrita como CADEIA — o beat corrente
-- empurra os passos dele e, por último, o beat que inicia o próximo elo — e
-- nunca pré-agendada em bloco. Pré-agendar carta 1 e carta 2 juntas faria os
-- passos dinâmicos da carta 1 caírem DEPOIS da carta 2.
--
-- SEM EventManager (headless/testes diretos) o push executa NA HORA: o
-- comportamento antigo, síncrono, continua valendo pra quem chama a API do
-- Game direto.
--
-- Ver memory/eventmanager_queues.md (a fila "base" pertence ao fluxo de
-- animação; "beats" é a espinha CAUSAL do combate).

local CombatBeats = {}

CombatBeats.QUEUE = "beats"

-- ============================================================================
-- TABELA DE TEMPOS — a ÚNICA. Afinar ritmo = mexer aqui, não caçar número solto.
-- Cada valor em segundos, com o motivo de existir.
-- ============================================================================
CombatBeats.HOLD = {
    -- Passo administrativo que precisa EXISTIR na ordem mas não pede ar
    -- (expirar armadura do inimigo, zerar flag de turno).
    MICRO        = 0.10,

    -- Carta no centro: tempo de LER a reação física dela. 0.35 vem do
    -- impactHold v3.1 (medido: abaixo disso o shake de tela mascara o hop).
    CARD_IMPACT  = 0.35,

    -- Tick de joker em cadeia (Balatro). 0.16 é o PROC_TICK do feel v1 —
    -- rápido o bastante pra virar "rajada", lento pra contar os jokers.
    JOKER_PROC   = 0.16,

    -- Efeito secundário da carta (aplicar veneno, curar, ganhar Força):
    -- o número aparece e ASSENTA antes do próximo acontecer.
    SIDE_EFFECT  = 0.28,

    -- Respiro entre a carta que terminou e a próxima começar (resolveGap v3).
    CARD_GAP     = 0.30,

    -- Orbe: canalizar, pulsar e evocar são LIDOS UM A UM (pedido explícito do
    -- dono). Mais ar que um efeito comum porque o jogador precisa associar o
    -- número ao orbe certo na fileira.
    ORB          = 0.40,

    -- Buff/debuff mudando o ESTADO de alguém — o caso que o dono citou por
    -- nome. É o beat mais longo da carta: mudança de estado vale pausa.
    STATUS       = 0.55,

    -- Telegrafia: o intent pisca e o nome do golpe sobe ANTES do inimigo agir.
    TELEGRAPH    = 0.45,

    -- Assentamento depois do inimigo defender/se buffar.
    ENEMY_ACT    = 0.35,

    -- Depois do golpe aterrissar: número, shake e barra de vida descendo.
    HIT_SETTLE   = 0.40,

    -- Espinhos: causa (o golpe) e efeito (o reflexo) precisam ser 2 momentos.
    REFLECT      = 0.45,

    -- Veneno ticando no fim do turno do inimigo.
    DOT          = 0.45,

    -- Duração de status caindo / buffs expirando.
    DECAY        = 0.25,

    -- Passagem de turno: upkeep → compra → gatilhos de início de turno.
    HANDOFF      = 0.35,
}

-- Multiplicador global de ritmo (1.0 = tabela acima). Ponto único pra afinar
-- o jogo inteiro mais rápido/lento sem tocar nos valores relativos.
CombatBeats.speed = 1.0

-- NOTA reducedMotion: NÃO entra aqui de propósito. A flag tira MOVIMENTO
-- (amplitude de hop/juice/bob, tratado em Moveable/Card), nunca INFORMAÇÃO
-- nem ORDEM — os beats continuam iguais, os passos continuam em sequência.

-- Resolve um hold: número cru, nome da tabela, ou nil (= INSTANT).
function CombatBeats.hold(h)
    if h == nil then return 0 end
    if type(h) == "number" then return h * CombatBeats.speed end
    local v = CombatBeats.HOLD[h]
    if not v then
        -- Fallback silencioso é proibido (CLAUDE.md §9): hold desconhecido AVISA.
        print("[CombatBeats] hold desconhecido: '" .. tostring(h) .. "' (usando MICRO)")
        v = CombatBeats.HOLD.MICRO
    end
    return v * CombatBeats.speed
end

-- ============================================================================
-- TRACE — a ordem executada, pra teste e pra debug.
-- ============================================================================
CombatBeats.tracing = false
CombatBeats.log = {}

local function record(label)
    if CombatBeats.tracing then
        CombatBeats.log[#CombatBeats.log + 1] = label
    end
end

function CombatBeats.startTrace()
    CombatBeats.tracing = true
    CombatBeats.log = {}
end

function CombatBeats.stopTrace()
    CombatBeats.tracing = false
end

-- Índice (1-based) do primeiro beat com esse label no trace, ou nil.
function CombatBeats.indexOf(label, from)
    for i = (from or 1), #CombatBeats.log do
        if CombatBeats.log[i] == label then return i end
    end
    return nil
end

-- Registra um acontecimento no trace SEM criar um beat. Para o evento
-- CONDICIONAL que reaproveita o instante do beat corrente (ver extendCurrent):
-- ele aconteceu de verdade e precisa aparecer na ordem — só não pediu uma
-- entrada própria na fila.
function CombatBeats.mark(label)
    record(label)
end

function CombatBeats.traceString()
    return table.concat(CombatBeats.log, " > ")
end



-- ============================================================================
-- API
-- ============================================================================

local function em()
    local EM, Ev = _G.EventManager, _G.Event
    if EM and Ev then return EM, Ev end
    return nil
end

-- Empurra UM beat. `hold` = segundos que a fila fica travada DEPOIS de fn rodar
-- (nome da tabela HOLD ou número). Sem EventManager roda na hora.
function CombatBeats.push(label, fn, hold)
    local EM, Ev = em()
    if not EM then
        record(label)
        if fn then fn() end
        return nil
    end
    -- trigger="before": roda fn no primeiro handle e SEGURA a fila por `delay`.
    -- É exatamente a semântica de beat (o engine já tinha; ver engine/Event.lua).
    local ev
    ev = Ev:new({
        trigger = "before",
        delay = CombatBeats.hold(hold),
        func = function()
            record(label)
            CombatBeats._current = ev
            if fn then fn() end
            CombatBeats._current = nil
            return true
        end,
    })
    return EM.add(ev, CombatBeats.QUEUE)
end

-- Estende o beat QUE ESTÁ RODANDO AGORA. Existe pro passo CONDICIONAL: um beat
-- de checagem barata (hold MICRO) que, quando o evento raro de fato acontece,
-- reivindica o tempo do evento ("se o inimigo enfureceu AGORA, segure").
-- Sem isso a alternativa seria dar ar morto ao caso comum (o evento não
-- acontece na maioria dos turnos) ou pular o instante no caso raro.
-- No-op fora de um beat.
function CombatBeats.extendCurrent(hold)
    local ev = CombatBeats._current
    if not ev then return false end
    ev.delay = math.max(ev.delay or 0, CombatBeats.hold(hold))
    return true
end

-- Beat que ESPERA uma condição (ex: o golpe do inimigo aterrissar no apex da
-- investida, que é animação e não tem hora fixa). startFn roda uma vez; a fila
-- só destrava quando isDone() virar true — ou no timeout (rede de segurança
-- contra travar o turno se a animação nunca terminar).
function CombatBeats.pushUntil(label, startFn, isDone, timeout, hold)
    local EM, Ev = em()
    timeout = timeout or 2.0
    if not EM then
        record(label)
        if startFn then startFn() end
        return nil
    end
    local started = false
    local ev
    ev = Ev:new({
        trigger = "condition",
        func = function()
            if not started then
                started = true
                record(label)
                if startFn then startFn() end
            end
            if isDone and isDone() then return true end
            if ev.timer >= timeout then
                print("[CombatBeats] timeout esperando '" .. tostring(label) .. "'")
                return true
            end
            return false
        end,
    })
    EM.add(ev, CombatBeats.QUEUE)
    if hold then CombatBeats.push(label .. ".settle", nil, hold) end
    return ev
end

-- Empurra uma lista de passos coletados num sink: { {label=, fn=, hold=}, ... }
function CombatBeats.pushAll(steps)
    for _, s in ipairs(steps or {}) do
        CombatBeats.push(s.label, s.fn, s.hold)
    end
end

-- Helper dos coletores: se houver sink, ENFILEIRA o passo; senão executa já.
-- É assim que EffectSystem/Game viram "sequenciáveis" sem duplicar código —
-- quem chama a API direto (testes, autoplay) continua vendo efeito síncrono.
function CombatBeats.step(sink, label, fn, hold)
    if sink then
        sink[#sink + 1] = { label = label, fn = fn, hold = hold }
    else
        fn()
    end
end

function CombatBeats.pending()
    local EM = _G.EventManager
    if not EM then return 0 end
    return EM.pendingCount(CombatBeats.QUEUE)
end

function CombatBeats.isBusy()
    return CombatBeats.pending() > 0
end

function CombatBeats.clear()
    local EM = _G.EventManager
    if EM then EM.clear(CombatBeats.QUEUE) end
end

return CombatBeats
