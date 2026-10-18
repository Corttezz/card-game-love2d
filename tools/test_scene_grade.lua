local TK = require("tools.testkit")
local M = {}

local SECTIONS = { "grade", "contact", "occlusion", "lowFog", "trees", "landmarks" }
local LANDMARK_KEYS = { "rest", "battle", "shop", "event", "elite", "castle" }

local function luma(c) return 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3] end
local function sat(c)
    local mx, mn = math.max(c[1], c[2], c[3]), math.min(c[1], c[2], c[3])
    return mx - mn
end

local function fnBody(src, name)
    local s = src:find("local function " .. name .. "%(")
    if not s then return nil end
    local e = src:find("\nend\n", s, true)
    return e and src:sub(s, e + 4) or nil
end

function M.run()
    local t = TK.new("SceneGrade: fonte única de cor da cena")
    local biomes = require("src.data.biomes")
    local DATA = require("src.data.scene_integration")
    local SceneGrade = require("engine.SceneGrade")
    local savedSettings = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }

    for _, b in ipairs(biomes) do
        local e = DATA[b.id]
        if t:truthy(b.id .. ": tem entrada na tabela", e ~= nil) then
            for _, sec in ipairs(SECTIONS) do
                t:truthy(b.id .. ": seção " .. sec, type(e[sec]) == "table")
            end
            for _, k in ipairs(LANDMARK_KEYS) do
                t:truthy(b.id .. ": landmarks." .. k, e.landmarks and e.landmarks[k] ~= nil)
            end
            local g = e.grade
            t:truthy(b.id .. ": satFar < satNear ≤ 1", g.satFar < g.satNear and g.satNear <= 1)
            t:truthy(b.id .. ": contrastFar em [0.4, 1]", g.contrastFar >= 0.4 and g.contrastFar <= 1)
            t:truthy(b.id .. ": fogFar ≤ 0.6 e fogNear < fogFar", g.fogFar <= 0.6 and g.fogNear < g.fogFar)
            t:truthy(b.id .. ": contact.height em (0, 0.08]", e.contact.height > 0 and e.contact.height <= 0.08)
            t:truthy(b.id .. ": tuftsMin ≤ tuftsMax", e.occlusion.tuftsMin <= e.occlusion.tuftsMax)
        end
    end

    local amb = { 0.9, 0.85, 0.8 }
    local c0, c1, cm = {}, {}, {}

    SceneGrade.begin("fields", 0, nil, 1, amb)
    t:truthy("isActive logo após begin", SceneGrade.isActive())
    t:eq("biome() = fields", SceneGrade.biome(), "fields")
    SceneGrade.color("prop", 0, c0)
    SceneGrade.color("prop", 1, c1)
    t:truthy("horizonte mais escuro que a base (contrastFar)", luma(c0) < luma(c1))
    t:truthy("horizonte menos saturado que a base", sat(c0) <= sat(c1) + 1e-6)
    t:truthy("fogAlpha(0) > fogAlpha(1)", SceneGrade.fogAlpha(0) > SceneGrade.fogAlpha(1))
    t:near("fogAlpha(1) = fogNear", SceneGrade.fogAlpha(1), DATA.fields.grade.fogNear, 1e-6)
    t:near("fogAlpha(0) = fogFar", SceneGrade.fogAlpha(0), DATA.fields.grade.fogFar, 1e-6)
    local mono = true
    for k = 1, 20 do
        if SceneGrade.fogAlpha(k / 20) > SceneGrade.fogAlpha((k - 1) / 20) + 1e-9 then mono = false end
    end
    t:truthy("fogAlpha decresce com t", mono)
    for k = 0, 10 do
        SceneGrade.color("tree", k / 10, cm)
        if cm[1] > 1 or cm[2] > 1 or cm[3] > 1 or cm[1] < 0 or cm[1] ~= cm[1] then mono = false end
    end
    t:truthy("cor sempre em [0,1], sem NaN", mono)

    local day, dusk = {}, {}
    SceneGrade.begin("fields", 0, nil, 1, amb)
    SceneGrade.color("prop", 1, day)
    SceneGrade.begin("fields", 1, nil, 1, amb)
    SceneGrade.color("prop", 1, dusk)
    t:truthy("pôr do sol dos campos puxa pro azul-roxo (b/r sobe)",
        dusk[3] / dusk[1] > day[3] / day[1])
    local m0, m1 = {}, {}
    SceneGrade.begin("fields", 0, nil, 1, amb)
    SceneGrade.color("mountain", 0, m0)
    SceneGrade.begin("fields", 1, nil, 1, amb)
    SceneGrade.color("mountain", 0, m1)
    t:truthy("montanha ignora a hora do dia (só profundidade)",
        math.abs(m0[1] - m1[1]) < 1e-6 and math.abs(m0[3] - m1[3]) < 1e-6)

    SceneGrade.begin("fields", 0.5, nil, 1, amb)
    local same = true
    local f0 = {}
    SceneGrade.flatColor(SceneGrade.FAMILIES[1], f0)
    for _, fam in ipairs(SceneGrade.FAMILIES) do
        local fc = SceneGrade.flatColor(fam, {})
        if math.abs(fc[1] - f0[1]) > 1e-9 or math.abs(fc[2] - f0[2]) > 1e-9
           or math.abs(fc[3] - f0[3]) > 1e-9 then same = false end
    end
    t:truthy("flatColor igual para TODAS as famílias", same)
    t:truthy("flatColor = ambiente puro", math.abs(f0[1] - amb[1]) < 1e-9
        and math.abs(f0[2] - amb[2]) < 1e-9 and math.abs(f0[3] - amb[3]) < 1e-9)

    local a, bb = {}, {}
    SceneGrade.begin("fields", 0.7, nil, 1, amb)
    SceneGrade.color("tree", 0.4, a)
    _G.gameSettings = { reducedMotion = true }
    SceneGrade.begin("fields", 0.7, nil, 1, amb)
    SceneGrade.color("tree", 0.4, bb)
    _G.gameSettings = { reducedMotion = false }
    t:truthy("reducedMotion não muda cor (remove movimento, não informação)",
        a[1] == bb[1] and a[2] == bb[2] and a[3] == bb[3])

    local pf, pc, pm = {}, {}, {}
    SceneGrade.begin("fields", 0.5, nil, 1, amb)
    SceneGrade.color("prop", 0.5, pf)
    SceneGrade.begin("highlands", 0.5, nil, 1, amb)
    SceneGrade.color("prop", 0.5, pc)
    SceneGrade.begin("highlands", 0.5, "fields", 0.5, amb)
    SceneGrade.color("prop", 0.5, pm)
    local between = true
    for k = 1, 3 do
        local lo, hi = math.min(pf[k], pc[k]) - 1e-6, math.max(pf[k], pc[k]) + 1e-6
        if pm[k] < lo or pm[k] > hi then between = false end
    end
    t:truthy("blend no meio: cor entre as duas linhas", between)
    t:truthy("blend no meio: fogAlpha finito", SceneGrade.fogAlpha(0.3) == SceneGrade.fogAlpha(0.3))

    do
        SceneGrade.begin("fields", 0, nil, 1, amb)
        local n1, nm, nf = SceneGrade.treeDepth(1, {}), SceneGrade.treeDepth(0.45, {}), SceneGrade.treeDepth(0.05, {})
        local td = DATA.fields.grade.treeDepth
        t:truthy("treeDepth(1): sem névoa, sem meia resolução, volume cheio",
            n1 and n1.lift == 0 and n1.lod == 0 and n1.vol == td.vol)
        t:near("treeDepth(1): saturação do perto", n1.sat, td.satNear or 1, 1e-6)
        t:truthy("treeDepth(0.45): névoa parcial, nítido", nm.lift > 0 and nm.lift < td.lift and nm.lod == 0)
        t:near("treeDepth(0.45): névoa da árvore = curva do chão", nm.lift, SceneGrade.fogAlpha(0.45) * td.lift, 1e-6)
        t:truthy("treeDepth(0.05): névoa do horizonte, meia resolução, menos saturação",
            nf.lift > nm.lift and nf.lift <= SceneGrade.fogAlpha(0) * td.lift + 1e-6
            and nf.lod == 1 and nf.sat < nm.sat and nm.sat < n1.sat)
        t:truthy("treeDepth(0.2): nítido (meia resolução só no horizonte)", SceneGrade.treeDepth(0.2, {}).lod == 0)
        t:truthy("dessaturação no horizonte de no máximo 15%", td.sat >= 0.85)
        local hr, hg, hb = SceneGrade.treeHaze()
        local fr, fg, fb = SceneGrade.fogRaw()
        t:truthy("névoa das árvores = névoa crua do bioma (sem clarear)",
            math.abs(hr - fr) < 1e-6 and math.abs(hg - fg) < 1e-6 and math.abs(hb - fb) < 1e-6)
        local gc, tc = SceneGrade.color("grass", 0.45, {}), SceneGrade.color("tree", 0.45, {})
        t:truthy("tint da árvore em t=0,45 não é mais claro que o tint da grama em t=1 (névoa só no shader)",
            SceneGrade.color("tree", 0.45, {})[2] <= SceneGrade.color("grass", 1, {})[2] + 1e-6 and gc and tc)
        SceneGrade.begin("highlands", 0, nil, 1, amb)
        t:falsy("bioma sem treeDepth: treeDepth = nil (sem shader)", SceneGrade.treeDepth(0.2, {}))
        SceneGrade.begin("highlands", 0, "fields", 0.5, amb)
        local mid = SceneGrade.treeDepth(0.2, {})
        t:truthy("no blend a partir dos campos a névoa das árvores esvai, sem salto",
            mid ~= nil and mid.lift > 0 and mid.lift < td.lift)
    end

    t:eq("familyOf(tree)", SceneGrade.familyOf("tree"), "tree")
    t:eq("familyOf(pine)", SceneGrade.familyOf("pine"), "tree")
    t:eq("familyOf(bush)", SceneGrade.familyOf("bush"), "tree")
    t:eq("familyOf(rock)", SceneGrade.familyOf("rock"), "rock")
    t:eq("familyOf(ruin)", SceneGrade.familyOf("ruin"), "rock")
    t:eq("familyOf(fence)", SceneGrade.familyOf("fence"), "prop")
    t:eq("familyOf(lantern, luminária)", SceneGrade.familyOf("lantern", true), "luminaire")
    t:eq("familyOf(desconhecido)", SceneGrade.familyOf("zzz"), "prop")

    do
        local LightEngine = require("engine.LightEngine")
        local prev = _G.gameSettings
        _G.gameSettings = { reducedMotion = false, lighting = false }
        LightEngine.beginFrame(amb)
        SceneGrade.begin("fields", 0.5, nil, 1, amb)
        local cc, ff = {}, {}
        SceneGrade.color("prop", 0.5, cc)
        SceneGrade.flatColor("prop", ff)
        t:truthy("lighting=false: cor e flatColor válidos",
            cc[1] == cc[1] and cc[1] > 0 and ff[1] == ff[1] and ff[1] > 0)
        _G.gameSettings = prev
    end

    do
        local realGet = love.timer.getTime
        local now = 1000
        love.timer.getTime = function() return now end
        SceneGrade.begin("fields", 1, nil, 1, amb)
        now = 1000.5
        local cc = {}
        SceneGrade.color("enemy", 0.5, cc)
        t:falsy("sem begin há 0,1 s: inativo", SceneGrade.isActive())
        t:truthy("sem begin há 0,1 s: color = 1", cc[1] == 1 and cc[2] == 1 and cc[3] == 1)
        love.timer.getTime = realGet
    end

    do
        local src = love.filesystem.read("src/ui/WorldRoad.lua") or ""
        local er = love.filesystem.read("src/ui/EnemyRenderer.lua") or ""
        local viaKind = { luminaire = true }
        for _, fam in pairs(SceneGrade.KIND_FAMILY) do viaKind[fam] = true end
        t:truthy("WorldRoad resolve família por kind (familyOf)",
            src:find("Scene.Grade.familyOf(", 1, true) ~= nil)
        for _, fam in ipairs(SceneGrade.FAMILIES) do
            local needle = 'color("' .. fam .. '"'
            t:truthy("família '" .. fam .. "' tem chamada no desenho",
                viaKind[fam] or src:find(needle, 1, true) ~= nil or er:find(needle, 1, true) ~= nil)
        end
        for _, fn in ipairs({ "drawDome", "drawRoad", "drawGrass", "drawCastleOf",
                              "drawMountainsOf", "drawMountainsFrontOf", "drawPropsBehind",
                              "drawEncounterFront", "drawTerrainDetail" }) do
            local body = fnBody(src, fn)
            t:truthy(fn .. ": chama Scene.Grade.color", body ~= nil and body:find("Scene.Grade.color(", 1, true) ~= nil)
        end
        for _, gone in ipairs({ "LMG.setTint", "local mixK", "liftT", "local tint = 0.35",
                                "local tint = 0.28", "setColor(0.88, 0.88, 0.88",
                                "setColor(0.94, 0.94, 0.94", "setColor(0.7, 0.7, 0.7",
                                "setColor(0.66, 0.66, 0.66", "setColor(0.6, 0.6, 0.6",
                                "oc.lift", ".lift = " }) do
            t:falsy("WorldRoad sem '" .. gone .. "'", src:find(gone, 1, true) ~= nil)
        end
        t:falsy("EnemyRenderer sem 'local tint = 0.28'", er:find("local tint = 0.28", 1, true) ~= nil)
        t:truthy("WorldRoad: SceneGrade.begin logo após LightEngine.beginFrame",
            src:find("LightEngine%.beginFrame%(amb%)%s*\n%s*Scene%.Grade%.begin%(") ~= nil)
    end

    do
        local WorldRoad = require("src.ui.WorldRoad")
        local W, H = love.graphics.getDimensions()
        local function shot(tod)
            local cv = love.graphics.newCanvas(W, H)
            WorldRoad.clearCache()
            WorldRoad.resetRun()
            WorldRoad.setBiome(1)
            WorldRoad._camZ = 5.5
            WorldRoad.setTimeOfDay(tod, true)
            for _ = 1, 10 do WorldRoad.update(1 / 30) end
            WorldRoad._blend = nil
            WorldRoad._prevBiomeIndex = nil
            love.graphics.setCanvas(cv)
            love.graphics.clear(0, 0, 0, 1)
            WorldRoad.draw(0, 52, W, H - 52, 1)
            WorldRoad.drawOverlays(0, 52, W, H - 52)
            love.graphics.setCanvas()
            return cv:newImageData()
        end
        local okA, idA = pcall(shot, 0)
        local okB, idB = pcall(shot, 1)
        t:truthy("cena desenha com o grade (dia e pôr do sol)", okA and okB)
        if okA and okB then
            local x, y = math.floor(W * 0.5), math.floor(H * 0.85)
            local r0, g0, b0 = idA:getPixel(x, y)
            local r1, g1, b1 = idB:getPixel(x, y)
            t:truthy("chão perto da base muda de cor com a hora do dia",
                math.abs(r0 - r1) + math.abs(g0 - g1) + math.abs(b0 - b1) > 0.01)
        end
        WorldRoad.clearCache()
        WorldRoad.resetRun()
    end

    _G.gameSettings = savedSettings
    return t:done()
end

return M
