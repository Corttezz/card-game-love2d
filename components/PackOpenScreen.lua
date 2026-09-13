-- components/PackOpenScreen.lua
-- Cinemática de pack opening fiel ao source do Balatro
-- (functions/UI_definitions.lua:1629-1857). Estrutura:
--
--   ┌────────────────── PACK OPEN OVERLAY ──────────────────┐
--   │                                                        │
--   │              [ CardArea linear horizontal ]            │
--   │                                                        │
--   │      ╔══════════════╗              ┌──────┐            │
--   │      ║  PACOTE X    ║              │ SKIP │            │
--   │      ║  Choose 1    ║              └──────┘            │
--   │      ╚══════════════╝                                  │
--   └────────────────────────────────────────────────────────┘
--
-- Sequência:
--   T=0.0   Loja desliza pra baixo (handled by main.lua via callback).
--           Sleeve do pack aparece materializando no centro.
--   T=0.4   Sleeve.explode() — partículas + screen jiggle.
--   T=1.3   Cards spawnam na posição do explode e voam pra CardArea linear,
--           materializando em cascata 80ms.
--   T=1.5   DynaText "Pacote X" + "Choose N" aparecem com pop_in cascade.
--           Skip button fica clicável.
--   <click> Card: dissolve + adiciona ao deck. Skip: cards restantes dissolvem.
--   Close   Loja desliza de volta. onComplete chamado.
--
-- NÃO TEM backdrop preto — segue Balatro (shop sai de cena, pack toma o lugar).

local PackOpenScreen = {}
PackOpenScreen.__index = PackOpenScreen

local Config         = require("src.core.Config")
local Debug          = require("src.core.Debug")
local FontManager    = require("src.ui.FontManager")
local Palette        = require("src.ui.Palette")
local PixelCanvas    = require("src.ui.PixelCanvas")
local Button         = require("components.Button")
local Sfx            = require("src.systems.Sfx")
local EventManager   = require("engine.EventManager")
local FlashShader    = require("src.ui.FlashShader")
local DynaText       = require("src.ui.DynaText")
local PackSleeve     = require("src.ui.PackSleeve")
local PackThemes     = require("src.ui.PackThemes")
local Layout         = require("src.ui.PackChoiceLayout")
local ImageCache     = require("src.ui.ImageCache")
local I18n           = require("src.i18n.I18n")

-- Acessibilidade: com reducedMotion o estouro continua ENTREGANDO a informação
-- (qual pacote era, quais cartas vieram) — o que some é o exagero: wobble,
-- jiggle de tela, rotação do burst e os destroços. Flash e onda de choque
-- permanecem, mais curtos e fracos, porque são eles que marcam o "abriu".
local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

-- Configuração de timeline (segundos).
local TIMING = {
    sleeveAppear   = 0.0,    -- sleeve materializa no centro
    sleeveExplode  = 0.7,    -- sleeve.explode() — começa partículas
    cardSpawn      = 1.3,    -- cards começam a spawnar (após explode peak)
    cardStagger    = 0.10,   -- delay entre cada card materializar
    titleAppear    = 1.5,    -- DynaText do nome+choose entra com pop_in
    skipEnable     = 1.7,    -- skip button fica clicável
}

-- Pose do sleeve = mesma Y da linha de cards. Quando o pack explode, cards
-- materializam ali mesmo e se espalham horizontalmente. Padrão Balatro
-- (UI_definitions.lua:1631-1635 — CardArea fica na posição da hand).
-- Centro do sleeve = centro da ZONA das cartas. O envelope estoura exatamente
-- de onde as cartas vão nascer; se as duas coisas divergem, as cartas "pulam"
-- do nada no primeiro frame.
local function sleeveCenter(zones)
    local sw = love.graphics.getWidth()
    if zones and zones.cards then
        return sw * 0.5, zones.cards.y + zones.cards.h * 0.5
    end
    return sw * 0.5, love.graphics.getHeight() * 0.42
end

