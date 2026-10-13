-- src/ui/shop/ShopProps.lua
-- PROPS VIVOS do Balcão do Mercador (Loja v3, F3, Out/2026). Módulo PURO de
-- desenho: não sabe de layout, de ofertas nem de input — a cena
-- (src/ui/shop/ShopScene.lua, frente loja-cena) decide ONDE cada prop fica
-- e chama update/draw. Zero regra de economia aqui.
--
-- API
--   ShopProps.lantern.new()                      -> lanterna
--     :update(dt, lookX)   lookX em [-1, 1]: a poça de luz "olha" pro objeto
--                          em hover, em DEGRAUS (LOOK_STEPS) perseguidos a
--                          LOOK_RATE passos/s. nil = volta ao centro.
--     :draw(x, y, scale)   x,y = ponto do GANCHO (topo-centro do sprite).
--                          Desenha poça de luz + poeira + sprite, nessa ordem.
--     :drawLight(x, y, s)  só a luz (poça em 3 degraus aditivos + halo da
--                          chama + poeira no feixe, 1 SpriteBatch) — pra cena
--                          que quer a luz ATRÁS das prateleiras e a lanterna
--                          na frente.
--     :drawSprite(x, y, s) só a lanterna.
--     :lightCenter(x,y,s)  -> cx, cy, r da poça (pra cena alinhar sombras).
--     campos lidos por teste/preview: frame (1..3), level (índice em
--     LEVELS), lookStep (inteiro em -LOOK_STEPS..LOOK_STEPS).
--
--   ShopProps.diceCup.new()                      -> copo dos Dados do Escriba
--     :setState("idle" | "shake" | "rolled", { a = 1..6, b = 1..6 })
--                          shake = hover (3 quadros + `sceneWoodKnock`
--                          baixo UMA vez por entrada); rolled = copo DEITADO
--                          e os dois dados JOGADOS no balcão com as faces.
--     :syncRun(run)        lê currentRun.scribeDice (ScribeDice.state) e
--                          entra em rolled com a soma da visita, ou idle.
--     :update(dt) / :draw(x, y, scale)   x,y = PÉ do copo (base-centro).
--     :width(scale)        largura ocupada (copo + dados quando rolled).
--
--   ShopProps.moth.new()                         -> mariposa
--     :update(dt)          agenda uma travessia a cada MOTH_MIN..MOTH_MAX s.
--     :draw(fx, fy, scale) fx,fy = centro da CHAMA (ShopProps.lantern.flameAt).
--     :isFlying() / :cross()   (preview e teste forçam a travessia)
--
--   ShopProps.cobweb.draw(x, y, scale)           teia estática, canto sup-esq.
--   ShopProps.saleTag.draw(x, y, scale)          etiqueta vermelha torta da
--                          oferta do dia (o TEXTO do preço é da cena).
--   ShopProps.missingAssets()                    -> lista de PNGs ausentes
--                          (fallback silencioso é proibido: cada miss AVISA
--                          uma vez e o teste falha se a lista não for vazia).
--
-- reducedMotion (_G.gameSettings.reducedMotion): chama no quadro 1, luz no
-- nível médio, poeira parada, copo sem chacoalho, mariposa POUSADA na
-- lanterna. Dados jogados e copo deitado continuam: são informação.
--
-- Doutrina: tudo em DEGRAUS (quadro, nível de luz, passo da poça, pulso da
-- poeira) — mesma vida do menu v3 e do LuminaireEngine; nada interpola.

local ImageCache = require("src.ui.ImageCache")
local Palette    = require("src.ui.Palette")
local Sfx        = require("src.systems.Sfx")

local ShopProps = {}

ShopProps.ASSETS = {
    lantern  = "assets/sprites/shop/lantern.png",         -- 32x48 x3
    diceCup  = "assets/sprites/shop/dice_cup.png",        -- 32x32 x5
    dieFaces = "assets/sprites/shop/die_faces.png",       -- 16x16 x6
    moth     = "assets/sprites/shop/moth.png",            -- 16x16 x4
    cobweb   = "assets/sprites/shop/cobweb.png",          -- 32x32
    saleTag  = "assets/sprites/shop/price_tag_sale.png",  -- 24x16
}

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) and true or false
end

