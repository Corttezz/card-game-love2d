local TK = require("tools.testkit")
local M = {}

function M.run()
    local t = TK.new("PropVariation: variação por instância determinística; vento em duas amplitudes")
    local PV = require("engine.PropVariation")
    local tbl = { tint = 0.05, scale = 0.08, flip = true, windPhase = true,
                  canopySway = 0.030, trunkSway = 0.010, bushSway = 0.040 }

    local a = PV.of(12.5, "tree", tbl)
    local aR, aS, aF, aP = a.tintR, a.scale, a.flip, a.windPhase
    local b = PV.of(12.5, "tree", tbl)
    t:truthy("mesma semente → mesmos valores", b.tintR == aR and b.scale == aS and b.flip == aF and b.windPhase == aP)
    local c = PV.of(13.7, "tree", tbl)
    t:truthy("semente diferente → valores diferentes", c.tintR ~= aR or c.scale ~= aS or c.windPhase ~= aP)

    local okRange, flips, phases = true, { [1] = 0, [-1] = 0 }, true
    for i = 1, 200 do
        local v = PV.of(i * 0.731, "tree", tbl)
        if v.tintR < 0.95 - 1e-9 or v.tintR > 1.05 + 1e-9 then okRange = false end
        if v.tintG < 0.97 - 1e-9 or v.tintG > 1.03 + 1e-9 then okRange = false end
        if v.scale < 0.92 - 1e-9 or v.scale > 1.08 + 1e-9 then okRange = false end
        if v.windPhase < 0 or v.windPhase >= 6.2832 then phases = false end
        flips[v.flip] = (flips[v.flip] or 0) + 1
    end
    t:truthy("tom em 1 ± tint, escala em 1 ± scale", okRange)
    t:truthy("fase em [0, 2π)", phases)
    t:truthy("espelho sorteia os dois lados (" .. flips[1] .. "/" .. flips[-1] .. ")", flips[1] > 50 and flips[-1] > 50)

    local nf = PV.of(5, "tree", { tint = 0, scale = 0, flip = false, windPhase = false })
    t:truthy("flip=false → sempre 1; windPhase=false → 0; tint/scale 0 → 1",
        nf.flip == 1 and nf.windPhase == 0 and nf.tintR == 1 and nf.scale == 1)

    local tr = PV.of(5, "tree", tbl)
    local trC, trT = tr.canopy, tr.trunk
    local bu = PV.of(5, "bush", tbl)
    t:truthy("árvore: copa 0.030 e tronco 0.010", trC == 0.030 and trT == 0.010)
    t:truthy("arbusto: copa = bushSway e tronco 0", bu.canopy == 0.040 and bu.trunk == 0)

    local v = PV.of(5, "tree", tbl)
    local r0, k0 = PV.sway(v, 10.0, 0, 0.022, false)
    local r1, k1 = PV.sway(v, 10.4, 0, 0.022, false)
    t:truthy("sway muda com o tempo", r0 ~= r1 or k0 ~= k1)
    t:truthy("tronco quase parado (|rot| ≤ trunk)", math.abs(r0) <= 0.010 + 1e-9 and math.abs(r1) <= 0.010 + 1e-9)
    t:truthy("copa balança mais que o tronco (|kx| pode chegar a canopy)", math.abs(k0) <= 0.030 + 1e-9)
    local _, kg = PV.sway(v, 10.0, 1.5, 0.022, false)
    t:truthy("rajada soma no cisalhamento da copa", math.abs(kg - k0 + 1.5 * 0.022) < 1e-9)
    local rr, kr = PV.sway(v, 10.0, 1.5, 0.022, true)
    t:truthy("reducedMotion → sem movimento (0, 0)", rr == 0 and kr == 0)
    local vr = PV.of(12.5, "tree", tbl)
    t:truthy("reducedMotion não mexe na variação (tom/escala/espelho ficam)",
        vr.tintR == aR and vr.scale == aS and vr.flip == aF)

    do
        local src = love.filesystem.read("src/ui/WorldRoad.lua") or ""
        t:falsy("WorldRoad sem a rotação fixa antiga (* 0.018)", src:find("p.z * 0.7) * 0.018", 1, true) ~= nil)
        t:truthy("drawList usa Scene.Var.sway", src:find("Scene.Var.sway(pv,", 1, true) ~= nil)
        t:truthy("companheiras com fase própria", src:find("Scene.Var.of(p.z + ci * 17.3", 1, true) ~= nil)
        t:truthy("emersão na crista usa a mesma variação", select(2, src:gsub("Scene%.Var%.of%(p%.z, p%.kind", "")) >= 2)
    end

    do
        local WorldRoad = require("src.ui.WorldRoad")
        local W, H = love.graphics.getDimensions()
        local cv = love.graphics.newCanvas(W, H)
        local ok = true
        for bio = 1, 6 do
            WorldRoad.clearCache()
            WorldRoad.resetRun()
            WorldRoad.setBiome(bio)
            WorldRoad._camZ = 5.5
            for _ = 1, 5 do WorldRoad.update(1 / 30) end
            WorldRoad._blend = nil
            WorldRoad._prevBiomeIndex = nil
            love.graphics.setCanvas(cv)
            local okD = pcall(WorldRoad.draw, 0, 52, W, H - 52, bio)
            love.graphics.setCanvas()
            ok = ok and okD
        end
        t:truthy("os 6 biomas desenham com variação de árvore", ok)
        WorldRoad.clearCache()
        WorldRoad.resetRun()
    end

    return t:done()
end

return M