-- A carta revelada é a RECOMPENSA — o clímax da cinemática. Ela usava a mesma
-- escala da mão (Config.Cards.BASE_SCALE), o que a 1024x768 dava ~128x192: as
-- três juntas ocupavam menos área que o banner do rodapé. Aqui ela ganha
-- escala própria, maior, e o respiro entre elas triplica (0.12 → 0.34 da
-- largura) pra lerem como TRÊS ESCOLHAS e não como uma fileira colada.
-- Zonas da tela de escolha. Recalculadas em show() e resize(); todo o desenho
-- lê daqui. Ver src/ui/PackChoiceLayout.lua pro plano e pro porquê.
function PackOpenScreen:_computeZones()
    local inst = self.pack and self.pack.instances and self.pack.instances[1]
    local imgW = (inst and inst.image and inst.image:getWidth()) or 96
    local imgH = (inst and inst.image and inst.image:getHeight()) or 144
    local n = (self.pack and self.pack.instances and #self.pack.instances) or 3
    self._zones = Layout.compute(n, imgW, imgH)
    return self._zones
end

function PackOpenScreen:_z()
    return self._zones or self:_computeZones()
end

function PackOpenScreen:new()
    local instance = setmetatable({}, PackOpenScreen)
    instance.visible = false
    instance.pack = nil
    instance.onComplete = nil
    instance.choicesRemaining = 0
    instance.skipButton = nil
    instance._closing = false
    instance._selectedCards = {}
    instance._sleeveDissolve = 1     -- 1 = invisível, 0 = sólido
    instance._sleeveExploded = false
    instance._sleeveScale = 1
    instance._sleeveTilt = 0          -- pre-explode wobble (rad)
    instance._burstScale = 0           -- 0 → theme.burstScale durante explode (PixelLab burst overlay)
    instance._burstAlpha = 0           -- 0 → 0.95 → 0 (peak no explode peak)
    instance._burstRotation = 0        -- gira durante explode (sentido/força vêm do tema)
    instance._cardsReady = false
    instance._theme = PackThemes.get("Standard")
    instance._elapsed = 0              -- relógio local da cinemática (wobble, ring)
    instance._washAlpha = 0            -- flash COLORIDO por tipo (sobre o flash branco)
    instance._ringT = nil              -- onda de choque: nil = inativa
    instance._debris = nil             -- destroços do estouro (física por tipo)
    instance._footerAlpha = 0          -- banner do título entra só em TIMING.titleAppear
    -- F3: card selection 3-zone (Balatro pattern, replica CardRewardScreen).
    instance.selectedCardIdx = nil
    instance.selectedCard = nil
    instance.selectButton = nil
    instance._selectionAnim = 0
    instance.titleText = nil          -- DynaText do nome do pack
    instance.chooseText = nil         -- DynaText "Choose N"
    instance._skipReady = false
    return instance
end

-- pack: { kind, size, choose, instances }
-- onComplete(selectedList) — selectedList = lista de cartas escolhidas (pode ser vazia).
function PackOpenScreen:show(pack, onComplete)
    self.visible = true
    self.pack = pack
    self.onComplete = onComplete
    self.choicesRemaining = pack.choose or 1
    self._closing = false
    self._selectedCards = {}
    self._sleeveDissolve = 1
    self._sleeveExploded = false
    self._sleeveScale = 1
    self._sleeveTilt = 0
    self._burstScale = 0
    self._burstAlpha = 0
    self._burstRotation = 0
    self._cardsReady = false
    -- Tema do tipo de pacote: manda na cor do flash, no burst, na onda de
    -- choque, nos destroços, no título e no pitch dos sons. Abrir um Arcano
    -- tem que PARECER diferente de abrir um Espectral.
    self._theme = PackThemes.get(pack.kind)
    self._elapsed = 0
    self._washAlpha = 0
    self._ringT = nil
    self._debris = nil
    self._footerAlpha = 0
    self._skipReady = false
    self.selectedCardIdx = nil
    self.selectedCard = nil
    self.selectButton = nil
    self._selectionAnim = 0

    self:_layoutCards()
    self:_buildSkipButton()
    -- _buildTitleTexts NÃO roda aqui: o banner entra em TIMING.titleAppear
    -- (ver _scheduleTimeline). Criar as DynaTexts só naquele instante é o que
    -- faz a cascata de pop_in tocar NA ENTRADA em vez de já ter terminado.
    self.titleText = nil
    self.chooseText = nil
    self:_scheduleTimeline()

    -- Registra os sons de lacre na 1a abertura (idempotente). Fica aqui, e nao
    -- no boot, porque main.lua nao e territorio deste trabalho -- se um dia a
    -- chamada entrar la, esta vira no-op e nada muda.
    pcall(PackThemes.registerSealSounds)

    -- F11.5: shopOpen (cozy chime) na entrada — não duplica com pack-seal-break
    -- que vem em sleeve.explode (T=0.7s).
    Sfx.play("shopOpen")
    Debug.log("[PackOpenScreen] Abrindo pacote", pack.kind, "size", #pack.instances, "choose", self.choicesRemaining)
end

function PackOpenScreen:hide()
    self.visible = false
    self.pack = nil
    self.skipButton = nil
    self.titleText = nil
    self.chooseText = nil
    self._selectedCards = {}
end

function PackOpenScreen:isVisible() return self.visible end

-- Recomputa todo o layout em resposta a resize. Mantém estado de seleção
-- (selectedCardIdx) intacto — só recalcula posições de cartas + skip button.
-- Reconstroi a ARTE das cartas. Trocar o modo de video (fullscreen, drag de
-- borda) invalida o CONTEUDO de todo Canvas: o objeto sobrevive, os pixels
-- nao. As cartas do pacote guardam esse canvas em , entao depois
-- de um resize elas desenham VAZIAS -- moldura e selo aparecem, a arte nao.
-- Era este o "toda desconfigurada" que o dono viu ao dar fullscreen.
--
-- Limpar o cache do CardFrame NAO basta: a instancia guarda a referencia
-- morta. Tem que limpar E re-renderizar, reatribuindo card.image.
function PackOpenScreen:_rebuildCardArt()
    if not (self.pack and self.pack.instances) then return end
    local CardFrame = require("src.ui.CardFrame")
    if CardFrame.clearCache then CardFrame.clearCache() end
    for _, card in ipairs(self.pack.instances) do
        if card then
            local ok, img = pcall(CardFrame.render, card)
            if ok and img then
                card.image = img
            else
                -- render usa beginDraw/endDraw; crash no meio deixa o canvas
                -- preso ativo e trava o present() do frame seguinte.
                love.graphics.setCanvas()
            end
        end
    end
end

function PackOpenScreen:resize()
    if not self.visible or not self.pack then return end
    -- ORDEM: arte primeiro (o layout mede image:getWidth()), zonas depois.
    self:_rebuildCardArt()
    self:_computeZones()
    self:_layoutCards()
    if self._buildSkipButton then self:_buildSkipButton() end
    -- Os botoes de acao sao reposicionados a cada frame pela zona D, entao
    -- resize nao precisa toca-los -- so garantir que a selecao sobrevive.
end

-- Paleta de dissolve/materialize das CARTAS do pacote. Antes era sempre o
-- roxo/magenta de DissolveShader.palette("booster") — o que fazia as cartas
-- do Celestial nascerem roxas. Agora nascem e somem na cor do pacote.
function PackOpenScreen:_dissolvePalette()
    local th = self._theme or PackThemes.get("Standard")
    return {
        {th.glow[1], th.glow[2], th.glow[3], 1.0},
        {th.titleHi[1], th.titleHi[2], th.titleHi[3], 1.0},
    }
end

function PackOpenScreen:_layoutCards()
    if not self.pack or not self.pack.instances then return end
    local n = #self.pack.instances
    if n == 0 then return end

    local z = self:_computeZones()
    local scale = z.cardScale
    self._cardScale = scale
    local cardW, cardH = z.cardW, z.cardH
    local cx, cy = sleeveCenter(z)

    -- Salva final positions pra _scheduleTimeline poder mover via setTargetPos.
    self._finalCardPositions = {}

    for i, card in ipairs(self.pack.instances) do
        local finalX, finalY = Layout.cardPos(z, i)
        self._finalCardPositions[i] = { x = finalX, y = finalY }


        -- Cards começam SNAP na posição do sleeve. setRenderPos zera a
        -- interpolação interna — primeira chamada não fica "voando do nada".
        --
        -- MAS: se a carta JÁ voou pro lugar dela (`_packDispatched`), snapar de
        -- volta pro sleeve seria um teleporte. Isso acontecia de verdade em
        -- `resize()`, que chama esta função: redimensionar a janela no meio da
        -- revelação jogava as três cartas de volta pro centro e elas FICAVAM lá
        -- (nada re-emitia o setTargetPos). Carta já despachada recalcula direto
        -- pra posição final nova.
        local spawnX, spawnY
        if card._packDispatched then
            spawnX, spawnY = finalX, finalY
        else
            spawnX = cx - cardW * 0.5
            spawnY = cy - cardH * 0.5   -- nascem no centro do sleeve
        end
        if card.setRenderPos then
            card:setRenderPos(spawnX, spawnY)
        else
            card.renderX = spawnX
            card.renderY = spawnY
        end
        card.targetX = spawnX
        card.targetY = spawnY
        card.x = spawnX
        card.y = spawnY
        card._posInitialized = true

        card.baseScale = scale
        card.currentScale = scale
        -- Hover mantém a MESMA proporção de crescimento da mão.
        card.targetScale = scale *
            ((Config.Cards.HOVER_SCALE or 1.466) / (Config.Cards.BASE_SCALE or 1.333))
        card.isRewardCard = true
        card._packIndex = i

        -- ESTADO DE NASCIMENTO, so pra carta que ainda nao apareceu.
        -- `dissolve = 1` significa "invisivel, esperando materializar". Isto
        -- aqui ficava incondicional porque _layoutCards so era chamado UMA vez,
        -- na abertura -- mas resize() tambem o chama, e entao ele apagava as
        -- cartas JA REVELADAS: dissolve voltava a 1, elas sumiam, as etiquetas
        -- de raridade sumiam junto (exigem dissolve < 0.2) e nada as trazia de
        -- volta, porque a timeline de materializacao ja tinha rodado.
        -- Era este o "toda desconfigurada" ao dar fullscreen.
        -- Licao geral: funcao usada por resize() nao pode reaplicar estado
        -- INICIAL -- ela recalcula geometria, nao renasce a tela.
        if not card._packDispatched then
            card.dissolve = 1
            card.dissolve_colours = self:_dissolvePalette()
        end
    end
end

function PackOpenScreen:_buildSkipButton()
    -- Posição: column à direita do footer, alinhado verticalmente com o título.
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    -- F11.2: reduzido de 110×48 → 90×34 pra ficar discreto, não disputar atenção com cards.
    -- F12: 90px é largura de "Pular", não de "Ueberspringen" — em alemão o
    -- Button caía na truncagem e o rótulo virava "Ue...", que não informa nada.
    -- Mede o texto JÁ LOCALIZADO e cresce só o necessário (o discreto continua
    -- discreto em pt_BR; quem tem palavra longa ganha espaço em vez de reticências).
    local label = I18n.t("common.skip")
    local btnH = 34
    local btnW = math.max(90, FontManager.getFont(12):getWidth(label) + 46)  -- +46 = ícone + padding
    -- Footer fica abaixo dos cards. Skip fica em column à direita do título.
    local footerY = sh * 0.78
    local x = sw * 0.78
    self.skipButton = Button:new(x, footerY, btnW, btnH, label,
        function() self:close() end,
        nil, 12)
    self.skipButton:setIcon("x_close")
    self.skipButton:setEnabled(false)  -- só habilita após delay
end

function PackOpenScreen:_buildTitleTexts()
    -- Title: nome do pack ("Pacote Padrão", etc). As DUAS cores do ciclo saem
    -- do tema — o nome do pacote é escrito na cor do próprio pacote.
    local th = self._theme
    local kindLabel = self:_kindLabel()
    self.titleText = DynaText.new({
        text = kindLabel,
        fontSize = 26,   -- F12: era 22; o nome do pacote é o título do evento
        bump = true,
        -- F12: o bump default (bump_phase=200) defasa letras vizinhas em
        -- ~-1.06 rad, o que ESPALHA as letras — num frame parado o título lia
        -- como texto quebrado (o "P" de Pacote 14px acima do resto). Com fase
        -- pequena o salto VIAJA pela palavra: vira ondulação, que é o efeito
        -- que sempre se quis. Amplitude cai pra ~6px (era 14) porque agora
        -- várias letras estão levantadas ao mesmo tempo.
        bump_phase = 0.42,
        bump_amount = 0.45,
        rotate = true,
        pop_in = 0.5,
        pop_in_rate = 4,
        spacing = 2,
        colours = {
            {th.titleHi[1], th.titleHi[2], th.titleHi[3], 1},
            {th.titleLo[1], th.titleLo[2], th.titleLo[3], 1},
        },
        colour_cycle = 1.5,
        shadow = true,
        align = "center",
    })

    -- Choose N (atualiza dinamicamente). SEM bump e SEM rotate: é texto
    -- INFORMATIVO ("quantas você ainda escolhe") e precisa ficar na linha de
    -- base. Era ele o pior caso do espalhamento — "Escolha 1" saía com o E
    -- abaixo e o "a" acima, ilegível em frame parado. A vida dele vem do
    -- pop_in na entrada e do pulse quando o número muda.
    self.chooseText = DynaText.new({
        text = I18n.t("pack.choose", { n = self.choicesRemaining }),
        fontSize = 14,
        bump = false,
        rotate = false,
        pop_in = 0.7,
        pop_in_rate = 4,
        spacing = 1,
        colours = {{0.95, 0.92, 0.88, 1}},
        shadow = true,
        align = "center",
    })
end

function PackOpenScreen:_kindLabel()
    return PackThemes.label(self.pack and self.pack.kind or "Standard")
end

-- Agenda toda a timeline via EventManager.parallel — não-blocking, paralela.
function PackOpenScreen:_scheduleTimeline()
    local th = self._theme
    local still = reducedMotion()

    -- T=0.0: sleeve materializa (dissolve 1 → 0).
    EventManager.parallelEase(self, "_sleeveDissolve", 0, 0.4, "smooth")

    -- T=0.45-0.7: PRÉ-EXPLODE (Balatro card.lua:explode pattern). O sleeve
    -- ENCOLHE um tico e treme (o tremor vem do _elapsed no update) — é a
    -- inspiração antes do grito. Com reducedMotion, nada disso acontece.
    if not still then
        EventManager.parallel(0.45, function()
            if _G.jiggleScreen then _G.jiggleScreen(0.4) end
            EventManager.parallelEase(self, "_sleeveScale", 0.93, 0.22, "smooth")
        end)
    end

    -- T=0.7: explode com flash + jiggle + burst overlay — tudo tematizado.
    EventManager.parallel(TIMING.sleeveExplode, function()
        self._sleeveExploded = true

        -- Flash: o branco do FlashShader dá o "estalo"; por cima dele entra
        -- uma lavagem ADITIVA na cor do pacote (self._washAlpha, decaída no
        -- update). É o que separa o roxo do Arcano do verde do Espectral já
        -- no primeiro frame do estouro.
        -- O branco cedeu espaço pra lavagem colorida (era 0.7): somados, o
        -- estouro tem o mesmo PUNCH de antes, só que agora tem COR.
        if FlashShader and FlashShader.trigger then
            FlashShader.trigger(still and 0.25 or 0.35, still and 0.20 or 0.32)
        end
        -- 0.50 → 0.35: somada ao branco do FlashShader, a lavagem a 0.50
        -- estourava a tela inteira e o cenário sumia atrás da cor por ~0.2s.
        -- Quem carrega a identidade é o BURST (agora grande e rápido), não um
        -- filtro por cima de tudo.
        -- 0.35 → 0.16. A lavagem existia pra dar COR a um estouro que era um
        -- sprite laranja genérico pros 5 tipos. Agora cada tipo tem arte
        -- própria e a cor vem de lá; a lavagem voltou a ser só o que devia
        -- ser: o clarão de um instante. Mais que isso tinge a cena inteira —
        -- a mesma doença do tint, só que em tela cheia.
        self._washAlpha = still and 0.09 or 0.16

        -- Onda de choque na cor do tema (raio e duração vêm do tema).
        self._ringT = 0

        if not still and _G.jiggleScreen then _G.jiggleScreen(1.2) end

        -- F11.5: packSealBreak (chunky paper tear) no explode. F12: o pitch é
        -- do tema (Espectral grave/arrastado, Celestial agudo/cristalino) e
        -- uma camada de acento temática entra por cima, se existir registrada.
        -- Som do lacre POR TIPO. Fallback por scan, igual ao burstFile: sem o
        -- arquivo do tipo, volta pro packSealBreak generico -- e so nesse
        -- caminho o pitch por tema continua valendo, porque ali ele ainda e a
        -- unica coisa que diferencia os cinco. Com gravacao propria o pitch
        -- volta a 1.0: mexer nele de novo seria tingir o som por cima da arte.
        if th.sealCode and Sfx.has and Sfx.has(th.sealCode) then
            Sfx.play(th.sealCode)
        else
            Sfx.play("packSealBreak", { pitch = th.sealPitch or 1 })
        end
        if th.sfxAccent and Sfx.has and Sfx.has(th.sfxAccent) then
            Sfx.play(th.sfxAccent, { volume = th.accentVol or 0.5, pitch = th.accentPitch or 1 })
        end

        -- NOME DA EASE: "easeout", minúsculo. O lookup de engine/Easing.lua é
        -- case-sensitive, então o "easeOut" camelCase que estava aqui era nil
        -- e caía em `smooth` — as seis animações do estouro NUNCA rodaram com
        -- a curva que o código dizia. Corrigido de verdade (e não maquiado
        -- pra "smooth") porque easeout é a curva FÍSICA de uma detonação:
        -- velocidade máxima no instante do impacto, desacelerando. Com smooth
        -- o burst tinha ramp-up — lia como algo sendo INFLADO, não estourado.
        -- Os tempos abaixo foram re-afinados pra curva certa: easeout percorre
        -- 44% do trajeto em 1/4 do tempo (smooth faz 16%), então o que era
        -- curto pra compensar o ramp-up de smooth agora sobra.

        -- Sleeve "explode" — some decidido, sem fantasma.
        -- 0.25 → 0.22: com easeout ele já está 44% dissolvido em 60ms; encurtar
        -- garante que suma antes das cartas entrarem.
        EventManager.parallelEase(self, "_sleeveDissolve", 1, 0.22, "easeout")
        -- 1.4 → 1.55 em 0.28: a expansão agora é toda no começo, então dá pra
        -- ir mais longe sem ficar lento — lê como "arrancado", não "inchado".
        EventManager.parallelEase(self, "_sleeveScale", 1.55, 0.28, "easeout")

        -- Burst overlay (sprite PixelLab 'burst.png'): expande, gira e some.
        -- Escala/tempo/sentido de giro saem do tema — Celestial abre grande e
        -- lento como um céu; Bufão roda feito roda de circo; Espectral é
        -- pequeno, anti-horário e demora pra dissipar.
        -- bTime fica como está: com easeout a onda abre quase toda no primeiro
        -- terço e a borda externa SETTLE devagar no resto — que é exatamente
        -- a personalidade por tipo que bTime codifica.
        local bScale = th.burstScale or 1.8
        local bTime  = th.burstTime or 0.5
        -- A ESCALA abre em METADE do bTime; rotação e fade continuam no bTime
        -- cheio. Antes as três duravam o mesmo, então o burst só alcançava o
        -- tamanho máximo quando o alpha já tinha caído — nunca estava grande
        -- E brilhante ao mesmo tempo, e a onda de choque (que abre rápido)
        -- ficava 3x maior que ele. Agora ele ESTOURA aberto e depois assenta.
        EventManager.parallelEase(self, "_burstScale", bScale, bTime * 0.5, "easeout")
        EventManager.parallelEase(self, "_burstAlpha", 0.95, 0.12, "easeout")
        if not still then
            -- Giro que nasce rápido e assenta = momento. Com smooth ele
            -- acelerava no meio e parecia motor ligando.
            EventManager.parallelEase(self, "_burstRotation",
                math.pi * (th.burstSpin or 0.4), bTime, "easeout")
        end
        -- Fade-out do burst começa após o pico. 0.16 → 0.20: o fade-in agora
        -- termina mais cedo, então sem esse respiro o brilho máximo quase não
        -- existiria. Sai com easeout também — despenca e deixa um rastro
        -- fraco, que é como fumaça dissipa (o Espectral vive disso).
        EventManager.parallel(0.20, function()
            EventManager.parallelEase(self, "_burstAlpha", 0, bTime * 0.9, "easeout")
        end)

        -- Destroços: confete, pó arcano, estrelas ou ectoplasma — a FÍSICA é
        -- que carrega a identidade (ver PackThemes.debris).
        self:_spawnDebris()
    end)

    -- T=1.3+: cards materializam na posição do sleeve. Quase em paralelo
    -- (delay 0.15s após materialize start) cada card SETA target pra posição
    -- final na linha — updateRender (lerp 16/s) lerpa naturalmente. Resultado:
    -- cards "voam" do sleeve pra linha enquanto materializam.
    for i, card in ipairs(self.pack.instances) do
        local at = TIMING.cardSpawn + (i - 1) * TIMING.cardStagger
        EventManager.parallel(at, function()
            if card.start_materialize then
                card:start_materialize(self:_dissolvePalette(), false, 0.7)
            else
                card.dissolve = 0
            end
            -- F11.5: packCardReveal por card que materializa, pitch crescente.
            -- F12: o pitch BASE é do tema — a escala de revelação do Espectral
            -- soa mais grave que a do Celestial.
            local basePitch = (self._theme and self._theme.revealPitch) or 0.9
            Sfx.play("packCardReveal", { pitch = basePitch + (i - 1) * 0.08, volume = 0.6 })
            if not reducedMotion() and _G.jiggleScreen then _G.jiggleScreen(0.15) end
        end)
        -- Alvo da linha disparado um tiquinho depois do materialize start, pra
        -- card já estar visível enquanto voa.
        EventManager.parallel(at + 0.18, function()
            local fp = self._finalCardPositions[i]
            if fp and card.setTargetPos then
                card:setTargetPos(fp.x, fp.y)
                card._packDispatched = true   -- já voou: resize não a traz de volta
            end
        end)
        -- POUSO: a carta chegava no lugar e simplesmente parava. Um kick de
        -- escala no instante em que assenta dá o peso que faltava — e é POR
        -- CARTA, casando com o packCardReveal de pitch crescente que já
        -- tocava sozinho, sem contrapartida visual.
        EventManager.parallel(at + 0.52, function()
            if card.juice_up and not reducedMotion() then
                card:juice_up(0.22, 0.10)
            end
        end)
    end

    -- T=last_card + 0.3: marca cards prontos pra hover/click.
    local lastCardAt = TIMING.cardSpawn + (#self.pack.instances - 1) * TIMING.cardStagger + 0.5
    EventManager.parallel(lastCardAt, function()
        self._cardsReady = true
        -- (O recuo do banner saiu aqui: ele existia porque o titulo ficava no
        -- RODAPE, competindo com as cartas. Agora o contexto e uma barra fina
        -- no topo, que nao disputa atencao -- e o recuo tinha um efeito
        -- colateral feio: derrubava _footerAlpha abaixo do limiar que desenha
        -- o botao Pular, entao ele sumia da tela pra sempre.)
    end)

    -- T=1.5: o banner do pacote ENTRA. Antes ele era desenhado desde o frame
    -- 0 — TIMING.titleAppear existia na tabela mas nunca era usado, então o
    -- nome do pacote já estava na tela enquanto o envelope ainda estava
    -- lacrado, e a revelação não tinha momento. Agora chega junto com as
    -- cartas assentando.
    EventManager.parallel(TIMING.titleAppear, function()
        self:_buildTitleTexts()
        EventManager.parallelEase(self, "_footerAlpha", 1, 0.28, "easeout")
    end)

    -- Skip button habilitado.
    EventManager.parallel(TIMING.skipEnable, function()
        self._skipReady = true
        if self.skipButton then self.skipButton:setEnabled(true) end
    end)
end

-- Sprite do estouro do tipo atual. Fallback por SCAN (mesmo padrão dos sons
-- assinatura de joker): se o arquivo do tema não existir no disco, cai no
-- burst.png genérico — nenhum tipo fica sem explosão se um asset sumir, e
-- adicionar um tipo novo é só dropar o PNG e apontar o burstFile.
function PackOpenScreen:_burstImage()
    local th = self._theme
    local path = th and th.burstFile
    if path and love.filesystem.getInfo(path) then
        return ImageCache.get(path)
    end
    if path then
        Debug.log("[PackOpenScreen] burst do tipo ausente, usando generico:", path)
    end
    return ImageCache.get("assets/sprites/packs/effects/burst.png")
end

-- ============================================================================
-- DESTROÇOS DO ESTOURO (física por tipo — PackThemes.KINDS[kind].debris)
-- ============================================================================
-- RNG: cosmético, logo RNG global (love.math/math.random). Os streams do Rng
-- são pra decisão de RUN — destroço de partícula não pode consumir seed.

function PackOpenScreen:_spawnDebris()
    if reducedMotion() then return end
    local d = self._theme and self._theme.debris
    if not d or (d.count or 0) <= 0 then return end

    local cx, cy = sleeveCenter(self:_z())
    local list = {}
    for i = 1, d.count do
        -- Distribuição em leque com jitter: radial puro fica "relógio".
        local ang = (i / d.count) * math.pi * 2 + (math.random() - 0.5) * 0.6
        local spd = (d.speed or 200) * (0.6 + math.random() * 0.7)
        list[#list + 1] = {
            x = cx + math.cos(ang) * 10,
            y = cy + math.sin(ang) * 10,
            vx = math.cos(ang) * spd,
            vy = math.sin(ang) * spd * 0.85,
            age = 0,
            life = (d.life or 1) * (0.7 + math.random() * 0.5),
            rot = math.random() * math.pi,
            spin = (math.random() * 2 - 1) * (d.spin or 0),
            size = d.size or 4,
            -- Dois terços na cor de brilho, um terço no acento: o contraste
            -- entre as duas é o que faz o estouro ler como "do tipo X".
            col = (i % 3 == 0) and self._theme.accent or self._theme.glow,
        }
    end
    self._debris = list
end

function PackOpenScreen:_updateDebris(dt)
    local list = self._debris
    if not list then return end
    local d = self._theme.debris
    local grav = d.gravity or 0
    -- drag como meia-vida exponencial: 0.97 quase não freia, 0.82 freia rápido.
    local k = (1 - (d.drag or 0.9)) * 12

    for i = #list, 1, -1 do
        local p = list[i]
        p.age = p.age + dt
        if p.age >= p.life then
            table.remove(list, i)
        else
            p.vy = p.vy + grav * dt
            local damp = math.exp(-k * dt)
            p.vx = p.vx * damp
            p.vy = p.vy * damp
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.rot = p.rot + p.spin * dt
        end
    end
    if #list == 0 then self._debris = nil end
end

function PackOpenScreen:_drawDebris()
    local list = self._debris
    if not list then return end
    local additive = self._theme.debris and self._theme.debris.additive

    local prevMode, prevAlphaMode = love.graphics.getBlendMode()
    if additive then love.graphics.setBlendMode("add", "alphamultiply") end
    for _, p in ipairs(list) do
        local t = p.age / p.life
        local a = (1 - t) * (1 - t)          -- some acelerando no fim
        local s = p.size * (1 - 0.35 * t)
        love.graphics.push()
        love.graphics.translate(p.x, p.y)
        love.graphics.rotate(p.rot)
        love.graphics.setColor(p.col[1], p.col[2], p.col[3], a)
        love.graphics.rectangle("fill", -s * 0.5, -s * 0.5, s, s)
        love.graphics.pop()
    end
    love.graphics.setBlendMode(prevMode, prevAlphaMode)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Onda de choque: anel que abre do centro na cor do pacote. É o elemento
-- mais barato e mais legível do estouro — mesmo com reducedMotion ele fica
-- (não é tremor, é gráfico), só menor e mais rápido.
function PackOpenScreen:_drawShockwave()
    local rt = self._ringT
    if not rt then return end
    local th = self._theme
    local dur = th.ringTime or 0.5
    local p = math.min(1, rt / dur)
    local eased = 1 - (1 - p) * (1 - p) * (1 - p)   -- easeOutCubic
    local cx, cy = sleeveCenter(self:_z())
    -- 320 → 210: o anel chegava a 350px de raio e dominava a tela, ficando 3x
    -- maior que o próprio estouro. A onda é o ECO da explosão, não o evento.
    local maxR = 210 * (th.ringScale or 1)
    local r = 30 + maxR * eased
    -- (1-p)^3: some mais rápido. Com quadrático ele ficava visível metade da
    -- animação e, sendo um círculo perfeito e nítido, lia como wireframe.
    local a = (1 - p) * (1 - p) * (1 - p) * 0.80

    local prevMode, prevAlphaMode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add", "alphamultiply")

    -- Falloff barato: 4 circunferências concêntricas com alpha decrescente
    -- pros dois lados. Uma linha só, por mais grossa que fosse, tinha borda
    -- dura — energia não tem contorno.
    local band = { {-7, 0.22}, {-3, 0.60}, {0, 1.00}, {3, 0.45}, {7, 0.18} }
    for _, L in ipairs(band) do
        local rr = r + L[1] * (1 + 2 * (1 - p))
        if rr > 2 then
            love.graphics.setLineWidth(math.max(1, 3 * (1 - p) + 1))
            love.graphics.setColor(th.glow[1], th.glow[2], th.glow[3], a * L[2])
            love.graphics.circle("line", cx, cy, rr)
        end
    end

    -- Anel interno atrasado, na cor de acento — dá espessura ao evento.
    if p > 0.10 then
        local p2 = (p - 0.10) / 0.90
        local a2 = (1 - p2) * (1 - p2) * 0.40
        love.graphics.setLineWidth(math.max(1, 3 * (1 - p2)))
        love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], a2)
        love.graphics.circle("line", cx, cy, 20 + maxR * 0.72 * p2)
    end

    love.graphics.setLineWidth(1)
    love.graphics.setBlendMode(prevMode, prevAlphaMode)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Lavagem colorida em cima do flash branco. Aditiva e fullscreen: o estouro
-- TINGE a tela com a cor do pacote por ~0.35s.
function PackOpenScreen:_drawColourWash()
    local a = self._washAlpha or 0
    if a <= 0.004 then return end
    local th = self._theme
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local prevMode, prevAlphaMode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add", "alphamultiply")
    love.graphics.setColor(th.flash[1], th.flash[2], th.flash[3], a)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    love.graphics.setBlendMode(prevMode, prevAlphaMode)
    love.graphics.setColor(1, 1, 1, 1)
end

function PackOpenScreen:_updateChooseText()
    if not self.chooseText then return end
    -- "Escolha N" / "Fechando..." eram PT cravado SEM ACENTO -- invisivel pra
    -- trava de literais acentuados, e visivel pro jogador em qualquer idioma.
    local label = self.choicesRemaining > 0
        and I18n.t("pack.choose", { n = self.choicesRemaining })
        or I18n.t("pack.closing")
    if self.chooseText.text ~= label then
        self.chooseText:setText(label)
        self.chooseText:pulse(0.4, 0.4)
    end
end

function PackOpenScreen:close()
    if self._closing then return end
    self._closing = true

    -- Cards restantes (não escolhidos) dissolvem com palette booster.
    for _, card in ipairs(self.pack.instances or {}) do
        if not card._chosen and card.start_dissolve then
            card:start_dissolve(self:_dissolvePalette(), true, 0.5, false)
        end
    end

    -- Cards escolhidos voam pro canto inferior (deck) antes de dissolver.
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    for _, card in ipairs(self._selectedCards) do
        if card.setTargetPos then
            card:setTargetPos(sw * 0.5, sh + 100)
        end
        if card.start_dissolve then
            EventManager.parallel(0.3, function()
                card:start_dissolve(self:_dissolvePalette(), true, 0.5, true)
            end)
        end
    end

    local cb = self.onComplete
    local selected = self._selectedCards
    EventManager.after(0.85, function()
        self:hide()
        if cb then cb(selected) end
    end)
end

function PackOpenScreen:selectCard(card)
    if self._closing or not self._cardsReady then return end
    if not card or card._chosen then return end
    if self.choicesRemaining <= 0 then return end

    card._chosen = true
    table.insert(self._selectedCards, card)
    self.choicesRemaining = self.choicesRemaining - 1

    if card.juice_up then card:juice_up(0.6, 0.18) end
    if FlashShader and FlashShader.trigger then FlashShader.trigger(0.35, 0.2) end
    -- Pisca na cor do pacote junto com o flash branco (mesma lavagem do
    -- estouro, bem mais fraca) — escolher fecha o ciclo cromatico do evento.
    -- 0.22 -> 0.09. O estouro do pacote usa 0.16; escolher uma carta estava
    -- lavando a tela MAIS que a explosao que abre o pacote -- hierarquia
    -- invertida. O clarao da escolha e uma confirmacao, nao um evento maior.
    self._washAlpha = math.max(self._washAlpha or 0, 0.09)
    -- F11.5: packCardPick dedicado pra escolha de carta no pack.
    Sfx.play("packCardPick", { pitch = (self._theme and self._theme.sealPitch) or 1 })
    if not reducedMotion() and _G.jiggleScreen then _G.jiggleScreen(0.5) end

    self:_updateChooseText()

    if self.choicesRemaining <= 0 then
        EventManager.after(0.35, function() self:close() end)
    end
end

function PackOpenScreen:update(dt)
    if not self.visible then return end

    self._elapsed = (self._elapsed or 0) + dt

    -- Wobble pré-estouro: o sleeve treme em rotação senoidal entre T=0.45 e o
    -- estouro, com amplitude subindo. É o telegrafo do "vai estourar".
    if not self._sleeveExploded and not reducedMotion() then
        local e = self._elapsed
        local from, to = 0.45, TIMING.sleeveExplode
        if e > from then
            local ramp = math.min(1, (e - from) / math.max(0.01, to - from))
            self._sleeveTilt = math.sin((e - from) * 55) * 0.055 * ramp
        end
    end

    -- Decaimento da lavagem colorida do estouro. 1.8 → 2.6/s (0.50 zera em
    -- ~0.19s): a 1.8 ela ainda valia 0.14 dois décimos depois do estalo e
    -- TINGIA a cena inteira — num frame parado o cenário sumia atrás da cor.
    -- Flash é para durar um instante; a identidade quem carrega é o burst.
    if (self._washAlpha or 0) > 0 then
        self._washAlpha = math.max(0, self._washAlpha - dt * 2.6)
    end

    -- Onda de choque.
    if self._ringT then
        self._ringT = self._ringT + dt
        if self._ringT > (self._theme.ringTime or 0.5) then self._ringT = nil end
    end

    self:_updateDebris(dt)

    if self.titleText then self.titleText:update(dt) end
    if self.chooseText then self.chooseText:update(dt) end

    if self.skipButton then self.skipButton:update(dt) end
    if self.selectButton then self.selectButton:update(dt) end
    if self.cancelButton then self.cancelButton:update(dt) end

    -- Interpola posição (renderX/renderY → targetX/targetY) por frame.
    -- Sem isso, cards ficam parados onde foram inicializados.
    for _, card in ipairs(self.pack.instances) do
        if card and card.updateRender then
            card:updateRender(dt)
        end
    end

    if not self._closing and self._cardsReady then
        for _, card in ipairs(self.pack.instances) do
            if card and card.updateMouse then
                local mx, my = love.mouse.getPosition()
                local interactive = (card.dissolve or 0) < 0.2 and not card._chosen
                card:updateMouse(mx, my, dt, interactive)
            end
        end
    end
end

function PackOpenScreen:draw()
    if not self.visible then return end
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()

    -- Vinheta sutil pra focar no centro (NÃO é backdrop preto, é gradient leve).
    -- Mantém a loja por trás visível mas levemente escurecida nos cantos.
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- 1) Sleeve no centro. Materializa subindo de dissolve=1 (invisível) pra
    -- 0 (visível). No explode (T=0.7), volta pra 1 com scale up — efeito "estouro".
    if self._sleeveDissolve < 0.99 and self.pack then
        local cx, cy = sleeveCenter(self:_z())
        local scale = self._sleeveScale or 1
        local alpha = 1 - (self._sleeveDissolve or 0)
        -- interactive=false: aqui o sleeve não é um item de prateleira, é
        -- cenário — o hover do PackSleeve não deve reagir ao mouse parado no
        -- centro da tela. O tilt do wobble entra por `rotation`.
        PackSleeve.drawAt(self.pack.id, self.pack.kind, cx, cy, scale, alpha, {
            interactive = false,  -- aqui o sleeve é cenário, não item de prateleira
            rotation = self._sleeveTilt or 0,
        })
    end

    -- 1a) Onda de choque do estouro (atrás do burst, na frente do sleeve).
    self:_drawShockwave()

    -- 1b) Burst overlay (PixelLab burst.png): sobreposto ao sleeve durante
    -- explode. Scale + rotation + alpha animam via _scheduleTimeline.
    -- Desenhado APÓS o sleeve mas ANTES dos cards: explosão "engole" o sleeve,
    -- cards saem pela frente.
    if (self._burstAlpha or 0) > 0.001 then
        local burst = self:_burstImage()
        if burst and burst:getWidth() > 1 then
            local cx, cy = sleeveCenter(self:_z())
            local bw, bh = burst:getWidth(), burst:getHeight()
            local s = self._burstScale or 0
            -- BRANCO, uma passada só. Cada tipo tem sprite próprio agora — a
            -- cor mora na ARTE. Tingir por cima (o que se fazia quando os 5
            -- dividiam um único sprite laranja) sujava o resultado: verde
            -- pintado sobre laranja dava o estouro sujo do Espectral. Aqui o
            -- alpha é a ÚNICA coisa que o código controla.
            love.graphics.setColor(1, 1, 1, self._burstAlpha)
            love.graphics.draw(burst, cx, cy, self._burstRotation or 0,
                               s, s, bw / 2, bh / 2)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end

    -- 1c) Destroços (confete / pó / estrelas / ectoplasma). Depois do burst,
    -- antes das cartas: voam POR TRÁS do que o jogador precisa ler.
    self:_drawDebris()

    -- 2) Cards (durante e após explode). Usa renderX/renderY (posição
    -- interpolada via updateRender) pra ficar coerente com o "voo" do sleeve.
    if self.pack and self.pack.instances then
        for _, card in ipairs(self.pack.instances) do
            if card and card.draw then
                local rx = card.renderX or card.x or 0
                local ry = card.renderY or card.y or 0
                card:draw(rx, ry, false, true)
            end
        end
    end

    -- ZONAS. Cada elemento abaixo mora numa banda reservada (ver
    -- src/ui/PackChoiceLayout.lua). Nenhuma delas encosta na outra em nenhum
    -- estado -- isso e garantido pela alocacao das alturas, nao por inspecao.
    self:_drawRarityTags()        -- A2: metadado colado na carta
    self:_drawSelectionHalo()     -- A:  moldura na carta escolhida
    self:_drawHeaderBand()        -- C:  contexto do pacote
    self:_drawDetailBand()        -- B:  detalhe da carta em foco
    self:_drawActionBand()        -- D:  Escolher / Cancelar / instrucao

    -- 6) Lavagem colorida do estouro POR CIMA de tudo do overlay (o flash
    -- branco do FlashShader ainda vem depois, no love.draw do main).
    self:_drawColourWash()

    love.graphics.setColor(1, 1, 1, 1)
