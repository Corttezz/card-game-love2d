local M = {}

local function analyze(path)
    local ok, sd = pcall(love.sound.newSoundData, path)
    if not ok or not sd then return nil, tostring(sd) end

    local n        = sd:getSampleCount()
    local rate     = sd:getSampleRate()
    local channels = sd:getChannelCount()
    local dur      = n / rate

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

    local peakIdx = 1
    for k, v in ipairs(env) do if v >= peak then peakIdx = k; break end end

    local function decayTo(frac)
        local target = peak * frac
        for k = peakIdx, #env do
            if env[k] <= target then return (k - peakIdx) * 0.01 end
        end
        return nil
    end

    return {
        dur = dur, rate = rate, channels = channels,
        peak = peak, rms = rms,
        attackAt = (peakIdx - 1) * 0.01,
        t50 = decayTo(0.50), t10 = decayTo(0.10), t01 = decayTo(0.01),
    }
end

function M.run(filter)
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
    return true
end

return M
