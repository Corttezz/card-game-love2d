local Debug = require("src.core.Debug")

local Narrator = {}

local utf8 = require("utf8")

Narrator.NAME_KEY = "tutorial.narrator.name"
Narrator.CPS = 52
Narrator.SPRITE_W, Narrator.SPRITE_H = 94, 93
Narrator.BOOK_Y = 57
Narrator.BUBBLE_MAX_W = 470
Narrator.PAD = 14
Narrator.MARGIN = 14

local PAUSE_LONG, PAUSE_SHORT = 0.24, 0.09
local BLIP_EVERY = 2
local BLIP_COUNT = 6

local frames
local warned = {}
local function warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    Debug.warn("[Narrator] AVISO: " .. msg)
end

local function loadFrames()
    if frames then return frames end
    frames = {}
    for _, n in ipairs({ "idle", "talk", "blink", "idle_breathe", "talk_breathe", "blink_breathe" }) do
        local path = "assets/sprites/narrator/raven_" .. n .. ".png"
        local ok, img = pcall(love.graphics.newImage, path)
        if ok and img then
            img:setFilter("nearest", "nearest")
            frames[n] = img
        else
            warnOnce(path, "quadro do corvo nao carregou: " .. path)
        end
    end
    return frames
end

local voice = nil
local voiceData = {}

local function audioOk()
    local a = _G.audioSystem
    return a and a.isAudioAvailable and a:isAudioAvailable()
end

local function ensureVoice()
    if voice then return true end
    if not audioOk() then return false end
    voice = {}
    for i = 1, BLIP_COUNT do
        local path = "audio/sfx/narrator/blip_" .. i .. ".wav"
        if not voiceData[i] then
            local ok, sd = pcall(love.sound.newSoundData, path)
            if ok then voiceData[i] = sd else warnOnce(path, "blip do narrador nao carregou: " .. path) end
        end
        if voiceData[i] then
            local ok, src = pcall(love.audio.newSource, voiceData[i], "static")
            if ok then voice[i] = src end
        end
    end
    return true
end

function Narrator.releaseVoice()
    if not voice then return end
    for _, src in pairs(voice) do
        pcall(function() src:stop(); src:release() end)
    end
    voice = nil
end

function Narrator.voiceCount()
    local n = 0
    for _ in pairs(voice or {}) do n = n + 1 end
    return n
end
Narrator.BLIP_COUNT = BLIP_COUNT