end

function PackOpenScreen:mousepressed(x, y, button)
    if not self.visible or self._closing then return false end

    if self._skipReady and self.skipButton and self.skipButton:mousepressed(x, y, button) then
        return true
    end

    -- Selection mini-buttons (Balatro card.lua:4582-4607: highlight cria use_button child).
    -- Consomem o click ANTES da detecção de clique na carta pra evitar
    -- "click no botão re-seleciona a carta atrás dele".
    if self.selectButton and self.selectButton:mousepressed(x, y, button) then
        return true
    end
    if self.cancelButton and self.cancelButton:mousepressed(x, y, button) then
        return true
    end

    if not self._cardsReady then return true end  -- consome durante intro pra evitar click acidental

    for i, card in ipairs(self.pack.instances or {}) do
        if card and not card._chosen and (card.dissolve or 0) < 0.2 then
            local imgW = card.image:getWidth() * (card.currentScale or 1)
            local imgH = card.image:getHeight() * (card.currentScale or 1)
            local rx = card.renderX or card.x or 0
            local ry = card.renderY or card.y or 0
            if x >= rx and x <= rx + imgW and y >= ry and y <= ry + imgH then
                -- Click numa carta = SELECIONA pra preview (3-zone overlay).
                -- Re-click na mesma OU click no Select button = confirma.
                if self.selectedCardIdx == i then
                    self:_clearCardSelection()
                    self:selectCard(card)  -- consome a escolha
                else
                    self:_setCardSelection(i, card)
                end
                return true
            end
        end
    end

    -- Click fora de cards e button → desselleciona.
    if self.selectedCardIdx then
        self:_clearCardSelection()
    end
    return true  -- consome cliques na área do overlay
