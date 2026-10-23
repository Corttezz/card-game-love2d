local TK = require("tools.testkit")
local M = {}

local ENEMY_DIR = "assets/sprites/characters/enemies/"

local function clipFiles(id, clip)
    local dir = ENEMY_DIR .. id .. "/animations/" .. clip .. "/south"
    local info = love.filesystem.getInfo(dir)
    if not info or info.type ~= "directory" then return nil end
    local out = {}
    for _, f in ipairs(love.filesystem.getDirectoryItems(dir)) do
        local n = tonumber(f:match("^(%d+)%.png$"))
        if n then out[#out + 1] = { n = n, path = dir .. "/" .. f } end
    end
    table.sort(out, function(a, b) return a.n < b.n end)
    return out
end

local function pixels(path)
    local ok, d = pcall(love.image.newImageData, path)
    if not ok then return nil end
    return d:getWidth() .. "x" .. d:getHeight() .. ":" .. d:getString()
end

local function checkData(t, EnemyLife)
    local Enemies = require("src.data.enemies")
    local files = love.filesystem.getDirectoryItems(EnemyLife.DIR)
    local n = 0
    for _, f in ipairs(files) do
        local id = f:match("^(.+)%.lua$")
        if id then
            n = n + 1
            local okL, chunk = pcall(love.filesystem.load, EnemyLife.DIR .. f)
            local okR, data = false, nil
            if okL and chunk then okR, data = pcall(chunk) end
            local valid, err = false, "nao carregou"
            if okR then valid, err = EnemyLife.validate(data, id) end
            t:truthy(id .. ": dados validos" .. (valid and "" or (" (" .. tostring(err) .. ")")), valid)
            t:truthy(id .. ": criatura do roster", Enemies.HOME_BIOME[id] ~= nil)
            if valid then
                local idle = clipFiles(id, "idle")
                local idle0 = idle and idle[1] and pixels(idle[1].path)
                t:truthy(id .. ": tem idle 0", idle0 ~= nil)
                local seen = {}
                for _, fd in ipairs(data.fidgets or {}) do
                    t:falsy(id .. ": fidget repetido " .. fd.clip, seen[fd.clip])
                    seen[fd.clip] = true
                    local fr = clipFiles(id, fd.clip)
                    t:truthy(id .. "/" .. fd.clip .. ": clip existe no disco", fr and #fr > 0)
                    if fr and #fr > 0 and idle0 then
                        t:truthy(string.format("%s/%s: 6 a 16 quadros (%d)", id, fd.clip, #fr), #fr >= 6 and #fr <= 16)
                        t:truthy(id .. "/" .. fd.clip .. ": quadro 0 = idle 0", pixels(fr[1].path) == idle0)
                        t:truthy(id .. "/" .. fd.clip .. ": ultimo quadro = idle 0", pixels(fr[#fr].path) == idle0)
                        local contiguous = true
                        for i, e in ipairs(fr) do if e.n ~= i - 1 then contiguous = false end end
                        t:truthy(id .. "/" .. fd.clip .. ": quadros 0..M-1 sem buraco", contiguous)
                    end
                end
            end
        end
    end
    t:truthy("ha dados de vida no repositorio (" .. n .. ")", n > 0)
    local Data = require("src.ui.EnemyLife")
    t:falsy("kind desconhecido rejeitado", Data.validate({ fx = { { kind = "fogo", xr = 0.5, yr = 0.5 } } }))
    t:falsy("xr fora de 0..1 rejeitado", Data.validate({ fx = { { kind = "smoke", xr = 1.5, yr = 0.5 } } }))
    t:falsy("clip sem prefixo fidget_ rejeitado", Data.validate({ fidgets = { { clip = "idle" } } }))
    t:falsy("gap invertido rejeitado", Data.validate({ gap = { 5, 2 } }))
end

local function checkScheduler(t, EnemyLife)
    local S = EnemyLife._S
    local seq, si = {}, 0
    for i = 1, 4096 do seq[i] = ((i * 7919) % 1000) / 1000 end
    local origRand = EnemyLife._rand
    EnemyLife._rand = function() si = si % #seq + 1 return seq[si] end
    local id = "__life_test__"
    EnemyLife._setData(id, {
        fidgets = { { clip = "fidget_a", fps = 10, weight = 3 }, { clip = "fidget_b", fps = 10, weight = 1 },
                    { clip = "fidget_c", fps = 12, weight = 1 } },
        gap = { 1.0, 2.0 },
    })
    EnemyLife.update(0, id, "idle", 1, true)
    S.warm.fidget_a, S.warm.fidget_b, S.warm.fidget_c = true, true, true

    local firedBusy = false
    for _ = 1, 600 do
        if EnemyLife.update(1 / 30, id, "idle", 1, true) then firedBusy = true end
    end
    t:falsy("ocupado (ataque/dano/intencao/cinematica): nunca comeca fidget", firedBusy)

    local firedMid = false
    for _ = 1, 600 do
        if EnemyLife.update(1 / 30, id, "idle", 3, false) then firedMid = true end
    end
    t:falsy("so comeca no quadro 0 do idle", firedMid)

    local firedOther = false
    for _ = 1, 300 do
        if EnemyLife.update(1 / 30, id, "attack", 1, false) then firedOther = true end
        if EnemyLife.update(1 / 30, id, "hurt", 1, false) then firedOther = true end
    end
    t:falsy("clip de ataque/dano tocando: sem fidget", firedOther)

    local picks, repeated, frame = {}, false, 0
    local badFrame, stacked = false, false
    local guard = 0
    while #picks < 60 and guard < 100000 do
        guard = guard + 1
        frame = frame % 8 + 1
        local clip = EnemyLife.update(1 / 30, id, "idle", frame, false)
        if clip then
            if frame ~= 1 then badFrame = true end
            if picks[#picks] == clip then repeated = true end
            picks[#picks + 1] = clip
            for _ = 1, 10 do
                if EnemyLife.update(1 / 30, id, clip, 2, false) then stacked = true end
            end
        end
    end
    t:eq("60 fidgets sorteados", #picks, 60)
    t:falsy("fidget so dispara no quadro 0", badFrame)
    t:falsy("fidget tocando nao empilha outro", stacked)
    t:falsy("nunca o mesmo fidget duas vezes seguidas", repeated)
    local counts = {}
    for _, c in ipairs(picks) do counts[c] = (counts[c] or 0) + 1 end
    t:truthy("peso 3 sai mais que peso 1", (counts.fidget_a or 0) > (counts.fidget_b or 0))

    local gs = _G.gameSettings
    _G.gameSettings = { reducedMotion = true }
    local firedReduced = false
    for i = 1, 900 do
        if EnemyLife.update(1 / 30, id, "idle", (i % 8) + 1, false) then firedReduced = true end
    end
    _G.gameSettings = gs
    t:falsy("reducedMotion: sem fidget", firedReduced)

    S.alive = false
    local firedDead = false
    for i = 1, 900 do
        if EnemyLife.update(1 / 30, id, "idle", (i % 8) + 1, false) then firedDead = true end
    end
    t:falsy("morto: sem fidget", firedDead)
    S.alive = true
    EnemyLife.update(0, id, "idle", 2, false)

    EnemyLife.force(3)
    local forced
    for _ = 1, 3 do forced = forced or EnemyLife.update(1 / 30, id, "idle", 1, false) end
    t:eq("galeria: forcar fidget N", forced, "fidget_c")

    EnemyLife._setData("__life_next__", { fx = { { kind = "smoke", xr = 0.5, yr = 0.5 } } })
    EnemyLife.prewarm("__life_next__")
    for _ = 1, 30 do EnemyLife.update(1 / 30, id, "idle", 1, true) end
    t:eq("viagem: o aquecimento do proximo inimigo sobrevive ao update do anterior", (EnemyLife.current()), "__life_next__")
    EnemyLife.update(1 / 30, id, "idle", 1, false)
    t:eq("fora da viagem o inimigo real assume", (EnemyLife.current()), id)
    EnemyLife._setData("__life_next__", nil)

    EnemyLife._rand = origRand
    EnemyLife._setData(id, nil)
end

local function allKindsData()
    local fx = {}
    for i, k in ipairs(require("src.ui.EnemyLife").KINDS) do
        fx[#fx + 1] = { kind = k, xr = 0.1 + 0.08 * i, yr = 0.2 + 0.05 * (i % 5), rate = 3 }
    end
    return { fx = fx }
end

local function checkFx(t, EnemyLife)
    local id = "__life_fx__"
    EnemyLife._setData(id, allKindsData())
    EnemyLife.update(0, id, "idle", 1, false)
    local canvas = love.graphics.newCanvas(400, 400)
    local seenKinds = {}
    local function frame(alive)
        EnemyLife.frame(100, 50, 2.5, 0, 0, 100, 100, alive, 1)
        EnemyLife.update(1 / 60, id, alive and "idle" or "death", 2, false)
        EnemyLife.drawBack()
        EnemyLife.drawFront()
        EnemyLife.drawFront(true)
    end
    love.graphics.setCanvas(canvas)
    for _ = 1, 240 do
        frame(true)
        for i = 1, EnemyLife.MAX do
            local k = EnemyLife._pk[i]
            if k ~= 0 then seenKinds[k] = true end
        end
    end
    t:truthy("os 10 tipos geram particulas (" .. EnemyLife.liveCount() .. ")", EnemyLife.liveCount() > 20)
    local nk = 0
    for _ in pairs(seenKinds) do nk = nk + 1 end
    t:eq("todos os tipos nascem", nk, #EnemyLife.KINDS)
    t:truthy("pool fixo nunca passa do teto", EnemyLife.liveCount() <= EnemyLife.MAX)

    local samples = {}
    for r = 1, 3 do
        collectgarbage("collect")
        collectgarbage("stop")
        local k0 = collectgarbage("count")
        for _ = 1, 60 do frame(true) end
        samples[r] = (collectgarbage("count") - k0) / 60
        collectgarbage("restart")
    end
    table.sort(samples)
    t:truthy(string.format("pool de fx sem alocacao por particula (%.3f KB/quadro com %d vivas, teto 1)", samples[2], EnemyLife.liveCount()), samples[2] < 1)

    do
        local t0 = love.timer.getTime()
        for _ = 1, 120 do frame(true) end
        local ms = (love.timer.getTime() - t0) * 1000 / 120
        t:truthy(string.format("custo de CPU do fx com %d vivas: %.3f ms/quadro (teto 0,5)", EnemyLife.liveCount(), ms), ms < 0.5)
    end
    for _ = 1, 3 do frame(false) end
    t:truthy("morte: nada nasce depois", true)
    for _ = 1, 33 do frame(false) end
    t:eq("morte: particulas somem em 0,5 s", EnemyLife.liveCount(), 0)

    local gs = _G.gameSettings
    _G.gameSettings = { reducedMotion = true }
    EnemyLife._setData(id, allKindsData())
    for _ = 1, 120 do frame(true) end
    t:eq("reducedMotion: sem fx", EnemyLife.liveCount(), 0)
    love.graphics.setCanvas()
    _G.gameSettings = gs
    EnemyLife._setData(id, nil)
end

local function writeFixture(id, clip, frames)
    local dir = ENEMY_DIR .. id .. "/animations/" .. clip .. "/south"
    love.filesystem.createDirectory(dir)
    local idle = clipFiles(id, "idle")
    local written = {}
    for i, src in ipairs(frames) do
        local d = love.image.newImageData(idle[src].path)
        local p = dir .. "/" .. (i - 1) .. ".png"
        d:encode("png", p)
        written[#written + 1] = p
    end
    return dir, written
end

local function removeFixture(id, clip, written)
    for _, p in ipairs(written) do love.filesystem.remove(p) end
    local base = ENEMY_DIR .. id .. "/animations/" .. clip
    love.filesystem.remove(base .. "/south")
    love.filesystem.remove(base)
end

local function checkRenderer(t, EnemyLife)
    local ER = require("src.ui.EnemyRenderer")
    local id = "cursed_scarecrow"
    local clip = "fidget_lifetest"
    local _, written = writeFixture(id, clip, { 1, 2, 3, 2, 1 })
    local okRun, err = pcall(function()
        ER.clearCache()
        require("src.ui.SpriteAnimation").clearCache()
        EnemyLife._setData(id, { fidgets = { { clip = clip, fps = 30, weight = 1 } }, gap = { 0.2, 0.3 } })
        local game = { enemy = { spriteId = id, health = 10, isBoss = false } }
        local canvas = love.graphics.newCanvas(800, 800)
        local function step(dt)
            ER.update(dt)
            love.graphics.setCanvas(canvas)
            ER.draw(game, 400, 700)
            love.graphics.setCanvas()
        end
        step(0)
        for _ = 1, 30 do step(0) end
        t:truthy("prewarm carrega o clip antes de tocar", EnemyLife.isWarm(clip))
        local sawFidget, startFrame, busyDuring = false, nil, false
        for _ = 1, 400 do
            step(1 / 60)
            local st = ER.debugState()
            if st.animName == clip then
                if not sawFidget then startFrame = ER._debugFrameCount() end
                sawFidget = true
                if ER.isBusy() then busyDuring = true end
                break
            end
        end
        t:truthy("fidget toca pelo mesmo caminho (SpriteAnimation)", sawFidget)
        t:eq("clip do fidget carregado inteiro", startFrame, 5)
        t:falsy("fidget nao conta como ocupado (nao segura o turno)", busyDuring)
        local back = false
        for _ = 1, 120 do
            step(1 / 60)
            if ER.debugState().animName == "idle" then back = true break end
        end
        t:truthy("fidget volta ao idle sozinho", back)
        t:eq("volta ao idle pulando o quadro 0 repetido", (ER.getLastFoot() or {}).frame, 2)
        local again = false
        for _ = 1, 600 do
            step(1 / 60)
            if ER.debugState().animName == clip then again = true break end
        end
        t:truthy("fidget acontece de novo depois do intervalo", again)
        ER.triggerHurt()
        local nm = ER.debugState().animName
        t:truthy("dano interrompe o fidget na hora (" .. tostring(nm) .. ")", nm ~= clip)
        for _ = 1, 600 do
            step(1 / 60)
            if ER.debugState().animName == clip then break end
        end
        ER.triggerAttack("attack", nil)
        t:truthy("ataque interrompe o fidget na hora", ER.debugState().animName ~= clip)
    end)
    removeFixture(id, clip, written)
    EnemyLife._setData(id, nil)
    ER.clearCache()
    t:truthy("integracao com o EnemyRenderer sem erro" .. (okRun and "" or (": " .. tostring(err))), okRun)
end

function M.run()
    local t = TK.new("monstros vivos parados (EnemyLife)")
    TK.bootstrap()
    local EnemyLife = require("src.ui.EnemyLife")
    local gs = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }
    checkData(t, EnemyLife)
    checkScheduler(t, EnemyLife)
    checkFx(t, EnemyLife)
    checkRenderer(t, EnemyLife)
    _G.gameSettings = gs
    EnemyLife.clearCache()
    return t:done()
end

return M
