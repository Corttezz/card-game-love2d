local TK = require("tools.testkit")

local M = {}
local DT = 1 / 30

local played = {}
local realPlay

local function spy()
    local Sfx = require("src.systems.Sfx")
    realPlay = realPlay or Sfx.play
    played = {}
    Sfx.play = function(name, opts)
        played[#played + 1] = { name = name, opts = opts or {}, at = M._clock or 0 }
        return realPlay(name, opts)
    end
end

local function unspy()
    if realPlay then require("src.systems.Sfx").play = realPlay end
end

local function count(name, from, to)
    local n = 0
    for _, p in ipairs(played) do
        if p.name == name and (not from or p.at >= from) and (not to or p.at < to) then n = n + 1 end
    end
    return n
end

local function open(opts)
    opts = opts or {}
    _G.EventManager.clear()
    local RoundEvalScreen = require("components.RoundEvalScreen")
    local game = TK.newRunGame("warrior")
    if opts.boss then
        game.runManager.currentRun.currentNode = { type = "boss" }
    end
    game.scoreSystem = game.scoreSystem or {}
    game.scoreSystem.lastBattle = opts.score and {
        total = 2232, breakdown = { { label = "Inimigo", value = "2232 pts" }, { label = "Rapido", value = "+210%" } },
    } or nil
    local screen = RoundEvalScreen:new()
    local calls = { n = 0 }
    M._clock = 0
    screen:show(game, opts.sources or {
        { label = "Vitoria", dollars = 13, kind = "victory" },
        { label = "HP cheio", dollars = 3, kind = "full_hp" },
        { label = "Chefe", dollars = 12, kind = "boss" },
        { label = "Juros", dollars = 2, kind = "interest" },
    }, function() calls.n = calls.n + 1 end)
    return screen, calls, game
end

local function step(screen, secs)
    for _ = 1, math.max(1, math.floor(secs / DT + 0.5)) do
        M._clock = M._clock + DT
        _G.EventManager.update(DT)
        screen:update(DT)
        love.graphics.origin()
        pcall(screen.draw, screen)
    end
end

local function staged(t)
    spy()
    local screen = open({ boss = true, score = true })
    t:eq("total da conta", screen.totalDollars, 30)
    t:falsy("abre contando", screen.landed)
    t:truthy("isCounting enquanto conta", screen:isCounting())
    t:falsy("botao nao aparece antes do pouso", screen.cashOutReady)

    local samples, mono = {}, true
    local prev = 0
    local firstRow = screen.rows[1].revealAt
    t:truthy(("chefe: linhas esperam o sting do fim de ato (%.2f s)"):format(firstRow), firstRow >= 1.55)
    while not screen.landed and M._clock < 15 do
        step(screen, DT)
        if screen.coinsAccumulated < prev then mono = false end
        prev = screen.coinsAccumulated
        samples[#samples + 1] = screen.coinsAccumulated
    end
    t:truthy("contagem nunca volta", mono)
    t:truthy("pousou", screen.landed)
    t:eq("total chega exato", screen.coinsAccumulated, 30)
    for i, r in ipairs(screen.rows) do
        t:eq(("linha %d: valor final"):format(i), r.value, r.n)
        t:truthy(("linha %d: revelada em ordem"):format(i), i == 1 or r.revealAt > screen.rows[i - 1].revealAt)
    end
    local lands = count("shopChestCoins")
    t:eq("pouso: um so baque de moedas", lands, 1)

    local ticks = {}
    for _, p in ipairs(played) do if p.name == "coinTick" then ticks[#ticks + 1] = p end end
    t:truthy(("tiques tocaram (%d)"):format(#ticks), #ticks >= 12)
    local r1 = screen.rows[1]
    local inRow = {}
    for _, p in ipairs(ticks) do
        if p.at >= r1.countAt and p.at <= r1.countEnd + DT then inRow[#inRow + 1] = p end
    end
    t:truthy(("linha 1: varios tiques (%d)"):format(#inRow), #inRow >= 5)
    if #inRow >= 4 then
        local half = math.floor(#inRow / 2)
        local gapA = (inRow[half].at - inRow[1].at) / math.max(1, half - 1)
        local gapB = (inRow[#inRow].at - inRow[half].at) / math.max(1, #inRow - half)
        t:truthy(("tique acelera: intervalo cai (%.3f -> %.3f)"):format(gapA, gapB), gapB < gapA)
        t:truthy(("tique sobe de tom (%.2f -> %.2f)"):format(inRow[1].opts.pitch, inRow[#inRow].opts.pitch),
            inRow[#inRow].opts.pitch > inRow[1].opts.pitch)
    end
    local minGap = math.huge
    for i = 2, #ticks do minGap = math.min(minGap, ticks[i].at - ticks[i - 1].at) end
    t:truthy(("tiques sem metralhar (min %.3f s)"):format(minGap), minGap >= 0.03)
    local loudEarly = 0
    for _, p in ipairs(played) do
        if p.at < 2.0 and (p.name == "coinTick" or p.name == "coinTotalThud") and (p.opts.volume or 1) > 0.5 then loudEarly = loudEarly + 1 end
    end
    t:eq("nada de moeda alta por cima do sting (0-2 s)", loudEarly, 0)

    step(screen, 0.2)
    t:falsy("botao espera o total assentar", screen.cashOutReady)
    step(screen, 0.4)
    t:truthy("botao aparece depois do pouso", screen.cashOutReady)
    t:eq("sino do botao uma vez", count("cashOutChime"), 1)
    t:truthy("brilhos e particulas no pouso", #screen._fx > 0 or #screen._glints > 0)
    unspy()
end

local function skipping(t)
    spy()
    local screen, calls, game = open({ score = true })
    step(screen, 0.1)
    screen:mousepressed(10, 10, 1)
    t:falsy("clique no primeiro quarto de segundo nao pula (clique que fechou a luta)", screen.landed)
    step(screen, 0.4)
    screen:mousepressed(10, 10, 1)
    t:truthy("clique pula a contagem", screen.landed)
    t:eq("pular mostra o total exato", screen.coinsAccumulated, screen.totalDollars)
    for i, r in ipairs(screen.rows) do t:eq(("pular: linha %d completa"):format(i), r.value, r.n) end
    t:eq("pular: um so pouso", count("shopChestCoins"), 1)
    t:falsy("pular nao resgata sozinho", screen._closing)
    step(screen, 0.3)
    t:truthy("botao logo depois de pular", screen.cashOutReady)
    local before = game.economySystem.currentGold
    screen:keypressed("return")
    t:truthy("Enter resgata", screen._closing)
    step(screen, 2.0)
    t:eq("ouro entra uma vez", game.economySystem.currentGold, before + screen.totalDollars)
    t:eq("segue para os espolios", calls.n, 1)

    local s2 = open()
    step(s2, 0.5)
    t:truthy("Espaco tambem pula", s2:keypressed("space") and s2.landed)
    t:falsy("Esc nao e engolido (menu de pausa)", s2:keypressed("escape"))
    unspy()
end

local function reduced(t)
    spy()
    _G.gameSettings = _G.gameSettings or {}
    local was = _G.gameSettings.reducedMotion
    _G.gameSettings.reducedMotion = true
    local screen = open({ boss = true })
    t:eq("movimento reduzido: painel ja no lugar", screen.slideOffsetY, 0)
    while not screen.cashOutReady and M._clock < 10 do step(screen, DT) end
    t:truthy("movimento reduzido: chega ao botao", screen.cashOutReady)
    t:eq("movimento reduzido: sem tiques", count("coinTick"), 0)
    t:eq("movimento reduzido: sem particulas", #screen._fx + #screen._glints, 0)
    t:eq("movimento reduzido: total exato", screen.coinsAccumulated, screen.totalDollars)
    t:truthy(("movimento reduzido: mais curto (%.2f s)"):format(screen.landAt), screen.landAt < 3.0)
    _G.gameSettings.reducedMotion = was
    unspy()
end

local function edges(t)
    spy()
    local s = open({ sources = { { label = "Vitoria", dollars = 1, kind = "victory" } } })
    while not s.cashOutReady and M._clock < 8 do step(s, DT) end
    t:eq("um dolar: total 1", s.coinsAccumulated, 1)
    local big = open({ sources = { { label = "Vitoria", dollars = 180, kind = "victory" } } })
    while not big.landed and M._clock < 8 do step(big, DT) end
    t:eq("180: total exato", big.coinsAccumulated, 180)
    t:truthy(("180: contagem curta (%.2f s)"):format(big.landAt), big.landAt < 3.0)
    t:truthy("180: moedas da pilha limitadas", big.rows[1].coins <= 10)
    local zero = open({ sources = {} })
    while not zero.cashOutReady and M._clock < 8 do step(zero, DT) end
    t:truthy("sem fontes: chega ao botao", zero.cashOutReady)
    local early = open()
    early:_onCashOutClick()
    step(early, 2.0)
    t:falsy("resgate no meio da contagem fecha", early:isVisible())

    local Game = require("src.core.Game")
    local g = TK.newRunGame("warrior")
    local kinds = {}
    for _, src in ipairs(g:_buildRoundEvalSources()) do kinds[#kinds + 1] = tostring(src.kind) end
    t:truthy("fontes trazem o tipo (icone): " .. table.concat(kinds, ","), #kinds > 0 and kinds[1] == "victory")
    local RE = require("components.RoundEvalScreen")
    for kind, icon in pairs(RE.ROW_ICONS) do
        t:truthy(("icone de %s existe"):format(kind), love.filesystem.getInfo("assets/sprites/icons/" .. icon .. ".png") ~= nil)
    end
    t:truthy("som do tique existe", love.filesystem.getInfo("audio/sfx/coin-tick.mp3") ~= nil)
    t:truthy("Game carregado", Game ~= nil)
    unspy()
end

local function toast(t)
    local AT = require("src.ui.AchievementToast")
    AT.clear()
    AT.anchor = "top"
    AT.hold = true
    AT.push({ name = "x", desc = "y" })
    AT.update(0.5)
    t:falsy("toast espera durante a contagem", AT._current())
    AT.hold = false
    AT.update(0.1)
    t:truthy("toast sai depois do pouso", AT._current())
    AT.anchor = "bottom"
    local _, y, _, h = AT.rect(1280, 720)
    t:truthy(("no cash out o toast fica embaixo, sob o botao (y=%d)"):format(y), y > 720 * 0.78 + 42 and y + h <= 720)
    AT.anchor = "top"
    local _, y2 = AT.rect(1280, 720)
    t:eq("fora do cash out continua no topo", y2, 60)
    AT.clear()
end

function M.run()
    TK.bootstrap()
    local t = TK.new("espolios: contagem do cash out")
    for _, f in ipairs({ { "contagem", staged }, { "pular", skipping }, { "movimento reduzido", reduced }, { "bordas", edges }, { "toast", toast } }) do
        local ok, err = pcall(f[2], t)
        t:truthy(f[1] .. " sem erro" .. (ok and "" or (": " .. tostring(err))), ok)
        unspy()
    end
    return t:done()
end

return M
