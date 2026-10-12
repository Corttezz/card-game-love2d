-- src/systems/ComboSystem.lua
-- COMBOS SIMPLES (Out/2026, decisão do dono): "combos no geral estão MUITO
-- fortes, de defesa e de ataque, e não são explicados — o jogador só joga
-- carta e combo sem saber. Tira e põe combos mais SIMPLES: quanto mais cartas
-- de ataque, mais o bônus sobe; o mesmo pra defesa; carta igual vale mais;
-- coringas de combo também."
--
-- Saem as 13 regras por TAG (Combo de Ataques, Remate, Convergência Arcana...)
-- — ninguém sabia que tag cada carta tinha. Ficam TRÊS regras que se leem na
-- própria mão, sem lógica escondida:
--
--   SARAIVADA (volley) — cada carta de ATAQUE depois da primeira, na mesma
--     jogada, ganha +step por ataque anterior (2º +2, 3º +4, 4º+ +6).
--   MURALHA (wall)     — o mesmo para cartas de DEFESA, em Bloqueio.
--   PAR (pair)         — cada CÓPIA repetida da mesma carta na jogada ganha
--     +value por cópia anterior (2ª cópia +3, 3ª +6).
--
-- Tudo é bônus PLANO, somado depois da Força e ANTES dos coringas (o
-- multiplicador de coringa multiplica a carta já com o bônus). Carta com a tag
-- `combo` (Golpe Rápido, Estilete...) conta como DUAS cartas na fila da
-- Saraivada/Muralha. Coringas de combo (`combo_boost`) dobram uma das regras.
--
-- Contrato (o mesmo de antes — Game, DamagePreview, piloto, tutorial e Guia
-- leem daqui):
--   ComboSystem.detect(turnContext, game?)          -> activeCombos
--   ComboSystem.cardSteps(card, value, ctx, game?)  -> valor, passos  (PURO)
--   ComboSystem.applyToCardValue(card, value, ctx)  -> valor (+ banner)
--   ComboSystem.applyOnceEffects / announce          (banner + som)
--   ComboSystem.RULES — a lista das 3 regras (Guia de combos, i18n)

local TagSystem = require("src.systems.TagSystem")
local Sfx = require("src.systems.Sfx")

local ComboSystem = {}

-- Notifica a UI (banner de combo). pcall: headless (tools/testes) não tem UI.
local function notifyComboUI(combos)
    pcall(function()
        require("src.ui.ComboBanner").show(combos)
    end)
end

-- O banner sobe no IMPACTO (primeira vez que um combo muda um número), não no
-- clique — e só no turno de verdade (`_comboAnnounced`): o piloto estima dano
-- com contexto sintético, e estimativa não é evento.
local function raiseComboBanner(turnContext)
    if not turnContext or not turnContext._comboAnnounced then return end
    if turnContext._comboBannerShown then return end
    turnContext._comboBannerShown = true
    notifyComboUI(turnContext.activeCombos)
end
ComboSystem.raiseBanner = raiseComboBanner

-- ============================================================================
-- As três regras (dados) — números escolhidos pela bateria (memory/combo_rules.md)
-- ============================================================================
-- `kind` = tipo de carta que a regra alcança; `step` = bônus por carta anterior
-- na fila; `cap` = teto de cartas anteriores contadas (o bônus para de subir).
-- `tag` só ilustra o Guia de combos (exemplos de carta), não decide nada.
ComboSystem.RULES = {
    { id = "volley", kind = "attack",  step = 2, cap = 3, tag = "strike",
      bonusType = "damage_bonus",  label = "Saraivada" },
    { id = "wall",   kind = "defense", step = 2, cap = 3, tag = "defend",
      bonusType = "defense_bonus", label = "Muralha" },
    { id = "pair",   kind = "same",    step = 3, cap = 2,
      bonusType = "card_bonus",    label = "Par" },
}

local RULE_BY_ID = {}
for _, r in ipairs(ComboSystem.RULES) do RULE_BY_ID[r.id] = r end
ComboSystem.RULE_BY_ID = RULE_BY_ID

-- Quanto a carta "pesa" na fila da Saraivada/Muralha (tag `combo` = 2).
local function queueWeight(card)
    return TagSystem.cardHasTag(card, "combo") and 2 or 1
