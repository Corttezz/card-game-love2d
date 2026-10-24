local TK = require("tools.testkit")

local M = {}

function M.run()
    local t = TK.new("test_enemy_pose")

    local EnemyPoses    = require("src.data.enemy_poses")
    local SceneAnchors  = require("src.data.scene_anchors")
    local SceneBg       = require("src.ui.SceneBackground")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local GameplayScene = require("src.scenes.GameplayScene")

    t:truthy("boss depois da cutscene luta DENTRO do castelo",
        GameplayScene.isInteriorNode("boss", true))
    t:falsy("boss ANTES da cutscene ainda esta na estrada",
        GameplayScene.isInteriorNode("boss", false))
    t:falsy("ELITE nao usa o salao do chefe (defeito Set/2026)",
        GameplayScene.isInteriorNode("elite", true))
    t:falsy("mini-boss briga na estrada",
        GameplayScene.isInteriorNode("mini_boss", true))
    t:falsy("batalha comum briga na estrada",
        GameplayScene.isInteriorNode("battle", true))

    local Config = require("src.core.Config")
    local totalAtos = Config.TotalActs or 3
    t:truthy("campanha tem ao menos 3 atos (sanidade do proprio teste)",
        totalAtos >= 3)
    for act = 1, totalAtos do
        local key = "castle_hall_" .. act
        t:truthy(key .. " tem ARTE no disco",
            love.filesystem.getInfo("assets/sprites/scenes/" .. key .. ".png") ~= nil)
        t:truthy(key .. " tem linha de chao declarada",
            SceneAnchors.BY_SCENE[key] ~= nil)
        local a = SceneAnchors.get(key)
        t:truthy(key .. " ancora na laje (yr=" .. tostring(a.yr) .. ")",
            a.yr > 0.60 and a.yr < 0.95)
    end

    do
        local vistos, repetido = {}, nil
        for act = 1, totalAtos do
            local p = "assets/sprites/scenes/castle_hall_" .. act .. ".png"
            if love.filesystem.getInfo(p) then
                local dados = love.filesystem.read(p)
                if vistos[dados] then
                    repetido = "atos " .. vistos[dados] .. " e " .. act
                end
                vistos[dados] = act
            end
        end
        t:falsy("nenhum salao de chefe se repete entre atos"
            .. (repetido and (" (" .. repetido .. ")") or ""), repetido ~= nil)
    end

    t:truthy("hall 2 ancora MAIS BAIXO que o hall 1 (laje mais baixa na arte)",
        SceneAnchors.get("castle_hall_2").yr
        > SceneAnchors.get("castle_hall_1").yr)

    do
        local key = "castle_hall_2"
        local tr1 = SceneBg.getCoverTransform(key, 1024, 768)
        local tr2 = SceneBg.getCoverTransform(key, 1920, 1080)
        t:truthy("cover transform do hall existe", tr1 ~= nil and tr2 ~= nil)
        if tr1 and tr2 then
            local _, y1 = SceneAnchors.groundAnchor(key, 1024, 768)
            local _, y2 = SceneAnchors.groundAnchor(key, 1920, 1080)
            local row1 = (y1 - tr1.oy) / tr1.scale
            local row2 = (y2 - tr2.oy) / tr2.scale
            t:near("mesma linha da arte em 1024x768 e 1920x1080",
                row1, row2, 1.5)
        end
    end

    local nodeTypes = { "battle", "elite", "mini_boss", "boss" }
    local seen = {}
    for act = 1, 6 do
        for _, nt in ipairs(nodeTypes) do
            local id = EnemyRenderer.resolveSpriteId(act, nt)
            if id and not seen[id] then
                seen[id] = true
                t:truthy("roster: '" .. id .. "' tem pose declarada",
                    EnemyPoses.BY_ID[id] ~= nil)
            end
        end
    end

    local dir = "assets/sprites/characters/enemies"
    if love.filesystem.getInfo(dir) then
        for _, name in ipairs(love.filesystem.getDirectoryItems(dir)) do
            local info = love.filesystem.getInfo(dir .. "/" .. name)
            if info and info.type == "directory" then
                t:truthy("sprite em disco: '" .. name .. "' tem pose",
                    EnemyPoses.BY_ID[name] ~= nil)
            end
        end
    end

    for id, p in pairs(EnemyPoses.BY_ID) do
        t:truthy(id .. ": pose valida",
            p.pose == "floating" or p.pose == "grounded")
        if p.pose == "floating" then
            t:truthy(id .. ": flutuante precisa de hover > 0",
                (p.hover or 0) > 0)
            t:truthy(id .. ": sombra de quem flutua e menor E mais fraca",
                (p.shadowK or 1) < 1 and (p.shadowA or 1) < 1)
        end
    end

    do
        local H = 300
        local prev = _G.gameSettings
        _G.gameSettings = { reducedMotion = true }
        local a = EnemyRenderer.poseOffsetY("dusk_shade", H, 0.0)
        local b = EnemyRenderer.poseOffsetY("dusk_shade", H, 3.7)
        local c = EnemyRenderer.poseOffsetY("dusk_shade", H, 11.2)
        t:near("reducedMotion: altura constante no tempo (t=0 vs 3.7)", a, b, 1e-9)
        t:near("reducedMotion: altura constante no tempo (t=0 vs 11.2)", a, c, 1e-9)
        local hover = EnemyPoses.get("dusk_shade").hover
        t:near("reducedMotion: altura = hover puro", a, -hover * H, 1e-9)
        t:truthy("reducedMotion: flutuante CONTINUA no ar", a < 0)

        _G.gameSettings = { reducedMotion = false }
        local bob = EnemyPoses.get("dusk_shade").bob
        local lo, hi = -(hover + bob) * H, -(hover - bob) * H
        local minV, maxV = math.huge, -math.huge
        for i = 0, 200 do
            local v = EnemyRenderer.poseOffsetY("dusk_shade", H, i * 0.05)
            if v < minV then minV = v end
            if v > maxV then maxV = v end
        end
        t:truthy("bob fica dentro da faixa hover+-bob",
            minV >= lo - 1e-6 and maxV <= hi + 1e-6)
        t:truthy("bob de verdade oscila", (maxV - minV) > 1)
        t:truthy("flutuante nunca encosta no chao", maxV < 0)

        local apoiados = 0
        for id, spec in pairs(EnemyPoses.BY_ID) do
            if spec.pose == "grounded" then
                apoiados = apoiados + 1
                if EnemyRenderer.poseOffsetY(id, H, 4.2) ~= 0 then
                    t:eq("grounded '" .. id .. "' nao tem offset de pose",
                        EnemyRenderer.poseOffsetY(id, H, 4.2), 0)
                end
            end
        end
        t:truthy("ha apoiados pra checar (" .. apoiados .. ")", apoiados > 5)
        t:eq("nenhum grounded tem offset", 0, 0)
        _G.gameSettings = prev
    end

    local ART = "assets/sprites/characters/enemies"

    local function padDoClip(id, clip)
        local p = ART .. "/" .. id .. "/animations/" .. clip .. "/south/0.png"
        if not love.filesystem.getInfo(p) then return nil end
        local ok, data = pcall(love.image.newImageData, p)
        if not ok or not data then return nil end
        local w, h = data:getWidth(), data:getHeight()
        for y = h - 1, 0, -1 do
            for x = 0, w - 1 do
                local _, _, _, a = data:getPixel(x, y)
                if a > 0.1 then return (h - 1) - y end
            end
        end
        return nil
    end

    do
        local checados = 0
        for _, id in ipairs(love.filesystem.getDirectoryItems(ART)) do
            local info = love.filesystem.getInfo(ART .. "/" .. id)
            if info and info.type == "directory" then
                local base = padDoClip(id, "idle")
                if base then
                    checados = checados + 1
                    for _, clip in ipairs({ "hurt", "death" }) do
                        local p = padDoClip(id, clip)
                        if p then
                            t:eq(id .. ": pe do '" .. clip
                                .. "' na mesma linha do idle", p, base)
                        end
                    end
                    t:truthy(id .. ": idle nao encosta na borda de baixo",
                        base >= 1)
                end
            end
        end
        t:truthy("checou os clips de varios inimigos (" .. checados .. ")",
            checados > 15)
    end

    do
        local dir = ART .. "/tower_lich/animations/idle/south"
        local frames = {}
        for _, f in ipairs(love.filesystem.getDirectoryItems(dir)) do
            if f:match("%.png$") then table.insert(frames, dir .. "/" .. f) end
        end
        table.sort(frames)
        t:truthy("idle do lich tem varios frames (" .. #frames .. ")",
            #frames >= 4)

        local function amplitude(fn)
            local lo, hi
            for _, path in ipairs(frames) do
                local ok, data = pcall(love.image.newImageData, path)
                if ok and data then
                    local v = fn(data)
                    if v then
                        lo = (lo and math.min(lo, v)) or v
                        hi = (hi and math.max(hi, v)) or v
                    end
                end
            end
            return (lo and hi) and (hi - lo) or 0
        end
        local function opaco(data, x, y)
            local _, _, _, a = data:getPixel(x, y)
            return a > 0.1
        end
        local bordaDir = amplitude(function(d)
            local w, h = d:getWidth(), d:getHeight()
            for x = w - 1, 0, -1 do
                for y = 0, h - 1 do if opaco(d, x, y) then return x end end
            end
        end)
        local function barra(x0r, x1r)
            return amplitude(function(d)
                local w, h = d:getWidth(), d:getHeight()
                local x0 = math.floor(w * x0r)
                local x1 = math.min(w - 1, math.floor(w * x1r))
                for y = h - 1, 0, -1 do
                    for x = x0, x1 do if opaco(d, x, y) then return y end end
                end
            end)
        end
        local total = bordaDir + barra(0.09, 0.24) + barra(0.70, 0.92)
        t:truthy("capa do lich SE MEXE entre os frames (soma=" .. total
            .. ", arte parada dava 3)", total >= 5)
        t:truthy("...capa esvoaca no voo sem sair do quadro (soma=" .. total .. ", teto 70)",
            total <= 70)
    end

    do
        local ER = require("src.ui.EnemyRenderer")
        local d = love.image.newImageData(40, 40)
        for y = 5, 24 do for x = 10, 29 do d:setPixel(x, y, 1, 1, 1, 1) end end
        for y = 25, 30 do d:setPixel(14, y, 1, 1, 1, 1); d:setPixel(15, y, 1, 1, 1, 1) end
        local g, fl, fr, low = ER._groundOf(d)
        t:eq("rabo fino abaixo do corpo nao vira o pe (chao na base do corpo)", g, 24)
        t:eq("...o pixel mais baixo continua sendo o rabo", low, 30)
        t:truthy("...pegada = largura do corpo (" .. fl .. ".." .. fr .. ")",
            fl == 10 and fr == 29)
        ER.clearCache()
        local m = ER.debugClipMetrics("plague_rats", "idle")
        t:eq("plague_rats: chao no groundRow 89 (patas), nao no rabo",
            (m.h - 1) - m.pad, 89)
    end

    local unknown = EnemyPoses.get("nao_existe_no_roster")
    t:eq("id desconhecido cai em grounded", unknown.pose, "grounded")
    t:eq("id desconhecido nao flutua", unknown.hover, 0)

    return t:done()
end

return M
