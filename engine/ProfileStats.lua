-- engine/ProfileStats.lua
-- Perfil persistente do jogador (fora da run): vitórias, derrotas, melhor
-- progresso, classe favorita. Sobrevive entre sessões via love.filesystem
-- (profile.lua no save dir), mesmo padrão atomic-write do SaveManager.
--
-- É o que faz o menu parecer "de verdade": o jogo lembra de você.
--
-- Uso:
--   local ProfileStats = require("engine.ProfileStats")
--   ProfileStats.recordRunStart("warrior")
--   ProfileStats.recordVictory(actNumber)
--   ProfileStats.recordDefeat(actNumber, floorInAct)
--   local s = ProfileStats.get()   -- {runs, wins, losses, bestAct, bestFloor, ...}

local SaveManager = require("engine.SaveManager")

local ProfileStats = {}

local PATH = "profile.lua"

local DEFAULTS = {
    runs      = 0,   -- runs iniciadas
    wins      = 0,   -- vitórias (boss do ato final morto)
    losses    = 0,   -- derrotas (player morreu)
    bestAct   = 0,   -- ato mais fundo já alcançado
    bestFloor = 0,   -- andar dentro do bestAct
    bestScore = 0,   -- recorde de pontuação TINTA×SELO (F3)
    lastClass = nil, -- classe da última run iniciada
}

local cache = nil

local function load()
    if cache then return cache end
    cache = {}
    for k, v in pairs(DEFAULTS) do cache[k] = v end
    if love.filesystem.getInfo(PATH) then
        local chunk = love.filesystem.load(PATH)
        if chunk then
            local ok, data = pcall(chunk)
            if ok and type(data) == "table" then
                for k, v in pairs(data) do cache[k] = v end
            end
        end
    end
    return cache
end

local function save()
    if not cache then return end
    -- Tools headless (screenshots/smokes) não podem poluir o perfil real.
    if _G.HEADLESS_TOOL then return end
    love.filesystem.write(PATH, "return " .. SaveManager.serialize(cache))
end

function ProfileStats.get()
    return load()
end

function ProfileStats.recordRunStart(classId)
    local s = load()
    s.runs = s.runs + 1
    s.lastClass = classId
    save()
end

-- Atualiza o "melhor progresso" (chamado por victory/defeat com o ponto
-- onde a run terminou).
local function bumpBest(actNumber, floorInAct)
    local s = load()
    actNumber = actNumber or 0
    floorInAct = floorInAct or 0
    if actNumber > s.bestAct
        or (actNumber == s.bestAct and floorInAct > s.bestFloor) then
        s.bestAct = actNumber
        s.bestFloor = floorInAct
    end
end

function ProfileStats.recordVictory(actNumber, floorInAct)
    local s = load()
    s.wins = s.wins + 1
    bumpBest(actNumber, floorInAct)
    save()
end

function ProfileStats.recordDefeat(actNumber, floorInAct)
    local s = load()
    s.losses = s.losses + 1
    bumpBest(actNumber, floorInAct)
    save()
end

-- Recorde de pontuação (persistido no fim da run — vitória OU derrota).
function ProfileStats.updateBestScore(score)
    if not score or score <= 0 then return end
    local s = load()
    if score > (s.bestScore or 0) then
        s.bestScore = score
        save()
    end
end

-- true se há qualquer histórico (menu decide se mostra a plaque de perfil).
function ProfileStats.hasHistory()
    return load().runs > 0
end

return ProfileStats
