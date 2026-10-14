local M = {}

local logf
local function out(fmt, ...)
    local line = select("#", ...) > 0 and fmt:format(...) or fmt
    io.stdout:write(line, "\n")
    if logf then logf:write(line, "\n"); logf:flush() end
end

function M.census(minSize)
    minSize = minSize or 200
    local seen = setmetatable({}, { __mode = "k" })
    local paths, total, udTypes = {}, 0, {}
    local queue, qh, qt = {}, 1, 0
    local function push(v, path)
        local tv = type(v)
        if tv ~= "table" and tv ~= "function" and tv ~= "userdata" and tv ~= "thread" then return end
        if seen[v] then return end
        seen[v] = true
        qt = qt + 1
        queue[qt] = { v, path }
    end
    seen[seen] = true; seen[queue] = true; seen[paths] = true
    push(package.loaded, "loaded")
    push(_G, "_G")
    push(debug.getregistry(), "REG")
    while qh <= qt do
        local item = queue[qh]; queue[qh] = nil; qh = qh + 1
        local v, path = item[1], item[2]
        total = total + 1
        local tv = type(v)
        if tv == "table" then
            local n = 0
            local mt = getmetatable(v)
            local weakK, weakV = false, false
            if type(mt) == "table" and type(rawget(mt, "__mode")) == "string" then
                weakK = mt.__mode:find("k") ~= nil
                weakV = mt.__mode:find("v") ~= nil
            end
            for k, x in next, v do
                n = n + 1
                local ks = type(k) == "string" and k or ("[" .. type(k) .. "]")
                if not weakK then push(k, path .. ".<k>") end
                if not weakV then push(x, path .. "." .. ks) end
            end
            if n >= minSize then paths[path] = n end
            if mt then push(mt, path .. ".<mt>") end
        elseif tv == "function" then
            local i = 1
            while true do
                local name, up = debug.getupvalue(v, i)
                if not name then break end
                push(up, path .. "^" .. name)
                i = i + 1
            end
        elseif tv == "userdata" then
            local ok, t = pcall(function() return v:type() end)
            local key = ok and t or "userdata"
            udTypes[key] = (udTypes[key] or 0) + 1
            local mt = getmetatable(v)
            if mt then push(mt, path .. ".<mt>") end
        end
    end
    return { total = total, paths = paths, ud = udTypes }
end

local wsMB
do
    local okF, ffi = pcall(require, "ffi")
    if okF and ffi.os == "Windows" then
        pcall(ffi.cdef, [[
            typedef struct { uint32_t cb; uint32_t PageFaultCount; size_t PeakWorkingSetSize;
                size_t WorkingSetSize; size_t QuotaPeakPagedPoolUsage; size_t QuotaPagedPoolUsage;
                size_t QuotaPeakNonPagedPoolUsage; size_t QuotaNonPagedPoolUsage;
                size_t PagefileUsage; size_t PeakPagefileUsage; } LP_PMC;
            void* GetCurrentProcess(void);
            int K32GetProcessMemoryInfo(void* p, LP_PMC* c, uint32_t cb);
        ]])
        wsMB = function()
            local c = ffi.new("LP_PMC")
            c.cb = ffi.sizeof(c)
            if ffi.C.K32GetProcessMemoryInfo(ffi.C.GetCurrentProcess(), c, c.cb) == 0 then return 0, 0 end
            return tonumber(c.WorkingSetSize) / 1048576, tonumber(c.PagefileUsage) / 1048576
        end
    end
end
M.wsMB = wsMB

