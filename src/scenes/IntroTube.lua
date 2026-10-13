-- src/scenes/IntroTube.lua
-- ABERTURA "a página e o televisor" (Out/2026, pedido do dono a partir de
-- heyparker.ai: "gostei do começo: a tela, a fita; quero o nosso visual").
--
-- Antes do boot de sempre (sintonia do canal, lua, redemoinho), a tela é
-- uma PÁGINA de pergaminho com o NOSSO televisor pequeno no meio (o mesmo
-- gabinete/tubo do crt.glsl, renderizado numa tela menor por
-- CRTShader.renderTube). Na tela do televisor o título e o subtítulo são
-- DATILOGRAFADOS com o blip do corvo e um cursor piscando; depois a câmera
-- MERGULHA no tubo (o televisor cresce até a abertura do tubo encher a
-- janela) e, nesse instante, o boot normal assume: o CRT de tela cheia liga
-- (powerOn) e a sintonia começa dentro do tubo.
--
-- Regras: qualquer tecla/clique pula; reducedMotion = texto inteiro na
-- hora, sem mergulho (corte); sem shader (driver sem GLSL) o televisor é
-- uma moldura plana de pixel art, AVISADA uma vez. Nada aqui é regra de
-- jogo: só coreografia. Tempos em IntroTube.T (segundos).

local Palette     = require("src.ui.Palette")
local FontManager = require("src.ui.FontManager")
local I18n        = require("src.i18n.I18n")

local IntroTube = {}

IntroTube.T = {
    fadeIn = 0.35,        -- página aparece
    tvPop  = 0.45,        -- televisor "pousa" (escala 0,92 -> 1)
    typeAt = 0.80,        -- começa a datilografar o título
    gapSub = 0.35,        -- pausa entre título e subtítulo
    hold   = 0.90,        -- segura com o texto completo
    insert = 1.10,        -- a CARTA viaja até a fenda do disquete (só com a arte)
    insertHold = 0.35,    -- clique + flash da tela depois de entrar
    dive   = 1.00,        -- mergulho no tubo
    cps    = 22,          -- caracteres por segundo (mais lento que o corvo: é cena)
}
IntroTube.TV_FRAC  = 0.46   -- largura do televisor / largura da janela
-- ARTE DO COMPUTADOR (dono, Out/2026: "gerar literalmente o computador do
-- site da Parker, nas nossas cores; o primeiro quadro é ele e depois dá
-- zoom"). Quando src/data/intro_computer.lua existe (gerado por
-- tools/intro_computer_import.py, ver docs/plan/intro-computer-prompt.md),
-- a abertura desenha ESSA arte no lugar do televisor do shader: o tubo
-- (sem o gabinete do shader, só a abertura curva com scanlines) vai DENTRO
-- do retângulo da tela da arte e o mergulho é na tela.
IntroTube.DATA_PATH = "src/data/intro_computer.lua"
IntroTube.ART_FRAC  = 0.70   -- altura do computador / altura da janela
-- A FENDA do disquete: no site uma mão enfia um disquete antes do mergulho;
-- aqui uma CARTA (o verso, src/ui/CardBack) entra pela fenda. `slot` vem
-- do importador (faixa escura abaixo da tela); sem ele, esta fração da arte.
IntroTube.SLOT_FALLBACK = { x = 0.52, y = 0.80, w = 0.34, h = 0.03 }
IntroTube.BEZEL_PX = 20     -- = BEZEL_PX do crt.glsl (gabinete dentro do canvas)
IntroTube.CORNER   = 0.012  -- raio relativo da abertura (= cornerR do shader)

local S = {}
local utf8 = require("utf8")

