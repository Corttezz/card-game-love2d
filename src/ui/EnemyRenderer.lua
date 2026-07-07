-- src/ui/EnemyRenderer.lua
-- Renderiza o inimigo como sprite animado no canvas de gameplay.
-- Combina MÚLTIPLAS camadas visuais pra maximizar polish:
--
--   1. Sombra elíptica no chão (alpha 0.45)
--   2. Partículas ambientais por ato (poeira/faíscas/névoa)
--   3. Animação pixellab real (frames) OU sprite estático
--   4. Idle bounce sutil (sin wave ±2px) — SEMPRE ativo, mesmo com anim real
--   5. Micro tremor (±1px horizontal, nervosismo constante)
--   6. Pulse de cor (tint varia ±8% em sin lento)
--   7. Flash branco em hurt (overlay)
--   8. Outline glow em hurt (aura vermelha)
--
-- Todas as camadas são baratas (trig + draw) e combinadas criam sensação de "vida".

local SpriteAnimation = require("src.ui.SpriteAnimation")
local LightEngine = require("engine.LightEngine")

local EnemyRenderer = {}

-- Cache de sprites estaticos (rotacoes south/east/west/north do create_character).
local staticCache = {}
local staticMiss = {}

-- Estado da animacao corrente por enemyId
local currentAnim = nil
local currentEnemyId = nil
local currentAnimName = nil
local hurtTime = 0

-- Ambient particles (fake): partículas locais orbitando o inimigo (poeira/spark/fog).
local ambientParticles = {}
local ambientSpawnTimer = 0

local IDLE_FPS = 8
local HURT_FPS = 12
local DEATH_FPS = 10

-- Pipeline atual usa só direção `south` (combate frontal estático). Outras
-- direções foram removidas em 2026-04-21 — economiza ~75% disco e créditos
-- de geração. Se um dia precisar de rotação, regerar via animate_character
-- com directions=["east","west","north"] específicas.
local DIRECTIONS = { "south" }

-- Cores temáticas por inimigo (pra partículas ambientais)
local AMBIENT_TINTS = {
    grave_slime  = { 0.45, 0.55, 0.30 },  -- verde podre
    stone_golem  = { 0.55, 0.50, 0.55 },  -- pedra roxa
    abyss_wraith = { 0.55, 0.30, 0.70 },  -- roxo espectral
}

local function loadStatic(id)
    if not id then return nil end
    if staticCache[id] then return staticCache[id] end
    if staticMiss[id] then return nil end

    local base = "assets/sprites/characters/enemies/" .. id .. "/"
    local sprites = {}
    local found = 0
    for _, dir in ipairs(DIRECTIONS) do
        local path = base .. dir .. ".png"
        if love.filesystem.getInfo(path) then
            local ok, img = pcall(love.graphics.newImage, path)
            if ok and img then
                img:setFilter("nearest", "nearest")
                sprites[dir] = img
                found = found + 1
            end
        end
    end
    if found == 0 then staticMiss[id] = true; return nil end
    staticCache[id] = sprites
    return sprites
end

local function ensureAnim(enemyId, animName)
    if currentAnim and currentEnemyId == enemyId and currentAnimName == animName
       and not currentAnim:isFinished() then
        return currentAnim
    end

    local fps = IDLE_FPS
    local opts = { loop = true }
    if animName == "hurt" then
        fps = HURT_FPS
        opts = { loop = false, onComplete = function()
            currentAnim = SpriteAnimation.new(enemyId, "idle", "south", IDLE_FPS, { loop = true })
            currentAnimName = "idle"
        end }
    elseif animName == "death" then
        fps = DEATH_FPS
        opts = { loop = false }
    end

    local anim = SpriteAnimation.new(enemyId, animName, "south", fps, opts)
    if anim then
        currentAnim = anim
        currentEnemyId = enemyId
        currentAnimName = animName
    end
    return anim
end

function EnemyRenderer.clearCache()
    staticCache = {}
    staticMiss = {}
    SpriteAnimation.clearCache()
    currentAnim = nil
    currentEnemyId = nil
    currentAnimName = nil
    ambientParticles = {}
end

-- Juice de CHEGADA (fim da viagem na estrada): o inimigo "assenta" com
-- duas quicadas rápidas em vez de aparecer num corte seco.
local arrivalT = 0
function EnemyRenderer.triggerArrival()
    arrivalT = 0.55
