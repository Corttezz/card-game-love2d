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

    -- ===== Eventos de BIOMA (Out/2026): só aparecem no cenário deles =====
    local biomeEvents, biomeByAct, leaks = 0, {}, 0
    for _, e in ipairs(Events.POOL) do
        if e.biomes then
            biomeEvents = biomeEvents + 1
            for _, b in ipairs(e.biomes) do biomeByAct[b] = (biomeByAct[b] or 0) + 1 end
        end
    end
    t:truthy("12+ eventos de bioma", biomeEvents >= 12)
    local everyBiome = true
    for b = 1, 6 do if (biomeByAct[b] or 0) < 2 then everyBiome = false end end
    t:truthy("todo bioma (1-6) tem 2+ eventos próprios", everyBiome)
    for b = 1, 6 do
        TK.seedRng(500 + b)
        for _ = 1, 60 do
            local e = Events.roll(b, {}, b)
            if e and e.biomes and not Events.fitsHere(e, b, b) then leaks = leaks + 1 end
        end
    end
    t:eq("evento de bioma nunca sai fora do bioma", leaks, 0)
    -- endless: ato 9 desenhando o bioma 4 -> eventos do gelo podem sair, os do
    -- campo (bioma 1) nao
    TK.seedRng(77)
    local frostSeen, fieldSeen = false, false
    for _ = 1, 200 do
        local e = Events.roll(9, {}, 4)
        if e and e.biomes then
            if e.biomes[1] == 4 then frostSeen = true end
            if e.biomes[1] == 1 then fieldSeen = true end
        end
    end
    t:truthy("endless no gelo sorteia evento do gelo", frostSeen)
    t:falsy("endless no gelo nunca sorteia evento do campo", fieldSeen)

    -- Todo evento tem ilustração e texto nos 5 idiomas.
    local I18n = require("src.i18n.I18n")
    local noArt, noText = {}, {}
    for _, e in ipairs(Events.POOL) do
        if not love.filesystem.getInfo("assets/sprites/ui/event_" .. e.id .. ".png") then
            noArt[#noArt + 1] = e.id
        end
        for _, loc in ipairs({ "pt_BR", "en", "es", "fr", "de" }) do
            local data = require("src.i18n.locales." .. loc)
            local ev = data.events and data.events[e.id]
            local ok = ev and ev.title and ev.body
            for i = 1, #e.options do ok = ok and ev["opt" .. i] end
            if not ok then noText[#noText + 1] = loc .. ":" .. e.id end
        end
    end
    t:eq("todo evento de bioma tem ilustração", (function()
        local out = {}
        for _, id in ipairs(noArt) do
            local ev = findEvent(id)
            if ev and ev.biomes then out[#out + 1] = id end
        end
        return table.concat(out, ",")
    end)(), "")
    t:eq("todo evento tem título/corpo/opções nos 5 idiomas", table.concat(noText, ","), "")

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

    -- ===== Os FloatingText de ganho/custo (regressao Set/2026) =====
    -- `gains`/`costs` sao DESCRITORES { k, n, fb }, nao strings. A migracao de
    -- i18n atualizou o rotulo do botao e esqueceu o `_spawnDeltas`, que
    -- concatenava a tabela: "attempt to concatenate upvalue 'txt' (a table
    -- value)" ao escolher qualquer opcao com ganho ou custo. Chegou como crash
    -- na cara do dono porque a trava existente (check_event_i18n) mede o
    -- ROTULO, e este caminho nao tinha cobertura nenhuma.
    --
    -- O crash mora DENTRO do callback agendado, entao nao basta chamar: e
    -- preciso BOMBEAR a fila. Um teste que so chamasse passaria em verde com o
    -- bug presente.
    local EventScreen = require("components.EventScreen")
    local FloatingText = require("src.ui.FloatingText")
    local EM = _G.EventManager

    local spawned, badArg = 0, 0
    local origSpawn = FloatingText.spawn
    FloatingText.spawn = function(texto, ...)
        if type(texto) ~= "string" then badArg = badArg + 1 end
        spawned = spawned + 1
    end

    local screen = setmetatable({ game = TK.newRunGame("warrior") }, { __index = EventScreen })
    local deltaCrashes, comDelta = 0, 0
    for _, e in ipairs(Events.POOL) do
        for _, opt in ipairs(e.options or {}) do
            if opt.gains or opt.costs then
                comDelta = comDelta + 1
                local ok, err = pcall(EventScreen._spawnDeltas, screen, opt, 100, 100)
                if not ok then
                    deltaCrashes = deltaCrashes + 1
                    if deltaCrashes <= 2 then
                        print("     CRASH ao agendar delta de " .. tostring(e.id) .. ": " .. tostring(err))
                    end
                end
            end
        end
    end
    -- Aqui o bug aparece: os callbacks so rodam no update.
    for _ = 1, 40 do
        local okPump, errPump = pcall(EM.update, 0.05)
        if not okPump then
            deltaCrashes = deltaCrashes + 1
            if deltaCrashes <= 3 then print("     CRASH no callback: " .. tostring(errPump)) end
        end
    end
    FloatingText.spawn = origSpawn

    t:truthy("ha opcoes com ganho/custo pra testar", comDelta > 10)
    t:eq("nenhum delta de evento crasha", deltaCrashes, 0)
    t:eq("todo FloatingText recebe STRING, nunca descritor", badArg, 0)
    t:truthy("os deltas realmente dispararam", spawned > 0)

    -- ===== Mecânicas novas dos eventos de bioma =====
    do
        TK.seedRng(4040)
        local g3 = TK.newRunGame("warrior")
        local run = g3.runManager.currentRun
        for _ = 1, 4 do g3:addCardToRun("warrior_strike") end
        local before = #run.currentDeck
        local corvo = findEvent("corvo_mensageiro")
        corvo.options[1].apply(g3)   -- transforma 2
        t:eq("transformar mantém o tamanho do deck", #run.currentDeck, before)

        local pacto = findEvent("pacto_infernal")
        local jokersBefore = #(run.jokers or {})
        local maxBefore = g3.player.maxHealth
        pacto.options[1].apply(g3)
        t:eq("pacto infernal dá 1 coringa", #(run.jokers or {}), jokersBefore + 1)
        t:eq("pacto infernal cobra 10 de vida máxima", g3.player.maxHealth, maxBefore - 10)

        g3.player.maxHealth = 25
        g3.player.health = 25
        t:falsy("custo de vida máxima que levaria abaixo de 20 desabilita a opção",
            Events.canAfford(pacto.options[1], g3))
    end

    return t:done()
end

return M
