-- tools/screenshot_journal.lua
-- Capturas do ROTEIRO DA JORNADA (components/RunJournalScreen.lua).
--
--   love . screenshot_journal               → run_journal_short_<WxH>_<loc>[_hover].png
--   love . screenshot_journal long          → run longa: 6 atos + endless
--   love . screenshot_journal small         → janela estreita 760x560
--   love . screenshot_journal - de          → outro idioma (3º arg)
--
-- Tamanho da janela por ambiente: JOURNAL_W / JOURNAL_H (um setMode por
-- processo — a memória de invariantes registra que setMode repetido dentro de
-- um tool TRAVA). Pedir janela maior que o desktop também trava: fique em
-- até 1920x1080.
--
-- Run CURTA: ato 1 fechado (CONQUISTADO) + ato 2 em andamento. Os dois
-- primeiros nós entram SÓ no mapHistory — é o backfill das runs anteriores à
-- feature ("Sem detalhes registrados").
-- Run LONGA: os 6 atos da campanha + uma faixa de endless com 11 paradas; é a
-- que exercita a rolagem e as linhas de 8 do endless.

local M = {}

local function capture(name)
    love.graphics.captureScreenshot(function(imageData)
        imageData:encode("png", name)
        print("[roteiro] " .. name .. " salvo")
    end)
    love.graphics.present()
end

-- Visita um nó como o jogo visitaria: mapHistory + journalBegin/Note/End.
-- Sem snapOut a entrada fica ABERTA — é o "você está aqui" (aro pulsando).
local function visit(rm, act, floor, ntype, snapIn, snapOut, notes, ev)
    local run = rm.currentRun
    run.actNumber = act
    run.floorInAct = floor
    run.currentFloor = (act - 1) * 8 + floor
    table.insert(run.mapHistory, { actNumber = act, floorInAct = floor, type = ntype })
    rm:journalBegin({ type = ntype }, snapIn)
    if ev then rm:journalEvent(ev.id, ev.idx, ev.label) end
    for _, n in ipairs(notes or {}) do rm:journalNote(n) end
    if snapOut then rm:journalEnd(snapOut) end
end

-- Ids reais do catálogo (carta inventada faria o tooltip avisar e a captura
-- mentir).
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

local function seedShort(rm, cards, jokers)
    local run = rm.currentRun
    local c1 = cards[1] or "warrior_strike"
    local c2 = cards[2] or "warrior_defend"
    local c3 = cards[3] or c1
    local j1 = jokers[1]

    table.insert(run.mapHistory, { actNumber = 1, floorInAct = 1, type = "battle" })
    table.insert(run.mapHistory, { actNumber = 1, floorInAct = 2, type = "battle" })

    visit(rm, 1, 3, "event", { hp = 52, maxHp = 60, gold = 28 },
        { hp = 45, gold = 28 }, { { kind = "card", id = c2 } },
        { id = "evt_altar", idx = 2, label = "Tocar o altar" })
    visit(rm, 1, 4, "battle", { hp = 45, maxHp = 60, gold = 28 },
        { hp = 38, gold = 47 }, { { kind = "card", id = c3 } })
    visit(rm, 1, 5, "rest", { hp = 38, maxHp = 60, gold = 47 },
        { hp = 56, gold = 47 }, { { kind = "forge", id = c1, lvl = 1 } })
    local shopNotes = {}
    if j1 then table.insert(shopNotes, { kind = "joker", id = j1, active = true }) end
    table.insert(shopNotes, { kind = "remove", id = c2 })
    visit(rm, 1, 6, "shop", { hp = 56, maxHp = 60, gold = 47 },
        { hp = 56, gold = 9 }, shopNotes)
    visit(rm, 1, 7, "mini_boss", { hp = 56, maxHp = 60, gold = 9 },
        { hp = 41, gold = 34 }, { { kind = "card", id = c1 } })
    visit(rm, 1, 8, "boss", { hp = 41, maxHp = 60, gold = 34 },
        { hp = 22, gold = 68 }, { { kind = "card", id = c3 } })

    visit(rm, 2, 1, "battle", { hp = 40, maxHp = 60, gold = 68 },
        { hp = 33, gold = 85 }, { { kind = "card", id = c2 } })
    visit(rm, 2, 2, "elite", { hp = 33, maxHp = 60, gold = 85 },
        { hp = 18, gold = 112 }, { { kind = "card", id = c1 },
                                   { kind = "forge", id = c3, lvl = 2 } })
    visit(rm, 2, 3, "rest", { hp = 18, maxHp = 60, gold = 112 },
        { hp = 36, gold = 112 }, { { kind = "forge", id = c1, lvl = 2 } })
    visit(rm, 2, 4, "shop", { hp = 36, maxHp = 60, gold = 112 }, nil,
        { { kind = "card", id = c3 } })
    run.actNumber, run.floorInAct = 2, 4
    return 1, 6   -- faixa/parada do hover (a loja com coringa + remoção)
