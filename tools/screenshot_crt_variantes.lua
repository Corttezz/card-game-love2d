local M = {}

M.VARIANTS = {
    { id = "atual", file = "shaders/crt.glsl", label = "ATUAL (o jogo hoje)" },
    { id = "A_bezel_curvatura", label = "A  moldura funda + curvatura + reflexo na borda" },
    { id = "B_mascara_aperture", label = "B  grade de abertura + scanline (forte nas bordas)" },
    { id = "C_halation_bloom", label = "C  halation / bloom do fosforo" },
    { id = "D_convergencia_bordas", label = "D  erro de convergencia RGB nas bordas" },
    { id = "E_vinheta_desfoque_bordas", label = "E  desfoque + vinheta nas bordas" },
    { id = "F_vidro_reflexo", label = "F  vidro: reflexo + borda + brilho" },
    { id = "G_forte_combinado", label = "G  combinado forte (H+B+C+D+E+F)" },
    { id = "H_moldura_segue_imagem", label = "H  moldura acompanha a imagem curva (sem cunha preta)" },
}

local W, H = 1920, 1080
local OUT = "crt_variantes"
local TIME = 12.345

local CROPS = {
    { id = "canto", x = 0, y = 0, w = 480, h = 270 },
    { id = "centro", x = 720, y = 300, w = 480, h = 270 },
    { id = "cartas", x = 660, y = 780, w = 600, h = 300 },
}

local function sendIf(sh, name, value)
    if sh:hasUniform(name) then sh:send(name, value) end
end

