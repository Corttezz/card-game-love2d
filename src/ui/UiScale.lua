-- src/ui/UiScale.lua
-- ESCALA GLOBAL DA INTERFACE (Out/2026 — auditoria de UI: "em 1080p pouco
-- escala e em 1440p nada escala"; carta ~7% da altura, texto ilegível,
-- miniaturas de 60px numa estante vazia).
--
-- A ideia: as telas de UI foram desenhadas pra ~1280x720. Em vez de reescrever
-- o layout de cada uma com um fator, elas passam a viver num ESPAÇO VIRTUAL
-- do tamanho da janela dividido por k, desenhado com love.graphics.scale(k).
-- Dentro do contexto:
--   * love.graphics.getWidth/getHeight/getDimensions devolvem o tamanho
--     VIRTUAL (todo layout das telas deriva deles — as zonas continuam zonas);
--   * love.mouse.getPosition/getX/getY devolvem o mouse VIRTUAL (o hover por
--     polling — 40+ call sites — funciona sem mudar nenhum);
--   * setScissor/intersectScissor/getScissor convertem pra pixels reais
--     (scissor ignora a transformação — o defeito clássico de UI escalada);
--   * FontManager rasteriza a fonte com dpiscale = escala corrente, então o
--     texto sai NÍTIDO no tamanho final, não um bitmap pequeno esticado.
--
--   k = clamp(min(W/1280, H/720), 1, 2.5) × multiplicador do jogador
--       (Configurações → Vídeo: 80% / 90% / Auto / 125% / 150%)
--
-- Quem entra no contexto: as telas ADOTADAS (UiScale.adopt) — todo método da
-- classe roda dentro dele (show/resize/update/draw/input), então layout
-- calculado no show() e hit-test no clique enxergam o mesmo espaço. Mouse
-- handlers (mousepressed/released/moved) recebem as coordenadas convertidas
-- quando a chamada vem de FORA do contexto (main.lua passa pixels reais).
--
-- Quem NÃO entra (por enquanto): o HUD de batalha e a mão (GameplayScene) —
-- outras frentes estão mexendo lá. `UiScale.k()` já está exposto pra quando
-- a batalha adotar. A TopBar escala fora da batalha (predicado chrome).

local UiScale = {}

UiScale.BASE_W, UiScale.BASE_H = 1280, 720
UiScale.MIN_AUTO, UiScale.MAX_AUTO = 1, 2.5
-- Multiplicadores oferecidos nas Configurações (1 = Auto). Relativos ao Auto
-- de propósito: um "150%" ABSOLUTO seria MENOR que o Auto num monitor 4K.
UiScale.OPTIONS = { 0.8, 0.9, 1, 1.25, 1.5 }

local userMul = 1
local forcedK = nil          -- testes: UiScale.force(1) congela o espaço
local depth = 0
local saved = nil            -- funções originais enquanto o contexto vale
local activeK = 1
local vw, vh = 0, 0
local chromeScaled = true    -- TopBar/tooltips de chrome escalam? (main.lua)

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

function UiScale.setUserMultiplier(m)
    m = tonumber(m) or 1
    if m <= 0 then
        print("[UiScale] multiplicador invalido (" .. tostring(m) .. "), usando 1")
        m = 1
    end
    userMul = m
end
function UiScale.userMultiplier() return userMul end

function UiScale.force(k) forcedK = k end

-- Fator automático para uma janela (puro).
function UiScale.auto(w, h)
    return clamp(math.min(w / UiScale.BASE_W, h / UiScale.BASE_H),
        UiScale.MIN_AUTO, UiScale.MAX_AUTO)
end

-- Fator efetivo para a janela atual (ou w,h dados). Fora do contexto lê a
-- janela de verdade (ou a falsificada pelos tools/testes).
function UiScale.k(w, h)
    if forcedK then return forcedK end
    if not w then
        if depth > 0 then return activeK end
        w, h = love.graphics.getWidth(), love.graphics.getHeight()
    end
    -- degraus de 1/4: fonte pixel e arte nearest ficam com blocos iguais
    -- (1366x768 daria 1.067 — tudo 7% maior e serrilhado à toa → 1)
    local k = math.floor(UiScale.auto(w, h) * userMul * 4 + 0.001) / 4
    return clamp(k, 0.75, 3)
end

-- Escala do contexto corrente (1 fora dele).
function UiScale.activeK() return depth > 0 and activeK or 1 end
function UiScale.isActive() return depth > 0 end

function UiScale.setChromeScaled(b) chromeScaled = b and true or false end
function UiScale.chromeScaled() return chromeScaled end
-- Fator que a TopBar usa AGORA (1 na batalha).
function UiScale.chromeK() return chromeScaled and UiScale.k() or 1 end

