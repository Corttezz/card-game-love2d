-- tools/screenshot_journal.lua
-- Capturas do ROTEIRO DA JORNADA (components/RunJournalScreen.lua).
--
--   love . screenshot_journal          → run_journal.png, run_journal_hover.png
--   love . screenshot_journal small    → run_journal_small.png (janela estreita)
--
-- A run mock tem histórico de DOIS atos pra exercitar os dois estados do
-- castelo de uma vez: ato 1 fechado (CONQUISTADO, portão aberto) e ato 2 em
-- andamento (silhueta + contador). Os dois primeiros nós entram SÓ no
-- mapHistory, sem entrada de journal — é o caminho de backfill das runs que
-- começaram antes desta feature ("Sem detalhes registrados").
--
-- O modo `small` roda num processo separado de propósito: a memória de
-- invariantes registra que chamadas repetidas de love.window.setMode dentro
-- de um tool TRAVAM. Um setMode por processo, e só pra janela MENOR.

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

-- Pega ids reais do catálogo pra não inventar carta que não existe (o
-- tooltip avisaria "carta fora do catálogo" e a captura mentiria).
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

-- mode: nil | "small"     locale: nil (pt_BR) | "en" | "es" | "fr" | "de"
-- O locale explícito existe pra VALIDAR A TRADUÇÃO: é em idioma estrangeiro
-- que o PT cravado aparece (a tela saía "AKT 1 — Catacumbas"). Capturar só em
-- pt_BR esconde exatamente o defeito que se quer pegar.
function M.run(mode, locale)
    _G.EventManager = require("engine.EventManager")
    _G.Event = require("engine.Event")
    local I18n = require("src.i18n.I18n")
    I18n.init()
    -- Locale FIXO na captura: o sandbox de ferramenta herda settings.tool.lua,
    -- que pode estar em qualquer idioma — a captura viraria alemão sem aviso.
    I18n.setLocale(locale or "pt_BR")
    require("src.ui.PixelCanvas").enableNearest()

    if mode == "small" then
        love.window.setMode(760, 560, { resizable = true })
    end

    local Game = require("src.core.Game")
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    _G.game = game

    local rm = game.runManager
    local run = rm.currentRun
    -- Zera o que startNewRun deixou (deck inicial anotou fora de nó — no-op).
    run.mapHistory, run.journal, run.journalOpen = {}, {}, nil

    local cards, jokers = pickIds()
    local c1 = cards[1] or "warrior_strike"
    local c2 = cards[2] or "warrior_defend"
    local c3 = cards[3] or c1
    local j1 = jokers[1]

    -- Dois nós SEM journal: só mapHistory (backfill / "sem detalhes").
    table.insert(run.mapHistory, { actNumber = 1, floorInAct = 1, type = "battle" })
    table.insert(run.mapHistory, { actNumber = 1, floorInAct = 2, type = "battle" })

    -- ===== ATO 1 — completo (andares 3..8) =====
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

    -- ===== ATO 2 — em andamento (andares 1..4) =====
    visit(rm, 2, 1, "battle", { hp = 40, maxHp = 60, gold = 68 },
        { hp = 33, gold = 85 }, { { kind = "card", id = c2 } })
    visit(rm, 2, 2, "elite", { hp = 33, maxHp = 60, gold = 85 },
        { hp = 18, gold = 112 }, { { kind = "card", id = c1 },
                                   { kind = "forge", id = c3, lvl = 2 } })
    visit(rm, 2, 3, "rest", { hp = 18, maxHp = 60, gold = 112 },
        { hp = 36, gold = 112 }, { { kind = "forge", id = c1, lvl = 2 } })
    -- Nó ATUAL: fica em aberto de propósito (aro pulsando + "você está aqui").
    visit(rm, 2, 4, "shop", { hp = 36, maxHp = 60, gold = 112 }, nil,
        { { kind = "card", id = c3 } })

    run.actNumber = 2
    run.floorInAct = 4

    local screen = require("components.RunJournalScreen"):new()
    screen:show(game)

    local dt = 1 / 30
    for _ = 1, 10 do screen:update(dt) end

    love.mouse.setPosition(-100, -100)   -- sem hover na visão geral
    love.graphics.clear(0, 0, 0, 1)
    screen:draw()
    local suffix = (locale and locale ~= "pt_BR") and ("_" .. locale) or ""
    capture(mode == "small" and ("run_journal_small" .. suffix .. ".png")
        or ("run_journal" .. suffix .. ".png"))

    if mode == "small" then
        love.event.quit()
        return
    end

    -- Hover no nó da loja do ato 1 (coringa + carta removida no mesmo nó):
    -- é o tooltip mais denso e o que valida o ancoramento.
    local L = screen:_layout()
    local target = L.bands[1] and L.bands[1].nodes[6]
    if target then
        love.mouse.setPosition(target.cx, target.cy)
    else
        print("[roteiro] AVISO: nó alvo do hover não encontrado")
    end
    for _ = 1, 4 do
        love.graphics.clear(0, 0, 0, 1)
        screen:draw()
    end
    love.graphics.clear(0, 0, 0, 1)
    screen:draw()
    capture("run_journal_hover" .. suffix .. ".png")

    love.event.quit()
end

return M
