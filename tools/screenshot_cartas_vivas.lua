local M = {}

local function capture(name)
    local data
    love.graphics.captureScreenshot(function(id) data = id end)
    love.graphics.present()
    if data then data:encode("png", name) end
    return data
end

local function diff(a, b, name)
    local w, h = a:getWidth(), a:getHeight()
    local out = love.image.newImageData(w, h)
    local n = 0
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local r1, g1, b1 = a:getPixel(x, y)
            local r2, g2, b2 = b:getPixel(x, y)
            local d = math.max(math.abs(r1 - r2), math.abs(g1 - g2), math.abs(b1 - b2))
            if d > 2 / 255 then
                n = n + 1
                out:setPixel(x, y, 1, 1, 1, 1)
            else
                out:setPixel(x, y, 0.08, 0.08, 0.08, 1)
            end
        end
    end
    out:encode("png", name)
    return n, w * h
end

function M.run()
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()
    local CardFrame = require("src.ui.CardFrame")
    local CardDatabase = require("src.systems.CardDatabase")
    local CardArt = require("src.ui.CardArt")
    local IFL = require("src.ui.IconFramesLoader")
    local UnlockSystem = require("src.systems.UnlockSystem")
    if UnlockSystem.setRevealAll then UnlockSystem.setRevealAll(true) end
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = false

    local realGetTime = love.timer.getTime
    local realMouse = love.mouse.getPosition
    local simNow = 2000
    love.timer.getTime = function() return simNow end
    love.mouse.getPosition = function() return 3, 3 end
    local W, H = love.graphics.getDimensions()
    local report = {}
    local function log(s) print("[cartas_vivas] " .. s); report[#report + 1] = s end

    local function warm(update, draw, frames)
        for _ = 1, frames do
            simNow = simNow + 1 / 60
            CardFrame.update()
            update(1 / 60)
            love.graphics.clear(0, 0, 0, 1)
            draw()
        end
    end
    local function shoot(cena, update, draw, dt)
        love.graphics.clear(0, 0, 0, 1); draw()
        local a = capture("cartas_vivas_" .. cena .. "_t1.png")
        simNow = simNow + (dt or 0.25)
        CardFrame.update()
        update(0)
        love.graphics.clear(0, 0, 0, 1); draw()
        local b = capture("cartas_vivas_" .. cena .. "_t2.png")
        local n, total = diff(a, b, "cartas_vivas_" .. cena .. "_diff.png")
        log(("%-16s pixels diferentes entre t1 e t2 (sem hover): %d de %d (%.2f%%)  vivas=%d")
            :format(cena, n, total, 100 * n / total, CardFrame._liveCount()))
        return n
    end

    local ok, err = pcall(function()
        local CollectionScreen = require("components.CollectionScreen")
        local col = CollectionScreen:new()
        col:show(function() end)
        for _ = 1, 400 do
            if col._buildDone then break end
            col:_buildInstances(1)
        end
        col:_applyFilter()
        local upd = function(dt) col:update(dt) end
        local drw = function() col:draw() end
        warm(upd, drw, 90)
        local nCol = shoot("colecao", upd, drw)

        _G.gameSettings.reducedMotion = true
        warm(upd, drw, 5)
        local nRed = shoot("colecao_reduzido", upd, drw)
        _G.gameSettings.reducedMotion = false
        if col.hide then pcall(col.hide, col) end

        local db = CardDatabase:new()
        local animated = {}
        for _, cd in pairs(db:getAllCards()) do
            local art = CardArt.resolve(cd)
            if art.iconName and IFL.has(art.iconName) and cd.type ~= "joker" then
                animated[#animated + 1] = cd
            end
        end
        table.sort(animated, function(a, b) return a.id < b.id end)
        local row = {}
        for i = 1, 6 do
            local inst = db:createCardInstance(animated[i * 7])
            inst.isHovered, inst.isSelected = false, false
            row[i] = inst
        end
        local function drawRow()
            love.graphics.setColor(0.10, 0.08, 0.06, 1)
            love.graphics.rectangle("fill", 0, 0, W, H)
            love.graphics.setColor(1, 1, 1, 1)
            for i, inst in ipairs(row) do
                inst:draw(40 + (i - 1) * 160, H / 2 - 100, false, false)
            end
        end
        warm(function() end, drawRow, 60)
        local nRow = shoot("mao_carddraw", function() end, drawRow, 2 * math.pi / 0.666)

        local Game = require("src.core.Game")
        local game = Game:new()
        game:startNewRun("mage")
        game:startGame()
        _G.game = game

        local DeckViewerScreen = require("components.DeckViewerScreen")
        local dv = DeckViewerScreen:new()
        dv:show(game)
        local updDv = function(dt) if dv.update then dv:update(dt) end end
        local drwDv = function() dv:draw() end
        warm(updDv, drwDv, 60)
        local nDv = shoot("deck_viewer", updDv, drwDv)
        dv:hide()

        local CardRewardScreen = require("components.CardRewardScreen")
        local rw = CardRewardScreen:new(game.shopSystem)
        rw.lastScreenWidth, rw.lastScreenHeight = W, H
        rw:show(game, function() end, function() end, "rewards")
        local updRw = function(dt)
            _G.EventManager.update(dt)
            rw:update(dt)
        end
        local drwRw = function()
            love.graphics.setColor(0.16, 0.12, 0.08, 1)
            love.graphics.rectangle("fill", 0, 0, W, H)
            love.graphics.setColor(1, 1, 1, 1)
            rw:draw()
        end
        warm(updRw, drwRw, 120)
        local nRw = shoot("espolios", updRw, drwRw)

        log(("RESUMO: colecao=%d deck_viewer=%d mao_carddraw=%d espolios=%d | reducedMotion colecao=%d (esperado 0)")
            :format(nCol, nDv, nRow, nRw, nRed))
        log((nCol > 0 and nDv > 0 and nRow > 0 and nRw > 0 and nRed == 0)
            and "VEREDITO: cartas vivas sem hover em todas as cenas; estaticas com reducedMotion"
            or "VEREDITO: FALHOU (alguma cena nao animou, ou reducedMotion animou)")
    end)

    love.timer.getTime = realGetTime
    love.mouse.getPosition = realMouse
    if UnlockSystem.setRevealAll then UnlockSystem.setRevealAll(false) end
    love.filesystem.write("cartas_vivas_relatorio.txt", table.concat(report, "\n") .. "\n")
    if not ok then
        print("[cartas_vivas] ERRO: " .. tostring(err))
        return false
    end
    print("[cartas_vivas] salvo em " .. love.filesystem.getSaveDirectory())
    return true
end

return M