end

function EnemyRenderer.getArrivalOffset()
    if arrivalT <= 0 then return 0 end
    local k = arrivalT / 0.55
    -- duas quicadas decrescentes (abs(sin) com envelope k²)
    return -math.abs(math.sin(k * math.pi * 2.2)) * 14 * k * k
end

function EnemyRenderer.triggerHurt()
    -- Guard: nao sobrescrever death anim com hurt. A death e "terminal" —
    -- uma vez acionada, nao volta pra hurt/idle. Sem esse guard, o hurt
    -- disparado pelo CombatAnimationSystem apos o dano fatal reiniciava
    -- a animacao e a morte nunca aparecia em tela.
    if currentAnimName == "death" then return end
    hurtTime = 0.20
    if currentEnemyId and SpriteAnimation.exists(currentEnemyId, "hurt", "south") then
        ensureAnim(currentEnemyId, "hurt")
    end
end

function EnemyRenderer.triggerDeath(enemyId)
    local id = enemyId or currentEnemyId
    if id and SpriteAnimation.exists(id, "death", "south") then
        ensureAnim(id, "death")
    end
end

-- Spawn de uma particula ambiental (poeira/spark/fog) orbitando o inimigo.
local function spawnAmbientParticle(cx, cy, tint)
    local angle = love.math.random() * math.pi * 2
    local dist = 20 + love.math.random() * 30
    table.insert(ambientParticles, {
        x = cx + math.cos(angle) * dist,
        y = cy - love.math.random() * 120,
        vx = (love.math.random() - 0.5) * 10,
        vy = -(10 + love.math.random() * 15), -- sobe devagar
        life = 1.0 + love.math.random() * 0.8,
        maxLife = 1.0,
        size = 1 + love.math.random(0, 1),
        tint = tint or { 0.6, 0.6, 0.6 },
    })
end

function EnemyRenderer.update(dt)
    if currentAnim then currentAnim:update(dt) end
    if hurtTime > 0 then hurtTime = math.max(0, hurtTime - dt) end
    if arrivalT > 0 then arrivalT = math.max(0, arrivalT - dt) end

    -- Spawn partículas ambientais a cada ~0.35s
    ambientSpawnTimer = ambientSpawnTimer - dt
    if ambientSpawnTimer <= 0 and currentEnemyId then
        ambientSpawnTimer = 0.28 + love.math.random() * 0.20
        -- posição central só pra spawn; o draw usa a posição real do inimigo
        local tint = AMBIENT_TINTS[currentEnemyId] or { 0.6, 0.6, 0.6 }
        -- Nota: spawn com placeholder cx=0 cy=0; reajustado em draw via offset
        -- (hack leve pq update nao sabe a pos; deixa particula nascer em 0,0
        -- e draw translada pro cx,cy). Mais simples: spawn direto em draw.
    end

    -- Atualiza partículas existentes
    for i = #ambientParticles, 1, -1 do
        local p = ambientParticles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(ambientParticles, i)
        end
    end
end

-- Spawn de particula ambiental na posicao correta (chamado em draw)
local function tickAmbientSpawn(cx, cy, dt_hint)
    if not currentEnemyId then return end
    if #ambientParticles > 18 then return end -- cap
    -- probabilidade baixa por frame; resulta em ~3-5 particulas/sec
    if love.math.random() < 0.08 then
        spawnAmbientParticle(cx, cy, AMBIENT_TINTS[currentEnemyId])
    end
end

