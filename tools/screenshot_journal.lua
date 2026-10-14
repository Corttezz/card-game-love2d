local M = {}

local OUT_DIR = "tools/preview_out/journal_map/"

local function fakeWindow(w, h)
    local rw, rh, rd = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    return function()
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = rw, rh, rd
    end
end

local fakeMX, fakeMY = -100, -100
local function fakeMouse()
    local gp, gx, gy = love.mouse.getPosition, love.mouse.getX, love.mouse.getY
    love.mouse.getPosition = function() return fakeMX, fakeMY end
    love.mouse.getX = function() return fakeMX end
    love.mouse.getY = function() return fakeMY end
    return function() love.mouse.getPosition, love.mouse.getX, love.mouse.getY = gp, gx, gy end
end

local function savePng(canvas, name)
    local fd = canvas:newImageData():encode("png")
    local path = OUT_DIR .. name
    local f = io.open(path, "wb")
    if not f then
        print("[roteiro] nao consegui abrir " .. path .. " (pasta existe?) — gravando no save dir")
        love.filesystem.write(name, fd)
        return
    end
    f:write(fd:getString())
    f:close()
    print("[roteiro] " .. path .. " salvo")
end

local function visit(rm, act, floor, options, pick, snapIn, snapOut, notes, ev)
    local run = rm.currentRun
    run.actNumber = act
    run.floorInAct = floor
    run.currentFloor = (act - 1) * 8 + floor
    local opts = {}
    for i, t in ipairs(options) do opts[i] = { type = t } end
    local node = opts[pick]
    table.insert(run.mapHistory, { actNumber = act, floorInAct = floor, type = node.type })
    rm:journalBegin(node, snapIn, opts, pick)
    if ev then rm:journalEvent(ev.id, ev.idx, ev.label) end
    for _, n in ipairs(notes or {}) do rm:journalNote(n) end
    if snapOut then rm:journalEnd(snapOut) end
end

local function pickIds()
    local CardDatabase = require("src.systems.CardDatabase")
    local cards, jokers = {}, {}
    for id, cd in pairs(CardDatabase:getAllCards()) do
        if cd.type == "joker" then
            table.insert(jokers, id)
        elseif cd.class == "warrior" or cd.class == "basic" then
            table.insert(cards, id)
        end
    end
    table.sort(cards); table.sort(jokers)
    return cards, jokers
end

function M.seedShort(rm, cards, jokers)
    local run = rm.currentRun
    local c1 = cards[1] or "warrior_strike"
    local c2 = cards[2] or "warrior_defend"
    local c3 = cards[3] or c1
    local j1 = jokers[1]

    table.insert(run.mapHistory, { actNumber = 1, floorInAct = 1, type = "battle" })
    table.insert(run.mapHistory, { actNumber = 1, floorInAct = 2, type = "battle" })

    visit(rm, 1, 3, { "event", "battle", "shop" }, 1, { hp = 52, maxHp = 60, gold = 28 },
        { hp = 45, gold = 28 }, { { kind = "card", id = c2 } },
        { id = "evt_altar", idx = 2, label = "Tocar o altar" })
    visit(rm, 1, 4, { "battle", "rest" }, 1, { hp = 45, maxHp = 60, gold = 28 },
        { hp = 38, gold = 47 }, { { kind = "card", id = c3 } })
    visit(rm, 1, 5, { "shop", "rest", "elite" }, 2, { hp = 38, maxHp = 60, gold = 47 },
        { hp = 56, gold = 47 }, { { kind = "forge", id = c1, lvl = 1 } })
    local shopNotes = {}
    if j1 then table.insert(shopNotes, { kind = "joker", id = j1, active = true }) end
    table.insert(shopNotes, { kind = "remove", id = c2 })
    visit(rm, 1, 6, { "battle", "shop" }, 2, { hp = 56, maxHp = 60, gold = 47 },
        { hp = 56, gold = 9 }, shopNotes)
    visit(rm, 1, 7, { "mini_boss" }, 1, { hp = 56, maxHp = 60, gold = 9 },
        { hp = 41, gold = 34 }, { { kind = "card", id = c1 } })
    visit(rm, 1, 8, { "boss" }, 1, { hp = 41, maxHp = 60, gold = 34 },
        { hp = 22, gold = 68 }, { { kind = "card", id = c3 } })

    visit(rm, 2, 1, { "battle", "event", "shop" }, 1, { hp = 40, maxHp = 60, gold = 68 },
        { hp = 33, gold = 85 }, { { kind = "card", id = c2 } })
    visit(rm, 2, 2, { "elite", "battle" }, 1, { hp = 33, maxHp = 60, gold = 85 },
        { hp = 18, gold = 112 }, { { kind = "card", id = c1 },
                                   { kind = "forge", id = c3, lvl = 2 } })
    visit(rm, 2, 3, { "rest", "event", "battle" }, 1, { hp = 18, maxHp = 60, gold = 112 },
        { hp = 36, gold = 112 }, { { kind = "forge", id = c1, lvl = 2 } })
    visit(rm, 2, 4, { "battle", "shop" }, 2, { hp = 36, maxHp = 60, gold = 112 }, nil,
        { { kind = "card", id = c3 } })
    run.actNumber, run.floorInAct = 2, 4
    run.pendingNodes = { { type = "event" }, { type = "battle" }, { type = "elite" } }
    return 2, 2
