-- src/ui/CardInfoDisplay.lua
-- Tooltip de carta no hover (mão, rewards, coleção via Card.lua).
--
-- v2 (design system Jul/2026 — playtest: "o tooltip quebra, texto passa do
-- painel, letter spacing ruim"): a fonte 16 era grande demais pro painel, a
-- largura era chutada (não media o conteúdo) e a linha de forja usava print
-- cru. Agora: TODO o conteúdo é MEDIDO antes (a maior linha define a largura,
-- com teto), tipografia na escala do design system (nome 13 / corpo 10 com
-- line-height 1.35 / meta 9), painel escuro-dourado do grimório (era cinza
-- azulado legado) e a forja mostra APENAS os ganhos reais da carta
-- (RunManager.getForgeGains — carta de ataque puro nunca anuncia DEF).

local FontManager = require("src.ui.FontManager")
local I18n = require("src.i18n.I18n")
local Palette = require("src.ui.Palette")

local CardInfoDisplay = {}
CardInfoDisplay.__index = CardInfoDisplay

local PAD = 12
local MAX_INNER = 280
local MIN_INNER = 170
local LINE_K = 1.35   -- line-height (respiro pedido no playtest)

function CardInfoDisplay:new()
    local instance = setmetatable({}, CardInfoDisplay)

    -- Configurações padrão (API preservada — Card.lua/CardRewardScreen usam)
    instance.showRarity = true
    instance.showStats = true
    instance.showDescription = false
    instance.textColor = { 1, 1, 1, 1 }

    -- Cores de raridade (fallback se Palette.forRarity não cobrir)
    instance.rarityColors = {
        common = { 0.7, 0.7, 0.7 },
        uncommon = { 0.2, 0.8, 0.2 },
        rare = { 0.8, 0.2, 0.8 },
        legendary = { 0.8, 0.6, 0.2 },
        basic = { 0.5, 0.5, 0.5 },
    }

    return instance
end

-- Configura as opções de exibição
function CardInfoDisplay:configure(options)
    if options.showRarity ~= nil then self.showRarity = options.showRarity end
    if options.showStats ~= nil then self.showStats = options.showStats end
    if options.showDescription ~= nil then self.showDescription = options.showDescription end
    if options.textColor then self.textColor = options.textColor end
    if options.rarityColors then self.rarityColors = options.rarityColors end
end

-- Linha de forja com os ganhos REAIS da carta (fonte única getForgeGains).
-- nil quando a carta não é forjada.
local function buildForgeLine(inst)
    if (inst.upgrades or 0) <= 0 then return nil end
    local RunManager = require("src.systems.RunManager")
    local gains = RunManager.getForgeGains(inst)
    local lvl = inst.upgrades
    local parts = {}
    if gains.atk then table.insert(parts, "+" .. (gains.atk * lvl) .. " " .. I18n.t("card_info.atk_short")) end
    if gains.def then table.insert(parts, "+" .. (gains.def * lvl) .. " " .. I18n.t("card_info.def_short")) end
    if gains.effect then table.insert(parts, "+" .. (gains.effect * lvl)) end
    local line = I18n.t("card_info.forged", { n = lvl }, "Forjada +" .. lvl)
    if #parts > 0 then
        line = line .. " (" .. table.concat(parts, ", ") .. ")"
    end
    return line
end

-- Keywords da descrição (glossário F5) — até 3 hits, texto composto.
-- Casa as palavras do LOCALE ATUAL contra a descrição já traduzida, e o
-- verbete exibido vem do i18n (`keyword.<id>.name/text`). Antes o glossário
-- era português em todo idioma (Out/2026).
local TextCase = require("src.i18n.TextCase")

-- Palavra começa aqui? (antes dela não pode haver letra ASCII: "gelo" não
-- casa dentro de "Congelar", "ice" não casa dentro de "twice"). O fim fica
-- livre para pegar plural/flexão ("Raios", "Orbs").
local function hasWord(lower, word)
    local from = 1
    while true do
        local i = lower:find(word, from, true)
        if not i then return false end
        if i == 1 or not lower:sub(i - 1, i - 1):match("%a") then return true end
        from = i + 1
    end
end

local function anyWord(lower, byLocale, loc)
    local words = byLocale and (byLocale[loc] or byLocale.en)
    if not words then return false end
    for _, w in ipairs(words) do
        if hasWord(lower, w) then return true end
    end
    return false
end

function CardInfoDisplay.collectKeywords(desc)
    if not desc or desc == "" then return {} end
    local hits = {}
    local lower = TextCase.lower(desc)
    local ok, Keywords = pcall(require, "src.data.keywords")
    if not ok then
        -- Chamado a cada hover: require quebrado avisaria todo quadro.
        if not CardInfoDisplay._warnedKeywords then
            CardInfoDisplay._warnedKeywords = true
            print("[CardInfoDisplay] AVISO: glossario nao carregou: " .. tostring(Keywords))
        end
        return hits
    end
    local loc = I18n.getLocale()
    -- group: no maximo UM verbete por grupo (orbes por elemento — a carta
    -- de Fogo explica so o orbe de Fogo, e o generico "Orbes" vira
    -- fallback em vez de segundo verbete; feedback Jul/2026).
    local groupHit = {}
    for _, kw in ipairs(Keywords) do
        if not (kw.group and groupHit[kw.group]) then
            -- requires: verbete só vale se a desc TAMBÉM contém uma das
            -- palavras-contexto (ex: "fogo" sozinho não é orbe de Fogo —
            -- precisa de "canaliza/evoca/orbe/valor" junto).
            local ctxOk = (kw.requires == nil) or anyWord(lower, kw.requires, loc)
            if ctxOk and anyWord(lower, kw.match, loc) then
                table.insert(hits, {
                    id   = kw.id,
                    name = I18n.t("keyword." .. kw.id .. ".name", nil, kw.id),
                    text = I18n.t("keyword." .. kw.id .. ".text", nil, ""),
                })
                if kw.group then groupHit[kw.group] = true end
            end
        end
        if #hits >= 3 then break end
    end
    return hits
end
local collectKeywords = CardInfoDisplay.collectKeywords

-- Desenha as informações da carta.
function CardInfoDisplay:draw(cardInstance, x, y, options)
    if not cardInstance then return end

    local localOptions = options or {}
    local showRarity = localOptions.showRarity ~= nil and localOptions.showRarity or self.showRarity
    local showStats = localOptions.showStats ~= nil and localOptions.showStats or self.showStats
    local showDescription = localOptions.showDescription ~= nil and localOptions.showDescription or self.showDescription

    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    -- Fontes (escala do design system)
    local nameFont = FontManager.getFont(13)
    local forgeFont = FontManager.getFont(9)
    local bodyFont = FontManager.getFont(10)
    local kwFont = FontManager.getFont(9)
    local statFont = FontManager.getFont(11)

    local nameLH = math.floor(nameFont:getHeight() * 1.2)
    local bodyLH = math.floor(bodyFont:getHeight() * LINE_K)
    local kwLH = math.floor(kwFont:getHeight() * LINE_K)

    -- ===== 1. CONTEÚDO =====
    local name = I18n.cardName(cardInstance)
    local desc = showDescription and I18n.cardDesc(cardInstance) or nil
    if desc == "" then desc = nil end
    local forgeLine = buildForgeLine(cardInstance)
    local kwHits = desc and collectKeywords(desc) or {}

    local rarityText = nil
    if showRarity and cardInstance.rarity then
        rarityText = require("src.i18n.TextCase").upper(I18n.t("rarity." .. cardInstance.rarity, nil, cardInstance.rarity))
    end

    -- ===== 2. MEDIDA (a maior linha define a largura; nada vaza) =====
    local _, nameLines = nameFont:getWrap(name or "", MAX_INNER)
    local descLines = {}
    if desc then _, descLines = bodyFont:getWrap(desc, MAX_INNER) end
    local kwBlocks = {}
    local kwSep = I18n.t("keyword.sep", nil, ": ")
    for _, kw in ipairs(kwHits) do
        local full = kw.name .. kwSep .. kw.text
        local _, lines = kwFont:getWrap(full, MAX_INNER)
        table.insert(kwBlocks, lines)
    end

    local innerW = MIN_INNER
    for _, l in ipairs(nameLines) do innerW = math.max(innerW, nameFont:getWidth(l)) end
    for _, l in ipairs(descLines) do innerW = math.max(innerW, bodyFont:getWidth(l)) end
    for _, block in ipairs(kwBlocks) do
        for _, l in ipairs(block) do innerW = math.max(innerW, kwFont:getWidth(l)) end
    end
    if forgeLine then
        innerW = math.max(innerW, math.min(MAX_INNER, forgeFont:getWidth(forgeLine)))
    end
    innerW = math.min(innerW, MAX_INNER)

    local panelH = PAD
    panelH = panelH + #nameLines * nameLH
    if forgeLine then panelH = panelH + kwLH + 2 end
    if #descLines > 0 then
        panelH = panelH + 7 + #descLines * bodyLH   -- 7 = separador + gap
    end
    for _, block in ipairs(kwBlocks) do
        panelH = panelH + 4 + #block * kwLH
    end
    if rarityText then panelH = panelH + 8 + 18 end
    if showStats then panelH = panelH + 8 + 16 end
    panelH = panelH + PAD

    local panelW = innerW + PAD * 2

    -- ===== 3. POSIÇÃO (gap ADAPTATIVO — playtest Jul/2026: o painel gruda
    -- a 6px da carta; clamp segura dentro da tela). Default ACIMA (cartas
    -- da mão, no rodapé). options.below = ABAIXO — para cartas no TOPO da
    -- tela (coringas ativos do combate, 1ª fileira do Gerenciador): acima,
    -- o clamp fazia o painel COBRIR o topo da própria carta (feedback
    -- Jul/2026 "o topo deles tá sendo cortado"). No modo below, y é a
    -- âncora INFERIOR da carta.
    local GAP = 6
    -- options.minY: teto do painel (espólios: a TopBar é camada chrome e
    -- desenha DEPOIS — painel preso no topo da tela ficava com o nome
    -- escondido atrás dela). Sem a opção, 8 px da borda como sempre.
    local topMin = localOptions.minY or 8
    local panelX = math.floor(x - panelW / 2 + 70)
    local panelY
    if localOptions.below then
        panelY = math.floor(y + GAP)
        if panelY + panelH > sh - 8 then panelY = sh - 8 - panelH end
    else
        panelY = math.floor(y - panelH - GAP)
        if panelY < topMin then panelY = topMin end
    end
    if localOptions.side and localOptions.cardW then
        -- AO LADO da carta (mão do combate, Out/2026): acima da carta
        -- levantada o painel caía sobre o tronco do inimigo, que fica no
        -- meio da tela. De lado, topo alinhado ao topo da carta: o painel
        -- ocupa a faixa da própria carta levantada e não sobe pro palco.
        -- Lado preferido = ESQUERDO: à direita moram Jogar/Encerrar, que
        -- desenham DEPOIS da mão e engoliam o painel (visto em 1024x768).
        -- Sem espaço (cartas da ponta esquerda), vira pra direita — perto do
        -- centro, longe dos botões.
        local cx0 = localOptions.cardX or x
        local cw = localOptions.cardW
        local right = cx0 + cw + GAP
        local left = cx0 - GAP - panelW
        panelX = (left >= 10) and left or right
        panelY = math.floor(y)
        if panelY + panelH > sh - 8 then panelY = sh - 8 - panelH end
        if panelY < topMin then panelY = topMin end
        panelX = math.floor(panelX)
    end
    if panelX < 10 then panelX = 10 end
    if panelX + panelW > sw - 10 then panelX = sw - panelW - 10 end
    -- Retângulo efetivamente desenhado: a régua do palco da batalha
    -- (tools/test_enemy_stage) mede o inimigo contra ESTE painel.
    self.lastRect = { x = panelX, y = panelY, w = panelW, h = panelH }

    -- ===== 4. RENDER (painel grimório escuro — era cinza azulado legado) =====
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", panelX + 3, panelY + 4, panelW, panelH, 6, 6)
    love.graphics.setColor(Palette.PANEL_FILL and Palette.PANEL_FILL[1] or 0.10,
        Palette.PANEL_FILL and Palette.PANEL_FILL[2] or 0.06,
        Palette.PANEL_FILL and Palette.PANEL_FILL[3] or 0.03, 0.97)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 6, 6)
    Palette.set(Palette.AGED_GOLD)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 6, 6)
    Palette.set(Palette.AGED_GOLD_DARK, 0.85)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", panelX + 3, panelY + 3, panelW - 6, panelH - 6, 4, 4)

    local tx = panelX + PAD
    local cy = panelY + PAD

    -- Nome (dourado claro, com sombra de tinta)
    love.graphics.setFont(nameFont)
    for _, line in ipairs(nameLines) do
        love.graphics.setColor(0, 0, 0, 0.9)
        love.graphics.print(line, tx + 1, cy + 1)
        Palette.set(Palette.AGED_GOLD_LIGHT)
        love.graphics.print(line, tx, cy)
        cy = cy + nameLH
    end

    -- Forja: só os ganhos REAIS (verde, com fit — nunca vaza)
    if forgeLine then
        love.graphics.setColor(0.55, 0.85, 0.45, 1)
        require("src.ui.TextFit").print(forgeLine, tx, cy + 2,
            { size = 9, maxW = innerW })
        cy = cy + kwLH + 2
    end

    -- Descrição (pergaminho claro com line-height)
    if #descLines > 0 then
        Palette.set(Palette.AGED_GOLD_DARK, 0.9)
        love.graphics.rectangle("fill", tx, cy + 3, innerW, 1)
        cy = cy + 7
        love.graphics.setFont(bodyFont)
        Palette.set(Palette.PARCHMENT_LIGHT)
        for _, line in ipairs(descLines) do
            love.graphics.print(line, tx, cy)
            cy = cy + bodyLH
        end
    end

    -- Glossário de keywords (nome dourado, corpo pergaminho)
    for i, kw in ipairs(kwHits) do
        cy = cy + 4
        love.graphics.setFont(kwFont)
        -- Nome dourado + corpo pergaminho, a partir do bloco pré-wrapado.
        -- O wrap apara o espaço do fim da linha, então compara sem ele; e só
        -- corta quando o nome inteiro está na linha (nunca no meio de um
        -- caractere UTF-8). Nome quebrado no wrap sai todo em pergaminho.
        local head = (kw.name .. kwSep):gsub("%s+$", "")
        local block = kwBlocks[i]
        for j, line in ipairs(block) do
            if j == 1 and line:sub(1, #head) == head then
                Palette.set(Palette.AGED_GOLD)
                love.graphics.print(head, tx, cy)
                Palette.set(Palette.PARCHMENT)
                love.graphics.print(line:sub(#head + 1), tx + kwFont:getWidth(head), cy)
            else
                Palette.set(Palette.PARCHMENT)
                love.graphics.print(line, tx, cy)
            end
            cy = cy + kwLH
        end
    end

    -- Raridade (pill compacta na cor da raridade)
    if rarityText then
        cy = cy + 8
        local rc = (Palette.forRarity and Palette.forRarity(cardInstance.rarity))
            or self.rarityColors[cardInstance.rarity] or { 1, 1, 1 }
        love.graphics.setFont(kwFont)
        local rw = kwFont:getWidth(rarityText) + 12
        love.graphics.setColor(rc[1], rc[2], rc[3], 0.22)
        love.graphics.rectangle("fill", tx, cy, rw, 16, 3, 3)
        love.graphics.setColor(rc[1], rc[2], rc[3], 1)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", tx, cy, rw, 16, 3, 3)
        love.graphics.print(rarityText, tx + 6, cy + 3)
        cy = cy + 18
    end

    -- Stats (ícones + valores reais da instância — forjada mostra o número real).
    -- Ícone escalado pra MESMA altura do número e ambos no MESMO topo de linha
    -- (playtest: o scale fixo 0.022 deixava ícone e valor desalinhados).
    if showStats then
        cy = cy + 8
        love.graphics.setFont(statFont)
        local statH = statFont:getHeight()
        local sx = tx
        local function statPair(icon, value, color)
            if icon then
                local s = statH / icon:getHeight()
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(icon, sx, cy, 0, s, s)
                sx = sx + math.ceil(icon:getWidth() * s) + 6
            end
            love.graphics.setColor(color or { 1, 1, 1, 1 })
            love.graphics.print(tostring(value), sx, cy)
            sx = sx + statFont:getWidth(tostring(value)) + 14
        end
        if cardInstance.attack and cardInstance.attack > 0 then
            statPair(cardInstance.attackIcon, cardInstance.attack, { 1, 0.45, 0.35, 1 })
        end
        if cardInstance.defense and cardInstance.defense > 0 then
            statPair(cardInstance.armorIcon, cardInstance.defense, { 0.6, 0.75, 0.95, 1 })
        end
        -- Coringa nao tem custo de mana — regra unica em CardFrame.showsManaCost.
        if require("src.ui.CardFrame").showsManaCost(cardInstance) then
            statPair(cardInstance.manaIcon, cardInstance.cost or 0, { 0.55, 0.75, 1, 1 })
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

return CardInfoDisplay
