-- src/VisualEffects.lua
-- Sistema de efeitos visuais avançados para UI profissional

local VisualEffects = {}

-- Shader para glow/brilho
local glowShader = [[
    extern vec2 screen;
    extern float intensity;
    extern vec3 glowColor;
    
    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
    {
        vec4 pixel = Texel(tex, texture_coords);
        vec2 uv = screen_coords / screen;
        
        // Efeito de glow radial
        float dist = length(uv - vec2(0.5));
        float glow = smoothstep(0.5, 0.0, dist) * intensity;
        
        // Combina cor original com glow
        vec3 finalColor = pixel.rgb + glowColor * glow;
        float alpha = max(pixel.a, glow);
        
        return vec4(finalColor, alpha);
    }
]]

-- Shader para distorção de ondas
local waveShader = [[
    extern float time;
    extern float amplitude;
    extern float frequency;
    
    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
    {
        vec2 uv = texture_coords;
        uv.y += sin(uv.x * frequency + time) * amplitude;
        
        return Texel(tex, uv) * color;
    }
]]

-- Shader para gradiente radial
local radialGradientShader = [[
    extern vec2 center;
    extern vec3 color1;
    extern vec3 color2;
    extern float radius;
    
    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
    {
        vec2 uv = texture_coords;
        float dist = length(uv - center);
        float t = smoothstep(0.0, radius, dist);
        
        vec3 finalColor = mix(color1, color2, t);
        return vec4(finalColor, 1.0);
    }
]]

-- Funções de utilidade para efeitos visuais
VisualEffects.Utils = {}

-- Desenha retângulo com bordas arredondadas e sombra
function VisualEffects.Utils.drawRoundedRectangleWithShadow(x, y, width, height, radius, fillColor, shadowColor, shadowOffset)
    shadowOffset = shadowOffset or 8
    
    -- Sombra
    if shadowColor then
        love.graphics.setColor(shadowColor)
        love.graphics.rectangle("fill", x + shadowOffset, y + shadowOffset, width, height, radius, radius)
    end
    
    -- Retângulo principal
    love.graphics.setColor(fillColor)
    love.graphics.rectangle("fill", x, y, width, height, radius, radius)
end

-- Desenha retângulo com borda gradiente
function VisualEffects.Utils.drawRoundedRectangleWithGradientBorder(x, y, width, height, radius, fillColor, borderColors, borderWidth)
    borderWidth = borderWidth or 3
    
    -- Preenchimento
    love.graphics.setColor(fillColor)
    love.graphics.rectangle("fill", x, y, width, height, radius, radius)
    
    -- Borda gradiente
    if borderColors and #borderColors >= 2 then
        local segments = 8
        for i = 1, segments do
            local t = (i - 1) / (segments - 1)
            local color = VisualEffects.Utils.interpolateColors(borderColors[1], borderColors[2], t)
            
            love.graphics.setColor(color)
            love.graphics.setLineWidth(borderWidth)
            love.graphics.rectangle("line", x, y, width, height, radius, radius)
        end
    end
end

-- Desenha círculo com glow
function VisualEffects.Utils.drawCircleWithGlow(x, y, radius, fillColor, glowColor, glowIntensity)
    glowIntensity = glowIntensity or 0.5
    
    -- Glow externo
    if glowColor and glowIntensity > 0 then
        love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], glowColor[4] * glowIntensity)
        love.graphics.circle("fill", x, y, radius + 10)
        love.graphics.circle("fill", x, y, radius + 5)
    end
    
    -- Círculo principal
    love.graphics.setColor(fillColor)
    love.graphics.circle("fill", x, y, radius)
end

-- Desenha texto com sombra e glow
function VisualEffects.Utils.drawTextWithEffects(text, x, y, font, textColor, shadowColor, glowColor, glowIntensity)
    font = font or love.graphics.getFont()
    glowIntensity = glowIntensity or 0
    
    -- Glow
    if glowColor and glowIntensity > 0 then
        love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], glowColor[4] * glowIntensity)
        for i = 1, 8 do
            local angle = (i - 1) * math.pi / 4
            local offsetX = math.cos(angle) * 3
            local offsetY = math.sin(angle) * 3
            love.graphics.setFont(font)
            love.graphics.print(text, x + offsetX, y + offsetY)
        end
    end
    
    -- Sombra
    if shadowColor then
        love.graphics.setColor(shadowColor)
        love.graphics.setFont(font)
        love.graphics.print(text, x + 2, y + 2)
    end
    
    -- Texto principal
    love.graphics.setColor(textColor)
    love.graphics.setFont(font)
    love.graphics.print(text, x, y)
