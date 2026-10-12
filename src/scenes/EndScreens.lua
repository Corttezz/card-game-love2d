-- src/scenes/EndScreens.lua
-- Telas terminais (gameOver, victory). Extraídas de main.lua.
--
-- v2 (Out/2026 — auditoria de UX): antes as duas telas só aceitavam TECLA
-- ("R"/"ESPAÇO"/"ESC" escritos num rodapé) — o mouse não fazia nada e o
-- gamepad também não. Agora são telas de verdade, no padrão StS (resumo da
-- run + botões) e Balatro (placa escura atrás de todo texto):
--
--   ZONAS (de cima pra baixo; cada elemento pertence a UMA):
--     TÍTULO    título animado + subtítulo (quem te matou / campanha vencida)
--               + pontuação e recorde — tudo sobre placa escura (o título
--               verde da vitória sumia na arte clara)
--     RESUMO    grade classe · alcance · desfecho · turnos · tempo ·
--               baralho · ouro · coringas
--     REVELAÇÃO maestria + desbloqueios (UnlockReveal) — ocupa o que sobra;
--               some se não couber (o conteúdo cede, as zonas não se mexem)
--     AÇÕES     Game over: Tentar de novo / Menu principal
--               Vitória:   Seguir no Endless / Tentar de novo / Menu principal
--
-- Entrada: mouse (clique no release, só se o press nasceu no mesmo botão),
-- teclado e gamepad via src/ui/MenuKit.lua (setas/WASD, Enter/Espaço, ESC =
-- menu; R = tentar de novo). O gamepad chega aqui já traduzido em tecla pelo
-- love.gamepadpressed do main.lua.
--
-- Os callbacks (tentar de novo / menu / endless) são injetados pelo main.lua
-- via EndScreens.setCallbacks — a tela não conhece a máquina de estados.
-- Sem update externo: o relógio tica no draw (love.timer.getDelta), como o
-- título DynaText sempre fez.

local FontManager = require("src.ui.FontManager")
local Theme = require("src.ui.Theme")
local Palette = require("src.ui.Palette")
local I18n = require("src.i18n.I18n")
local TextCase = require("src.i18n.TextCase")
local SceneBackground = require("src.ui.SceneBackground")
local DynaText = require("src.ui.DynaText")
local UnlockReveal = require("src.ui.UnlockReveal")
local MenuKit = require("src.ui.MenuKit")
local TextFit = require("src.ui.TextFit")

local EndScreens = {}

-- Segundos depois de a tela aparecer em que a entrada é ignorada: o clique
-- ou a tecla que matou o chefe (ou o jogador) não pode cair num botão.
EndScreens.INPUT_DELAY = 0.5

local S = {
    kind = nil,          -- "gameOver" | "victory"
    t = 0,               -- tempo desde a entrada
    lastDraw = nil,
    focus = 1,
    pressed = nil,       -- índice do botão onde o press do mouse nasceu
    layout = nil,
    layoutKey = nil,
    callbacks = {},
}

function EndScreens.setCallbacks(cb)
    S.callbacks = cb or {}
end

-- ===================================================================
-- DADOS PUROS (testáveis sem desenhar)
-- ===================================================================

local function currentRun(game)
    return game and game.runManager and game.runManager.currentRun or nil
end

-- A vitória pode virar Endless? Só numa run que JÁ registrou a vitória
-- (campaignWon) e ainda não está no endless.
function EndScreens.canEndless(game)
    local run = currentRun(game)
    return (game and game.isRunMode and run and run.campaignWon
        and not run.endlessMode) and true or false
end

local function enemyName(game)
    local id = game and game.enemy and game.enemy.spriteId
    if not id then return "?" end
    return I18n.t("end_screen.enemy." .. id)
end

local function formatTime(secs)
    if not secs or secs <= 0 then return "-" end
    secs = math.floor(secs)
    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)
    local s = secs % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%d:%02d", m, s)
end
EndScreens.formatTime = formatTime

