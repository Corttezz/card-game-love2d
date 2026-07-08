-- src/systems/TagSystem.lua
-- Catalogo canonico de tags + helpers para deteccao de combos/sinergias.
--
-- Contrato:
--   Toda carta pode ter um array card.tags = {"strike", "finisher"}.
--   Tags sao strings sem prefixo "#" (o prefixo so aparece em UI/docs).
--   getCardTags(card) normaliza: le card.tags, deriva tags implicitas do tipo
--   (attack->"strike", defense->"defend", joker->"passive", effect->"utility"),
--   e garante array sem duplicados.
--
-- O CATALOG e a unica fonte de verdade das tags validas: se uma carta usar uma
-- tag fora do catalogo, um warning e logado via Debug.warn. Isso evita typos
-- silenciosos que quebrariam ComboSystem.

local TagSystem = {}

-- Categorias ajudam a filtragem e cores em UI (pilulas coloridas no card).
-- Toda tag nova DEVE ser adicionada aqui antes de ser usada em dados de carta.
TagSystem.CATALOG = {
    -- Arquetipos basicos (derivados do tipo, sempre presentes)
    strike     = { category = "archetype", color = {0.85, 0.30, 0.25}, desc = "Ataque fisico" },
    defend     = { category = "archetype", color = {0.30, 0.55, 0.85}, desc = "Defesa/armor" },
    passive    = { category = "archetype", color = {0.90, 0.75, 0.20}, desc = "Joker passivo" },
    utility    = { category = "archetype", color = {0.45, 0.80, 0.50}, desc = "Efeito/utility" },

    -- Mecanicas (status, recursos)
    armor       = { category = "mechanic",  color = {0.55, 0.65, 0.75}, desc = "Empilha armor" },
    poison      = { category = "mechanic",  color = {0.40, 0.75, 0.30}, desc = "Aplica veneno" },
    weak        = { category = "mechanic",  color = {0.60, 0.50, 0.80}, desc = "Debuff weak" },
    vulnerable  = { category = "mechanic",  color = {0.80, 0.50, 0.60}, desc = "Debuff vulnerable" },
    strength    = { category = "mechanic",  color = {0.85, 0.45, 0.25}, desc = "Ganha/usa strength" },
    dexterity   = { category = "mechanic",  color = {0.50, 0.70, 0.50}, desc = "Ganha/usa dexterity" },
    channel     = { category = "mechanic",  color = {0.40, 0.60, 0.90}, desc = "Canaliza orb" },
    evoke       = { category = "mechanic",  color = {0.50, 0.30, 0.70}, desc = "Evoca orb" },
    exhaust     = { category = "mechanic",  color = {0.55, 0.40, 0.55}, desc = "Exaurir (remove da run)" },
    innate      = { category = "mechanic",  color = {0.75, 0.75, 0.40}, desc = "Comeca na mao" },
    retain      = { category = "mechanic",  color = {0.75, 0.60, 0.30}, desc = "Nao descarta no fim do turno" },
    draw        = { category = "mechanic",  color = {0.60, 0.85, 0.85}, desc = "Compra cartas" },
    discard     = { category = "mechanic",  color = {0.65, 0.55, 0.45}, desc = "Descarta cartas" },
    heal        = { category = "mechanic",  color = {0.90, 0.55, 0.70}, desc = "Cura" },
    lifesteal   = { category = "mechanic",  color = {0.70, 0.20, 0.30}, desc = "Cura ao atacar" },
    thorn       = { category = "mechanic",  color = {0.50, 0.50, 0.60}, desc = "Reflete dano" },
    aoe         = { category = "mechanic",  color = {0.85, 0.65, 0.35}, desc = "Dano em area" },
    mana        = { category = "mechanic",  color = {0.30, 0.45, 0.90}, desc = "Interage com mana" },
    debuff      = { category = "mechanic",  color = {0.70, 0.40, 0.65}, desc = "Aplica debuff generico" },
    potion      = { category = "mechanic",  color = {0.85, 0.40, 0.85}, desc = "Pocao/consumivel" },

    -- Elementos (mago/efeitos)
    fire        = { category = "element",   color = {0.95, 0.45, 0.15}, desc = "Fogo" },
    ice         = { category = "element",   color = {0.55, 0.80, 0.95}, desc = "Gelo" },
    lightning   = { category = "element",   color = {0.95, 0.85, 0.25}, desc = "Raio" },
    dark        = { category = "element",   color = {0.30, 0.20, 0.45}, desc = "Sombra" },
    holy        = { category = "element",   color = {0.95, 0.90, 0.65}, desc = "Luz" },
    magic       = { category = "element",   color = {0.60, 0.40, 0.85}, desc = "Magia generica" },

    -- Arquetipos avancados (role semantico em uma build)
    finisher    = { category = "role",      color = {0.90, 0.20, 0.30}, desc = "Carta de remate" },
    starter     = { category = "role",      color = {0.55, 0.85, 0.55}, desc = "Carta inicial" },
    combo       = { category = "role",      color = {0.85, 0.70, 0.40}, desc = "Peca de combo" },
    cycle       = { category = "role",      color = {0.70, 0.85, 0.55}, desc = "Parte de motor draw/discard" },
    scaling     = { category = "role",      color = {0.80, 0.50, 0.25}, desc = "Escala com estado" },
    zero_cost   = { category = "role",      color = {0.60, 0.60, 0.60}, desc = "Custo zero" },
}