-- Retorna bbox { x, y, w, h } do sprite desenhado (em pixels de tela), ou false.
-- EnemyHud usa esse bbox pra ancorar HP bar / intent icon.
function EnemyRenderer.draw(game, cx, cy)
    if not game or not game.enemy or not game.enemy.spriteId then return false end
    local id = game.enemy.spriteId

    -- Detecta necessidade de re-iniciar a idle:
    --  1) Inimigo trocou de spriteId (novo ato/node).
    --  2) Nao ha anim carregada ainda.
    --  3) Anim de death terminou mas o inimigo atual esta vivo (proxima batalha
    --     com mesmo spriteId): sem esse reset, a tela continua mostrando o
    --     ultimo frame de death ("inimigo deitado morto").
    local enemyAlive = game.enemy and game.enemy.health > 0
    local stuckOnDeath = currentAnimName == "death"
        and currentAnim and currentAnim:isFinished()
        and enemyAlive
    if currentEnemyId ~= id or currentAnim == nil or stuckOnDeath then
        ensureAnim(id, "idle")
    end

    -- Resolve sprite ou anim
    local iw, ih = 0, 0
    local hasAnim = (currentAnim ~= nil)
    if hasAnim then
        iw, ih = currentAnim:getSize()
    else
        local sprites = loadStatic(id)
        if not sprites then return false end
        local staticImg = sprites.south or sprites.east or sprites.west or sprites.north
        if not staticImg then return false end
        iw, ih = staticImg:getWidth(), staticImg:getHeight()
    end

    -- Escala alvo. 250 normal / 330 boss. v5: escala ADAPTATIVA (float) —
    -- o piso max(4,...) era pros sprites antigos de ~50px; o roster novo
    -- tem 150-220px de conteúdo e virava gigante com scale 4.
    local targetHeight = 250
    if game.enemy and game.enemy.isBoss then targetHeight = 330 end
    local scale = targetHeight / ih
    if ih <= 80 then scale = math.max(4, math.floor(scale)) end -- roster legado

    -- =========================================================
    -- CAMADAS VISUAIS (aplicadas em ordem)
    -- =========================================================
    local t = love.timer.getTime()

    -- (2) Partículas ambientais: spawn + draw por baixo do sprite
    tickAmbientSpawn(cx, cy, 0)
    for _, p in ipairs(ambientParticles) do
        local alpha = math.max(0, math.min(1, p.life / (p.maxLife * 2)))
        love.graphics.setColor(p.tint[1], p.tint[2], p.tint[3], alpha * 0.55)
        love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), p.size, p.size)
    end

    -- (4) Idle bounce (±1px vertical — respiração; ±2 parecia flutuar)
    local bounce = math.floor(math.sin(t * 1.6) * 1)
    -- (5) Micro tremor (±1px horizontal)
    local jitter = math.floor(math.sin(t * 13.1) * 0.5 + math.cos(t * 17.3) * 0.5)

    local drawX = cx - (iw * scale) / 2 + jitter
    local drawY = cy - ih * scale + bounce + EnemyRenderer.getArrivalOffset()

    -- (1) Sombra RASTEIRA no chão (v5.4): larga e achatada, colada nos pés
    -- (cy = superfície real via getRoadAnchor) — ancora o monstro no chão.
    -- A versão antiga flutuava por causa de offset; o problema era o offset,
    -- não a sombra. Sem ela o inimigo parece adesivo (feedback).
    love.graphics.setColor(0, 0, 0, 0.30)
    love.graphics.ellipse("fill", cx + jitter * 0.5, cy - 1,
        iw * scale * 0.42, math.max(4, iw * scale * 0.055))

    -- (6) Pulse de tint (cor varia ±6% lentamente, respiração sutil)
    local pulse = 0.94 + (math.sin(t * 1.1) * 0.5 + 0.5) * 0.06
    love.graphics.setColor(pulse, pulse, pulse, 1)

    -- (3) Sprite principal (anim real OR estático)
    if hasAnim then
        currentAnim:draw(drawX, drawY, scale, { pulse, pulse, pulse, 1 })
    else
        local sprites = loadStatic(id)
        local staticImg = sprites and (sprites.south or sprites.east or sprites.west or sprites.north)
        if staticImg then
            love.graphics.draw(staticImg, drawX, drawY, 0, scale, scale)
        end
    end

    -- (8) Aura vermelha durante hurt (outline glow barato: draw com offset + tint)
    if hurtTime > 0 then
        local a = hurtTime / 0.20
        local offsets = { {-2, 0}, {2, 0}, {0, -2}, {0, 2} }
        love.graphics.setColor(1, 0.2, 0.2, a * 0.35)
        for _, off in ipairs(offsets) do
            if hasAnim then
                currentAnim:draw(drawX + off[1], drawY + off[2], scale)
            else
                local sprites = loadStatic(id)
                local staticImg = sprites and sprites.south
                if staticImg then
                    love.graphics.draw(staticImg, drawX + off[1], drawY + off[2], 0, scale, scale)
                end
            end
        end

        -- (7) Flash branco por cima
        love.graphics.setColor(1, 1, 1, a * 0.55)
        if hasAnim then
            currentAnim:draw(drawX, drawY, scale)
        else
            local sprites = loadStatic(id)
            local staticImg = sprites and sprites.south
            if staticImg then
                love.graphics.draw(staticImg, drawX, drawY, 0, scale, scale)
            end
        end
    end

    -- LightEngine v1.1: o corpo do inimigo OCLUI luzes atrás dele (janelas
    -- do castelo, poças mais fundas) — silhueta pixel-perfeita no lightmap.
    -- z = BATTLE_REL (posição do inimigo na estrada); no-op sem frame de luz
    -- (interiores). Lanterna mais PRÓXIMA que ele continua iluminando-o.
    do
        local oxT, oyT = love.graphics.transformPoint(drawX, drawY)
        local animRef = hasAnim and currentAnim or nil
        local staticRef = nil
        if not animRef then
            local sprites = loadStatic(id)
            staticRef = sprites and (sprites.south or sprites.east
                or sprites.west or sprites.north)
        end
        if animRef or staticRef then
            LightEngine.submitOccluder({
                z = 9,   -- WorldRoad.BATTLE_REL (sem require circular)
                bx = oxT, by = oyT, w = iw * scale, h = ih * scale,
                fn = function()
                    if animRef then
                        -- SpriteAnimation:draw ignora setColor sem tint —
                        -- repassa a cor ambiente que o engine deixou setada
                        local r, g, b = love.graphics.getColor()
                        animRef:draw(oxT, oyT, scale, { r, g, b, 1 })
                    else
                        love.graphics.draw(staticRef, oxT, oyT, 0, scale, scale)
                    end
                end,
            })
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    -- Retorna bounding box do sprite pra overlays (HP bar / intent).
    -- cx já é o eixo horizontal do sprite; pés ficam em cy; topo em drawY.
    return {
        cx = cx,
        topY = drawY,
        bottomY = cy,
        width = iw * scale,
        height = ih * scale,
    }
