-- tools/check_loop.lua
-- Mede se as faixas de música fecham o LOOP sem emenda audível, e se são
-- distinguíveis umas das outras.
--
-- Existe porque música do jogo toca em `loop = true` para sempre: o defeito
-- não aparece na primeira passada, aparece na virada — e a virada acontece
-- 20s depois, quando ninguém está mais olhando. `check_sfx` mede o envelope
-- do arquivo inteiro e não diz nada sobre o ponto onde o fim encosta no
-- começo. Este diz.
--
-- Uso:
--   love . check_loop            -- todos os audio/music/*.mp3
--   love . check_loop act        -- filtra por substring
--
-- Mede quatro coisas:
--
--   SALTO   diferença de amplitude entre a ÚLTIMA amostra e a PRIMEIRA.
--           É o clique. Acima de ~0.05 se ouve como "tec" a cada volta.
--
--   RMS ini / RMS fim   energia dos 400ms de cada ponta. Se o fim está muito
--           mais quieto que o começo (fade-out que o modelo colou sozinho),
--           a volta soa como alguém religando o som. Razão saudável fica
--           entre 0,5x e 2,0x.
--
--   DC      offset médio. Sinal com DC longe de zero dá estalo garantido na
--           emenda mesmo com salto pequeno.
--
--   BRILHO  taxa de cruzamentos por zero, em kHz. É um proxy barato (O(n),
--           sem FFT) do centroide espectral: grave cruza o zero poucas vezes,
--           agudo cruza muito. Responde, SEM OUVIR, a pergunta "essas faixas
--           são distinguíveis umas das outras?".
--
-- POR QUE A COLUNA BRILHO EXISTE (Set/2026). A primeira leva da trilha tinha
-- os três atos e o boss com centroide espectral de 107, 173, 139 e 154 Hz —
-- quatro retumbos graves quase idênticos, com ~85% da energia abaixo de
-- 200 Hz. Cada arquivo, isolado, passava em tudo: envelope bom, loop fechado,
-- loudness certa. O dono ouviu e disse "cada ato tem que ser uma música
-- diferente". Nenhuma métrica de arquivo único pega isso, porque **o defeito
-- não existe num arquivo: existe entre dois**. Depois de reescrever os prompts
-- descrevendo ARRANJO (instrumento, andamento, modo) em vez de CLIMA, os
-- mesmos quatro foram para 1005, 2393, 541 e 1137 Hz.
--
-- Daí as duas regras que este tool aplica:
--   - brilho < 0,15k = retumbo, não música;
--   - duas faixas a menos de 20% de distância em brilho vão soar como a mesma
--     coisa, por mais diferente que o prompt tenha sido.

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

    -- Brilho por cruzamentos de zero. Um seno de f Hz cruza 2f vezes por
    -- segundo, entao zcr/2 aproxima a frequencia dominante.
    local crossings, prev = 0, mono(0)
    for si = 1, n - 1 do
        local v = mono(si)
        if (v >= 0) ~= (prev >= 0) then crossings = crossings + 1 end
        prev = v
    end
    local brightness = (crossings / (n / rate)) / 2 / 1000

    -- DC offset do arquivo inteiro (amostrado de 64 em 64 — basta).
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
    print(string.format("%-22s %6s %8s %9s %9s %7s %8s %8s",
        "arquivo", "dur", "salto", "rms ini", "rms fim", "razao", "dc", "brilho"))

    local shown, warned = 0, 0
    local bright = {}
    for _, f in ipairs(files) do
        if (not filter) or f:find(filter, 1, true) then
            local r, err = analyze(DIR .. "/" .. f)
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

    -- O defeito que motivou a coluna BRILHO nao existe num arquivo isolado:
    -- existe entre dois. Por isso a comparacao roda aqui, sobre o conjunto.
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
    print("salto <= 0.05 = emenda inaudivel. razao entre 0,5x e 2,0x = sem fade nas pontas.")
    print("brilho < 0,15k = retumbo, nao musica. Faixas a menos de 20% entre si soam iguais.")
    love.event.quit()
    return (warned + colisoes) == 0
end

return M