-- ---------------------------------------------------------------------------
-- Sheets horizontais: quadro i em x = (i-1)*fw. Miss avisa UMA vez.
-- ---------------------------------------------------------------------------
local sheets = {}
local warned = {}

local function sheet(key, fw, fh)
    local s = sheets[key]
    if s then return s end
    local path = ShopProps.ASSETS[key]
    local img = ImageCache.tryGet(path)
    if not img then
        if not warned[key] then
            warned[key] = true
            print("[ShopProps] asset ausente: " .. tostring(path) .. " (prop '" .. key .. "' não desenha)")
        end
        return nil
    end
    img:setFilter("nearest", "nearest")
    local iw, ih = img:getDimensions()
    fw, fh = fw or iw, fh or ih
    local n = math.max(1, math.floor(iw / fw))
    if iw % fw ~= 0 or ih ~= fh then
        print(("[ShopProps] %s tem %dx%d, esperado múltiplo de %dx%d"):format(path, iw, ih, fw, fh))
    end
    local quads = {}
    for i = 1, n do
        quads[i] = love.graphics.newQuad((i - 1) * fw, 0, fw, fh, iw, ih)
    end
    s = { img = img, quads = quads, n = n, fw = fw, fh = fh }
    sheets[key] = s
    return s
end

local function drawFrame(s, i, x, y, scale, r, ox, oy)
    i = math.max(1, math.min(s.n, i))
    love.graphics.draw(s.img, s.quads[i], x, y, r or 0, scale, scale, ox or 0, oy or 0)
end

function ShopProps.missingAssets()
    local out = {}
    for key, path in pairs(ShopProps.ASSETS) do
        local info = love.filesystem.getInfo(path)
        if not info then out[#out + 1] = path end
    end
    table.sort(out)
    return out
end

-- textura 1x1 branca pro SpriteBatch da poeira (um só pra todas as lanternas)
local dot
local function dotImage()
    if dot then return dot end
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, 1, 1, 1, 1)
    dot = love.graphics.newImage(data)
    dot:setFilter("nearest", "nearest")
    return dot
end

-- ===========================================================================
-- LANTERNA
-- ===========================================================================
local Lantern = {}
Lantern.__index = Lantern

Lantern.FW, Lantern.FH = 32, 48
Lantern.FLAME = { x = 15.5, y = 31 }   -- centro da chama no sprite (cand_0)
Lantern.LEVELS = { 0.82, 1.00, 1.14 }  -- intensidade da luz, só estes 3 valores
Lantern.HOLDS = { 0.08, 0.12, 0.18, 0.26 } -- quanto um quadro/nível SEGURA (s)
Lantern.LOOK_STEPS = 2                 -- a poça anda -2..2 passos
Lantern.LOOK_PX = 7                    -- px (de sprite) por passo
Lantern.LOOK_RATE = 4                  -- passos por segundo (perseguição)
Lantern.POOL_DY = 30                   -- centro da poça abaixo da chama
Lantern.POOL_RX, Lantern.POOL_RY = 34, 19
Lantern.DUST_N = 18
Lantern.DUST_DEPTH = 72                -- feixe: da chama até POOL_DY+... (px de sprite)
Lantern.AMBER = { 1.00, 0.72, 0.36 }

local function newMote(i)
    local depth = love.math.random() * Lantern.DUST_DEPTH
    return {
        y = depth,
        x = (love.math.random() - 0.5) * 2 * (5 + depth * 0.45),
        speed = 2.5 + love.math.random() * 4.5,  -- px/s (sobe devagar)
        drift = (love.math.random() - 0.5) * 2.0,
        phase = i * 0.37,
        size = love.math.random() < 0.3 and 2 or 1,
    }
end

function ShopProps.newLantern()
    local l = setmetatable({}, Lantern)
    l.frame = 1
    l.level = 2
    l.hold = 0
    l.lookStep = 0
    l.lookTarget = 0
    l.lookTimer = 0
    l.clock = 0
    l.motes = {}
    for i = 1, Lantern.DUST_N do l.motes[i] = newMote(i) end
    l.batch = love.graphics.newSpriteBatch(dotImage(), Lantern.DUST_N, "stream")
    return l
