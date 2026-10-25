local TK = require("tools.testkit")

local M = {}

local EXPECTED = {
    warrior_immolate = "fire",
    rogue_dirty_blade = "poison",
    rogue_poison_dart = "poison",
    rogue_venom_fang = "poison",
    rogue_twin_fangs = "poison",
    warrior_strike = "physical",
    warrior_bash = "physical",
    mage_fireball = "fire",
    mage_frost_nova = "ice",
    mage_zap = "lightning",
    mage_doom_and_gloom = "dark",
    mage_arcane_torrent = "arcane",
    mage_radiant_prayer = "holy",
}

local function sortedIds(all)
    local ids = {}
    for id in pairs(all) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

local function checkData(t, db)
    local R = require("src.systems.Resistances")
    local all = db:getAllCards()
    local missing, invalid, mismatch, spell = {}, {}, {}, {}
    local damageCards = 0
    for _, id in ipairs(sortedIds(all)) do
        local cd = all[id]
        if cd.damageType ~= nil and not R.isValidType(cd.damageType) then
            invalid[#invalid + 1] = id .. "=" .. tostring(cd.damageType)
        end
        if R.dealsDamage(cd) then
            damageCards = damageCards + 1
            if cd.damageType == nil then missing[#missing + 1] = id end
        end
        if cd.damageType and R.ofCard(cd) ~= cd.damageType then
            mismatch[#mismatch + 1] = id
        end
        local inst = db:createCardInstance(cd)
        if inst.damageType ~= cd.damageType then mismatch[#mismatch + 1] = id .. "(instancia)" end
        if cd.damageType and cd.damageType ~= "physical" and R.ofSpell(inst) ~= cd.damageType then
            spell[#spell + 1] = id
        end
    end
    t:truthy("ha cartas de dano no catalogo (" .. damageCards .. ")", damageCards >= 40)
    t:eq("toda carta de dano tem damageType explicito", table.concat(missing, ","), "")
    t:eq("todo damageType e um tipo valido", table.concat(invalid, ","), "")
    t:eq("Resistances.ofCard le o damageType (dado e instancia)", table.concat(mismatch, ","), "")
    t:eq("magia de carta elemental usa o mesmo tipo", table.concat(spell, ","), "")
    for id, ty in pairs(EXPECTED) do
        t:eq(id .. " e " .. ty, all[id] and all[id].damageType, ty)
    end
    t:eq("fallback por tag sem damageType: fogo", R.ofCard({ tags = { "strike", "fire" } }), "fire")
    t:eq("fallback por tag sem damageType: magia vira arcano", R.ofCard({ tags = { "magic" } }), "arcane")
    t:eq("fallback sem tag: fisico", R.ofCard({ tags = {} }), "physical")
    t:eq("damageType vence a tag", R.ofCard({ damageType = "poison", tags = { "fire" } }), "poison")
    t:eq("holy esta no catalogo de tipos", R.isValidType("holy"), true)
    local feel = require("src.systems.CardFeel")
    t:eq("Imolar soa como fogo (tag corrigida)", feel.themeOf(db:createCardInstance(all.warrior_immolate)), "fire")
end

local function checkCombat(t)
    local R = require("src.systems.Resistances")
    local Enemy = require("src.entities.Enemy")
    local EnemyRoster = require("src.systems.EnemyRoster")
    local db = require("src.systems.CardDatabase"):new()
    local dart = db:createCardInstance(db:getCard("rogue_poison_dart"))
    local lich = EnemyRoster.spawn(Enemy, "tower_lich", { health = 200, damage = 6, kind = "boss" }, 2)
    t:eq("golpe do dardo e veneno no lich (imune)", R.level(lich, R.ofCard(dart)), "immune")
    local imm = db:createCardInstance(db:getCard("warrior_immolate"))
    t:eq("Imolar e fraco contra o lich (fogo)", R.level(lich, R.ofCard(imm)), "weak")
end

local function nonEmpty(data, x0, y0, w, h)
    local n = 0
    for y = y0, y0 + h - 1 do
        for x = x0, x0 + w - 1 do
            local _, _, _, a = data:getPixel(x, y)
            if a > 0 then n = n + 1 end
        end
    end
    return n
end

local function checkRender(t, db)
    local CardFrame = require("src.ui.CardFrame")
    local Badge = require("src.ui.card.components.CardElementBadge")
    local R = require("src.systems.Resistances")
    local all = db:getAllCards()
    local out, overlap, noBadge, badgeOnPhysical = {}, {}, {}, {}
    local W, H = CardFrame.WIDTH, CardFrame.HEIGHT
    for _, id in ipairs(sortedIds(all)) do
        local cd = all[id]
        local inst = db:createCardInstance(cd)
        local ty = R.badgeOf(inst)
        local rect = { CardFrame.elementBadgeRect(inst) }
        if ty then
            if not Badge.has(ty) or not rect[1] then
                noBadge[#noBadge + 1] = id
            else
                local x, y, w, h = rect[1], rect[2], rect[3], rect[4]
                if x < 0 or y < 0 or x + w > W or y + h + 1 > H then out[#out + 1] = id end
                local ax, ay, aw, ah = CardFrame.artSlotBounds(inst)
                if x < ax or x + w > ax + aw or y < ay or y + h > ay + ah then
                    overlap[#overlap + 1] = id
                end
            end
        elseif rect[1] then
            badgeOnPhysical[#badgeOnPhysical + 1] = id
        end
    end
    t:eq("todo tipo nao fisico tem selo", table.concat(noBadge, ","), "")
    t:eq("selo dentro da carta", table.concat(out, ","), "")
    t:eq("selo dentro da janela da arte (nao cobre custo, selo, nome nem rodape)",
        table.concat(overlap, ","), "")
    t:eq("fisico e sem tipo nao ganham selo", table.concat(badgeOnPhysical, ","), "")

    for _, id in ipairs({ "mage_fireball", "rogue_poison_dart", "joker_boss_lich", "mage_radiant_prayer" }) do
        CardFrame.invalidate({ id = id })
        local inst = db:createCardInstance(all[id])
        local img = CardFrame.render(inst)
        local data = img:newImageData()
        local x, y, w, h = CardFrame.elementBadgeRect(inst)
        local col = Badge.colors(R.badgeOf(inst)).glyph
        local hits = 0
        for py = y, y + h - 1 do
            for px = x, x + w - 1 do
                local r, g, b = data:getPixel(px, py)
                if math.abs(r - col[1]) < 0.02 and math.abs(g - col[2]) < 0.02
                    and math.abs(b - col[3]) < 0.02 then
                    hits = hits + 1
                end
            end
        end
        t:truthy(id .. ": glifo do elemento pintado no canvas (" .. hits .. " px)", hits >= 8)
        t:truthy(id .. ": canvas inteiro opaco no miolo", nonEmpty(data, x, y, w, h) == w * h)
        data:release()
        local anim = CardFrame.getAnimation(inst)
        if anim then
            local missingFrames = 0
            for i, cv in ipairs(anim.canvases) do
                local d = cv:newImageData()
                local fh = 0
                for py = y, y + h - 1 do
                    for px = x, x + w - 1 do
                        local r, g, b = d:getPixel(px, py)
                        if math.abs(r - col[1]) < 0.02 and math.abs(g - col[2]) < 0.02
                            and math.abs(b - col[3]) < 0.02 then
                            fh = fh + 1
                        end
                    end
                end
                if fh < 8 then missingFrames = missingFrames + 1 end
                d:release()
                if i >= 6 then break end
            end
            t:eq(id .. ": selo em todo quadro animado", missingFrames, 0)
        end
        love.graphics.present()
    end
end

local function checkTooltip(t, db)
    local I18n = require("src.i18n.I18n")
    local CID = require("src.ui.CardInfoDisplay")
    local all = db:getAllCards()
    local problems = {}
    local R = require("src.systems.Resistances")
    for _, loc in ipairs(I18n.available) do
        local tb = require("src.i18n.locales." .. loc)
        local ci = tb.card_info or {}
        for _, key in ipairs({ "damage_type", "element" }) do
            local v = ci[key]
            if type(v) ~= "string" or not v:find("{type}", 1, true) then
                problems[#problems + 1] = loc .. ":card_info." .. key
            elseif v:find("\226\128\148") or v:find("\226\128\147") or v:find(" %- ") then
                problems[#problems + 1] = loc .. ":card_info." .. key .. " travessao"
            end
        end
        for _, ty in ipairs(R.TYPES) do
            if type(((tb.resist or {}).type or {})[ty]) ~= "string" then
                problems[#problems + 1] = loc .. ":resist.type." .. ty
            end
        end
    end
    t:eq("linha de tipo nos 5 idiomas", table.concat(problems, ","), "")

    local prev = I18n.getLocale and I18n.getLocale() or "pt_BR"
    for _, loc in ipairs(I18n.available) do
        I18n.setLocale(loc)
        local line = CID.buildElementLine(db:createCardInstance(all.rogue_poison_dart))
        local name = I18n.t("resist.type.poison")
        t:truthy(loc .. ": tooltip do dardo diz o tipo (" .. tostring(line and line.text) .. ")",
            line and line.text:find(name, 1, true) and not line.text:find("{", 1, true))
    end
    I18n.setLocale(prev)
    local strike = CID.buildElementLine(db:createCardInstance(all.warrior_strike))
    t:truthy("golpe fisico mostra o tipo so no tooltip", strike and strike.type == "physical" and not strike.badge)
    t:eq("defesa sem elemento nao ganha linha", CID.buildElementLine(db:createCardInstance(all.warrior_defend)), nil)
    local holy = CID.buildElementLine(db:createCardInstance(all.mage_radiant_prayer))
    t:truthy("carta sagrada sem dano diz Elemento", holy and holy.badge and holy.type == "holy")

    local ok = pcall(function()
        local cv = love.graphics.newCanvas(800, 600)
        love.graphics.push("all")
        love.graphics.setCanvas(cv)
        local d = CID:new()
        d:draw(db:createCardInstance(all.mage_fireball), 400, 400, {})
        love.graphics.pop()
        cv:release()
    end)
    t:truthy("tooltip desenha com a linha de tipo", ok)
end

function M.run()
    local t = TK.new("tipo de dano por carta")
    TK.bootstrap()
    local db = require("src.systems.CardDatabase"):new()
    checkData(t, db)
    checkCombat(t)
    checkRender(t, db)
    checkTooltip(t, db)
    return t:done()
end

return M
