-- src/scenes/EndScreens.lua
-- Telas terminais (gameOver, victory). Extraídas de main.lua.
-- Estáticas: sem update, só draw.

local Config = require("src.core.Config")
local FontManager = require("src.ui.FontManager")
local Theme = require("src.ui.Theme")
local I18n = require("src.i18n.I18n")
local SceneBackground = require("src.ui.SceneBackground")

local EndScreens = {}

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

    local titleFont = FontManager.getResponsiveFont(Config.UI.TITLE_FONT_RATIO, 48)
    love.graphics.setFont(titleFont)
    local title = I18n.t("game_over.title")
    local titleWidth = titleFont:getWidth(title)
    love.graphics.setColor(Theme.Colors.ERROR)
    love.graphics.print(title, centerX - titleWidth / 2, centerY - height * 0.167)

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

    local titleFont = FontManager.getResponsiveFont(Config.UI.TITLE_FONT_RATIO, 48)
    love.graphics.setFont(titleFont)
    local title = I18n.t("victory.title")
    local titleWidth = titleFont:getWidth(title)
    love.graphics.setColor(Theme.Colors.SUCCESS)
    love.graphics.print(title, centerX - titleWidth / 2, centerY - height * 0.167)

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
