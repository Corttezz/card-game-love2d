local TK = require("tools.testkit")
local M = {}

local function synth(w, h, fn)
    local d = love.image.newImageData(w, h)
    d:mapPixel(function(x, y)
        if fn(x, y) then return 0.5, 0.3, 0.2, 1 end
        return 0, 0, 0, 0
    end)
    local img = love.graphics.newImage(d)
    img:setFilter("nearest", "nearest")
    return img, d
end

local function loadWorld(key)
    local path = "assets/sprites/world/" .. key .. ".png"
    local d = love.image.newImageData(path)
    local img = love.graphics.newImage(d)
    img:setFilter("nearest", "nearest")
    return img, d
end

local function render(fn)
    local W, H = love.graphics.getDimensions()
    local cv = love.graphics.newCanvas(W, H)
    love.graphics.setCanvas(cv)
    love.graphics.clear(0.5, 0.5, 0.5, 1)
    love.graphics.setColor(1, 1, 1, 1)
    fn()
    love.graphics.setCanvas()
    return cv:newImageData()
end

local function lumaAt(id, x, y)
    local r, g, b = id:getPixel(x, y)
    return 0.299 * r + 0.587 * g + 0.114 * b
end

function M.run()
    local t = TK.new("ContactShadow: faixa de contato colada na pegada; terra queimada só na fogueira")
    local CS = require("engine.ContactShadow")
    local SceneGrade = require("engine.SceneGrade")
    local DATA = require("src.data.scene_integration")
    local savedSettings = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }

    do
        local img, d = synth(8, 6, function(x, y)
            if x >= 3 and x <= 4 then return y >= 1 and y <= 2 end
            return y >= 1
        end)
        local fp = CS.scan(img, d)
        t:truthy("scan: devolve pegada", fp ~= nil)
        t:eq("scan: linha de contato = última linha", fp and fp.bottom, 5)
        t:eq("scan: dois vãos de contato", fp and #fp.spans, 2)
        t:truthy("scan: colunas 0..2 e 5..7 tocam o chão (3..4 no ar)",
            fp and fp.spans[1][1] == 0 and fp.spans[1][2] == 2
            and fp.spans[2][1] == 5 and fp.spans[2][2] == 7)
        t:truthy("scan: cache por imagem (mesma tabela)", CS.scan(img, d) == fp)
        t:truthy("footprint(img) = scan", CS.footprint(img) == fp)
    end

    do
        local keys = { "fields_rock_0", "fields_tree_0", "landmark_rest", "landmark_shop",
                       "landmark_battle", "landmark_event", "landmark_elite", "landmark_chest" }
        for _, f in ipairs(love.filesystem.getDirectoryItems("assets/sprites/world")) do
            local k = f:match("^(%a+_landmark_%a+)%.png$")
            if k then keys[#keys + 1] = k end
        end
        for _, key in ipairs(keys) do
            local img, d = loadWorld(key)
            local fp = CS.scan(img, d)
            if t:truthy(key .. ": pegada medida", fp ~= nil and #fp.spans > 0) then
                local okSpan = true
                for _, sp in ipairs(fp.spans) do
                    if sp[1] > sp[2] or sp[1] < 0 or sp[2] >= fp.w then okSpan = false end
                end
                t:truthy(key .. ": vãos dentro da imagem e ordenados", okSpan)
            end
        end
    end

    local cfg = DATA.fields.contact
    local W, H = love.graphics.getDimensions()
    local FX, FY = math.floor(W * 0.5), math.floor(H * 0.6)

    do
        local img, d = loadWorld("landmark_rest")
        local fp = CS.scan(img, d)
        local s = 3
        local id = render(function()
            CS.setFrame(cfg, 0.36, 0.22, 0.46)
            t:truthy("queue aceita imagem com pegada", CS.queue(img, FX, FY, s, 0.8, 1, 1))
            t:eq("queued() conta a fila", CS.queued(), 1)
            CS.flush()
            t:eq("flush esvazia a fila", CS.queued(), 0)
        end)
        local ground = lumaAt(id, 4, 4)
        local gaps, dark = 0, 0
        for _, sp in ipairs(fp.spans) do
            for col = sp[1], sp[2] do
                local sx = math.floor(FX + (col + 0.5 - fp.w / 2) * s)
                if lumaAt(id, sx, FY) < ground - 0.02 then dark = dark + 1 else gaps = gaps + 1 end
            end
        end
        t:eq("faixa de contato: toda coluna de contato escurecida (vãos = 0)", gaps, 0)
        t:truthy("faixa de contato: escureceu alguma coisa", dark > 0)
        local farX = math.floor(FX + (fp.w / 2 + 12) * s)
        t:truthy("fora da pegada o chão fica intacto", math.abs(lumaAt(id, farX, FY) - ground) < 0.005)
        local above = lumaAt(id, math.floor(FX + (fp.spans[1][1] + 0.5 - fp.w / 2) * s), FY - 2)
        t:truthy("faixa não sobe acima do contato", math.abs(above - ground) < 0.005)
        local hpx = math.max(1, math.floor(cfg.height * fp.w * s * (0.55 + 0.45 * 0.8) + 0.5))
        local below = lumaAt(id, math.floor(FX + (fp.spans[1][1] + 0.5 - fp.w / 2) * s), FY + 2 * hpx + 2)
        t:truthy("faixa é curta (acabou a 2× a altura)", math.abs(below - ground) < 0.005)
    end

    do
        local img, d = loadWorld("fields_tree_0")
        local fp = CS.scan(img, d)
        local id = render(function()
            CS.setFrame(cfg, 0.36, 0.22, 0.46)
            CS.queue(img, FX, FY, 0.35, 0.2, 1, 1)
            CS.flush()
        end)
        local sp = fp.spans[1]
        local px = math.floor(FX + ((sp[1] + sp[2] + 1) * 0.5 - fp.w / 2) * 0.35)
        local darkest = 1
        for dx = -1, 1 do darkest = math.min(darkest, lumaAt(id, px + dx, FY)) end
        t:truthy("escala mínima: faixa ≥ 1 px", darkest < lumaAt(id, 4, 4) - 0.01)
    end

    do
        local img = love.graphics.newImage(love.image.newImageData(4, 4))
        local Debug = require("src.core.Debug")
        local warns = 0
        local realWarn = Debug.warn
        Debug.warn = function() warns = warns + 1 end
        local okQ, res = pcall(CS.queue, img, FX, FY, 2, 0.5, 1, 1)
        local okQ2 = pcall(CS.queue, img, FX, FY, 2, 0.5, 1, 1)
        Debug.warn = realWarn
        t:truthy("imagem sem pegada: no-op avisado", okQ and okQ2 and res == false and warns == 1)
        CS.flush()
    end

    do
        local id = render(function()
            CS.setFrame(cfg, 0.36, 0.22, 0.46)
            CS.scorch(FX, FY, 120, 0.8, 1.35, 0.5)
        end)
        local ground = lumaAt(id, 4, 4)
        t:truthy("scorch: centro escurecido", lumaAt(id, FX, FY) < ground - 0.02)
        t:truthy("scorch: cabe no raio (fora = chão)", math.abs(lumaAt(id, FX + 120, FY) - ground) < 0.005)
        t:truthy("scorch: achatado (acima de 0,5 raio em y = chão)",
            math.abs(lumaAt(id, FX, FY - 60) - ground) < 0.005)
    end

    do
        local WorldRoad = require("src.ui.WorldRoad")
        local function frameWith(key)
            WorldRoad.clearCache()
            WorldRoad.resetRun()
            WorldRoad.setBiome(1)
            WorldRoad._camZ = 5.5
            for _ = 1, 10 do WorldRoad.update(1 / 30) end
            WorldRoad._blend = nil
            WorldRoad._prevBiomeIndex = nil
            WorldRoad._landmark = { key = key, z = WorldRoad._camZ + 9, size = 3.6, phase = 0 }
            CS.stats.scorch, CS.stats.contacts = 0, 0
            local cv = love.graphics.newCanvas(W, H)
            love.graphics.setCanvas(cv)
            love.graphics.clear(0, 0, 0, 1)
            WorldRoad.draw(0, 52, W, H - 52, 1)
            WorldRoad.drawOverlays(0, 52, W, H - 52)
            love.graphics.setCanvas()
            return CS.stats.scorch, CS.stats.contacts
        end
        local sc1, c1 = frameWith("landmark_rest")
        local sc2, c2 = frameWith("landmark_battle")
        t:eq("cena: fogueira desenha terra queimada", sc1, 1)
        t:eq("cena: bandeira não desenha terra queimada", sc2, 0)
        t:truthy("cena: props e marco enfileiram contato (" .. c1 .. ")", c1 >= 10 and c2 >= 10)
        WorldRoad._landmark = nil
        WorldRoad.clearCache()
        WorldRoad.resetRun()
    end

    do
        local img, d = loadWorld("fields_rock_0")
        CS.scan(img, d)
        CS.setFrame(cfg, 0.36, 0.22, 0.46)
        for _ = 1, 3 do CS.queue(img, FX, FY, 2, 0.5, 1, 1) end
        CS.flush()
        collectgarbage("collect")
        collectgarbage("stop")
        local k0 = collectgarbage("count")
        for _ = 1, 50 do
            for _ = 1, 40 do CS.queue(img, FX, FY, 2, 0.5, 1, 1) end
            CS.flush()
        end
        local perKB = (collectgarbage("count") - k0) / 50
        collectgarbage("restart")
        t:truthy(string.format("fila sem lixo por quadro (%.2f KB ≤ 1)", perKB), perKB <= 1)
    end

    do
        local src = love.filesystem.read("src/ui/WorldRoad.lua") or ""
        t:truthy("WorldRoad: ContactShadow.flush logo após ShadowEngine.flush",
            src:find("ShadowEngine%.flush%(%)%s*\n%s*Scene%.Contact%.flush%(%)") ~= nil)
        t:truthy("WorldRoad: scan no tryLoadPng e no toImage",
            select(2, src:gsub("Scene%.Contact%.scan%(img, data%)", "")) >= 2)
        t:truthy("WorldRoad: scan nos quadros de animação",
            src:find("Scene.Contact.scan(im, data)", 1, true) ~= nil)
        t:falsy("WorldRoad sem shOptPool solto", src:find("local shOptPool", 1, true) ~= nil)
    end

    _G.gameSettings = savedSettings
    return t:done()
end

return M