-- carrega a arte do computador (nil = usar o televisor do shader)
local artCache = { path = nil, data = false }
function IntroTube.computerArt()
    local path = IntroTube.DATA_PATH
    if artCache.path == path then return artCache.data or nil end
    artCache.path = path
    artCache.data = false
    if not (path and love.filesystem.getInfo(path)) then return nil end
    local ok, chunk = pcall(love.filesystem.load, path)
    if not ok or not chunk then
        print("[IntroTube] dados do computador ilegiveis: " .. tostring(chunk))
        return nil
    end
    local okR, d = pcall(chunk)
    if not okR or type(d) ~= "table" or not d.image or not d.screen then
        print("[IntroTube] dados do computador invalidos em " .. path)
        return nil
    end
    local okI, img = pcall(love.graphics.newImage, d.image)
    if not okI then
        print("[IntroTube] arte do computador nao carregou: " .. tostring(img))
        return nil
    end
    img:setFilter("nearest", "nearest")
    d.img = img
    d.w, d.h = img:getWidth(), img:getHeight()
    artCache.data = d
    return d
end
function IntroTube.reloadArt() artCache.path = nil end

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

local function easeInOutCubic(t)
    t = math.max(0, math.min(1, t))
    return t < 0.5 and 4 * t * t * t or 1 - ((-2 * t + 2) ^ 3) / 2
end
local function easeOutBack(t)
    t = math.max(0, math.min(1, t))
    local c1, c3 = 1.70158, 2.70158
    return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local warned = {}
local function warnOnce(k, msg)
    if warned[k] then return end
    warned[k] = true
    print("[IntroTube] " .. msg)
end

-- ===================================================================
-- Estado
-- ===================================================================
function IntroTube.init(opts)
    opts = opts or {}
    S = {
        phase = "page",            -- page | insert | dive | done
        t = 0, diveT = 0, insT = 0, insSfx = 0,
        title = opts.title or I18n.t("menu.title"),
        sub = opts.subtitle or I18n.t("menu.subtitle"),
        shownTitle = 0, shownSub = 0, acc = 0, pauseT = 0, letters = 0,
        doneTyping = false, holdT = 0,
        onDone = opts.onDone,
        onSkip = opts.onSkip,
        canvases = nil,
        skipped = false,
    }
    S.lenTitle = utf8.len(S.title) or #S.title
    S.lenSub = utf8.len(S.sub) or #S.sub
    if reducedMotion() then
        S.shownTitle, S.shownSub, S.doneTyping = S.lenTitle, S.lenSub, true
    end
end

function IntroTube.phase() return S.phase end
function IntroTube.isDone() return S.phase == "done" end
function IntroTube.typed() return S.shownTitle, S.shownSub end
function IntroTube.diveProgress() return S.phase == "dive" and S.diveT / IntroTube.T.dive or (S.phase == "done" and 1 or 0) end
function IntroTube.insertProgress() return S.phase == "insert" and math.min(1, S.insT / IntroTube.T.insert) or 0 end

local function finish()
    if S.phase == "done" then return end
    S.phase = "done"
    if S.canvases then S.canvases = nil end
    if S.onDone then S.onDone() end
end

function IntroTube.skip()
    if S.phase == "done" then return end
    S.skipped = true
    finish()
end

-- ===================================================================
-- Update: datilografia + mergulho
-- ===================================================================
local function blip()
    local ok, Narrator = pcall(require, "src.ui.Narrator")
    if ok and Narrator.playBlip then Narrator.playBlip() end
end
local function sfx(name)
    local ok, Sfx = pcall(require, "src.systems.Sfx")
    if ok and Sfx.play then pcall(Sfx.play, name) end
end

