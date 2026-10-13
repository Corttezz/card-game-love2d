-- tools/instant_engine.lua
-- RELOGIO INSTANTANEO do simulador (Out/2026, frente de balanceamento).
--
-- O jogo e dirigido por filas de eventos temporais (_G.EventManager): a
-- resolucao de cada carta e o turno do inimigo sao CADEIAS de beats
-- (src/systems/CombatBeats.lua), cada um segurando o proximo por 0,1-0,55 s.
-- O piloto (tools/autoplay.lua) avancava esse relogio em passos de 1/30 s —
-- um turno de ~2,4 s de jogo custava ~70 iteracoes de EventManager.update e,
-- somando as centenas de batalhas que a simulacao de deck rejoga, era um
-- terco do tempo de uma bateria.
--
-- Aqui o relogio anda por SALTOS: cada iteracao avanca DT segundos de uma
-- vez e repete ate nao sobrar nada pendente. A REGRA nao muda — e o mesmo
-- EventManager, os mesmos beats, na mesma ordem causal:
--   * um evento "before"/"after" com hold <= DT completa na mesma passada e o
--     EventManager ja processa o proximo elo da cadeia na MESMA passada
--     (table.remove + indice parado), entao uma cadeia inteira drena de uma
--     vez;
--   * o unico beat que espera algo de fora e a investida do inimigo
--     (CombatBeats.pushUntil: o dano cai no APEX da animacao, em
--     EnemyRenderer.update). Por isso cada iteracao tambem avanca o
--     EnemyRenderer, o Enemy e o CombatSequence — exatamente o que o pump do
--     piloto ja fazia, so que com dt grande.
--
-- DT precisa ficar ABAIXO do timeout do pushUntil (2,5 s): o `timer` do
-- evento soma dt ANTES de testar a condicao, e um salto >= 2,5 s faria o beat
-- "enemy.attack" expirar por timeout na primeira passada, ANTES do apex — o
-- golpe cairia fora de ordem (depois dos espinhos, do veneno, ate do upkeep
-- que zera a armadura). Com DT = 1,0 s o apex (0,34 s) chega na primeira
-- EnemyRenderer.update e a condicao fecha na iteracao seguinte.
--
-- Nada que roda ENTRE os beats no jogo real mexe em regra: EnemyRenderer so
-- dispara o callback do apex, Enemy:update so decrementa cooldown/ticker de
-- exibicao, CombatSequence:update so anima cartas voando. A prova nao e este
-- comentario: e tools/test_instant_parity.lua, que joga as mesmas seeds pelo
-- relogio de 1/30 e pelo relogio instantaneo e exige traco identico (vida,
-- escudo, mana, intent, mao e estado dos streams do Rng, turno a turno).

local Instant = {}

-- Salto do relogio por iteracao. Maior que qualquer HOLD da tabela de beats
-- (0,55) e que a investida inteira do inimigo (0,76); menor que o timeout do
-- pushUntil (2,5). Ver cabecalho.
Instant.DT = 1.0

-- Teto de iteracoes por dreno. Uma cadeia de turno tem ~10-30 elos que
-- precisam de passada propria (um por golpe multi-hit, um por hold > DT);
-- 400 saltos = 400 s de jogo. Estourar isso e BUG de cadeia (fila que nunca
-- esvazia) e e anunciado, nunca engolido.
Instant.MAX_ITERS = 400

-- Contadores de diagnostico (throughput smoke / relatorio).
Instant.stats = { drains = 0, iters = 0, stalls = 0 }

local EM = require("engine.EventManager")

local function tickWorld(game, dt)
    local okER, ER = pcall(require, "src.ui.EnemyRenderer")
    if okER and ER.update then ER.update(dt) end
    if game.enemy and game.enemy.update then game.enemy:update(dt) end
    if game.combatAnimationSystem and game.combatAnimationSystem.update then
        game.combatAnimationSystem:update(dt)
    end
end

-- Avanca o mundo ate a fila esvaziar e o combate deixar de bloquear.
-- Devolve o numero de iteracoes gastas.
function Instant.drain(game)
    local dt = Instant.DT
    local cs = game.combatAnimationSystem
    local n = 0
    while true do
        n = n + 1
        EM.update(dt)
        tickWorld(game, dt)
        local busy = EM.pendingCount() > 0
            or (cs and cs.isBlocking and cs:isBlocking())
        if not busy then break end
        if n >= Instant.MAX_ITERS then
            Instant.stats.stalls = Instant.stats.stalls + 1
            print(("[instant_engine] fila nao esvaziou em %d saltos (%d eventos pendentes, "
                .. "combate %s) — abandonando o dreno. Isto e BUG de cadeia."):format(
                n, EM.pendingCount(), tostring(cs and cs:isBlocking())))
            break
        end
    end
    Instant.stats.drains = Instant.stats.drains + 1
    Instant.stats.iters = Instant.stats.iters + n
    return n
end

-- Substituto do `pump(game, secs)` do piloto: ignora `secs` (o tempo de
-- espera era so animacao) e drena. Mantem o dreno de apresentacao do piloto
-- por fora (quem instala passa o `drainPresentation`).
function Instant.makePump(drainPresentation)
    return function(game, _secs)
        if drainPresentation then drainPresentation() end
        return Instant.drain(game)
    end
end

-- Liga o relogio instantaneo no piloto. Idempotente.
function Instant.install(Autoplay)
    Autoplay = Autoplay or require("tools.autoplay")
    if Autoplay.pumpImpl and Autoplay.pumpImpl.__instant then return Autoplay end
    local pump = Instant.makePump(Autoplay.drainPresentation)
    Autoplay.pumpImpl = setmetatable({ __instant = true }, { __call = function(_, g, s) return pump(g, s) end })
    Autoplay.clockMode = "instant"
    return Autoplay
end

-- Volta ao relogio de quadros (1/30 s por passo, ou Autoplay.pumpDt).
function Instant.uninstall(Autoplay)
    Autoplay = Autoplay or require("tools.autoplay")
    Autoplay.pumpImpl = nil
    Autoplay.clockMode = "frames"
    return Autoplay
end

function Instant.resetStats()
    Instant.stats = { drains = 0, iters = 0, stalls = 0 }
end

return Instant