end

function PackOpenScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    if self.skipButton and self.skipButton:mousereleased(x, y, button) then return true end
    if self.selectButton and self.selectButton:mousereleased(x, y, button) then return true end
    if self.cancelButton and self.cancelButton:mousereleased(x, y, button) then return true end
    return false
end

-- ============================================================================
-- CARD SELECTION (3-zone overlay com info-left + preview-right + button attached)
-- ============================================================================

function PackOpenScreen:_setCardSelection(idx, card)
    self.selectedCardIdx = idx
    self.selectedCard = card

    -- Os botoes NAO sao mais ancorados na carta. Antes nasciam em
    -- `ry + imgH + 8`, exatamente onde a etiqueta de raridade tambem nascia, e
    -- tapavam a raridade da carta selecionada. Agora sao dimensionados aqui e
    -- POSICIONADOS pela zona D (_drawActionBand), que e territorio exclusivo
    -- deles.
    local btnH = 36
    local selLabel = I18n.t("reward.select_card", nil, "ESCOLHER")
    local selW = math.max(120, FontManager.getFont(10):getWidth(selLabel) + 40)

    self.selectButton = Button:new(0, 0, selW, btnH, selLabel,
        function()
            local toSelect = self.selectedCard
            self:_clearCardSelection()
            if toSelect then self:selectCard(toSelect) end
        end, nil, 10)

    -- reward.cancel, nao common.cancel: a chave vive no mesmo bloco do
    -- reward.select_card usado acima. Com a chave errada o fallback entrava e o
    -- botao saia em portugues ao lado de um jogo em alemao.
    local cancelLabel = I18n.t("reward.cancel", nil, "Cancelar")
    local cancelW = math.max(100, FontManager.getFont(10):getWidth(cancelLabel) + 40)
    self.cancelButton = Button:new(0, 0, cancelW, btnH, cancelLabel,
        function() self:_clearCardSelection() end, nil, 10)
    self.cancelButton:setIcon("x_close")

    if EventManager and EventManager.parallelEase then
        EventManager.parallelEase(self, "_selectionAnim", 1, 0.18, "smooth", "pack_select")
    else
        self._selectionAnim = 1
    end

    if Sfx.playWithVariation then
        Sfx.playWithVariation("hoverCard", 1.1, 0.08, 0.5, 0.05)
    end
