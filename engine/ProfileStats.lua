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

-- MODO RECUPERAÇÃO (Out/2026): o perfil existia no disco e NENHUMA geração
-- (principal, .tmp, .bak) parseou. Antes o load caía nos defaults e o
-- próximo save gravava os defaults POR CIMA — conquistas, desbloqueios e
-- vitórias perdidos. Agora o jogo segue com o perfil em memória, mas NUNCA
-- grava: o arquivo danificado fica intacto (e copiado em .corrupt-<ts>)
-- para recuperação manual.
local recoveryMode = false
local recoveryWarned = false
-- SÓ TESTES: com caminho próprio, o save funciona mesmo sob HEADLESS_TOOL.
local testPath = nil

local DEFAULTS = {
    runs      = 0,   -- runs iniciadas
    wins      = 0,   -- vitórias (boss do ato final morto)
    losses    = 0,   -- derrotas (player morreu)
    bestAct   = 0,   -- ato mais fundo já alcançado
    bestFloor = 0,   -- andar dentro do bestAct
    bestScore = 0,   -- recorde de pontuação TINTA×SELO (F3)
    lastClass = nil, -- classe da última run iniciada
    -- F4 (conquistas):
    achievements = {},  -- { [id] = true }
    counters = {},      -- { cardsPlayed = N, forges = N }
    cardsSeen = {},     -- { [cardId] = true } (Bibliotecário)
    winsByClass = {},   -- { warrior = true, ... } (Trindade)
    tipsSeen = {},      -- { [tipId] = true } dicas do tutorial já vistas (src/systems/Tutorial)
}

local cache = nil

local function load()
    if cache then return cache end
    cache = {}
    for k, v in pairs(DEFAULTS) do cache[k] = v end
    -- Tabelas aninhadas precisam existir mesmo em perfis antigos.
    cache.achievements = {}
    cache.counters = {}
    cache.cardsSeen = {}
    cache.winsByClass = {}
    cache.tipsSeen = {}
    -- Perfil e DADO, nunca codigo: readDataFile recusa bytecode e roda o
    -- chunk sem acesso a os/io; se o principal não parseia, tenta .tmp/.bak.
    local data, info = SaveManager.readDataFile(testPath or PATH)
    if data then
        for k, v in pairs(data) do cache[k] = v end
        if info.source ~= "main" then
            print("[ProfileStats] !!! perfil RECUPERADO de " .. tostring(info.source)
                .. " (principal ilegivel" .. (info.corruptCopy
                    and (", copia em " .. info.corruptCopy) or "") .. ")")
        end
    elseif info.existed then
        recoveryMode = true
        print("[ProfileStats] !!!!!! PERFIL ILEGIVEL E SEM BACKUP VALIDO — modo"
            .. " recuperacao: o jogo NAO vai gravar o perfil nesta sessao para"
            .. " nao apagar o progresso. Copia: " .. tostring(info.corruptCopy))
    end
    return cache
end

local function save()
    if not cache then return end
    -- Tools headless (screenshots/smokes) não podem poluir o perfil real.
    if _G.HEADLESS_TOOL and not testPath then return end
    if recoveryMode then
        if not recoveryWarned then
            recoveryWarned = true
            print("[ProfileStats] modo recuperacao: gravacao do perfil RECUSADA")
        end
        return
    end
    local ok, err = SaveManager.writeFile(testPath or PATH,
        "return " .. SaveManager.serialize(cache))
    if not ok then print("[ProfileStats] falha ao salvar perfil: " .. tostring(err)) end
end

-- true quando o perfil não carregou e o jogo se recusa a gravá-lo.
function ProfileStats.isRecoveryMode()
    load()
    return recoveryMode
end

-- SÓ TESTES: aponta o perfil para outro arquivo (nil = volta ao real) e
-- zera cache/modo recuperação, forçando releitura do disco.
function ProfileStats._setPathForTests(path)
    testPath = path
    cache = nil
    recoveryMode = false
    recoveryWarned = false
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

function ProfileStats.recordVictory(actNumber, floorInAct, classId)
    local s = load()
    s.wins = s.wins + 1
    if classId then
        s.winsByClass = s.winsByClass or {}
        s.winsByClass[classId] = true
    end
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

-- Contadores acumulados entre runs (cartas jogadas, forjas...). NÃO salva a
-- cada bump (seria 1 write de disco por turno) — quem fecha o ciclo chama
-- flush() (fim de batalha / unlock de conquista).
function ProfileStats.bump(key, n)
    local s = load()
    s.counters = s.counters or {}
    s.counters[key] = (s.counters[key] or 0) + (n or 1)
end

function ProfileStats.markSeen(cardId)
    if not cardId then return end
    local s = load()
    s.cardsSeen = s.cardsSeen or {}
    s.cardsSeen[cardId] = true
end

-- ===== Dicas do tutorial (Out/2026) =====
-- Cada dica aparece UMA vez por perfil. Marcar grava na hora (é raro: ~15
-- dicas na vida do jogador) — fechar o jogo logo depois não pode re-mostrar.
function ProfileStats.isTipSeen(id)
    local s = load()
    return s.tipsSeen ~= nil and s.tipsSeen[id] == true
end

function ProfileStats.markTipSeen(id)
    if not id then return end
    local s = load()
    s.tipsSeen = s.tipsSeen or {}
    if s.tipsSeen[id] then return end
    s.tipsSeen[id] = true
    save()
end

-- Configurações → Jogo → "Rever as dicas": esquece todas. Devolve quantas.
function ProfileStats.resetTips()
    local s = load()
    local n = 0
    for _ in pairs(s.tipsSeen or {}) do n = n + 1 end
    s.tipsSeen = {}
    save()
    return n
end

function ProfileStats.tipsSeenCount()
    local n = 0
    for _ in pairs(load().tipsSeen or {}) do n = n + 1 end
    return n
end

function ProfileStats.flush()
    save()
end

-- SÓ TESTES: troca o perfil em memória (nil = recarrega do disco no próximo
-- get). Devolve o anterior pra o teste restaurar. Nada vai pro disco
-- (save() já é no-op sob _G.HEADLESS_TOOL).
function ProfileStats._swapForTests(tbl)
    local prev = cache
    cache = tbl
    if tbl then
        tbl.achievements = tbl.achievements or {}
        tbl.counters = tbl.counters or {}
        tbl.cardsSeen = tbl.cardsSeen or {}
        tbl.winsByClass = tbl.winsByClass or {}
        tbl.tipsSeen = tbl.tipsSeen or {}
        for k, v in pairs(DEFAULTS) do
            if tbl[k] == nil and type(v) ~= "table" then tbl[k] = v end
        end
    end
    return prev
end

-- true se há qualquer histórico (menu decide se mostra a plaque de perfil).
function ProfileStats.hasHistory()
    return load().runs > 0
end

return ProfileStats
