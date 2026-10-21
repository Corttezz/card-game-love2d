local M = {}

M.VERSIONS = {
    { id = "antes", file = "tools/crt_variants/antigo.glsl" },
    { id = "G", file = "tools/crt_variants/G_forte_combinado.glsl" },
    { id = "final", file = "shaders/crt.glsl" },
}

M.SIZES = { { 1920, 1080 }, { 1366, 768 } }

local OUT = "crt_final"
local TIME = 12.345

local function sendAll(sh, W, H, strength, pw, pdir)
    local function s(n, v) if sh:hasUniform(n) then sh:send(n, v) end end
    s("time", TIME)
    s("resolution", { W, H })
    s("strength", strength or 0.75)
    s("power", pw or 1)
    s("powerDir", pdir or 1)
    s("glitch", 0)
    s("glitchY", 0.5)
    s("degrade", 0)
    s("calmRect", { 0, 0, 0, 0 })
    s("calmRect2", { 0, 0, 0, 0 })
    s("caScale", 1)
end

local function through(sh, scene, out, W, H, strength, pw, pdir)
    love.graphics.push("all")
    love.graphics.setCanvas(out)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setShader(sh)
    sendAll(sh, W, H, strength, pw, pdir)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(scene, 0, 0)
    love.graphics.setShader()
    love.graphics.pop()
end

local function classify(r, g, b)
    local l = 0.299 * r + 0.587 * g + 0.114 * b
    if l > 0.30 then return "img" end
    if l < 0.035 then return "black" end
    return "frame"
end

local function scan(data, x0, y0, dx, dy, maxN)
    local plastic, black = 0, 0
    local x, y = x0, y0
    for _ = 1, maxN do
        local c = classify(data:getPixel(x, y))
        if c == "img" then break end
        if c == "black" then black = black + 1 else plastic = plastic + 1 end
        x, y = x + dx, y + dy
    end
    return plastic + black, plastic, black
end

function M.frameWidths(sh, W, H, strength)
    local white = love.graphics.newCanvas(W, H)
    love.graphics.push("all")
    love.graphics.setCanvas(white)
    love.graphics.clear(1, 1, 1, 1)
    love.graphics.pop()
    local out = love.graphics.newCanvas(W, H)
    through(sh, white, out, W, H, strength)
    local d = out:newImageData()
    out:release()
    white:release()
    local r = {}
    r.left = { scan(d, 0, math.floor(H / 2), 1, 0, math.floor(W / 2)) }
    r.right = { scan(d, W - 1, math.floor(H / 2), -1, 0, math.floor(W / 2)) }
    r.top = { scan(d, math.floor(W / 2), 0, 0, 1, math.floor(H / 2)) }
    r.bottom = { scan(d, math.floor(W / 2), H - 1, 0, -1, math.floor(H / 2)) }
    r.diag = { scan(d, 0, 0, 1, 1, math.floor(H / 2)) }
    d:release()
    return r
end

local function crop(img, W, H, x, y, w, h, name)
    local c = love.graphics.newCanvas(w * 2, h * 2)
    local q = love.graphics.newQuad(x, y, w, h, W, H)
    love.graphics.push("all")
    love.graphics.setCanvas(c)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.draw(img, q, 0, 0, 0, 2, 2)
    love.graphics.pop()
    c:newImageData():encode("png", name)
    c:release()
    q:release()
end

function M.perf(sh, W, H, n)
    local src = love.graphics.newCanvas(W, H)
    local dst = love.graphics.newCanvas(W, H)
    love.graphics.push("all")
    love.graphics.setCanvas(src)
    love.graphics.clear(0.4, 0.3, 0.2, 1)
    love.graphics.pop()
    local function burst(useShader)
        local probe = dst:newImageData(1, 1, 0, 0, 1, 1)
        probe:release()
        local t0 = love.timer.getTime()
        for _ = 1, n do
            love.graphics.push("all")
            love.graphics.setCanvas(dst)
            if useShader then
                love.graphics.setShader(sh)
                sendAll(sh, W, H, 0.75)
            end
            love.graphics.draw(src, 0, 0)
            love.graphics.pop()
        end
        local p2 = dst:newImageData(1, 1, 0, 0, 1, 1)
        p2:release()
        return (love.timer.getTime() - t0) / n * 1000
    end
    burst(true)
    local base = math.huge
    local with = math.huge
    for _ = 1, 3 do
        base = math.min(base, burst(false))
        with = math.min(with, burst(true))
    end
    src:release()
    dst:release()
    return with - base, with, base