end

function PackOpenScreen:_clearCardSelection()
    self.selectedCardIdx = nil
    self.selectedCard = nil
    self.selectButton = nil
    self.cancelButton = nil
    if EventManager and EventManager.parallelEase then
        EventManager.parallelEase(self, "_selectionAnim", 0, 0.12, "smooth", "pack_select")
    else
        self._selectionAnim = 0
    end
end

-- Desenha overlay de carta selecionada — apenas halo dourado + mini-buttons
-- compactos sob a carta (Balatro use_and_sell_buttons pattern). Os painéis
-- info/preview aparecem via hover separadamente em PackOpenScreen:draw().
-- ============================================================================
-- ZONA C — CONTEXTO DO PACOTE
-- ============================================================================
-- Nome do pacote, quantas escolhas restam e o Pular. Subiu do rodape pro topo:
-- embaixo ele disputava atencao com as cartas justo no momento em que elas sao
-- o assunto, e ainda empurrava a acao (Escolher/Cancelar) pra fora da tela em
-- janela baixa. Contexto no topo, decisao embaixo, carta no meio.
function PackOpenScreen:_drawHeaderBand()
    local fa = self._footerAlpha or 0
    if fa <= 0.01 then return end
    local z = self:_z()
    local h = z.header
    local th = self._theme

    local PF = Palette.PANEL_FILL
    PixelCanvas.rect(h.x, h.y, h.w, h.h, {PF[1], PF[2], PF[3], (PF[4] or 1) * fa * 0.92})
    PixelCanvas.rectOutline(h.x, h.y, h.w, h.h,
        {th.accent[1] * 0.55, th.accent[2] * 0.55, th.accent[3] * 0.55, fa})
    -- Fita do pacote no topo da banda.
    PixelCanvas.rect(h.x + 3, h.y + 3, h.w - 6, 3,
        {th.titleHi[1], th.titleHi[2], th.titleHi[3], fa})

    -- O nome do pacote fica a esquerda do centro pra abrir espaco ao Pular.
    local nameCx = h.x + h.w * 0.42
    if self.titleText then self.titleText:draw(nameCx, h.y + 24) end
    if self.chooseText then self.chooseText:draw(nameCx, h.y + 46) end

    if self.skipButton and fa > 0.75 then
        self.skipButton.x = math.floor(h.x + h.w - self.skipButton.width - 12)
        self.skipButton.y = math.floor(h.y + (h.h - self.skipButton.height) * 0.5)
        self.skipButton:draw()
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Moldura da carta selecionada. Fica NA carta (zona A) -- e o unico feedback de
-- selecao que pode morar ali, porque acompanha o objeto sem ocupar area nova.
function PackOpenScreen:_drawSelectionHalo()
    local anim = self._selectionAnim or 0
    local card = self.selectedCard
    if not card or not card.image or anim < 0.01 then return end
    local imgW = card.image:getWidth() * (card.currentScale or 1)
    local imgH = card.image:getHeight() * (card.currentScale or 1)
    local rx = card.renderX or card.x or 0
    local ry = card.renderY or card.y or 0
    local a = 0.55 * anim * (reducedMotion() and 1
        or (0.7 + 0.3 * math.sin(love.timer.getTime() * 3.5)))
    love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], a)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", rx - 3, ry - 3, imgW + 6, imgH + 6)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- ZONA A2 — ETIQUETAS DE RARIDADE (metadado colado na carta)
