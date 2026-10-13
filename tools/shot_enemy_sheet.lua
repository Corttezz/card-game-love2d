-- tools/shot_enemy_sheet.lua
-- Prancha de TODOS os inimigos (assets/sprites/characters/enemies/*) na
-- estrada do bioma deles, pelo caminho real (GameplayScene.draw), com o HUD
-- (intent, vida, pills). Serve pra conferir de olho se o HUD está centrado
-- no CORPO (Out/2026: "o 29 e a barra estão à esquerda do corpo").
--
--   SHOT_SIZE=1920x1080 love . test_one shot_enemy_sheet [id1,id2,...]
--
-- SHEET_MODE=feet: recorte 2x no PÉ de cada um (contato com o chão), com
-- tiques magenta na linha de chão → enemy_feet_sheet.png.
-- SHEET_MODE=death: o mesmo recorte no ÚLTIMO quadro da morte (cadáver)
-- → enemy_death_sheet.png.
-- Saída: enemy_sheet.png no save dir (recortes lado a lado, com o nome e
-- uma marca amarela no eixo do corpo, abaixo do pé).

local M = {}

-- bioma de cada inimigo: ROSTER quando ele está lá; senão pelo nome
local KEYWORDS = {
    { 4, { "frost", "ice", "rime", "glacier", "winter" } },
    { 3, { "ember", "hell", "abyss", "obsidian", "pit", "tyrant" } },
    { 5, { "bog", "mire", "rot", "plague", "spore", "leech", "croc", "toad" } },
    { 6, { "dusk", "eclipse", "blood", "fallen", "spectral", "dullahan" } },
    { 2, { "moon", "rune", "stone", "tower", "storm", "gargoyle", "griffin", "harpy" } },
}
local function actFor(id)
    local ok, Enemies = pcall(require, "src.data.enemies")
    if ok and Enemies.ROSTER then
        for act, pools in pairs(Enemies.ROSTER) do
            for _, list in pairs(pools) do
                for _, e in ipairs(list) do if e == id then return act end end
            end
        end
    end
    for _, kw in ipairs(KEYWORDS) do
        for _, w in ipairs(kw[2]) do
            if id:find(w, 1, true) then return kw[1] end
        end
    end
    return 1
end

function M.run(which)
    local sw, sh = (os.getenv("SHOT_SIZE") or ""):match("^(%d+)x(%d+)$")
    if sw then love.window.setMode(tonumber(sw), tonumber(sh)) end
    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")

    local Game = require("src.core.Game")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local WorldRoad = require("src.ui.WorldRoad")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local Button = require("components.Button")
    local FontManager = require("src.ui.FontManager")

    local ids = {}
    if which and which ~= "" and which ~= "all" then
        for id in which:gmatch("[^,]+") do ids[#ids + 1] = id end
    else
        local root = "assets/sprites/characters/enemies"
        for _, d in ipairs(love.filesystem.getDirectoryItems(root)) do
            if love.filesystem.getInfo(root .. "/" .. d .. "/animations/idle/south") then
                ids[#ids + 1] = d
            end
        end
        table.sort(ids)
    end

    local w, h = love.graphics.getDimensions()
    local canvas = love.graphics.newCanvas(w, h)
    -- SHEET_MODE=feet: recorte AMPLIADO 2x no pé (contato com o chão), com
    -- tiques magenta na linha de chão pedida, fora do corpo
    local mode = os.getenv("SHEET_MODE")
    -- death: mata o inimigo e fotografa o ÚLTIMO quadro (cadáver) no pé
    local death = mode == "death"
    local feet = mode == "feet" or death
    local cw, ch = math.floor(w * 0.30), math.floor(h * 0.56)
    local fw, fh = 340, 150
    if feet then cw, ch = fw * 2, fh * 2 end
    local feetCanvas = feet and love.graphics.newCanvas(cw, ch) or nil
    -- strip: 6 instantes do idle por inimigo (uma linha cada) — prova de
    -- que fumaça/raio/gota/brilho pintados SE MEXEM na cena real
    -- attack: 6 instantes do GOLPE (preparo → apex → volta), na cena real
    local attackMode = mode == "attack" or mode == "attack_strong"
    local stripMode = mode == "strip" or attackMode
    if stripMode then cw, ch = math.floor(w * 0.20), math.floor(h * 0.42) end
    local cols = 6
    local rows = stripMode and #ids or math.ceil(#ids / cols)
    local sheet = love.image.newImageData(cols * (cw + 4), rows * (ch + 4))
    local font = FontManager.getFont(14)

    for n, id in ipairs(ids) do
        local act = actFor(id)
        _G.EventManager.clear()
        local game = Game:new()
        game:startNewRun("warrior")
        game:startGame()
        local run = game.runManager.currentRun
        run.actNumber = act
        run.floorInAct = 3
        run.currentNode = { type = "battle" }
        game.messageSystem = nil
        game.enemy.spriteId = id
        game.enemy.isBoss = false
        EnemyRenderer.clearCache()
        EnemyRenderer.resetRun()
        _G.game = game
        local topBar = TopBar:new()
        topBar:setGame(game)
        GameplayScene.init({
            game = game, topBar = topBar, gameUI = GameUI:new(),
            playButton = Button:new(w * 0.80, h * 0.80, 150, 46, "Jogar"),
        })
        WorldRoad.setBiome(act)
        WorldRoad.setTimeOfDay(0.75, true)
        for _ = 1, 60 do
            WorldRoad.update(1 / 30)
            EnemyRenderer.update(1 / 30)
        end
        if stripMode then
            if attackMode then
                love.graphics.setCanvas(canvas)
                GameplayScene.draw()          -- carrega a idle deste id
                love.graphics.setCanvas()
                EnemyRenderer.triggerAttack(mode == "attack_strong" and "strong" or "attack",
                    function() end)
            end
            -- golpe: t = 0.06 0.18 0.30 0.36 0.50 0.76 s (apex em 0.34)
            local steps = attackMode and { 2, 4, 4, 2, 4, 8 } or { 8, 8, 8, 8, 8, 8 }
            for i = 1, 6 do
                for _ = 1, steps[i] do EnemyRenderer.update(1 / 30) end
                love.graphics.setCanvas(canvas)
                love.graphics.clear(0, 0, 0, 1)
                GameplayScene.draw()
                love.graphics.setCanvas()
                local f = EnemyRenderer.getLastFoot()
                local img = canvas:newImageData()
                local bx = f and f.bodyX or w / 2
                local gy = f and f.groundY or h * 0.76
                local x0 = math.max(0, math.min(w - cw, math.floor(bx - cw / 2)))
                local y0 = math.max(0, math.min(h - ch, math.floor(gy - ch * 0.92)))
                sheet:paste(img, (i - 1) * (cw + 4), (n - 1) * (ch + 4), x0, y0, cw, ch)
            end
        end
        if death then
            love.graphics.setCanvas(canvas)
            GameplayScene.draw()          -- carrega a idle deste id
            love.graphics.setCanvas()
            game.enemy.health = 0
            EnemyRenderer.triggerDeath(id)
            for _ = 1, 90 do EnemyRenderer.update(1 / 30) end
        end
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 1)
        GameplayScene.draw()
        -- marca: eixo do corpo (amarelo) abaixo do pé — o HUD (desenhado pelo
        -- jogo) tem que estar centrado nesta mesma coluna
        local foot = EnemyRenderer.getLastFoot()
        if foot and death then
            print(string.format("[cadaver] %-20s gap=%.1f frame=%s pad=%s",
                id, foot.footBottom - foot.groundY, tostring(foot.frame), tostring(foot.pad)))
        end
        if foot then
            print(string.format("[eixo] %-20s hud=%.1f corpo=%.1f dif=%.1f px (%.2f px da arte)",
                id, foot.hudCx or -1, foot.bodyX or -1,
                (foot.bodyX or 0) - (foot.hudCx or 0),
                ((foot.bodyX or 0) - (foot.hudCx or 0)) / (foot.scale or 1)))
        end
        if foot and foot.bodyX then
            love.graphics.setColor(1, 1, 0, 0.9)
            love.graphics.rectangle("fill", math.floor(foot.bodyX), foot.groundY + 6, 2, 30)
        end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(font)
        local img
        if feet and foot then
            love.graphics.setColor(1, 0, 1, 1)
            local gx = math.floor(foot.bodyX)
            love.graphics.rectangle("fill", gx - fw / 2, foot.groundY, 12, 1)
            love.graphics.rectangle("fill", gx + fw / 2 - 12, foot.groundY, 12, 1)
            love.graphics.setCanvas(feetCanvas)
            love.graphics.clear(0, 0, 0, 1)
            love.graphics.setColor(1, 1, 1, 1)
            local q = love.graphics.newQuad(gx - fw / 2, foot.groundY - fh * 0.75, fw, fh,
                canvas:getDimensions())
            canvas:setFilter("nearest", "nearest")
            love.graphics.draw(canvas, q, 0, 0, 0, 2, 2)
            love.graphics.print(id, 6, 4)
            love.graphics.setCanvas()
            img = feetCanvas:newImageData()
            sheet:paste(img, ((n - 1) % cols) * (cw + 4), math.floor((n - 1) / cols) * (ch + 4),
                0, 0, cw, ch)
        elseif not stripMode then
            love.graphics.print(id .. "  (ato " .. act .. ")", w / 2 - cw / 2 + 6, h * 0.14 + 4)
            love.graphics.setCanvas()
            img = canvas:newImageData()
            local x0 = math.floor((w - cw) / 2)
            local y0 = math.floor(h * 0.14)
            sheet:paste(img, ((n - 1) % cols) * (cw + 4), math.floor((n - 1) / cols) * (ch + 4),
                x0, y0, cw, ch)
        else
            love.graphics.setCanvas()
        end
    end
    local out = attackMode and ("enemy_" .. mode .. "_sheet.png")
        or stripMode and "enemy_strip_sheet.png" or death and "enemy_death_sheet.png"
        or (feet and "enemy_feet_sheet.png" or "enemy_sheet.png")
    sheet:encode("png", out)
    print("[shot_enemy_sheet] " .. #ids .. " inimigos -> " .. out)
    return true
end

return M