end

-- 6 atos completos + endless. Tipos variam por ato pra a grade não virar
-- papel de parede; ganhos ciclam pelo catálogo.
local function seedLong(rm, cards, jokers)
    local run = rm.currentRun
    local plans = {
        { "battle", "battle", "event", "battle", "rest", "shop", "elite", "boss" },
        { "battle", "event", "battle", "elite", "rest", "battle", "mini_boss", "boss" },
        { "battle", "shop", "battle", "event", "elite", "rest", "battle", "boss" },
        { "event", "battle", "elite", "battle", "shop", "rest", "mini_boss", "boss" },
        { "battle", "battle", "rest", "elite", "event", "shop", "elite", "boss" },
        { "battle", "elite", "event", "battle", "rest", "shop", "mini_boss", "boss" },
    }
    local hp, gold, k = 60, 20, 0
    local function nextCard() k = k + 1; return cards[(k % #cards) + 1] end
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
            visit(rm, act, fl, t, { hp = hp, maxHp = 70, gold = gold },
                { hp = hpOut, gold = goldOut }, notes,
                t == "event" and { id = "evt_x", idx = 1, label = "Beber da fonte" } or nil)
            hp, gold = math.max(20, hpOut), goldOut
            if fl == 8 then hp = math.min(70, hp + 25) end
        end
    end
    -- Endless: o ato trava em totalActs+1 e o andar cicla 1..8.
    local types = { "battle", "elite", "shop", "battle", "rest", "event", "elite", "boss",
                    "battle", "elite", "battle" }
    for i, t in ipairs(types) do
        local fl = ((i - 1) % 8) + 1
        local last = (i == #types)
        visit(rm, 7, fl, t, { hp = hp, maxHp = 70, gold = gold },
            (not last) and { hp = hp - 4, gold = gold + 20 } or nil,
            { { kind = "card", id = nextCard() } })
        hp, gold = hp - 4, gold + 20
    end
    run.actNumber, run.floorInAct, run.endlessMode = 7, 3, true
    return 7, 6
end

function M.run(mode, locale)
    _G.EventManager = require("engine.EventManager")
    _G.Event = require("engine.Event")
    local I18n = require("src.i18n.I18n")
    I18n.init()
    -- Locale FIXO: o sandbox herda settings.tool.lua, que pode estar em
    -- qualquer idioma — a captura viraria alemão sem aviso.
    I18n.setLocale(locale or "pt_BR")
    require("src.ui.PixelCanvas").enableNearest()

    local W, H = tonumber(os.getenv("JOURNAL_W")), tonumber(os.getenv("JOURNAL_H"))
    if mode == "small" then W, H = 760, 560 end
    if W and H then love.window.setMode(W, H, { resizable = true }) end

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
    if mode == "long" then
        hb, hn = seedLong(rm, cards, jokers)
    else
        hb, hn = seedShort(rm, cards, jokers)
    end

    -- JOURNAL_PROTO: outro módulo de tela (protótipos/antes-depois).
    local proto = os.getenv("JOURNAL_PROTO")
    local screen = require(proto or "components.RunJournalScreen"):new()
    screen:show(game)

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local tag = ("%s_%dx%d_%s"):format(mode or "short", sw, sh, locale or "pt_BR")
    if proto then tag = tag .. "_" .. (os.getenv("JOURNAL_PROTO_TAG") or "proto") end

    love.mouse.setPosition(-100, -100)
    love.graphics.clear(0, 0, 0, 1)
    screen:draw()
    capture("run_journal_" .. tag .. ".png")

    local L = screen:_layout()
    local band = L.bands[hb]
    local cell = band and (band.cells or band.nodes)[hn]
    if cell then
        love.mouse.setPosition(cell.cx, cell.cy)
    else
        print("[roteiro] AVISO: parada alvo do hover não encontrada")
    end
    love.graphics.clear(0, 0, 0, 1)
    screen:draw()
    capture("run_journal_" .. tag .. "_hover.png")

    love.event.quit()
end

return M
