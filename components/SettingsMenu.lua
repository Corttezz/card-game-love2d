-- components/SettingsMenu.lua
-- CONFIGURAÇÕES — overlay modal aberto pelo menu principal ou pela PAUSA.
--
-- v3 (Out/2026 — "seguir o padrão de hoje"). Estrutura do create_UIBox_settings
-- do Balatro (functions/UI_definitions.lua:2265): ABAS com conteúdo de altura
-- FIXA (o painel não pula ao trocar de aba — tab_h do Balatro) e um botão
-- VOLTAR que devolve pra quem abriu (back_func = 'options': aberto da pausa,
-- volta pra pausa; aberto do menu, fecha).
--
--   ÁUDIO   Geral · Música · Efeitos                          (sliders 0-100%)
--   VÍDEO   Tela cheia · VSync · Shader CRT · Iluminação       (toggles)
--   JOGO    Ritmo do combate · Tremor de tela · Movimento reduzido
--   IDIOMA  os 5 idiomas pelo nome nativo — 1 clique/Enter escolhe
--
-- Todo controle de ajuste tem a MESMA forma: [<] valor [>] — o "option
-- cycle" do Balatro (←/→ ajusta, ↑/↓ escolhe a linha, Tab/Q/E troca aba,
-- ESC volta). O IDIOMA não: no ciclo o dono tinha que passar idioma por
-- idioma até chegar no seu (Out/2026, "piorou"). Agora é lista direta com
-- o atual aceso, numa aba própria — não o dropdown da v2, que abria pra
-- fora do painel em janela pequena.
--
-- Visual: painel escuro-dourado canônico (UiPanel) + título dourado, igual à
-- pausa/loja/roteiro. A v2 misturava o OSD âmbar de TV com os botões sépia
-- ("dois dialetos na mesma tela") e tinha linhas de altura FIXA que, em
-- 800x600, punham o botão FECHAR por cima da linha do Idioma.
--
-- Persistência: toda mudança grava via engine/SaveManager.saveSettings e
-- espelha em _G.gameSettings (lido por ScreenShake/Moveable/WorldRoad).
-- SettingsMenu.applyRuntime(settings) aplica no boot o que não vive em
-- módulo próprio (ritmo do combate, vsync).

local FontManager = require("src.ui.FontManager")
local Palette     = require("src.ui.Palette")
local CRTShader   = require("src.ui.CRTShader")
local I18n        = require("src.i18n.I18n")
local SaveManager = require("engine.SaveManager")
local Sfx         = require("src.systems.Sfx")
local Button      = require("components.Button")
local UiPanel     = require("src.ui.UiPanel")
local TextFit     = require("src.ui.TextFit")
local MenuKit     = require("src.ui.MenuKit")

local SettingsMenu = {}
SettingsMenu.__index = SettingsMenu
-- navega sozinha (MenuKit): o cursor de foco do teclado/pad não toma as teclas
SettingsMenu.ownsNavigation = true

local STEP = 0.1   -- passo dos sliders (10%)

-- Ritmo do combate: multiplicador de VELOCIDADE exibido ao jogador. O
-- CombatBeats.speed é multiplicador de DURAÇÃO, então speed = 1 / x.
SettingsMenu.COMBAT_SPEEDS = { 1, 1.5, 2, 3 }

-- Métricas
local PAD       = 22
local TITLE_H   = 50
local TAB_H     = 32
local ROW_H     = 40
local ROW_GAP   = 6
local ZONE_GAP  = 12
local BACK_H    = 36
local ARROW_W   = 28

-- Escala do painel (padrão das EndScreens/pausa): 768 de altura = 1, até
-- 1.75 em telas grandes. Uma instância visível por vez, então mora no módulo
-- e o rebuild a atualiza; S() vale pra layout E desenho.
local U = 1
local function S(v) return math.floor(v * U + 0.5) end
local MAX_ROWS  = 5   -- a aba Idioma tem 5 linhas

-- Selo curto ao lado do nome nativo (código, não bandeira: idioma não é país).
local LANG_BADGE = { pt_BR = "PT", en = "EN", es = "ES", fr = "FR", de = "DE" }

-- ===================================================================
-- RUNTIME (estático): aplica settings que não moram em módulo próprio.
-- ===================================================================
local function speedLabel(x)
    if x == math.floor(x) then return ("%dx"):format(x) end
    return ("%.1fx"):format(x)
end

