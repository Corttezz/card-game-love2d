local M = {}

local function analyze(path)
    local ok, sd = pcall(love.sound.newSoundData, path)
    if not ok or not sd then return nil, tostring(sd) end

    local n        = sd:getSampleCount()
    local rate     = sd:getSampleRate()
    local channels = sd:getChannelCount()
    if n < 2 then return nil, "arquivo curto demais" end

    local function mono(s)
        local v = 0
        for c = 1, channels do v = v + sd:getSample(s, c) end
        return v / channels
    end

    local jump = math.abs(mono(n - 1) - mono(0))

    local W = math.min(math.floor(rate * 0.4), math.floor(n / 2))
    local function rmsRange(from)
        local acc = 0
        for s = from, from + W - 1 do
            local v = mono(s)
            acc = acc + v * v
        end
        return math.sqrt(acc / W)
    end
    local rmsHead = rmsRange(0)
    local rmsTail = rmsRange(n - W)

    local crossings, prev = 0, mono(0)
    for si = 1, n - 1 do
        local v = mono(si)
        if (v >= 0) ~= (prev >= 0) then crossings = crossings + 1 end
        prev = v
    end
    local brightness = (crossings / (n / rate)) / 2 / 1000

    local acc, cnt = 0, 0
    for s = 0, n - 1, 64 do acc = acc + mono(s); cnt = cnt + 1 end

    return {
        dur = n / rate,
        jump = jump,
        rmsHead = rmsHead, rmsTail = rmsTail,
        ratio = rmsHead > 0 and (rmsTail / rmsHead) or 0,
        dc = acc / cnt,
        brightness = brightness,
    }
end

function M.run(filter)
    local DIR = os.getenv("CHECK_LOOP_DIR") or "audio/music"
    if not love.filesystem.getInfo(DIR) then
        print("Sem " .. DIR .. "/ — nada a medir.")
        love.event.quit()
        return true
    end

    local files = {}
    for _, item in ipairs(love.filesystem.getDirectoryItems(DIR)) do
        if item:match("%.mp3$") then
            files[#files + 1] = { nome = item, caminho = DIR .. "/" .. item }
        end
    end
    table.sort(files, function(a, b) return a.nome < b.nome end)

    if love.filesystem.getInfo("audio/music.mp3") then
        table.insert(files, 1, { nome = "music.mp3 (menu)",
                                 caminho = "audio/music.mp3" })
    end

    print("")
    print("=== EMENDA DE LOOP ===")
    print(string.format("%-22s %6s %8s %9s %9s %7s %8s %8s",
        "arquivo", "dur", "salto", "rms ini", "rms fim", "razao", "dc", "brilho"))

    local shown, warned = 0, 0
    local bright = {}
    for _, entrada in ipairs(files) do
        local f = entrada.nome
        if (not filter) or f:find(filter, 1, true) then
            local r, err = analyze(entrada.caminho)
            if r then
                local flag = ""
                if r.jump > 0.05 then flag = flag .. " SALTO!" end
                if r.ratio < 0.5 or r.ratio > 2.0 then flag = flag .. " DESNIVEL!" end
                if math.abs(r.dc) > 0.01 then flag = flag .. " DC!" end
                if r.brightness < 0.15 then flag = flag .. " RETUMBO!" end
                if flag ~= "" then warned = warned + 1 end
                print(string.format("%-22s %5.2fs %8.4f %9.4f %9.4f %6.2fx %8.4f %6.2fk%s",
                    f, r.dur, r.jump, r.rmsHead, r.rmsTail, r.ratio, r.dc,
                    r.brightness, flag))
                bright[#bright + 1] = { f = f, b = r.brightness }
                shown = shown + 1
            else
                print(string.format("%-22s  FALHOU AO DECODIFICAR: %s", f, err))
            end
        end
    end

    table.sort(bright, function(a, b) return a.b < b.b end)
    local colisoes = 0
    for k = 2, #bright do
        local lo, hi = bright[k - 1], bright[k]
        if hi.b > 0 and (hi.b - lo.b) / hi.b < 0.20 then
            if colisoes == 0 then
                print("\nFaixas perto demais em brilho (vao soar parecidas):")
            end
            print(string.format("  %-20s e %-20s  (%.2fk vs %.2fk)",
                lo.f, hi.f, lo.b, hi.b))
            colisoes = colisoes + 1
        end
    end

    print(string.format("\n%d faixa(s), %d com aviso, %d colisao(oes) de brilho.",
        shown, warned, colisoes))
    love.event.quit()
    return (warned + colisoes) == 0
end

return M
