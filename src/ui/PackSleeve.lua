-- src/ui/PackSleeve.lua
-- Renderiza o "envelope" (sleeve) de um booster pack — a carta selada que
-- aparece na PRATELEIRA da loja e, depois, centralizada antes de explodir.
--
-- Estratégia:
--   • PNG do PixelLab em assets/sprites/packs/<id>.png (caminho normal).
--   • Fallback procedural por kind se o PNG sumir.
--
-- O sleeve é, ANTES DE TUDO, a arte. Os PNGs do PixelLab já trazem moldura,
-- cantoneiras metálicas com rebites, fitas cruzadas e selo — o envelope está
-- COMPLETO no arquivo. O trabalho deste módulo é mostrá-lo, não redecorá-lo.
--
-- Histórico (Set/2026) que existe pra não ser repetido: uma versão anterior
-- empilhou por cima da arte (a) um halo aditivo feito de 3 cópias escaladas do
-- PRÓPRIO sleeve e (b) cantoneiras em "L" desenhadas por código. As duas foram
-- REJEITADAS pelo dono e removidas:
--   • o halo de silhueta, sendo a arte retangular, não lia como brilho — lia
--     como uma cópia fantasma e desfocada do pacote atrás dele, indistinguível
--     de erro de renderização. Um halo com a forma do objeto só funciona com
--     silhueta recortada; com retângulo, não funciona.
--   • as cantoneiras de código dobravam as chapas que a arte JÁ tem pintadas,
--     transbordando a borda. Era redundância, não reforço.
-- Se for preciso destacar o pacote de novo, o sinal tem que ser algo que a arte
-- NÃO tem — e a regra é errar para MENOS.
--
-- O que sobrou, e por quê:
--   1) faíscas orbitando — discretas, ficam FORA da arte, não a cobrem;
--   2) reação de hover — o sleeve sobe, incha de leve e inclina. Feedback de
--      interação, que nenhuma arte estática pode dar sozinha;
-- E o que NAO sobrou: o booster shader, desligado por padrão (ver o comentário
-- em drawAt). Era a terceira camada sobre a arte e a última a cair.
--
-- HOVER: `drawAt` DETECTA o mouse sozinho a partir do retângulo que vai
-- desenhar. Nenhum chamador precisa mudar — quem quiser desligar passa
-- `opts.interactive = false` (é o que a cinemática de abertura faz, onde o
-- sleeve não é clicável).
--
-- Acessibilidade: com `_G.gameSettings.reducedMotion` some a OSCILAÇÃO
-- (respiração, tilt, órbita das faíscas) — a reação de hover permanece,
-- estática.

local PackSleeve = {}

local ImageCache    = require("src.ui.ImageCache")
local PixelCanvas   = require("src.ui.PixelCanvas")
local FontManager   = require("src.ui.FontManager")
local BoosterShader = require("src.ui.BoosterShader")
local PackThemes    = require("src.ui.PackThemes")

local SLEEVE_W, SLEEVE_H = 128, 192

-- Glyph/título só do fallback procedural (o PNG já traz o seu).
local PROCEDURAL_GLYPHS = {
    Standard  = "✦",
    Buffoon   = "♛",
    Arcana    = "☉",
    Celestial = "✧",
    Spectral  = "☠",
}

-- Cache de canvases procedurais por kind (evita regerar todo frame).
local proceduralCache = {}

-- Estado de hover por sleeve desenhado (chave = packId ou kind). Guarda o
-- valor interpolado 0..1 pra transição suave em vez de liga/desliga.
local hoverState = {}

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

-- Hash estável de string → 0..1. Usado pra dessincronizar a respiração e as
-- faíscas entre pacotes vizinhos na prateleira (sem isso todos pulsam juntos
-- e o efeito vira "a UI inteira piscando").
local function seedOf(key)
    local h = 0
    for i = 1, #key do
        h = (h * 31 + key:byte(i)) % 65536
    end
    return h / 65536
end

local function stateFor(key)
    local s = hoverState[key]
    if not s then
        s = { h = 0, seed = seedOf(key) }
        hoverState[key] = s
    end
    return s
end

-- Tenta achar PNG em assets/sprites/packs/<id>.png. Retorna Image ou nil.
local function tryLoadPNG(packId)
    if not packId then return nil end
    local path = "assets/sprites/packs/" .. packId .. ".png"
    if love.filesystem.getInfo(path) then
        return ImageCache.get(path)
    end
    return nil
end