end

-- Billboard leve pro WorldRoad: o inimigo que vem "lá de trás" na estrada
-- durante a viagem. Retorna { img, iw, ih, targetScale } ou nil.
-- targetScale = mesma escala que draw() usa na batalha (handoff sem pulo).
function EnemyRenderer.getEncounterBillboard(enemy)
    if not enemy or not enemy.spriteId then return nil end
    local sprites = loadStatic(enemy.spriteId)
    local img = sprites and (sprites.south or sprites.east or sprites.west or sprites.north)
    if not img then return nil end
    local ih = img:getHeight()
    local targetHeight = enemy.isBoss and 330 or 250
    local ts = targetHeight / ih
    if ih <= 80 then ts = math.max(4, math.floor(ts)) end -- roster legado
    return {
        img = img,
        iw = img:getWidth(),
        ih = ih,
        targetScale = ts,
    }
end

-- ROSTER v5 (data-driven): monstro por CONTEXTO — ato/bioma × tipo de node.
-- battle = comum; elite/mini_boss = elite do ato; boss = chefe do ato.
-- 4-6 = biomas endless (frost/marsh/dusk), casados com o visual do
-- WorldRoad (que também embrulha o índice módulo 6).
local ENEMY_ROSTER = {
    [1] = { battle = "cursed_scarecrow", elite = "harvest_reaper",
            mini_boss = "harvest_reaper", boss = "carrion_king" },
    [2] = { battle = "moon_gargoyle", elite = "rune_golem",
            mini_boss = "rune_golem", boss = "tower_lich" },
    [3] = { battle = "ember_imp", elite = "obsidian_sentinel",
            mini_boss = "obsidian_sentinel", boss = "abyss_tyrant" },
    [4] = { battle = "frost_wight", elite = "glacier_knight",
            mini_boss = "glacier_knight", boss = "winter_monarch" },
    [5] = { battle = "bog_ghoul", elite = "mire_hag",
            mini_boss = "mire_hag", boss = "rot_colossus" },
    [6] = { battle = "dusk_shade", elite = "blood_duke",
            mini_boss = "blood_duke", boss = "eclipse_queen" },
}

function EnemyRenderer.resolveSpriteId(actNumber, nodeType)
    -- mesmo wrap do WorldRoad.rawBiome: endless cicla 4,5,6,1,2,3,...
    local effectiveAct = (((actNumber or 1) - 1) % 6) + 1
    local roster = ENEMY_ROSTER[effectiveAct] or ENEMY_ROSTER[1]
    return roster[nodeType or "battle"] or roster.battle
end

return EnemyRenderer