local function typeStep(dt)
    if S.doneTyping then return end
    if S.t < IntroTube.T.typeAt then return end
    if S.pauseT > 0 then S.pauseT = S.pauseT - dt return end
    S.acc = S.acc + dt * IntroTube.T.cps
    while S.acc >= 1 do
        S.acc = S.acc - 1
        if S.shownTitle < S.lenTitle then
            S.shownTitle = S.shownTitle + 1
            S.letters = S.letters + 1
            if S.letters % 2 == 1 then blip() end
            if S.shownTitle == S.lenTitle then S.pauseT = IntroTube.T.gapSub; S.acc = 0; return end
        elseif S.shownSub < S.lenSub then
            S.shownSub = S.shownSub + 1
            local off = utf8.offset(S.sub, S.shownSub)
            local ch = off and S.sub:sub(off, off) or ""
            S.letters = S.letters + 1
            if S.letters % 2 == 1 then blip() end
            if ch == "." or ch == "!" or ch == "?" then S.pauseT = 0.28; S.acc = 0; return end
        else
            S.doneTyping = true
            return
        end
    end
end

function IntroTube.update(dt)
    if S.phase == "done" then return end
    S.t = S.t + dt
    if S.phase == "page" then
        typeStep(dt)
        if S.doneTyping then
            S.holdT = S.holdT + dt
            if S.holdT >= IntroTube.T.hold then
                if reducedMotion() then finish()
                elseif IntroTube.computerArt() then S.phase = "insert"; S.insT = 0
                else S.phase = "dive"; S.diveT = 0 end
            end
        end
    elseif S.phase == "insert" then
        S.insT = S.insT + dt
        if S.insSfx == 0 then S.insSfx = 1; sfx("cardDraw") end
        if S.insSfx == 1 and S.insT >= IntroTube.T.insert * 0.78 then S.insSfx = 2; sfx("buttonClick") end
        if S.insT >= IntroTube.T.insert + IntroTube.T.insertHold then S.phase = "dive"; S.diveT = 0 end
    elseif S.phase == "dive" then
        S.diveT = S.diveT + dt
        if S.diveT >= IntroTube.T.dive then finish() end
    end
end

-- ===================================================================
-- Draw
-- ===================================================================
-- Geometria do televisor na janela (px): canvas do tubo e escala do mergulho.
-- Com a ARTE: `art` = escala da imagem, `ax/ay` = canto dela, `sx/sy/sw/sh`
-- = a tela em px da janela; o tubo é renderizado no tamanho da tela mais o
-- gabinete do shader (que fica de fora, recortado).
function IntroTube.geometry(W, H)
    local d = IntroTube.computerArt()
    if d then
        local k = math.min((H * IntroTube.ART_FRAC) / d.h, (W * 0.62) / d.w)
        k = math.max(0.1, k)
        local aw, ah = d.w * k, d.h * k
        local ax, ay = W / 2 - aw / 2, H * 0.50 - ah / 2
        local sx, sy = ax + d.screen.x * k, ay + d.screen.y * k
        local sw, sh = d.screen.w * k, d.screen.h * k
        local tw, th = math.max(8, math.floor(sw)), math.max(8, math.floor(sh))
        local sEnd = math.max(W / sw, H / sh)
        local F = IntroTube.SLOT_FALLBACK
        local sl = d.slot or { x = d.w * F.x, y = d.h * F.y, w = d.w * F.w, h = d.h * F.h }
        return { art = k, ax = ax, ay = ay, aw = aw, ah = ah, sx = sx, sy = sy, sw = sw, sh = sh,
                 tw = tw, th = th, cx = sx + sw / 2, cy = sy + sh / 2, sEnd = sEnd,
                 innerW = sw, innerH = sh, mode = "art",
                 slot = { x = ax + sl.x * k, y = ay + sl.y * k, w = sl.w * k, h = sl.h * k } }
    end
    local tw = math.floor(W * IntroTube.TV_FRAC)
    local th = math.floor(tw * 0.75)
    local cx, cy = W / 2, H * 0.47
    -- a ABERTURA do tubo (canvas menos o gabinete) tem que encher a janela
    -- no fim do mergulho: escala pela maior razão (cobre, não cabe)
    local B = IntroTube.BEZEL_PX
    local innerW, innerH = tw - 2 * B, th - 2 * B
    local sEnd = math.max(W / innerW, H / innerH)
    return { tw = tw, th = th, cx = cx, cy = cy, sEnd = sEnd, innerW = innerW, innerH = innerH, mode = "tube" }
