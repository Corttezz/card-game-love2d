-- components/CreditsScreen.lua
-- Créditos do jogo (aberto pelo link "Créditos" no rodapé do menu).
--
-- Substitui o placeholder "Sobre" (known_gaps 6): jogo publicado na Steam
-- precisa dizer quem fez e de onde vêm motor/fonte/ferramentas de asset —
-- e a licença zlib do LÖVE e a SIL OFL da fonte PEDEM atribuição.
--
-- Conteúdo é DADO (CREDITS abaixo) apontando pra chaves i18n: papel e nome
-- vêm dos 5 locales (nome próprio repetido em cada um é intencional — a
-- convenção do projeto não deixa literal de UI no código).
--
-- Layout calculado A CADA draw a partir da tela atual: não há rect cacheado,
-- então resize é de graça (memory/resize_pattern.md). Se a lista não cabe,
-- a fonte encolhe (zona de conteúdo cede ESCALA, nunca posição).

local FontManager = require("src.ui.FontManager")
local Palette     = require("src.ui.Palette")
local Panel9      = require("src.ui.Panel9")
local I18n        = require("src.i18n.I18n")
local Sfx         = require("src.systems.Sfx")

local CreditsScreen = {}
CreditsScreen.__index = CreditsScreen

-- Ordem de exibição. Cada entrada: chave do papel + chave do nome.
CreditsScreen.CREDITS = {
    { role = "credits.role_design",   name = "credits.name_design" },
    { role = "credits.role_art",      name = "credits.name_art" },
    { role = "credits.role_audio",    name = "credits.name_audio" },
    { role = "credits.role_engine",   name = "credits.name_engine" },
    { role = "credits.role_font",     name = "credits.name_font" },
    { role = "credits.role_inspired", name = "credits.name_inspired" },
}

function CreditsScreen:new()
    local o = setmetatable({}, CreditsScreen)
    o.visible = false
    o.onClose = nil
    return o
end

function CreditsScreen:show(onClose)
    self.visible = true
    self._pressed = false
    self.onClose = onClose
    Sfx.play("menuOpen")
end

function CreditsScreen:hide()
    if not self.visible then return end
    self.visible = false
    local cb = self.onClose
    self.onClose = nil
    Sfx.play("menuClose")
    if cb then cb() end
end

function CreditsScreen:isVisible() return self.visible end
function CreditsScreen:update(dt) end
function CreditsScreen:resize() end

function CreditsScreen:panelRect()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local pw = math.min(720, math.floor(sw * 0.90))
    local ph = math.min(640, math.floor(sh * 0.90))
    return math.floor((sw - pw) / 2), math.floor((sh - ph) / 2), pw, ph
end

-- Mede o bloco com uma escala de fonte; devolve altura total + fontes.
local function measure(innerW, roleSize, nameSize)
    local rf, nf = FontManager.getFont(roleSize), FontManager.getFont(nameSize)
    local h = 0
    for _, c in ipairs(CreditsScreen.CREDITS) do
        local _, rl = rf:getWrap(I18n.t(c.role), innerW)
        local _, nl = nf:getWrap(I18n.t(c.name), innerW)
        h = h + #rl * rf:getHeight() + 6 + #nl * nf:getHeight() * 1.2 + 18
    end
    return h, rf, nf
end

-- Layout puro (sem desenhar) — usado pelo draw e pelo teste de geometria.
function CreditsScreen:layout()
    local px, py, pw, ph = self:panelRect()
    local innerW = pw - 80
    local titleF = FontManager.getFont(ph < 480 and 16 or 20)
    local hintF = FontManager.getFont(8)
    local top = py + 34 + titleF:getHeight() + 22
    local bottom = py + ph - 34 - hintF:getHeight() - 26 - FontManager.getFont(11):getHeight()
    local avail = bottom - top
    local roleSize, nameSize = 9, 13
    local h, rf, nf = measure(innerW, roleSize, nameSize)
    while h > avail and nameSize > 8 do
        nameSize = nameSize - 1
        roleSize = math.max(7, roleSize - 1)
        h, rf, nf = measure(innerW, roleSize, nameSize)
    end
    return {
        px = px, py = py, pw = pw, ph = ph, innerW = innerW,
        titleF = titleF, hintF = hintF, roleF = rf, nameF = nf,
        top = top, listH = h, bottom = bottom,
    }
end

function CreditsScreen:draw()
    if not self.visible then return end
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0.04, 0.03, 0.02, 0.82)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    local L = self:layout()
    Panel9.draw("panel_main", L.px, L.py, L.pw, L.ph)
    local cx = L.px + L.pw / 2

    -- Título
    local title = I18n.t("credits.title")
    love.graphics.setFont(L.titleF)
    Palette.set(Palette.INK)
    love.graphics.print(title, math.floor(cx - L.titleF:getWidth(title) / 2), L.py + 34)
    Palette.set(Palette.AGED_GOLD_DARK or Palette.RUST)
    love.graphics.rectangle("fill", L.px + 60, L.top - 12, L.pw - 120, 1)

    -- Lista centralizada verticalmente na zona de conteúdo.
    local y = L.top + math.max(0, math.floor((L.bottom - L.top - L.listH) / 2))
    for _, c in ipairs(self.CREDITS) do
        love.graphics.setFont(L.roleF)
        Palette.set(Palette.RUST)
        local _, rl = L.roleF:getWrap(I18n.t(c.role), L.innerW)
        for _, line in ipairs(rl) do
            love.graphics.print(line, math.floor(cx - L.roleF:getWidth(line) / 2), math.floor(y))
            y = y + L.roleF:getHeight()
        end
        y = y + 6
        love.graphics.setFont(L.nameF)
        Palette.set(Palette.INK)
        local _, nl = L.nameF:getWrap(I18n.t(c.name), L.innerW)
        for _, line in ipairs(nl) do
            love.graphics.print(line, math.floor(cx - L.nameF:getWidth(line) / 2), math.floor(y))
            y = y + L.nameF:getHeight() * 1.2
        end
        y = y + 18
    end

    -- Agradecimento + dica de saída (zona de rodapé, fixa).
    local thanks = I18n.t("credits.thanks")
    local tf = FontManager.getFont(11)
    love.graphics.setFont(tf)
    Palette.set(Palette.BLOOD or Palette.RUST)
    love.graphics.print(thanks, math.floor(cx - tf:getWidth(thanks) / 2),
        L.py + L.ph - 34 - L.hintF:getHeight() - 12 - tf:getHeight())
    local hint = I18n.t("credits.hint")
    love.graphics.setFont(L.hintF)
    Palette.set(Palette.RUST)
    love.graphics.print(hint, math.floor(cx - L.hintF:getWidth(hint) / 2),
        L.py + L.ph - 34 - L.hintF:getHeight())
    love.graphics.setColor(1, 1, 1, 1)
end

function CreditsScreen:keypressed(key)
    if not self.visible then return false end
    if key == "escape" or key == "return" or key == "space" then self:hide() end
    return true
end

-- Qualquer clique fecha (tela de leitura, sem nada clicável dentro) — mas
-- só um clique INTEIRO dado aqui: o release do clique que ABRIU a tela (o
-- press foi no link do menu) não pode fechá-la no mesmo instante.
function CreditsScreen:mousepressed(x, y, button)
    if not self.visible then return false end
    self._pressed = true
    return true
end

function CreditsScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    if self._pressed then
        self._pressed = false
        self:hide()
    end
    return true
end

return CreditsScreen