-- ============================================================================
-- Mora na banda `tags`, reservada so pra isso. Antes dividia o Y com os botoes
-- de confirmar/cancelar (ambos nasciam em `ry + imgH + 8`) e o botao tapava a
-- raridade -- o defeito que o dono viu. Agora os botoes moram na zona D e a
-- colisao e impossivel por construcao, nao por ajuste de pixel.
function PackOpenScreen:_drawRarityTags()
    if not self._cardsReady or self._closing then return end
    if not (self.pack and self.pack.instances) then return end
    local z = self:_z()

    local font = FontManager.getFont(11)
    love.graphics.setFont(font)
    for _, card in ipairs(self.pack.instances) do
        if card and card.rarity and not card._chosen and (card.dissolve or 0) < 0.2 then
            local imgW = card.image:getWidth() * (card.currentScale or 1)
            local rx = card.renderX or card.x or 0
            local label = (I18n.t("rarity." .. card.rarity, nil, card.rarity)):upper()
            local tw = font:getWidth(label)
            local tx = math.floor(rx + (imgW - tw) * 0.5)
            local ty = math.floor(z.tags.y + (z.tags.h - font:getHeight()) * 0.5)

            -- Cor CLAREADA: as cores de raridade do Palette foram feitas pra
            -- moldura sobre pergaminho claro; cruas sobre o fundo escuro do
            -- pacote, o vermelho de `rare` some. Levanta em direcao ao branco
            -- so o bastante pra ler, preservando a matiz.
            local rc = Palette.forRarity(card.rarity)
            local lit = { rc[1] + (1 - rc[1]) * 0.45,
                          rc[2] + (1 - rc[2]) * 0.45,
                          rc[3] + (1 - rc[3]) * 0.45, 1 }
            love.graphics.setColor(0, 0, 0, 0.72)
            love.graphics.rectangle("fill", tx - 7, ty - 3, tw + 14, font:getHeight() + 5)
            love.graphics.setColor(rc[1], rc[2], rc[3], 0.85)
            love.graphics.rectangle("line", tx - 7, ty - 3, tw + 14, font:getHeight() + 5)
            FontManager.drawWithOutline(label, tx, ty, lit, 0.95)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- ZONA B — DETALHE DA CARTA EM FOCO