end

local function ensureCanvases(tw, th)
    local c = S.canvases
    if c and c.tw == tw and c.th == th then return c end
    local okA, content = pcall(love.graphics.newCanvas, tw, th)
    local okB, tube = pcall(love.graphics.newCanvas, tw, th)
    if not (okA and okB) then
        warnOnce("canvas", "canvas do televisor falhou: " .. tostring(content) .. " / " .. tostring(tube))
        S.canvases = false
        return nil
    end
    content:setFilter("linear", "linear")
    tube:setFilter("linear", "linear")
    S.canvases = { tw = tw, th = th, content = content, tube = tube }
    return S.canvases
end

local function sub(str, n)
    if n <= 0 then return "" end
    local off = utf8.offset(str, n + 1)
    return off and str:sub(1, off - 1) or str
end

-- O texto some ANTES do zoom (dono, Out/2026: "antes do zoom apague o que
-- tá escrito"): com a arte, apaga junto com o flash da carta; no televisor
-- do shader, nos últimos 0,3 s da espera. No mergulho a tela está vazia.
local function textAlpha()
    local T = IntroTube.T
    if S.phase == "page" then
        if S.doneTyping and not IntroTube.computerArt() and not reducedMotion() then
            return math.max(0, math.min(1, (T.hold - S.holdT) / 0.3))
        end
        return 1
    elseif S.phase == "insert" then
        if S.insT <= T.insert then return 1 end
        return math.max(0, 1 - (S.insT - T.insert) / T.insertHold)
    end
    return 0
end

-- O programa que passa na tela do televisor: fósforo escuro + texto
-- datilografado + cursor. Em px do canvas do tubo.
local function drawTubeContent(tw, th, alpha)
    local ta = alpha * textAlpha()
    local ink = Palette.INK
    love.graphics.clear(ink[1] * 0.55, ink[2] * 0.55, ink[3] * 0.6, 1)
    -- brilho frio do fósforo no centro (degraus, sem gradiente contínuo)
    for i = 3, 1, -1 do
        local k = i / 3
        love.graphics.setColor(0.10, 0.11, 0.10, 0.22 * (1 - k) + 0.06)
        love.graphics.rectangle("fill", tw * (0.5 - 0.5 * k), th * (0.5 - 0.5 * k), tw * k, th * k)
    end
    local titleF = FontManager.getFont(math.max(12, math.floor(tw / 14)))
    local subF = FontManager.getFont(math.max(8, math.floor(tw / 30)))
    local t1 = sub(S.title, S.shownTitle)
    local t2 = sub(S.sub, S.shownSub)
    local cur = (math.floor(love.timer.getTime() * 2.2) % 2 == 0) and "_" or ""
    local typingTitle = S.shownTitle < S.lenTitle
    local y1 = math.floor(th * 0.40 - titleF:getHeight() / 2)
    love.graphics.setFont(titleF)
    local w1 = titleF:getWidth(t1)
    local x1 = math.floor((tw - w1) / 2)
    Palette.set(Palette.INK, 0.8 * ta)
    love.graphics.print(t1, x1 + 2, y1 + 2)
    Palette.set(Palette.PARCHMENT_LIGHT, ta)
    love.graphics.print(t1 .. (typingTitle and cur or ""), x1, y1)
    if S.shownTitle >= S.lenTitle then
        -- o subtítulo cabe na ABERTURA do tubo: encolhe a fonte e, se ainda
        -- não couber, quebra em linhas (a largura do texto completo decide a
        -- quebra, pra não pular de linha enquanto datilografa)
        local inner = tw - 2 * IntroTube.BEZEL_PX - 28
        local TextFit = require("src.ui.TextFit")
        local f2 = TextFit.fit(S.sub, math.max(8, math.floor(tw / 30)), inner * 2, 7)
        local _, fullLines = f2:getWrap(S.sub, inner)
        local showCur = (S.shownSub < S.lenSub) or S.doneTyping
        local shown = t2 .. (showCur and cur or "")
        local _, lines = f2:getWrap(shown, inner)
        love.graphics.setFont(f2)
        Palette.set(Palette.PARCHMENT, ta)
        local y2 = y1 + titleF:getHeight() + math.floor(th * 0.06)
        for i, ln in ipairs(lines) do
            if i <= math.max(#fullLines, 1) + 1 then
                love.graphics.print(ln, math.floor((tw - f2:getWidth(ln)) / 2), y2 + (i - 1) * (f2:getHeight() + 4))
            end
        end
    end
    -- a carta entrou: a tela "lê" o disco num flash de fósforo que apaga
    if S.phase == "insert" and S.insT > IntroTube.T.insert then
        local k = 1 - (S.insT - IntroTube.T.insert) / IntroTube.T.insertHold
        Palette.set(Palette.PARCHMENT_LIGHT, 0.85 * math.max(0, math.min(1, k)) * alpha)
        love.graphics.rectangle("fill", 0, 0, tw, th)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- A CARTA entra na fenda do disquete (o disquete do site, no nosso visual):
-- vem do canto inferior direito já girada, endireita no caminho e some pela
-- FENDA. O truque é um recorte na linha da fenda: tudo acima dela está
-- "dentro" do gabinete, então a carta desaparece conforme sobe. Em px da
-- janela (durante a fase insert o computador está em escala 1).
local function drawInsertCard(G, W, H)
    if S.phase ~= "insert" or not G.slot then return end
    local T = IntroTube.T
    local u = easeInOutCubic(math.min(1, S.insT / T.insert))
    local sl = G.slot
    local cw = math.max(24, sl.w * 0.82)
    local ch = cw * 1.5
    local x0, y0 = W + cw * 0.8, H + ch * 0.6
    local x1, y1 = sl.x + sl.w / 2, sl.y - ch / 2 + ch * 0.05
    local x, y = x0 + (x1 - x0) * u, y0 + (y1 - y0) * u
    local rot = -0.38 * (1 - u)
    local okCB, CardBack = pcall(require, "src.ui.CardBack")
    if not okCB or not CardBack.draw then
        warnOnce("cardback", "CardBack indisponivel: abertura sem a carta na fenda")
        return
    end
    love.graphics.push("all")
    love.graphics.setScissor(0, math.floor(sl.y), W, math.max(1, H - math.floor(sl.y)))
    local ink = Palette.INK
    love.graphics.setColor(ink[1], ink[2], ink[3], 0.35)
    love.graphics.push()
    love.graphics.translate(x + 8, y + 10)
    love.graphics.rotate(rot)
    love.graphics.rectangle("fill", -cw / 2, -ch / 2, cw, ch, 4, 4)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
    CardBack.draw(x, y, cw, ch, { rot = rot, alpha = 1 })
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

-- Moldura plana de pixel art (sem shader): gabinete INK + aro + tubo.
local function drawFlatTube(content, tw, th)
    local B = IntroTube.BEZEL_PX
    local c = Palette.darken(Palette.INK, 0.6)
    love.graphics.setColor(0.115, 0.104, 0.095, 1)
    love.graphics.rectangle("fill", 0, 0, tw, th, 6, 6)
    love.graphics.setColor(c[1], c[2], c[3], 1)
    love.graphics.rectangle("fill", B - 3, B - 3, tw - 2 * B + 6, th - 2 * B + 6, 4, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(content, B, B, 0, (tw - 2 * B) / tw, (th - 2 * B) / th)
end

-- A página: pergaminho com grão e vinheta de tinta em degraus (Bayer).
local pageCanvas, pageKey
local function drawPage(W, H, alpha)
    local key = W .. "x" .. H
    if pageKey ~= key then
        pageKey = key
        local ok, cv = pcall(love.graphics.newCanvas, W, H)
        if ok then
            pageCanvas = cv
            love.graphics.push("all")
            love.graphics.setCanvas(cv)
            love.graphics.origin()
            local P = Palette.PARCHMENT
            love.graphics.clear(P[1], P[2], P[3], 1)
            -- grão fixo (hash) e vinheta em 5 degraus com dither
            local D = Palette.PARCHMENT_DARK
            local cell = math.max(2, math.floor(math.min(W, H) / 240))
            local BAYER = { { 0, 8, 2, 10 }, { 12, 4, 14, 6 }, { 3, 11, 1, 9 }, { 15, 7, 13, 5 } }
            for y = 0, H - 1, cell do
                for x = 0, W - 1, cell do
                    local nx, ny = (x / W - 0.5) * 2, (y / H - 0.5) * 2
                    local d = math.sqrt(nx * nx + ny * ny)
                    local v = math.max(0, (d - 0.55) / 0.75)
                    local step = math.floor(v * 5) / 5
                    local frac = v * 5 - math.floor(v * 5)
                    local lvl = step + ((BAYER[(y / cell) % 4 + 1][(x / cell) % 4 + 1] < frac * 16) and 0.2 or 0)
                    local g = math.sin(x * 12.9898 + y * 78.233) * 43758.5453
                    g = g - math.floor(g)
                    local a = lvl * 0.55 + ((g > 0.93) and 0.08 or 0)
                    if a > 0 then
                        love.graphics.setColor(D[1], D[2], D[3], math.min(0.8, a))
                        love.graphics.rectangle("fill", x, y, cell, cell)
                    end
                end
            end
            love.graphics.pop()
        else
            pageCanvas = nil
            warnOnce("page", "canvas da pagina falhou: " .. tostring(cv))
        end
    end
    if pageCanvas then
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(pageCanvas, 0, 0)
    else
        local P = Palette.PARCHMENT
        love.graphics.setColor(P[1], P[2], P[3], alpha)
        love.graphics.rectangle("fill", 0, 0, W, H)
    end
end

function IntroTube.draw()
    if S.phase == "done" then return end
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local G = IntroTube.geometry(W, H)
    local T = IntroTube.T
    local fade = math.min(1, S.t / T.fadeIn)
    local dive = (S.phase == "dive") and easeInOutCubic(S.diveT / T.dive) or 0
    if reducedMotion() then fade = 1 end

    -- página (escurece no mergulho: a sala some, só o tubo fica)
    drawPage(W, H, 1)
    if dive > 0 then
        love.graphics.setColor(0, 0, 0, dive)
        love.graphics.rectangle("fill", 0, 0, W, H)
    end

    local pop = reducedMotion() and 1 or (0.92 + 0.08 * easeOutBack(math.min(1, S.t / T.tvPop)))
    local scale = pop * (1 + (G.sEnd - 1) * dive)
    local tvAlpha = fade
    if G.mode == "art" then
        -- a ARTE do computador: tubo (recortado, sem gabinete) dentro da
        -- tela, a imagem por cima; tudo escala em torno do centro da tela
        local B = IntroTube.BEZEL_PX
        local c = ensureCanvases(G.tw + 2 * B, G.th + 2 * B)
        local d = IntroTube.computerArt()
        love.graphics.push()
        love.graphics.translate(G.cx, G.cy)
        love.graphics.scale(scale, scale)
        love.graphics.translate(-G.cx, -G.cy)
        if dive < 1 then
            local sh = Palette.INK
            love.graphics.setColor(sh[1], sh[2], sh[3], 0.40 * tvAlpha * (1 - dive))
            love.graphics.rectangle("fill", G.ax + 10, G.ay + 12, G.aw, G.ah, 6, 6)
        end
        if c then
            love.graphics.push("all")
            love.graphics.setCanvas(c.content)
            love.graphics.origin()
            love.graphics.clear(0, 0, 0, 1)
            love.graphics.translate(B, B)
            drawTubeContent(G.tw, G.th, 1)
            love.graphics.pop()
            local CRT = require("src.ui.CRTShader")
            local okTube = CRT.renderTube and CRT.renderTube(c.content, c.tube)
            local src = okTube and c.tube or c.content
            if not okTube then warnOnce("shader", "crt.glsl indisponivel: tela do computador sem curvatura") end
            local cw, ch = src:getDimensions()
            S.quad = S.quad or love.graphics.newQuad(0, 0, 1, 1, 1, 1)
            S.quad:setViewport(B, B, cw - 2 * B, ch - 2 * B, cw, ch)
            love.graphics.setColor(1, 1, 1, tvAlpha)
            love.graphics.draw(src, S.quad, G.sx, G.sy, 0, G.sw / (cw - 2 * B), G.sh / (ch - 2 * B))
        end
        love.graphics.setColor(1, 1, 1, tvAlpha)
        love.graphics.draw(d.img, G.ax, G.ay, 0, G.art, G.art)
        drawInsertCard(G, W, H)
        love.graphics.pop()
        love.graphics.setColor(1, 1, 1, 1)
    end
    -- o televisor do shader (sem a arte): conteúdo -> tubo (shader) -> na página
    local c = (G.mode == "tube") and ensureCanvases(G.tw, G.th) or nil
    if c then
        love.graphics.push("all")
        love.graphics.setCanvas(c.content)
        love.graphics.origin()
        drawTubeContent(G.tw, G.th, 1)
        love.graphics.pop()
        local CRT = require("src.ui.CRTShader")
        local okTube = CRT.renderTube and CRT.renderTube(c.content, c.tube)
        if not okTube then
            love.graphics.push("all")
            love.graphics.setCanvas(c.tube)
            love.graphics.origin()
            love.graphics.clear(0, 0, 0, 0)
            drawFlatTube(c.content, G.tw, G.th)
            love.graphics.pop()
            warnOnce("shader", "crt.glsl indisponivel: televisor da abertura em moldura plana")
        end
        -- sombra dura do televisor na página (luz do alto à esquerda)
        if dive < 1 then
            local sh = Palette.INK
            love.graphics.setColor(sh[1], sh[2], sh[3], 0.45 * tvAlpha * (1 - dive))
            love.graphics.rectangle("fill", G.cx - G.tw / 2 * scale + 10, G.cy - G.th / 2 * scale + 12,
                G.tw * scale, G.th * scale, 8, 8)
        end
        love.graphics.setColor(1, 1, 1, tvAlpha)
        love.graphics.draw(c.tube, G.cx, G.cy, 0, scale, scale, G.tw / 2, G.th / 2)
    end

    -- dica de pular (some no mergulho)
    if dive <= 0 and S.t > 0.6 then
        local font = FontManager.getFont(10)
        love.graphics.setFont(font)
        local label = I18n.t("boot.skip_hint")
        local pulse = 0.5 + math.sin(love.timer.getTime() * 2) * 0.2
        local D = Palette.PARCHMENT_DARK
        love.graphics.setColor(D[1], D[2], D[3], pulse * fade)
        love.graphics.print(label, math.floor((W - font:getWidth(label)) / 2), H - 28)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function IntroTube.keypressed() if S.phase ~= "done" then IntroTube.skip() end end
function IntroTube.mousepressed() if S.phase ~= "done" then IntroTube.skip() end end
function IntroTube.resize() S.canvases = nil; pageKey = nil end
function IntroTube.mode() return IntroTube.geometry(love.graphics.getWidth(), love.graphics.getHeight()).mode end
function IntroTube._state() return S end

return IntroTube
