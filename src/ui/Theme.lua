-- src/Theme.lua
-- Sistema de design profissional — paleta grimório sépia (alinhada com Palette.lua).
-- Todas as cores derivam dos tons PARCHMENT / INK / BLOOD / STEEL / AGED_GOLD / MOSS / RUST.

local Palette = require("src.ui.Palette")

local Theme = {}

-- Helper: copia {r,g,b,a} e aplica alpha opcional
local function rgba(c, a)
    return { c[1], c[2], c[3], a or c[4] or 1 }
end

Theme.Colors = {
    -- Cores base (grimório dark)
    PRIMARY   = rgba(Palette.INK, 1),              -- Preto tinta (fundo principal)
    SECONDARY = rgba(Palette.TAROT_NAVY_DARK, 1),  -- Navy escuro (paineis)
    ACCENT    = rgba(Palette.AGED_GOLD, 1),        -- Dourado envelhecido
    ACCENT_SECONDARY = rgba(Palette.BLOOD, 1),     -- Vermelho sangue (alt)

    -- Cores de estado (grimório, não neon)
    SUCCESS = rgba(Palette.MOSS, 1),               -- Verde musgo
    WARNING = rgba(Palette.RUST, 1),               -- Laranja ferrugem
    ERROR   = rgba(Palette.BLOOD, 1),              -- Vermelho sangue
    INFO    = rgba(Palette.STEEL, 1),              -- Aço azulado

    -- Cores de texto
    TEXT_PRIMARY   = rgba(Palette.PARCHMENT_LIGHT, 1),  -- Bone white
    TEXT_SECONDARY = rgba(Palette.PARCHMENT, 1),        -- Bege envelhecido
    TEXT_DISABLED  = rgba(Palette.PARCHMENT_DARK, 1),   -- Marrom escuro

    -- Cores de interface
    UI_BACKGROUND = rgba(Palette.INK, 0.92),   -- Fundo UI semi-transparente
    UI_BORDER     = rgba(Palette.AGED_GOLD, 1),
    UI_HIGHLIGHT  = rgba(Palette.TAROT_NAVY, 1),

    -- Cores de cartas
    CARD_ATTACK  = rgba(Palette.BLOOD, 1),
    CARD_DEFENSE = rgba(Palette.STEEL, 1),
    CARD_JOKER   = rgba(Palette.AGED_GOLD, 1),

    -- Cores de barras (HUD)
    HEALTH_BAR = rgba(Palette.BLOOD, 1),
    ARMOR_BAR  = rgba(Palette.STEEL_LIGHT, 1),
    MANA_BAR   = rgba(Palette.AGED_GOLD, 1),
}

-- Gradientes profissionais
Theme.Gradients = {
    -- Gradiente de fundo principal
    BACKGROUND_MAIN = function(x, y, width, height)
        local colors = {
            {0.05, 0.05, 0.08, 1},      -- Topo: muito escuro
            {0.1, 0.1, 0.15, 1},        -- Meio: escuro
            {0.08, 0.08, 0.12, 1}       -- Base: escuro médio
        }
        return colors
    end,
    
    -- Gradiente de botões
    BUTTON_PRIMARY = function(x, y, width, height)
        local colors = {
            {0.2, 0.6, 0.2, 1},         -- Topo: verde claro
            {0.15, 0.5, 0.15, 1},       -- Meio: verde médio
            {0.1, 0.4, 0.1, 1}          -- Base: verde escuro
        }
        return colors
    end,
    
    -- Gradiente de cartas
    CARD_GLOW = function(x, y, width, height)
        local colors = {
            {0.8, 0.6, 0.2, 0.8},       -- Centro: dourado brilhante
            {0.6, 0.4, 0.1, 0.4},       -- Meio: dourado médio
            {0.4, 0.2, 0.05, 0.1}       -- Borda: dourado escuro
        }
        return colors
    end
}