-- ============================================================================
-- Qual carta esta "em foco": a que esta sob o mouse; se nenhuma, a selecionada.
-- Hover manda sobre selecao porque quem passa o mouse esta COMPARANDO -- quer
-- ver a carta que esta olhando, nao a que ja escolheu.
function PackOpenScreen:_focusedCard()
    if not (self.pack and self.pack.instances) then return nil end
    for _, card in ipairs(self.pack.instances) do
        if card and card.isHovered and not card._chosen and (card.dissolve or 0) < 0.2 then
            return card
        end
    end
    if self.selectedCard and not self.selectedCard._chosen then
        return self.selectedCard
    end
    return nil
end

-- "chip" de metadado: rotulo pequeno + valor, com moldura. E como a loja
-- (src/ui/CardDetailPanel.lua) apresenta custo/dano, e aqui o jogador precisa
-- DA MESMA informacao: este e o momento de decisao dele.
local function drawChip(x, y, w, h, label, value, colour)
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(colour[1], colour[2], colour[3], 0.75)
    love.graphics.rectangle("line", x, y, w, h)
    local fl = FontManager.getFont(8)
    love.graphics.setFont(fl)
    love.graphics.setColor(0.80, 0.76, 0.70, 0.95)
    love.graphics.printf(label, x, y + 4, w, "center")
    local fv = FontManager.getFont(13)
    love.graphics.setFont(fv)
    love.graphics.setColor(colour[1], colour[2], colour[3], 1)
    love.graphics.printf(value, x, y + 4 + fl:getHeight() + 1, w, "center")
