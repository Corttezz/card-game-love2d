-- components/EventScreen.lua
-- Narrativa: titulo + corpo + 2-4 opcoes. Executa option.apply(game) e fecha.
--
-- F4 do UI Overhaul (docs/plan/ui-ux-overhaul-v1.md): cena real de fundo
-- (path_event), painel grimório (Panel9) com ILUSTRAÇÃO do evento
-- (assets/sprites/ui/event_<id>.png, geradas via PixelLab) e opções dentro
-- do painel — no lugar do miolo vazio da tela antiga (nota D+ no
-- levantamento).

local EventScreen = {}
EventScreen.__index = EventScreen

local FontManager      = require("src.ui.FontManager")
local Palette          = require("src.ui.Palette")
local Button           = require("components.Button")
local Panel9           = require("src.ui.Panel9")
local SceneBackground  = require("src.ui.SceneBackground")
local HintBar          = require("src.ui.HintBar")
local Sfx              = require("src.systems.Sfx")
local Moveable         = require("engine.Moveable")
local I18n             = require("src.i18n.I18n")
local Debug            = require("src.core.Debug")
local EventManager     = require("engine.EventManager")
local DynaText         = require("src.ui.DynaText")
local FloatingText     = require("src.ui.FloatingText")

local illustrationCache = {}

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

-- Toca o primeiro código registrado da lista (contrato de som novo do
-- projeto: o call site nasce pronto e o arquivo passa a tocar sozinho quando
-- cair em audio/sfx/). Avisa só quando HÁ sistema de áudio — sem ele nenhum
-- código resolve e o aviso seria ruído garantido em todo run headless.
local _sfxWarned = {}
local function playFirstSfx(codes, opts)
    for _, code in ipairs(codes) do
        if Sfx.has(code) then
            Sfx.play(code, opts)
            return code
        end
    end
    if _G.audioSystem then
        local key = table.concat(codes, "/")
        if not _sfxWarned[key] then
            _sfxWarned[key] = true
            Debug.warn("[EventScreen] nenhum sfx registrado em: " .. key)
        end
    end
    return nil
end

local function getIllustration(eventId)
    if not eventId then return nil end
    if illustrationCache[eventId] ~= nil then
        return illustrationCache[eventId] or nil
    end
    local path = "assets/sprites/ui/event_" .. eventId .. ".png"
    if love.filesystem.getInfo(path) then
        local ok, img = pcall(love.graphics.newImage, path)
        if ok and img then
            img:setFilter("nearest", "nearest")
            illustrationCache[eventId] = img
            return img
        end
    end
    illustrationCache[eventId] = false
    return nil
end

-- Fila PRÓPRIA (memory/eventmanager_queues.md, regra de ouro): a `base`
-- pertence ao combate e prende eventos de tela atrás do rabo dele.
local FXQ = "event_fx"

-- Entrada/saída: o painel sobe um pouco e assenta; o véu da cena escurece
-- junto. Dose pequena de propósito — o dono pediu "efeitos sutis", e uma tela
-- de LEITURA não pode chegar saltitando: o jogador precisa ler o texto, não
-- assistir a ele.
local ENTER_DUR   = 0.34
local ENTER_RISE  = 26     -- px que o painel sobe durante a entrada
local EXIT_DUR    = 0.30

function EventScreen:new()
    local instance = setmetatable({}, EventScreen)
    instance.visible = false
    instance.event = nil
    instance.game = nil
    instance.onClose = nil
    instance.buttons = {}
    instance.resultText = nil
    instance.resultTimer = 0
    -- Estado de animação. Vive aqui (e não em locals do módulo) porque o
    -- resize precisa saber que existe — invariante §2: estado cacheado novo
    -- obriga a estender o resize NO MESMO commit.
    instance.panelOy = 0     -- deslocamento vertical da entrada/saída
    instance.fade    = 1     -- 0..1, multiplica alpha de tudo
    instance._closing = false
    return instance
end

function EventScreen:show(event, game, onClose)
    self.visible = true
    self.event = event
    self.game = game
    self.onClose = onClose
    self.resultText = nil
    self.resultTimer = 0
    self._closing = false
    self:buildButtons()
    self:_buildTitle()

    EventManager.clear(FXQ)

    if reducedMotion() then
        self.panelOy, self.fade = 0, 1
    else
        self.panelOy = ENTER_RISE
        self.fade = 0
        EventManager.parallelEase(self, "panelOy", 0, ENTER_DUR, "back_out", FXQ)
        EventManager.parallelEase(self, "fade",    1, ENTER_DUR * 0.7, "smooth", FXQ)
    end

    -- O vento chega com a encruzilhada. Sustenta 1,5s por baixo da leitura,
    -- que é o tempo de o jogador olhar a ilustração e o texto.
    playFirstSfx({ "eventEnterWind", "menuOpen" })