-- Efeitos visuais
Theme.Effects = {
    -- Sombra padrão
    SHADOW = {
        offsetX = 4,
        offsetY = 4,
        blur = 8,
        color = {0, 0, 0, 0.3}
    },
    
    -- Brilho padrão
    GLOW = {
        intensity = 0.8,
        spread = 2,
        color = {0.8, 0.6, 0.2, 0.6}
    },
    
    -- Bordas arredondadas
    BORDER_RADIUS = 8,
    
    -- Transições suaves
    TRANSITION_SPEED = 0.15
}

-- Tipografia hierárquica
Theme.Typography = {
    -- Títulos principais
    TITLE_LARGE = {
        size = 48,
        weight = "bold",
        color = Theme.Colors.TEXT_PRIMARY
    },
    
    -- Títulos médios
    TITLE_MEDIUM = {
        size = 32,
        weight = "bold",
        color = Theme.Colors.TEXT_PRIMARY
    },
    
    -- Títulos pequenos
    TITLE_SMALL = {
        size = 24,
        weight = "bold",
        color = Theme.Colors.TEXT_PRIMARY
    },
    
    -- Texto do corpo
    BODY = {
        size = 16,
        weight = "normal",
        color = Theme.Colors.TEXT_SECONDARY
    },
    
    -- Texto pequeno
    CAPTION = {
        size = 12,
        weight = "normal",
        color = Theme.Colors.TEXT_DISABLED
    }
}

-- Funções utilitárias de design
Theme.Utils = {
    -- Desenha gradiente vertical
    drawVerticalGradient = function(x, y, width, height, colors)
        local segments = #colors
        local segmentHeight = height / segments
        
        for i = 1, segments do
            local color = colors[i]
            local segmentY = y + (i - 1) * segmentHeight
            local segmentHeightFinal = segmentHeight
            
            -- Último segmento pode ser maior para cobrir completamente
            if i == segments then
                segmentHeightFinal = height - (i - 1) * segmentHeight
            end
            
            love.graphics.setColor(color)
            love.graphics.rectangle("fill", x, segmentY, width, segmentHeightFinal)
        end
    end,
    
    -- Desenha gradiente radial
    drawRadialGradient = function(centerX, centerY, radius, innerColor, outerColor)
        local segments = 20
        local angleStep = (2 * math.pi) / segments
        
        for i = 1, segments do
            local angle1 = (i - 1) * angleStep
            local angle2 = i * angleStep
            
            -- Interpola cor baseada na distância
            local t1 = 0
            local t2 = 1
            
            local color1 = Theme.Utils.interpolateColor(innerColor, outerColor, t1)
            local color2 = Theme.Utils.interpolateColor(innerColor, outerColor, t2)
            
            -- Desenha segmento
            love.graphics.setColor(color1)
            love.graphics.polygon("fill", 
                centerX, centerY,
                centerX + math.cos(angle1) * radius, centerY + math.sin(angle1) * radius,
                centerX + math.cos(angle2) * radius, centerY + math.sin(angle2) * radius
            )
        end
    end,
    
    -- Interpola entre duas cores
    interpolateColor = function(color1, color2, t)
        -- Validação de segurança
        if not color1 or not color2 or type(color1) ~= "table" or type(color2) ~= "table" then
            return {1, 1, 1, 1} -- Cor padrão se algo der errado
        end
        
        -- Garante que as cores tenham 4 componentes (RGBA)
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
    
    -- Desenha sombra
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
    
    -- Desenha borda arredondada
    drawRoundedRectangle = function(x, y, width, height, color, borderColor)
        local radius = Theme.Effects.BORDER_RADIUS
        
        -- Preenchimento
        if color then
            love.graphics.setColor(color)
            love.graphics.rectangle("fill", x, y, width, height, radius, radius)
        end
        
        -- Borda
        if borderColor then
            love.graphics.setColor(borderColor)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x, y, width, height, radius, radius)
        end
    end,
    
    -- Desenha texto com sombra
    drawTextWithShadow = function(text, x, y, font, color, shadowColor)
        -- Sombra
        if shadowColor then
            love.graphics.setColor(shadowColor)
            love.graphics.print(text, x + 2, y + 2)
        end
        
        -- Texto principal
        love.graphics.setColor(color)
        love.graphics.print(text, x, y)
    end
}

return Theme