-- Converte coordenadas de tela → virtuais (k da janela atual).
function UiScale.toVirtual(x, y)
    local k = UiScale.k()
    return x / k, y / k
end

-- ===== contexto =====
local function patch(k)
    local g, m = love.graphics, love.mouse
    saved = {
        gw = g.getWidth, gh = g.getHeight, gd = g.getDimensions,
        ss = g.setScissor, is = g.intersectScissor, gs = g.getScissor,
        mp = m.getPosition, mx = m.getX, my = m.getY, msp = m.setPosition,
    }
    local W, H = saved.gw(), saved.gh()
    vw, vh = math.floor(W / k + 0.5), math.floor(H / k + 0.5)
    local s = saved
    g.getWidth = function() return vw end
    g.getHeight = function() return vh end
    g.getDimensions = function() return vw, vh end
    g.setScissor = function(x, y, w, h)
        if x == nil then return s.ss() end
        return s.ss(math.floor(x * k), math.floor(y * k), math.ceil(w * k), math.ceil(h * k))
    end
    g.intersectScissor = function(x, y, w, h)
        return s.is(math.floor(x * k), math.floor(y * k), math.ceil(w * k), math.ceil(h * k))
    end
    g.getScissor = function()
        local x, y, w, h = s.gs()
        if not x then return nil end
        return x / k, y / k, w / k, h / k
    end
    -- a leitura crua passa pela lente do CRT (InputFocus.installMouseGate →
    -- CRTShader.screenToContent), que mede a JANELA: ela precisa ver as
    -- dimensões reais durante a leitura, senão o mapeamento entorta
    local function rawMouse()
        local cw, ch, cd = g.getWidth, g.getHeight, g.getDimensions
        g.getWidth, g.getHeight, g.getDimensions = s.gw, s.gh, s.gd
        local ok, x, y = pcall(s.mp)
        g.getWidth, g.getHeight, g.getDimensions = cw, ch, cd
        if not ok then error(x, 0) end
        return x, y
    end
    m.getPosition = function()
        local x, y = rawMouse()
        return x / k, y / k
    end
    m.getX = function() local x = rawMouse(); return x / k end
    m.getY = function() local _, y = rawMouse(); return y / k end
    m.setPosition = function(x, y) return s.msp(x * k, y * k) end
end

local function unpatch()
    local g, m, s = love.graphics, love.mouse, saved
    g.getWidth, g.getHeight, g.getDimensions = s.gw, s.gh, s.gd
    g.setScissor, g.intersectScissor, g.getScissor = s.ss, s.is, s.gs
    m.getPosition, m.getX, m.getY, m.setPosition = s.mp, s.mx, s.my, s.msp
    saved = nil
end

-- Entra no contexto (aninhável). `k` opcional força o fator (tooltip que
-- nasceu num contexto e desenha depois, fora dele).
function UiScale.begin(k)
    if depth > 0 then depth = depth + 1 return end
    activeK = k or UiScale.k()   -- ANTES de subir a profundidade (k() lê activeK dentro)
    depth = 1
    if activeK == 1 then return end   -- caminho rápido: espaço = tela
    patch(activeK)
    love.graphics.push()
    love.graphics.scale(activeK)
end

function UiScale.finish()
    if depth <= 0 then return end
    depth = depth - 1
    if depth > 0 then return end
    if saved then
        love.graphics.pop()
        unpatch()
    end
    activeK = 1
end

-- Higiene de frame (como InputFocus.resetLayers): um erro no meio de um
-- método adotado deixaria as funções globais trocadas pra sempre.
function UiScale.reset()
    if depth > 0 then
        print("[UiScale] contexto vazou (profundidade " .. depth .. ") — restaurando")
        if saved then
            pcall(love.graphics.pop)
            unpatch()
        end
        depth, activeK = 0, 1
    end
end

-- Roda fn FORA do contexto (de dentro de um método adotado). Uso: chamar
-- love.resize a partir das Configurações — o resize global recria canvases
-- e layouts da batalha, que precisam da janela REAL. Só de input/update
-- (nunca no meio de um draw com push próprio por cima do nosso).
function UiScale.outside(fn, ...)
    if depth == 0 then return fn(...) end
    local d, k = depth, activeK
    if saved then
        love.graphics.pop()
        unpatch()
    end
    depth, activeK = 0, 1
    local res = { pcall(fn, ...) }
    depth, activeK = d, k
    if k ~= 1 then
        patch(k)
        love.graphics.push()
        love.graphics.scale(k)
    end
    if not res[1] then error(res[2], 0) end
    return unpack(res, 2, table.maxn(res))
