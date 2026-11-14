-- Cena de abertura de ato ("cartão de título" do ato): pintura em camadas com parallax, partes vivas,
-- o nome do ato escrito letra a letra e o som ambiente do bioma. Pedido do Daniel (14/11/2026);
-- formato e regras em docs/cenas_de_ato/STYLE.md, dados por ato em src/data/act_intros.lua.
--
-- Nunca segura a run: sem dados, sem arte, opção desligada ou erro ao carregar = available() falso e o
-- jogo segue direto. Qualquer clique, tecla ou botão pula. Não entra no save (o Continuar nunca reabre).
local Debug       = require("src.core.Debug")
local FontManager = require("src.ui.FontManager")
local I18n        = require("src.i18n.I18n")

local ActIntro = {}

ActIntro.VW, ActIntro.VH = 480, 270     -- tela virtual da pintura
ActIntro.DURATION = 8.6                 -- s; fade de entrada 0,8 e de saída 0,9
ActIntro.FADE_IN, ActIntro.FADE_OUT = 0.8, 0.9
ActIntro.MARGIN = 12                    -- px virtuais cortados de cada lado (folga do parallax)
ActIntro.DRIFT = 9                      -- px virtuais que a câmera desliza na cena inteira
ActIntro.TITLE_AT, ActIntro.CPS = 1.5, 16
ActIntro.SKIP_GRACE = 0.25              -- ignora o clique que acabou de abrir a cena

local DATA                               -- require tardio (testes trocam o módulo)
local cache = {}                         -- [ato] = { images..., anims } (carregado uma vez)
local S = { active = false }

local function data() DATA = DATA or require("src.data.act_intros"); return DATA end
local function settings() return _G.gameSettings or {} end
local function reducedMotion() return settings().reducedMotion and true or false end

local function roman(n) return ({ "I", "II", "III", "IV", "V", "VI" })[n] or tostring(n) end

local function newImage(path)
    local img = love.graphics.newImage(path)
    img:setFilter("nearest", "nearest")
    return img
end

-- carrega a arte do ato; devolve nil (sem erro) se faltar qualquer peça
local function load(act)
    if cache[act] ~= nil then return cache[act] or nil end
    local D = data()[act]
    if not D then cache[act] = false; return nil end
    local ok, res = pcall(function()
        local r = { D = D }
        for _, k in ipairs({ "far", "ground", "arch" }) do r[k] = newImage(D.dir .. k .. ".png") end
        local adir = D.animDir or D.dir   -- o viajante é o mesmo nos 6 atos: atos 2-6 usam os loops do ato 1
        local anims = love.filesystem.load(adir .. "anims.lua")()
        r.anims = anims
        r.traveler = newImage(adir .. anims.traveler.file)
        r.crow = newImage(adir .. anims.crow.file)
        r.quads = {}
        for _, k in ipairs({ "traveler", "crow" }) do
            local a, img = anims[k], r[k]
            r.quads[k] = {}
            for i = 0, a.frames - 1 do
                r.quads[k][i + 1] = love.graphics.newQuad(i * a.w, 0, a.w, a.h, img:getDimensions())
            end
        end
        return r
    end)
    if not ok then
        Debug.warn("[ActIntro] arte do ato " .. tostring(act) .. " indisponível: " .. tostring(res))
        cache[act] = false
        return nil
    end
    cache[act] = res
    return res
end

