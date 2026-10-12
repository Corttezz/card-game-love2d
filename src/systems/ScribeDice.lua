-- src/systems/ScribeDice.lua
-- DADOS DO ESCRIBA (Out/2026): a aposta opcional da loja. LÓGICA PURA —
-- a tela é components/ScribeDiceScreen.lua, os números são
-- Config.Economy.DICE.
--
-- O QUE É
-- Dois dados de osso. O jogador escolhe a APOSTA (Baixo 2-6 / Sete / Alto
-- 8-12) e o VALOR (três fichas que crescem por ato), paga e lança. Uma
-- jogada por visita à loja.
--
-- POR QUE ESTE DESENHO (e não outro)
--   • Probabilidade LEGÍVEL: a soma de 2d6 é a distribuição que todo jogador
--     de tabuleiro já conhece, e cada aposta mostra a chance em % escrita
--     na ficha. Nada de odds escondidas.
--   • EV ~justo (Baixo/Alto 15/36 × 2,5 = 1,04; Sete 6/36 × 6 = 1,00): a
--     aposta não é imposto disfarçado nem mina de ouro. O que ela VENDE é
--     VARIÂNCIA — e variância tem valor real quando falta pouco pra uma
--     compra ("tenho $22, a bancada custa $30"). É uma decisão, não um
--     botão de ganhar dinheiro.
--   • NÃO É FARMÁVEL: uma jogada por loja (a loja é nó do mapa, então o teto
--     é o número de lojas da corrida) e a ficha maior é limitada por ato.
--   • NÃO É SAVE-SCUMÁVEL: os dados saem do stream "shop" do Rng da run e
--     o resultado é gravado no save NO MESMO FRAME do lançamento, antes de
--     a animação revelar qualquer coisa. Fechar o jogo no meio da rolagem e
--     voltar mostra a mesa já usada, com o mesmo resultado.
--
-- ESTADO (viaja no save): currentRun.scribeDice = {
--   key   = chave do nó da loja (dois nós nunca colidem),
--   used  = true depois do lançamento,
--   bet, stake, dice = {a, b}, sum, won, payout }
-- Estado de OUTRO nó é resíduo e é descartado ao consultar.

local Config = require("src.core.Config")
local Rng = require("src.systems.Rng")

local ScribeDice = {}

local function cfg()
    local c = Config.Economy and Config.Economy.DICE
    if not c then
        print("[ScribeDice] Config.Economy.DICE ausente — mini-jogo desligado")
    end
    return c
end

-- Ordem = ordem da tela (esquerda → direita).
ScribeDice.BET_IDS = { "low", "seven", "high" }

-- Faixas de soma de cada aposta. A chance é CONTADA (36 combinações), não
-- escrita à mão: um número na ficha que não bate com a regra é mentira de UI.
local RANGES = {
    low   = { 2, 6 },
    seven = { 7, 7 },
    high  = { 8, 12 },
}

function ScribeDice.wins(betId, sum)
    local r = RANGES[betId]
    return r ~= nil and sum >= r[1] and sum <= r[2]
end

-- Chance exata de vencer (0..1), contando as 36 combinações de 2d6.
function ScribeDice.chance(betId)
    local n = 0
    for a = 1, 6 do
        for b = 1, 6 do
            if ScribeDice.wins(betId, a + b) then n = n + 1 end
        end
    end
    return n / 36
end

-- Multiplicador PAGO na vitória (o retorno total: aposta $8 × 2,5 = $20).
function ScribeDice.payoutMult(betId)
    local c = cfg()
    local m = c and c.PAYOUT and c.PAYOUT[betId]
    if not m then
        print("[ScribeDice] aposta sem pagamento no Config: " .. tostring(betId))
        return 0
    end
    return m
end

-- Valor esperado por $1 apostado (1,0 = justo). Exposto pro teste travar o
-- desenho: se alguém mexer no pagamento e a aposta virar mina, fica vermelho.
function ScribeDice.expectedValue(betId)
    return ScribeDice.chance(betId) * ScribeDice.payoutMult(betId)
end

-- Quanto volta pro bolso numa vitória com `stake` (inteiro, arredonda pra
-- baixo — a casa nunca paga centavo).
function ScribeDice.payout(betId, stake)
    return math.floor(stake * ScribeDice.payoutMult(betId))
end

-- As três fichas do ato: base × (1 + POR_ATO × (ato-1)), arredondadas pra
-- PAR (×2,5 de um par é sempre inteiro — a ficha nunca paga $12,50).
function ScribeDice.stakes(act)
    local c = cfg()
    if not c then return {} end
    act = math.max(1, math.floor(tonumber(act) or 1))
    local k = 1 + (c.STAKE_PER_ACT or 0) * (act - 1)
    local out = {}
    for i, base in ipairs(c.STAKES or {}) do
        local v = base * k
        out[i] = math.max(2, 2 * math.floor(v / 2 + 0.5))
    end
    return out
end

-- Chave do nó: mesma ideia da vitrine no save (CardRewardScreen) —
-- ato + andar + quantos nós já foram escolhidos.
function ScribeDice.nodeKey(run)
    return ("dice|%d|%d|%d"):format(run.actNumber or 1, run.floorInAct or 1,
        #(run.mapHistory or {}))
end

-- Estado do nó ATUAL (nil se não houve jogada aqui). Resíduo de outro nó é
-- apagado — senão a mesa da loja anterior apareceria "usada" na próxima.
function ScribeDice.state(run)
    if not run then return nil end
    local st = run.scribeDice
    if st and st.key ~= ScribeDice.nodeKey(run) then
        run.scribeDice = nil
        return nil
    end
    return st
end

function ScribeDice.isUsed(run)
    local st = ScribeDice.state(run)
    return st ~= nil and st.used == true
end

-- Pode lançar? Devolve (ok, motivo). Motivos viram chave i18n na tela.
function ScribeDice.canRoll(run, economy, betId, stake)
    if not cfg() then return false, "disabled" end
    if not run then return false, "no_run" end
    if ScribeDice.isUsed(run) then return false, "used" end
    if not RANGES[betId] then return false, "bad_bet" end
    local valid = false
    for _, s in ipairs(ScribeDice.stakes(run.actNumber)) do
        if s == stake then valid = true end
    end
    if not valid then return false, "bad_stake" end
    if not economy or not economy:canAfford(stake) then return false, "poor" end
    return true
end

-- O LANÇAMENTO. Cobra, sorteia (stream "shop"), paga, marca o nó como usado
-- e devolve o estado. Quem chama grava o checkpoint NA HORA (a tela faz).
function ScribeDice.roll(run, economy, betId, stake)
    local ok, why = ScribeDice.canRoll(run, economy, betId, stake)
    if not ok then return nil, why end

    economy:spendGold(stake, "minigame", "scribe_dice")
    local rng = Rng.get()
    local a = rng:random("shop", 6)
    local b = rng:random("shop", 6)
    local sum = a + b
    local won = ScribeDice.wins(betId, sum)
    local payout = won and ScribeDice.payout(betId, stake) or 0
    if payout > 0 then economy:earnGold(payout, "scribe_dice") end

    local st = {
        key = ScribeDice.nodeKey(run), used = true,
        bet = betId, stake = stake, dice = { a, b }, sum = sum,
        won = won, payout = payout,
    }
    run.scribeDice = st
    return st
end

return ScribeDice
