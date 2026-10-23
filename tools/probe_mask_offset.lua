local M = {}

function M.run(arg)
    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()
    require("src.systems.ScreenShake").install()
    local Halo = require("tools.probe_enemy_halo")
    local VW, VH = 1920, 1080
    local o = { love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions }
    love.graphics.getWidth = function() return VW end
    love.graphics.getHeight = function() return VH end
    love.graphics.getDimensions = function() return VW, VH end
    local id = arg or "fallen_angel"
    local Entradas = require("tools.entradas")
    local GameplayScene = require("src.scenes.GameplayScene")
    local WorldRoad = require("src.ui.WorldRoad")
    local ER = require("src.ui.EnemyRenderer")
    local LE = require("engine.LightEngine")
    local SA = require("src.ui.SpriteAnimation")
    local list = Entradas.roster()
    local DT = 1 / 30
    local ctx = Entradas.mount(list[Entradas.indexOf(list, id)], { dt = DT })
    Entradas.startEntrance(ctx, DT)
    for _ = 1, 700 do
        GameplayScene.update(DT)
        if not WorldRoad.isTraveling() then break end
    end
    for _ = 1, 60 do GameplayScene.update(DT) end
    local cv = love.graphics.newCanvas(VW, VH)
    love.graphics.setCanvas(cv)
    GameplayScene.draw()
    love.graphics.setCanvas()
    local mc = LE._maskCanvas()
    local md = mc and mc:newImageData()
    local lf = ER.getLastFoot()
    local fps, opts = ER._idleSpec(id)
    local anim = SA.new(id, "idle", "south", fps, opts)
    local img = anim.frames[lf.frame or 1]
    local mask, x0, y0, W, H = Halo.silhouette(img, lf.drawX, lf.drawY, lf.scale, { lf.tx, lf.ty, lf.ux, lf.uy })
    local sx1, sy1, sx2, sy2 = 1e9, 1e9, -1, -1
    for k in pairs(mask) do
        local x, y = k % VW, math.floor(k / VW)
        sx1, sy1, sx2, sy2 = math.min(sx1, x), math.min(sy1, y), math.max(sx2, x), math.max(sy2, y)
    end
    local mx1, my1, mx2, my2 = 1e9, 1e9, -1, -1
    local mw, mh = md:getWidth(), md:getHeight()
    for y = math.max(0, y0 - 40), math.min(mh - 1, y0 + H + 40) do
        for x = math.max(0, x0 - 40), math.min(mw - 1, x0 + W + 40) do
            local _, _, _, a = md:getPixel(x, y)
            if a >= 0.5 then
                mx1, my1, mx2, my2 = math.min(mx1, x), math.min(my1, y), math.max(mx2, x), math.max(my2, y)
            end
        end
    end
    print(string.format("transform %.3f,%.3f x%.3f,%.3f", lf.tx, lf.ty, lf.ux, lf.uy))
    print(string.format("mask canvas %dx%d  sprite bbox %d,%d-%d,%d  mask bbox %d,%d-%d,%d  dx1=%d dy1=%d dx2=%d dy2=%d",
        mw, mh, sx1, sy1, sx2, sy2, mx1, my1, mx2, my2, mx1 - sx1, my1 - sy1, mx2 - sx2, my2 - sy2))
    md:release()
    cv:release()
    love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = o[1], o[2], o[3]
    return true
end

return M
