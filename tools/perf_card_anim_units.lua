local M = {}
function M.run()
    require("tools.testkit").bootstrap()
    require("src.ui.PixelCanvas").enableNearest()
    local CardFrame = require("src.ui.CardFrame")
    local CardDatabase = require("src.systems.CardDatabase")
    local CardArt = require("src.ui.CardArt")
    local IFL = require("src.ui.IconFramesLoader")
    local db = CardDatabase:new()
    local animated = {}
    for _, cd in pairs(db:getAllCards()) do
        local art = CardArt.resolve(cd)
        if art.iconName and IFL.has(art.iconName) then animated[#animated + 1] = cd end
    end
    table.sort(animated, function(a, b) return a.id < b.id end)
    local T = love.timer.getTime
    local t0 = T(); local n = 0
    for i = 1, 20 do
        local art = CardArt.resolve(animated[i])
        IFL.clearCache()
        local h
        repeat h = IFL.getIncremental(art.iconName, 100) until h
        n = n + #h.frames
    end
    print(("[perf_card_anim_units] decode PNG: %.3f ms/frame (%d frames)"):format((T() - t0) * 1000 / n, n))
    local insts = {}
    for i = 1, 20 do insts[i] = db:createCardInstance(animated[i]) end
    t0 = T()
    for i = 1, 20 do CardFrame.invalidate(insts[i]); CardFrame.render(insts[i]) end
    print(("[perf_card_anim_units] render (camadas+compose): %.3f ms/carta"):format((T() - t0) * 1000 / 20))
    t0 = T()
    for i = 1, 20 do CardFrame._renderDirectForParity(insts[i]) end
    print(("[perf_card_anim_units] renderOne direto: %.3f ms/carta"):format((T() - t0) * 1000 / 20))
    IFL.clearCache()
    for i = 1, 20 do local art = CardArt.resolve(insts[i]); IFL.get(art.iconName) end
    t0 = T(); local frames = 0
    for i = 1, 20 do local a = CardFrame.getAnimation(insts[i]); frames = frames + #a.canvases - 1 end
    print(("[perf_card_anim_units] composeFrame: %.3f ms/frame (%d frames)"):format((T() - t0) * 1000 / frames, frames))
    love.graphics.present()
    CardFrame.clearCache()
    for i = 1, 20 do CardFrame.render(insts[i]) end
    love.graphics.present()
    t0 = T()
    for i = 1, 20 do CardFrame.getAnimation(insts[i]) end
    love.graphics.present()
    print(("[perf_card_anim_units] compose+present (GPU incluso): %.3f ms/frame"):format((T() - t0) * 1000 / frames))
    return true
end
return M
