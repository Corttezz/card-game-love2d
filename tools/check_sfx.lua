-- tools/check_sfx.lua
-- Mede o ENVELOPE de um SFX: duração, pico, e em quanto tempo a energia cai.
-- Existe porque validar som gerado por IA olhando só o header do MP3 não diz
-- nada sobre o que importa no design. Caso concreto (Set/2026): `forgeStrike`
-- é tocado TRÊS vezes com ~0.28s de espaçamento — se a cauda for longa, as
-- três se somam e viram lama. O header não revela isso; o envelope revela.
--
-- Uso:
--   love . check_sfx                      -- todos os audio/sfx/*.mp3
--   love . check_sfx forge                -- só os que casam com "forge"
--
-- Lê: pico absoluto, RMS, e o tempo até a energia cair a 50%/10%/1% do pico
-- (decay times). Para percussivo seco, t10 curto é o que se quer.
--
-- ATENÇÃO — `ataque` NÃO é o início do som. É o instante do PICO.
-- Um `ataque` de 0,10s pode ser (a) 100ms de silêncio antes do evento, ou
-- (b) um envelope legítimo que sobe até o pico. A coluna não distingue, e
-- essa ambiguidade quase fez descartar um arquivo bom (`event-choice-seal`,
-- Set/2026: ataque 0,10s, mas onset audível em 0,01s — o carimbo dispara
-- junto com o clique e só atinge o pico 90ms depois).
--
-- Quem responde "o som começa QUANDO?" é `tools/sfx_envelope.lua`, que
-- desenha a curva janela a janela e imprime o onset audível:
--     love . sfx_envelope <substring>
-- Regra prática: este tool diz QUANTO; o sfx_envelope diz ONDE. Som que
-- responde a clique precisa de ONSET ~0; ambiente pode ter swell à vontade.

local M = {}

local function analyze(path)
    local ok, sd = pcall(love.sound.newSoundData, path)
    if not ok or not sd then return nil, tostring(sd) end

    local n        = sd:getSampleCount()
    local rate     = sd:getSampleRate()
    local channels = sd:getChannelCount()
    local dur      = n / rate

    -- Envelope por janelas de 10ms (pico absoluto dentro da janela).
    local WIN = math.max(1, math.floor(rate * 0.01))
    local env, peak = {}, 0
    local sumSq, total = 0, 0
    local i = 0
    while i < n do
        local hi = 0
        local last = math.min(i + WIN - 1, n - 1)
        for s = i, last do
            local v = 0
            for c = 1, channels do
                local a = math.abs(sd:getSample(s, c))
                if a > v then v = a end
            end
            if v > hi then hi = v end
            sumSq = sumSq + v * v
            total = total + 1
        end
        env[#env + 1] = hi
        if hi > peak then peak = hi end
        i = i + WIN
    end

    local rms = total > 0 and math.sqrt(sumSq / total) or 0

    -- Índice do pico e quanto tempo leva pra cair abaixo de cada limiar
    -- DEPOIS do pico (é o decay que interessa, não o ataque).
    local peakIdx = 1
    for k, v in ipairs(env) do if v >= peak then peakIdx = k; break end end

    local function decayTo(frac)
        local target = peak * frac
        for k = peakIdx, #env do
            if env[k] <= target then return (k - peakIdx) * 0.01 end
        end
        return nil   -- nunca cai até esse nível dentro do arquivo
    end

    return {
        dur = dur, rate = rate, channels = channels,
        peak = peak, rms = rms,
        attackAt = (peakIdx - 1) * 0.01,
        t50 = decayTo(0.50), t10 = decayTo(0.10), t01 = decayTo(0.01),
    }
end

function M.run(filter)
    -- Varre audio/sfx E as subpastas (joker-sig/ mora lá). Sem isso os sons
    -- assinatura de coringa ficavam invisíveis pro checador — e foi justamente
    -- um deles (warrior_standard_bearer) que o dono apontou como alto demais.
    local files = {}
    local function collect(dir, prefix)
        for _, item in ipairs(love.filesystem.getDirectoryItems(dir)) do
            local full = dir .. "/" .. item
            local info = love.filesystem.getInfo(full)
            if info and info.type == "directory" then
                collect(full, prefix .. item .. "/")
            elseif item:match("%.mp3$") then
                files[#files + 1] = prefix .. item
            end
        end
    end
    collect("audio/sfx", "")
    table.sort(files)

    print("")
    print("=== ENVELOPE DOS SFX ===")
    print(string.format("%-34s %6s %6s %6s %7s %7s %7s %7s",
        "arquivo", "dur", "pico", "rms", "ataque", "t50", "t10", "t01"))

    local shown = 0
    for _, f in ipairs(files) do
        if (not filter) or f:find(filter, 1, true) then
            local r, err = analyze("audio/sfx/" .. f)
            if r then
                local function fmt(v) return v and string.format("%6.2fs", v) or "     —" end
                print(string.format("%-34s %5.2fs %6.3f %6.3f %7s %7s %7s %7s",
                    f, r.dur, r.peak, r.rms, fmt(r.attackAt), fmt(r.t50),
                    fmt(r.t10), fmt(r.t01)))
                shown = shown + 1
            else
                print(string.format("%-34s  FALHOU AO DECODIFICAR: %s", f, err))
            end
        end
    end

    print(string.format("\n%d arquivo(s). t10 = tempo até cair a 10%% do pico.", shown))
    print("Percussivo seco quer t10 BAIXO; sustentado/ambiente quer alto.")
    return true
end

return M