local function buildScene()
    local TK = require("tools.testkit")
    TK.bootstrap()
    require("src.ui.PixelCanvas").enableNearest()
    require("src.systems.ScreenShake").install()
    local UiScale = require("src.ui.UiScale")
    local Config = require("src.core.Config")
    local Theme = require("src.ui.Theme")
    local Button = require("components.Button")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local GameplayScene = require("src.scenes.GameplayScene")
    local WorldRoad = require("src.ui.WorldRoad")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local I18n = require("src.i18n.I18n")

    TK.seedRng(777)
    local game = TK.newRunGame("warrior")
    UiScale.force(nil)
    _G.game = game

    local run = game.runManager.currentRun
    run.actNumber, run.floorInAct = 1, 3
    run.currentNode = { type = "battle" }
    local EnemyRoster = require("src.systems.EnemyRoster")
    local ActSystem = require("src.systems.ActSystem")
    local Enemy = require("src.entities.Enemy")
    game.enemy = EnemyRoster.spawn(Enemy, "cursed_scarecrow", ActSystem.getEnemyStats(1, 3, "battle"))
    game.enemy.spriteId = "cursed_scarecrow"
    game.enemy.isBoss = false

    local topBar = TopBar:new()
    topBar:setGame(game)
    local bw = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_WIDTH_RATIO, 180, "width")
    local bh = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_HEIGHT_RATIO, 60, "height")
    GameplayScene.init({
        game = game,
        playButton = Button:new(0, 0, bw, bh, I18n.t("play_button.label"), function() end, Theme.Colors.SUCCESS, 18),
        endTurnButton = Button:new(0, 0, bw, math.floor(bh * 0.72), I18n.t("play_button.end_turn"), function() end, Theme.Colors.WARNING, 14),
        topBar = topBar,
        gameUI = GameUI:new(),
    })
    GameplayScene.setGame(game)
    GameplayScene.resetTurnState()
    WorldRoad.setBiome(1)

    local db = require("src.systems.CardDatabase"):new()
    db:loadData()
    game.hand = {}
    for _, id in ipairs({ "warrior_strike", "warrior_bash", "warrior_defend",
        "warrior_iron_wave", "warrior_quick_strike" }) do
        local cd = db:getCard(id)
        if cd then game.hand[#game.hand + 1] = db:createCardInstance(cd) end
    end
    game.player.mana, game.player.maxMana = 3, 3
    game.selectedCards = {}
    game.turn = "player"

    WorldRoad.setTimeOfDay(0.85, true)
    for _ = 1, 60 do
        UiScale.begin(); _G.EventManager.update(1 / 30); UiScale.finish()
        GameplayScene.update(1 / 30)
        WorldRoad.setTimeOfDay(0.85, true)
        if game.messageSystem then game.messageSystem:update(1 / 30) end
    end
    if game.messageSystem then game.messageSystem.messages = {} end

    local scene = love.graphics.newCanvas(W, H)
    love.graphics.push("all")
    love.graphics.setCanvas({ scene, stencil = true })
    love.graphics.clear(0, 0, 0, 1)
    GameplayScene.draw()
    love.graphics.pop()
    scene:setFilter("linear", "linear")
    return scene
end

local function applyVariant(scene, v, out)
    local file = v.file or ("tools/crt_variants/" .. v.id .. ".glsl")
    local ok, sh = pcall(love.graphics.newShader, file)
    if not ok then
        print("[FAIL] " .. v.id .. ": " .. tostring(sh))
        return false
    end
    love.graphics.push("all")
    love.graphics.setCanvas(out)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setShader(sh)
    sendIf(sh, "time", TIME)
    sendIf(sh, "resolution", { W, H })
    sendIf(sh, "strength", 0.75)
    sendIf(sh, "power", 1)
    sendIf(sh, "powerDir", 1)
    sendIf(sh, "glitch", 0)
    sendIf(sh, "glitchY", 0.5)
    sendIf(sh, "degrade", 0)
    sendIf(sh, "calmRect", { 0, 0, 0, 0 })
    sendIf(sh, "calmRect2", { 0, 0, 0, 0 })
    sendIf(sh, "caScale", 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(scene, 0, 0)
    love.graphics.setShader()
    love.graphics.pop()
    sh:release()
    return true
end

local function label(font, text, x, y)
    love.graphics.setFont(font)
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", x, y, font:getWidth(text) + 20, font:getHeight() + 10)
    love.graphics.setColor(1, 0.93, 0.75, 1)
    love.graphics.print(text, x + 10, y + 5)
    love.graphics.setColor(1, 1, 1, 1)
end

function M.run()
    local rw, rh, rd = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    local realMouse = love.mouse.getPosition
    love.graphics.getWidth = function() return W end
    love.graphics.getHeight = function() return H end
    love.graphics.getDimensions = function() return W, H end
    love.mouse.getPosition = function() return 5, 5 end
    love.filesystem.createDirectory(OUT)

    local ok, err = pcall(function()
        require("src.ui.FontManager").clearCache()
        local scene = buildScene()
        scene:newImageData():encode("png", OUT .. "/sem_crt.png")
        print("[crt_variantes] " .. OUT .. "/sem_crt.png")
        local out = love.graphics.newCanvas(W, H)
        local images = {}
        for _, v in ipairs(M.VARIANTS) do
            if applyVariant(scene, v, out) then
                local data = out:newImageData()
                data:encode("png", OUT .. "/" .. v.id .. ".png")
                print("[crt_variantes] " .. OUT .. "/" .. v.id .. ".png")
                local img = love.graphics.newImage(data)
                img:setFilter("nearest", "nearest")
                images[#images + 1] = { v = v, img = img }
                data:release()
            end
        end
        out:release()

        local font = love.graphics.newFont(26)
        local tw, th = W / 2, H / 2
        local cols = 4
        local rows = math.ceil(#images / cols)
        local sheet = love.graphics.newCanvas(tw * cols, th * rows)
        love.graphics.push("all")
        love.graphics.setCanvas(sheet)
        love.graphics.clear(0.05, 0.05, 0.05, 1)
        for i, it in ipairs(images) do
            local cx = ((i - 1) % cols) * tw
            local cy = math.floor((i - 1) / cols) * th
            it.img:setFilter("linear", "linear")
            love.graphics.draw(it.img, cx, cy, 0, 0.5, 0.5)
            it.img:setFilter("nearest", "nearest")
            label(font, it.v.label, cx + 8, cy + th - 50)
        end
        love.graphics.pop()
        sheet:newImageData():encode("png", OUT .. "/folha_contato.png")
        print("[crt_variantes] " .. OUT .. "/folha_contato.png")
        sheet:release()

        for _, c in ipairs(CROPS) do
            local cw, ch = c.w * 2, c.h * 2
            local single = love.graphics.newCanvas(cw, ch)
            local gcols = 4
            local grid = love.graphics.newCanvas(cw * gcols, ch * math.ceil(#images / gcols))
            for i, it in ipairs(images) do
                local q = love.graphics.newQuad(c.x, c.y, c.w, c.h, W, H)
                love.graphics.push("all")
                love.graphics.setCanvas(single)
                love.graphics.clear(0, 0, 0, 1)
                love.graphics.draw(it.img, q, 0, 0, 0, 2, 2)
                love.graphics.pop()
                local name = OUT .. "/recorte_" .. c.id .. "_" .. it.v.id .. ".png"
                single:newImageData():encode("png", name)
                print("[crt_variantes] " .. name)
                love.graphics.push("all")
                love.graphics.setCanvas(grid)
                if i == 1 then love.graphics.clear(0.05, 0.05, 0.05, 1) end
                local gx = ((i - 1) % gcols) * cw
                local gy = math.floor((i - 1) / gcols) * ch
                love.graphics.draw(single, gx, gy)
                label(font, it.v.label, gx + 8, gy + ch - 50)
                love.graphics.pop()
                q:release()
            end
            local gname = OUT .. "/recortes_" .. c.id .. "_todos.png"
            grid:newImageData():encode("png", gname)
            print("[crt_variantes] " .. gname)
            grid:release()
            single:release()
        end
        for _, it in ipairs(images) do it.img:release() end
        scene:release()
    end)
    if not ok then print("[FAIL] crt_variantes: " .. tostring(err)) end
    love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = rw, rh, rd
    love.mouse.getPosition = realMouse
    require("src.ui.UiScale").force(1)
    return ok
end

return M
