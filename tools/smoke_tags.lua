-- tools/smoke_tags.lua
-- Smoke test isolado do TagSystem. Roda via: love . smoke_tags
-- Valida: derivacao implicita, merge, normalizacao, contagem, validacao.

local TagSystem = require("src.systems.TagSystem")

local M = {}

function M.run()
    local fail = 0
    local pass = 0

    local function check(name, cond)
        if cond then
            pass = pass + 1
            print("  [ok] " .. name)
        else
            fail = fail + 1
            print("  [FAIL] " .. name)
        end
    end

    print("---- TagSystem smoke test ----")

    -- 1. Derivacao implicita por tipo
    local c1 = { type = "attack" }
    local t1 = TagSystem.getCardTags(c1)
    check("attack sem tags recebe 'strike' implicito", t1[1] == "strike" and #t1 == 1)

    local c1b = { type = "defense" }
    local t1b = TagSystem.getCardTags(c1b)
    check("defense sem tags recebe 'defend' implicito", t1b[1] == "defend")

    local c1c = { type = "joker" }
    local t1c = TagSystem.getCardTags(c1c)
    check("joker recebe 'passive' implicito", t1c[1] == "passive")

    -- 2. Tags explicitas + implicita (sem duplicar)
    local c2 = { type = "attack", tags = { "strike", "poison", "finisher" } }
    local t2 = TagSystem.getCardTags(c2)
    check("strike explicito nao duplica", #t2 == 3)
    check("poison e finisher preservados", t2[2] == "poison" and t2[3] == "finisher")

    -- 3. Prefixo "#" aceito na fonte
    local c3 = { type = "attack", tags = { "#poison" } }
    local t3 = TagSystem.getCardTags(c3)
    check("prefixo # e removido na normalizacao", t3[2] == "poison")

    -- 4. Contagem agregada
    local cards = {
        { type = "attack" },
        { type = "attack", tags = { "poison" } },
        { type = "defense" },
        { type = "defense", tags = { "armor" } },
    }
    local counts = TagSystem.countAllTags(cards)
    check("2 strikes contados", counts.strike == 2)
    check("2 defends contados", counts.defend == 2)
    check("1 poison contado", counts.poison == 1)
    check("1 armor contado", counts.armor == 1)

    -- 5. countTagInCards (por tag especifica)
    check("countTagInCards(strike)==2", TagSystem.countTagInCards(cards, "strike") == 2)
    check("countTagInCards(#poison) aceita prefixo", TagSystem.countTagInCards(cards, "#poison") == 1)
    check("countTagInCards(ausente)==0", TagSystem.countTagInCards(cards, "zero_cost") == 0)

    -- 6. cardHasTag / cardHasAnyTag / cardHasAllTags
    local c6 = { type = "attack", tags = { "poison", "finisher" } }
    check("cardHasTag encontra poison", TagSystem.cardHasTag(c6, "poison"))
    check("cardHasTag encontra strike (implicito)", TagSystem.cardHasTag(c6, "strike"))
    check("cardHasTag retorna false para ausente", not TagSystem.cardHasTag(c6, "armor"))
    check("cardHasAnyTag com OR", TagSystem.cardHasAnyTag(c6, { "armor", "poison" }))
    check("cardHasAllTags com AND", TagSystem.cardHasAllTags(c6, { "strike", "poison", "finisher" }))
    check("cardHasAllTags falha se uma falta", not TagSystem.cardHasAllTags(c6, { "strike", "armor" }))

    -- 7. getTagInfo tem fallback
    local info = TagSystem.getTagInfo("tag_inventada_xyz")
    check("getTagInfo tem fallback para tag invalida", info ~= nil and info.category == "unknown")

    -- 8. listByCategory
    local elements = TagSystem.listByCategory("element")
    check("listByCategory(element) retorna >=4", #elements >= 4)

    -- 9. Tag desconhecida loga warning mas nao crasha
    local c9 = { type = "attack", tags = { "pure_nonsense_xyz" } }
    local ok = pcall(TagSystem.getCardTags, c9)
    check("tag desconhecida nao crasha", ok)

    print(string.format("\n  TOTAL: %d pass / %d fail", pass, fail))
    return fail == 0
end

return M
