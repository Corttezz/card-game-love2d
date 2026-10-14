local TK = require("tools.testkit")

local M = {}

local function contains(list, v)
    for _, x in ipairs(list) do if x == v then return true end end
    return false
end

function M.run()
    local t = TK.new("Props vivos da loja")
    TK.bootstrap()
    local ShopProps = require("src.ui.shop.ShopProps")
    _G.gameSettings = _G.gameSettings or {}
    local savedRM = _G.gameSettings.reducedMotion
    _G.gameSettings.reducedMotion = false
    ShopProps._reset()

    local missing = ShopProps.missingAssets()
    t:eq("nenhum asset ausente" .. (#missing > 0 and (": " .. table.concat(missing, ", ")) or ""), #missing, 0)
    local expect = {
        { "lantern", 96, 48 }, { "diceCup", 160, 32 }, { "dieFaces", 96, 16 },
        { "moth", 64, 16 }, { "cobweb", 32, 32 }, { "saleTag", 24, 16 },
    }
    for _, e in ipairs(expect) do
        local info = love.filesystem.getInfo(ShopProps.ASSETS[e[1]])
        if info then
            local img = love.graphics.newImage(ShopProps.ASSETS[e[1]])
            local w, h = img:getDimensions()
            t:truthy(("%s é %dx%d (tem %dx%d)"):format(e[1], e[2], e[3], w, h), w == e[2] and h == e[3])
        end
    end

    local Lantern = ShopProps.lantern.Lantern
    local l = ShopProps.lantern.new()
    local framesSeen, levelsSeen, badFrame, badLevel = {}, {}, false, false
    local fracStep = false
    for i = 1, 600 do
        l:update(1 / 60, nil)
        if l.frame ~= math.floor(l.frame) or l.frame < 1 or l.frame > 3 then badFrame = true end
        if not Lantern.LEVELS[l.level] then badLevel = true end
        if l.lookStep ~= math.floor(l.lookStep) then fracStep = true end
        framesSeen[l.frame] = true
        levelsSeen[l.level] = true
    end
    t:falsy("quadro da chama sempre 1..3 inteiro", badFrame)
    t:falsy("nível de luz sempre do catálogo", badLevel)
    t:truthy("em 10 s a chama passou pelos 3 quadros", framesSeen[1] and framesSeen[2] and framesSeen[3])
    t:truthy("em 10 s a luz passou por 2+ níveis", (levelsSeen[1] and 1 or 0) + (levelsSeen[2] and 1 or 0) + (levelsSeen[3] and 1 or 0) >= 2)
    t:eq("sem hover a poça fica no centro", l.lookStep, 0)
    l:update(1 / 60, 1.0)
    t:eq("primeiro frame com hover: alvo 2, passo ainda 0", l.lookStep, 0)
    for _ = 1, 18 do l:update(1 / 60, 1.0) end
    t:eq("depois de ~1/4 s: 1 passo", l.lookStep, 1)
    for _ = 1, 18 do l:update(1 / 60, 1.0) end
    t:eq("depois de ~1/2 s: 2 passos (teto)", l.lookStep, 2)
    for _ = 1, 30 do l:update(1 / 60, 1.0) end
    t:eq("não passa do teto", l.lookStep, 2)
    t:falsy("passo nunca fracionário", fracStep)
    for _ = 1, 18 do l:update(1 / 60, -0.3) end
    t:eq("hover à esquerda (-0.3): desce um passo por vez", l.lookStep, 1)
    for _ = 1, 60 do l:update(1 / 60, -0.3) end
    t:eq("alvo -1 alcançado e segurado", l.lookStep, -1)
    local cx0 = select(1, l:lightCenter(100, 50, 1))
    l.lookStep = 0
    local cx1 = select(1, l:lightCenter(100, 50, 1))
    t:eq("cada passo move a poça LOOK_PX", cx1 - cx0, Lantern.LOOK_PX)

    local cup = ShopProps.diceCup.new()
    t:eq("copo nasce em repouso", cup.state, "idle")
    cup:setState("rolled", { a = 9, b = 2 })
    t:eq("faces inválidas são recusadas", cup.state, "idle")
    cup:setState("rolled", { a = 3, b = 4 })
    cup:update(0)
    t:eq("rolled: copo deitado (quadro 5)", cup.frame, 5)
    t:truthy("dados guardados", cup.dice and cup.dice[1] == 3 and cup.dice[2] == 4)
    t:truthy("rolled ocupa mais largura (copo + 2 dados)", cup:width(1) > 32)
    cup:setState("idle")
    t:falsy("de pé: sem dados na mesa", cup.dice)
    cup:setState("shake")
    local seen = {}
    for i = 1, 30 do cup:update(1 / 30); seen[cup.frame] = true end
    t:truthy("chacoalho usa os quadros 2, 3 e 4", seen[2] and seen[3] and seen[4])
    t:falsy("chacoalho não usa repouso nem deitado", seen[1] or seen[5])
    cup:setState("idle")
    local run = { actNumber = 1, floorInAct = 1, mapHistory = {} }
    t:falsy("syncRun sem jogada: falso", cup:syncRun(run))
    t:eq("sem jogada: copo em pé", cup.state, "idle")
    run.scribeDice = { key = "dice|1|1|0", used = true, dice = { 6, 1 }, sum = 7 }
    t:truthy("syncRun com jogada da visita", cup:syncRun(run))
    t:truthy("mostra as faces salvas (6 e 1)", cup.state == "rolled" and cup.dice[1] == 6 and cup.dice[2] == 1)
    table.insert(run.mapHistory, { type = "shop" })
    t:falsy("nó seguinte: resíduo descartado", cup:syncRun(run))
    t:eq("nó seguinte: copo de pé outra vez", cup.state, "idle")

    local Moth = ShopProps.moth.Moth
    local m = ShopProps.moth.new()
    t:truthy("espera inicial entre 20 e 40 s", m.wait >= Moth.MIN_WAIT and m.wait <= Moth.MAX_WAIT)
    t:falsy("nasce parada", m:isFlying())
    m:update(Moth.MAX_WAIT + 1)
    t:truthy("depois da espera: voa", m:isFlying())
    local flew = 0
    while m:isFlying() and flew < 60 do m:update(0.25); flew = flew + 0.25 end
    t:truthy("a travessia termina (" .. flew .. " s)", not m:isFlying() and flew > 1 and flew < 20)
    t:truthy("reagenda entre 20 e 40 s", m.wait >= Moth.MIN_WAIT and m.wait <= Moth.MAX_WAIT)

    _G.gameSettings.reducedMotion = true
    local lr = ShopProps.lantern.new()
    lr:update(1 / 60, nil)
    local f0, lv0 = lr.frame, lr.level
    local m0x, m0y = lr.motes[1].x, lr.motes[1].y
    for _ = 1, 300 do lr:update(1 / 60, 0.9) end
    t:truthy("reduzido: chama parada no quadro 1", lr.frame == 1 and f0 == 1)
    t:truthy("reduzido: luz no nível médio", lr.level == 2 and lv0 == 2)
    t:truthy("reduzido: poeira parada", lr.motes[1].x == m0x and lr.motes[1].y == m0y)
    t:eq("reduzido: a poça ainda aponta pro hover (informação)", lr.lookStep, 2)
    local cr = ShopProps.diceCup.new()
    cr:setState("shake")
    for _ = 1, 20 do cr:update(1 / 30) end
    t:eq("reduzido: copo não chacoalha", cr.frame, 1)
    cr:setState("rolled", { a = 2, b = 5 }); cr:update(0)
    t:truthy("reduzido: dados jogados e copo deitado continuam", cr.frame == 5 and cr.dice[2] == 5)
    local mr = ShopProps.moth.new()
    mr:update(Moth.MAX_WAIT + 1)
    t:falsy("reduzido: a mariposa não voa", mr:isFlying())
    _G.gameSettings.reducedMotion = false

    local cv = love.graphics.newCanvas(640, 400)
    local L = {
        wall = { x = 0, y = 0, w = 640, h = 400 },
        shelfTop = { x = 40, y = 40, w = 380, h = 120 },
        shelfBottom = { x = 40, y = 180, w = 380, h = 90 },
        counter = { x = 20, y = 300, w = 600, h = 80, dice = { x = 300, y = 318, w = 60, h = 56 } },
        scroll = { x = 520, y = 40, w = 100, h = 230 },
        lantern = { x = 440, y = 60, w = 64, h = 104 },
    }
    local fake = { actNumber = 2, floorInAct = 3, mapHistory = {},
        scribeDice = { key = "dice|2|3|0", used = true, dice = { 5, 2 }, sum = 7 } }
    t:noerror("objetos desenham num canvas", function()
        love.graphics.setCanvas(cv)
        l:draw(100, 20, 2); l:drawLight(100, 20, 2, { pool = false })
        cup:draw(300, 200, 2); m:cross(); m:update(1.2); m:draw(100, 60, 2)
        ShopProps.cobweb.draw(0, 0, 2); ShopProps.saleTag.draw(400, 300, 2)
        love.graphics.setCanvas()
    end)
    t:noerror("fachada: load/update/draw*", function()
        ShopProps._reset()
        ShopProps.load()
        local ctx = { t = 0, reduced = false, hoverX = 100, hoverY = 100, run = fake, cupHover = 0 }
        for _ = 1, 60 do ShopProps.update(1 / 30, L, ctx) end
        love.graphics.setCanvas(cv)
        ShopProps.drawBack(L, ctx)
        ShopProps.drawLantern(L.lantern, ctx)
        ShopProps.drawDiceCup(L.counter.dice, ctx)
        ShopProps.drawFront(L, ctx)
        love.graphics.setCanvas()
    end)
    local sc = ShopProps.scene()
    t:truthy("fachada: copo lê a jogada da run (5 e 2)", sc and sc.cup.state == "rolled" and sc.cup.dice[1] == 5 and sc.cup.dice[2] == 2)
    t:truthy("fachada: hover à esquerda move a luz pra esquerda", sc and sc.lantern.lookStep < 0 and ShopProps.lookDx(L.lantern) < 0)
    local fx, fy = ShopProps.flameAnchor(L.lantern)
    t:truthy("flameAnchor dentro do rect da lanterna",
        fx >= L.lantern.x and fx <= L.lantern.x + L.lantern.w and fy >= L.lantern.y and fy <= L.lantern.y + L.lantern.h)
    t:truthy("lightLevel é um dos 3 níveis", contains(Lantern.LEVELS, ShopProps.lightLevel()))
    ShopProps.update(1 / 30, L, { cupHover = 1, run = { actNumber = 2, floorInAct = 3, mapHistory = {} } })
    t:eq("fachada: hover no copo sem jogada chacoalha", sc.cup.state, "shake")

    ShopProps._reset()
    _G.gameSettings.reducedMotion = savedRM
    return t:done()
end

return M
