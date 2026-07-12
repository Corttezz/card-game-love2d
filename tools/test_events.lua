-- tools/test_events.lua
-- Eventos narrativos (src/data/events.lua): Events.roll (determinismo + no-repeat
-- por ato via stream "event"), integridade do catálogo, e um PROPERTY TEST que
-- aplica TODA opção de TODO evento sem crashar. + efeito numérico do Altar.
--   love . test_events

local TK = require("tools.testkit")
local Events = require("src.data.events")

local M = {}

local function findEvent(id)
    for _, e in ipairs(Events.POOL) do
        if e.id == id then return e end
    end
    return nil
end

function M.run()
    TK.bootstrap()
    local t = TK.new("eventos: Events + escolhas")

    -- ===== Integridade do catálogo =====
    t:truthy("POOL não vazio", #Events.POOL > 0)
    local badEvent = 0
    for _, e in ipairs(Events.POOL) do
        if not (e.id and e.title and e.options and #e.options > 0) then badEvent = badEvent + 1 end
        for _, o in ipairs(e.options or {}) do
            if type(o.apply) ~= "function" or type(o.label) ~= "string" then badEvent = badEvent + 1 end
        end
    end
    t:eq("todo evento tem id/title/options e toda opção tem apply+label", badEvent, 0)

    -- ===== Events.roll: determinismo por seed =====
    TK.seedRng(1000)
    local a = Events.roll(1, {})
    TK.seedRng(1000)
    local b = Events.roll(1, {})
    t:truthy("roll retorna evento", a ~= nil)
    t:truthy("mesma seed -> mesmo evento", a and b and a.id == b.id)
    t:truthy("evento rolado tem options", a and a.options and #a.options > 0)

    -- ===== Events.roll: no-repeat por ato =====
    TK.seedRng(2024)
    local hist, seen, dup = {}, {}, false
    local rolls = 0
    for _ = 1, 8 do
        local e = Events.roll(1, hist)
        if not e then break end
        if seen[e.id] then dup = true end
        seen[e.id] = true
        hist[e.id] = 1  -- marca visto neste ato (como main.lua faz)
        rolls = rolls + 1
    end
    t:truthy("rolou vários eventos distintos", rolls >= 5)
    t:falsy("nenhuma repetição enquanto pool não esgota", dup)

    -- ===== PROPERTY: toda opção de todo evento aplica sem crashar =====
    -- Stub do card picker: no jogo real é a UI (RestScreen); headless não tem
    -- UI, então stubamos para exercitar a delegação (escriba/espelho/forja).
    local pickerCalls = 0
    local origPicker = _G.openCardPicker
    _G.openCardPicker = function(_mode, onDone)
        pickerCalls = pickerCalls + 1
        if onDone then onDone() end
    end

    local g = TK.newRunGame("warrior")
    local crashes, applied, feedbacks = 0, 0, 0
    for _, e in ipairs(Events.POOL) do
        for _, opt in ipairs(e.options) do
            -- topa recursos pra exercitar os ramos "pode pagar"
            g.economySystem.currentGold = 999
            g.player.health = g.player.maxHealth
            g.player.mana = g.player.maxMana
            local ok, res = pcall(opt.apply, g)
            applied = applied + 1
            if not ok then
                crashes = crashes + 1
                print("     CRASH em " .. e.id .. " / '" .. opt.label .. "': " .. tostring(res))
            elseif type(res) == "string" then
                feedbacks = feedbacks + 1
            end
        end
    end
    _G.openCardPicker = origPicker  -- restaura

    t:truthy("aplicou várias opções (>20)", applied > 20)
    t:eq("nenhuma opção de evento crasha", crashes, 0)
    t:truthy("maioria das opções dá feedback textual", feedbacks >= applied / 2)
    t:truthy("eventos de picker delegam ao openCardPicker", pickerCalls >= 3)

    -- ===== Efeito numérico: Altar Proibido (sacrifício = -8 HP) =====
    local altar = findEvent("altar_proibido")
    if altar then
        local g2 = TK.newRunGame("warrior")
        g2.player.health = g2.player.maxHealth
        local before = g2.player.health
        -- opção 1 = sacrificar sangue (custo 8 HP)
        pcall(altar.options[1].apply, g2)
        t:eq("Altar/sacrificar custa 8 HP", g2.player.health, before - 8)
    else
        t:truthy("evento altar_proibido existe", false)
    end

    return t:done()
end

return M
