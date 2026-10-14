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
    return true
end

return M