local function diffCensus(a, b, top)
    local rows = {}
    for p, n in pairs(b.paths) do
        local d = n - (a.paths[p] or 0)
        if d > 0 then rows[#rows + 1] = { p = p, n = n, d = d } end
    end
    table.sort(rows, function(x, y) return x.d > y.d end)
    for i = 1, math.min(top or 25, #rows) do
        out("    +%-7d (%7d) %s", rows[i].d, rows[i].n, rows[i].p)
    end
    local uds = {}
    for t, n in pairs(b.ud) do
        local d = n - (a.ud[t] or 0)
        if d ~= 0 then uds[#uds + 1] = ("%s %+d (=%d)"):format(t, d, n) end
    end
    table.sort(uds)
    if #uds > 0 then out("    userdata: %s", table.concat(uds, ", ")) end
end

function M.snapshot()
    collectgarbage("collect"); collectgarbage("collect")
    local st = love.graphics and love.graphics.getStats and love.graphics.getStats() or {}
    local EM = _G.EventManager
    return {
        heapKB = collectgarbage("count"),
        texMB = (st.texturememory or 0) / 1048576,
        canvases = st.canvases or 0, images = st.images or 0, fonts = st.fonts or 0,
        em = EM and EM.pendingCount and EM.pendingCount() or 0,
    }
end

local function tagEventSites()
    local EM = _G.EventManager
    local orig = EM.add
    EM.add = function(ev, q)
        for lvl = 2, 8 do
            local info = debug.getinfo(lvl, "Sl")
            if not info then break end
            if not info.short_src:find("engine[/\\]Event") then
                ev._site = info.short_src .. ":" .. tostring(info.currentline)
                break
            end
        end
        return orig(ev, q)
    end
end

local function dumpQueues()
    local EM = _G.EventManager
    for name, q in pairs(EM.queues) do
        if #q > 0 then
            local sites = {}
            for _, ev in ipairs(q) do
                local k = (ev._site or "?") .. " [" .. tostring(ev.trigger) .. (ev.blocking and ",B" or "") .. "]"
                sites[k] = (sites[k] or 0) + 1
            end
            local rows = {}
            for k, n in pairs(sites) do rows[#rows + 1] = { k = k, n = n } end
            table.sort(rows, function(a, b) return a.n > b.n end)
            out("  fila %s: %d eventos", name, #q)
            for i = 1, math.min(8, #rows) do out("    %5d  %s", rows[i].n, rows[i].k) end
        end
    end
end

function M.run(runsArg, classArg, seedArg, policyArg)
    local runs = tonumber(runsArg or "6") or 6
    local cls = classArg or "mage"
    local seed = tonumber(seedArg or "500000") or 500000
    logf = io.open(love.filesystem.getSaveDirectory() .. "/leak_probe.log", "w")
    pcall(function() io.stdout:setvbuf("line") end)

    local Autoplay = require("tools.balance_sim").setup(policyArg or "v6")
    tagEventSites()
    local created = {}
    M.created = created
    for _, fname in ipairs({ "newCanvas", "newImage", "newText", "newMesh", "newSpriteBatch",
            "newParticleSystem", "newQuad" }) do
        local orig = love.graphics[fname]
        love.graphics[fname] = function(...)
            local info = debug.getinfo(2, "Sl")
            local k = fname .. " " .. (info and (info.short_src .. ":" .. info.currentline) or "?")
            created[k] = (created[k] or 0) + 1
            return orig(...)
        end
    end
    do
        local orig = love.image.newImageData
        love.image.newImageData = function(...)
            local info = debug.getinfo(2, "Sl")
            local k = "newImageData " .. (info and (info.short_src .. ":" .. info.currentline) or "?")
            created[k] = (created[k] or 0) + 1
            return orig(...)
        end
    end
    if os.getenv("LEAK_MIDRUN") then
        local EM, n, upd = _G.EventManager, 0, _G.EventManager.update
        local peak = 0
        EM.update = function(dt)
            n = n + 1
            local h = collectgarbage("count")
            if h > peak + 20480 then
                peak = h
                out("    PICO heap %.0f MB em: %s", h / 1024, debug.traceback("", 2):sub(1, 1500))
            end
            if n % 20000 == 0 then
                local st = love.graphics.getStats()
                local ws, priv = 0, 0
                if wsMB then ws, priv = wsMB() end
                out("    mid: heap %.0f KB | tex %.1f MB canv %d img %d | WS %.0f MB priv %.0f MB",
                    collectgarbage("count"), st.texturememory / 1048576, st.canvases, st.images, ws, priv)
            end
            return upd(dt)
        end
    end
    local realPrint = print
    local censusEvery = tonumber(os.getenv("LEAK_CENSUS") or "1") or 1
    local prevC
    local s0 = M.snapshot()
    out("[leak_probe] base: heap %.0f KB, tex %.1f MB, canvases %d, images %d",
        s0.heapKB, s0.texMB, s0.canvases, s0.images)
    if censusEvery > 0 then prevC = M.census() end
    local t0 = os.clock()
    for i = 1, runs do
        print = function() end
        local ok, rec = pcall(Autoplay.playRunRecord, cls, i, seed + i)
        print = realPrint
        local s = M.snapshot()
        out("[leak_probe] run %d %s: %s floors %s | heap %.0f KB | tex %.1f MB canv %d img %d font %d | EM %d | t=%.0fs",
            i, cls, ok and tostring(rec.outcome) or ("CRASH " .. tostring(rec)),
            ok and tostring(rec.floors) or "-", s.heapKB, s.texMB, s.canvases, s.images, s.fonts,
            s.em, os.clock() - t0)
        dumpQueues()
        local rows = {}
        for k, c in pairs(created) do rows[#rows + 1] = { k = k, c = c } end
        table.sort(rows, function(a, b) return a.c > b.c end)
        for j = 1, math.min(10, #rows) do out("    criados %6d  %s", rows[j].c, rows[j].k) end
        for k in pairs(created) do created[k] = nil end
        if censusEvery > 0 and i % censusEvery == 0 then
            local c = M.census()
            out("  census: %d objetos (%+d)", c.total, c.total - prevC.total)
            diffCensus(prevC, c, 25)
            prevC = c
        end
    end
    if logf then logf:close() end
    love.event.quit()
end

return M