end

-- Desenha gradiente radial
function VisualEffects.Utils.drawRadialGradient(x, y, width, height, centerColor, edgeColor)
    local segments = 16
    local centerX = x + width / 2
    local centerY = y + height / 2
    local maxRadius = math.max(width, height) / 2
    
    for i = 1, segments do
        local t = (i - 1) / (segments - 1)
        local radius = maxRadius * t
        local color = VisualEffects.Utils.interpolateColors(centerColor, edgeColor, t)
        
        love.graphics.setColor(color)
        love.graphics.circle("fill", centerX, centerY, radius)
    end
end

-- Desenha gradiente linear
function VisualEffects.Utils.drawLinearGradient(x, y, width, height, startColor, endColor, direction)
    direction = direction or "vertical"
    local segments = 8
    
    if direction == "vertical" then
        local segmentHeight = height / segments
        for i = 1, segments do
            local t = (i - 1) / (segments - 1)
            local color = VisualEffects.Utils.interpolateColors(startColor, endColor, t)
            
            love.graphics.setColor(color)
            love.graphics.rectangle("fill", x, y + (i - 1) * segmentHeight, width, segmentHeight)
        end
    else -- horizontal
        local segmentWidth = width / segments
        for i = 1, segments do
            local t = (i - 1) / (segments - 1)
            local color = VisualEffects.Utils.interpolateColors(startColor, endColor, t)
            
            love.graphics.setColor(color)
            love.graphics.rectangle("fill", x + (i - 1) * segmentWidth, y, segmentWidth, height)
        end
    end
end

-- Interpolação de cores
function VisualEffects.Utils.interpolateColors(color1, color2, t)
    return {
        color1[1] + (color2[1] - color1[1]) * t,
        color1[2] + (color2[2] - color1[2]) * t,
        color1[3] + (color2[3] - color1[3]) * t,
        color1[4] + (color2[4] - color1[4]) * t
    }
end

-- Desenha retângulo com borda animada
function VisualEffects.Utils.drawAnimatedBorder(x, y, width, height, radius, borderColor, time, speed)
    speed = speed or 2
    local borderWidth = 3
    
    -- Calcula offset da animação
    local offset = math.sin(time * speed) * 2
    
    -- Desenha borda animada
    love.graphics.setColor(borderColor)
    love.graphics.setLineWidth(borderWidth)
    
    -- Borda superior com animação
    love.graphics.line(x + offset, y, x + width - offset, y)
    
    -- Borda direita
    love.graphics.line(x + width, y, x + width, y + height)
    
    -- Borda inferior com animação
    love.graphics.line(x + width - offset, y + height, x + offset, y + height)
    
    -- Borda esquerda
    love.graphics.line(x, y + height, x, y)
end

-- Desenha retângulo com efeito de vidro
function VisualEffects.Utils.drawGlassRectangle(x, y, width, height, radius, baseColor, transparency)
    transparency = transparency or 0.3
    
    -- Sombra sutil
    love.graphics.setColor(0, 0, 0, 0.2)
    love.graphics.rectangle("fill", x + 2, y + 2, width, height, radius, radius)
    
    -- Base principal
    local glassColor = {
        baseColor[1] * 0.8,
        baseColor[2] * 0.8,
        baseColor[3] * 0.8,
        transparency
    }
    love.graphics.setColor(glassColor)
    love.graphics.rectangle("fill", x, y, width, height, radius, radius)
    
    -- Brilho superior
    local highlightColor = {
        1, 1, 1, 0.1
    }
    love.graphics.setColor(highlightColor)
    love.graphics.rectangle("fill", x, y, width, height / 3, radius, radius)
end

-- Desenha ícone com efeitos
function VisualEffects.Utils.drawIconWithEffects(x, y, size, iconType, color, glowColor, glowIntensity)
    glowIntensity = glowIntensity or 0.3
    
    -- Glow
    if glowColor and glowIntensity > 0 then
        love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], glowColor[4] * glowIntensity)
        love.graphics.circle("fill", x, y, size + 5)
    end
    
    -- Ícone principal
    love.graphics.setColor(color)
    
    if iconType == "star" then
        VisualEffects.Utils.drawStar(x, y, size, size * 0.5)
    elseif iconType == "diamond" then
        VisualEffects.Utils.drawDiamond(x, y, size)
    elseif iconType == "circle" then
        love.graphics.circle("fill", x, y, size)
    end
