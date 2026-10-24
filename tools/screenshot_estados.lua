local M = {}

M.IDS = { "abyss_acolyte", "frost_troll", "ember_imp", "pit_brute", "dusk_bat", "winter_monarch" }
M.STATES = {
    "none", "poison", "burn", "weak", "vulnerable", "strength", "enraged", "regen", "block", "veil",
    "poison+weak", "burn+enraged",
}
M.FRAMES = 12
M.STEP = 6

local function split(s, pat)
    local out = {}
    for w in s:gmatch(pat) do out[#out + 1] = w end
    return out
end

function M.run()
    local vw, vh = (os.getenv("VIDA_VIRTUAL") or "1920x1080"):match("^(%d+)x(%d+)$")
    vw, vh = tonumber(vw), tonumber(vh)
    local vcanvas = love.graphics.newCanvas(vw, vh)
    vcanvas:setFilter("nearest", "nearest")
    love.graphics.getWidth = function() return vw end
    love.graphics.getHeight = function() return vh end
    love.graphics.getDimensions = function() return vw, vh end

    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = os.getenv("ESTADOS_REDUCED") == "1"

    local Vida = require("tools.vida")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyLife = require("src.ui.EnemyLife")
    local ER = require("src.ui.EnemyRenderer")
    local list = Vida.roster()
    local ids = os.getenv("ESTADOS_IDS") and split(os.getenv("ESTADOS_IDS"), "[%w_]+") or M.IDS
    local states = os.getenv("ESTADOS_LIST") and split(os.getenv("ESTADOS_LIST"), "[%w_+]+") or M.STATES
    local tag = os.getenv("ESTADOS_TAG") or "depois"
    local root = "estados_v2/" .. tag
    love.filesystem.createDirectory(root)
    local meta = {}
    EnemyLife.enabled = false

    local function draw()
        love.graphics.setCanvas(vcanvas)
        love.graphics.clear(0, 0, 0, 1)
        GameplayScene.draw()
        love.graphics.setCanvas()
    end

    for _, st in ipairs(states) do
        local dir = root .. "/" .. st:gsub("%+", "-")
        love.filesystem.createDirectory(dir)
        for _, id in ipairs(ids) do
            local entry = list[Vida.indexOf(list, id) or 1]
            EnemyLife._rng:setSeed(0x51DE)
            Vida.mount(entry)
            EnemyLife.prewarmNow(id)
            local forced = {}
            if st ~= "none" then forced = split(st, "[%a_]+") end
            EnemyLife.States.force(forced)
            for _ = 1, 150 do Vida.step(1 / 60, entry); draw() end
            local foot = ER.getLastFoot()
            local ux = foot.ux or 1
            local bx = (foot.tx or 0) + foot.drawX * ux
            local by = (foot.ty or 0) + foot.drawY * (foot.uy or 1)
            local bw, bh = foot.iw * foot.scale * ux, foot.ih * foot.scale * (foot.uy or 1)
            local m = 60
            local cx0 = math.max(0, math.floor(bx - m))
            local cy0 = math.max(0, math.floor(by - m))
            local cw = math.min(vw - cx0, math.floor(bw + 2 * m))
            local ch = math.min(vh - cy0, math.floor(bh + 2 * m))
            for f = 0, M.FRAMES - 1 do
                for _ = 1, M.STEP do Vida.step(1 / 60, entry); draw() end
                local img = vcanvas:newImageData()
                if f == 0 and st == states[1] then img:encode("png", dir .. "/" .. id .. "_full.png") end
                local crop = love.image.newImageData(cw, ch)
                crop:paste(img, 0, 0, cx0, cy0, cw, ch)
                img:release()
                crop:encode("png", string.format("%s/%s_%02d.png", dir, id, f))
                crop:release()
            end
            collectgarbage("collect")
            meta[#meta + 1] = string.format("%s %s %d %d %d %d %d %d %d %d %d", st, id, cx0, cy0, cw, ch,
                math.floor(bx - cx0), math.floor(by - cy0), math.floor(bw), math.floor(bh), EnemyLife.liveCount())
            EnemyLife.States.force(nil)
        end
        print("[estados] " .. tag .. " " .. st .. " -> " .. dir)
    end
    EnemyLife.enabled = true
    love.filesystem.write(root .. "/meta.txt", table.concat(meta, "\n") .. "\n")
    print("[estados] meta -> " .. love.filesystem.getSaveDirectory() .. "/" .. root .. "/meta.txt")
    love.event.quit()
    return true
end

return M
