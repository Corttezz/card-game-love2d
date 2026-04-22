-- src/ui/ManaOrb.lua
-- Orb circular de mana estilo Balatro (money) / Slay the Spire (energy orb).
-- Posicionado bottom-right, mais perto do botão Jogar que o painel do canto,
-- encurtando o loop de feedback "olha mana → olha carta → joga".

local FontManager = require("src.ui.FontManager")
local Palette = require("src.ui.Palette")
local Config = require("src.core.Config")
local ValueEasing = require("src.ui.ValueEasing")

local ManaOrb = {}
ManaOrb.__index = ManaOrb

local RADIUS = 44

function ManaOrb:new()
    local instance = setmetatable({}, ManaOrb)
    instance.x = 0
    instance.y = 0
    instance.radius = RADIUS
    instance.animTime = 0
    instance.lastMana = nil
    instance.spendFlash = 0 -- 0..1, flash rápido quando mana cai
    instance.gainFlash = 0  -- 0..1, flash suave quando restaura
    instance.disp = {}       -- tabela de display values eased (ValueEasing)
    return instance
end

function ManaOrb:update(dt, player)
    self.animTime = self.animTime + dt
    if self.spendFlash > 0 then self.spendFlash = math.max(0, self.spendFlash - dt * 4) end
    if self.gainFlash > 0 then self.gainFlash = math.max(0, self.gainFlash - dt * 2) end
    -- Ease display do valor de mana toward real. Orb renderiza disp pra
    -- feedback visual suave (Balatro ease_mana style).
    if player then
        ValueEasing.tick(self.disp, "mana", player.mana or 0, dt, 12)
    end
end

function ManaOrb:updatePosition()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    -- Canto inferior direito, margem maior que o painel da esquerda
    -- pra não colidir com a mão de cartas (cartas vão até ~90% do width).
    self.x = sw - Config.Utils.getResponsiveSize(0.05, 50, "width")
    self.y = sh - Config.Utils.getResponsiveSize(0.06, 55, "height")
end

local function setColor(c, a)
    love.graphics.setColor(c[1], c[2], c[3], a or c[4] or 1)
end

function ManaOrb:draw(player)
    if not player then return end
    -- Valor real pra detecção de flash (evento instantâneo) e valor eased
    -- pra exibição numérica + preenchimento do orb.
    local actual = player.mana or 0
    local cur = self.disp.mana or actual
    local maxMana = player.maxMana or 3

    -- Detecta mudanças pra flash (baseado no REAL, não no eased)
    if self.lastMana ~= nil then
        if actual < self.lastMana then
            self.spendFlash = 1
        elseif actual > self.lastMana then
            self.gainFlash = 1
        end
    end
    self.lastMana = actual

    local cx, cy = self.x, self.y
    local r = self.radius

    -- Sombra no chão
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.ellipse("fill", cx, cy + r + 2, r * 0.8, 4)

    -- Halo externo pulsante (mais forte quando há mana disponível)
    local availability = (cur > 0) and 1 or 0.35
    local pulse = 0.75 + math.sin(self.animTime * 2.5) * 0.25
    love.graphics.setColor(0.30, 0.55, 0.95, 0.25 * pulse * availability)
    love.graphics.circle("fill", cx, cy, r + 8)

    -- Flash de gasto (vermelho rápido) ou ganho (verde suave)
    if self.spendFlash > 0 then
        love.graphics.setColor(0.9, 0.2, 0.2, self.spendFlash * 0.5)
        love.graphics.circle("fill", cx, cy, r + 4)
    elseif self.gainFlash > 0 then
        love.graphics.setColor(0.4, 0.9, 1.0, self.gainFlash * 0.35)
        love.graphics.circle("fill", cx, cy, r + 4)
    end

    -- Fundo escuro do orb
    love.graphics.setColor(0.05, 0.08, 0.18, 0.98)
    love.graphics.circle("fill", cx, cy, r)

    -- Fluido interno azul (gradient fake via círculos concêntricos)
    local manaPct = math.max(0, math.min(1, cur / maxMana))
    if manaPct > 0 then
        -- Círculo interno vivo
        love.graphics.setColor(0.20, 0.42, 0.92, 0.90 * availability)
        love.graphics.circle("fill", cx, cy, r * (0.55 + 0.25 * manaPct))

        -- Highlight lunar
        love.graphics.setColor(0.75, 0.90, 1.0, 0.55 * availability)
        love.graphics.circle("fill", cx - r * 0.25, cy - r * 0.35, r * 0.18)
    end

    -- Moldura dourada envelhecida
    setColor(Palette.AGED_GOLD_DARK, 1)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", cx, cy, r)
    setColor(Palette.AGED_GOLD, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", cx, cy, r - 2)

    -- Outline tinta pra separar do fundo
    setColor(Palette.INK, 1)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", cx, cy, r + 2)
    love.graphics.setLineWidth(1)

    -- Tipografia empilhada com gap: número atual grande em cima, /max médio abaixo.
    -- Sem overlap. Fonte reduzida (32→26) pra caber no orb r=44 com margem.
    local bigFont = FontManager.getResponsiveFont(0.04, 26)
    local smallFont = FontManager.getResponsiveFont(0.025, 14)

    local curTxt = tostring(math.floor(cur + 0.001))
    love.graphics.setFont(bigFont)
    local bw = bigFont:getWidth(curTxt)
    local bh = bigFont:getHeight()

    local maxTxt = "/" .. maxMana
    love.graphics.setFont(smallFont)
    local sw2 = smallFont:getWidth(maxTxt)
    local sh2 = smallFont:getHeight()

    -- Bloco total (número + gap 3px + /max) centralizado verticalmente
    local gap = 3
    local blockH = bh + gap + sh2
    local topY = math.floor(cy - blockH / 2)

    -- Número principal (branco, outline preto com diagonais pra ler sobre o azul)
    love.graphics.setFont(bigFont)
    local numTx = math.floor(cx - bw / 2)
    FontManager.drawWithOutline(curTxt, numTx, topY, { 1, 1, 1, 1 }, 0.9, true)

    -- /max (azul claro saturado, outline preto, com gap acima)
    love.graphics.setFont(smallFont)
    local maxY = topY + bh + gap
    local maxTx = math.floor(cx - sw2 / 2)
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.print(maxTxt, maxTx + 1, maxY + 1)
    love.graphics.setColor(0.80, 0.92, 1.0, 1)
    love.graphics.print(maxTxt, maxTx, maxY)

    love.graphics.setColor(1, 1, 1, 1)
end

return ManaOrb