end

function Lantern:update(dt, lookX)
    self.clock = self.clock + dt
    -- alvo da poça em degraus (nil/0 = centro)
    local target = 0
    if lookX then
        lookX = math.max(-1, math.min(1, lookX))
        target = math.floor(lookX * Lantern.LOOK_STEPS + 0.5)
    end
    self.lookTarget = target
    if reducedMotion() then
        -- sem movimento: chama parada, luz no nível médio, poça vai direto
        -- pro alvo (informação de "qual objeto" continua), poeira parada.
        self.frame, self.level = 1, 2
        self.lookStep = target
        return
    end
    -- perseguição a LOOK_RATE passos/s, um passo por vez (nunca contínua)
    if self.lookStep ~= target then
        self.lookTimer = self.lookTimer + dt
        if self.lookTimer >= 1 / Lantern.LOOK_RATE then
            self.lookTimer = 0
            self.lookStep = self.lookStep + (target > self.lookStep and 1 or -1)
        end
    else
        self.lookTimer = 0
    end
    -- flicker em degraus: segura um quadro/nível por HOLDS[k] e troca seco
    self.hold = self.hold - dt
    if self.hold <= 0 then
        local r = love.math.random()
        self.frame = r < 0.5 and 1 or (r < 0.78 and 2 or 3)
        local lv = love.math.random()
        self.level = lv < 0.6 and 2 or (lv < 0.85 and 1 or 3)
        self.hold = Lantern.HOLDS[love.math.random(#Lantern.HOLDS)]
    end
    -- poeira: sobe devagar dentro do feixe, pulso de brilho a 4 Hz (degrau)
    for _, m in ipairs(self.motes) do
        m.y = m.y - m.speed * dt
        m.x = m.x + m.drift * dt
        local hw = 5 + math.max(0, m.y) * 0.45
        if m.y < 4 then
            m.y = Lantern.DUST_DEPTH
            m.x = (love.math.random() - 0.5) * 2 * (5 + m.y * 0.45)
        end
        if m.x < -hw then m.x = -hw; m.drift = math.abs(m.drift)
        elseif m.x > hw then m.x = hw; m.drift = -math.abs(m.drift) end
    end
end

function Lantern:intensity()
    return Lantern.LEVELS[self.level] or 1
end

-- centro da chama na tela
function Lantern:flameAt(x, y, scale)
    return x + (Lantern.FLAME.x - Lantern.FW / 2) * scale, y + Lantern.FLAME.y * scale
end

function Lantern:lightCenter(x, y, scale)
    local fx, fy = self:flameAt(x, y, scale)
    return fx + self.lookStep * Lantern.LOOK_PX * scale,
           fy + Lantern.POOL_DY * scale,
           Lantern.POOL_RX * scale
end

function Lantern:drawLight(x, y, scale, opts)
    scale = scale or 1
    local pool = not (opts and opts.pool == false)
    local k = self:intensity()
    local a = Lantern.AMBER
    local fx, fy = self:flameAt(x, y, scale)
    local cx, cy = self:lightCenter(x, y, scale)
    love.graphics.setBlendMode("add")
    -- poça: 3 elipses DEGRAU (nada de gradiente), deslocadas pelo lookStep
    for step = 0, (pool and 2 or -1) do
        local f = 1 - step * 0.30
        love.graphics.setColor(a[1], a[2], a[3], (0.05 + 0.025 * step) * k)
        love.graphics.ellipse("fill", math.floor(cx), math.floor(cy),
            Lantern.POOL_RX * scale * f, Lantern.POOL_RY * scale * f, 24)
    end
    -- halo da chama: 2 anéis curtos
    for step = 0, 1 do
        love.graphics.setColor(a[1], a[2] + 0.1, a[3], (0.06 + 0.05 * step) * k)
        love.graphics.circle("fill", math.floor(fx), math.floor(fy), (14 - step * 6) * scale, 16)
    end
    -- poeira no feixe: 1 SpriteBatch, posição inteira, brilho em degrau
    local batch = self.batch
    batch:clear()
    local pulse = math.floor(self.clock * 4) % 2 == 0 and 1 or 0
    for _, m in ipairs(self.motes) do
        local tw = 0.28 + 0.16 * (((math.floor(m.phase * 10) + pulse) % 2))
        batch:setColor(a[1], a[2] + 0.12, a[3] + 0.2, tw * k)
        batch:add(math.floor(fx + m.x * scale), math.floor(fy + m.y * scale), 0,
            m.size * scale, m.size * scale)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(batch)
    love.graphics.setBlendMode("alpha")
end

function Lantern:drawSprite(x, y, scale)
    scale = scale or 1
    local s = sheet("lantern", Lantern.FW, Lantern.FH)
    if not s then return end
    love.graphics.setColor(1, 1, 1, 1)
    drawFrame(s, self.frame, math.floor(x - Lantern.FW / 2 * scale), math.floor(y), scale)
end

function Lantern:draw(x, y, scale)
    self:drawLight(x, y, scale)
    self:drawSprite(x, y, scale)
end

ShopProps.lantern = { new = ShopProps.newLantern, flameAt = function(x, y, s)
    return x + (Lantern.FLAME.x - Lantern.FW / 2) * s, y + Lantern.FLAME.y * s
end, Lantern = Lantern }

-- ===========================================================================
-- COPO DE DADOS
-- ===========================================================================
local DiceCup = {}
DiceCup.__index = DiceCup
DiceCup.FW, DiceCup.FH = 32, 32
DiceCup.DIE = 16
DiceCup.SHAKE_FPS = 11
DiceCup.FRAME_IDLE, DiceCup.FRAME_SHAKE, DiceCup.FRAME_LYING = 1, { 2, 3, 4 }, 5
DiceCup.STATES = { idle = true, shake = true, rolled = true }

function ShopProps.newDiceCup()
    local c = setmetatable({}, DiceCup)
    c.state = "idle"
    c.frame = 1
    c.t = 0
    c.dice = nil
    return c
end

function DiceCup:setState(state, opts)
    if not DiceCup.STATES[state] then
        print("[ShopProps] estado de copo desconhecido: " .. tostring(state))
        return
    end
    if state == "rolled" then
        local a = opts and tonumber(opts.a)
        local b = opts and tonumber(opts.b)
        if not a or not b or a < 1 or a > 6 or b < 1 or b > 6 then
            print("[ShopProps] rolled sem faces válidas (a=" .. tostring(a) .. ", b=" .. tostring(b) .. ")")
            return
        end
        self.dice = { math.floor(a), math.floor(b) }
    elseif self.state == "rolled" then
        -- copo deitado só levanta quando a visita muda (syncRun com mesa livre)
        self.dice = nil
    end
    if state == "shake" and self.state ~= "shake" and not reducedMotion() then
        Sfx.play("sceneWoodKnock", { volume = 0.35, pitch = 1.25 })
    end
    self.state = state
    self.t = 0
    self.frame = state == "rolled" and DiceCup.FRAME_LYING or DiceCup.FRAME_IDLE
end

-- Lê o estado da visita (memory/scribe_dice.md): jogada feita neste nó →
-- copo deitado com as faces; senão, de pé.
function DiceCup:syncRun(run)
    local ScribeDice = require("src.systems.ScribeDice")
    local st = ScribeDice.state(run)
    if st and st.used and st.dice then
        if self.state ~= "rolled" or not self.dice
            or self.dice[1] ~= st.dice[1] or self.dice[2] ~= st.dice[2] then
            self:setState("rolled", { a = st.dice[1], b = st.dice[2] })
        end
        return true
    end
    if self.state == "rolled" then self:setState("idle") end
    return false
end

function DiceCup:update(dt)
    self.t = self.t + dt
    if self.state == "shake" then
        if reducedMotion() then
            self.frame = DiceCup.FRAME_IDLE
        else
            local i = math.floor(self.t * DiceCup.SHAKE_FPS) % #DiceCup.FRAME_SHAKE + 1
            self.frame = DiceCup.FRAME_SHAKE[i]
        end
    elseif self.state == "rolled" then
        self.frame = DiceCup.FRAME_LYING
    else
        self.frame = DiceCup.FRAME_IDLE
    end
end

function DiceCup:width(scale)
    scale = scale or 1
    if self.state == "rolled" then
        return (DiceCup.FW + 6 + DiceCup.DIE * 2 + 4) * scale
    end
    return DiceCup.FW * scale
end

-- x,y = PÉ do copo (base-centro). Dados jogados à direita, ao longo da
-- diagonal da mesa (`opts.slope`). Sem sombra aqui: a loja desenha a sombra
-- de CONTATO (ShopPerspective, dither colado na base; elipse = flutuando).
-- `opts.outline` 0..1 = contorno claro de 1 px (hover).
function DiceCup:draw(x, y, scale, opts)
    scale = scale or 1
    opts = opts or {}
    local slope = opts.slope or 0
    local s = sheet("diceCup", DiceCup.FW, DiceCup.FH)
    if not s then return end
    local cx = math.floor(x - DiceCup.FW / 2 * scale)
    local cy = math.floor(y - DiceCup.FH * scale)
    if (opts.outline or 0) > 0.01 and opts.silhouette then
        love.graphics.setShader(opts.silhouette)
        local c = Palette.PARCHMENT_LIGHT
        love.graphics.setColor(c[1], c[2], c[3], opts.outline)
        for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            drawFrame(s, self.frame, cx + d[1], cy + d[2], scale)
        end
        love.graphics.setShader()
    end
    love.graphics.setColor(1, 1, 1, 1)
    drawFrame(s, self.frame, cx, cy, scale)
    -- dados: jogados (rolled) ou um dado de enfeite parado (opts.idleDie,
    -- Loja v5: o copo sozinho lia como uma CANECA sem preço). opts.dicePos =
    -- posições {dx, dy} do PÉ de cada dado relativas ao pé do copo (a loja
    -- põe os dados À FRENTE do copo, longe do sino); sem ela, à direita.
    local show = (self.state == "rolled" and self.dice) and self.dice
        or (opts.idleDie and { opts.idleDie }) or nil
    if show then
        local faces = sheet("dieFaces", DiceCup.DIE, DiceCup.DIE)
        if faces then
            local off = (DiceCup.FW / 2 + 6) * scale
            for i = 1, #show do
                local p = opts.dicePos and opts.dicePos[i]
                local dx, dy
                if p then
                    dx = math.floor(x + p[1] * scale - DiceCup.DIE / 2 * scale)
                    dy = math.floor(y + p[2] * scale + slope * p[1] * scale - DiceCup.DIE * scale)
                else
                    dx = math.floor(x + off)
                    dy = math.floor(y + slope * off - (DiceCup.DIE + 2) * scale)
                end
                love.graphics.setColor(1, 1, 1, 1)
                drawFrame(faces, show[i], dx, dy, scale)
                off = off + (DiceCup.DIE + 4) * scale
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

ShopProps.diceCup = { new = ShopProps.newDiceCup, DiceCup = DiceCup }

-- ===========================================================================
-- MARIPOSA
-- ===========================================================================
local Moth = {}
Moth.__index = Moth
Moth.FW, Moth.FH = 16, 16
Moth.MIN_WAIT, Moth.MAX_WAIT = 20, 40
Moth.SPAN = 110        -- px de sprite de cada lado da chama
Moth.SPEED = 46        -- px/s
Moth.FPS = 14
Moth.PERCH = { x = 14, y = 6 }  -- pouso em reducedMotion (relativo à chama)

function ShopProps.newMoth()
    local m = setmetatable({}, Moth)
    m.wait = Moth.MIN_WAIT + love.math.random() * (Moth.MAX_WAIT - Moth.MIN_WAIT)
    m.flying = false
    m.t = 0
    m.dir = 1
    m.frame = 1
    return m
end

function Moth:cross()
    self.flying = true
    self.t = 0
    self.dir = love.math.random() < 0.5 and -1 or 1
end

function Moth:isFlying() return self.flying end

function Moth:update(dt)
    if reducedMotion() then
        self.flying = false
        self.frame = 3
        return
    end
    if self.flying then
        self.t = self.t + dt
        self.frame = math.floor(self.t * Moth.FPS) % 4 + 1
        if self.t * Moth.SPEED > Moth.SPAN * 2 then
            self.flying = false
            self.wait = Moth.MIN_WAIT + love.math.random() * (Moth.MAX_WAIT - Moth.MIN_WAIT)
        end
    else
        self.wait = self.wait - dt
        if self.wait <= 0 then self:cross() end
    end
end

-- fx,fy = centro da chama. Voo em arco raso que passa pela chama, com
-- ziguezague em degraus de 1 px (mariposa não voa reto).
function Moth:draw(fx, fy, scale)
    scale = scale or 1
    local s = sheet("moth", Moth.FW, Moth.FH)
    if not s then return end
    love.graphics.setColor(1, 1, 1, 1)
    if reducedMotion() then
        drawFrame(s, 3, math.floor(fx + Moth.PERCH.x * scale), math.floor(fy + Moth.PERCH.y * scale),
            scale, 0, Moth.FW / 2, Moth.FH / 2)
        return
    end
    if not self.flying then return end
    local d = self.t * Moth.SPEED - Moth.SPAN          -- -SPAN..SPAN
    local x = fx + d * self.dir * scale
    local arc = -(1 - (d / Moth.SPAN) ^ 2) * 10        -- sobe até rente ao vidro
    local zig = math.floor(math.sin(self.t * 9) * 3)
    local y = fy + (arc + zig) * scale
    drawFrame(s, self.frame, math.floor(x), math.floor(y), scale, 0, Moth.FW / 2, Moth.FH / 2)
end

ShopProps.moth = { new = ShopProps.newMoth, Moth = Moth }

-- ===========================================================================
-- TEIA e ETIQUETA (estáticas)
-- ===========================================================================
ShopProps.cobweb = {}
function ShopProps.cobweb.draw(x, y, scale)
    local s = sheet("cobweb")
    if not s then return end
    love.graphics.setColor(1, 1, 1, 0.9)
    drawFrame(s, 1, math.floor(x), math.floor(y), scale or 1)
    love.graphics.setColor(1, 1, 1, 1)
end

ShopProps.saleTag = { W = 24, H = 16 }
function ShopProps.saleTag.draw(x, y, scale)
    local s = sheet("saleTag")
    if not s then return end
    love.graphics.setColor(1, 1, 1, 1)
    drawFrame(s, 1, math.floor(x), math.floor(y), scale or 1)
end

-- ===========================================================================
-- FACHADA PRA CENA (contrato combinado com a frente loja-cena, Out/2026)
-- A cena não instancia nada: chama estas funções na ordem do frame.
--   ShopProps.load()                      cria os props e AVISA asset ausente
--   ShopProps.update(dt, L, ctx)          L = ShopLayout.layout(); ctx = { t,
--                                         reduced, hoverX, hoverY, run | dice,
--                                         cupHover }  (run = currentRun, pra
--                                         ler os dados da visita; ou dice={a,b})
--   ShopProps.drawBack(L, ctx)            teia no canto da estante de cima +
--                                         halo e poeira no feixe (a POÇA/cone
--                                         na parede é da cena: use lookDx())
--   ShopProps.drawLantern(rect, ctx)      sprite da lanterna no rect (escala
--                                         inteira que cabe)
--   ShopProps.flameAnchor(rect) -> x, y   centro da chama no rect da lanterna
--   ShopProps.lookDx() -> px              deslocamento em DEGRAUS da luz
--                                         (já em px de tela, segue o hover)
--   ShopProps.drawDiceCup(rect, ctx)      copo apoiado no tampo (pé = y+h);
--                                         ctx.hover 0..1 chacoalha; o estado
--                                         jogado vem do update (run/dice)
--   ShopProps.drawFront(L, ctx)           mariposa (por cima de tudo)
-- ===========================================================================
local S = nil   -- singletons da cena

local function lanternScale(rect)
    return math.max(1, math.floor(math.min(rect.w / Lantern.FW, rect.h / Lantern.FH)))
end

local function lanternHook(rect)
    local sc = lanternScale(rect)
    return math.floor(rect.x + rect.w / 2), math.floor(rect.y + (rect.h - Lantern.FH * sc) / 2), sc
end

function ShopProps.load()
    S = { lantern = ShopProps.newLantern(), cup = ShopProps.newDiceCup(), moth = ShopProps.newMoth() }
    for _, path in ipairs(ShopProps.missingAssets()) do
        print("[ShopProps] asset ausente: " .. path)
    end
    return S
end

function ShopProps.update(dt, L, ctx)
    if not S then ShopProps.load() end
    ctx = ctx or {}
    local lookX = nil
    local lr = L and L.lantern
    if lr and ctx.hoverX then
        local fx = lr.x + lr.w / 2
        local span = (L.wall and L.wall.w or love.graphics.getWidth()) / 2
        lookX = math.max(-1, math.min(1, (ctx.hoverX - fx) / math.max(1, span)))
    end
    S.lantern:update(dt, lookX)
    if ctx.run then
        S.cup:syncRun(ctx.run)
    elseif ctx.dice and ctx.dice[1] and ctx.dice[2] then
        if S.cup.state ~= "rolled" or S.cup.dice[1] ~= ctx.dice[1] or S.cup.dice[2] ~= ctx.dice[2] then
            S.cup:setState("rolled", { a = ctx.dice[1], b = ctx.dice[2] })
        end
    elseif S.cup.state == "rolled" then
        S.cup:setState("idle")
    end
    if S.cup.state ~= "rolled" then
        local hov = (ctx.cupHover or ctx.hover or 0) > 0.5
        if hov and S.cup.state ~= "shake" then S.cup:setState("shake")
        elseif not hov and S.cup.state == "shake" then S.cup:setState("idle") end
    end
    S.cup:update(dt)
    S.moth:update(dt)
end

function ShopProps.flameAnchor(rect)
    local hx, hy, sc = lanternHook(rect)
    local l = S and S.lantern
    if l then return l:flameAt(hx, hy, sc) end
    return ShopProps.lantern.flameAt(hx, hy, sc)
end

function ShopProps.lookDx(rect)
    if not S then return 0 end
    local sc = rect and lanternScale(rect) or 1
    return S.lantern.lookStep * Lantern.LOOK_PX * sc
end

function ShopProps.lightLevel()
    return S and S.lantern:intensity() or 1
end

function ShopProps.drawBack(L, ctx)
    if not S then ShopProps.load() end
    if L and L.shelfTop then
        local sc = math.max(1, math.floor(L.shelfTop.h / 96))
        ShopProps.cobweb.draw(L.shelfTop.x + 2, L.shelfTop.y + 2, sc)
    end
    if L and L.lantern then
        local hx, hy, sc = lanternHook(L.lantern)
        S.lantern:drawLight(hx, hy, sc, { pool = false })
    end
end

function ShopProps.drawLantern(rect, ctx)
    if not S then ShopProps.load() end
    local hx, hy, sc = lanternHook(rect)
    S.lantern:drawSprite(hx, hy, sc)
end

function ShopProps.drawDiceCup(rect, ctx)
    if not S then ShopProps.load() end
    ctx = ctx or {}
    local sc = math.max(1, math.floor(rect.h / DiceCup.FH))
    S.cup:draw(math.floor(rect.x + rect.w / 2), math.floor(rect.y + rect.h), sc,
        { slope = ctx.slope, outline = ctx.outline, silhouette = ctx.silhouette,
          dicePos = ctx.dicePos, idleDie = ctx.idleDie })
end

function ShopProps.drawFront(L, ctx)
    if not S then ShopProps.load() end
    if not (L and L.lantern) then return end
    local hx, hy, sc = lanternHook(L.lantern)
    local fx, fy = S.lantern:flameAt(hx, hy, sc)
    S.moth:draw(fx, fy, sc)
end

function ShopProps.scene() return S end

-- pra testes: esquece sheets (depois de trocar um PNG), avisos e a cena
function ShopProps._reset()
    sheets, warned, S = {}, {}, nil
end

return ShopProps