-- Gera canvas procedural pra um kind. Cache por kind. Cores vêm do MESMO
-- tema do resto do efeito — fallback e PNG falam a mesma língua cromática.
local function buildProcedural(kind)
    if proceduralCache[kind] then return proceduralCache[kind] end
    local th = PackThemes.get(kind)

    local bg      = th.base
    local accent  = th.accent
    local outline = { bg[1] * 0.22, bg[2] * 0.22, bg[3] * 0.22, 1 }

    local W, H = SLEEVE_W, SLEEVE_H
    local canvas = love.graphics.newCanvas(W, H)
    local prevCanvas = love.graphics.getCanvas()
    love.graphics.setCanvas(canvas)
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)

    -- Fundo do envelope.
    PixelCanvas.rect(0, 0, W, H, bg)
    -- Borda dupla (outline grosso + accent fino dentro).
    PixelCanvas.rectOutline(0, 0, W, H, outline)
    PixelCanvas.rectOutline(2, 2, W - 4, H - 4, accent)
    PixelCanvas.rectOutline(4, 4, W - 8, H - 8, outline)

    -- "Selo" central — disco com glyph.
    local cx, cy = W * 0.5, H * 0.5
    love.graphics.setColor(outline)
    love.graphics.circle("fill", cx, cy, 28)
    love.graphics.setColor(accent)
    love.graphics.circle("fill", cx, cy, 24)
    love.graphics.setColor(outline)
    love.graphics.circle("line", cx, cy, 24)

    -- Glyph no selo.
    local glyph = PROCEDURAL_GLYPHS[kind] or PROCEDURAL_GLYPHS.Standard
    local glyphFont = FontManager.getFont(28)
    love.graphics.setFont(glyphFont)
    love.graphics.setColor(outline)
    local gw = glyphFont:getWidth(glyph)
    local gh = glyphFont:getHeight()
    love.graphics.print(glyph, cx - gw * 0.5, cy - gh * 0.5)

    -- Título empilhado embaixo.
    local titleFont = FontManager.getFont(10)
    love.graphics.setFont(titleFont)
    love.graphics.setColor(accent)
    -- th.label deixou de existir (virou labelKey + i18n). Sem isto o fallback
    -- procedural saia com o titulo em BRANCO, o que so apareceria no dia em que
    -- um PNG de sleeve sumisse -- exatamente quando ninguem esta olhando.
    love.graphics.printf(PackThemes.label(kind), 0, H - 36, W, "center")

    -- Cantos decorativos (4 pequenos rects nas pontas).
    for _, p in ipairs({
        {6, 6}, {W - 14, 6}, {6, H - 14}, {W - 14, H - 14},
    }) do
        PixelCanvas.rect(p[1], p[2], 8, 8, accent)
        PixelCanvas.rectOutline(p[1], p[2], 8, 8, outline)
    end

    love.graphics.pop()
    love.graphics.setCanvas(prevCanvas)

    proceduralCache[kind] = canvas
    return canvas
end

-- Retorna a Image (PNG do PixelLab OU canvas procedural) pra um pack.
-- Prioridade: PNG > procedural por kind > Standard fallback.
function PackSleeve.getImage(packId, kind)
    local png = tryLoadPNG(packId)
    if png then return png end
    return buildProcedural(kind or "Standard")
end

function PackSleeve.getDimensions()
    return SLEEVE_W, SLEEVE_H
end

-- O mouse está sobre o retângulo do sleeve desenhado em (cx, cy) com `scale`?
-- Exposto pra quem quiser sincronizar tooltip/cursor com a reação do sleeve.
function PackSleeve.isMouseOver(cx, cy, scale)
    if not (love.mouse and love.mouse.getPosition) then return false end
    scale = scale or 1
    local w = SLEEVE_W * scale * 0.5
    local h = SLEEVE_H * scale * 0.5
    local mx, my = love.mouse.getPosition()
    return mx >= cx - w and mx <= cx + w and my >= cy - h and my <= cy + h
end

-- ===========================================================================
-- Camadas do efeito
-- ===========================================================================

-- Faíscas: pontos numa órbita elíptica em volta do sleeve, cintilando fora de
-- fase. Quantidade e velocidade saem do tema (Celestial tem mais e mais
-- lentas; Bufão tem menos e rápidas).
local function drawSparkles(th, cx, cy, scale, alpha, hover, t, seed, still)
    local n = th.sparkles or 0
    if n <= 0 then return end
    local rx = SLEEVE_W * scale * 0.62
    local ry = SLEEVE_H * scale * 0.56
    local px = math.max(2, math.floor(2 * scale))
    local speed = still and 0 or (th.sparkleSpeed or 0.5)

    local prevMode, prevAlphaMode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add", "alphamultiply")
    for i = 1, n do
        local phase = seed * 6.2832 + i * (6.2832 / n)
        local ang = phase + t * speed
        local sx = cx + math.cos(ang) * rx
        local sy = cy + math.sin(ang * 1.3 + phase) * ry
        local tw = still and 0.7 or (0.5 + 0.5 * math.sin(t * 2.4 + i * 1.7 + seed * 10))
        local a = tw * (0.35 + 0.45 * hover) * alpha
        if a > 0.01 then
            love.graphics.setColor(th.glow[1], th.glow[2], th.glow[3], a)
            love.graphics.rectangle("fill", math.floor(sx), math.floor(sy), px, px)
            love.graphics.setColor(1, 1, 1, a * 0.55)
            love.graphics.rectangle("fill", math.floor(sx), math.floor(sy), 1, 1)
        end
    end
    love.graphics.setBlendMode(prevMode, prevAlphaMode)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ===========================================================================