end

-- Dimensões REAIS da janela, mesmo dentro do contexto.
function UiScale.realDimensions()
    if saved then return saved.gw(), saved.gh() end
    return love.graphics.getWidth(), love.graphics.getHeight()
end

-- Roda fn dentro do contexto, restaurando mesmo em erro (que é relançado).
function UiScale.run(fn, ...)
    UiScale.begin()
    local res = { pcall(fn, ...) }
    UiScale.finish()
    if not res[1] then error(res[2], 0) end
    return unpack(res, 2)
end

-- ===== adoção =====
local MOUSE = { mousepressed = true, mousereleased = true, mousemoved = true }

-- Embrulha TODOS os métodos de `tbl` pra rodarem no contexto.
--   opts.method    true (default) = funções chamadas com ':' (self primeiro)
--   opts.predicate função opcional: só escala quando devolve true
-- Idempotente (marca a tabela).
function UiScale.adopt(tbl, opts)
    if type(tbl) ~= "table" or rawget(tbl, "__uiScaleAdopted") then return tbl end
    opts = opts or {}
    local method = opts.method ~= false
    local pred = opts.predicate
    local names = {}
    for name, fn in pairs(tbl) do
        if type(fn) == "function" and name ~= "__index" then names[#names + 1] = name end
    end
    for _, name in ipairs(names) do
        local fn = tbl[name]
        local isMouse = MOUSE[name]
        tbl[name] = function(...)
            -- já dentro do contexto (chamada aninhada): nada a fazer — as
            -- coordenadas já são virtuais
            if depth > 0 or (pred and not pred()) then return fn(...) end
            UiScale.begin()
            local args, n = { ... }, select("#", ...)
            if isMouse and activeK ~= 1 then
                local i = method and 2 or 1
                if type(args[i]) == "number" then args[i] = args[i] / activeK end
                if type(args[i + 1]) == "number" then args[i + 1] = args[i + 1] / activeK end
            end
            local res = { xpcall(fn, debug.traceback, unpack(args, 1, n)) }
            if not res[1] then
                UiScale.reset()
                error(res[2], 0)
            end
            UiScale.finish()
            return unpack(res, 2, table.maxn(res))
        end
    end
    rawset(tbl, "__uiScaleAdopted", true)
    return tbl
end

-- As telas de UI do jogo (a batalha entra por MODULES). A TopBar tem
-- predicado (chromeScaled) — hoje sempre ligado. TELA NOVA DE UI: entra aqui
-- no mesmo commit.
UiScale.SCREENS = {
    "components.Menu", "components.ClassSelectionScreen",
    "components.CardRewardScreen", "components.CollectionScreen",
    "components.AchievementsScreen", "components.CreditsScreen",
    "components.DeckViewerScreen", "components.JokerManagerScreen",
    "components.RunJournalScreen", "components.ScribeDiceScreen",
    "components.MapScreen", "components.RestScreen",
    "components.EventScreen", "components.PackOpenScreen",
    "components.RoundEvalScreen", "components.PauseMenu",
    "components.SettingsMenu",
}
UiScale.MODULES = { "src.scenes.EndScreens", "src.ui.ConfirmDialog", "src.ui.AchievementToast",
    -- batalha: a CENA é adotada (mão/HUD/botões); o mundo dentro dela roda
    -- em UiScale.outside (ver o cabeçalho de GameplayScene)
    "src.scenes.GameplayScene" }

function UiScale.adoptDefaults()
    for _, mod in ipairs(UiScale.SCREENS) do
        local ok, m = pcall(require, mod)
        if ok then UiScale.adopt(m)
        else print("[UiScale] tela nao carregou, fica sem escala: " .. mod .. " (" .. tostring(m) .. ")") end
    end
    for _, mod in ipairs(UiScale.MODULES) do
        UiScale.adopt(require(mod), { method = false })
    end
    UiScale.adopt(require("components.TopBar"), { predicate = UiScale.chromeScaled })
end

-- Escala de transformação corrente (para a fonte nítida). Só consultada
-- dentro do contexto — fora dele (batalha) a fonte não muda.
function UiScale.fontDpi()
    if depth == 0 or activeK == 1 then return 1 end
    local x0 = love.graphics.transformPoint(0, 0)
    local x1 = love.graphics.transformPoint(1, 0)
    local s = math.abs(x1 - x0)
    -- degraus de 0.25: animação de escala (hover, entrada) não cria uma fonte
    -- por frame; e nunca abaixo de 1 (canvas com origin() desenha em 1:1)
    return math.max(1, math.min(3, math.floor(s * 4 + 0.5) / 4))
end

return UiScale