local function tokenize(text)
    local words = {}
    local emph = false
    local cur, curEmph, pendingSpace = {}, false, false
    local function flush()
        if #cur > 0 then
            words[#words + 1] = { text = table.concat(cur), emph = curEmph, space = pendingSpace }
            cur = {}
            pendingSpace = false
        end
    end
    for _, cp in utf8.codes(text) do
        local ch = utf8.char(cp)
        if ch == "*" then
            flush()
            emph = not emph
            curEmph = emph
        elseif ch == " " or ch == "\n" then
            flush()
            pendingSpace = true
            if ch == "\n" then
                words[#words + 1] = { text = "", newline = true }
                pendingSpace = false
            end
        else
            if #cur == 0 then curEmph = emph end
            cur[#cur + 1] = ch
        end
    end
    flush()
    return words
end

function Narrator.wrap(text, font, width)
    local lines = { {} }
    local lineW = 0
    for _, w in ipairs(tokenize(text or "")) do
        if w.newline then
            lines[#lines + 1] = {}
            lineW = 0
        else
            local piece = (w.space and lineW > 0) and (" " .. w.text) or w.text
            local pw = font:getWidth(piece)
            if lineW > 0 and lineW + pw > width and w.space then
                lines[#lines + 1] = {}
                lineW = 0
                piece = w.text
                pw = font:getWidth(piece)
            end
            local line = lines[#lines]
            line[#line + 1] = { text = piece, emph = w.emph, chars = utf8.len(piece) or #piece }
            lineW = lineW + pw
        end
    end
    local total = 0
    for _, line in ipairs(lines) do
        for _, p in ipairs(line) do total = total + p.chars end
    end
    return lines, total
end

local S = {
    text = nil, plain = nil, shown = 0, total = 0, pause = 0, acc = 0,
    beakT = 0, blinkT = 0, nextBlink = 3, hopT = 0, t = 0,
    letters = 0, lastBlip = 0,
    px = nil, py = nil, slide = 0, flip = false,
}
Narrator.state = S

function Narrator.say(text)
    S.text = text or ""
    S.plain = S.text:gsub("%*", "")
    S.total = utf8.len(S.plain) or #S.plain
    S.shown, S.pause, S.acc, S.letters = 0, 0, 0, 0
    S.hopT = 0.30
end

function Narrator.isRevealing() return S.text ~= nil and S.shown < S.total end
function Narrator.finishReveal() S.shown = S.total; S.pause = 0 end

local function charAt(i)
    local off = utf8.offset(S.plain, i)
    if not off then return "" end
    local nxt = utf8.offset(S.plain, i + 1) or (#S.plain + 1)
    return S.plain:sub(off, nxt - 1)
end

local function blip()
    if not ensureVoice() then return end
    local i
    repeat i = love.math.random(1, BLIP_COUNT) until i ~= S.lastBlip or BLIP_COUNT == 1
    S.lastBlip = i
    local src = voice[i]
    if not src then return end
    local a = _G.audioSystem
    local g = (a and a.groups) or {}
    src:stop()
    src:setVolume(0.32 * (g.sfx or 1) * (g.master or 1))
    src:setPitch(0.96 + love.math.random() * 0.10)
    src:play()
end

function Narrator.playBlip() blip() end

function Narrator.update(dt)
    S.t = S.t + dt
    if S.hopT > 0 then S.hopT = math.max(0, S.hopT - dt) end
    if S.beakT > 0 then S.beakT = math.max(0, S.beakT - dt) end
    S.nextBlink = S.nextBlink - dt
    if S.nextBlink <= 0 then
        S.blinkT = 0.13
        S.nextBlink = 2.5 + love.math.random() * 2.5
    end
    if S.blinkT > 0 then S.blinkT = math.max(0, S.blinkT - dt) end
    if S.text and S.shown < S.total then
        if S.pause > 0 then
            S.pause = S.pause - dt
        else
            S.acc = S.acc + dt * Narrator.CPS
            while S.acc >= 1 and S.shown < S.total do
                S.acc = S.acc - 1
                S.shown = S.shown + 1
                local ch = charAt(S.shown)
                if ch:match("[%w\128-\255]") then
                    S.letters = S.letters + 1
                    if S.letters % BLIP_EVERY == 1 then
                        blip()
                        S.beakT = 0.075
                    end
                end
                if ch == "." or ch == "!" or ch == "?" then
                    S.pause = PAUSE_LONG; S.acc = 0; break
                elseif ch == "," or ch == ";" or ch == ":" or ch == "—" then
                    S.pause = PAUSE_SHORT; S.acc = 0; break
                end
            end
        end
    end
end

local function fonts(k)
    local FM = require("src.ui.FontManager")
    return FM.getFont(math.max(9, math.floor(13 * k))),
           FM.getFont(math.max(8, math.floor(11 * k))),
           FM.getFont(math.max(7, math.floor(8 * k)))
end
Narrator.fonts = fonts

function Narrator.spriteScale(k)
    return math.max(2, math.floor(2 * k + 0.5))
end

local function footItemW(it, k)
    if not it then return 0 end
    local _, _, fF = fonts(k)
    local gs = math.floor(16 * k)
    local gw = it.glyph and (math.max(gs, fF:getWidth(it.glyph) + 8) + math.floor(4 * k)) or 0
    return gw + fF:getWidth(it.label or "")
end
Narrator.footItemW = footItemW

function Narrator.measure(text, k, W, footer)
    local fB, fN, fF = fonts(k)
    local s = Narrator.spriteScale(k)
    local pad = math.floor(Narrator.PAD * k)
    local maxW = math.min(math.floor(Narrator.BUBBLE_MAX_W * k),
        W - Narrator.SPRITE_W * s - math.floor(Narrator.MARGIN * k) * 3)
    maxW = math.max(math.floor(200 * k), maxW)
    local inner = maxW - pad * 2
    local lines = Narrator.wrap(text, fB, inner)
    local w = 0
    for _, line in ipairs(lines) do
        local lw = 0
        for _, p in ipairs(line) do lw = lw + fB:getWidth(p.text) end
        w = math.max(w, lw)
    end
    local lw_, rw_ = footItemW(footer and footer.left, k), footItemW(footer and footer.right, k)
    local fgap = math.floor(18 * k)
    local stack = (lw_ + rw_ + fgap) > inner
    w = math.max(w, stack and math.max(lw_, rw_) or (lw_ + rw_ + fgap), math.floor(180 * k))
    local lh = math.floor(fB:getHeight() * 1.35)
    local nameH = fN:getHeight() + math.floor(6 * k)
    local rowH = math.max(fF:getHeight(), math.floor(16 * k))
    local footH = (stack and (rowH * 2 + math.floor(4 * k)) or rowH) + math.floor(8 * k)
    local h = pad + nameH + #lines * lh + footH + pad
    return { w = math.min(maxW, w + pad * 2), h = h, lines = lines, lh = lh,
        pad = pad, nameH = nameH, footH = footH, footStack = stack, rowH = rowH }
end

local function overlap(a, b)
    if not (a and b) then return 0 end
    local x1 = math.max(a.x, b.x)
    local y1 = math.max(a.y, b.y)
    local x2 = math.min(a.x + a.w, b.x + b.w)
    local y2 = math.min(a.y + a.h, b.y + b.h)
    if x2 <= x1 or y2 <= y1 then return 0 end
    return (x2 - x1) * (y2 - y1)
end
Narrator.overlap = overlap

function Narrator.layout(size, W, H, k, spot, avoid, keep)
    local s = Narrator.spriteScale(k)
    local rw, rh = Narrator.SPRITE_W * s, Narrator.SPRITE_H * s
    local m = math.floor(Narrator.MARGIN * k)
    local gap = math.floor(6 * k)
    local pw = rw + gap + size.w
    local ph = math.max(rh, size.h + math.floor(rh * 0.25))
    local topY = 0
    for _, z in ipairs(avoid or {}) do
        if z.y <= 0 then topY = math.max(topY, z.y + z.h) end
    end
    local function make(side, x, y)
        local flip = side:find("right") ~= nil
        local P = { x = x, y = y, w = pw, h = ph }
        local raven, bubble
        if flip then
            raven = { x = x + pw - rw, y = y + ph - rh, w = rw, h = rh }
            bubble = { x = x, y = y + ph - rh * 0.25 - size.h, w = size.w, h = size.h }
        else
            raven = { x = x, y = y + ph - rh, w = rw, h = rh }
            bubble = { x = x + rw + gap, y = y + ph - rh * 0.25 - size.h, w = size.w, h = size.h }
        end
        bubble.y = math.max(y, bubble.y)
        return { side = side, panel = P, raven = raven, bubble = bubble, flip = flip }
    end
    local cands = {
        make("bottom_left", m, H - m - ph),
        make("bottom_right", W - m - pw, H - m - ph),
        make("top_left", m, topY + m),
        make("top_right", W - m - pw, topY + m),
        make("mid_left", m, math.floor((H - ph) / 2)),
        make("mid_right", W - m - pw, math.floor((H - ph) / 2)),
    }
    local padSpot = spot and { x = spot.x - 10 * k, y = spot.y - 10 * k,
        w = spot.w + 20 * k, h = spot.h + 20 * k }
    local function score(c)
        local sc = 0
        for _, r in ipairs({ c.raven, c.bubble }) do
            sc = sc + overlap(r, padSpot) * 10
            for _, z in ipairs(avoid or {}) do sc = sc + overlap(r, z) * 4 end
            if r.x < 0 or r.y < 0 or r.x + r.w > W or r.y + r.h > H then
                sc = sc + 1e7
            end
        end
        return sc
    end
    local best, bestScore
    for i, c in ipairs(cands) do
        local sc = score(c) + i
        if keep and c.side == keep and score(c) == 0 then return c end
        if not bestScore or sc < bestScore then best, bestScore = c, sc end
    end
    best.score = bestScore - 1
    return best
end

function Narrator.validate(L, W, H, spot, avoid)
    local errs = {}
    for name, r in pairs({ raven = L.raven, bubble = L.bubble }) do
        if r.x < -0.5 or r.y < -0.5 or r.x + r.w > W + 0.5 or r.y + r.h > H + 0.5 then
            errs[#errs + 1] = name .. " sai da tela"
        end
        if spot and overlap(r, spot) > 0 then errs[#errs + 1] = name .. " cobre o recorte" end
        for _, z in ipairs(avoid or {}) do
            if overlap(r, z) > 0 then errs[#errs + 1] = name .. " cobre a TopBar" end
        end
    end
    return #errs == 0, errs
end

local function setC(c, a)
    love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * (a or 1))
end

function Narrator.drawSpotlight(spot, W, H, k, alpha, dimA, towards)
    local g = love.graphics
    local a = (dimA or 0.62) * alpha
    g.setColor(0.02, 0.015, 0.03, a)
    if not spot then
        g.rectangle("fill", 0, 0, W, H)
        return
    end
    local pad = math.floor(10 * k)
    local x, y = math.floor(spot.x - pad), math.floor(spot.y - pad)
    local w, h = math.floor(spot.w + pad * 2), math.floor(spot.h + pad * 2)
    g.rectangle("fill", 0, 0, W, math.max(0, y))
    g.rectangle("fill", 0, y + h, W, math.max(0, H - y - h))
    g.rectangle("fill", 0, y, math.max(0, x), h)
    g.rectangle("fill", x + w, y, math.max(0, W - x - w), h)
    local pulse = 0.55 + 0.45 * math.sin(love.timer.getTime() * 4.2)
    local Palette = require("src.ui.Palette")
    local lw = math.max(2, math.floor(2 * k))
    setC(Palette.AGED_GOLD_LIGHT, alpha * (0.65 + 0.35 * pulse))
    g.setLineWidth(lw)
    g.rectangle("line", x, y, w, h)
    setC(Palette.AGED_GOLD, alpha * 0.45 * pulse)
    g.rectangle("line", x - lw * 2, y - lw * 2, w + lw * 4, h + lw * 4)
    g.setLineWidth(1)
    local cx, cy = x + w / 2, y + h / 2
    local tx, ty = towards and towards.x or cx, towards and towards.y or (cy - 1)
    local dx, dy = tx - cx, ty - cy
    local bob = math.floor(math.abs(math.sin(love.timer.getTime() * 5)) * 7 * k)
    local sz = math.floor(10 * k)
    local ax, ay, dir
    if math.abs(dx) / math.max(1, w) > math.abs(dy) / math.max(1, h) then
        dir = dx < 0 and "left" or "right"
        ay = cy
        ax = dir == "left" and (x - lw * 3 - sz - bob) or (x + w + lw * 3 + sz + bob)
    else
        dir = dy < 0 and "up" or "down"
        ax = cx
        ay = dir == "up" and (y - lw * 3 - sz - bob) or (y + h + lw * 3 + sz + bob)
    end
    if ay - sz < 0 then dir, ay = "down", y + h + lw * 3 + sz + bob end
    if ay + sz > H then dir, ay = "up", y - lw * 3 - sz - bob end
    local pts
    if dir == "up" then
        pts = { ax - sz, ay - sz, ax + sz, ay - sz, ax, ay + sz * 0.4 }
    elseif dir == "down" then
        pts = { ax - sz, ay + sz, ax + sz, ay + sz, ax, ay - sz * 0.4 }
    elseif dir == "left" then
        pts = { ax - sz, ay - sz, ax - sz, ay + sz, ax + sz * 0.4, ay }
    else
        pts = { ax + sz, ay - sz, ax + sz, ay + sz, ax - sz * 0.4, ay }
    end
    setC(Palette.INK, alpha)
    g.push(); g.translate(math.floor(2 * k), math.floor(2 * k)); g.polygon("fill", pts); g.pop()
    setC(Palette.AGED_GOLD_LIGHT, alpha)
    g.polygon("fill", pts)
end

local function frameName()
    local base = (S.beakT > 0) and "talk" or ((S.blinkT > 0) and "blink" or "idle")
    local breathe = math.sin(S.t * 2.4) > 0.25
    return breathe and (base .. "_breathe") or base
end

local quadCache = {}
local function quadsFor(iw, ih)
    local key = iw .. "x" .. ih
    local q = quadCache[key]
    if not q then
        local by = Narrator.BOOK_Y
        q = { love.graphics.newQuad(0, by, iw, ih - by, iw, ih),
              love.graphics.newQuad(0, 0, iw, by, iw, ih) }
        quadCache[key] = q
    end
    return q[1], q[2]
end

function Narrator.drawRaven(r, flip, alpha, k)
    local F = loadFrames()
    local img = F[frameName()] or F.idle
    if not img then
        love.graphics.setColor(0.1, 0.08, 0.12, alpha)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
        return
    end
    local s = Narrator.spriteScale(k)
    local iw, ih = img:getDimensions()
    local hop = 0
    if S.hopT > 0 then hop = math.floor(math.sin((1 - S.hopT / 0.30) * math.pi) * 4) end
    local sx = flip and -s or s
    local ox = flip and (r.x + r.w) or r.x
    love.graphics.setColor(1, 1, 1, alpha)
    local by = Narrator.BOOK_Y
    local qBook, qBird = quadsFor(iw, ih)
    love.graphics.draw(img, qBook, math.floor(ox), math.floor(r.y + by * s), 0, sx, s)
    love.graphics.draw(img, qBird, math.floor(ox), math.floor(r.y - hop * s), 0, sx, s)
end

function Narrator.drawBubble(b, size, alpha, k, flip, footer)
    local g = love.graphics
    local Palette = require("src.ui.Palette")
    local fB, fN, fF = fonts(k)
    local pad = size.pad
    local x, y, w, h = math.floor(b.x), math.floor(b.y), math.floor(b.w), math.floor(b.h)
    setC(Palette.INK, alpha * 0.6)
    g.rectangle("fill", x + math.floor(4 * k), y + math.floor(4 * k), w, h)
    setC(Palette.PARCHMENT_LIGHT, alpha)
    g.rectangle("fill", x, y, w, h)
    setC(Palette.PARCHMENT, alpha * 0.55)
    g.rectangle("fill", x, y + h - math.floor(size.footH + pad * 0.5), w, math.floor(size.footH + pad * 0.5))
    local lw = math.max(2, math.floor(2 * k))
    g.setLineWidth(lw)
    setC(Palette.INK, alpha)
    g.rectangle("line", x, y, w, h)
    setC(Palette.AGED_GOLD, alpha)
    g.rectangle("line", x + lw * 2, y + lw * 2, w - lw * 4, h - lw * 4)
    g.setLineWidth(1)
    local ty = y + h - math.floor(28 * k)
    local tail
    if flip then
        tail = { x + w, ty, x + w + math.floor(12 * k), ty + math.floor(8 * k), x + w, ty + math.floor(16 * k) }
    else
        tail = { x, ty, x - math.floor(12 * k), ty + math.floor(8 * k), x, ty + math.floor(16 * k) }
    end
    setC(Palette.PARCHMENT_LIGHT, alpha); g.polygon("fill", tail)
    setC(Palette.INK, alpha); g.setLineWidth(lw); g.line(tail); g.setLineWidth(1)
    local I18n = require("src.i18n.I18n")
    local name = I18n.t(Narrator.NAME_KEY, nil, "Pena")
    g.setFont(fN)
    setC(Palette.BLOOD, alpha)
    g.print(name, x + pad, y + pad)
    g.setFont(fB)
    local cy = y + pad + size.nameH
    local left = S.shown
    for _, line in ipairs(size.lines) do
        local cx = x + pad
        for _, p in ipairs(line) do
            if left <= 0 then break end
            local txt = p.text
            if left < p.chars then
                local cut = utf8.offset(txt, left + 1)
                txt = txt:sub(1, (cut or (#txt + 1)) - 1)
            end
            left = left - p.chars
            setC(p.emph and Palette.BLOOD or Palette.INK, alpha)
            g.print(txt, math.floor(cx), math.floor(cy))
            cx = cx + fB:getWidth(p.text)
        end
        cy = cy + size.lh
    end
    if footer then
        local gs = math.floor(16 * k)
        local fy = y + h - pad - gs
        local fyR = size.footStack and (fy - size.rowH - math.floor(4 * k)) or fy
        local okNC, NC = pcall(require, "src.ui.NavCursor")
        g.setFont(fF)
        local function glyph(lbl, gx)
            if okNC and NC.drawGlyph and lbl then
                return NC.drawGlyph(lbl, gx, fy, gs)
            end
            return 0
        end
        if footer.left then
            local gx = x + pad
            local gw = glyph(footer.left.glyph, gx)
            g.setFont(fF)
            setC(Palette.PARCHMENT_DARK, alpha)
            g.print(footer.left.label, gx + gw + math.floor(4 * k),
                math.floor(fy + (gs - fF:getHeight()) / 2))
            footer.left.rect = { x = gx, y = fy, w = gw + 4 * k + fF:getWidth(footer.left.label), h = gs }
        end
        if footer.right and not Narrator.isRevealing() then
            local label = footer.right.label
            local lwid = fF:getWidth(label)
            local gw0 = footer.right.glyph and math.max(gs, fF:getWidth(footer.right.glyph) + 8) or 0
            local bob = math.floor(math.abs(math.sin(love.timer.getTime() * 4)) * 2 * k)
            local gx = x + w - pad - lwid - gw0 - math.floor(4 * k)
            local sfy = fy
            fy = fyR
            glyph(footer.right.glyph, gx)
            fy = sfy
            g.setFont(fF)
            setC(footer.right.gold and Palette.BLOOD or Palette.INK, alpha)
            g.print(label, gx + gw0 + math.floor(4 * k) + bob, math.floor(fyR + (gs - fF:getHeight()) / 2))
        end
    end
end

function Narrator._reset()
    S.text, S.plain, S.shown, S.total, S.pause, S.acc = nil, nil, 0, 0, 0, 0
    S.beakT, S.blinkT, S.hopT, S.letters = 0, 0, 0, 0
    S.px, S.py, S.slide = nil, nil, 0
end

return Narrator