end

function M.run()
    local rw, rh, rd = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    local realMouse = love.mouse.getPosition
    love.mouse.getPosition = function() return 5, 5 end
    love.filesystem.createDirectory(OUT)
    local Shots = require("tools.screenshot_crt_variantes")
    local mode = (arg and arg[#arg]) or ""

    local ok, err = pcall(function()
        local shaders = {}
        for _, v in ipairs(M.VERSIONS) do
            shaders[v.id] = love.graphics.newShader(v.file)
        end
        for _, sz in ipairs(M.SIZES) do
            local W, H = sz[1], sz[2]
            love.graphics.getWidth = function() return W end
            love.graphics.getHeight = function() return H end
            love.graphics.getDimensions = function() return W, H end
            for _, v in ipairs(M.VERSIONS) do
                for _, st in ipairs({ 0.75, 0.35 }) do
                    local f = M.frameWidths(shaders[v.id], W, H, st)
                    print(("[moldura] %dx%d %-6s forca %.2f  esq %d (plastico %d, preto %d)  topo %d (%d, %d)  dir %d  base %d  diagonal %d"):format(
                        W, H, v.id, st, f.left[1], f.left[2], f.left[3], f.top[1], f.top[2], f.top[3],
                        f.right[1], f.bottom[1], f.diag[1]))
                end
            end
            if mode ~= "perf" then
                require("src.ui.FontManager").clearCache()
                local scene = Shots.buildScene(W, H)
                local out = love.graphics.newCanvas(W, H)
                for _, v in ipairs(M.VERSIONS) do
                    through(shaders[v.id], scene, out, W, H, 0.75)
                    local data = out:newImageData()
                    local base = ("%s/%dx%d_%s"):format(OUT, W, H, v.id)
                    data:encode("png", base .. ".png")
                    print("[crt_final] " .. base .. ".png")
                    local img = love.graphics.newImage(data)
                    img:setFilter("nearest", "nearest")
                    crop(img, W, H, 0, 0, math.floor(W / 4), math.floor(H / 4), base .. "_canto_sup_esq.png")
                    crop(img, W, H, W - math.floor(W / 4), H - math.floor(H / 4), math.floor(W / 4), math.floor(H / 4), base .. "_canto_inf_dir.png")
                    crop(img, W, H, math.floor(W * 3 / 8), math.floor(H * 3 / 8), math.floor(W / 4), math.floor(H / 4), base .. "_centro.png")
                    img:release()
                    data:release()
                    if v.id == "final" and W == 1920 then
                        for _, pk in ipairs({ { 0.5, -1, "desligando" }, { 0.2, -1, "ponto" }, { 0.45, 1, "ligando" }, { 0.7, 1, "rolando" } }) do
                            through(shaders[v.id], scene, out, W, H, 0.75, pk[1], pk[2])
                            local dp = out:newImageData()
                            dp:encode("png", base .. "_energia_" .. pk[3] .. ".png")
                            print("[crt_final] " .. base .. "_energia_" .. pk[3] .. ".png")
                            dp:release()
                        end
                    end
                    if v.id == "final" then
                        through(shaders[v.id], scene, out, W, H, 0.35)
                        local d2 = out:newImageData()
                        d2:encode("png", base .. "_low.png")
                        print("[crt_final] " .. base .. "_low.png")
                        d2:release()
                    end
                end
                out:release()
                scene:release()
            end
        end
        for _, sz in ipairs({ { 1920, 1080 }, { 2560, 1440 } }) do
            for _, v in ipairs(M.VERSIONS) do
                local cost, with, base = M.perf(shaders[v.id], sz[1], sz[2], 40)
                print(("[perf] %dx%d %-6s %.3f ms por quadro (com %.3f, sem %.3f)"):format(sz[1], sz[2], v.id, cost, with, base))
            end
        end
        for _, s in pairs(shaders) do s:release() end
    end)
    if not ok then print("[FAIL] crt_final: " .. tostring(err)) end
    love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = rw, rh, rd
    love.mouse.getPosition = realMouse
    require("src.ui.UiScale").force(1)
    return ok
end

return M
