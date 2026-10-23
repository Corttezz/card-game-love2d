local M = {}

M.VW, M.VH = 1920, 1080

function M.run(arg)
    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()
    require("src.systems.ScreenShake").install()
    local o = { love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions }
    love.graphics.getWidth = function() return M.VW end
    love.graphics.getHeight = function() return M.VH end
    love.graphics.getDimensions = function() return M.VW, M.VH end
    local CRT = require("src.ui.CRTShader")
    CRT.load()
    CRT.setEnabled(true)
    CRT.setPower(1, 1)
    local tag = arg or "depois"
    local Entradas = require("tools.entradas")
    local GameplayScene = require("src.scenes.GameplayScene")
    local WorldRoad = require("src.ui.WorldRoad")
    local ER = require("src.ui.EnemyRenderer")
    local EE = require("src.ui.EnemyEntrance")
    local cv = love.graphics.newCanvas(M.VW, M.VH)
    local function shot()
        local wo = GameplayScene.WORLD_ONLY
        GameplayScene.WORLD_ONLY = true
        CRT.beginScene()
        love.graphics.clear(0, 0, 0, 1)
        GameplayScene.draw()
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        CRT.endScene(cv)
        love.graphics.setCanvas()
        GameplayScene.WORLD_ONLY = wo
        return cv:newImageData()
    end
    local DT = 1 / 30
    local list = Entradas.roster()
    for _, id in ipairs({ "fallen_angel", "ember_imp" }) do
        for _, phase in ipairs({ "entrada", "batalha" }) do
            local ctx = Entradas.mount(list[Entradas.indexOf(list, id)], { dt = DT, tod = 0.85 })
            Entradas.startEntrance(ctx, DT)
            local foot = nil
            for _ = 1, 700 do
                GameplayScene.update(DT)
                local tr, S = WorldRoad._travel, EE.state()
                if S and S.footX then foot = { S.footX, S.footY } end
                if phase == "entrada" and tr and S and tr.t >= tr.duration + (tr.settle or 0) - 0.4 then break end
                if not WorldRoad.isTraveling() then break end
            end
            if phase == "batalha" then
                for _ = 1, 60 do GameplayScene.update(DT) end
                local lf = ER.getLastFoot()
                if lf then foot = { lf.hudCx or lf.bodyX, lf.groundY } end
            end
            shot():release()
            local d = shot()
            local W, H = 420, 380
            local x0 = math.max(0, math.min(M.VW - W, math.floor((foot and foot[1] or M.VW / 2) - W / 2)))
            local y0 = math.max(0, math.min(M.VH - H, math.floor((foot and foot[2] or M.VH * 0.6) - H + 20)))
            local out = love.image.newImageData(W, H)
            out:paste(d, 0, 0, x0, y0, W, H)
            out:encode("png", string.format("halo_%s_%s_%s.png", id, phase, tag))
            out:release()
            d:release()
        end
    end
    cv:release()
    love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = o[1], o[2], o[3]
    return true
end

return M
