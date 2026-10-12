-- src/systems/ComboSystem.lua
-- Detecta sinergias entre cartas jogadas no mesmo turno, gerando multiplicadores
-- e bonus que o EffectSystem aplica antes dos jokers.
--
-- Contrato:
--   ComboSystem.detect(turnContext) -> { combo1, combo2, ... }
--   Cada combo tem { id, rule, matches (lista de cartas) }
--   ComboSystem.applyToCardValue(card, baseValue, turnContext, targetType) -> novoValor
--     targetType e "attack" ou "defense". So aplica combos cujo bonus match.
--
-- RULES sao dataDRiven: adicionar novas regras e so acrescentar uma entrada.
-- Tipos de regra suportados:
--   "min_count_tag"   — N+ cartas com a tag
--   "pair_tags"       — cartas cobrindo todas as tags em `requires`
--
-- Tipos de bonus suportados:
--   "damage_multiplier"  — multiplica dano em ataques
--   "defense_multiplier" — multiplica defesa em defesas
--   "damage_bonus"       — soma dano fixo em ataques
--   "defense_bonus"      — soma defesa fixa em defesas
--   "apply_debuff"       — aplica debuff no inimigo apos resolver cartas
--   "heal"               — cura player

local TagSystem = require("src.systems.TagSystem")
local I18n = require("src.i18n.I18n")

-- Nome EXIBIDO do combo: i18n (combos.<id>) com rule.label de fallback — a
-- MESMA resolucao que src/ui/ComboBanner.lua ja fazia. Os toasts liam
-- combo.label direto e por isso saiam em PT dentro do feed traduzido.
local function comboName(combo)
    return I18n.t("combos." .. tostring(combo.id), nil,
        combo.label or tostring(combo.id))
end
local Sfx = require("src.systems.Sfx")

local ComboSystem = {}

-- Notifica a UI (banner de combo). Declarado no TOPO de proposito: local em
-- Lua so existe ABAIXO da definicao, e quem chama esta la embaixo. pcall
-- porque contextos headless (tools/testes sem canvas) nao tem UI — vira
-- no-op silencioso em vez de derrubar o combate.
local function notifyComboUI(combos)
    pcall(function()
        require("src.ui.ComboBanner").show(combos)
    end)
end

