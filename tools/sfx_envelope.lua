-- tools/sfx_envelope.lua
-- Desenha a CURVA do envelope de um sfx em ASCII, janela a janela.
--
-- Complementa o tools/check_sfx.lua: aquele dá os números-resumo (pico, t10),
-- este mostra a FORMA. A diferença importa quando o número-resumo engana —
-- caso real (Set/2026): `card-shelf-place` media "ataque em 0,41s" num arquivo
-- de 0,60s, e só a curva responde a pergunta que decide o uso: os 0,41s antes
-- do pico são SILÊNCIO (defeito de geração, o som chega atrasado) ou são som
-- de verdade subindo (envelope legítimo, é só antecipar o disparo)?
--
-- Isso é crítico pra som tocado em CASCATA: se o evento audível não coincide
-- com o evento visual, o jogador ouve a carta 2 quando vê a carta 5.
--
-- Uso:
--   love . sfx_envelope card-shelf-place
--   love . sfx_envelope shop-leave-whoosh 0.02   (janela de 20ms)

local M = {}

local BARS = 54

function M.run(name, winSec)
    if not name then
        print("uso: love . sfx_envelope <nome-sem-extensao> [janelaSegundos]")
        return false
    end
    winSec = tonumber(winSec) or 0.01

    local path = "audio/sfx/" .. name .. ".mp3"
    if not love.filesystem.getInfo(path) then
        print("nao encontrado: " .. path)
        return false
    end

    local ok, sd = pcall(love.sound.newSoundData, path)
    if not ok or not sd then
        print("falhou ao decodificar: " .. tostring(sd))
        return false
    end

    local n, rate, ch = sd:getSampleCount(), sd:getSampleRate(), sd:getChannelCount()
    local WIN = math.max(1, math.floor(rate * winSec))

    local env, peak = {}, 0
    local i = 0
    while i < n do
        local hi = 0
        for s = i, math.min(i + WIN - 1, n - 1) do
            for c = 1, ch do
                local a = math.abs(sd:getSample(s, c))
                if a > hi then hi = a end
            end
        end
        env[#env + 1] = hi
        if hi > peak then peak = hi end
        i = i + WIN
    end

    print("")
    print(string.format("=== %s  (%.2fs, pico %.3f, janela %.0fms) ===",
        path, n / rate, peak, winSec * 1000))

    -- Onset AUDÍVEL: primeira janela acima de 5% do pico. É esta — não o
    -- instante do pico — que define quando o jogador ouve o som começar.
    local onset
    for k, v in ipairs(env) do
        if v >= peak * 0.05 then onset = (k - 1) * winSec; break end
    end

    for k, v in ipairs(env) do
        local t = (k - 1) * winSec
        local rel = (peak > 0) and (v / peak) or 0
        local bar = string.rep("#", math.floor(rel * BARS + 0.5))
        print(string.format("%6.2fs |%-" .. BARS .. "s| %.3f", t, bar, v))
    end

    print(string.format("\nonset audivel (>=5%% do pico): %s",
        onset and string.format("%.2fs", onset) or "nao encontrado"))
    print("Se o onset for ~0.00s o som dispara junto com o evento visual.")
    print("Se for tardio, o arquivo tem lead-in: ou antecipa o disparo, ou corta.")
    return true
end

return M
