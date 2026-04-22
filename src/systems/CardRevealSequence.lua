-- src/systems/CardRevealSequence.lua
-- Orquestrador genérico do "booster pack opening" do Balatro. Pipeline:
--
--   1. Source card explode (dissolve + partículas + shake + sfx)
--   2. Result cards aparecem na posição da source card com dissolve=1
--   3. Cada result card start_materialize em cascata (80ms entre elas)
--   4. Result cards fluem pra suas posições finais (via targetX/Y da Card)
--   5. Callback final
--
-- ARQUITETURA: Inspirado em card.lua:Card:open do Balatro (linhas 1681-1794),
-- mas desacoplado de mecânica de pack — funciona pra qualquer "source produz
-- N resultados com animação". Casos de uso:
--   - Booster pack opening (futuro)
--   - Shop: comprou carta → aparece com reveal (hoje é instantâneo)
--   - Event: ganhou carta aleatória de recompensa
--   - Forge: upgrade de carta (carta velha dissolve, nova materializa)
--
-- USO:
--   local CardRevealSequence = require("src.systems.CardRevealSequence")
--   CardRevealSequence.run({
--       sourceCard = mysteryPackCard,  -- carta que vai explodir
--       resultCards = {card1, card2, card3},  -- já instanciadas mas invisíveis
--       layoutPositions = {  -- posições finais das resultCards
--           {x=300, y=400}, {x=420, y=400}, {x=540, y=400}
--       },
--       onComplete = function() print("opened!") end,
--       -- opcionais
--       explodeDelay = 0.4,       -- tempo até source explodir (default 0.4s)
--       cascadeInterval = 0.08,   -- gap entre materialize de cada result
--       flowDelay = 0.3,          -- quanto tempo esperar antes de fluir pro layout
-- })
--
-- REQUER:
--   - sourceCard e resultCards devem ser instâncias de src/cards/base/Card.lua
--   - EventManager inicializado
--   - DissolveShader carregado (opcional, fallback gracioso)

local CardRevealSequence = {}

-- Estado de sequências ativas (apenas diagnóstico; EventManager é quem roda).
local activeCount = 0

-- Executa a sequência completa. Retorna false se setup inválido.
function CardRevealSequence.run(config)
    assert(config, "CardRevealSequence.run requer config")
    local sourceCard = config.sourceCard
    local resultCards = config.resultCards or {}
    local layoutPositions = config.layoutPositions or {}
    assert(sourceCard, "sourceCard é obrigatório")

    local EM = _G.EventManager
    local Ev = _G.Event
    if not EM or not Ev then
        print("[CardRevealSequence] EventManager não disponível — sequência pulada")
        if config.onComplete then config.onComplete() end
        return false
    end

    local explodeDelay = config.explodeDelay or 0.4
    local cascadeInterval = config.cascadeInterval or 0.08
    local flowDelay = config.flowDelay or 0.3
    local explodeDuration = 1.3 -- default do Card:explode

    -- Fase 0: delay inicial (pack "carrega") antes do boom
    EM.after(explodeDelay, function()
        sourceCard:explode(nil, 1.0)
    end)

    -- Fase 1: enquanto source explode, prepara result cards na posição da source.
    -- Setamos dissolve=1 pra que apareçam queimadas; start_materialize reverte.
    local spawnAt = explodeDelay + 0.5 -- ~meio do explode (efeito de saída)
    for idx, card in ipairs(resultCards) do
        card.dissolve = 1
        card.x = sourceCard.x or 0
        card.y = sourceCard.y or 0
        if card.setRenderPos then
            card:setRenderPos(sourceCard.x or 0, sourceCard.y or 0)
        end

        -- Materialize escalonado: cada carta aparece cascadeInterval depois
        local materializeDelay = spawnAt + (idx - 1) * cascadeInterval
        EM.after(materializeDelay, function()
            card:start_materialize(nil, false, 1.0)
        end)
    end

    -- Fase 2: flow — cartas voam pros layoutPositions após materialize
    local flowAt = spawnAt + explodeDuration * 0.5 + flowDelay
    for idx, card in ipairs(resultCards) do
        local pos = layoutPositions[idx]
        if pos and card.setTargetPos then
            EM.after(flowAt + (idx - 1) * 0.04, function()
                card:setTargetPos(pos.x, pos.y)
                -- Juice sutil pra marcar "cheguei"
                if card.juice_up then card:juice_up(0.1, 0.03) end
            end)
        end
    end

    -- Fase 3: callback final
    local totalDuration = flowAt + #resultCards * 0.04 + 0.5
    EM.after(totalDuration, function()
        activeCount = math.max(0, activeCount - 1)
        if config.onComplete then config.onComplete() end
    end)

    activeCount = activeCount + 1
    return true
end

-- Versão mini: só materializa um conjunto de cartas numa área (sem source).
-- Útil pra "cartas aparecem na tela de reward" com fade-in.
function CardRevealSequence.materializeMany(cards, layoutPositions, onComplete, cascadeInterval)
    local EM = _G.EventManager
    if not EM then
        if onComplete then onComplete() end
        return false
    end

    cascadeInterval = cascadeInterval or 0.1

    for idx, card in ipairs(cards) do
        local pos = layoutPositions and layoutPositions[idx]
        if pos then
            card.x = pos.x
            card.y = pos.y
            if card.setRenderPos then card:setRenderPos(pos.x, pos.y) end
        end
        card.dissolve = 1
        EM.after((idx - 1) * cascadeInterval, function()
            card:start_materialize(nil, idx > 1) -- só primeira toca som
        end)
    end

    local total = #cards * cascadeInterval + 0.8
    EM.after(total, function()
        if onComplete then onComplete() end
    end)
    return true
end

-- Versão inversa: dissolve um conjunto de cartas (ex: sell all, clear hand).
function CardRevealSequence.dissolveMany(cards, onComplete, cascadeInterval, colours)
    local EM = _G.EventManager
    if not EM then
        if onComplete then onComplete() end
        return false
    end
    cascadeInterval = cascadeInterval or 0.06

    for idx, card in ipairs(cards) do
        EM.after((idx - 1) * cascadeInterval, function()
            card:start_dissolve(colours, idx > 1) -- só primeira toca som
        end)
    end

    local total = #cards * cascadeInterval + 1.0
    EM.after(total, function()
        if onComplete then onComplete() end
    end)
    return true
end

-- Diagnóstico
function CardRevealSequence.activeCount()
    return activeCount
end

return CardRevealSequence