end

function M.seedLong(rm, cards, jokers)
    local run = rm.currentRun
    local plans = {
        { "battle", "battle", "event", "battle", "rest", "shop", "elite", "boss" },
        { "battle", "event", "battle", "elite", "rest", "battle", "mini_boss", "boss" },
        { "battle", "shop", "battle", "event", "elite", "rest", "battle", "boss" },
        { "event", "battle", "elite", "battle", "shop", "rest", "mini_boss", "boss" },
        { "battle", "battle", "rest", "elite", "event", "shop", "elite", "boss" },
        { "battle", "elite", "event", "battle", "rest", "shop", "mini_boss", "boss" },
    }
    local alt = { "shop", "rest", "event", "battle", "elite" }
    local hp, gold, k = 60, 20, 0
    local function nextCard() k = k + 1; return cards[(k % #cards) + 1] end
    local function options(t, fl, act)
        if fl >= 7 then return { t }, 1 end
        local n = ((fl + act) % 2 == 0) and 3 or 2
        local pick = ((fl * 3 + act) % n) + 1
        local list = {}
        for i = 1, n do
            if i == pick then list[i] = t else list[i] = alt[((fl + i + act) % #alt) + 1] end
        end
        return list, pick
    end
    for act, plan in ipairs(plans) do
        for fl, t in ipairs(plan) do
            local notes = {}
            local hpOut, goldOut = hp, gold
            if t == "battle" or t == "elite" or t == "mini_boss" or t == "boss" then
                hpOut = math.max(8, hp - (t == "battle" and 6 or 14))
                goldOut = gold + (t == "battle" and 16 or 30)
                notes[1] = { kind = "card", id = nextCard() }
                if t == "boss" and jokers[act] then
                    notes[2] = { kind = "joker", id = jokers[act] }
                end
            elseif t == "rest" then
                if fl % 2 == 0 then
                    hpOut = math.min(70, hp + 20)
                else
                    notes[1] = { kind = "forge", id = nextCard(), lvl = act }
                end
            elseif t == "shop" then
                goldOut = math.max(0, gold - 60)
                notes[1] = { kind = "card", id = nextCard() }
                notes[2] = { kind = "remove", id = nextCard() }
                notes[3] = { kind = "card", id = nextCard() }
            elseif t == "event" then
                hpOut = hp - 5
                notes[1] = { kind = "card", id = nextCard() }
            end
            local list, pick = options(t, fl, act)
            visit(rm, act, fl, list, pick, { hp = hp, maxHp = 70, gold = gold },
                { hp = hpOut, gold = goldOut }, notes,
                t == "event" and { id = "evt_x", idx = 1, label = "Beber da fonte" } or nil)
            hp, gold = math.max(20, hpOut), goldOut
            if fl == 8 then hp = math.min(70, hp + 25) end
        end
    end
    local types = { "battle", "elite", "shop", "battle", "rest", "event", "elite", "boss",
                    "battle", "elite", "battle" }
    for i, t in ipairs(types) do
        local fl = ((i - 1) % 8) + 1
        local last = (i == #types)
        local list, pick = options(t, fl, 7)
        visit(rm, 7, fl, list, pick, { hp = hp, maxHp = 70, gold = gold },
            (not last) and { hp = hp - 4, gold = gold + 20 } or nil,
            { { kind = "card", id = nextCard() } })
        hp, gold = hp - 4, gold + 20
    end
    run.actNumber, run.floorInAct, run.endlessMode = 7, 3, true
    return 7, 6
end

function M.setupGame(mode)
    local Game = require("src.core.Game")
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    _G.game = game
    local rm = game.runManager
    local run = rm.currentRun
    run.mapHistory, run.journal, run.journalOpen = {}, {}, nil
    local cards, jokers = pickIds()
    local hb, hn
    if mode == "long" then hb, hn = M.seedLong(rm, cards, jokers)
    else hb, hn = M.seedShort(rm, cards, jokers) end
    return game, hb, hn
end

function M.run(mode, locale)
    _G.EventManager = require("engine.EventManager")
    _G.Event = require("engine.Event")
    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    local FontManager = require("src.ui.FontManager")
    local UiScale = require("src.ui.UiScale")
    UiScale.force(nil)
    if mode == "-" or mode == "" then mode = nil end

    local sizes = {}
    for w, h in tostring(os.getenv("JOURNAL_SIZES") or "1920x1080,1024x768"):gmatch("(%d+)x(%d+)") do
        sizes[#sizes + 1] = { tonumber(w), tonumber(h) }
    end
    local locales = locale and { locale } or { "pt_BR", "de" }

    local game, hb, hn = M.setupGame(mode)
    local Screen = require("components.RunJournalScreen")
    local restoreMouse = fakeMouse()

    for _, loc in ipairs(locales) do
        I18n.setLocale(loc)
        for _, sz in ipairs(sizes) do
            local w, h = sz[1], sz[2]
            local restore = fakeWindow(w, h)
            FontManager.clearCache()
            local ok, err = pcall(function()
                local screen = Screen:new()
                screen:show(game)
                local tag = ("%s_%dx%d_%s"):format(mode or "short", w, h, loc)
                local function shot(suffix)
                    local canvas = love.graphics.newCanvas(w, h)
                    love.graphics.setCanvas(canvas)
                    love.graphics.clear(0, 0, 0, 1)
                    screen:draw()
                    love.graphics.setCanvas()
                    savePng(canvas, "run_journal_" .. tag .. suffix .. ".png")
                    canvas:release()
                end
                fakeMX, fakeMY = -100, -100
                shot("")
                local L = screen:_layout()
                local S = L.sheets[hb]
                local p = S and S.nodes and S.nodes[hn]
                if p then
                    local k = UiScale.k(w, h)
                    fakeMX, fakeMY = p.x * k, p.y * k
                    shot("_hover")
                else
                    print("[roteiro] AVISO: parada alvo do hover nao encontrada")
                end
                fakeMX, fakeMY = -100, -100
                for i = 1, #screen.acts do if not screen:isActOpen(i) then screen:toggleAct(i) end end
                screen:keypressed("home")
                shot("_allopen")
                screen:hide()
            end)
            if not ok then
                love.graphics.setCanvas()
                UiScale.reset()
                print("[roteiro] " .. w .. "x" .. h .. " " .. loc .. " FALHOU: " .. tostring(err))
            end
            restore()
        end
    end
    restoreMouse()
    FontManager.clearCache()
    love.event.quit()
    return true
end

return M
