local Palette = require("src.ui.Palette")

local Theme = {}

local function rgba(c, a)
    return { c[1], c[2], c[3], a or c[4] or 1 }
end

Theme.Colors = {
    PRIMARY   = rgba(Palette.INK, 1),
    SECONDARY = rgba(Palette.TAROT_NAVY_DARK, 1),
    ACCENT    = rgba(Palette.AGED_GOLD, 1),
    ACCENT_SECONDARY = rgba(Palette.BLOOD, 1),

    SUCCESS = rgba(Palette.MOSS, 1),
    WARNING = rgba(Palette.RUST, 1),
    ERROR   = rgba(Palette.BLOOD, 1),
    INFO    = rgba(Palette.STEEL, 1),

    TEXT_PRIMARY   = rgba(Palette.PARCHMENT_LIGHT, 1),
    TEXT_SECONDARY = rgba(Palette.PARCHMENT, 1),
    TEXT_DISABLED  = rgba(Palette.PARCHMENT_DARK, 1),

    UI_BACKGROUND = rgba(Palette.INK, 0.92),
    UI_BORDER     = rgba(Palette.AGED_GOLD, 1),
    UI_HIGHLIGHT  = rgba(Palette.TAROT_NAVY, 1),

    CARD_ATTACK  = rgba(Palette.BLOOD, 1),
    CARD_DEFENSE = rgba(Palette.STEEL, 1),
    CARD_JOKER   = rgba(Palette.AGED_GOLD, 1),

    HEALTH_BAR = rgba(Palette.BLOOD, 1),
    ARMOR_BAR  = rgba(Palette.STEEL_LIGHT, 1),
    MANA_BAR   = rgba(Palette.AGED_GOLD, 1),
}

Theme.Gradients = {
    BACKGROUND_MAIN = function(x, y, width, height)
        local colors = {
            {0.05, 0.05, 0.08, 1},
            {0.1, 0.1, 0.15, 1},
            {0.08, 0.08, 0.12, 1}
        }
        return colors
    end,

    BUTTON_PRIMARY = function(x, y, width, height)
        local colors = {
            {0.2, 0.6, 0.2, 1},
            {0.15, 0.5, 0.15, 1},
            {0.1, 0.4, 0.1, 1}
        }
        return colors
    end,

    CARD_GLOW = function(x, y, width, height)
        local colors = {
            {0.8, 0.6, 0.2, 0.8},
            {0.6, 0.4, 0.1, 0.4},
            {0.4, 0.2, 0.05, 0.1}
        }
        return colors
    end
}

Theme.Effects = {
    SHADOW = {
        offsetX = 4,
        offsetY = 4,
        blur = 8,
        color = {0, 0, 0, 0.3}
    },

    GLOW = {
        intensity = 0.8,
        spread = 2,
        color = {0.8, 0.6, 0.2, 0.6}
    },

    BORDER_RADIUS = 8,

    TRANSITION_SPEED = 0.15
}

Theme.Typography = {
    TITLE_LARGE = {
        size = 48,
        weight = "bold",
        color = Theme.Colors.TEXT_PRIMARY
    },

    TITLE_MEDIUM = {
        size = 32,
        weight = "bold",
        color = Theme.Colors.TEXT_PRIMARY
    },

    TITLE_SMALL = {
        size = 24,
        weight = "bold",
        color = Theme.Colors.TEXT_PRIMARY
    },

    BODY = {
        size = 16,
        weight = "normal",
        color = Theme.Colors.TEXT_SECONDARY
    },

    CAPTION = {
        size = 12,
        weight = "normal",
        color = Theme.Colors.TEXT_DISABLED
    }
}

Theme.Utils = {
    drawVerticalGradient = function(x, y, width, height, colors)
        local segments = #colors
        local segmentHeight = height / segments

        for i = 1, segments do
            local color = colors[i]
            local segmentY = y + (i - 1) * segmentHeight
            local segmentHeightFinal = segmentHeight

            if i == segments then
                segmentHeightFinal = height - (i - 1) * segmentHeight
            end

            love.graphics.setColor(color)
            love.graphics.rectangle("fill", x, segmentY, width, segmentHeightFinal)
        end
    end,

    drawRadialGradient = function(centerX, centerY, radius, innerColor, outerColor)
        local segments = 20
        local angleStep = (2 * math.pi) / segments

        for i = 1, segments do
            local angle1 = (i - 1) * angleStep
            local angle2 = i * angleStep

            local color1 = Theme.Utils.interpolateColor(innerColor, outerColor, 0)

            love.graphics.setColor(color1)
            love.graphics.polygon("fill",
                centerX, centerY,
                centerX + math.cos(angle1) * radius, centerY + math.sin(angle1) * radius,
                centerX + math.cos(angle2) * radius, centerY + math.sin(angle2) * radius
            )
        end
    end,

    interpolateColor = function(color1, color2, t)
        if not color1 or not color2 or type(color1) ~= "table" or type(color2) ~= "table" then
            return {1, 1, 1, 1}
        end

        local c1 = {
            color1[1] or 1,
            color1[2] or 1,
            color1[3] or 1,
            color1[4] or 1
        }

        local c2 = {
            color2[1] or 1,
            color2[2] or 1,
            color2[3] or 1,
            color2[4] or 1
        }

        return {
            c1[1] + (c2[1] - c1[1]) * t,
            c1[2] + (c2[2] - c1[2]) * t,
            c1[3] + (c2[3] - c1[3]) * t,
            c1[4] + (c2[4] - c1[4]) * t
        }
    end,

    drawShadow = function(x, y, width, height, shadow)
        love.graphics.setColor(shadow.color)
        love.graphics.rectangle("fill",
            x + shadow.offsetX,
            y + shadow.offsetY,
            width, height,
            Theme.Effects.BORDER_RADIUS,
            Theme.Effects.BORDER_RADIUS
        )
    end,

    drawRoundedRectangle = function(x, y, width, height, color, borderColor)
        local radius = Theme.Effects.BORDER_RADIUS

        if color then
            love.graphics.setColor(color)
            love.graphics.rectangle("fill", x, y, width, height, radius, radius)
        end

        if borderColor then
            love.graphics.setColor(borderColor)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x, y, width, height, radius, radius)
        end
    end,

    drawTextWithShadow = function(text, x, y, font, color, shadowColor)
        if shadowColor then
            love.graphics.setColor(shadowColor)
            love.graphics.print(text, x + 2, y + 2)
        end

        love.graphics.setColor(color)
        love.graphics.print(text, x, y)
    end
}

return Theme