function SettingsMenu.applyRuntime(settings)
    settings = settings or _G.gameSettings or {}
    local x = tonumber(settings.combatSpeed) or 1
    if x <= 0 then
        print("[SettingsMenu] combatSpeed invalido (" .. tostring(settings.combatSpeed) .. "), usando 1")
        x = 1
    end
    require("src.systems.CombatBeats").speed = 1 / x
    require("src.ui.UiScale").setUserMultiplier(settings.uiScale or 1)
    -- VSync: só fora das ferramentas (captura tem que ser reproduzível).
    if not _G.HEADLESS_TOOL and settings.vsync ~= nil
        and love.window and love.window.setVSync then
        local ok, err = pcall(love.window.setVSync, settings.vsync and 1 or 0)
        if not ok then print("[SettingsMenu] setVSync falhou: " .. tostring(err)) end
    end
end

local function gs()
    _G.gameSettings = _G.gameSettings or {}
    return _G.gameSettings
end

local function clamp01(v) return math.max(0, math.min(1, v)) end
local function round1(v) return math.floor(v * 10 + 0.5) / 10 end

-- ===== volumes (AudioManager quando há áudio; gameSettings sempre) =====
local VOL_FIELD = { master = "masterVolume", music = "musicVolume", sfx = "sfxVolume",
                    ambient = "ambientVolume" }
local VOL_DEFAULT = { master = 1.0, music = 0.3, sfx = 0.7, ambient = 1.0 }

local function getVolume(kind)
    local a = _G.audioSystem
    if a then
        if kind == "music" then return a.musicVolume or 0 end
        if kind == "sfx" then return a.sfxVolume or 0 end
        if kind == "ambient" then return a.ambientVolume or VOL_DEFAULT.ambient end
        return a.volume or 0
    end
    local v = gs()[VOL_FIELD[kind]]
    if v == nil then v = VOL_DEFAULT[kind] end
    return v
end

local function setVolume(kind, v)
    v = round1(clamp01(v))
    gs()[VOL_FIELD[kind]] = v
    local a = _G.audioSystem
    if a then
        if kind == "music" then a:setMusicVolume(v)
        elseif kind == "sfx" then a:setSFXVolume(v)
        elseif kind == "ambient" then a:setAmbientVolume(v)
        else a:setVolume(v) end
    end
    -- AMOSTRA no volume novo: a música se ouve sozinha (já está tocando);
    -- sfx/master tocam um clique pelo próprio grupo ajustado.
    if kind ~= "music" and kind ~= "ambient" then   -- ambiente se ouve sozinho (cama tocando)
        Sfx.play("buttonClick", { pitch = 1.0 + v * 0.12 })
    end
end

local function getVSync()
    if love.window and love.window.getVSync then
        local ok, v = pcall(love.window.getVSync)
        if ok then return v ~= 0 end
    end
    return gs().vsync ~= false
end

local function speedIndex()
    local cur = tonumber(gs().combatSpeed) or 1
    for i, v in ipairs(SettingsMenu.COMBAT_SPEEDS) do
        if math.abs(v - cur) < 0.01 then return i end
    end
    return 1
end

-- ===================================================================
-- DEFINIÇÃO DAS ABAS (dados → linhas). Cada linha:
--   kind  "slider" | "toggle" | "cycle"
--   get() → valor (slider 0..1, toggle bool, cycle texto)
--   step(dir) muda um passo (dir = -1/+1); slider também tem set(v)
-- ===================================================================
-- Uma linha "choice" por idioma: get() = é o atual?; step() = escolhe.
-- I18n.setLocale já persiste (I18n.saveSetting); o snapshot do _persist
-- leva o locale junto pro settings.
local function languageRows(menu)
    local rows = {}
    for _, code in ipairs(I18n.getAvailable()) do
        rows[#rows + 1] = { key = "lang_" .. code, kind = "choice", code = code,
            label = I18n.getLabel(code), badge = LANG_BADGE[code] or code:upper(),
            get = function() return I18n.getLocale() == code end,
            step = function()
                if I18n.getLocale() == code then return end
                if I18n.setLocale(code) then
                    gs().locale = code
                    FontManager.clearCache()
                    menu:rebuild()   -- rótulos no idioma novo
                else
                    print("[SettingsMenu] idioma indisponivel: " .. tostring(code))
                end
            end }
    end
    return rows
end