-- Resumo da run: { subtitle, cells = { {label, value}, ... } }.
function EndScreens.summary(kind, game)
    local run = currentRun(game) or {}
    local cells = {}
    local function add(labelKey, value)
        cells[#cells + 1] = { label = I18n.t("end_screen." .. labelKey), value = tostring(value) }
    end

    local className = run.classId
        and I18n.t("classes." .. run.classId .. ".name", nil, run.className)
        or (game and game.selectedClass) or "-"
    add("label_class", className)

    if run.endlessMode then
        add("label_reached", I18n.t("end_screen.reached_endless",
            { n = math.max(1, run.floorsInEndless or 1) }))
    else
        add("label_reached", I18n.t("end_screen.reached_act",
            { act = run.actNumber or 1, floor = run.floorInAct or 1 }))
    end

    local subtitle
    if kind == "victory" then
        add("label_fate", I18n.t("end_screen.fate_victory"))
        subtitle = I18n.t("end_screen.victory_sub",
            { acts = require("src.core.Config").TotalActs or 6 })
    else
        local name = enemyName(game)
        add("label_killed_by", name)
        if run.endlessMode then
            subtitle = I18n.t("end_screen.endless_sub",
                { n = math.max(1, run.floorsInEndless or 1), enemy = name })
        else
            subtitle = I18n.t("end_screen.defeat_sub", { enemy = name })
        end
    end

    add("label_turns", run.turnsTotal or 0)
    add("label_time", formatTime(run.playSeconds))
    add("label_deck", I18n.t("end_screen.deck_n", { n = run.currentDeck and #run.currentDeck or 0 }))
    local gold = game and game.economySystem and game.economySystem.currentGold or 0
    add("label_gold", math.floor(gold))
    add("label_jokers", run.jokers and #run.jokers or 0)
    return { subtitle = subtitle, cells = cells }
end

-- Botões da tela, na ordem visual (o primeiro é o primário / foco inicial).
function EndScreens.actions(kind, game)
    local cb = S.callbacks
    local list = {}
    if kind == "victory" and EndScreens.canEndless(game) then
        list[#list + 1] = { key = "endless", title = I18n.t("end_screen.endless"),
            desc = I18n.t("end_screen.endless_desc"),
            action = function() if cb.onEndless then cb.onEndless() end end }
    end
    list[#list + 1] = { key = "retry", title = I18n.t("end_screen.retry"),
        desc = I18n.t("end_screen.retry_desc"),
        action = function() if cb.onRetry then cb.onRetry() end end }
    list[#list + 1] = { key = "menu", title = I18n.t("end_screen.menu"),
        desc = I18n.t("end_screen.menu_desc"),
        action = function() if cb.onMenu then cb.onMenu() end end }
    list[1].primary = true
    return list
end

-- ===================================================================
-- LAYOUT
-- ===================================================================

-- Escala tipográfica: 768 de altura = 1; telas grandes crescem até ~1.9.
local function uiScale(sh)
    return math.max(1, math.min(1.9, sh / 768))
end

local GAP = 14

-- Monta as zonas e os retângulos dos botões para (kind, game) no tamanho
-- de tela corrente. Puro em relação ao estado de animação.
function EndScreens.layout(kind, game)
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local u = uiScale(sh)
    local colW = math.min(sw - 32, math.floor(980 * math.min(u, 1.5)))
    local x = math.floor((sw - colW) / 2)
    local pad = math.floor(12 * u)

    local sizes = {
        title = math.min(72, math.floor(40 * u)),
        sub = math.floor(12 * u),
        score = math.floor(12 * u),
        label = math.floor(8 * u),
        value = math.floor(12 * u),
        btnTitle = math.floor(14 * u),
        btnDesc = math.floor(8 * u),
    }
    local fh = function(sz) return FontManager.getFont(sz):getHeight() end

    local L = { sizes = sizes, u = u, pad = pad, kind = kind }
    local y = math.max(12, math.floor(sh * 0.035))

    -- TÍTULO
    local titleH = pad + sizes.title + math.floor(10 * u) + fh(sizes.sub)
        + math.floor(8 * u) + fh(sizes.score) + pad
    L.title = { x = x, y = y, w = colW, h = titleH }
    y = y + titleH + GAP

    -- AÇÕES (medidas antes: a revelação fica com o que sobra no meio)
    local acts = EndScreens.actions(kind, game)
    local n = #acts
    local bgap = math.floor(12 * u)
    local bw = math.min(math.floor(320 * u), math.floor((colW - bgap * (n - 1)) / n))
    local withDesc = true
    local btnH = pad + fh(sizes.btnTitle) + math.floor(6 * u) + fh(sizes.btnDesc) + pad

    -- RESUMO
    local cells = 8
    local cols = (colW >= 720) and 4 or 2
    local rows = math.ceil(cells / cols)
    local cellH = fh(sizes.label) + math.floor(5 * u) + fh(sizes.value)
    local rowGap = math.floor(10 * u)
    local sumH = pad * 2 + rows * cellH + (rows - 1) * rowGap

    -- Cabe? Quem cede é o CONTEÚDO: primeiro a descrição dos botões.
    local bottomMargin = math.max(16, math.floor(sh * 0.035))
    local need = y + sumH + GAP + btnH + bottomMargin
    if need > sh then
        withDesc = false
        btnH = pad + fh(sizes.btnTitle) + pad
    end
    L.summary = { x = x, y = y, w = colW, h = sumH, cols = cols, rows = rows,
                  cellH = cellH, rowGap = rowGap }
    y = y + sumH + GAP

    local ay = sh - bottomMargin - btnH
    local rowW = n * bw + (n - 1) * bgap
    local bx = math.floor((sw - rowW) / 2)
    L.actions = { x = bx, y = ay, w = rowW, h = btnH }
    L.buttons = {}
    for i, a in ipairs(acts) do
        L.buttons[i] = { x = bx + (i - 1) * (bw + bgap), y = ay, w = bw, h = btnH,
            key = a.key, title = a.title, desc = withDesc and a.desc or nil,
            primary = a.primary, action = a.action }
    end

    -- REVELAÇÃO: o vão entre o resumo e as ações (UnlockReveal pinta a placa
    -- 8px acima da banda recebida — por isso o +8).
    local revTop = y + 8
    local revBottom = ay - GAP
    if game and game.unlockResult and revBottom - revTop >= math.floor(70 * u) then
        -- Teto: o conteúdo do UnlockReveal não passa de ~340px (cartas em
        -- escala 1.6 no máximo); sem teto, em 2560x1440 a placa virava um
        -- retângulo escuro quase vazio.
        L.reveal = { x = x, y = revTop, w = colW, h = math.min(340, revBottom - revTop) }
    end
    return L
end

local function ensureLayout(kind, game)
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local key = table.concat({ kind, sw, sh, I18n.current or "",
        tostring(EndScreens.canEndless(game)), tostring(game and game.unlockResult ~= nil) }, "|")
    if S.layoutKey ~= key or not S.layout then
        S.layout = EndScreens.layout(kind, game)
        S.layoutKey = key
        S.focus = math.max(1, math.min(#S.layout.buttons, S.focus or 1))
    end
    return S.layout
end

-- Invalida o layout (love.resize / troca de idioma).
function EndScreens.resize()
    S.layoutKey = nil
end

-- Checagem geométrica (usada pelo test_end_screens). Lista de problemas.
function EndScreens.validate(L)
    L = L or S.layout
    local problems = {}
    if not L then return { "sem layout" } end
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local function onScreen(r, name)
        if r.x < 0 or r.y < 0 or r.x + r.w > sw or r.y + r.h > sh then
            problems[#problems + 1] = ("%s fora da tela (%d,%d %dx%d em %dx%d)")
                :format(name, r.x, r.y, r.w, r.h, sw, sh)
        end
    end
    local order = { "title", "summary", "reveal", "actions" }
    local prev
    for _, name in ipairs(order) do
        local r = L[name]
        if r then
            onScreen(r, "zona " .. name)
            -- reveal pinta 8px acima da própria banda: compara com essa borda
            local top = (name == "reveal") and (r.y - 8) or r.y
            if prev and top < prev.r.y + prev.r.h then
                problems[#problems + 1] = ("zona %s invade %s"):format(name, prev.name)
            end
            prev = { name = name, r = r }
        end
    end
    for i, b in ipairs(L.buttons or {}) do
        onScreen(b, "botao " .. b.key)
        for j = i + 1, #L.buttons do
            if MenuKit.overlaps(b, L.buttons[j]) then
                problems[#problems + 1] = ("botao %s sobrepoe %s"):format(b.key, L.buttons[j].key)
            end
        end
        -- textos cabem no botão (TextFit garante; aqui confere a fonte mínima)
        local _, shown = TextFit.fit(b.title, L.sizes.btnTitle, b.w - L.pad * 2, 8)
        if shown ~= b.title then
            problems[#problems + 1] = ("titulo do botao %s truncado (%q)"):format(b.key, shown)
        end
    end
    return problems
end

-- ===================================================================
-- ESTADO / ENTRADA
-- ===================================================================

-- Chamado pelo draw: detecta re-entrada na tela (outro tipo, ou a tela não
-- era desenhada havia um tempo) e zera relógio e foco.
local function tickEnter(kind)
    local now = love.timer.getTime()
    if S.kind ~= kind or not S.lastDraw or (now - S.lastDraw > 0.3) then
        S.kind = kind
        S.t = 0
        S.focus = 1
        S.pressed = nil
        S.layoutKey = nil
    else
        S.t = S.t + (love.timer.getDelta() or 0)
    end
    S.lastDraw = now
end

-- Para testes/ferramentas: entra na tela sem desenhar (zera relógio/foco).
function EndScreens._enter(kind, game, t)
    S.kind = kind
    S.t = t or 0
    S.focus = 1
    S.pressed = nil
    S.layoutKey = nil
    S.lastDraw = love.timer.getTime()
    ensureLayout(kind, game)
end

function EndScreens._state() return S end

local function ready() return S.layout and S.t >= EndScreens.INPUT_DELAY end

local function activate(i)
    local b = S.layout and S.layout.buttons[i]
    if not b then return false end
    local okS, Sfx = pcall(require, "src.systems.Sfx")
    if okS then Sfx.playWithVariation("buttonClick", 1.0, 0.08) end
    b.action()
    return true
end

local function buttonAt(x, y)
    for i, b in ipairs(S.layout and S.layout.buttons or {}) do
        if MenuKit.hit(b, x, y) then return i end
    end
end

function EndScreens.focusedKey()
    local b = S.layout and S.layout.buttons[S.focus]
    return b and b.key
end

function EndScreens.keypressed(key)
    if not ready() then return true end
    if key == "r" then
        for i, b in ipairs(S.layout.buttons) do
            if b.key == "retry" then return activate(i) end
        end
    end
    local it = MenuKit.intent(key, MenuKit.shiftDown())
    local n = #S.layout.buttons
    if it == "left" or it == "up" or it == "tab_prev" then
        S.focus = ((S.focus - 2) % n) + 1
        local okS, Sfx = pcall(require, "src.systems.Sfx")
        if okS then Sfx.playWithVariation("menuHover", 1.0, 0.12) end
    elseif it == "right" or it == "down" or it == "tab_next" then
        S.focus = (S.focus % n) + 1
        local okS, Sfx = pcall(require, "src.systems.Sfx")
        if okS then Sfx.playWithVariation("menuHover", 1.0, 0.12) end
    elseif it == "confirm" then
        return activate(S.focus)
    elseif it == "back" then
        for i, b in ipairs(S.layout.buttons) do
            if b.key == "menu" then return activate(i) end
        end
    end
    return true
end

function EndScreens.mousepressed(x, y, button)
    if button ~= 1 or not ready() then return true end
    S.pressed = buttonAt(x, y)
    return true
end

function EndScreens.mousereleased(x, y, button)
    if button ~= 1 then return true end
    local i = ready() and buttonAt(x, y)
    local pressed = S.pressed
    S.pressed = nil
    if i and i == pressed then return activate(i) end
    return true
end

-- Mouse que MEXE leva o foco (mouse parado não rouba o foco do teclado).
local function trackHover()
    local mx, my = love.mouse.getPosition()
    local okC, CRT = pcall(require, "src.ui.CRTShader")
    if okC and CRT.screenToContent then mx, my = CRT.screenToContent(mx, my) end
    local i = buttonAt(mx, my)
    if mx ~= S.lastMX or my ~= S.lastMY then
        local first = S.lastMX == nil
        S.lastMX, S.lastMY = mx, my
        if i and not first and i ~= S.focus then
            S.focus = i
            local okS, Sfx = pcall(require, "src.systems.Sfx")
            if okS then Sfx.playWithVariation("menuHover", 1.0, 0.12) end
        end
    end
    if i and ready() then
        local okM, CM = pcall(require, "src.ui.CursorManager")
        if okM and CM.request then CM.request("hand") end
    end
end

-- ===================================================================
-- DRAW
-- ===================================================================

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
                -- Mesma correção do título do pacote e do Round Eval: com o
                -- default (bump_phase=200) as letras vizinhas defasam ~-1,06
                -- rad e o título ESPALHA em vez de ondular. Fase pequena faz
                -- o salto viajar pela palavra.
                bump_phase = 0.42,
                bump_amount = 0.45,
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
        entry.dyna.timer = 0
        entry.dyna.popped_in = false
        entry.dyna:pulse(0.5, 0.45)
    end

    entry.lastDraw = now
    entry.dyna:update(love.timer.getDelta())
    return entry.dyna
end

-- Placa escura com filete dourado: TODO texto da tela final mora numa.
local function plate(r, alpha)
    Palette.set(Palette.INK, alpha or 0.82)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 4, 4)
    Palette.set(Palette.AGED_GOLD_DARK, 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1, 4, 4)
end

local function drawTitleZone(kind, game, L, sum)
    local z = L.title
    plate(z)
    local s = L.sizes
    local cx = z.x + z.w / 2
    local titleText = (kind == "victory") and I18n.t("victory.title")
        or I18n.t("end_screen.defeat_title")
    titleText = TextCase.upper(titleText)
    -- Título cede a fonte até caber na placa (locale de palavra longa).
    local size = s.title
    while size > 16 and FontManager.getFont(size):getWidth(titleText) > z.w - L.pad * 2 do
        size = size - 2
    end
    local color = (kind == "victory") and Palette.AGED_GOLD_LIGHT or Palette.lighten(Palette.BLOOD, 0.45)
    local dyna = ensureTitle(kind, titleText, size, color)
    local ty = z.y + L.pad
    dyna:draw(cx, ty + size / 2)

    local y = ty + s.title + math.floor(10 * L.u)
    Palette.set(Palette.PARCHMENT_LIGHT)
    TextFit.print(sum.subtitle, z.x + L.pad, y,
        { size = s.sub, maxW = z.w - L.pad * 2, align = "center", minSize = 8 })
    y = y + FontManager.getFont(s.sub):getHeight() + math.floor(8 * L.u)

    -- Pontuação + recorde na mesma linha.
    local ProfileStats = require("engine.ProfileStats")
    local best = ProfileStats.get().bestScore or 0
    local isNew = game and game.scoreSystem and game.scoreSystem.recordBroken
    local scoreTxt = I18n.t("end_screen.score", { score = game and game.score or 0 })
    local recTxt = isNew and I18n.t("end.new_record") or I18n.t("end.record", { n = best })
    local f = FontManager.getFont(s.score)
    local sep = "   ·   "
    local total = f:getWidth(scoreTxt .. sep .. recTxt)
    if total > z.w - L.pad * 2 then
        f = TextFit.fit(scoreTxt .. sep .. recTxt, s.score, z.w - L.pad * 2, 8)
        total = f:getWidth(scoreTxt .. sep .. recTxt)
    end
    love.graphics.setFont(f)
    local sx = math.floor(cx - total / 2)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.print(scoreTxt, sx, y)
    sx = sx + f:getWidth(scoreTxt)
    Palette.set(Palette.PARCHMENT, 0.8)
    love.graphics.print(sep, sx, y)
    sx = sx + f:getWidth(sep)
    if isNew then love.graphics.setColor(1, 0.85, 0.30, 1) else Palette.set(Palette.PARCHMENT) end
    love.graphics.print(recTxt, sx, y)
end

local function drawSummary(L, sum)
    local z = L.summary
    plate(z, 0.78)
    local cw = math.floor((z.w - L.pad * 2) / z.cols)
    for i, c in ipairs(sum.cells) do
        local col = (i - 1) % z.cols
        local row = math.floor((i - 1) / z.cols)
        local cx = z.x + L.pad + col * cw
        local cy = z.y + L.pad + row * (z.cellH + z.rowGap)
        Palette.set(Palette.AGED_GOLD)
        TextFit.print(c.label, cx + 6, cy, { size = L.sizes.label, maxW = cw - 12, minSize = 6 })
        Palette.set(Palette.PARCHMENT_LIGHT)
        TextFit.print(c.value, cx + 6,
            cy + FontManager.getFont(L.sizes.label):getHeight() + math.floor(5 * L.u),
            { size = L.sizes.value, maxW = cw - 12, minSize = 7 })
    end
    Palette.set(Palette.AGED_GOLD_DARK, 0.6)
    for c = 1, z.cols - 1 do
        love.graphics.rectangle("fill", z.x + L.pad + c * cw - 1, z.y + L.pad, 1, z.h - L.pad * 2)
    end
end

local function drawButton(L, b, focused)
    local x, y, w, h = b.x, b.y, b.w, b.h
    local fill, outline, titleCol, descCol
    if b.primary then
        fill = focused and Palette.AGED_GOLD_LIGHT or Palette.AGED_GOLD
        outline = Palette.AGED_GOLD_LIGHT
        titleCol, descCol = Palette.INK, Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.4)
    else
        fill = focused and Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.55)
            or Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.25)
        outline = focused and Palette.AGED_GOLD or Palette.AGED_GOLD_DARK
        titleCol = focused and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT_LIGHT
        descCol = Palette.PARCHMENT
    end
    -- sombra dura + placa + emboss (gramática do Button clean / PauseMenu)
    Palette.set(Palette.INK, 0.6)
    love.graphics.rectangle("fill", x + 3, y + 3, w, h, 3, 3)
    Palette.set(fill)
    love.graphics.rectangle("fill", x, y, w, h, 3, 3)
    love.graphics.setColor(1, 1, 1, b.primary and 0.22 or 0.06)
    love.graphics.rectangle("fill", x + 2, y + 1, w - 4, 2)
    Palette.set(outline)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 3, 3)

    local ty = y + L.pad
    Palette.set(titleCol)
    TextFit.print(b.title, x + L.pad, ty,
        { size = L.sizes.btnTitle, maxW = w - L.pad * 2, align = "center", minSize = 8 })
    if b.desc then
        Palette.set(descCol)
        TextFit.print(b.desc, x + L.pad,
            ty + FontManager.getFont(L.sizes.btnTitle):getHeight() + math.floor(6 * L.u),
            { size = L.sizes.btnDesc, maxW = w - L.pad * 2, align = "center", minSize = 6 })
    end
end

local function drawScreen(kind, game)
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()

    local bgScene = (kind == "victory") and "victory" or "gameOver"
    if not SceneBackground.draw(bgScene, width, height, kind == "victory" and 0.35 or 0.40) then
        local bgColors = (kind == "victory")
            and { {0.1, 0.3, 0.1, 1}, {0.05, 0.2, 0.05, 1}, {0.02, 0.15, 0.02, 1} }
            or  { {0.3, 0.1, 0.1, 1}, {0.2, 0.05, 0.05, 1}, {0.15, 0.02, 0.02, 1} }
        Theme.Utils.drawVerticalGradient(0, 0, width, height, bgColors)
    end

    tickEnter(kind)
    local L = ensureLayout(kind, game)
    trackHover()
    local sum = EndScreens.summary(kind, game)

    drawTitleZone(kind, game, L, sum)
    drawSummary(L, sum)
    if L.reveal then
        UnlockReveal.draw(game.unlockResult, L.reveal.x, L.reveal.y, L.reveal.w, L.reveal.h)
    end

    for i, b in ipairs(L.buttons) do
        drawButton(L, b, i == S.focus)
    end
    -- O anel de foco só acende quando a tela já aceita entrada.
    local fb = L.buttons[S.focus]
    if fb and ready() then MenuKit.focusRing(fb.x, fb.y, fb.w, fb.h, S.t) end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(FontManager.getFont(12))
end

function EndScreens.drawGameOver(game)
    drawScreen("gameOver", game)
end

function EndScreens.drawVictory(game)
    drawScreen("victory", game)
end

return EndScreens