end

-- Multiplicador dos coringas de combo sobre uma regra (combo_boost).
-- Maior vence, como todo multiplicador de coringa (P0.9).
function ComboSystem.boostFor(game, ruleId)
    local best = 1
    for _, joker in ipairs((game and game.jokerSlots) or {}) do
        for _, e in ipairs(joker.effects or {}) do
            if e.type == "combo_boost" and e.combo == ruleId and (e.value or 1) > best then
                best = e.value or 1
            end
        end
    end
    return best
end

-- Bônus de UMA regra numa carta, dado o contexto da jogada. Devolve 0 quando a
-- regra não alcança a carta. `cards` = a jogada em ordem de resolução.
local function ruleBonusFor(rule, card, cards, game)
    if not card then return 0 end
    local before = 0
    if rule.kind == "same" then
        if card.type ~= "attack" and card.type ~= "defense" then return 0 end
        for _, c in ipairs(cards) do
            if c == card then break end
            if c.id and c.id == card.id then before = before + 1 end
        end
    else
        if card.type ~= rule.kind then return 0 end
        for _, c in ipairs(cards) do
            if c == card then break end
            if c.type == rule.kind then before = before + queueWeight(c) end
        end
    end
    if before <= 0 then return 0 end
    local b = rule.step * math.min(before, rule.cap)
    return math.floor(b * ComboSystem.boostFor(game, rule.id))
end
ComboSystem.ruleBonusFor = ruleBonusFor

local function playOf(turnContext)
    return (turnContext and (turnContext.allSelectedCards or turnContext.snapshot)) or {}
end

-- Combos que a jogada dispara (para banner, prévia, pontuação, conquistas).
-- Cada entrada = a regra + `bonus` { type, value = soma dos bônus da jogada }.
function ComboSystem.detect(turnContext, game)
    turnContext.activeCombos = turnContext.activeCombos or {}
    for i = #turnContext.activeCombos, 1, -1 do turnContext.activeCombos[i] = nil end
    game = game or turnContext.game
    local cards = playOf(turnContext)
    for _, rule in ipairs(ComboSystem.RULES) do
        local total = 0
        for _, c in ipairs(cards) do total = total + ruleBonusFor(rule, c, cards, game) end
        if total > 0 then
            table.insert(turnContext.activeCombos, {
                id = rule.id, label = rule.label, rule = rule,
                bonus = { type = rule.bonusType, value = total },
            })
        end
    end
    return turnContext.activeCombos
end

-- Versão PURA: (valor, passos). Passo = { combo, op = "add", value, after }.
-- A prévia de dano (DamagePreview) mostra estes passos como fichas — a MESMA
-- conta do combate.
function ComboSystem.cardSteps(card, baseValue, turnContext, game)
    local steps = {}
    if not turnContext then return baseValue, steps end
    game = game or turnContext.game
    local cards = playOf(turnContext)
    local v = baseValue
    for _, rule in ipairs(ComboSystem.RULES) do
        local b = ruleBonusFor(rule, card, cards, game)
        if b > 0 then
            v = v + b
            steps[#steps + 1] = { combo = rule, op = "add", value = b, after = v }
        end
    end
    return v, steps
end

function ComboSystem.applyToCardValue(card, baseValue, turnContext)
    local v = ComboSystem.cardSteps(card, baseValue, turnContext)
    if v ~= baseValue then raiseComboBanner(turnContext) end
    return v
end

-- Os combos simples não têm prêmio de fim de jogada (debuff/cura/evoke saíram
-- com as regras por tag). Mantido pelo contrato: o banner sobe aqui se a
-- jogada tiver combo e nenhum número tiver mudado antes.
function ComboSystem.applyOnceEffects(_game, turnContext)
    if not turnContext or not turnContext.activeCombos then return end
    if #turnContext.activeCombos > 0 then raiseComboBanner(turnContext) end
end

-- Anúncio no clique: só o som (o banner diz o nome, no impacto).
function ComboSystem.announce(_game, turnContext)
    if not turnContext.activeCombos or #turnContext.activeCombos == 0 then return end
    turnContext._comboAnnounced = true
    Sfx.play("comboTrigger")
end

return ComboSystem
