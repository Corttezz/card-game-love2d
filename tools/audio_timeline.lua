local TL = {}

local cur = nil

TL.STATE_COLORS = {
    playing = { 0.30, 0.45, 0.75 }, roundEval = { 0.75, 0.60, 0.25 }, cardReward = { 0.60, 0.45, 0.20 },
    mapSelection = { 0.35, 0.60, 0.35 }, gameOver = { 0.70, 0.20, 0.20 }, victory = { 0.80, 0.70, 0.30 },
    menu = { 0.45, 0.45, 0.45 }, rest = { 0.55, 0.35, 0.55 }, event = { 0.35, 0.55, 0.60 },
}

function TL.start(name)
    cur = { name = name, samples = {}, events = {}, t0 = nil }
end

function TL.active() return cur ~= nil end

function TL.sample(clock, st, vol, duck, codes, filterOn, phase)
    if not cur then return end
    cur.t0 = cur.t0 or clock
    cur.samples[#cur.samples + 1] = { t = clock - cur.t0, st = st, vol = vol, duck = duck, codes = codes,
        filter = filterOn, phase = phase }
end

function TL.event(clock, label)
    if not cur then return end
    cur.t0 = cur.t0 or clock
    cur.events[#cur.events + 1] = { t = clock - cur.t0, label = label }
end

local function outDir()
    local d = love.filesystem.getSource() .. "/tools/preview_out/audio_fluxo/"
    os.execute('mkdir "' .. d:gsub("/", "\\") .. '" 2>nul')
    return d
end

function TL.finish()
    local c = cur
    cur = nil
    if not c or #c.samples < 2 then return nil end
    local W, H = 1600, 460
    local L, R, T, B = 60, 20, 40, 120
    local span = math.max(1, c.samples[#c.samples].t)
    local function X(t) return L + (W - L - R) * (t / span) end
    local function Y(v) return T + (H - T - B) * (1 - math.max(0, math.min(1.05, v)) / 1.05) end
    local canvas = love.graphics.newCanvas(W, H)
    local font = love.graphics.newFont(12)
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.07, 0.07, 0.08, 1)
    love.graphics.setFont(font)
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    love.graphics.print(c.name .. "  (verde = musica / ajuste, laranja = duck, azul = passa-baixa, vermelho = eventos)", L, 10)
    love.graphics.setColor(0.25, 0.25, 0.28, 1)
    for v = 0, 1, 0.25 do
        love.graphics.line(L, Y(v), W - R, Y(v))
        love.graphics.print(("%.2f"):format(v), 8, Y(v) - 7)
    end
    for s = 0, math.floor(span) do
        love.graphics.setColor(0.25, 0.25, 0.28, 1)
        love.graphics.line(X(s), T, X(s), H - B)
        love.graphics.setColor(0.6, 0.6, 0.6, 1)
        love.graphics.print(tostring(s) .. "s", X(s) - 6, H - B + 4)
    end
    for i = 2, #c.samples do
        local a, b = c.samples[i - 1], c.samples[i]
        if a.filter then
            love.graphics.setColor(0.2, 0.4, 0.9, 0.25)
            love.graphics.rectangle("fill", X(a.t), T, math.max(1, X(b.t) - X(a.t)), H - B - T)
        end
        love.graphics.setColor(0.3, 1.0, 0.4, 1)
        love.graphics.setLineWidth(3)
        love.graphics.line(X(a.t), Y(a.vol), X(b.t), Y(b.vol))
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1.0, 0.6, 0.2, 1)
        love.graphics.line(X(a.t), Y(a.duck) - 1, X(b.t), Y(b.duck) - 1)
        local col = TL.STATE_COLORS[a.st] or { 0.3, 0.3, 0.3 }
        love.graphics.setColor(col[1], col[2], col[3], 1)
        love.graphics.rectangle("fill", X(a.t), H - B + 22, math.max(1, X(b.t) - X(a.t)) + 1, 14)
        if a.phase then
            love.graphics.setColor(0.8, 0.3, 0.8, 1)
            love.graphics.rectangle("fill", X(a.t), H - B + 38, math.max(1, X(b.t) - X(a.t)) + 1, 8)
        end
    end
    local lastSt, lastCodes = nil, nil
    for _, s in ipairs(c.samples) do
        if s.st ~= lastSt then
            lastSt = s.st
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(tostring(s.st), X(s.t) + 2, H - B + 48)
        end
        if s.codes ~= lastCodes then
            lastCodes = s.codes
            love.graphics.setColor(0.6, 0.9, 0.6, 1)
            love.graphics.print(s.codes, X(s.t) + 2, H - B + 64)
        end
    end
    local row = 0
    for _, e in ipairs(c.events) do
        love.graphics.setColor(1, 0.3, 0.3, 1)
        love.graphics.line(X(e.t), T, X(e.t), H - B)
        love.graphics.print(e.label, X(e.t) + 3, T + 2 + (row % 6) * 14)
        row = row + 1
    end
    love.graphics.setCanvas()
    love.graphics.pop()
    local img = canvas:newImageData()
    local path = outDir() .. c.name .. ".png"
    local fd = img:encode("png")
    local f = io.open(path, "wb")
    if f then f:write(fd:getString()); f:close() end
    fd:release()
    img:release()
    canvas:release()
    font:release()
    love.graphics.present()
    print("[audio_timeline] " .. path)
    return path
end

return TL
