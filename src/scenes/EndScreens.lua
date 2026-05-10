-- src/scenes/EndScreens.lua
-- Telas terminais (gameOver, victory). Extraídas de main.lua.
-- Estáticas: sem update externo, mas fazem tick interno de DynaText no draw
-- (via love.timer.getDelta) pra título animar mesmo sem hook em main.update.

local Config = require("src.core.Config")
local FontManager = require("src.ui.FontManager")
local Theme = require("src.ui.Theme")
local I18n = require("src.i18n.I18n")
local SceneBackground = require("src.ui.SceneBackground")
local DynaText = require("src.ui.DynaText")

local EndScreens = {}

-- Cache de instâncias DynaText por chave (gameOver/victory). Recriadas se a
-- fonte responsiva muda (resize) ou texto muda (locale). Trackeia lastDrawTime
-- pra detectar "re-entrada" na cena → dispara :pulse() + reset do pop_in.
local titleDyna = {}
local function ensureTitle(key, text, size, color)
    local entry = titleDyna[key]
    local now = love.timer.getTime()
    local reentered = (not entry) or (entry.lastDraw and (now - entry.lastDraw > 0.3))

    if not entry or entry.cachedText ~= text or entry.cachedSize ~= size then
        entry = {
            dyna = DynaText.new({
                text = text,
                fontSize = size,
                bump = true,                  -- letras "saltam" episodicamente
                rotate = true,
                pop_in = 0.5,
                pop_in_rate = 4,
                colours = { { color[1], color[2], color[3], color[4] or 1 } },
                shadow = true,
                align = "center",
                spacing = 0,
            }),
            cachedText = text,
            cachedSize = size,
        }
        titleDyna[key] = entry
        reentered = true
    end

    if reentered then
        -- Reset timer pra re-disparar pop_in cascade + dá pulse de impacto
        entry.dyna.timer = 0
        entry.dyna.popped_in = false
        entry.dyna:pulse(0.5, 0.45)
    end

    entry.lastDraw = now
    -- Tick interno (sem update externo do main).
    entry.dyna:update(love.timer.getDelta())
    return entry.dyna
end

function EndScreens.drawGameOver(game)
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()

    -- Scene PNG em primeiro plano; fallback pro gradiente vermelho legado
    if not SceneBackground.draw("gameOver", width, height, 0.40) then
        local bgColors = {
            {0.3, 0.1, 0.1, 1},
            {0.2, 0.05, 0.05, 1},
            {0.15, 0.02, 0.02, 1},
        }
        Theme.Utils.drawVerticalGradient(0, 0, width, height, bgColors)
    end

    local centerX = width / 2
    local centerY = height / 2

    local titleSize = math.min(48, math.floor(height * (Config.UI.TITLE_FONT_RATIO or 0.08)))
    local title = I18n.t("game_over.title")
    local dyna = ensureTitle("gameOver", title, titleSize, Theme.Colors.ERROR)
    dyna:draw(centerX, centerY - height * 0.167 + titleSize / 2)

    local scoreFont = FontManager.getResponsiveFont(Config.UI.SCORE_FONT_RATIO, 24)
    love.graphics.setFont(scoreFont)
    local scoreText = I18n.t("game_over.final_score", { score = game.score })
    local scoreWidth = scoreFont:getWidth(scoreText)
    love.graphics.setColor(Theme.Colors.TEXT_PRIMARY)
    love.graphics.print(scoreText, centerX - scoreWidth / 2, centerY - height * 0.083)

    local instructionFont = FontManager.getResponsiveFont(Config.UI.INSTRUCTION_FONT_RATIO, 18)
    love.graphics.setFont(instructionFont)
    local instruction = I18n.t("game_over.instructions")
    local instructionWidth = instructionFont:getWidth(instruction)
    love.graphics.setColor(Theme.Colors.TEXT_SECONDARY)
    love.graphics.print(instruction, centerX - instructionWidth / 2, centerY + height * 0.083)

    love.graphics.setFont(love.graphics.newFont())
end

function EndScreens.drawVictory(game)
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()

    if not SceneBackground.draw("victory", width, height, 0.35) then
        local bgColors = {
            {0.1, 0.3, 0.1, 1},
            {0.05, 0.2, 0.05, 1},
            {0.02, 0.15, 0.02, 1},
        }
        Theme.Utils.drawVerticalGradient(0, 0, width, height, bgColors)
    end

    local centerX = width / 2
    local centerY = height / 2

    local titleSize = math.min(48, math.floor(height * (Config.UI.TITLE_FONT_RATIO or 0.08)))
    local title = I18n.t("victory.title")
    local dyna = ensureTitle("victory", title, titleSize, Theme.Colors.SUCCESS)
    dyna:draw(centerX, centerY - height * 0.167 + titleSize / 2)

    local scoreFont = FontManager.getResponsiveFont(Config.UI.SCORE_FONT_RATIO, 24)
    love.graphics.setFont(scoreFont)
    local scoreText = I18n.t("victory.final_score", { score = game.score })
    local scoreWidth = scoreFont:getWidth(scoreText)
    love.graphics.setColor(Theme.Colors.TEXT_PRIMARY)
    love.graphics.print(scoreText, centerX - scoreWidth / 2, centerY - height * 0.083)

    local instructionFont = FontManager.getResponsiveFont(Config.UI.INSTRUCTION_FONT_RATIO, 18)
    love.graphics.setFont(instructionFont)
    local instruction = I18n.t("victory.instructions")
    local instructionWidth = instructionFont:getWidth(instruction)
    love.graphics.setColor(Theme.Colors.TEXT_SECONDARY)
    love.graphics.print(instruction, centerX - instructionWidth / 2, centerY + height * 0.083)

    love.graphics.setFont(love.graphics.newFont())
end

return EndScreens
