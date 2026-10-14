local Debug = require("src.core.Debug")

local Palette     = require("src.ui.Palette")
local FontManager = require("src.ui.FontManager")
local I18n        = require("src.i18n.I18n")

local IntroTube = {}

IntroTube.T = {
    fadeIn = 0.35,
    tvPop  = 0.45,
    typeAt = 0.80,
    gapSub = 0.35,
    hold   = 0.90,
    insert = 1.10,
    insertHold = 0.35,
    dive   = 1.00,
    cps    = 22,
}
IntroTube.TV_FRAC  = 0.46
IntroTube.DATA_PATH = "src/data/intro_computer.lua"
IntroTube.ART_FRAC  = 0.70
IntroTube.SLOT_FALLBACK = { x = 0.52, y = 0.80, w = 0.34, h = 0.03 }
IntroTube.BEZEL_PX = 20
IntroTube.CORNER   = 0.012

local S = {}
local utf8 = require("utf8")

local artCache = { path = nil, data = false }
function IntroTube.computerArt()
    local path = IntroTube.DATA_PATH
    if artCache.path == path then return artCache.data or nil end
    artCache.path = path
    artCache.data = false
    if not (path and love.filesystem.getInfo(path)) then return nil end
    local ok, chunk = pcall(love.filesystem.load, path)
    if not ok or not chunk then
        Debug.warn("[IntroTube] dados do computador ilegiveis: " .. tostring(chunk))
        return nil
    end
    local okR, d = pcall(chunk)
    if not okR or type(d) ~= "table" or not d.image or not d.screen then
        Debug.warn("[IntroTube] dados do computador invalidos em " .. path)
        return nil
    end
    local okI, img = pcall(love.graphics.newImage, d.image)
    if not okI then
        Debug.warn("[IntroTube] arte do computador nao carregou: " .. tostring(img))
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
    Debug.warn("[IntroTube] " .. msg)
end

function IntroTube.init(opts)
    opts = opts or {}
    S = {
        phase = "page",
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
function IntroTube.endedWithDive() return S.dove == true end
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
        if S.diveT >= IntroTube.T.dive then S.dove = true; finish() end
    end
end

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
        local B = IntroTube.BEZEL_PX
        local sEndX, sEndY = (W - 2 * B) / sw, (H - 2 * B) / sh
        local sEnd = math.max(sEndX, sEndY)
        local F = IntroTube.SLOT_FALLBACK
        local sl = d.slot or { x = d.w * F.x, y = d.h * F.y, w = d.w * F.w, h = d.h * F.h }
        return { art = k, ax = ax, ay = ay, aw = aw, ah = ah, sx = sx, sy = sy, sw = sw, sh = sh,
                 tw = tw, th = th, cx = sx + sw / 2, cy = sy + sh / 2, sEnd = sEnd,
                 sEndX = sEndX, sEndY = sEndY,
                 innerW = sw, innerH = sh, mode = "art",
                 slot = { x = ax + sl.x * k, y = ay + sl.y * k, w = sl.w * k, h = sl.h * k } }
    end
    local tw = math.floor(W * IntroTube.TV_FRAC)
    local th = math.floor(tw * 0.75)
    local cx, cy = W / 2, H * 0.47
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

local function drawTubeContent(tw, th, alpha)
    local ta = alpha * textAlpha()
    local ink = Palette.INK
    love.graphics.clear(ink[1] * 0.55, ink[2] * 0.55, ink[3] * 0.6, 1)
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
    if S.phase == "insert" and S.insT > IntroTube.T.insert then
        local k = 1 - (S.insT - IntroTube.T.insert) / IntroTube.T.insertHold
        Palette.set(Palette.PARCHMENT_LIGHT, 0.85 * math.max(0, math.min(1, k)) * alpha)
        love.graphics.rectangle("fill", 0, 0, tw, th)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

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

    drawPage(W, H, 1)
    if dive > 0 then
        love.graphics.setColor(0, 0, 0, dive)
        love.graphics.rectangle("fill", 0, 0, W, H)
    end

    local pop = reducedMotion() and 1 or (0.92 + 0.08 * easeOutBack(math.min(1, S.t / T.tvPop)))
    local scale = pop * (1 + (G.sEnd - 1) * dive)
    local tvAlpha = fade
    if G.mode == "art" then
        local B = IntroTube.BEZEL_PX
        local d = IntroTube.computerArt()
        local sxK = pop * (1 + (G.sEndX - 1) * dive)
        local syK = pop * (1 + (G.sEndY - 1) * dive)
        local px, py = G.cx + (W / 2 - G.cx) * dive, G.cy + (H / 2 - G.cy) * dive
        local c = (dive > 0) and ensureCanvases(W, H) or ensureCanvases(G.tw + 2 * B, G.th + 2 * B)
        love.graphics.push()
        love.graphics.translate(px, py)
        love.graphics.scale(sxK, syK)
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
            local cw0, ch0 = c.content:getDimensions()
            drawTubeContent(cw0 - 2 * B, ch0 - 2 * B, 1)
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
        if dive < 1 then
            local sh = Palette.INK
            love.graphics.setColor(sh[1], sh[2], sh[3], 0.45 * tvAlpha * (1 - dive))
            love.graphics.rectangle("fill", G.cx - G.tw / 2 * scale + 10, G.cy - G.th / 2 * scale + 12,
                G.tw * scale, G.th * scale, 8, 8)
        end
        love.graphics.setColor(1, 1, 1, tvAlpha)
        love.graphics.draw(c.tube, G.cx, G.cy, 0, scale, scale, G.tw / 2, G.th / 2)
    end

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
