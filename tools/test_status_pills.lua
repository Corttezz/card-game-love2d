-- tools/test_status_pills.lua
-- Trava dos ESTADOS VISÍVEIS (pills de status do jogador e do inimigo).
--
-- POR QUE ESTE TESTE EXISTE
-- Set/2026, queixa do dono sobre a carta "Barreira de Fogo": ela reflete dano
-- ao defender e o jogador não tinha COMO SABER que estava com reflexo ativo.
-- A auditoria achou mais seis estados que mudavam as regras sem nunca aparecer
-- na tela (reflexo, roubo de vida, regen, sangria, Bloqueio retido, armadura
-- do inimigo e o modo agressivo dele). Este teste cobre:
--   1. a pill APARECE quando o estado existe e SOME quando acaba;
--   2. estado de carta (buff com duração) e de coringa (permanente) somam na
--      MESMA pill, e a duração finita vence a variante permanente;
--   3. o tooltip resolve nos 5 idiomas — inspecionando o MÓDULO de cada locale,
--      não I18n.t (que cai no en e mascararia chave faltando);
--   4. nada se sobrepõe: a banda de pills é de altura FIXA (contrato que o
--      OrbRow usa) e a row cabe na largura em qualquer tamanho de janela;
--   5. todo estado do vocabulário tem cor E ícone de verdade (sem o fallback
--      silencioso "?" do PixelIcons — ui_layout_invariants §3).
--
--   love . test_one test_status_pills
--   love . test_all               (registrado em tools/run_all_tests.lua)

local TK = require("tools.testkit")
local M = {}

local StatusPill      = require("src.ui.StatusPill")
local PlayerBuffPills = require("src.ui.PlayerBuffPills")
local EnemyHud        = require("src.ui.EnemyHud")
local PixelIcons      = require("src.ui.PixelIcons")
local Player          = require("src.entities.Player")
local Enemy           = require("src.entities.Enemy")

-- ===== Janela falsa (memory/ui_layout_invariants.md §2: nunca setMode aqui) =====
local realW, realH = love.graphics.getWidth, love.graphics.getHeight
local fakeW, fakeH = nil, nil
local function fakeWindow(w, h)
    fakeW, fakeH = w, h
    love.graphics.getWidth = function() return fakeW or realW() end
    love.graphics.getHeight = function() return fakeH or realH() end
end
local function restoreWindow()
    love.graphics.getWidth, love.graphics.getHeight = realW, realH
end

local function byName(list, name)
    for _, e in ipairs(list) do
        if e.name == name then return e end
    end
    return nil
end

local function joker(effectType, value)
    return { id = "j_" .. effectType, name = effectType,
        effects = { { type = effectType, value = value } } }
end

