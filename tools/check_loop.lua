local M = {}

local function loopPointsByFile()
    local MD = require("src.systems.MusicDirector")
    local out = {}
    for code, file in pairs(MD.TRACKS) do
        if MD.LOOPS[code] then out[file] = MD.LOOPS[code] end
    end
    for id, code in pairs(MD.BOSS_TRACKS) do
        if MD.LOOPS[code] then out[MD.bossFile(id)] = MD.LOOPS[code] end
    end
    return out
end

local function analyze(path, lp)
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

    local first, last = 0, n - 1
    if lp then
        first = math.floor(lp.loopStart * rate + 0.5)
        last = math.floor(lp.loopEnd * rate + 0.5) - 1
        if last + 1 + math.floor(rate) > n then return nil, "arquivo acaba antes de loopEnd + 1 s" end
    end
    local jump = math.abs(mono(last) - mono(first))
    local stepLimit = nil
    if lp then
        jump = 0
        local atraso = math.floor(rate * 0.1)
        for o = 0, atraso - 1 do
            jump = math.max(jump, math.abs(mono(last + 1 + o) - mono(first + o)))
        end
        local diffs = {}
        local prev = mono(last - math.floor(rate * 0.4))
        for si = last - math.floor(rate * 0.4) + 1, last do
            local v = mono(si)
            diffs[#diffs + 1] = math.abs(v - prev)
            prev = v
        end
        table.sort(diffs)
        stepLimit = diffs[math.max(1, math.floor(#diffs * 0.99))]
    end

    local W = math.min(math.floor(rate * 0.4), math.floor(n / 2))
    local function rmsRange(from)
        local acc = 0
        for s = from, from + W - 1 do
            local v = mono(s)
            acc = acc + v * v
        end
        return math.sqrt(acc / W)
    end
    local rmsHead = rmsRange(first)
    local rmsTail = rmsRange(last + 1 - W)

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
        stepLimit = stepLimit,
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

    local loops = loopPointsByFile()
    local files = {}
    for _, item in ipairs(love.filesystem.getDirectoryItems(DIR)) do
        if item:match("%.mp3$") then
            files[#files + 1] = { nome = item, caminho = DIR .. "/" .. item, lp = loops[item] }
        end
    end
    local SUB = DIR .. "/boss"
    if love.filesystem.getInfo(SUB) then
        for _, id in ipairs(love.filesystem.getDirectoryItems(SUB)) do
            local pasta = SUB .. "/" .. id
            if love.filesystem.getInfo(pasta, "directory") then
                for _, item in ipairs(love.filesystem.getDirectoryItems(pasta)) do
                    if item:match("%.mp3$") then
                        files[#files + 1] = { nome = "boss/" .. id .. "/" .. item,
                                              caminho = pasta .. "/" .. item, grupo = "boss/" .. id }
                    end
                end
            end
        end
    end
    table.sort(files, function(a, b) return a.nome < b.nome end)

    if love.filesystem.getInfo("audio/music.mp3") then
        table.insert(files, 1, { nome = "music.mp3 (menu)",
                                 caminho = "audio/music.mp3" })
    end

    print("")
    print("=== EMENDA DE LOOP ===")
    print(string.format("%-28s %6s %8s %9s %9s %7s %8s %8s",
        "arquivo", "dur", "salto", "rms ini", "rms fim", "razao", "dc", "brilho"))

    local shown, warned = 0, 0
    local bright = {}
    local grupos = {}
    for _, entrada in ipairs(files) do
        local f = entrada.nome
        if (not filter) or f:find(filter, 1, true) then
            local r, err = analyze(entrada.caminho, entrada.lp)
            if r then
                local flag = ""
                if r.jump > math.max(0.05, r.stepLimit or 0) then flag = flag .. " SALTO!" end
                if r.ratio < 0.5 or r.ratio > 2.0 then flag = flag .. " DESNIVEL!" end
                if math.abs(r.dc) > 0.01 then flag = flag .. " DC!" end
                if r.brightness < 0.15 then flag = flag .. " RETUMBO!" end
                if flag ~= "" then warned = warned + 1 end
                print(string.format("%-28s %5.2fs %8.4f %9.4f %9.4f %6.2fx %8.4f %6.2fk%s",
                    f, r.dur, r.jump, r.rmsHead, r.rmsTail, r.ratio, r.dc,
                    r.brightness, flag))
                if entrada.lp then
                    print(string.format("  emenda no ponto de loop: %.3fs -> %.3fs (introducao %.2fs, loop %.2fs);"
                        .. " salto = pior degrau em 0,1 s de atraso, limite %.4f (passo normal p99 da faixa)",
                        entrada.lp.loopEnd, entrada.lp.loopStart, entrada.lp.loopStart,
                        entrada.lp.loopEnd - entrada.lp.loopStart, math.max(0.05, r.stepLimit or 0)))
                end
                if entrada.grupo then
                    grupos[entrada.grupo] = grupos[entrada.grupo] or { soma = 0, n = 0 }
                    grupos[entrada.grupo].soma = grupos[entrada.grupo].soma + r.brightness
                    grupos[entrada.grupo].n = grupos[entrada.grupo].n + 1
                else
                    bright[#bright + 1] = { f = f, b = r.brightness }
                end
                shown = shown + 1
            else
                print(string.format("%-28s  FALHOU AO DECODIFICAR: %s", f, err))
                warned = warned + 1
            end
        end
    end

    for g, v in pairs(grupos) do
        bright[#bright + 1] = { f = g .. " (media)", b = v.soma / v.n }
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