end

function PackOpenScreen:_drawDetailBand()
    if not self._cardsReady or self._closing then return end
    local z = self:_z()
    local d = z.detail
    local th = self._theme

    -- O ESPACO da banda e sempre reservado pelo PackChoiceLayout (por isso a
    -- tela nao pula quando o mouse entra e sai de uma carta), mas a CAIXA so e
    -- desenhada quando ha conteudo. Reservar espaco != desenhar container
    -- vazio -- essa confusao produziu o defeito que o dono reportou:
    -- "ficou com um espaco meio que empty, que sai preenchido quando eu passo
    -- o mouse. Isso ficou bem estranho" (Set/2026).
    -- O texto-instrucao que morava aqui tambem era REDUNDANTE: a zona D (acao)
    -- ja mostra a instrucao enquanto nao ha selecao. Sem foco, nada a dizer.
    local card = self:_focusedCard()
    if not card then return end

    love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.92)
    love.graphics.rectangle("fill", d.x, d.y, d.w, d.h)
    love.graphics.setColor(th.accent[1] * 0.5, th.accent[2] * 0.5, th.accent[3] * 0.5, 1)
    love.graphics.rectangle("line", d.x, d.y, d.w, d.h)

    local PAD = 16
    -- Coluna esquerda: nome + descricao + efeitos. Direita: chips numericos.
    local chipW, chipH, chipGap = 76, 40, 8
    local chips = {}
    chips[#chips + 1] = { I18n.t("pack.chip_cost"), tostring(card.cost or 0),
                          Palette.AGED_GOLD_LIGHT }
    if (card.attack or 0) > 0 then
        chips[#chips + 1] = { I18n.t("pack.chip_damage"), tostring(card.attack),
                              Palette.forCardType("attack") }
    elseif (card.defense or 0) > 0 then
        chips[#chips + 1] = { I18n.t("pack.chip_defense"), tostring(card.defense),
                              Palette.forCardType("defense") }
    end
    local chipsW = #chips * chipW + math.max(0, #chips - 1) * chipGap
    local textW = d.w - PAD * 2 - (chipsW > 0 and (chipsW + PAD) or 0)

    -- Linha 1: NOME (esquerda) + TIPO . RARIDADE (direita da coluna de texto).
    local okN, hName = pcall(I18n.cardName, card)
    love.graphics.setFont(FontManager.getFont(15))
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2],
                           Palette.AGED_GOLD_LIGHT[3], 1)
    love.graphics.printf((okN and hName) or card.name or "?", d.x + PAD, d.y + 10, textW, "left")

    local typeLabel = I18n.t("card_type." .. (card.type or "unknown"), nil, card.type or "?")
    local rarLabel = card.rarity and I18n.t("rarity." .. card.rarity, nil, card.rarity) or nil
    love.graphics.setFont(FontManager.getFont(9))
    local tc = Palette.forCardType(card.type)
    love.graphics.setColor(tc[1], tc[2], tc[3], 1)
    love.graphics.printf(typeLabel:upper() .. (rarLabel and ("  -  " .. rarLabel:upper()) or ""),
        d.x + PAD, d.y + 13, textW, "right")

    love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.45)
    love.graphics.rectangle("fill", d.x + PAD, d.y + 34, textW, 1)

    -- Descricao.
    local okD, hDesc = pcall(I18n.cardDesc, card)
    local desc = (okD and hDesc) or card.description or ""
    love.graphics.setFont(FontManager.getFont(10))
    love.graphics.setColor(Palette.PARCHMENT_LIGHT[1], Palette.PARCHMENT_LIGHT[2],
                           Palette.PARCHMENT_LIGHT[3], 0.95)
    love.graphics.printf(desc, d.x + PAD, d.y + 42, textW, "left")

    -- Efeitos: a loja mostra, e sao eles que dizem o que a carta REALMENTE faz
    -- alem do numero. Ate 3, numa linha so, pra nao estourar a banda.
    if card.effects and #card.effects > 0 then
        local parts = {}
        for i = 1, math.min(3, #card.effects) do
            -- I18n.effectDesc humaniza ("damage_bonus 3" -> texto legivel). E
            -- o mesmo helper que src/ui/CardDetailPanel.lua usa na loja;
            -- mostrar o  cru era texto de programador na cara do jogador.
            local okE, txt = pcall(I18n.effectDesc, card.effects[i])
            -- Sem chave de traducao, effectDesc devolve o TIPO CRU
            -- ("retain_armor"). Texto de programador na cara do jogador e pior
            -- que ausencia: omite em vez de vazar. Heuristica: chave crua nao
            -- tem espaco e tem underscore.
            if okE and txt and txt ~= "" and not (txt:find("_") and not txt:find(" ")) then
                parts[#parts + 1] = txt
            end
        end
        love.graphics.setFont(FontManager.getFont(8))
        love.graphics.setColor(th.titleHi[1], th.titleHi[2], th.titleHi[3], 0.75)
        love.graphics.printf(table.concat(parts, "   -   "),
            d.x + PAD, d.y + d.h - 20, textW, "left")
    end

    -- Chips numericos, encostados na direita da banda.
    local cx = d.x + d.w - PAD - chipsW
    local cy = d.y + math.floor((d.h - chipH) * 0.5)
    for _, c in ipairs(chips) do
        drawChip(cx, cy, chipW, chipH, c[1], c[2], c[3])
        cx = cx + chipW + chipGap
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- ZONA D — ACAO
-- ============================================================================
-- Sem selecao: a instrucao. Com selecao: Escolher + Cancelar. Sempre na MESMA
-- banda, entao nada se move quando o jogador clica -- e nada encosta na carta
-- nem na etiqueta de raridade.
function PackOpenScreen:_drawActionBand()
    if not self._cardsReady or self._closing then return end
    local z = self:_z()
    local a = z.action
    local th = self._theme

    if self.selectedCard and self.selectButton and self.cancelButton then
        local gap = 12
        local totalW = self.selectButton.width + self.cancelButton.width + gap
        local bx = math.floor(a.x + (a.w - totalW) * 0.5)
        local by = math.floor(a.y + (a.h - self.selectButton.height) * 0.5)
        self.selectButton.x, self.selectButton.y = bx, by
        self.cancelButton.x = bx + self.selectButton.width + gap
        self.cancelButton.y = by
        self.selectButton:draw()
        self.cancelButton:draw()
    elseif self.choicesRemaining > 0 then
        local pulse = reducedMotion() and 1
            or (0.82 + 0.18 * math.sin(love.timer.getTime() * 3))
        local f = FontManager.getFont(14)
        love.graphics.setFont(f)
        local hint = I18n.t("pack.click_hint")
        local hw = f:getWidth(hint)
        FontManager.drawWithOutline(hint,
            math.floor(a.x + (a.w - hw) * 0.5),
            math.floor(a.y + (a.h - f:getHeight()) * 0.5),
            { th.titleHi[1], th.titleHi[2], th.titleHi[3], pulse }, 0.9)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function PackOpenScreen:keypressed(key)
    if not self.visible then return false end
    if key == "escape" and self._skipReady then
        self:close()
        return true
    end
    return false
end

return PackOpenScreen