function SettingsMenu:_tabs()
    local menu = self
    local function volRow(kind, labelKey)
        return { key = "vol_" .. kind, kind = "slider", label = I18n.t(labelKey),
            get = function() return getVolume(kind) end,
            set = function(v) setVolume(kind, v) end,
            step = function(dir) setVolume(kind, getVolume(kind) + dir * STEP) end }
    end
    local function toggle(key, labelKey, get, set)
        return { key = key, kind = "toggle", label = I18n.t(labelKey),
            get = get, step = function() set(not get()) end }
    end
    return {
        { key = "audio", label = I18n.t("settings.tab_audio"), rows = {
            volRow("master", "settings.master"),
            volRow("music", "settings.music"),
            volRow("sfx", "settings.sfx"),
            volRow("ambient", "settings.ambient"),
        } },
        { key = "video", label = I18n.t("settings.tab_video"), rows = {
            toggle("fullscreen", "settings.fullscreen",
                function() return love.window.getFullscreen() end,
                function(v)
                    love.window.setFullscreen(v)
                    gs().fullscreen = v
                    FontManager.clearCache()
                    -- love.resize reposiciona TODAS as telas (inclusive esta).
                    if love.resize then
                        local UiScale = require("src.ui.UiScale")
                        UiScale.outside(love.resize, UiScale.realDimensions())
                    else
                        menu:rebuild()
                    end
                end),
            toggle("vsync", "settings.vsync", getVSync,
                function(v)
                    gs().vsync = v
                    if love.window and love.window.setVSync then
                        local ok, err = pcall(love.window.setVSync, v and 1 or 0)
                        if not ok then print("[SettingsMenu] setVSync falhou: " .. tostring(err)) end
                    end
                end),
            { key = "ui_scale", kind = "cycle", label = I18n.t("settings.ui_scale"),
              get = function()
                  local m = tonumber(gs().uiScale) or 1
                  if math.abs(m - 1) < 0.01 then return I18n.t("settings.ui_scale_auto") end
                  return ("%d%%"):format(math.floor(m * 100 + 0.5))
              end,
              step = function(dir)
                  local opts = require("src.ui.UiScale").OPTIONS
                  local cur, idx = tonumber(gs().uiScale) or 1, 1
                  for i, v in ipairs(opts) do
                      if math.abs(v - cur) < 0.01 then idx = i end
                  end
                  idx = math.max(1, math.min(#opts, idx + dir))   -- sem dar a volta: é um tamanho
                  gs().uiScale = opts[idx]
                  require("src.ui.UiScale").setUserMultiplier(opts[idx])
                  FontManager.clearCache()
                  -- love.resize reposiciona TODAS as telas no espaço novo
                  if love.resize then
                      local UiScale = require("src.ui.UiScale")
                      UiScale.outside(love.resize, UiScale.realDimensions())
                  else
                      menu:rebuild()
                  end
              end },
            toggle("crt", "settings.crt_shader",
                function() return CRTShader.isEnabled() end,
                function(v) CRTShader.setEnabled(v); gs().crtShader = v end),
            toggle("lighting", "settings.lighting",
                function() return gs().lighting ~= false end,
                function(v) gs().lighting = v end),
        } },
        { key = "game", label = I18n.t("settings.tab_game"), rows = {
            { key = "combat_speed", kind = "cycle", label = I18n.t("settings.combat_speed"),
              get = function() return speedLabel(SettingsMenu.COMBAT_SPEEDS[speedIndex()]) end,
              step = function(dir)
                  local n = #SettingsMenu.COMBAT_SPEEDS
                  local i = ((speedIndex() - 1 + dir) % n) + 1
                  gs().combatSpeed = SettingsMenu.COMBAT_SPEEDS[i]
                  SettingsMenu.applyRuntime(gs())
              end },
            { key = "screenshake", kind = "slider", label = I18n.t("settings.screenshake"),
              get = function() return gs().screenshake or 1.0 end,
              set = function(v) gs().screenshake = round1(clamp01(v)) end,
              step = function(dir)
                  gs().screenshake = round1(clamp01((gs().screenshake or 1.0) + dir * STEP))
              end },
            toggle("reduced_motion", "settings.reduced_motion",
                function() return gs().reducedMotion and true or false end,
                function(v) gs().reducedMotion = v end),
        } },
        { key = "language", label = I18n.t("settings.language"), rows = languageRows(menu) },
    }
end

-- ===================================================================
-- CICLO DE VIDA
-- ===================================================================
function SettingsMenu:new()
    local instance = setmetatable({}, SettingsMenu)
    instance.visible = false
    instance.tab = 1
    instance.focus = 1          -- linha focada (1..#rows; #rows+1 = VOLTAR)
    instance.rows = {}
    instance.tabs = {}
    instance.onClose = nil
    instance._t = 0
    return instance
end

-- opts.onClose: chamado ao VOLTAR (a pausa usa pra se reabrir).
function SettingsMenu:show(opts)
    self.visible = true
    self.onClose = opts and opts.onClose or nil
    self.tab = self.tab or 1
    self.focus = 1
    self._t = 0
    self._pressed = nil
    self:rebuild()
    Sfx.play("menuOpen")
end

-- Fecha. `skipCallback` = fechamento forçado (sem voltar pra pausa).
function SettingsMenu:hide(skipCallback)
    if self.visible then Sfx.play("menuClose") end
    self.visible = false
    local cb = self.onClose
    self.onClose = nil
    if cb and not skipCallback then cb() end
end

function SettingsMenu:isVisible() return self.visible end
function SettingsMenu:toggle()
    if self.visible then self:hide() else self:show() end
end

function SettingsMenu:tabCount() return #(self.tabs or {}) end

function SettingsMenu:setTab(i)
    local n = #self.tabs
    if n == 0 then return end
    i = ((i - 1) % n) + 1
    if i ~= self.tab then
        self.tab = i
        self.focus = 1
        Sfx.playWithVariation("menuHover", 1.1, 0.08)
        self:rebuild()
    end
end

-- ===================================================================
-- LAYOUT
-- ===================================================================
function SettingsMenu:rebuild()
    self.tabs = self:_tabs()
    if self.tab > #self.tabs then self.tab = 1 end

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    U = 1   -- a escala mora no UiScale (espaço virtual); aqui é sempre 1:1
    local PAD, TITLE_H, TAB_H, ROW_H = S(PAD), S(TITLE_H), S(TAB_H), S(ROW_H)
    local ROW_GAP, ZONE_GAP, BACK_H, ARROW_W = S(ROW_GAP), S(ZONE_GAP), S(BACK_H), S(ARROW_W)
    local pw = math.max(300, math.min(S(600), sw - 32))
    local innerW = pw - PAD * 2

    -- Altura: conteúdo de altura FIXA (MAX_ROWS) — a aba não muda o painel.
    -- Janela baixa: quem cede é a altura da linha (até 30px), não as zonas.
    local rowH = ROW_H
    local function total(rh)
        return PAD + TITLE_H + TAB_H + ZONE_GAP + MAX_ROWS * (rh + ROW_GAP) - ROW_GAP
            + ZONE_GAP + BACK_H + PAD
    end
    while total(rowH) > sh - 24 and rowH > 30 do rowH = rowH - 2 end
    local ph = math.min(total(rowH), sh - 16)
    local px = math.floor((sw - pw) / 2)
    local py = math.floor((sh - ph) / 2)
    self._panel = { x = px, y = py, w = pw, h = ph }
    self._rowH = rowH

    local x, y = px + PAD, py + PAD
    local z = {}
    z.title = { x = x, y = y, w = innerW, h = TITLE_H }
    y = y + TITLE_H
    z.tabs = { x = x, y = y, w = innerW, h = TAB_H }
    self._tabRects = {}
    local gap = 6
    local tw = math.floor((innerW - gap * (#self.tabs - 1)) / #self.tabs)
    for i = 1, #self.tabs do
        self._tabRects[i] = { x = x + (i - 1) * (tw + gap), y = y, w = tw, h = TAB_H }
    end
    y = y + TAB_H + ZONE_GAP
    z.content = { x = x, y = y, w = innerW, h = MAX_ROWS * (rowH + ROW_GAP) - ROW_GAP }

    -- Coluna de controle à direita, larga o bastante pro "DESLIGADO" em DE.
    local ctrlW = math.min(S(300), math.floor(innerW * 0.56))
    self.rows = {}
    for i, def in ipairs(self.tabs[self.tab].rows) do
        local ry = y + (i - 1) * (rowH + ROW_GAP)
        local r = { x = x, y = ry, w = innerW, h = rowH, def = def }
        local cx = x + innerW - ctrlW - 8
        local ah = rowH - S(12)
        local m = S(6)
        r.ctrl = { x = cx, y = ry + m, w = ctrlW, h = ah }
        r.left = { x = cx, y = ry + m, w = ARROW_W, h = ah }
        r.right = { x = cx + ctrlW - ARROW_W, y = ry + m, w = ARROW_W, h = ah }
        r.value = { x = cx + ARROW_W + m, y = ry + m, w = ctrlW - ARROW_W * 2 - m * 2, h = ah }
        r.label = { x = x + 12, y = ry, w = cx - (x + 12) - 12, h = rowH }
        if def.kind == "choice" then
            -- a linha inteira é o alvo; sem setas
            r.left, r.right = nil, nil
            r.ctrl = { x = x, y = ry, w = innerW, h = rowH }
            r.value = r.ctrl
            r.label = { x = x + S(64), y = ry, w = innerW - S(64) - S(48), h = rowH }
        end
        self.rows[i] = r
    end
    y = z.content.y + z.content.h + ZONE_GAP

    local backLabel = self.onClose and I18n.t("settings.back") or I18n.t("settings.close")
    local bw = math.min(S(220), innerW)
    z.back = { x = math.floor(px + (pw - bw) / 2), y = y, w = bw, h = BACK_H }
    self.backButton = Button:new(z.back.x, z.back.y, bw, BACK_H, backLabel,
        function() self:hide() end, nil, S(12))
    self._zones = z

    self.focus = math.max(1, math.min(#self.rows + 1, self.focus or 1))
end

function SettingsMenu:resize()
    if self.visible then self:rebuild() end
end

-- Não-sobreposição + tudo dentro do painel/janela (test_pause_menu).
function SettingsMenu:validate()
    local problems = {}
    local p, z = self._panel, self._zones
    if not p or not z then return { "sem layout" } end
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    if p.x < 0 or p.y < 0 or p.x + p.w > sw or p.y + p.h > sh then
        problems[#problems + 1] = "painel fora da janela"
    end
    local function inside(r, name)
        if r.x < p.x or r.y < p.y or r.x + r.w > p.x + p.w or r.y + r.h > p.y + p.h then
            problems[#problems + 1] = name .. " vaza do painel"
        end
    end
    local prev
    for _, name in ipairs({ "title", "tabs", "content", "back" }) do
        local r = z[name]
        inside(r, "zona " .. name)
        if prev and r.y < prev.r.y + prev.r.h then
            problems[#problems + 1] = ("zona %s invade %s"):format(name, prev.name)
        end
        prev = { name = name, r = r }
    end
    for i, r in ipairs(self.rows) do
        if r.y + r.h > z.content.y + z.content.h + 0.5 then
            problems[#problems + 1] = "linha " .. i .. " passa da zona de conteudo"
        end
        if r.label.w < 40 then problems[#problems + 1] = "rotulo da linha " .. i .. " espremido" end
        if r.def.kind ~= "choice" then
            if r.value.w < 60 then problems[#problems + 1] = "valor da linha " .. i .. " espremido" end
            if MenuKit.overlaps(r.left, r.value) or MenuKit.overlaps(r.value, r.right) then
                problems[#problems + 1] = "controles da linha " .. i .. " se cruzam"
            end
            if r.label.x + r.label.w > r.ctrl.x then
                problems[#problems + 1] = "rotulo da linha " .. i .. " invade o controle"
            end
        end
        for j = i + 1, #self.rows do
            if MenuKit.overlaps(r, self.rows[j]) then
                problems[#problems + 1] = ("linhas %d e %d se cruzam"):format(i, j)
            end
        end
    end
    for i, a in ipairs(self._tabRects or {}) do
        inside(a, "aba " .. i)
        for j = i + 1, #self._tabRects do
            if MenuKit.overlaps(a, self._tabRects[j]) then
                problems[#problems + 1] = ("abas %d e %d se cruzam"):format(i, j)
            end
        end
    end
    return problems
end

-- ===================================================================
-- AÇÕES
-- ===================================================================
-- Snapshot completo → disco (e espelho em _G.gameSettings).
function SettingsMenu:_persist()
    local g = gs()
    local snapshot = {
        masterVolume  = getVolume("master"),
        musicVolume   = getVolume("music"),
        sfxVolume     = getVolume("sfx"),
        ambientVolume = getVolume("ambient"),
        fullscreen    = love.window.getFullscreen(),
        vsync         = getVSync(),
        crtShader     = CRTShader.isEnabled(),
        lighting      = g.lighting ~= false,
        reducedMotion = g.reducedMotion and true or false,
        screenshake   = g.screenshake or 1.0,
        combatSpeed   = tonumber(g.combatSpeed) or 1,
        uiScale       = tonumber(g.uiScale) or 1,
        locale        = I18n.getLocale(),
    }
    for k, v in pairs(snapshot) do g[k] = v end
    local ok, err = SaveManager.saveSettings(snapshot)
    if not ok then print("[SettingsMenu] falha ao salvar settings: " .. tostring(err)) end
    return ok
end

-- Muda a linha i um passo (dir -1/+1). Persiste.
function SettingsMenu:stepRow(i, dir)
    local r = self.rows[i]
    if not r then return end
    r.def.step(dir)
    if r.def.kind ~= "slider" or r.def.key == "screenshake" then
        Sfx.playWithVariation("buttonClick", 1.0, 0.08)
    end
    self:_persist()
end

-- Clique no corpo do valor: slider pula pro ponto; toggle/cycle avançam.
function SettingsMenu:_clickValue(i, mx)
    local r = self.rows[i]
    if not r then return end
    if r.def.kind == "slider" then
        local v = (mx - r.value.x) / r.value.w
        v = math.ceil(clamp01(v) * 10) / 10
        r.def.set(v)
        if r.def.key == "screenshake" then Sfx.playWithVariation("buttonClick", 1.0, 0.08) end
        self:_persist()
    else
        self:stepRow(i, 1)
    end
end

-- ===================================================================
-- UPDATE / INPUT
-- ===================================================================
function SettingsMenu:update(dt)
    if not self.visible then return end
    self._t = (self._t or 0) + (dt or 0)
    if self.backButton then self.backButton:update(dt) end
    local mx, my = love.mouse.getPosition()
    if mx ~= self._lastMX or my ~= self._lastMY then
        local first = self._lastMX == nil
        self._lastMX, self._lastMY = mx, my
        if not first then
            local target
            for i, r in ipairs(self.rows) do
                if MenuKit.hit(r, mx, my) then target = i end
            end
            if self._zones and MenuKit.hit(self._zones.back, mx, my) then target = #self.rows + 1 end
            if target and target ~= self.focus then
                self.focus = target
                if target <= #self.rows then Sfx.playWithVariation("menuHover", 1.0, 0.12) end
            end
        end
    end
    for i, r in ipairs(self._tabRects or {}) do
        if MenuKit.hit(r, mx, my) and i ~= self.tab then
            require("src.ui.CursorManager").request("hand")
        end
    end
    for _, r in ipairs(self.rows) do
        if MenuKit.hit(r.ctrl, mx, my) then require("src.ui.CursorManager").request("hand") end
    end
end

local function partAt(self, x, y)
    for i, r in ipairs(self._tabRects or {}) do
        if MenuKit.hit(r, x, y) then return { kind = "tab", i = i } end
    end
    for i, r in ipairs(self.rows) do
        if r.def.kind == "choice" and MenuKit.hit(r, x, y) then return { kind = "choice", i = i } end
        if MenuKit.hit(r.left, x, y) then return { kind = "left", i = i } end
        if MenuKit.hit(r.right, x, y) then return { kind = "right", i = i } end
        if MenuKit.hit(r.value, x, y) then return { kind = "value", i = i } end
    end
    return nil
end

function SettingsMenu:mousepressed(x, y, button)
    if not self.visible then return false end
    if button == 1 then
        self._pressed = partAt(self, x, y)
        if self.backButton then self.backButton:mousepressed(x, y, button) end
    end
    return true   -- modal
end

function SettingsMenu:mousereleased(x, y, button)
    if not self.visible then return false end
    if button ~= 1 then return true end
    if self.backButton and self.backButton:mousereleased(x, y, button) then return true end
    local part = partAt(self, x, y)
    local pressed = self._pressed
    self._pressed = nil
    if not part or not pressed or part.kind ~= pressed.kind or part.i ~= pressed.i then
        return true
    end
    if part.kind == "tab" then
        self:setTab(part.i)
    elseif part.kind == "left" then
        self.focus = part.i; self:stepRow(part.i, -1)
    elseif part.kind == "right" then
        self.focus = part.i; self:stepRow(part.i, 1)
    elseif part.kind == "value" then
        self.focus = part.i; self:_clickValue(part.i, x)
    elseif part.kind == "choice" then
        self.focus = part.i; self:stepRow(part.i, 1)
    end
    return true
end

function SettingsMenu:keypressed(key)
    if not self.visible then return false end
    local n = tonumber(key)
    if n and n >= 1 and n <= #self.tabs then self:setTab(n) return true end
    local it = MenuKit.intent(key, MenuKit.shiftDown())
    local onBack = self.focus > #self.rows
    if it == "back" then
        self:hide()
    elseif it == "tab_next" then self:setTab(self.tab + 1)
    elseif it == "tab_prev" then self:setTab(self.tab - 1)
    elseif it == "up" or it == "down" then
        local total = #self.rows + 1
        self.focus = ((self.focus - 1 + (it == "up" and -1 or 1)) % total) + 1
        Sfx.playWithVariation("menuHover", 1.0, 0.12)
    elseif (it == "left" or it == "right") and not onBack
        and self.rows[self.focus] and self.rows[self.focus].def.kind ~= "choice" then
        self:stepRow(self.focus, it == "left" and -1 or 1)
    elseif it == "confirm" then
        if onBack then
            Sfx.playWithVariation("buttonClick", 1.0, 0.08)
            self:hide()
        else
            local r = self.rows[self.focus]
            if r and r.def.kind ~= "slider" then self:stepRow(self.focus, 1) end
        end
    end
    return true
end

-- ===================================================================
-- DRAW
-- ===================================================================
local function drawSegments(r, value)
    local segs = 10
    local gap = 2
    local pctW = FontManager.getFont(S(9)):getWidth("100%") + S(8)
    local barW = r.w - pctW
    local segW = math.max(3, math.floor((barW - gap * (segs - 1)) / segs))
    local segH = math.max(8, r.h - 14)
    local bx = r.x
    local by = r.y + math.floor((r.h - segH) / 2)
    local filled = math.floor(value * segs + 0.5)
    for i = 1, segs do
        local sx = bx + (i - 1) * (segW + gap)
        Palette.set(Palette.INK, 0.8)
        love.graphics.rectangle("fill", sx + 1, by + 1, segW, segH)
        if i <= filled then
            Palette.set(Palette.AGED_GOLD_LIGHT)
            love.graphics.rectangle("fill", sx, by, segW, segH)
            love.graphics.setColor(1, 1, 1, 0.25)
            love.graphics.rectangle("fill", sx, by, segW, 2)
        else
            Palette.set(Palette.AGED_GOLD_DARK)
            love.graphics.rectangle("line", sx + 0.5, by + 0.5, segW - 1, segH - 1)
        end
    end
    local pct = ("%d%%"):format(math.floor(value * 100 + 0.5))
    Palette.set(Palette.PARCHMENT_LIGHT)
    TextFit.print(pct, r.x + r.w - pctW + 4, r.y + math.floor((r.h - S(9)) / 2),
        { size = S(9), maxW = pctW - 4, align = "right" })
end

local function drawArrow(r, glyph, hot)
    Palette.set(hot and Palette.AGED_GOLD or Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.5))
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 3, 3)
    Palette.set(hot and Palette.AGED_GOLD_LIGHT or Palette.AGED_GOLD_DARK)
    love.graphics.rectangle("line", r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1, 3, 3)
    local f = FontManager.getFont(S(10))
    love.graphics.setFont(f)
    Palette.set(hot and Palette.INK or Palette.PARCHMENT_LIGHT)
    love.graphics.print(glyph, math.floor(r.x + (r.w - f:getWidth(glyph)) / 2),
        math.floor(r.y + (r.h - f:getHeight()) / 2))
end

-- Linha de idioma: selo do código + nome nativo; a ATUAL fica acesa
-- (placa dourada + lâmpada cheia), as outras são só texto sobre o painel.
local function drawChoice(r, focused)
    local current = r.def.get()
    if current then
        Palette.set(Palette.AGED_GOLD, focused and 1 or 0.85)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 3, 3)
        love.graphics.setColor(1, 1, 1, 0.18)
        love.graphics.rectangle("fill", r.x + 2, r.y + 1, r.w - 4, 2)
    elseif focused then
        Palette.set(Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.35))
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 3, 3)
        Palette.set(Palette.AGED_GOLD_DARK)
        love.graphics.rectangle("line", r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1, 3, 3)
    else
        Palette.set(Palette.AGED_GOLD_DARK, 0.45)
        love.graphics.rectangle("fill", r.x + 8, r.y + r.h + math.floor(S(ROW_GAP) / 2) - 1, r.w - 16, 1)
    end
    -- selo do código
    local bw, bh = S(36), math.min(S(22), r.h - 10)
    local bx, by = r.x + S(14), r.y + math.floor((r.h - bh) / 2)
    Palette.set(current and Palette.INK or Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.3))
    love.graphics.rectangle("fill", bx, by, bw, bh, 2, 2)
    Palette.set(current and Palette.AGED_GOLD_DARK or Palette.AGED_GOLD_DARK)
    love.graphics.rectangle("line", bx + 0.5, by + 0.5, bw - 1, bh - 1, 2, 2)
    Palette.set(current and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT)
    TextFit.print(r.def.badge, bx, by + math.floor((bh - S(9)) / 2), { size = S(9), maxW = bw, align = "center" })
    -- nome nativo
    Palette.set(current and Palette.INK or (focused and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT_LIGHT))
    TextFit.print(r.def.label, r.label.x, r.y + math.floor((r.h - S(12)) / 2),
        { size = S(12), maxW = r.label.w })
    -- lâmpada à direita: cheia = atual (lê o estado sem depender do idioma)
    local d = S(10)
    local lx, ly = r.x + r.w - S(14) - d, r.y + math.floor((r.h - d) / 2)
    Palette.set(current and Palette.INK or Palette.AGED_GOLD_DARK)
    love.graphics.rectangle(current and "fill" or "line", lx + 0.5, ly + 0.5, d - 1, d - 1)
    love.graphics.setColor(1, 1, 1, 1)
end

function SettingsMenu:_drawRow(i, r, focused, mx, my)
    if r.def.kind == "choice" then return drawChoice(r, focused) end
    if focused then
        Palette.set(Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.35))
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 3, 3)
        Palette.set(Palette.AGED_GOLD_DARK)
        love.graphics.rectangle("line", r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1, 3, 3)
    else
        Palette.set(Palette.AGED_GOLD_DARK, 0.45)
        love.graphics.rectangle("fill", r.x + 8, r.y + r.h + math.floor(S(ROW_GAP) / 2) - 1, r.w - 16, 1)
    end
    Palette.set(focused and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT_LIGHT)
    TextFit.print(r.def.label, r.label.x, r.y + math.floor((r.h - S(12)) / 2),
        { size = S(12), maxW = r.label.w })

    drawArrow(r.left, "<", MenuKit.hit(r.left, mx, my))
    drawArrow(r.right, ">", MenuKit.hit(r.right, mx, my))

    local kind, v = r.def.kind, r.def.get()
    if kind == "slider" then
        drawSegments(r.value, v or 0)
    else
        local text, col
        if kind == "toggle" then
            text = v and I18n.t("settings.on") or I18n.t("settings.off")
            col = v and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT
        else
            text, col = tostring(v), Palette.PARCHMENT_LIGHT
        end
        Palette.set(Palette.INK, 0.55)
        love.graphics.rectangle("fill", r.value.x, r.value.y, r.value.w, r.value.h, 3, 3)
        local ty = r.value.y + math.floor((r.value.h - S(10)) / 2)
        if kind == "toggle" then
            -- lâmpada acesa/apagada COLADA no texto (grupo centralizado):
            -- lê o estado antes da palavra, sem depender do idioma.
            local d, gapL = S(8), S(8)
            local font, shown = TextFit.fit(text, S(10), r.value.w - d - gapL - 12)
            local groupW = d + gapL + font:getWidth(shown)
            local gx = math.floor(r.value.x + (r.value.w - groupW) / 2)
            local ly = r.value.y + math.floor((r.value.h - d) / 2)
            Palette.set(v and Palette.AGED_GOLD_LIGHT or Palette.AGED_GOLD_DARK)
            love.graphics.rectangle(v and "fill" or "line", gx + 0.5, ly + 0.5, d - 1, d - 1)
            love.graphics.setFont(font)
            Palette.set(col)
            love.graphics.print(shown, gx + d + gapL, ty)
        else
            Palette.set(col)
            TextFit.print(text, r.value.x + 6, ty,
                { size = S(10), maxW = r.value.w - 12, align = "center" })
        end
    end
end

function SettingsMenu:draw()
    if not self.visible then return end
    local t = self._t or 0
    MenuKit.drawVeil(t, 0.65)
    MenuKit.pushEnter(t)

    local p, z = self._panel, self._zones
    UiPanel.draw(p.x, p.y, p.w, p.h)
    local mx, my = love.mouse.getPosition()

    -- CABEÇALHO (mesma gramática da pausa)
    local title = I18n.t("settings.title")
    local tf, shown = TextFit.fit(title, S(22), z.title.w, 12)
    love.graphics.setFont(tf)
    local tx = math.floor(z.title.x + (z.title.w - tf:getWidth(shown)) / 2)
    Palette.set(Palette.INK, 0.85)
    love.graphics.print(shown, tx + 2, z.title.y + 4 + 2)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.print(shown, tx, z.title.y + 4)
    Palette.set(Palette.AGED_GOLD_DARK)
    love.graphics.rectangle("fill", z.title.x + 24, z.title.y + z.title.h - S(14), z.title.w - 48, 1)

    -- ABAS
    for i, r in ipairs(self._tabRects) do
        local active = i == self.tab
        local hot = MenuKit.hit(r, mx, my)
        if active then
            Palette.set(Palette.AGED_GOLD)
        elseif hot then
            Palette.set(Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.6))
        else
            Palette.set(Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.3))
        end
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 3, 3)
        Palette.set(active and Palette.AGED_GOLD_LIGHT or Palette.AGED_GOLD_DARK)
        love.graphics.rectangle("line", r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1, 3, 3)
        Palette.set(active and Palette.INK or Palette.PARCHMENT_LIGHT)
        TextFit.print(self.tabs[i].label, r.x + 6, r.y + math.floor((r.h - S(11)) / 2),
            { size = S(11), maxW = r.w - 12, align = "center" })
    end
    -- base da aba ativa liga a aba ao conteúdo
    Palette.set(Palette.AGED_GOLD)
    love.graphics.rectangle("fill", z.tabs.x, z.tabs.y + z.tabs.h + 3, z.tabs.w, 2)

    -- LINHAS
    for i, r in ipairs(self.rows) do
        self:_drawRow(i, r, i == self.focus, mx, my)
    end

    -- VOLTAR
    if self.backButton then self.backButton:draw() end

    -- anel de foco (por cima de tudo, item focado)
    if self.focus > #self.rows then
        MenuKit.focusRing(z.back.x, z.back.y, z.back.w, z.back.h, t)
    elseif self.rows[self.focus] then
        local r = self.rows[self.focus]
        MenuKit.focusRing(r.x, r.y, r.w, r.h, t, 2)
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

return SettingsMenu