-- QUANDO O BANNER APARECE (v2, feedback do dono Set/2026: "so precisa
-- aparecer quando triggar o combo de fato").
--
-- Diagnostico: nunca foi o caso de aparecer sem combo — detect() so devolve
-- regra que casou, e announce() ja saia cedo com lista vazia. O que o dono
-- viu foi o banner subindo no ANUNCIO, junto do clique em "Jogar Cartas",
-- enquanto o efeito so acontece varios frames depois, quando a carta pousa e
-- o numero muda. Aparecia antes da propria causa.
--
-- Agora o banner sobe no IMPACTO: na primeira vez que um combo REALMENTE
-- altera alguma coisa. Duas portas, a que vier primeiro:
--   · applyToCardValue — o valor da carta mudou (dano/bloqueio maior);
--   · applyOnceEffects — turno so com combo de evento (cura/debuff/evoke),
--     em que nenhum valor de carta muda.
-- O guarda `_comboAnnounced` garante que so o turno de VERDADE dispara: o
-- piloto (tools/autoplay.lua) chama applyToCardValue com contexto sintetico
-- pra ESTIMAR dano, e estimativa nao e evento.
local function raiseComboBanner(turnContext)
    if not turnContext or not turnContext._comboAnnounced then return end
    if turnContext._comboBannerShown then return end
    turnContext._comboBannerShown = true
    notifyComboUI(turnContext.activeCombos)
end

-- ============================================================================
-- COMBO v3 — INTENCAO, NAO VOLUME (Out/2026)
-- ============================================================================
-- Queixa do dono: "o combo de muitas cartas da dano demais... vira
-- automatico: seleciona um milhao de cartas e pronto, nao precisa pensar".
-- A leva grande era SEMPRE a melhor porque o combo crescia mais rapido que o
-- numero de cartas (medido: tools/balance_sim, secao "Jogadas"):
--   * todo bonus valia pra TODA carta de ataque/defesa da leva, tivesse ela a
--     tag do combo ou nao;
--   * os multiplicadores de combo se MULTIPLICAVAM entre si
--     (x1.4 golpes * x1.3 remate * x1.5 arcano = x2.73, antes dos coringas);
--   * bonus planos (+6 do Triplo Golpe, +5 da Tempestade...) entravam UMA VEZ
--     POR CARTA — a 5a carta somava mais que a 2a.
-- Tres regras novas, as mesmas da camada de coringas (P0.9):
--   1. ALVO: o bonus vale so pras cartas que FORMAM o combo (`appliesTo`,
--      padrao = a tag da regra). "*" = qualquer carta do tipo certo.
--   2. MAIOR MULTIPLICADOR VENCE: numa carta, so o maior multiplicador de
--      combo conta; os outros nao compoem. Planos somam.
--   3. PLANO E POR LEVA (`once`): o bonus fixo entra UMA vez, na primeira
--      carta da leva que ele alcanca — premio de montar o combo, nao de
--      empilhar cartas.
-- Resultado: o dano cresce LINEAR com o numero de cartas; o que paga e
-- escolher QUAIS cartas vao juntas.
--
-- `id` e a chave i18n (combos.<id>); `label` e fallback.
ComboSystem.RULES = {
    -- v3: x1.4 -> x1.5. O x1.4 compunha com os outros multiplicadores e
    -- valia ate em carta sem a tag; sozinho e so nos golpes, x1.5 devolve o
    -- poder que a bateria mostrou perdido (warrior 40% -> 30% com x1.4).
    { id = "strike_combo",
      rule = "min_count_tag", tag = "strike", minCount = 2,
      bonus = { type = "damage_multiplier", value = 1.5 },
      label = "Combo de Ataques" },

    { id = "defend_wall",
      rule = "min_count_tag", tag = "defend", minCount = 2,
      bonus = { type = "defense_multiplier", value = 1.5 },
      label = "Muralha" },

    -- v3: +6 POR golpe (3 golpes = +18, 5 = +30) -> +10 uma vez por leva.
    { id = "triple_strike",
      rule = "min_count_tag", tag = "strike", minCount = 3,
      bonus = { type = "damage_bonus", value = 10, once = true },
      label = "Triplo Golpe" },

    -- v3: +6 por defesa -> +10 uma vez por leva.
    { id = "armor_tower",
      rule = "min_count_tag", tag = "armor", minCount = 2,
      bonus = { type = "defense_bonus", value = 10, once = true },
      label = "Torre de Armaduras" },

    -- Out/2026 (balanceamento de classe): +2 -> +4. Unico combo do eixo do
    -- ladino, e o veneno e o que escala contra a vida alta do A4-A6.
    { id = "poison_stack",
      rule = "min_count_tag", tag = "poison", minCount = 2,
      bonus = { type = "apply_debuff", debuff = "poison", stacks = 4, duration = 2 },
      label = "Veneno Concentrado" },

    { id = "channel_burst",
      rule = "min_count_tag", tag = "channel", minCount = 3,
      bonus = { type = "evoke_on_combo", value = 1 },
      label = "Explosao Arcana" },

    -- v3: +5 em todo ataque -> +6 no primeiro ataque da leva (as cartas de
    -- compra/descarte quase nunca sao ataques: o premio vai pro golpe).
    { id = "cycle_motion",
      rule = "pair_tags", requires = { "draw", "discard" },
      appliesTo = "*",
      bonus = { type = "damage_bonus", value = 6, once = true },
      label = "Em Movimento" },

    -- v3: x1.3 em todo ataque -> x1.6 so no REMATE (a carta finisher). Com
    -- o maior-vence, um x1.3 perderia sempre pro x1.5 do Combo de Ataques
    -- (todo finisher tambem e golpe) — o remate precisa valer mais pra que
    -- montar golpe + finisher seja uma decisao.
    { id = "finisher_chain",
      rule = "pair_tags", requires = { "strike", "finisher" },
      appliesTo = "finisher",
      bonus = { type = "damage_multiplier", value = 1.6 },
      label = "Remate" },

    { id = "lifesteal_burst",
      rule = "pair_tags", requires = { "strike", "lifesteal" },
      bonus = { type = "heal", value = 4 },
      label = "Ferida Vital" },

    { id = "magic_focus",
      rule = "min_count_tag", tag = "magic", minCount = 2,
      bonus = { type = "damage_multiplier", value = 1.5 },
      -- Rebalance v2 (Jul/2026, P1.1): label renomeado ('Foco Arcano' colidia
      -- com o nome da carta mage_arcane_focus).
      label = "Convergencia Arcana" },

    -- v3: +6 em toda defesa -> +6 uma vez, na carta de espinhos.
    { id = "thorn_reflex",
      rule = "pair_tags", requires = { "defend", "thorn" },
      appliesTo = "thorn",
      bonus = { type = "defense_bonus", value = 6, once = true },
      label = "Reflexos Espinhados" },

    -- Rebalance v2 (Jul/2026, P1.3): combos elementais — payoff das tags
    -- lightning/ice pro Canalizador do mago. v3: +5 por ataque -> +6 uma vez.
    { id = "tempestade",
      rule = "min_count_tag", tag = "lightning", minCount = 2,
      appliesTo = "*",
      bonus = { type = "damage_bonus", value = 6, once = true },
      label = "Tempestade" },

    -- Nao ha DEFESA com tag ice no catalogo: o Bloqueio vai pra primeira
    -- defesa da leva ("*"), como antes ia pra todas.
    { id = "zero_absoluto",
      rule = "min_count_tag", tag = "ice", minCount = 2,
      appliesTo = "*",
      bonus = { type = "defense_bonus", value = 6, once = true },
      label = "Zero Absoluto" },
}

-- Avalia se uma regra dispara dado um turnContext (com tagCounts).
local function ruleMatches(rule, turnContext)
    if rule.rule == "min_count_tag" then
        local count = (turnContext.tagCounts and turnContext.tagCounts[rule.tag]) or 0
        return count >= (rule.minCount or 2)
    elseif rule.rule == "pair_tags" then
        -- Balance v2 (Jul/2026): as tags precisam vir de CARTAS DISTINTAS.
        -- Antes, uma carta com strike+finisher se auto-combinava ×1.3
        -- sozinha (todo finisher tinha premium fantasma embutido).
        local req = rule.requires or {}
        local snapshot = turnContext.allSelectedCards or turnContext.snapshot or {}
        local TagSystem = require("src.systems.TagSystem")
        -- tenta uma atribuição: para cada tag exigida, uma carta diferente.
        local function assign(tagIdx, usedCards)
            if tagIdx > #req then return true end
            for ci, card in ipairs(snapshot) do
                if not usedCards[ci]
                    and TagSystem.cardHasTag(card, req[tagIdx]) then
                    usedCards[ci] = true
                    if assign(tagIdx + 1, usedCards) then return true end
                    usedCards[ci] = nil
                end
            end
            return false
        end
        return assign(1, {})
    end
    return false
end

-- Detecta combos ativos dado um turnContext. Retorna lista de { id, rule, bonus, label }.
-- Efeito colateral: anexa em turnContext.activeCombos (idempotente se chamado 2x).
function ComboSystem.detect(turnContext)
    turnContext.activeCombos = turnContext.activeCombos or {}
    if not turnContext.tagCounts then return turnContext.activeCombos end
    -- Limpa deteccao anterior se for re-chamada
    for i = #turnContext.activeCombos, 1, -1 do
        turnContext.activeCombos[i] = nil
    end
    for _, rule in ipairs(ComboSystem.RULES) do
        if ruleMatches(rule, turnContext) then
            table.insert(turnContext.activeCombos, rule)
        end
    end
    return turnContext.activeCombos
end

-- Aplica combos de valor (damage_*/defense_*) sobre um valor base para uma carta.
-- Chamado pelo Game:processCardInCombat depois do applyCardEffects e ANTES dos jokers.
-- Isso garante que jokers com multiplicador multipliquem o valor ja potencializado.
-- Tags que a CARTA precisa ter pro bonus valer nela (combo v3).
-- nil = qualquer carta do tipo certo.
local function targetTags(rule)
    if rule.appliesTo == "*" then return nil end
    if rule.appliesTo then
        return type(rule.appliesTo) == "table" and rule.appliesTo or { rule.appliesTo }
    end
    if rule.tag then return { rule.tag } end
    return rule.requires   -- par sem alvo declarado: qualquer tag do par
end

-- O tipo de carta que o bonus alcanca (dano -> ataque, defesa -> defesa).
local BONUS_CARD_TYPE = {
    damage_multiplier = "attack", damage_bonus = "attack",
    defense_multiplier = "defense", defense_bonus = "defense",
}

-- A carta FORMA o combo `rule`? (tipo certo + tag do alvo)
function ComboSystem.cardIsTarget(rule, card)
    local b = rule.bonus or {}
    if not card or BONUS_CARD_TYPE[b.type] ~= card.type then return false end
    local tags = targetTags(rule)
    if not tags then return true end
    for _, tag in ipairs(tags) do
        if TagSystem.cardHasTag(card, tag) then return true end
    end
    return false
end

-- Bonus `once`: so a PRIMEIRA carta-alvo da leva (ordem de resolucao).
local function isFirstTarget(rule, card, turnContext)
    for _, c in ipairs(turnContext.allSelectedCards or {}) do
        if ComboSystem.cardIsTarget(rule, c) then return c == card end
    end
    return true
end

-- Versao PURA (sem banner): devolve (valor, passos). `passos` e a lista de
-- { combo, op = "mult"|"add", value, after } que a previa de dano
-- (src/systems/DamagePreview.lua) mostra ao jogador — a MESMA conta que o
-- combate faz, entao previa == resultado por construcao.
-- Ordem: o MAIOR multiplicador de combo da carta (so ele) e depois os planos
-- (plano nao e multiplicado: +8 e +8).
function ComboSystem.cardSteps(card, baseValue, turnContext)
    local steps = {}
    if not turnContext or not turnContext.activeCombos then return baseValue, steps end
    local bestMult, adds = nil, {}
    for _, combo in ipairs(turnContext.activeCombos) do
        local b = combo.bonus
        if b and ComboSystem.cardIsTarget(combo, card) then
            if b.type == "damage_multiplier" or b.type == "defense_multiplier" then
                if not bestMult or (b.value or 1) > (bestMult.bonus.value or 1) then
                    bestMult = combo
                end
            elseif (b.type == "damage_bonus" or b.type == "defense_bonus")
                and (not b.once or isFirstTarget(combo, card, turnContext)) then
                adds[#adds + 1] = combo
            end
        end
    end
    local v = baseValue
    if bestMult then
        v = v * (bestMult.bonus.value or 1)
        steps[#steps + 1] = { combo = bestMult, op = "mult",
            value = bestMult.bonus.value or 1, after = v }
    end
    for _, combo in ipairs(adds) do
        v = v + (combo.bonus.value or 0)
        steps[#steps + 1] = { combo = combo, op = "add",
            value = combo.bonus.value or 0, after = v }
    end
    return v, steps
end

-- Porta do banner pra quem calcula pela versao pura (Game via DamagePreview).
ComboSystem.raiseBanner = raiseComboBanner

function ComboSystem.applyToCardValue(card, baseValue, turnContext)
    local v = ComboSystem.cardSteps(card, baseValue, turnContext)
    -- causa e efeito: o banner sobe no exato momento em que o numero sobe
    if v ~= baseValue then raiseComboBanner(turnContext) end
    return v
end

-- Aplica combos de EVENTO (debuff/heal/evoke) uma unica vez por turno (chamado
-- apos todas as cartas do turno ja terem sido processadas). turnContext carrega
-- activeCombos; game e usado para efeitos colaterais.
function ComboSystem.applyOnceEffects(game, turnContext)
    if not turnContext or not turnContext.activeCombos then return end
    -- rede de seguranca: turno cujos combos sao SO de evento (cura/debuff/
    -- evoke) nunca passa por applyToCardValue com mudanca — o banner sobe aqui
    raiseComboBanner(turnContext)
    for _, combo in ipairs(turnContext.activeCombos) do
        local b = combo.bonus
        if b then
            if b.type == "apply_debuff" and game.enemy then
                game.enemy:addStatusEffect({
                    name = b.debuff or "poison",
                    stacks = b.stacks or 1,
                    duration = b.duration or 2,
                })
                game:addMessage(I18n.t("messages.combo_debuff", {
                    combo = comboName(combo), stacks = b.stacks or 1,
                    name = b.debuff or "debuff" }), "warning")
            elseif b.type == "heal" and game.player then
                -- P2.5 (Jul/2026, rebalance v2): heal de combo roteia pelo
                -- heal_multiplier (com floor via P2.4) — sem isso Calice do
                -- Sabio/dark_embrace nao amplificavam o lifesteal_burst.
                local amount = b.value or 0
                if game.effectSystem and game.effectSystem.applyHealMultiplier then
                    amount = game.effectSystem:applyHealMultiplier(game, amount)
                end
                game.player:heal(amount)
                game:addMessage(I18n.t("messages.combo_heal", {
                    combo = comboName(combo), value = amount }), "success")
            elseif b.type == "evoke_on_combo" then
                -- Evoca 1 orb extra ao fim do turno
                local orb = game.player:popOldestOrb()
                if orb and game.effectSystem then
                    game.effectSystem:_evokeOrbEffect(game, orb)
                    game:addMessage(I18n.t("messages.combo_orb", {
                        combo = comboName(combo) }), "success")
                end
            end
        end
    end
end

-- Anuncio dos combos detectados. Chamado por Game:playSelectedCards uma vez,
-- no momento do clique — ANTES das cartas voarem. Aqui saem o log (historico
-- no feed lateral) e o som. O BANNER (src/ui/ComboBanner.lua) sai depois, no
-- impacto, por raiseComboBanner — ver a nota la em cima.
function ComboSystem.announce(game, turnContext)
    if not turnContext.activeCombos or #turnContext.activeCombos == 0 then return end
    for _, combo in ipairs(turnContext.activeCombos) do
        game:addMessage(I18n.t("messages.combo_announce", {
            combo = comboName(combo) }), "success")
    end
    -- marca o turno como REAL (ver raiseComboBanner) — o banner nao sobe
    -- aqui: espera o combo mexer no numero, la no impacto da carta.
    turnContext._comboAnnounced = true
    Sfx.play("comboTrigger")
end

return ComboSystem
