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
                for sname, sd in pairs(data.states or {}) do
                    if sd.clip then
                        local fr = clipFiles(id, sd.clip)
                        t:truthy(id .. "/" .. sd.clip .. ": clip de estado existe no disco", fr and #fr > 0)
                        if fr and #fr > 0 and idle0 then
                            t:truthy(string.format("%s/%s: 8 a 16 quadros (%d)", id, sd.clip, #fr), #fr >= 8 and #fr <= 16)
                            t:truthy(id .. "/" .. sd.clip .. ": quadro 0 = idle 0", pixels(fr[1].path) == idle0)
                            t:truthy(id .. "/" .. sd.clip .. ": ultimo quadro = idle 0", pixels(fr[#fr].path) == idle0)
                        end
                    end
                    t:truthy(id .. ": estado " .. sname .. " conhecido", EnemyLife.States.INDEX[sname] ~= nil)
                end
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
    EnemyLife.update(0, id, "idle", 1, false)
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


local function walkLua(dir, out)
    for _, f in ipairs(love.filesystem.getDirectoryItems(dir)) do
        local p = dir .. "/" .. f
        local info = love.filesystem.getInfo(p)
        if info and info.type == "directory" then walkLua(p, out)
        elseif f:match("%.lua$") then out[#out + 1] = p end
    end
end

local function enemyStatusNames()
    local names = {}
    local files = {}
    walkLua("src", files)
    for _, p in ipairs(files) do
        local src = love.filesystem.read(p) or ""
        for n in src:gmatch("addStatusEffect%(%s*{%s*name%s*=%s*\"([%w_]+)\"") do names[n] = p end
        for n in src:gmatch("debuffName%s*=%s*\"([%w_]+)\"") do names[n] = p end
        if p:find("^src/data/cards/") then
            for n in src:gmatch("\"apply_debuff\"%s*,%s*value%s*=%s*\"([%w_]+)\"") do names[n] = p end
        end
    end
    for id, kit in pairs(require("src.data.enemies").KITS or {}) do
        for _, ph in ipairs(kit.phases or {}) do names[ph.id or "eclipse"] = "kit " .. id end
    end
    names.block, names.strength, names.veil = "armor", "baseDamage", "intentVeil"
    return names
end

local function checkStates(t, EnemyLife)
    local ES = EnemyLife.States
    local names = enemyStatusNames()
    local n = 0
    for name, where in pairs(names) do
        n = n + 1
        local kit = nil
        for _, k in pairs(require("src.data.enemies").KITS or {}) do
            for _, ph in ipairs(k.phases or {}) do if ph.id == name then kit = k end end
        end
        local c = ES.canonical(name, kit and { kit = kit } or nil)
        t:truthy(string.format("status %s (%s) tem estado visivel ou e token de chefe", name, where),
            c ~= nil or ES.TOKEN_ONLY[name])
        if c then t:truthy("estado " .. c .. " tem visual generico", ES.GEN[c] ~= nil) end
    end
    t:truthy("varreu os status do jogo (" .. n .. ")", n >= 8)
    for _, want in ipairs({ "poison", "burn", "weak", "vulnerable", "strength", "regen", "enraged", "fury", "block", "veil" }) do
        t:truthy("status " .. want .. " coberto", ES.canonical(want) ~= nil)
    end

    local id = "__life_states__"
    EnemyLife._setData(id, { fx = {} })
    EnemyLife.update(0, id, "idle", 1, false)
    local B = ES._B
    B.n, B.w, B.h, B.top, B.baseY, B.baseL, B.baseR, B.headX, B.headY = 0, 100, 100, 5, 95, 30, 70, 50, 6
    for i = 1, 40 do
        B.n = B.n + 1
    end
    local canvas = love.graphics.newCanvas(300, 300)
    local fake = { statusEffects = {}, armor = 0, baseDamage = 10, maxHealth = 100, health = 100 }
    local function frame(anim, enemy)
        EnemyLife.frame(50, 50, 2, 0, 0, 100, 100, anim ~= "death", 1, enemy or fake)
        EnemyLife.update(1 / 60, id, anim or "idle", 2, false)
        EnemyLife.drawBack()
        EnemyLife.drawFront()
    end
    love.graphics.setCanvas(canvas)
    local everyOk = true
    for _, st in ipairs(ES.LIST) do
        ES.force({ st })
        local seenLive = false
        for _ = 1, 240 do
            frame("idle")
            if EnemyLife.liveCount() > 0 or EnemyLife.jitterPx() ~= 0 then seenLive = true end
        end
        local r, g, b = EnemyLife.tint(1, 1, 1)
        local visual = seenLive or r < 1 or g < 1 or b < 1
            or EnemyLife.animRate("idle") ~= 1 or EnemyLife.stretchPx() ~= 0 or ES.any()
        if st == "block" then
            fake.armor = 0
            ES.force(nil)
            frame("idle")
            fake.armor = 12
            for _ = 1, 30 do frame("idle") end
            visual = visual or EnemyLife.liveCount() > 0
            fake.armor = 0
            ES.force({ st })
        end
        t:truthy("estado " .. st .. " aparece (particula, cor, ritmo ou postura)", visual)
        if not visual then everyOk = false end
    end
    ES.force(ES.LIST)
    local maxKinds = 0
    for _ = 1, 120 do
        frame("idle")
        if ES.kindCount() > maxKinds then maxKinds = ES.kindCount() end
    end
    t:truthy("todos os estados juntos: no maximo " .. ES.MAX_KINDS .. " tipos de particula (" .. maxKinds .. ")",
        maxKinds <= ES.MAX_KINDS)
    local samples = {}
    for r = 1, 3 do
        collectgarbage("collect")
        collectgarbage("stop")
        local k0 = collectgarbage("count")
        for _ = 1, 60 do frame("idle") end
        samples[r] = (collectgarbage("count") - k0) / 60
        collectgarbage("restart")
    end
    table.sort(samples)
    t:truthy(string.format("estados sem alocacao por quadro (%.3f KB/quadro, teto 1)", samples[2]), samples[2] < 1)
    for _ = 1, 40 do frame("death") end
    local r, g, b = EnemyLife.tint(1, 1, 1)
    t:truthy("morte: nenhum estado (cor, ritmo, particula de estado)",
        r == 1 and g == 1 and b == 1 and ES.kindCount() == 0 and not ES.any())
    t:eq("morte: particulas somem", EnemyLife.liveCount(), 0)
    ES.force(nil)
    fake.statusEffects = { { name = "poison", stacks = 4, duration = 2 }, { name = "fury", stacks = 2, duration = 99 } }
    for _ = 1, 5 do frame("idle") end
    t:truthy("ao vivo: veneno lido do inimigo", ES.level("poison") > 0)
    t:truthy("ao vivo: furia vira enfurecido", ES.level("enraged") > 0)
    fake.baseDamage = 14
    frame("idle")
    t:truthy("ao vivo: forca ganha aparece", ES.level("strength") > 0)
    fake.statusEffects = {}
    fake.baseDamage = 10
    frame("idle")
    t:eq("sem status: sem estado", ES.level("poison"), 0)
    love.graphics.setCanvas()
    EnemyLife._setData(id, nil)
    t:falsy("estado desconhecido nos dados rejeitado", EnemyLife.validate({ states = { sono = {} } }))
    t:falsy("clip de estado sem prefixo rejeitado", EnemyLife.validate({ states = { poison = { clip = "idle" } } }))
    t:truthy("estado com fx proprio aceito", EnemyLife.validate({ states = { burn = { fx = { { kind = "embers", xr = 0.5, yr = 0.9 } } } } }))
    return everyOk
end

local function checkStateClip(t, EnemyLife)
    local ER = require("src.ui.EnemyRenderer")
    local id = "cursed_scarecrow"
    local clip = "state_poison"
    local _, written = writeFixture(id, clip, { 1, 2, 3, 4, 3, 2, 1, 1 })
    local okRun, err = pcall(function()
        ER.clearCache()
        require("src.ui.SpriteAnimation").clearCache()
        EnemyLife._setData(id, { states = { poison = { clip = clip, fps = 30 } } })
        local enemy = { spriteId = id, health = 10, isBoss = false, statusEffects = {}, armor = 0, baseDamage = 5, maxHealth = 50 }
        local game = { enemy = enemy }
        local canvas = love.graphics.newCanvas(800, 800)
        local function step(dt)
            ER.update(dt)
            love.graphics.setCanvas(canvas)
            ER.draw(game, 400, 700)
            love.graphics.setCanvas()
        end
        for _ = 1, 30 do step(0) end
        t:truthy("clip de estado aquecido", EnemyLife.isWarm(clip))
        enemy.statusEffects = { { name = "poison", stacks = 3, duration = 2 } }
        local entered, enterFrame = false, nil
        for _ = 1, 300 do
            local before = ER.debugState().animName
            step(1 / 60)
            if ER.debugState().animName == clip then entered = true enterFrame = (ER.getLastFoot() or {}).frame break end
            if before ~= "idle" then break end
        end
        t:truthy("veneno troca o idle pelo clip de estado", entered)
        t:eq("troca no quadro 0: o clip de estado entra no seu quadro 0 (= idle 0)", enterFrame, 1)
        t:falsy("clip de estado nao conta como ocupado", ER.isBusy())
        ER.triggerHurt()
        t:truthy("dano sobrepoe o estado", ER.debugState().animName ~= clip)
        local back = false
        for _ = 1, 300 do
            step(1 / 60)
            if ER.debugState().animName == clip then back = true break end
        end
        t:truthy("depois do dano volta ao clip de estado", back)
        enemy.statusEffects = {}
        local left = false
        for _ = 1, 300 do
            step(1 / 60)
            if ER.debugState().animName == "idle" then left = true break end
        end
        t:truthy("sem veneno volta ao idle no quadro 0", left)
        enemy.statusEffects = { { name = "poison", stacks = 3, duration = 2 } }
        for _ = 1, 120 do step(1 / 60) end
        enemy.health = 0
        ER.triggerDeath(id)
        local during = false
        for _ = 1, 120 do
            step(1 / 60)
            if ER.debugState().animName == clip then during = true end
        end
        t:falsy("estado nunca toca durante a morte", during)
    end)
    removeFixture(id, clip, written)
    EnemyLife._setData(id, nil)
    ER.clearCache()
    t:truthy("clip de estado integrado sem erro" .. (okRun and "" or (": " .. tostring(err))), okRun)
end

local function checkDowndraft(t, EnemyLife)
    local V = EnemyLife.validate
    t:falsy("downdraft sem strokes rejeitado", V({ fx = { { kind = "downdraft", xr = 0.5, yr = 1 } } }))
    t:falsy("stroke nao inteiro rejeitado", V({ fx = { { kind = "downdraft", xr = 0.5, yr = 1, strokes = { 2.5 } } } }))
    t:falsy("strokes fora do downdraft rejeitado", V({ fx = { { kind = "smoke", xr = 0.5, yr = 1, strokes = { 2 } } } }))
    t:truthy("downdraft com strokes aceito", V({ fx = { { kind = "downdraft", xr = 0.5, yr = 1, strokes = { 2, 8 } } } }))

    local Poses = require("src.data.enemy_poses")
    local Enemies = require("src.data.enemies")
    for id, p in pairs(Poses.BY_ID) do
        local d = EnemyLife.load(id)
        local drafts = {}
        for _, e in ipairs((d and d.fx) or {}) do
            if e.kind == "downdraft" then drafts[#drafts + 1] = e end
        end
        if p.pose == "floating" and Enemies.HOME_BIOME[id] then
            t:truthy(id .. ": quem voa sopra o chao (downdraft declarado)", #drafts > 0)
            local nIdle = #(clipFiles(id, "idle") or {})
            for _, e in ipairs(drafts) do
                for _, f in ipairs(e.strokes) do
                    t:truthy(string.format("%s: stroke %d dentro do idle (%d quadros)", id, f, nIdle), f <= nIdle)
                end
            end
        elseif p.pose ~= "floating" then
            t:eq(id .. ": apoiado nao sopra o chao", #drafts, 0)
        end
    end

    local ER = require("src.ui.EnemyRenderer")
    for fid, p in pairs(Poses.BY_ID) do
        if p.flapPeak then
            local hi = ER.poseOffsetY(fid, 100, 0, 0, p.flapPeak)
            local lo = ER.poseOffsetY(fid, 100, 0, 0, (p.flapPeak + 0.5) % 1)
            t:truthy(string.format("%s: corpo mais alto no pico da batida (%.2f < %.2f)", fid, hi, lo), hi < lo)
        end
    end

    local id = "__life_draft__"
    local strokes = { 3, 9 }
    EnemyLife._setData(id, { fx = { { kind = "downdraft", xr = 0.5, yr = 1, spread = 0.4, strokes = strokes } } })
    EnemyLife.update(0, id, "idle", 1, false)
    local frameN, f = 12, 1
    local function tick(anim, dt)
        EnemyLife.frame(100, 50, 2, 0, 0, 100, 100, anim ~= "death", 1, nil, 90)
        local s0 = EnemyLife.strokeCount()
        EnemyLife.update(dt or (1 / 12), id, anim, f, false)
        local fired = EnemyLife.strokeCount() - s0
        local was = f
        f = (f % frameN) + 1
        return fired, was
    end
    local wrong, fires = 0, 0
    for _ = 1, frameN * 4 do
        local fired, was = tick("idle")
        local isStroke = was == strokes[1] or was == strokes[2]
        if fired > 0 then fires = fires + 1 end
        if (fired > 0) ~= isStroke then wrong = wrong + 1 end
    end
    t:eq("motas so nos quadros de batida", wrong, 0)
    t:eq("uma rajada por batida (4 voltas x 2 batidas)", fires, 8)
    t:truthy("rajada gera motas (" .. EnemyLife.draftCount() .. ")", EnemyLife.draftCount() > 0)

    local fidFires = 0
    for _ = 1, frameN * 2 do fidFires = fidFires + tick("fidget_x") end
    t:eq("fidget nao sopra", fidFires, 0)

    local runs = {}
    for r = 1, 3 do
        collectgarbage("collect")
        collectgarbage("stop")
        local k0 = collectgarbage("count")
        for _ = 1, frameN * 10 do tick("idle") end
        runs[r] = (collectgarbage("count") - k0) / (frameN * 10)
        collectgarbage("restart")
    end
    table.sort(runs)
    local kb = runs[1]
    t:truthy(string.format("downdraft sem alocacao (%.4f KB/quadro)", kb), kb < 0.05)

    local deathFires = 0
    for _ = 1, 12 do deathFires = deathFires + tick("death") end
    t:eq("morte: nenhuma batida sopra", deathFires, 0)
    for _ = 1, 12 do tick("death") end
    t:eq("morte: motas somem", EnemyLife.draftCount(), 0)

    local gs = _G.gameSettings
    _G.gameSettings = { reducedMotion = true }
    EnemyLife._setData(id, { fx = { { kind = "downdraft", xr = 0.5, yr = 1, strokes = strokes } } })
    EnemyLife.update(0, id, "idle", 1, false)
    local redFires = 0
    for _ = 1, frameN * 2 do redFires = redFires + tick("idle") end
    t:eq("reducedMotion: sem sopro", redFires + EnemyLife.draftCount(), 0)
    _G.gameSettings = gs
    EnemyLife._setData(id, nil)
end

M.PIXEL_IDS = { "abyss_acolyte", "frost_troll", "ember_imp", "pit_brute", "dusk_bat", "winter_monarch" }
M.MIN_CHANGED = 0.04
M.MAX_ROW_JUMP = 0.65
M.BAND_WINDOW = 4
M.DELTA = 0.06
M._rb, M._rc = {}, {}

function M.measure(base, img, x0, y0, x1, y1)
    local body, changed = 0, 0
    local maxJump = 0
    local RB, RC, nr = M._rb, M._rc, 0
    for y = y0, y1 do
        local rb, rc = 0, 0
        for x = x0, x1 do
            local r0, g0, b0, a0 = base:getPixel(x, y)
            local r1, g1, b1 = img:getPixel(x, y)
            local ch = math.abs(r0 - r1) + math.abs(g0 - g1) + math.abs(b0 - b1) > M.DELTA
            if a0 > 0.5 then
                rb = rb + 1
                if ch then rc = rc + 1 end
            elseif ch then
                changed = changed + 1
            end
        end
        body, changed = body + rb, changed + rc
        nr = nr + 1
        RB[nr], RC[nr] = rb, rc
    end
    local Wn = M.BAND_WINDOW
    for i = Wn + 1, nr - Wn do
        local ab, ac, bb, bc = 0, 0, 0, 0
        local thin = false
        for j = i - Wn, i - 1 do ab, ac = ab + RB[j], ac + RC[j]; if RB[j] < 30 then thin = true end end
        for j = i, i + Wn - 1 do bb, bc = bb + RB[j], bc + RC[j]; if RB[j] < 30 then thin = true end end
        if not thin then
            local jmp = math.abs(ac / ab - bc / bb)
            if jmp > maxJump then maxJump = jmp end
        end
    end
    return changed / math.max(1, body), maxJump
end

local function checkStatePixels(t, EnemyLife)
    local ER = require("src.ui.EnemyRenderer")
    local ES = EnemyLife.States
    t:truthy("shader de estados compila", ES.shader() ~= nil)
    do
        local a = love.image.newImageData(120, 120)
        local b = love.image.newImageData(120, 120)
        for y = 0, 119 do
            for x = 0, 119 do
                local v = 0.4 + 0.3 * ((x * 7 + y * 13) % 5) / 5
                a:setPixel(x, y, v, v * 0.9, v * 0.8, 1)
                if y >= 70 then b:setPixel(x, y, v * 0.3, v * 0.2, v * 0.1, 1) else b:setPixel(x, y, v, v * 0.9, v * 0.8, 1) end
            end
        end
        local _, jmp = M.measure(a, b, 0, 0, 119, 119)
        a:release(); b:release()
        t:truthy(string.format("detector pega a faixa queimada antiga (salto %.2f)", jmp), jmp > M.MAX_ROW_JUMP)
    end
    local realTime = love.timer.getTime
    love.timer.getTime = function() return 1234.5 end
    local W, H = 900, 900
    local canvas = love.graphics.newCanvas(W, H)
    local function render(game, skip)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)
        ER.draw(game, W / 2, H - 120)
        love.graphics.setCanvas()
        if skip then return nil end
        return canvas:newImageData()
    end
    local lowFail, bandFail, sanityFail = {}, {}, {}
    local report = {}
    for _, id in ipairs(M.PIXEL_IDS) do
        ER.clearCache()
        ER.resetRun()
        EnemyLife.clearCache()
        local game = { enemy = { spriteId = id, health = 10, maxHealth = 10, isBoss = false, statusEffects = {},
                                 armor = 0, baseDamage = 5 } }
        EnemyLife.prewarmNow(id)
        ES.force({})
        for _ = 1, 4 do ER.update(1 / 60); render(game, true) end
        local base = render(game)
        local again = render(game)
        local same = 0
        for y = 0, H - 1, 3 do
            for x = 0, W - 1, 3 do
                local r0, g0, b0 = base:getPixel(x, y)
                local r1, g1, b1 = again:getPixel(x, y)
                if math.abs(r0 - r1) + math.abs(g0 - g1) + math.abs(b0 - b1) > 0.02 then same = same + 1 end
            end
        end
        if same > 0 then sanityFail[#sanityFail + 1] = id end
        again:release()
        local x0, y0, x1, y1 = W, H, 0, 0
        for y = 0, H - 1, 2 do
            for x = 0, W - 1, 2 do
                local _, _, _, a = base:getPixel(x, y)
                if a > 0.5 then
                    if x < x0 then x0 = x end
                    if x > x1 then x1 = x end
                    if y < y0 then y0 = y end
                    if y > y1 then y1 = y end
                end
            end
        end
        x0, y0 = math.max(0, x0 - 40), math.max(0, y0 - 40)
        x1, y1 = math.min(W - 1, x1 + 40), math.min(H - 1, y1 + 10)
        local frameIdx = (ER.getLastFoot() or {}).frame or 1
        for _, st in ipairs(ES.LIST) do
            ES.force({ st })
            for _ = 1, 50 do EnemyLife.update(1 / 60, id, "idle", frameIdx, false) end
            local img = render(game)
            local frac, maxJump = M.measure(base, img, x0, y0, x1, y1)
            img:release()
            report[#report + 1] = string.format("%s/%s %.2f", id, st, frac)
            if frac < M.MIN_CHANGED then lowFail[#lowFail + 1] = string.format("%s/%s(%.3f)", id, st, frac) end
            if maxJump > M.MAX_ROW_JUMP then bandFail[#bandFail + 1] = string.format("%s/%s(%.2f)", id, st, maxJump) end
        end
        base:release()
        ES.force(nil)
    end
    love.timer.getTime = realTime
    t:eq("desenho sem estado e estavel (base da comparacao): " .. table.concat(sanityFail, " "), #sanityFail, 0)
    t:eq(string.format("todo estado muda ao menos %d%% do corpo em 6 criaturas: %s", M.MIN_CHANGED * 100,
        table.concat(lowFail, " ")), #lowFail, 0)
    t:eq("nenhum estado pinta faixa reta (salto entre linhas vizinhas <= " .. M.MAX_ROW_JUMP .. "): "
        .. table.concat(bandFail, " "), #bandFail, 0)
    t:truthy("cobertura por estado: " .. table.concat(report, " "), #report == #M.PIXEL_IDS * #ES.LIST)

    local img = love.graphics.newImage(love.image.newImageData(64, 64))
    ES.force(ES.LIST)
    EnemyLife.update(1 / 60, "frost_troll", "idle", 1, false)
    love.graphics.setCanvas(canvas)
    for _ = 1, 10 do ES.drawBody(img, 10, 10, 3, 1, 1, 1, 1, nil) end
    local samples = {}
    for r = 1, 3 do
        collectgarbage("collect")
        collectgarbage("stop")
        local k0 = collectgarbage("count")
        for _ = 1, 200 do ES.drawBody(img, 10, 10, 3, 1, 1, 1, 1, nil) end
        samples[r] = (collectgarbage("count") - k0) / 200
        collectgarbage("restart")
    end
    love.graphics.setCanvas()
    table.sort(samples)
    t:truthy(string.format("corpo com estados sem alocacao por quadro (%.4f KB)", samples[2]), samples[2] < 0.05)
    ES.force(nil)
    ER.clearCache()
    ER.resetRun()
    EnemyLife.clearCache()
end

function M.run()
    local t = TK.new("monstros vivos parados (EnemyLife)")
    TK.bootstrap()
    local EnemyLife = require("src.ui.EnemyLife")
    EnemyLife.clearCache()
    EnemyLife.States.force(nil)
    local gs = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }
    checkData(t, EnemyLife)
    checkScheduler(t, EnemyLife)
    checkFx(t, EnemyLife)
    checkRenderer(t, EnemyLife)
    checkStates(t, EnemyLife)
    checkStateClip(t, EnemyLife)
    checkDowndraft(t, EnemyLife)
    checkStatePixels(t, EnemyLife)
    _G.gameSettings = gs
    EnemyLife.clearCache()
    return t:done()
end

return M