end

-- Desenha estrela
function VisualEffects.Utils.drawStar(centerX, centerY, outerRadius, innerRadius)
    local points = 5
    local vertices = {}
    
    for i = 0, points * 2 - 1 do
        local angle = i * math.pi / points
        local radius = i % 2 == 0 and outerRadius or innerRadius
        local x = centerX + math.cos(angle) * radius
        local y = centerY + math.sin(angle) * radius
        table.insert(vertices, x)
        table.insert(vertices, y)
    end
    
    love.graphics.polygon("fill", vertices)
end

-- Desenha diamante
function VisualEffects.Utils.drawDiamond(centerX, centerY, size)
    local vertices = {
        centerX, centerY - size,
        centerX + size, centerY,
        centerX, centerY + size,
        centerX - size, centerY
    }
    
    love.graphics.polygon("fill", vertices)
end

-- Efeitos de partículas para UI
VisualEffects.Particles = {}

-- Partículas de energia
function VisualEffects.Particles.energyParticles(x, y, count, color, time)
    count = count or 10
    color = color or {1, 1, 1, 1}
    
    for i = 1, count do
        local angle = (i / count) * math.pi * 2 + time
        local radius = 20 + math.sin(time * 3 + i) * 10
        local px = x + math.cos(angle) * radius
        local py = y + math.sin(angle) * radius
        local alpha = 0.5 + math.sin(time * 2 + i) * 0.5
        
        love.graphics.setColor(color[1], color[2], color[3], color[4] * alpha)
        love.graphics.circle("fill", px, py, 2)
    end
end

-- Partículas de sparkle
function VisualEffects.Particles.sparkleParticles(x, y, count, color, time)
    count = count or 8
    color = color or {1, 1, 1, 1}
    
    for i = 1, count do
        local angle = (i / count) * math.pi * 2 + time * 2
        local radius = 15 + math.sin(time * 4 + i) * 8
        local px = x + math.cos(angle) * radius
        local py = y + math.sin(angle) * radius
        local alpha = 0.3 + math.sin(time * 3 + i) * 0.7
        local size = 1 + math.sin(time * 5 + i) * 2
        
        love.graphics.setColor(color[1], color[2], color[3], color[4] * alpha)
        love.graphics.rectangle("fill", px - size/2, py - size/2, size, size)
    end
end

-- Sistema de partículas para efeitos especiais
VisualEffects.Particles = {
    -- Efeito de seleção de carta
    createCardSelectEffect = function(x, y)
        -- Efeito visual simples quando carta é selecionada
        -- Por enquanto, apenas um placeholder
        love.graphics.setColor(1, 1, 0, 0.5)
        love.graphics.circle("fill", x, y, 50)
    end,
    
    -- Partículas de energia
    energyParticles = function(x, y, count, color, time)
        count = count or 5
        color = color or {1, 0.8, 0.2, 0.6}
        time = time or 0
        
        for i = 1, count do
            local angle = (i / count) * math.pi * 2 + time
            local radius = 15 + math.sin(time * 4 + i) * 8
            local px = x + math.cos(angle) * radius
            local py = y + math.sin(angle) * radius
            local alpha = 0.3 + math.sin(time * 3 + i) * 0.3
            local size = 2 + math.sin(time * 5 + i) * 1
            
            love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
            love.graphics.circle("fill", px, py, size)
        end
    end,
    
    -- Partículas de sparkle
    sparkleParticles = function(x, y, count, color, time)
        count = count or 8
        color = color or {1, 1, 1, 0.8}
        time = time or 0
        
        for i = 1, count do
            local angle = (i / count) * math.pi * 2 + time * 2
            local radius = 20 + math.sin(time * 6 + i) * 10
            local px = x + math.cos(angle) * radius
            local py = y + math.sin(angle) * radius
            local alpha = 0.4 + math.sin(time * 4 + i) * 0.4
            local size = 1 + math.sin(time * 8 + i) * 0.5
            
            love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
            love.graphics.rectangle("fill", px - size/2, py - size/2, size, size)
        end
    end
}

return VisualEffects