local function registerSounds(D)
    local audio = _G.audioSystem
    if not audio or not audio.sources then return end
    local list = {}
    for _, s in ipairs(D.sfx or {}) do list[#list + 1] = s end
    if data().chime then list[#list + 1] = data().chime end
    for _, s in ipairs(list) do
        if not audio.sources[s.code] and love.filesystem.getInfo(s.file) then
            audio:loadSound(s.code, s.file, { volume = s.volume or 1, group = s.loop and "ambient" or "sfx",
                                             stream = s.loop and true or false })
        end
    end
end

-- A cena aparece? (opção ligada + dados + arte carregada). Barato depois da 1ª vez.
function ActIntro.available(act)
    if settings().actIntros == false then return false end
    -- ferramentas/testes sem janela pulam a cena (como a intro do BootScene); quem testa a cena força
    if _G.HEADLESS_TOOL and not _G.ACT_INTRO_FORCE then return false end
    if not act or not data()[act] then return false end
    return load(act) ~= nil
end

-- ---------------------------------------------------------------- partículas (semente fixa: igual em todo replay)
local function seeded(seed)
    local rng = love.math.newRandomGenerator(seed)
    return function(a, b) return a + (b - a) * rng:random() end
end

local function makeFog(cfg, seed)
    -- textura de névoa 256x(h) com ruído suave na horizontal, alfa forte no meio e nada nas bordas
    local w, h = 256, cfg.h
    local id = love.image.newImageData(w, h)
    for y = 0, h - 1 do
        local v = 1 - math.abs((y + 0.5) / h * 2 - 1)
        v = v * v * (3 - 2 * v)
        for x = 0, w - 1 do
            local n = love.math.noise(x / 38, y / 9, seed) * 0.65 + love.math.noise(x / 11, y / 5, seed + 7) * 0.35
            id:setPixel(x, y, 1, 1, 1, math.max(0, math.min(1, v * (n * 1.5 - 0.25))))
        end
    end
    local img = love.graphics.newImage(id)
    img:setWrap("repeat", "clamp")
    img:setFilter("nearest", "nearest")
    return img
end

local function initParticles(D)
    local r = seeded(1400 + (S.act or 1))
    S.leaves, S.dust = {}, {}
    for i = 1, (D.leaves and D.leaves.count or 0) do
        S.leaves[i] = { x = r(20, 470), y = r(-60, 40), vy = r(9, 16), vx = r(2, 7), ph = r(0, 6.28),
                        sw = r(4, 9), c = D.leaves.colors[1 + math.floor(r(0, #D.leaves.colors - 0.001))],
                        delay = r(0, 4.5), front = i % 3 == 0 }
    end
    local b = D.dust and D.dust.box or { 0, 0, 1, 1 }
    for i = 1, (D.dust and D.dust.count or 0) do
        S.dust[i] = { x = r(b[1], b[3]), y = r(b[2], b[4]), vx = r(-1.5, 2.5), vy = r(-2.0, 0.6),
                      ph = r(0, 6.28), sp = r(1.2, 3.0) }
    end
    S.fx = {}
    for k, f in ipairs(D.fx or {}) do
        local list = {}
        for i = 1, f.count do
            list[i] = { x = r(-20, ActIntro.VW + 20), y = r(f.ymin or -10, f.ymax or ActIntro.VH), ph = r(0, 6.28),
                        sp = r(0.7, 1.3), size = (f.size or 1) * (r(0, 1) < 0.25 and 2 or 1) }
        end
        S.fx[k] = list
    end
    S.fog = D.fog and makeFog(D.fog, 3.1) or nil
    S.fog2 = D.fog2 and makeFog(D.fog2, 8.7) or nil
end

-- ---------------------------------------------------------------- ciclo de vida
-- start(act, onDone) -> true se a cena abriu; false = nada aconteceu e o chamador segue direto
function ActIntro.start(act, onDone)
    if not ActIntro.available(act) then return false end
    local ok, err = pcall(function()
        local A = load(act)
        S = { active = true, act = act, A = A, D = A.D, t = 0, onDone = onDone, played = {}, chimed = false,
              still = reducedMotion() }
        registerSounds(A.D)
        initParticles(A.D)
        local kicker = I18n.t("act_intro.kicker", { n = roman(act) }, "ACT " .. roman(act))
        S.kicker = kicker
        S.name = require("src.systems.ActSystem").getActName(act)   -- o mesmo nome do HUD, mapa e resumo
        S.sub = I18n.t("act_intro.act" .. act .. "_sub", nil, "")
    end)
    if not ok then
        Debug.warn("[ActIntro] falha ao abrir a cena: " .. tostring(err))
        S = { active = false }
        return false
    end
    return true
end

function ActIntro.isActive() return S.active end
function ActIntro.time() return S.t or 0 end

local function finish()
    if not S.active then return end
    local cb = S.onDone
    local audio = _G.audioSystem
    for code, src in pairs(S.played or {}) do
        if src and src.stop and S.loops and S.loops[code] then pcall(src.stop, src) end
    end
    S = { active = false }
    if audio and audio.fadeGroup then pcall(audio.fadeGroup, audio, "ambient", 0, 0.6) end
    if cb then cb() end
end
ActIntro.finish = finish

function ActIntro.skip()
    if not S.active or S.t < ActIntro.SKIP_GRACE then return false end
    -- pular = encurta para o fade de saída (0,35 s), sem corte seco
    local fadeStart = ActIntro.DURATION - ActIntro.FADE_OUT
    if S.t < fadeStart then S.skipAt = S.t end
    return true
end

local function titleChars()
    return utf8 and utf8.len(S.name) or #S.name
end

local function alphaAt(t)
    local a = 1
    if t < ActIntro.FADE_IN then a = t / ActIntro.FADE_IN end
    local endAt = S.skipAt and (S.skipAt + 0.35) or ActIntro.DURATION
    local outLen = S.skipAt and 0.35 or ActIntro.FADE_OUT
    if t > endAt - outLen then a = math.min(a, math.max(0, (endAt - t) / outLen)) end
    return a
end

function ActIntro.update(dt)
    if not S.active then return end
    S.t = S.t + dt
    local t = S.t
    -- som
    local audio = _G.audioSystem
    S.loops = S.loops or {}
    for _, s in ipairs(S.D.sfx or {}) do
        if not S.played[s.code] and t >= s.at then
            local src = audio and audio.play and audio:play(s.code, { loop = s.loop or false }) or nil
            S.played[s.code] = src or true
            if s.loop then S.loops[s.code] = true end
        end
    end
    -- o ambiente acompanha o fade da imagem (entra e sai junto, sem corte seco)
    if audio and audio.setInstanceGain then
        local ga = math.max(0, math.min(1, alphaAt(t)))
        for code in pairs(S.loops) do
            local src = S.played[code]
            if type(src) ~= "boolean" then audio:setInstanceGain(code, src, ga) end
        end
    end
    local typed = (t - ActIntro.TITLE_AT) * ActIntro.CPS
    if not S.chimed and typed >= titleChars() then
        S.chimed = true
        if audio and audio.play and data().chime then audio:play(data().chime.code) end
    end
    -- partículas
    if not S.still then
        for _, l in ipairs(S.leaves) do
            if t > l.delay then
                l.y = l.y + l.vy * dt
                l.x = l.x + (l.vx + math.sin(t * 1.7 + l.ph) * l.sw) * dt
                if l.y > ActIntro.VH + 4 then l.y = -6; l.x = l.x - 60 end
            end
        end
        for k, f in ipairs(S.D.fx or {}) do
            local vx, vy = f.vx or 0, f.vy or 0
            for _, q in ipairs(S.fx[k]) do
                q.x = q.x + (vx * q.sp + math.sin(t * (f.sway or 0.8) + q.ph) * (f.swayAmp or 0)) * dt
                q.y = q.y + vy * q.sp * dt
                local y0, y1 = f.ymin or -10, f.ymax or ActIntro.VH
                if vy > 0 and q.y > y1 then q.y = y0; q.x = q.x + 37 % ActIntro.VW end
                if vy < 0 and q.y < y0 then q.y = y1; q.x = (q.x * 1.37 + 53) % (ActIntro.VW + 40) - 20 end
                if q.x > ActIntro.VW + 30 then q.x = -25 elseif q.x < -30 then q.x = ActIntro.VW + 25 end
            end
        end
        for _, p in ipairs(S.dust) do
            p.x = p.x + (p.vx + math.sin(t * 0.7 + p.ph) * 1.2) * dt
            p.y = p.y + (p.vy + math.cos(t * 0.5 + p.ph) * 0.8) * dt
        end
    end
    local endAt = S.skipAt and (S.skipAt + 0.35) or ActIntro.DURATION
    if t >= endAt then finish() end
end

-- ---------------------------------------------------------------- desenho
local canvas, canvasS
local rayMesh, vigMesh

local function ensureCanvas(W, H)
    local vw, vh = ActIntro.VW - 2 * ActIntro.MARGIN, ActIntro.VH - 2 * ActIntro.MARGIN * ActIntro.VH / ActIntro.VW
    local s = math.max(1, math.ceil(math.max(W / vw, H / vh)))
    if not canvas or canvasS ~= s then
        canvas = love.graphics.newCanvas(math.floor(vw * s + 0.5), math.floor(vh * s + 0.5))
        canvas:setFilter("linear", "linear")
        canvasS = s
    end
    return s, vw, vh
end

local function drawScene(s)
    local A, D, t = S.A, S.D, S.t
    local g = love.graphics
    local m = ActIntro.MARGIN
    local my = m * ActIntro.VH / ActIntro.VW
    local p = S.still and 0 or math.min(1, t / ActIntro.DURATION)
    local ease = p * p * (3 - 2 * p)
    local cam = (ease - 0.5) * ActIntro.DRIFT * 2         -- -DRIFT .. +DRIFT
    local function off(k) return -m - cam * k end
    local P = D.parallax
    g.push()
    g.scale(s, s)
    g.translate(0, -my)
    g.setColor(1, 1, 1, 1)
    local function img(im, k) g.draw(im, math.floor(off(k) * s + 0.5) / s, 0) end
    img(A.far, P.far)
    -- névoa no horizonte (esconde a emenda céu/chão e dá profundidade)
    local function fog(tex, cfg, k)
        if not tex then return end
        local c = cfg.color
        g.setColor(c[1], c[2], c[3], cfg.alpha)
        local sx = (t * cfg.speed + off(k)) % 256
        for x = -sx - 256, ActIntro.VW + 256, 256 do g.draw(tex, x, cfg.y - cfg.h / 2) end
        g.setColor(1, 1, 1, 1)
    end
    fog(S.fog, D.fog, P.far + 0.1)
    -- corvos ao longe (atrás do chão)
    for _, c in ipairs(D.crows or {}) do
        local ct = t - c.at
        if ct > 0 and not S.still then
            local fr = math.floor(ct * A.anims.crow.fps) % A.anims.crow.frames + 1
            local x = c.from + ct * c.speed + off(P.far + 0.1) + m
            local y = c.y + math.sin(ct * 2.2) * 2
            g.draw(A.crow, A.quads.crow[fr], x, y, 0, c.scale, c.scale)
        end
    end
    img(A.ground, P.ground)
    -- lanterna do oratório
    if D.lantern then
        local L = D.lantern
        local fl = 0.75 + 0.25 * math.sin(t * 9.1) * math.sin(t * 3.7 + 1.3)
        g.setBlendMode("add")
        for r = 7, 2, -1 do
            g.setColor(L.color[1], L.color[2], L.color[3], 0.05 * fl * (8 - r) / 2)
            g.circle("fill", L.x + off(P.ground) + m, L.y, r)
        end
        g.setBlendMode("alpha")
        g.setColor(1, 1, 1, 1)
    end
    -- viajante (loop do manto ao vento)
    if D.traveler ~= false then   -- false: o viajante da própria pintura fica na camada do chão
        local a = A.anims.traveler
        local fr = S.still and 1 or (math.floor(t * a.fps) % a.frames + 1)
        local tp = D.traveler or { x = a.x, y = a.y }
        local tint = D.travelerTint or { 1, 1, 1 }
        local sc = tp.scale or 1
        g.setColor(tint[1], tint[2], tint[3], 1)
        g.draw(A.traveler, A.quads.traveler[fr], tp.x + off(P.traveler) + m, tp.y, 0, sc, sc)
        g.setColor(1, 1, 1, 1)
    end
    fog(S.fog2, D.fog2, P.ground)
    -- raios de luz e poeira dourada (aditivo, entre o mundo e o arco)
    local lc = D.light
    g.setBlendMode("add")
    if D.rays then
        local R = D.rays
        local fx, fy = R.from[1] + off(P.far) + m, R.from[2]
        for i = 1, R.count do
            local ang = math.rad(150 + i * 11 + math.sin(t * 0.4 + i) * 1.5)
            local len, wd = 300, 10 + i * 4
            local ex, ey = fx + math.cos(ang) * len, fy + math.sin(ang) * len
            local nx, ny = -math.sin(ang) * wd, math.cos(ang) * wd
            local a = R.alpha * (0.7 + 0.3 * math.sin(t * 0.9 + i * 1.7))
            -- triângulo em degradê: forte na fonte de luz, some na ponta (sem borda dura)
            rayMesh = rayMesh or g.newMesh(3, "triangles", "stream")
            rayMesh:setVertices({
                { fx, fy, 0, 0, lc[1], lc[2], lc[3], a },
                { ex + nx, ey + ny, 0, 0, lc[1], lc[2], lc[3], 0 },
                { ex - nx, ey - ny, 0, 0, lc[1], lc[2], lc[3], 0 },
            })
            g.setColor(1, 1, 1, 1)
            g.draw(rayMesh)
        end
    end
    if not S.still then
        for _, d in ipairs(S.dust) do
            local tw = 0.5 + 0.5 * math.sin(t * d.sp + d.ph)
            g.setColor(lc[1], lc[2], lc[3], 0.35 * tw)
            g.rectangle("fill", math.floor(d.x + off(P.ground) + m), math.floor(d.y), 1, 1)
        end
    end
    g.setBlendMode("alpha")
    g.setColor(1, 1, 1, 1)
    -- folhas atrás do arco, o arco, folhas na frente
    local function leaves(front)
        if S.still then return end
        for _, l in ipairs(S.leaves) do
            if l.front == front and t > l.delay then
                local c = l.c
                g.setColor(c[1], c[2], c[3], 1)
                local flip = math.sin(t * 3 + l.ph) > 0
                local x, y = math.floor(l.x + off(front and P.arch or P.ground) + m), math.floor(l.y)
                if flip then g.rectangle("fill", x, y, 2, 1) else g.rectangle("fill", x, y, 1, 2) end
            end
        end
        g.setColor(1, 1, 1, 1)
    end
    local function fxLayer(front)
        if S.still then return end
        for k, f in ipairs(D.fx or {}) do
            if (f.front or false) == front then
                local c = f.color
                local ox = off(front and P.arch or P.ground) + m
                if f.kind == "rain" then
                    g.setColor(c[1], c[2], c[3], f.alpha)
                    g.setLineWidth(1 / s)
                    for _, q in ipairs(S.fx[k]) do
                        local x, y = q.x + ox, q.y
                        g.line(x, y, x - (f.vx or 0) * 0.05, y - (f.vy or 0) * 0.05)
                    end
                elseif f.kind == "glow" then           -- brasas, luzes do pântano, almas: ponto + halo aditivo
                    g.setBlendMode("add")
                    for _, q in ipairs(S.fx[k]) do
                        local tw = 0.55 + 0.45 * math.sin(t * (f.twinkle or 2) * q.sp + q.ph)
                        local x, y = math.floor(q.x + ox), math.floor(q.y)
                        g.setColor(c[1], c[2], c[3], f.alpha * 0.35 * tw)
                        g.circle("fill", x + 0.5, y + 0.5, (f.halo or 2.5) * q.size)
                        g.setColor(c[1], c[2], c[3], f.alpha * tw)
                        g.rectangle("fill", x, y, q.size, q.size)
                    end
                    g.setBlendMode("alpha")
                else                                    -- "snow" e "mote": pixel simples
                    for _, q in ipairs(S.fx[k]) do
                        local tw = f.twinkle and (0.6 + 0.4 * math.sin(t * f.twinkle * q.sp + q.ph)) or 1
                        g.setColor(c[1], c[2], c[3], f.alpha * tw)
                        g.rectangle("fill", math.floor(q.x + ox), math.floor(q.y), q.size, q.size)
                    end
                end
            end
        end
        g.setColor(1, 1, 1, 1)
    end
    fxLayer(false)
    leaves(false)
    img(A.arch, P.arch)
    leaves(true)
    fxLayer(true)
    g.pop()
end

local function drawTitle(W, H, a)
    local t = S.t - ActIntro.TITLE_AT
    if t <= 0 then return end
    local g = love.graphics
    local big = FontManager.getFont(math.max(20, math.min(60, math.floor(H * 0.05))))
    local small = FontManager.getFont(math.max(11, math.min(26, math.floor(H * 0.022))))
    local x, y = math.floor(W * 0.075), math.floor(H * 0.20)
    local gold = { 0.95, 0.82, 0.52 }
    local function shadowed(font, text, px, py, alpha, col)
        g.setFont(font)
        g.setColor(0.05, 0.04, 0.04, 0.85 * alpha)
        g.print(text, px + math.max(2, math.floor(H / 360)), py + math.max(2, math.floor(H / 360)))
        g.setColor(col[1], col[2], col[3], alpha)
        g.print(text, px, py)
    end
    local k = math.min(1, t / 0.6)
    shadowed(small, S.kicker, x, y, a * k, { 0.86, 0.78, 0.62 })
    local n = math.floor(t * ActIntro.CPS)
    local shown = S.name
    if utf8 and n < (utf8.len(S.name) or 0) then
        local cut = utf8.offset(S.name, n + 1)
        shown = cut and S.name:sub(1, cut - 1) or S.name
    end
    local ny = y + small:getHeight() * 1.25
    shadowed(big, shown, x, ny, a, gold)
    local subT = t - (titleChars() / ActIntro.CPS) - 0.15
    if subT > 0 then
        local sy = ny + big:getHeight() * 1.15
        -- filete fino entre o nome e o subtítulo
        g.setColor(gold[1], gold[2], gold[3], 0.55 * a * math.min(1, subT / 0.5))
        local lw = math.floor(big:getWidth(S.name) * math.min(1, subT / 0.7))
        g.rectangle("fill", x, sy - math.floor(big:getHeight() * 0.12), lw, math.max(1, math.floor(H / 540)))
        shadowed(small, S.sub, x, sy + math.floor(H * 0.008), a * math.min(1, subT / 0.6), { 0.90, 0.86, 0.76 })
    end
    g.setColor(1, 1, 1, 1)
end

function ActIntro.draw()
    if not S.active then return end
    local g = love.graphics
    local W, H = g.getDimensions()
    local s, vw, vh = ensureCanvas(W, H)
    local prev = g.getCanvas()
    g.push("all")
    g.setCanvas(canvas)
    g.clear(0, 0, 0, 1)
    g.origin()
    drawScene(s)
    g.pop()
    g.setCanvas(prev)
    local a = alphaAt(S.t)
    g.push("all")
    g.setColor(0, 0, 0, 1)
    g.rectangle("fill", 0, 0, W, H)
    local cw, ch = canvas:getDimensions()
    local k = math.max(W / cw, H / ch)
    g.setColor(a, a, a, 1)
    g.draw(canvas, math.floor((W - cw * k) / 2), math.floor((H - ch * k) / 2), 0, k, k)
    -- vinheta suave nas laterais para o título ler bem
    -- degradê contínuo da esquerda (sem faixas): escurece só atrás do título
    vigMesh = vigMesh or g.newMesh({ { 0, 0, 0, 0, 0, 0, 0, 1 }, { 1, 0, 0, 0, 0, 0, 0, 0 },
                                     { 1, 1, 0, 0, 0, 0, 0, 0 }, { 0, 1, 0, 0, 0, 0, 0, 1 } }, "fan", "static")
    g.setColor(1, 1, 1, 0.42 * a)
    g.draw(vigMesh, 0, 0, 0, W * 0.55, H)
    drawTitle(W, H, a)
    g.pop()
end

function ActIntro.keypressed() return ActIntro.skip() end
function ActIntro.mousepressed() return ActIntro.skip() end
function ActIntro.gamepadpressed() return ActIntro.skip() end

-- testes
function ActIntro._resetCache() cache = {}; DATA = nil; canvas = nil; rayMesh = nil; vigMesh = nil end
function ActIntro._state() return S end

return ActIntro
