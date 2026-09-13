-- tools/check_loop.lua
-- Mede se uma faixa fecha o LOOP sem emenda audível.
--
-- Existe porque música do jogo toca em `loop = true` para sempre: o defeito
-- não aparece na primeira passada, aparece na virada — e a virada acontece
-- 22s depois, quando ninguém está mais olhando. `check_sfx` mede o envelope
-- do arquivo inteiro e não diz nada sobre o ponto onde o fim encosta no
-- começo. Este diz.
--
-- Uso:
--   love . check_loop            -- todos os audio/music/*.mp3
--   love . check_loop act        -- filtra por substring
--
-- Mede três coisas, nesta ordem de importância:
--
--   SALTO   diferença de amplitude entre a ÚLTIMA amostra e a PRIMEIRA.
--           É o clique. Acima de ~0.05 se ouve como "tec" a cada volta.
--
--   RMS ini / RMS fim   energia dos 400ms de cada ponta. Se o fim está muito
--           mais quieto que o começo (fade-out que o modelo colou sozinho),
--           a volta soa como alguém religando o som. Razão saudável fica
--           entre 0,5x e 2x.
--
--   DC      offset médio. Sinal com DC longe de zero dá estalo garantido na
--           emenda mesmo com salto pequeno.

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

    -- Salto na emenda: última amostra encostando na primeira.
    local jump = math.abs(mono(n - 1) - mono(0))

    -- RMS das duas pontas (400ms cada).
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

    -- DC offset do arquivo inteiro (amostrado de 64 em 64 — basta).
    local acc, cnt = 0, 0
    for s = 0, n - 1, 64 do acc = acc + mono(s); cnt = cnt + 1 end

    return {
        dur = n / rate,
        jump = jump,
        rmsHead = rmsHead, rmsTail = rmsTail,
        ratio = rmsHead > 0 and (rmsTail / rmsHead) or 0,
        dc = acc / cnt,
    }
end

function M.run(filter)
    local DIR = "audio/music"
    if not love.filesystem.getInfo(DIR) then
        print("Sem " .. DIR .. "/ — nada a medir.")
        love.event.quit()
        return true
    end

    local files = {}
    for _, item in ipairs(love.filesystem.getDirectoryItems(DIR)) do
        if item:match("%.mp3$") then files[#files + 1] = item end
    end
    table.sort(files)

    print("")
    print("=== EMENDA DE LOOP ===")
    print(string.format("%-22s %6s %8s %9s %9s %7s %8s",
        "arquivo", "dur", "salto", "rms ini", "rms fim", "razao", "dc"))

    local shown, warned = 0, 0
    for _, f in ipairs(files) do
        if (not filter) or f:find(filter, 1, true) then
            local r, err = analyze(DIR .. "/" .. f)
            if r then
                local flag = ""
                if r.jump > 0.05 then flag = flag .. " SALTO!" end
                if r.ratio < 0.5 or r.ratio > 2.0 then flag = flag .. " DESNIVEL!" end
                if math.abs(r.dc) > 0.01 then flag = flag .. " DC!" end
                if flag ~= "" then warned = warned + 1 end
                print(string.format("%-22s %5.2fs %8.4f %9.4f %9.4f %6.2fx %8.4f%s",
                    f, r.dur, r.jump, r.rmsHead, r.rmsTail, r.ratio, r.dc, flag))
                shown = shown + 1
            else
                print(string.format("%-22s  FALHOU AO DECODIFICAR: %s", f, err))
            end
        end
    end

    print(string.format("\n%d faixa(s), %d com aviso.", shown, warned))
    print("salto <= 0.05 = emenda inaudivel. razao entre 0,5x e 2,0x = sem fade nas pontas.")
    love.event.quit()
    return warned == 0
end

return M
