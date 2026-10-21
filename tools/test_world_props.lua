local TK = require("tools.testkit")
local M = {}

local WORLD = "assets/sprites/world/"
local TREEISH = { tree = true, pine = true, deadtree = true, bush = true }

local function bottomOpaqueWidth(data, row)
    local w, n = data:getWidth(), 0
    for x = 0, w - 1 do
        local _, _, _, a = data:getPixel(x, row)
        if a >= 0.6 then n = n + 1 end
    end
    return n
end

function M.run()
    local t = TK.new("Props de árvore do mundo (PNG, raízes no chão)")
    local biomes = require("src.data.biomes")
    local props = require("src.data.world_props")
    local WorldRoad = require("src.ui.WorldRoad")

    local TREE_KIND = { fields = "tree", highlands = "pine", abyss = "deadtree",
                        frost = "pine", marsh = "deadtree", dusk = "tree" }
    for _, b in ipairs(biomes) do
        local kinds = {}
        for k in pairs(b.propWeights or {}) do
            if TREEISH[k] then kinds[#kinds + 1] = k end
        end
        table.sort(kinds)
        for _, k in ipairs(kinds) do
            local path = WORLD .. b.id .. "_" .. k .. "_0.png"
            local has = love.filesystem.getInfo(path) ~= nil
            if k == TREE_KIND[b.id] then
                t:truthy(("%s: espécie da parede '%s' tem PNG da variante 0"):format(b.id, k), has)
            elseif not has then
                print(("  [aviso] %s: kind '%s' sorteável sem PNG (procedural)"):format(b.id, k))
            end
        end
    end

    local keys = {}
    for k in pairs(props.sink) do keys[#keys + 1] = k end
    table.sort(keys)
    t:check("tabela de sink não está vazia", #keys > 0)
    t:check("SINK_DEFAULT_FRAC < SINK_MAX_FRAC",
        props.SINK_DEFAULT_FRAC < props.SINK_MAX_FRAC)
    for _, key in ipairs(keys) do
        local sink = props.sink[key]
        local path = WORLD .. key .. ".png"
        local info = love.filesystem.getInfo(path)
        if t:truthy(key .. ": PNG existe", info ~= nil) then
            local data = love.image.newImageData(path)
            local h = data:getHeight()
            t:check(("%s: sink %d dentro de [1, %d%% da altura %d]")
                :format(key, sink, props.SINK_MAX_FRAC * 100, h),
                sink >= 1 and sink <= math.floor(h * props.SINK_MAX_FRAC))
            t:check(key .. ": sem margem transparente embaixo (crop)",
                bottomOpaqueWidth(data, h - 1) > 0)
            t:check(key .. ": linha de contato tem tronco opaco",
                bottomOpaqueWidth(data, h - sink - 1) >= 3)
        end
    end

    for key, n in pairs(props.variants or {}) do
        local bid, kind = key:match("^(%a+)_(%a+)$")
        t:eq(key .. ": WorldRoad.propVariants = tabela", WorldRoad.propVariants(bid, kind), n)
        for v = 0, n - 1 do
            t:truthy(("%s: variante %d tem PNG e sink"):format(key, v),
                love.filesystem.getInfo(WORLD .. key .. "_" .. v .. ".png") ~= nil
                and props.sink[key .. "_" .. v] ~= nil)
        end
        t:falsy(("%s: nenhum PNG além das %d variantes declaradas"):format(key, n),
            love.filesystem.getInfo(WORLD .. key .. "_" .. n .. ".png") ~= nil)
    end
    t:eq("sem entrada em variants: 3 variantes", WorldRoad.propVariants("zz_sem_entrada", "pine"), 3)

    do
        local sh = WorldRoad.treeDepthShader()
        if t:truthy("shader de profundidade das árvores compila", sh ~= nil and sh ~= false) then
            local img = love.graphics.newImage(WORLD .. "fields_tree_0.png")
            img:setFilter("nearest", "nearest")
            local iw, ih = img:getDimensions()
            local prevShader = love.graphics.getShader()
            local function render(depth)
                local cv = love.graphics.newCanvas(iw, ih)
                love.graphics.setCanvas(cv)
                love.graphics.clear(0, 0, 0, 0)
                love.graphics.setShader()
                love.graphics.setBlendMode("alpha")
                love.graphics.setColor(0.9, 0.95, 0.85, 1)
                if depth then
                    sh:send("depth", depth)
                    sh:send("fog", { 0.6, 0.68, 0.74 })
                    sh:send("texel", { 1 / iw, 1 / ih })
                    love.graphics.setShader(sh)
                end
                love.graphics.draw(img, 0, 0)
                love.graphics.setShader()
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.setCanvas()
                return cv:newImageData()
            end
            local plain, near, far = render(nil), render({ 0, 1, 0, 0 }), render({ 0.3, 0.8, 1, 0 })
            love.graphics.setShader(prevShader)
            local same, diff, opaque = true, 0, 0
            for y = 0, ih - 1 do
                for x = 0, iw - 1 do
                    local r0, g0, b0, a0 = plain:getPixel(x, y)
                    local r1, g1, b1, a1 = near:getPixel(x, y)
                    local r2, g2, b2 = far:getPixel(x, y)
                    if math.abs(r0 - r1) > 1 / 255 or math.abs(g0 - g1) > 1 / 255
                       or math.abs(b0 - b1) > 1 / 255 or math.abs(a0 - a1) > 1 / 255 then same = false end
                    if a0 > 0.5 then
                        opaque = opaque + 1
                        if math.abs(r0 - r2) + math.abs(g0 - g2) + math.abs(b0 - b2) > 0.02 then diff = diff + 1 end
                    end
                end
            end
            t:truthy("perto (lift 0, sat 1, lod 0, vol 0): pixel-idêntico ao desenho cru", same)
            t:truthy(("longe (lift/sat/lod): a maioria dos pixels muda (%d de %d)"):format(diff, opaque),
                diff > opaque * 0.5)
        end
    end

    do
        WorldRoad.clearCache()
        WorldRoad.resetRun()
        WorldRoad.setBiome(1)
        WorldRoad._camZ = 5.5
        for _ = 1, 3 do WorldRoad.update(1 / 30) end
        local bySide = { [-1] = {}, [1] = {} }
        for _, p in ipairs(WorldRoad._props) do
            if p.wall and not p.ghost then table.insert(bySide[p.side], p) end
        end
        local used, pairsN, equalN = {}, 0, 0
        for _, list in pairs(bySide) do
            table.sort(list, function(a, b) return a.z < b.z end)
            for i, p in ipairs(list) do
                used[p.variant] = true
                if i > 1 then
                    pairsN = pairsN + 1
                    if list[i - 1].variant == p.variant then equalN = equalN + 1 end
                end
            end
        end
        local nUsed = 0
        for _ in pairs(used) do nUsed = nUsed + 1 end
        t:truthy(("parede dos campos usa pelo menos 5 das 6 variantes (%d)"):format(nUsed), nUsed >= 5)
        t:truthy(("parede: vizinhas do mesmo lado raramente repetem a silhueta (%d de %d)"):format(equalN, pairsN),
            pairsN > 10 and equalN <= pairsN * 0.2)
        WorldRoad.clearCache()
        WorldRoad.resetRun()
    end

    local cut0, vis0, h0 = WorldRoad.propCutInfo("tree", 0, "fields")
    t:eq("fields tree v0: sink da tabela", cut0, props.sink.fields_tree_0)
    t:eq("fields tree v0: altura visível = altura - sink", vis0, h0 - cut0)
    local cut2 = WorldRoad.propCutInfo("tree", 2, "fields")
    local hasV2 = love.filesystem.getInfo(WORLD .. "fields_tree_2.png") ~= nil
    if hasV2 then
        t:eq("fields tree v2: sink da própria tabela", cut2, props.sink.fields_tree_2)
    else
        t:eq("fields tree v2 sem PNG: herda o sink da variante 0", cut2, cut0)
    end
    local cutRock = WorldRoad.propCutInfo("rock", 0, "fields")
    t:eq("pedra não enterra", cutRock, 0)
    local cutLum = WorldRoad.propCutInfo("lantern", 0, "fields")
    t:eq("luminária não enterra por aqui (footPad é do LuminaireEngine)", cutLum, 0)
    local cutBush, _, hBush = WorldRoad.propCutInfo("bush", 0, "fields")
    t:eq("arbusto sem entrada: SINK_DEFAULT_FRAC da altura", cutBush,
        math.floor(hBush * props.SINK_DEFAULT_FRAC + 0.5))

    do
        local GrassField = require("engine.GrassField")
        local savedSettings = _G.gameSettings
        _G.gameSettings = { reducedMotion = false }
        local W, H = love.graphics.getDimensions()
        local cv = love.graphics.newCanvas(W, H)
        local function frame()
            WorldRoad.update(1 / 30)
            love.graphics.setCanvas(cv)
            love.graphics.clear(0, 0, 0, 1)
            WorldRoad.draw(0, 52, W, H - 52, 1)
            WorldRoad.drawOverlays(0, 52, W, H - 52)
            love.graphics.setCanvas()
        end
        WorldRoad.clearCache()
        WorldRoad.resetRun()
        WorldRoad.setBiome(1)
        WorldRoad._camZ = 5.5
        for _ = 1, 10 do frame() end
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        WorldRoad._landmark = { key = "landmark_rest", z = WorldRoad._camZ + 9, size = 3.6, phase = 0 }
        WorldRoad._camZ = WorldRoad._camZ + 0.01
        GrassField.resetStats()
        frame()
        local total = GrassField.stats.builds + GrassField.stats.replays
        local at = WorldRoad._landmarkDrawnAt or -1
        t:truthy(("landmark escolhido pintado ENTRE fatias de grama (fatia %d de %d)"):format(at, total),
            at > 0 and at < total)
        local lx = WorldRoad.getRoadAnchor(9, 0, 52, W, H - 52)
        local reqs, n = GrassField._tuftRequests()
        local near = 0
        for i = 1, n do
            if math.abs(reqs[i].x - lx) < 200 and reqs[i].rel < 9.2 and reqs[i].rel > 8.5 then near = near + 1 end
        end
        t:eq("nenhum tufo de grama pedido na base do landmark (fica sobre a estrada)", near, 0)
        local src = love.filesystem.read("src/ui/WorldRoad.lua") or ""
        t:falsy("drawLandmarkFront não existe mais", src:find("drawLandmarkFront", 1, true) ~= nil)
        t:truthy("landmark escolhido desenha dentro de drawProps (balanço da cena)",
            src:find("local function drawChosenLandmark()", 1, true) ~= nil)
        t:truthy("GrassField.beginFrame antes do castelo",
            src:find("GrassField%.beginFrame%(%).-drawCastle%(g, x, w, WorldRoad%._camZ%)") ~= nil)

        GrassField.resetStats()
        for _ = 1, 50 do frame() end
        GrassField.resetStats()
        for _ = 1, 5 do frame() end
        t:eq("com tufos e câmera parada a grama ainda reusa o lote (0 builds)", GrassField.stats.builds, 0)

        local capPix = 2.0 * 2.08 * WorldRoad.enemyScreenK(H - 52) * 1.1
        for b = 1, 6 do
            WorldRoad.restoreProgress(b, 3)
            for _ = 1, 400 do
                if WorldRoad.isPrewarmed(b) then break end
                WorldRoad.prewarmTick(0.05, b)
            end
            for _ = 1, 90 do WorldRoad.update(1 / 30) end
            WorldRoad._blend = nil
            WorldRoad._prevBiomeIndex = nil
            WorldRoad.setHandZone(W * 0.36, W * 0.64, H * 0.8)
            WorldRoad.setBattleEnemyDraw(function() end, nil)
            love.graphics.setCanvas(cv)
            love.graphics.clear(0, 0, 0, 1)
            WorldRoad.draw(0, 52, W, H - 52, b)
            love.graphics.setCanvas()
            local GC = require("engine.GroundClutter")
            local cs = GC.stats
            t:truthy(("bioma %d: primeiro plano com 2 a 8 detalhes de chão por lado (esq %d, dir %d)")
                :format(b, cs.left, cs.right), cs.left >= 2 and cs.right >= 2 and cs.left <= 8 and cs.right <= 8)
            t:truthy(("bioma %d: detalhe de chão até 2x o pixel do inimigo (pior %.2f)"):format(b, cs.worst),
                cs.worst > 0 and cs.worst <= 2.0)
            t:truthy(("bioma %d: detalhe de chão fora da estrada (folga %.0f px)"):format(b, cs.roadGap),
                cs.roadGap > -W * 0.02)
            local worst, nS = 0, 0
            for _, he in ipairs(WorldRoad._hitScene) do
                local hd = he.ref and require("engine.LuminaireEngine").def(he.ref.bid, he.ref.kind)
                if he.s and not (hd and hd.roadside) then
                    nS = nS + 1
                    if he.s > worst then worst = he.s end
                end
            end
            local ctop = WorldRoad._castleTop
            t:truthy(("bioma %d: castelo no centro da crista ao retomar a run (dx %.1f)")
                :format(b, ctop and (ctop.cx - W / 2) or 999),
                ctop ~= nil and math.abs(ctop.cx - W / 2) <= 1)
            t:truthy(("bioma %d: nenhum prop (fora o poste, que segue a lei de continuidade) passa de 2x o pixel do inimigo, com a variação de escala por instância (pior %.2f, teto %.2f, %d props)")
                :format(b, worst, capPix, nS), nS > 0 and worst <= capPix)
        end
        do
            WorldRoad.restoreProgress(1, 3)
            for _ = 1, 30 do WorldRoad.update(1 / 30) end
            WorldRoad._blend = nil
            WorldRoad._prevBiomeIndex = nil
            love.graphics.setCanvas(cv)
            WorldRoad.draw(0, 52, W, H - 52, 1)
            love.graphics.setCanvas()
            local cx0 = WorldRoad._castleTop.cx
            local moved = 0
            for _ = 1, 20 do
                WorldRoad.update(1 / 60)
                love.graphics.setCanvas(cv)
                WorldRoad.draw(0, 52, W, H - 52, 1)
                love.graphics.setCanvas()
                moved = math.max(moved, math.abs(WorldRoad._castleTop.cx - cx0))
            end
            t:truthy(("castelo parado durante a cena parada (deslocamento máximo %.1f px)"):format(moved), moved <= 1)
        end
        do
            local CD = require("src.ui.CastleDrift")
            local MM = require("src.systems.MapManager")
            local function frame(dt)
                WorldRoad.update(dt)
                love.graphics.setCanvas(cv)
                WorldRoad.draw(0, 52, W, H - 52, 1)
                love.graphics.setCanvas()
                return WorldRoad._castleTop.cx - W / 2
            end
            local function pick(types, idx)
                local nodes = {}
                for i, ty in ipairs(types) do nodes[i] = { type = ty, label = MM.labelFor(ty) } end
                WorldRoad.showFork(nodes, function() end)
                local before
                for _ = 1, 25 do before = frame(1 / 30) end
                local b = WorldRoad._fork.markBoxes[idx]
                WorldRoad.forkMousePressed((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2)
                local jump = math.abs(frame(1 / 30) - before)
                for _ = 1, 400 do
                    if not WorldRoad._fork then break end
                    frame(1 / 30)
                end
                WorldRoad._landmark = nil
                return jump
            end
            WorldRoad.restoreProgress(1, 2)
            WorldRoad._blend = nil
            WorldRoad._prevBiomeIndex = nil
            local dx0 = frame(1 / 30)
            t:truthy(("castelo centrado no início do ato (dx %.1f)"):format(dx0), math.abs(dx0) <= 1)
            local jump = pick({ "battle", "rest", "shop" }, 1)
            t:truthy(("castelo não salta no clique do ramo (%.2f px)"):format(jump), jump <= 2)
            WorldRoad.travel({})
            for _ = 1, 400 do
                if not WorldRoad.isTraveling() then break end
                frame(1 / 30)
            end
            local dxL = frame(1 / 30)
            t:truthy(("ramo da esquerda puxa o castelo um pouco para o lado do ramo (dx %.1f)"):format(dxL),
                dxL * CD.SIGN < -W * 0.01 and math.abs(dxL) <= W * CD.MAX + 1)
            local moved = 0
            for _ = 1, 30 do moved = math.max(moved, math.abs(frame(1 / 60) - dxL)) end
            t:truthy(("castelo parado na batalha com o desvio (%.2f px)"):format(moved), moved <= 1)
            pick({ "battle", "shop", "rest" }, 1)
            pick({ "battle", "shop", "rest" }, 1)
            local dxM = frame(1 / 30)
            t:truthy(("desvio acumulado respeita o teto (dx %.1f, teto %.1f)"):format(dxM, W * CD.MAX),
                math.abs(dxM) <= W * CD.MAX + 1)
            pick({ "boss" }, 1)
            WorldRoad.travel({})
            for _ = 1, 400 do
                if not WorldRoad.isTraveling() then break end
                frame(1 / 30)
            end
            local dxB = frame(1 / 30)
            t:truthy(("castelo centrado na porta do chefe (dx %.1f)"):format(dxB), math.abs(dxB) <= 1)
            WorldRoad._fork = nil
            WorldRoad.restoreProgress(1, 3)
        end
        for _, b in ipairs({ 1, 2, 3, 4, 5, 6 }) do
            WorldRoad.restoreProgress(b, 3)
            WorldRoad._plan = nil
            for _ = 1, 400 do
                if WorldRoad.isPrewarmed(b) then break end
                WorldRoad.prewarmTick(0.05, b)
            end
            for _ = 1, 30 do WorldRoad.update(1 / 30) end
            WorldRoad._blend = nil
            WorldRoad._prevBiomeIndex = nil
            local lum
            for _, p in ipairs(WorldRoad._props) do
                local LE = require("engine.LuminaireEngine")
                local d = not p.ghost and LE.def(p.bid, p.kind)
                if d and d.roadside then lum = p; break end
            end
            t:truthy(("bioma %d: há luminária de beira de estrada para o teste de afastamento"):format(b), lum ~= nil)
            if lum then
                local LE = require("engine.LuminaireEngine")
                local nRoad = 0
                for _, d in pairs(LE.catalog(lum.bid)) do
                    if d.roadside then nRoad = nRoad + 1 end
                end
                t:eq(("bioma %d: um único tipo de poste de beira de estrada"):format(b), nRoad, 1)
                local far = 0
                for _, p in ipairs(WorldRoad._props) do
                    local d = not p.ghost and LE.def(p.bid, p.kind)
                    if d and d.roadside and math.abs(p.lane - LE.ROAD_LANE) > 1e-9 then far = far + 1 end
                end
                t:eq(("bioma %d: todo poste colado à estrada na mesma faixa"):format(b), far, 0)
            end
        end
        WorldRoad.resetRun()
        WorldRoad.setBiome(1)
        WorldRoad._camZ = 5.51
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        for _ = 1, 4 do frame() end

        _G.gameSettings = { reducedMotion = true }
        GrassField.resetStats()
        WorldRoad._camZ = WorldRoad._camZ + 0.01
        frame()
        t:truthy("reducedMotion mantém os tufos (informação, não movimento)", GrassField.stats.tufts > 0)
        _G.gameSettings = { reducedMotion = false }

        local realBegin = GrassField.beginFrame
        GrassField.beginFrame = function()
            realBegin()
            GrassField.requireTufts(5, 100, 10, 3, 0.01)
        end
        GrassField.resetStats()
        WorldRoad._camZ = WorldRoad._camZ + 0.01
        local okMin = pcall(frame)
        GrassField.beginFrame = realBegin
        t:truthy("tufo com escala mínima não quebra", okMin)

        WorldRoad._landmark = nil
        WorldRoad.clearCache()
        WorldRoad.resetRun()
        _G.gameSettings = savedSettings
    end

    do
        local GF = require("engine.GrassField")
        local P = GF.PRESETS.frost
        t:truthy("gelo: tapete de capim ralo (neve aparece entre os talos)", (P.carpet or 1) <= 0.5)
        t:eq("gelo: talos sem o tom seco quente", P.dry, 0)
        local frost
        for _, b in ipairs(require("src.data.biomes")) do if b.id == "frost" then frost = b end end
        local g = frost and frost.grassA
        local L = g and (0.299 * g[1] + 0.587 * g[2] + 0.114 * g[3]) or 0
        t:truthy(string.format("gelo: chão claro de neve (luminância %.2f ≥ 0,65)", L), L >= 0.65)
    end

    do
        local faltam = {}
        local clut = require("src.data.ground_clutter").biomes
        for _, b in ipairs(require("src.data.biomes")) do
            local kinds = {}
            for k in pairs(b.propWeights or {}) do kinds[#kinds + 1] = k end
            for _, e in ipairs(clut[b.id] or {}) do kinds[#kinds + 1] = e.kind end
            for _, k in ipairs(kinds) do
                local path = "assets/sprites/world/" .. b.id .. "_" .. k .. "_0.png"
                if not love.filesystem.getInfo(path) then faltam[#faltam + 1] = b.id .. "_" .. k end
            end
        end
        table.sort(faltam)
        t:truthy("todo prop e todo detalhe de chão tem arte desenhada (sem sprite procedural): "
            .. (#faltam == 0 and "ok" or table.concat(faltam, ", ")), #faltam == 0)
    end

    return t:done()
end

return M