function M.run()
    local t = TK.new("status pills (estados visiveis)")

    -- ===== 1. Player: a pill aparece quando o estado existe =====
    local p = Player:new()
    t:eq("player limpo nao tem pill", #PlayerBuffPills.collect(p, nil), 0)

    p.strength = 3
    p.dexterity = 2
    local list = PlayerBuffPills.collect(p, nil)
    t:eq("forca vira pill", (byName(list, "strength") or {}).stacks, 3)
    t:eq("destreza vira pill", (byName(list, "dexterity") or {}).stacks, 2)

    -- Reflexo vindo de CARTA: contrato acertado com o dono do EffectSystem —
    -- a carta chama player:addBuff("thorn", duration, stacks).
    p:addBuff("thorn", 2, 7)
    list = PlayerBuffPills.collect(p, nil)
    local thorn = byName(list, "thorn")
    t:truthy("thorn de carta vira pill", thorn ~= nil)
    t:eq("thorn: stacks = dano refletido", thorn and thorn.stacks, 7)
    t:eq("thorn: duracao do buff", thorn and thorn.duration, 2)
    t:eq("thorn com duracao NAO usa desc permanente", thorn and thorn.variant, nil)

    -- ===== 2. A pill SOME quando o estado acaba =====
    p:onTurnStart() -- duration 2 -> 1
    t:truthy("thorn sobrevive ao 1o turno", byName(PlayerBuffPills.collect(p, nil), "thorn") ~= nil)
    p:onTurnStart() -- duration 1 -> 0, removido
    t:eq("thorn some quando a duracao zera",
        byName(PlayerBuffPills.collect(p, nil), "thorn"), nil)

    -- ===== 3. Derivados de coringa ATIVO (o estado vive no joker, não no player) =====
    local game = { jokerSlots = {
        joker("on_defend_damage", 6), -- NÃO vira pill: vira buff "thorn" ao Bloquear
        joker("on_attack_heal", 3),
        joker("regen_per_turn", 2),
        joker("damage_per_turn", 1),
        { id = "j_bastiao", name = "Bastiao", effects = { { type = "retain_armor" } } },
    } }
    local fresh = Player:new()
    list = PlayerBuffPills.collect(fresh, game)
    -- Reflexo é ESTADO ARMADO: o joker só vira pill depois de armar o buff
    -- (senão o mesmo reflexo apareceria somado duas vezes).
    t:eq("coringa de reflexo NAO vira pill sozinho", byName(list, "thorn"), nil)
    t:eq("roubo de vida vira pill", (byName(list, "lifesteal") or {}).stacks, 3)
    t:eq("regeneracao vira pill", (byName(list, "regen") or {}).stacks, 2)
    t:eq("sangria vira pill", (byName(list, "bleed") or {}).stacks, 1)
    local retain = byName(list, "retain_armor")
    t:truthy("bloqueio retido vira pill", retain ~= nil)
    t:eq("bloqueio retido nao imprime numero", retain and retain.showStacks, false)

    -- Duas fontes de reflexo no mesmo turno (carta + coringa) armam o MESMO
    -- buff — a pill mostra o total refletido, não duas pills.
    fresh:addBuff("thorn", 1, 4)
    fresh:addBuff("thorn", 1, 6)
    list = PlayerBuffPills.collect(fresh, game)
    thorn = byName(list, "thorn")
    t:eq("duas fontes de reflexo somam numa pill so", thorn and thorn.stacks, 10)
    t:eq("thorn armado usa a desc com duracao", thorn and thorn.variant, nil)
    t:eq("duracao NAO acumula (contrato StS)", thorn and thorn.duration, 1)

    -- Jokers na BANCADA (fora de jokerSlots) não viram pill.
    t:eq("sem jokerSlots nao ha derivado",
        byName(PlayerBuffPills.collect(Player:new(), { jokerSlots = {} }), "regen"), nil)

    -- Ordem canônica: a pill não dança de lugar entre frames.
    local ordered = PlayerBuffPills.collect((function()
        local q = Player:new(); q.strength = 1; q.dexterity = 1; return q
    end)(), game)
    t:eq("ordem: forca primeiro", ordered[1] and ordered[1].name, "strength")
    t:eq("ordem: destreza segunda", ordered[2] and ordered[2].name, "dexterity")

    -- ===== 4. Inimigo: armadura e modo agressivo =====
    local e = Enemy:new(50, 10)
    t:eq("inimigo limpo nao tem pill", #EnemyHud.collectPills(e), 0)
    e.armor = 9
    local epills = EnemyHud.collectPills(e)
    t:eq("armadura do inimigo vira pill", (byName(epills, "block") or {}).stacks, 9)
    e.armor = 0
    t:eq("pill de armadura some quando zera",
        byName(EnemyHud.collectPills(e), "block"), nil)

    e.attackPattern = "aggressive"
    local enraged = byName(EnemyHud.collectPills(e), "enraged")
    t:truthy("modo agressivo vira pill", enraged ~= nil)
    t:eq("enfurecido nao imprime numero", enraged and enraged.showStacks, false)

    e.statusEffects = { { name = "poison", stacks = 3, duration = 2 } }
    e.armor = 5
    epills = EnemyHud.collectPills(e)
    t:eq("armadura + enfurecido + debuffs coexistem", #epills, 3)
    t:eq("armadura vem primeiro (decisao mais urgente)", epills[1].name, "block")
    -- Leitura pura: collectPills não pode escrever nada no inimigo.
    t:eq("collectPills nao muta statusEffects", #e.statusEffects, 1)

    -- Forward-compat: quando a fúria/armadura virarem status de verdade, o
    -- statusEffects VENCE e o derivado some — nunca duas pills do mesmo estado.
    e.statusEffects = {
        { name = "enraged", stacks = 1, duration = 99 },
        { name = "block", stacks = 5, duration = 1 },
    }
    e.armor = 5
    e.attackPattern = "aggressive"
    local dedup = EnemyHud.collectPills(e)
    t:eq("status real suprime o derivado (sem pill dobrada)", #dedup, 2)
    local nEnraged = 0
    for _, x in ipairs(dedup) do
        if x.name == "enraged" then nEnraged = nEnraged + 1 end
    end
    t:eq("uma unica pill de furia", nEnraged, 1)
    e.statusEffects = { { name = "poison", stacks = 3, duration = 2 } }

    -- ===== 5. i18n nos 5 locales (inspeciona o MÓDULO, não I18n.t) =====
    local LOCALES = { "pt_BR", "en", "es", "fr", "de" }
    local NEW_STATES = { "thorn", "lifesteal", "regen", "bleed", "retain_armor",
        "block", "enraged" }
    local WITH_PERMANENT = { thorn = true, lifesteal = true, regen = true,
        bleed = true, retain_armor = true }
    local ASCII_ONLY = { es = true, fr = true, de = true }

    for _, code in ipairs(LOCALES) do
        local mod = require("src.i18n.locales." .. code)
        local missing, empty, nonAscii = {}, {}, {}
        for _, name in ipairs(NEW_STATES) do
            local entry = mod.status and mod.status[name]
            if not entry then
                missing[#missing + 1] = name
            else
                local keys = { "name", "desc" }
                if WITH_PERMANENT[name] then keys[#keys + 1] = "desc_permanent" end
                for _, k in ipairs(keys) do
                    local v = entry[k]
                    if type(v) ~= "string" or v == "" then
                        empty[#empty + 1] = name .. "." .. k
                    elseif ASCII_ONLY[code] and v:find("[\128-\255]") then
                        -- Convenção do projeto: de/es/fr transliteram pra ASCII.
                        nonAscii[#nonAscii + 1] = name .. "." .. k
                    end
                end
            end
        end
        t:eq(code .. ": todos os estados novos existem", table.concat(missing, ","), "")
        t:eq(code .. ": nenhuma string vazia", table.concat(empty, ","), "")
        t:eq(code .. ": sem acento (convencao)", table.concat(nonAscii, ","), "")
        -- Toast disparado pelo EffectSystem quando o reflexo é armado.
        local ready = mod.messages and mod.messages.thorn_ready
        t:truthy(code .. ": messages.thorn_ready existe",
            type(ready) == "string" and ready ~= "")
    end

    -- Interpolação de verdade, pelo caminho real do tooltip.
    local I18n = require("src.i18n.I18n")
    I18n.init()
    local prevLocale = I18n.getLocale()
    I18n.setLocale("pt_BR", true)
    local desc = I18n.t("status.thorn.desc", { stacks = 7, duration = 2 }, "")
    t:truthy("desc interpola {stacks}", desc:find("7") ~= nil)
    t:truthy("desc interpola {duration}", desc:find("2") ~= nil)
    local permDesc = I18n.t("status.thorn.desc_permanent", { stacks = 6 }, "")
    t:truthy("desc_permanent nao fala de duracao", permDesc:find("{duration}") == nil)
    t:truthy("desc_permanent interpola {stacks}", permDesc:find("6") ~= nil)
    I18n.setLocale(prevLocale, true)

    -- ===== 6. Cor + ícone de verdade pra todo estado do vocabulário =====
    local noIcon, noColor, ghostIcon = {}, {}, {}
    for name in pairs(StatusPill.COLORS) do
        local iconName = StatusPill.ICONS[name]
        if not iconName then
            noIcon[#noIcon + 1] = name
        elseif not love.filesystem.getInfo("assets/sprites/icons/" .. iconName .. ".png")
            and PixelIcons[iconName] == nil then
            -- Nem PNG nem matriz: IconLoader entregaria o "?" silenciosamente.
            ghostIcon[#ghostIcon + 1] = name .. "->" .. iconName
        end
    end
    for name in pairs(StatusPill.ICONS) do
        if not StatusPill.COLORS[name] then noColor[#noColor + 1] = name end
    end
    t:eq("todo estado com cor tem icone", table.concat(noIcon, ","), "")
    t:eq("todo estado com icone tem cor", table.concat(noColor, ","), "")
    t:eq("nenhum icone fantasma (cairia no '?')", table.concat(ghostIcon, ","), "")
    for _, name in ipairs(NEW_STATES) do
        t:truthy("estado novo '" .. name .. "' tem cor", StatusPill.COLORS[name] ~= nil)
    end

    -- ===== 7. Geometria: banda fixa + nada fora da tela =====
    -- A banda de pills tem altura CONSTANTE, independente de quantas pills
    -- existem. É esse contrato que deixa o OrbRow empilhar acima sem colidir.
    local okGeom = pcall(function()
        for _, size in ipairs({ { 800, 600 }, { 1024, 768 }, { 1920, 1080 }, { 640, 480 } }) do
            fakeWindow(size[1], size[2])
            local panelX, panelY = 14, size[2] - 120
            local bandTop = PlayerBuffPills.getBandTop(panelY)

            t:truthy(size[1] .. "x" .. size[2] .. ": banda acima do painel",
                bandTop + PlayerBuffPills.BAND_HEIGHT <= panelY)

            local prevTop = nil
            for n = 1, 10 do
                local top = PlayerBuffPills.getBandTop(panelY)
                if prevTop then assert(top == prevTop, "banda mudou de altura") end
                prevTop = top
                -- A row cabe na largura disponível em qualquer contagem.
                local pillSize = PlayerBuffPills.getPillSize(n, panelX)
                local w = StatusPill.getRowDims(n, pillSize, 8)
                assert(panelX + w <= love.graphics.getWidth(),
                    "row de " .. n .. " pills vaza a tela em " .. size[1] .. "px")
                assert(pillSize <= PlayerBuffPills.BAND_HEIGHT,
                    "pill maior que a banda")
            end

            -- Inimigo: o cluster (intent + pills) cabe na largura da tela.
            local en = Enemy:new(50, 10)
            en.armor = 8
            en.attackPattern = "aggressive"
            en.statusEffects = {
                { name = "poison", stacks = 2, duration = 2 },
                { name = "weak", stacks = 1, duration = 2 },
                { name = "vulnerable", stacks = 1, duration = 1 },
            }
            local iw = EnemyHud.getIntentDims(en)
            local count = #EnemyHud.collectPills(en)
            local ps = StatusPill.fitSize(count,
                love.graphics.getWidth() * 0.9 - iw - 10, 42, 10)
            local pw = EnemyHud.getStatusPillsDims(en, ps)
            assert(iw + 10 + pw <= love.graphics.getWidth(),
                "cluster do inimigo vaza a tela em " .. size[1] .. "px")
        end
    end)
    restoreWindow()
    t:truthy("geometria ok em 4 tamanhos de janela (janela falsificada)", okGeom)

    -- ===== 8. Desenho de verdade não quebra (canvas fora da tela) =====
    local canvas = love.graphics.newCanvas(1024, 768)
    local okDraw = pcall(function()
        love.graphics.setCanvas(canvas)
        local HudManager = require("src.ui.HudManager")
        local hud = HudManager:new()
        local g = {
            player = fresh,
            jokerSlots = game.jokerSlots,
            enemy = e,
            selectedClass = "warrior",
        }
        hud:update(0.016, g)
        hud:draw(g)
        EnemyHud.draw(g, false, 512, 400)
        love.graphics.setCanvas()
    end)
    if not okDraw then love.graphics.setCanvas() end
    t:truthy("HUD com todos os estados novos desenha sem erro", okDraw)

    -- ===== 9. Estado desconhecido AVISA (nunca cai calado no cinza/'?') =====
    -- ui_layout_invariants §3. Sem esta trava, um estado novo sem cor/ícone
    -- desenharia uma bolinha cinza e ninguém saberia por semanas.
    StatusPill.clearCache()
    local realPrint = print
    local said = {}
    print = function(...) said[#said + 1] = table.concat({ ... }, " ") end
    pcall(function()
        love.graphics.setCanvas(canvas)
        StatusPill.render("estado_que_nao_existe", 10, 10, { size = 32 })
        love.graphics.setCanvas()
    end)
    print = realPrint
    love.graphics.setCanvas()
    local warnedIcon, warnedColor = false, false
    for _, line in ipairs(said) do
        if line:find("estado_que_nao_existe") and line:find("ICONS") then warnedIcon = true end
        if line:find("estado_que_nao_existe") and line:find("COLORS") then warnedColor = true end
    end
    t:truthy("estado sem icone avisa no console", warnedIcon)
    t:truthy("estado sem cor avisa no console", warnedColor)
    StatusPill.clearCache()

    return t:done()
end

return M
