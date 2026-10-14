local Debug = require("src.core.Debug")

local BackgroundConfig = {}

BackgroundConfig.BACKGROUNDS = {
    GAMEPLAY = {
        path = "assets/backgrounds/step1.png",
        fallback = "gradient",
        scaleMode = "cover",
        opacity = 1.0,
        tint = {1, 1, 1, 1}
    },
    MENU = {
        path = "assets/backgrounds/menu_bg.png",
        fallback = "gradient",
        scaleMode = "cover",
        opacity = 1.0,
        tint = {1, 1, 1, 1}
    },
    CARD_REWARD = {
        path = "assets/backgrounds/reward_bg.png",
        fallback = "gradient",
        scaleMode = "cover",
        opacity = 0.8,
        tint = {1, 1, 1, 1}
    }
}

function BackgroundConfig.loadBackground(backgroundKey)
    local config = BackgroundConfig.BACKGROUNDS[backgroundKey]
    if not config then
        Debug.warn("[BackgroundConfig] AVISO: background nao encontrado:", backgroundKey)
        return nil
    end

    local success, image = pcall(love.graphics.newImage, config.path)
    if success then
        return image
    else
        Debug.warn("[BackgroundConfig] AVISO: nao foi possivel carregar background:", config.path)
        return nil
    end
end

function BackgroundConfig.drawBackground(background, config, width, height, offsetX, offsetY)
    if not background or not config then
        return false
    end

    offsetX = offsetX or 0
    offsetY = offsetY or 0

    local bgWidth = background:getWidth()
    local bgHeight = background:getHeight()
    local scale = 1
    local drawX = offsetX
    local drawY = offsetY

    if config.scaleMode == "cover" then
        local scaleX = width / bgWidth
        local scaleY = height / bgHeight
        scale = math.max(scaleX, scaleY)
        drawX = offsetX + (width - bgWidth * scale) / 2
        drawY = offsetY + (height - bgHeight * scale) / 2
    elseif config.scaleMode == "contain" then
        local scaleX = width / bgWidth
        local scaleY = height / bgHeight
        scale = math.min(scaleX, scaleY)
        drawX = offsetX + (width - bgWidth * scale) / 2
        drawY = offsetY + (height - bgHeight * scale) / 2
    elseif config.scaleMode == "stretch" then
        love.graphics.draw(background, offsetX, offsetY, 0, width / bgWidth, height / bgHeight)
        return true
    end

    local tint = config.tint
    love.graphics.setColor(tint[1], tint[2], tint[3], tint[4] * config.opacity)

    love.graphics.draw(background, drawX, drawY, 0, scale, scale)

    return true
end

function BackgroundConfig.getConfig(backgroundKey)
    return BackgroundConfig.BACKGROUNDS[backgroundKey]
end

function BackgroundConfig.listBackgrounds()
    local list = {}
    for key, config in pairs(BackgroundConfig.BACKGROUNDS) do
        table.insert(list, {
            key = key,
            path = config.path,
            scaleMode = config.scaleMode
        })
    end
    return list
end

return BackgroundConfig