-- Desenho principal
-- ===========================================================================

-- Desenha o sleeve (faíscas + arte com shader tingido).
-- (cx, cy) é o CENTRO. scale default 1. alpha default 1 — respeitada, nunca
-- sobrescrita (bug F7.5).
--
-- opts (tudo opcional; omitir = comportamento padrão de prateleira):
--   interactive — false desliga a auto-detecção de hover (default true)
--   hover       — força o estado de hover (0..1 ou bool), ignora o mouse
--   rotation    — tilt extra em rad (a cinemática usa no wobble pré-estouro)
--   sparkles    — false desliga as faíscas
--   shader      — true RELIGA o booster shader (default: DESLIGADO, ver abaixo)
--   key         — chave própria pro estado de hover (default packId/kind)
--   phase       — congela a fase do booster shader (default = relógio). Sem
--                 isso a captura sai não-determinística: a faixa de foil está
--                 onde o relógio deixou, e medir "quanto o shader desvia da
--                 arte" vira sorteio
function PackSleeve.drawAt(packId, kind, cx, cy, scale, alpha, opts)
    scale = scale or 1
    alpha = alpha == nil and 1 or alpha
    if alpha <= 0.001 then return end

    local img = PackSleeve.getImage(packId, kind)
    if not img then return end

    opts = opts or {}
    local th    = PackThemes.get(kind)
    local still = reducedMotion()
    local t     = love.timer and love.timer.getTime() or 0
    local dt    = (love.timer and love.timer.getDelta and love.timer.getDelta()) or 0
    local key   = opts.key or tostring(packId or kind or "pack")
    local st    = stateFor(key)

    -- Alvo de hover: forçado pelo chamador, detectado no mouse, ou desligado.
    local target
    if opts.hover ~= nil then
        target = (opts.hover == true and 1) or (opts.hover == false and 0) or opts.hover
    elseif opts.interactive == false then
        target = 0
    else
        target = PackSleeve.isMouseOver(cx, cy, scale) and 1 or 0
    end
    -- Lerp enquadrado (12/s) — sem isso o sleeve "pula" ao entrar/sair.
    local k = math.min(1, dt * 12)
    st.h = st.h + (target - st.h) * k
    local hover = st.h

    -- Respiração e pulso do halo. Dessincronizados por seed.
    local seed = st.seed
    local breathe = still and 0
        or math.sin(t * 1.7 + seed * 6.2832) * 0.012 * (1 - 0.5 * hover)
    local drawScale = scale * (1 + 0.055 * hover + breathe)
    local lift = -5 * hover
    local rot = (opts.rotation or 0)
        + (still and 0 or math.sin(t * 5.5 + seed * 3) * 0.035 * hover)
    local dy = cy + lift

    -- 1) faíscas (fora da silhueta, nunca por cima da ilustração)
    if opts.sparkles ~= false then
        drawSparkles(th, cx, dy, scale, alpha, hover, t, seed, still)
    end

    -- 2) a arte, com o booster shader iridescente
    -- ARTE PURA POR PADRÃO (Set/2026). O booster shader ficou DESLIGADO aqui
    -- por decisão tomada em cima de uma comparação lado a lado (a folha de 3
    -- linhas de `love . screenshot_packopen shelf`, linha "ARTE PURA"):
    --   Arcano   puro = azul-real com olho dourado vivo | com shader = roxo lavado
    --   Celestial puro = azul-noite, lua e prata nítidas | com shader = embaçado
    --   Bufão    puro = carmim com máscara em ouro vivo | com shader = arroseado
    --   Padrão   puro = pergaminho, tiras escuras, lacre | com shader = névoa rosada
    --   Espectral puro = verde com caveira em contraste  | com shader = menta lavado
    -- O argumento que fechou a questão não foi gosto: o shader aplicava a MESMA
    -- listra diagonal nos cinco. A rodada inteira foi gastar esforço criando
    -- identidade POR TIPO (bursts dedicados, temas, cores próprias) e esse
    -- efeito uniformizava tudo por cima — trabalhava contra o próprio objetivo.
    --
    -- NÃO religue isto achando que é melhoria. Se um dia quiserem foil de
    -- verdade, o lugar dele é numa CARTA com edition, não no envelope.
    -- Consequência: `sheen`/`sheen_amt` em shaders/booster.glsl viraram CAMINHO
    -- MORTO no uso normal (o arquivo segue compilando e testado, mas ninguém o
    -- aplica). Mantidos pra não quebrar quem passar `shader = true`.
    local ox, oy = img:getWidth() * 0.5, img:getHeight() * 0.5
    if opts.shader == true and BoosterShader.isAvailable() then
        BoosterShader.apply(img, opts.phase or t, 0, th.glow, th.sheenAmt or 0.5)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(img, cx, dy, rot, drawScale, drawScale, ox, oy)
        BoosterShader.clear()
    else
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(img, cx, dy, rot, drawScale, drawScale, ox, oy)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return PackSleeve
