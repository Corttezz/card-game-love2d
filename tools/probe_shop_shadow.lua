-- tools/probe_shop_shadow.lua
-- Sonda: quantos pontos a sombra de contato do PACOTE desenha em repouso e
-- levantado (hover). love . test_one probe_shop_shadow
local M = {}
function M.run()
    local TK = require("tools.testkit")
    TK.bootstrap()
    require("src.i18n.I18n").init()
    local rw, rh = love.graphics.getWidth, love.graphics.getHeight
    love.graphics.getWidth = function() return 1280 end
    love.graphics.getHeight = function() return 720 end
    local realMouse = love.mouse.getPosition
    local mx, my = 5, 5
    love.mouse.getPosition = function() return mx, my end
    local EM = require("engine.EventManager")
    local game = TK.newRunGame("warrior")
    game.economySystem.currentGold = 60
    local screen = require("components.CardRewardScreen"):new(game.shopSystem)
    screen:show(game, function() end, function() end, "shop")
    local function pump(secs) for _ = 1, math.floor(secs * 60) do EM.update(1 / 60); screen:update(1 / 60) end end
    pump(1.5)
    local pack
    for _, it in ipairs(screen.scene.items) do if it.kind == "pack" then pack = it end end
    local SP = require("src.ui.shop.ShopPerspective")
    local realPts = love.graphics.points
    local count = 0
    love.graphics.points = function(p) count = count + (type(p) == "table" and #p or 1) return realPts(p) end
    local L = screen.scene.L
    local o = pack:uprightParams(L, false, 0)
    SP.drawContactShadow(o, L.art.tableMask, 1)
    print(("[probe] repouso: lift=%.2f pontos=%d"):format(o.lift or 0, count))
    mx, my = pack:center()
    pump(0.6)
    count = 0
    o = pack:uprightParams(L, false, 0)
    SP.drawContactShadow(o, L.art.tableMask, 1)
    print(("[probe] hover: liftPx=%.2f lift(arte)=%.2f pontos=%d fy=%.1f"):format(pack:liftPx(), o.lift or 0, count, o.fy))
    love.graphics.points = realPts
    love.mouse.getPosition = realMouse
    love.graphics.getWidth, love.graphics.getHeight = rw, rh
    return true
end
return M
