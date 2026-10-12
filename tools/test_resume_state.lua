-- tools/test_resume_state.lua
-- CONTINUAR NÃO PERDE NADA (Out/2026 — bug do dono: "cliquei em Continuar e
-- todos os PONTOS zeraram. Isso nunca pode acontecer").
--
-- Joga alguns andares (roteiro determinístico: luta vencida, cash out,
-- recompensa, forja, coringa, ouro, pontuação), e em CADA estágio salva →
-- Game NOVO → loadRun → resumeRun e compara em profundidade um retrato de
-- TODO o estado da run. O retrato é a lista do que precisa sobreviver; o que
-- fica de fora está nomeado em TRANSIENT com o porquê. Campo novo no
-- currentRun entra de graça (o retrato copia o currentRun inteiro) — e se
-- não sobreviver à serialização (função, userdata, chave reservada, inf), a
-- diferença aparece aqui com o caminho.
--
--   love . test_one test_resume_state

local TK = require("tools.testkit")

local M = {}

-- Fora do retrato do currentRun, com o motivo:
local TRANSIENT_RUN = {
    rngState = "comparado à parte (estado VIVO do Rng, não o snapshot gravado)",
    battleRng = "comparado indiretamente: a luta retomada tem que repetir mão e golpe",
    battleEnemyRng = "idem (stream do inimigo no spawn)",
}

-- ---------------------------------------------------------------------------
-- Retrato
-- ---------------------------------------------------------------------------
local function deepcopy(v, seen)
    if type(v) ~= "table" then
        if type(v) == "function" or type(v) == "userdata" or type(v) == "thread" then
            return "<" .. type(v) .. ">"   -- não serializa: TEM que acusar diff
        end
        return v
    end
    seen = seen or {}
    if seen[v] then return "<ciclo>" end
    seen[v] = true
    local out = {}
    for k, x in pairs(v) do out[k] = deepcopy(x, seen) end
    seen[v] = nil
    return out
end

local function cardSig(list)
    local all = {}
    for _, c in ipairs(list or {}) do
        all[#all + 1] = ("%s+%s/%s/%s/%s"):format(tostring(c.id),
            tostring(c.upgradeLevel or c.level or c.up or 0),
            tostring(c.attack), tostring(c.edition), tostring(c.seal))
    end
    table.sort(all)
    return table.concat(all, ",")
end

-- O baralho que a PRÓXIMA luta monta (forja/edição/selo aplicados). As
-- pilhas em memória fora da luta são resto da luta anterior (transitório).
local function deckSignature(game)
    return cardSig(game.runManager:buildPlayableDeck())
end

local function rngStreams()
    local st = require("src.systems.Rng").get():getState()
    return { states = deepcopy(st.states), counters = deepcopy(st.counters),
        meta = deepcopy(st.meta) }
end

-- `battle` = estágio de luta: inclui a mão e o inimigo (a luta tem que ser
-- a MESMA). Fora da luta eles são descartáveis (o main mata o inimigo
-- provisório do resumeRun) e o RNG tem que voltar intocado.
local function snapshot(game, battle)
    local run = game.runManager.currentRun
    local runCopy = deepcopy(run)
    for k in pairs(TRANSIENT_RUN) do runCopy[k] = nil end
    local p, sc, ec = game.player, game.scoreSystem, game.economySystem
    local s = {
        run = runCopy,
        score = game.score,
        runScore = sc.runScore,
        recordBroken = sc.recordBroken,
        lastBattle = deepcopy(sc.lastBattle),
        gold = ec.currentGold,
        goldEarned = ec.totalGoldEarned,
        goldSpent = ec.goldSpent,
        interestCap = ec:getInterestCap(),
        maxHealth = p.maxHealth,
        health = p.health,
        baseMaxMana = p.baseMaxMana,
        maxArmor = p.maxArmor,
        orbSlots = p.orbSlots,
        retainArmor = p.retainArmor and true or false,
        maxJokerSlots = game.maxJokerSlots,
        jokers = {},
        deck = deckSignature(game),
        selectedClass = game.selectedClass,
        isRunMode = game.isRunMode,
    }
    for i, j in ipairs(game.jokerSlots or {}) do s.jokers[i] = j.id end
    if battle then
        s.hand = {}
        for i, c in ipairs(game.hand) do s.hand[i] = c.id end
        s.piles = cardSig(game.deck) .. " | " .. cardSig(game.discard)
        s.enemy = {
            id = game.enemy.kitId or game.enemy.spriteId,
            maxHealth = game.enemy.maxHealth, health = game.enemy.health,
            damage = game.enemy.damage, intent = deepcopy(game.enemy.nextIntent),
            intentDamage = game.enemy.nextIntentDamage,
        }
        s.mana = p.mana
        s.maxMana = p.maxMana
        s.orbs = deepcopy(p.orbs)
        s.buffs = deepcopy(p.buffs)
        s.armor = p.armor
    end
    -- Na luta: o RNG retomado tem que estar EXATAMENTE onde a luta original
    -- estava depois de montada (mesmos sorteios consumidos, em cada stream) —
    -- senão o golpe seguinte do inimigo já diverge, mesmo com a abertura
    -- igual. Fora da luta: intocado.
    s.rng = rngStreams()
    return s
end

local function diff(a, b, path, out)
    if type(a) ~= type(b) then
        out[#out + 1] = ("%s: %s ≠ %s"):format(path, tostring(a), tostring(b))
        return
    end
    if type(a) ~= "table" then
        if a ~= b then out[#out + 1] = ("%s: %s ≠ %s"):format(path, tostring(a), tostring(b)) end
        return
    end
    for k, v in pairs(a) do diff(v, b[k], path .. "." .. tostring(k), out) end
    for k, v in pairs(b) do
        if a[k] == nil then out[#out + 1] = ("%s.%s: (ausente) ≠ %s"):format(path, tostring(k), tostring(v)) end
    end
end

-- Save → Game NOVO → loadRun → resumeRun (o mesmo caminho do Continuar).
local function continueFromDisk()
    local Game = require("src.core.Game")
    local g = Game:new()
    local ok = g.runManager:loadRun()
    if ok then g:resumeRun() end
    return g, ok
end

local function check(t, label, before, game, battle)
    local g2, ok = continueFromDisk()
    if not t:truthy(label .. ": save carregou", ok) then return g2 end
    local after = snapshot(g2, battle)
    local out = {}
    diff(before, after, "estado", out)
    for i = 1, math.min(#out, 12) do print("      DIFF " .. out[i]) end
    t:eq(label .. ": estado idêntico após Continuar (nº de diferenças)", #out, 0)
    return g2
end

-- ---------------------------------------------------------------------------
-- Roteiro
-- ---------------------------------------------------------------------------
local function anyJokerId()
    local CardDatabase = require("src.systems.CardDatabase")
    local ids = {}
    for id, cd in pairs(CardDatabase:getAllCards()) do
        if type(cd) == "table" and cd.type == "joker" then ids[#ids + 1] = cd.id or id end
    end
    table.sort(ids)
    return ids[1]
end

local function winBattle(game)
    game.enemy.health = 0
    game:_onEnemyDeath()
    game.runManager.currentRun.battlesWon = (game.runManager.currentRun.battlesWon or 0) + 1
end

local function goToNextBattle(game, stripEnemy)
    local rm = game.runManager
    rm:advanceFloorInAct()
    rm:generateNextNodes(3)
    local idx = 1
    for i, n in ipairs(rm:getPendingNodes()) do
        if n.type == "battle" then idx = i break end
    end
    rm:chooseNode(idx, { hp = game.player.health, maxHp = game.player.maxHealth,
        gold = game.economySystem.currentGold })
    rm.currentRun.currentNode.type = "battle"
    -- Nó SEM inimigo pré-sorteado (save antigo, ou evento que caiu pra luta
    -- comum): o nextPhase sorteia quem luta. Era o caminho em que a luta
    -- retomada abria com outro golpe — e o roteiro só passava por ele quando
    -- a encruzilhada sorteada não tinha nó de luta (dependia da ordem das
    -- suítes). Agora é forçado.
    if stripEnemy then
        rm.currentRun.currentNode.enemyId = nil
    elseif not rm.currentRun.currentNode.enemyId then
        require("src.systems.EnemyRoster").assignNodes(rm.currentRun, { rm.currentRun.currentNode })
    end
    game:nextPhase()
end

local function stage(game, name, extra)
    local run = game.runManager.currentRun
    run.stage = name
    run.stageEventId = extra
    game:checkpointRun()
end

function M.run()
    local t = TK.new("Continuar preserva TODO o estado da run")
    TK.bootstrap()
    local SaveManager = require("engine.SaveManager")
    SaveManager.deleteRun()
    TK.seedRng(31337)

    local game = TK.newRunGame("mage")
    local rm = game.runManager
    local run = rm.currentRun

    -- ===== andar 1: luta vencida, ouro, pontuação =====
    goToNextBattle(game)
    winBattle(game)
    t:truthy("roteiro: a luta pontuou", (game.score or 0) > 0)
    game.economySystem:earnGold(40, "test")
    game.economySystem:spendGold(7, "card", "x")

    -- CASH OUT
    stage(game, "cashout")
    local snap = snapshot(game, false)
    local g2 = check(t, "cashout", snap, game, false)
    t:truthy("cashout: pontos NÃO zeram (game.score = runScore)",
        g2.score == game.score and g2.score > 0)
    t:truthy("cashout: recibo da última batalha volta",
        g2.scoreSystem.lastBattle and g2.scoreSystem.lastBattle.total == game.scoreSystem.lastBattle.total)

    -- RECOMPENSA: carta nova, forja, coringa, vida/mana máximas
    stage(game, "rewards")
    game:addCardToRun(run.currentDeck[1] and (type(run.currentDeck[1]) == "table"
        and run.currentDeck[1].id or run.currentDeck[1]))
    -- Baralho grande o bastante pra mão inicial ser um SORTEIO de verdade
    -- (com 4 cartas a mão é o deck inteiro e a ordem quase não pesa).
    local CardDatabase = require("src.systems.CardDatabase")
    local extra = {}
    for id, cd in pairs(CardDatabase:getAllCards()) do
        if type(cd) == "table" and cd.class == "mage" and cd.type ~= "joker" then
            extra[#extra + 1] = cd.id or id
        end
    end
    table.sort(extra)
    for i = 1, math.min(8, #extra) do game:addCardToRun(extra[i]) end
    if rm.upgradeCardAt then rm:upgradeCardAt(1) end
    local jid = anyJokerId()
    if jid then game:addJokerToRun(jid) end
    game.player.maxHealth = game.player.maxHealth + 5
    game.player.baseMaxMana = game.player.baseMaxMana + 1
    game:checkpointRun()
    check(t, "rewards", snapshot(game, false), game, false)

    -- ENCRUZILHADA
    rm:advanceFloorInAct()
    rm:generateNextNodes(3)
    stage(game, "fork")
    check(t, "fork", snapshot(game, false), game, false)

    -- LOJA / DESCANSO / EVENTO (o nó em si já tem cobertura própria; aqui o
    -- que importa é o estado da run em volta)
    rm:chooseNode(1, { hp = game.player.health, maxHp = game.player.maxHealth,
        gold = game.economySystem.currentGold })
    stage(game, "shop")
    check(t, "shop", snapshot(game, false), game, false)
    stage(game, "rest")
    check(t, "rest", snapshot(game, false), game, false)
    stage(game, "event", "x_test_event")
    check(t, "event", snapshot(game, false), game, false)

    -- ===== andar 2: LUTA (retomar = a MESMA luta, do começo) =====
    run.stage = "fork"; run.pendingNodes = nil
    goToNextBattle(game)
    local battleSnap = snapshot(game, true)
    t:eq("luta: mago abre com 1 orbe (passiva uma vez só)", #(game.player.orbs or {}), 1)
    -- Jogar um turno: "Salvar e sair" no meio da luta NÃO regrava; o
    -- Continuar volta ao início dela.
    game.player.health = game.player.health - 7
    game.economySystem:earnGold(3, "mid")
    local gb = check(t, "luta (meio do combate → recomeça igual)", battleSnap, game, true)
    t:eq("luta: mago retomado também tem 1 orbe", #(gb.player.orbs or {}), 1)

    -- As duas origens do inimigo: pré-sorteado na encruzilhada (caminho
    -- normal) e sorteado no nextPhase (save antigo / evento que vira luta).
    -- Antes do conserto, só uma delas batia — e qual dependia do mapa.
    for _, strip in ipairs({ false, true }) do
        winBattle(game)
        run.stage = "fork"; run.pendingNodes = nil
        goToNextBattle(game, strip)
        local label = strip and "luta (inimigo sorteado no nextPhase)"
            or "luta (inimigo pré-sorteado no nó)"
        check(t, label, snapshot(game, true), game, true)
    end

    -- ===== ENDLESS =====
    winBattle(game)
    run.campaignWon = true
    game:enterEndless()
    local RunModifiers = require("src.systems.RunModifiers")
    if RunModifiers.beginEndlessCycle then RunModifiers.beginEndlessCycle(run) end
    stage(game, "cashout")
    check(t, "endless (cash out)", snapshot(game, false), game, false)

    -- ===== serialização: chaves reservadas e infinito =====
    local SM = require("engine.SaveManager")
    local txt = "return " .. SM.serialize({ ["end"] = 1, big = math.huge, neg = -math.huge })
    local back = SM.decodeData(txt, "x")
    t:truthy("serialize: chave reservada e ±inf voltam",
        back and back["end"] == 1 and back.big == math.huge and back.neg == -math.huge)

    SaveManager.deleteRun()
    return t:done()
end

return M