end

-- Saída com fade. Um evento é a decisão mais irreversível da run e terminava
-- com um corte seco pro mapa; agora a tela se retira. O callback do fluxo vem
-- DEPOIS, e só uma vez (_closing), pelo mesmo motivo da saída da loja.
function EventScreen:_closeWithFade()
    if self._closing then return end
    self._closing = true
    local cb = self.onClose

    if reducedMotion() then
        self:hide()
        if cb then cb() end
        return
    end

    EventManager.parallelEase(self, "fade", 0, EXIT_DUR, "smooth", FXQ)
    EventManager.parallelEase(self, "panelOy", -ENTER_RISE * 0.6, EXIT_DUR, "smooth", FXQ)
    EventManager.parallel(EXIT_DUR + 0.02, function()
        if not self.visible then return end
        self:hide()
        if cb then cb() end
    end, FXQ)
end

function EventScreen:hide()
    self.visible = false
    self.event = nil
    self.buttons = {}
    self.titleDyna = nil
    self._closing = false
    self.panelOy, self.fade = 0, 1
    EventManager.clear(FXQ)
end

function EventScreen:isVisible() return self.visible end

-- O DynaText do título nasce no SHOW (e no resize), não no primeiro draw.
-- Criando-o em draw, o pop_in só começava a contar quando a tela já estava
-- desenhando: o update() dos frames anteriores não tinha em que tickar, e num
-- frame capturado logo após o show saía UMA letra ("Q" em vez de "Quelle des
-- Lebens"). Com ele criado aqui, a cascata roda junto com a entrada.
function EventScreen:_buildTitle()
    local ev = self.event
    local title = ev and I18n.t("events." .. ev.id .. ".title", nil, ev.title or "") or ""
    self.titleDyna = DynaText.new({
        text = title,
        fontSize = 20,
        -- bump DESLIGADO: título de evento é TEXTO DE LEITURA e o jogador
        -- precisa lê-lo parado — mesma decisão que o RoundEval tomou pro
        -- `totalText`. A ENTRADA pode ser animada; a leitura, não.
        bump = false,
        pop_in = reducedMotion() and 0 or 0.4,
        pop_in_rate = 5,
        spacing = 1,
        colours = { { Palette.INK[1], Palette.INK[2], Palette.INK[3], 1 } },
        align = "center",
    })
end

function EventScreen:resize()
    if not self.visible then return end
    self:buildButtons()
    -- Estado cacheado que o resize TEM que recalcular junto: o DynaText do
    -- título deriva da fonte responsiva, então numa troca de resolução ele
    -- ficaria com a métrica antiga. panelOy/fade são relativos e sobrevivem.
    self:_buildTitle()
end

-- Geometria do painel (compartilhada entre build e draw).
function EventScreen:panelRect()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local pw = math.min(620, math.floor(sw * 0.78))
    local ph = math.min(600, math.floor(sh * 0.88))
    local px = math.floor((sw - pw) / 2)
    local py = math.floor((sh - ph) / 2)
    return px, py, pw, ph
end

-- Label da opção com custo/ganho EXPLÍCITO entre colchetes (padrão StS: o
-- botão declara a troca, nunca é pegadinha). Campos data-driven da opção:
--   gains = { "$45", "carta rara" }  →  [+$45 / +carta rara]
--   costs = { "12 HP", "20 ouro" }   →  [-12 HP / -20 ouro]
-- Sem esses campos o label sai como está (opções "ir embora" etc).
-- Resolve UM delta. Aceita as duas formas:
--   { k = "hp", n = 8, fb = "8 HP" }   → token traduzido, com {n}/{pct}
--   "8 HP"                             → string crua (compat)
-- A tabela inteira vai como `vars`, então {n} e {pct} interpolam sozinhos.
local function deltaText(d)
    if type(d) == "string" then return d end
    if type(d) ~= "table" or not d.k then return tostring(d) end
    return I18n.t("events.tokens." .. d.k, d, d.fb or d.k)
end

local function composeOptionLabel(ev, opt, index)
    -- Rótulo traduzido; o literal que sobrou no events.lua é o fallback.
    local label = opt.label
    if ev and ev.id then
        label = I18n.t("events." .. ev.id .. ".opt" .. index, nil, opt.label or "")
    end
    if not opt.gains and not opt.costs then return label end
    local parts = {}
    for _, g in ipairs(opt.gains or {}) do table.insert(parts, "+" .. deltaText(g)) end
    for _, c in ipairs(opt.costs or {}) do table.insert(parts, "-" .. deltaText(c)) end
    if #parts == 0 then return label end
    return label .. "  [" .. table.concat(parts, " / ") .. "]"
end

-- Exposto pra ferramenta de verificação (tools/check_event_labels.lua) medir
-- o rótulo FINAL em todos os idiomas sem redesenhar a tela. Fonte única: é o
-- mesmo texto que o botão recebe.
function EventScreen:optionLabel(opt, index)
    return composeOptionLabel(self.event, opt, index)
end

function EventScreen:buildButtons()
    self.buttons = {}
    if not self.event then return end
    local px, py, pw, ph = self:panelRect()
    local opts = self.event.options or {}
    local btnW = pw - 120
    local btnH = 46
    local spacing = 10
    -- opções ancoradas no RODAPÉ do painel (ilustração+texto ficam em cima)
    local startY = py + ph - 40 - (#opts) * (btnH + spacing)
    for i, opt in ipairs(opts) do
        local y = startY + (i - 1) * (btnH + spacing)
        local x = math.floor(px + (pw - btnW) / 2)
        local onClick = function()
            local feedback
            -- ROTEIRO: registra a opção ANTES do apply — as aquisições do
            -- apply (carta, forja, remoção) caem na mesma entrada do nó e
            -- assim aparecem sob a opção que as causou.
            local rm = self.game and self.game.runManager
            if rm and rm.journalEvent then
                rm:journalEvent(self.event and self.event.id, i, opt.label)
            end
            if opt.apply then
                local ok, res = pcall(opt.apply, self.game)
                if ok then feedback = res end
            end
            self.resultText = feedback
                or I18n.t("event.default_result", nil, "Voce segue em frente.")
            self.resultTimer = 1.8
            -- Limpa botoes enquanto feedback e exibido (impede duplo-click)
            self.buttons = {}

            -- O LACRE: a escolha do evento é a decisão mais irreversível da
            -- run e não tinha marca nenhuma. Carimbo + tremor curto.
            playFirstSfx({ "eventChoiceSeal", "buttonClick" })
            if _G.jiggleScreen then _G.jiggleScreen(0.45) end

            -- O que a opção COBRA e o que ela PAGA sobe em número, do jeito
            -- que o combate já faz. O dado já existia estruturado em
            -- opt.gains/opt.costs (é o que monta o rótulo "[+$45 / -12 HP]");
            -- até agora só era texto dentro do botão, nunca um evento.
            self:_spawnDeltas(opt, x + btnW * 0.5, y)
        end
        local btn = Button:new(x, y, btnW, btnH,
            composeOptionLabel(self.event, opt, i), onClick, nil, 10)
        table.insert(self.buttons, btn)
    end
end

-- Ganhos e custos da opção escolhida sobem como FloatingText, escalonados.
-- Ganho em dourado, custo em vermelho — a MESMA leitura direcional do ouro na
-- TopBar, pra não ensinar dois vocabulários de cor pro jogador.
function EventScreen:_spawnDeltas(opt, cx, cy)
    if reducedMotion() then return end
    local i = 0
    local function emit(list, prefix, color)
        for _, txt in ipairs(list or {}) do
            local delay = i * 0.13
            i = i + 1
            EventManager.parallel(delay, function()
                FloatingText.spawn(prefix .. txt, cx, cy - i * 4, {
                    color = color, fontSize = 13, lift = 30, hold = 0.5,
                })
            end, FXQ)
        end
    end
    emit(opt.gains, "+", { 1, 0.84, 0.32, 1 })
    emit(opt.costs, "-", { 0.90, 0.35, 0.30, 1 })
end

-- O painel é TRANSLADADO no desenho, mas o Button faz hit-test na posição
-- real (love.mouse.getPosition contra self.x/y). Enquanto a entrada/saída
-- corre, os dois discordam em até 26px — o jogador veria o realce numa opção
-- e clicaria noutra. Então durante a animação a tela simplesmente não aceita
-- input, e o hover fica limpo. Dura 0,34s; ninguém decide um evento nesse
-- tempo, e a alternativa (compensar o offset em cada handler) espalharia a
-- mesma constante por quatro lugares.
function EventScreen:_isAnimating()
    return self._closing or math.abs(self.panelOy or 0) > 0.5
end

function EventScreen:update(dt)
    if not self.visible then return end
    if self:_isAnimating() then
        for _, b in ipairs(self.buttons) do b.hover = false; b.pressed = false end
    else
        for _, b in ipairs(self.buttons) do b:update(dt) end
    end
    if self.titleDyna then self.titleDyna:update(dt) end
    if self.resultTimer > 0 then
        self.resultTimer = self.resultTimer - dt
        if self.resultTimer <= 0 then
            self.resultTimer = 0
            self:_closeWithFade()
        end
    end
end

function EventScreen:draw()
    if not self.visible then return end
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    -- Cena real de encruzilhada misteriosa (cover-fit + véu)
    local drawn = SceneBackground.draw("path_event", sw, sh, 0.40)
    if not drawn then
        love.graphics.setColor(0.06, 0.05, 0.07, 1)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    end
    love.graphics.setColor(1, 1, 1, 1)

    -- MOVIMENTO do painel: translate no desenho, NUNCA somado em panelRect().
    -- panelRect é a âncora imutável do layout (lição das "cartas invisíveis":
    -- offset somado na posição-base vira feedback loop porque draw grava
    -- estado). Assim o botão continua sabendo onde ele mora, e a entrada é só
    -- uma camada de apresentação por cima.
    love.graphics.push()
    love.graphics.translate(0, self.panelOy or 0)

    local px, py, pw, ph = self:panelRect()
    Panel9.draw("panel_main", px, py, pw, ph)

    -- Titulo via DynaText (pop-in cascata), no lugar do print estático.
    -- Título (DynaText montado no show) e corpo vêm do locale; os literais
    -- que sobraram em events.lua são o fallback.
    local ev = self.event
    -- DynaText:draw recebe o CENTRO vertical; o print antigo recebia o TOPO.
    -- +10 (meia altura da fonte 20) mantém o título no mesmo lugar de antes.
    if self.titleDyna then
        self.titleDyna:draw(math.floor(px + pw / 2), py + 50)
    end

    -- Área útil entre o título e as opções (pro conteúdo centralizar)
    local opts = (self.event and self.event.options) or {}
    local buttonsTop = py + ph - 40 - (#opts) * (46 + 10)
    local areaTop = py + 80
    local areaH = buttonsTop - areaTop - 16

    -- ILUSTRAÇÃO do evento (moldura interna escura; 128×96 @2x = 256×192)
    local img = getIllustration(self.event and self.event.id)
    local bodyFont = FontManager.getFont(10)
    local bodyText = ev and I18n.t("events." .. ev.id .. ".body", nil, ev.body or "") or ""
    local bodyW = pw - 120
    local _, bodyLines = bodyFont:getWrap(bodyText, bodyW)
    -- ENTRELINHA medida, não chutada (`love . check_font_metrics`): na fonte
    -- do projeto em corpo 10, `getHeight()` reporta 10px mas a TINTA dos
    -- glifos ocupa 11px — acento e descendente moram FORA da métrica. Como o
    -- printf empilha por getHeight(), a segunda linha subia por cima da
    -- primeira. Só aparecia em idioma de texto longo (o alemão), porque em PT
    -- quase todo corpo cabe numa linha.
    --
    -- 1.1 não resolvia: dava exatamente 11px, ou seja, as linhas passavam a
    -- se encostar em vez de se sobrepor. 1.3 = 13px deixa 2px de respiro, que
    -- é o mínimo para 'Ç' de uma linha não beijar o 'p' da linha de cima.
    local bodyLH = math.floor(bodyFont:getHeight() * 1.3 + 0.5)
    local bodyH = #bodyLines * bodyLH

    -- Desenha as linhas JÁ QUEBRADAS, com a mesma entrelinha que o cálculo de
    -- altura acima usa. Antes o layout reservava 1.1 e o printf desenhava 1.0:
    -- dois números para a mesma coisa, e por isso um deles estava sempre errado.
    local function drawBody(x, y)
        love.graphics.setFont(bodyFont)
        Palette.set(Palette.INK)
        for i, line in ipairs(bodyLines) do
            love.graphics.printf(line, x, y + (i - 1) * bodyLH, bodyW, "center")
        end
    end

    if img then
        local iw, ih = img:getWidth(), img:getHeight()
        local s = math.min(2, (pw - 200) / iw)
        local dw, dh = iw * s, ih * s
        -- centraliza o bloco ilustração+texto na área útil
        local blockH = dh + 28 + bodyH
        local contentY = math.floor(areaTop + math.max(0, (areaH - blockH) / 2))
        local ix = math.floor(px + pw / 2 - dw / 2)
        Panel9.draw("panel_inner", ix - 10, contentY - 8, dw + 20, dh + 16, {
            fill = { 0.10, 0.08, 0.06, 0.95 },
        })
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, ix, contentY, 0, s, s)
        drawBody(px + 60, contentY + dh + 28)
    else
        -- sem ilustração: corpo CENTRALIZADO verticalmente (a tela antiga
        -- deixava um vazio enorme de pergaminho)
        local contentY = math.floor(areaTop + math.max(0, (areaH - bodyH) / 2))
        drawBody(px + 60, contentY)
    end

    -- Botoes (opções)
    for _, b in ipairs(self.buttons) do b:draw() end

    -- Feedback apos escolha
    if self.resultText then
        local rf = FontManager.getFont(12)
        love.graphics.setFont(rf)
        Palette.set(Palette.MOSS)
        love.graphics.print(self.resultText,
            math.floor(px + pw / 2 - rf:getWidth(self.resultText) / 2),
            py + ph - 90)
    end

    love.graphics.pop()

    HintBar.draw(I18n.t("event.hint",
        { n = math.max(1, #(self.event and self.event.options or {})) },
        "Clique numa opcao OU pressione 1-{n} · a escolha e definitiva"))

    -- CORTINA da transição. Um retângulo escuro por cima de tudo, abrindo na
    -- entrada e fechando na saída.
    --
    -- Escolhi isto em vez de multiplicar alpha em cada setColor da tela: o
    -- fade por alpha exigiria tocar em ~15 pontos de desenho e qualquer um
    -- esquecido ficaria opaco no meio da transição — defeito que só aparece
    -- em 3 frames e ninguém acha depois. A cortina é uma linha, não tem como
    -- ficar pela metade, e lê como a encruzilhada emergindo do escuro.
    local f = self.fade or 1
    if f < 0.999 then
        love.graphics.setColor(0.03, 0.025, 0.035, 1 - f)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function EventScreen:mousepressed(x, y, button)
    if not self.visible then return false end
    if self:_isAnimating() then return true end   -- engole: painel em transito
    -- ARMA o pressed de cada botão. Sem isto o Button:mousereleased abaixo
    -- não dispara (ele exige self.pressed) — ver Button.lua:508.
    for _, b in ipairs(self.buttons) do
        if b:mousepressed(x, y, button) then return true end
    end
    return true
end

function EventScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    if self:_isAnimating() then return true end
    -- FIX Set/2026: esta tela chamava `b.onClick()` DIRETO, pulando o
    -- Button:mousereleased — e com ele o `buttonClick`, o `juice_up` e o
    -- jiggle que todo botão do jogo dá (Button.lua:516-528). Resultado: a
    -- escolha do evento, que é a decisão mais irreversível da run, era o
    -- único clique MUDO e sem reação do jogo inteiro.
    for _, b in ipairs(self.buttons) do
        if b:mousereleased(x, y, button) then return true end
    end
    return false
end

function EventScreen:keypressed(key)
    if not self.visible then return false end
    if self:_isAnimating() then return true end
    if key == "1" or key == "2" or key == "3" or key == "4" then
        local i = tonumber(key)
        local btn = self.buttons[i]
        if btn and btn.onClick then
            -- O atalho de teclado não passa pelo Button:mousereleased, então
            -- o feedback do clique é reproduzido aqui — escolher pelo 1-4 tem
            -- que soar igual a escolher pelo mouse.
            Sfx.playWithVariation("buttonClick", 1.0, 0.08)
            Moveable.juice_up(btn, 0.22, 0.05)
            if _G.jiggleScreen then _G.jiggleScreen(0.3) end
            btn.onClick()
        end
        return true
    end
    return false
end

return EventScreen