-- Derivacao implicita por tipo de carta.
-- Usada quando card.tags e nil/vazio.
local IMPLICIT_BY_TYPE = {
    attack  = "strike",
    defense = "defend",
    joker   = "passive",
    effect  = "utility",
}

-- Retorna a tag implicita para um tipo de carta (ou nil).
function TagSystem.implicitTagFor(cardType)
    return IMPLICIT_BY_TYPE[cardType]
end

-- Valida uma tag contra o catalogo. Retorna true se valida, false+log se nao.
function TagSystem.isValid(tag)
    if not TagSystem.CATALOG[tag] then
        print("[TagSystem] tag desconhecida: " .. tostring(tag))
        return false
    end
    return true
end

-- Normaliza tags de uma carta: le card.tags (ou {}), adiciona a implicita do tipo,
-- remove duplicados, valida contra catalogo.
-- Retorna array novo (nao muta a carta).
function TagSystem.getCardTags(card)
    local out = {}
    local seen = {}

    local implicit = IMPLICIT_BY_TYPE[card.type]
    if implicit then
        table.insert(out, implicit)
        seen[implicit] = true
    end

    if card.tags and type(card.tags) == "table" then
        for _, tag in ipairs(card.tags) do
            if type(tag) == "string" and not seen[tag] then
                -- Aceita com ou sem "#" no dado fonte; normaliza sem prefixo
                local clean = tag:gsub("^#", "")
                if not seen[clean] then
                    TagSystem.isValid(clean) -- loga warning se invalida
                    table.insert(out, clean)
                    seen[clean] = true
                end
            end
        end
    end

    return out
end

-- Conta ocorrencias de uma tag especifica em uma lista de cartas.
function TagSystem.countTagInCards(cards, tag)
    if not cards or not tag then return 0 end
    local count = 0
    local clean = tag:gsub("^#", "")
    for _, card in ipairs(cards) do
        local tags = TagSystem.getCardTags(card)
        for _, t in ipairs(tags) do
            if t == clean then
                count = count + 1
                break
            end
        end
    end
    return count
end

-- Conta TODAS as tags em uma lista de cartas. Retorna {[tag]=n}.
function TagSystem.countAllTags(cards)
    local counts = {}
    if not cards then return counts end
    for _, card in ipairs(cards) do
        local tags = TagSystem.getCardTags(card)
        -- F5 gameplay-overhaul: tag "combo" (Combo-starter) faz as DEMAIS
        -- tags da carta contarem em DOBRO pras regras do ComboSystem —
        -- antes era decorativa (a auditoria pegou "não faz nada").
        local weight = 1
        for _, tag in ipairs(tags) do
            if tag == "combo" then weight = 2 break end
        end
        for _, tag in ipairs(tags) do
            if tag ~= "combo" then
                counts[tag] = (counts[tag] or 0) + weight
            end
        end
    end
    return counts
end

-- Verifica se uma carta tem uma tag especifica.
function TagSystem.cardHasTag(card, tag)
    local clean = tag:gsub("^#", "")
    for _, t in ipairs(TagSystem.getCardTags(card)) do
        if t == clean then return true end
    end
    return false
end

-- Verifica se uma carta tem QUALQUER uma das tags passadas (OR).
function TagSystem.cardHasAnyTag(card, tags)
    for _, tag in ipairs(tags) do
        if TagSystem.cardHasTag(card, tag) then return true end
    end
    return false
end

-- Verifica se uma carta tem TODAS as tags passadas (AND).
function TagSystem.cardHasAllTags(card, tags)
    for _, tag in ipairs(tags) do
        if not TagSystem.cardHasTag(card, tag) then return false end
    end
    return true
end

-- Retorna os metadados de uma tag (cor, categoria, desc). Fallback se desconhecida.
function TagSystem.getTagInfo(tag)
    local clean = tag:gsub("^#", "")
    return TagSystem.CATALOG[clean] or {
        category = "unknown",
        color = {0.5, 0.5, 0.5},
        desc = clean,
    }
end

-- Lista todas as tags por categoria (util para UI de filtragem/colecao).
function TagSystem.listByCategory(category)
    local out = {}
    for tag, info in pairs(TagSystem.CATALOG) do
        if info.category == category then
            table.insert(out, tag)
        end
    end
    table.sort(out)
    return out
end

return TagSystem
