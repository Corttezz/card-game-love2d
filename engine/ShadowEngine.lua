-- engine/ShadowEngine.lua
-- ============================================================================
-- SHADOWENGINE v1 — sombras PROJETADAS de silhueta (Jul/2026)
-- ============================================================================
-- Substitui as elipses "círculo nos pés" dos objetos de destaque por uma
-- sombra convincente: a SILHUETA do próprio sprite, virada de cabeça pra
-- baixo a partir dos pés (o sol dos biomas vive no horizonte, atrás do
-- castelo → a sombra projeta pro PRIMEIRO PLANO), achatada e cisalhada:
--
--   COMPRIMENTO ∝ horário do dia (sol baixo no anoitecer = sombra longa)
--   DIREÇÃO     ∝ posição do astro do bioma (ponta foge do sol, por coluna
--                 da tela — árvore à esquerda do sol inclina pra esquerda)
--   OPACIDADE   ∝ luminância do ambiente de luz (luz difusa = sombra suave)
--   TAMANHO     ∝ escala do dono (perspectiva de graça: longe = sombra
--                 pequena, perto = grande — "cada árvore uma sombra")
--
-- REGRA DE PROFUNDIDADE (lei do projeto): a sombra desenha JUNTO do dono
-- no painter — deitada no chão do slot dele, grama mais próxima cobre.
-- NÃO usar nas cartas (sombra de carta é outra linguagem, já aprovada).
-- Zero stencil, zero shader — só transform + tint.
--
-- USO:
--   WorldRoad (1x por frame):  ShadowEngine.setFrame(sunX, w, tod, luma)
--   sprite estático:           ShadowEngine.sprite(img, feetX, feetY, s, opts)
--   draw arbitrário (anim):    local tint = ShadowEngine.begin(feetX, feetY)
--                              if tint then <desenha com tint>;
--                                 ShadowEngine.finish() end
-- ============================================================================

local ShadowEngine = {}

local frame = {
    sunX = 0, w = 1,
    len = 0.5,          -- fração da altura do sprite que vira sombra
    alpha = 0.26,
    stamp = -1,         -- staleness: frame só vale por ~0.1s (interiores
                        -- não chamam setFrame → begin() vira no-op)
}

-- WorldRoad configura 1x por frame de mundo.
-- sunX = x NA TELA do astro do bioma; w = largura da área do mundo;
-- tod = 0(dia)..1(anoitecer); luma = LightEngine.ambientLuma().
function ShadowEngine.setFrame(sunX, w, tod, luma)
    frame.sunX = sunX or 0
    frame.w = math.max(1, w or 1)
    -- sol alto (dia) = sombra curta; sol rasante (anoitecer) = comprida.
    -- v8.1 (feedback: "sem distorção, fiel demais; pode ser maior"):
    -- 0.34-0.64 → 0.55-1.00 — a sombra ESTICA de verdade
    frame.len = 0.55 + 0.45 * math.max(0, math.min(1, tod or 1))
    -- ambiente escuro = luz difusa = sombra mais suave (nunca some:
    -- piso 0.15 mantém o objeto ancorado no chão)
    local l = math.max(0, math.min(1, luma or 1))
    frame.alpha = 0.15 + 0.15 * l
    frame.stamp = love.timer.getTime()
end

function ShadowEngine.isActive()
    return (love.timer.getTime() - frame.stamp) < 0.1
end

-- deslocamento normalizado da PONTA pra longe do sol naquela coluna [-1..1]
local function tipShift(px)
    return math.max(-1, math.min(1, (px - frame.sunX) / (frame.w * 0.5)))
end

-- ----------------------------------------------------------------------------
-- Sombra de um SPRITE estático (props do mundo: árvores, marcos, encounter).
-- feetX/feetY = âncora dos pés no chão; s = escala do dono na cena.
-- opts: alphaK (0..1), lenK, flip (espelho do dono: ±1)
-- ----------------------------------------------------------------------------
function ShadowEngine.sprite(img, feetX, feetY, s, opts)
    if not img or not ShadowEngine.isActive() then return false end
    opts = opts or {}
    local iw, ih = img:getWidth(), img:getHeight()
    local shd = tipShift(feetX)
    love.graphics.setColor(0, 0, 0, frame.alpha * (opts.alphaK or 1))
    -- draw args: offset(-ox,-oy) → shear → scale → translate.
    -- oy=ih (pés): topo do sprite tem y local -ih → shear kx desloca a
    -- ponta em -kx·ih·s ⇒ ponta pra LONGE do sol pede kx = -shd·K.
    -- sy NEGATIVO espelha verticalmente (sombra desce dos pés pro
    -- primeiro plano).
    love.graphics.draw(img, math.floor(feetX), math.floor(feetY), 0,
        s * (opts.flip or 1),
        -s * frame.len * (opts.lenK or 1),
        iw / 2, ih,
        -shd * 0.78, 0)
    love.graphics.setColor(1, 1, 1, 1)
    return true
end

-- ----------------------------------------------------------------------------
-- Sombra de um DRAW arbitrário (animação do inimigo): abre o transform
-- projetado nos pés e devolve o tint preto; o chamador desenha a MESMA
-- silhueta que desenharia em pé, relativa à origem (pés em 0,0), e fecha
-- com finish(). Retorna nil quando inativo (interiores → elipse legada).
-- ----------------------------------------------------------------------------
local beginTint = { 0, 0, 0, 0.26 }
function ShadowEngine.begin(feetX, feetY, opts)
    if not ShadowEngine.isActive() then return nil end
    opts = opts or {}
    local shd = tipShift(feetX)
    love.graphics.push()
    love.graphics.translate(math.floor(feetX), math.floor(feetY))
    -- ordem de emissão translate→shear→scale ⇒ no ponto aplica scale
    -- ANTES do shear: y já flipado (positivo abaixo dos pés) → ponta
    -- pra longe do sol pede kx = +shd·K (sinal oposto ao .sprite)
    love.graphics.shear(shd * 0.78, 0)
    love.graphics.scale(1, -frame.len * (opts.lenK or 1))
    beginTint[4] = frame.alpha * (opts.alphaK or 1)
    love.graphics.setColor(beginTint)
    return beginTint
end

function ShadowEngine.finish()
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

-- ----------------------------------------------------------------------------
-- FILA (props do mundo): sombra cai SOBRE a grama — mas no painter o
-- tapete mais próximo desenha depois do prop e COBRIA a sombra imediata
-- (campo 100% coberto = sombra invisível). Solução: os props ENFILEIRAM;
-- o WorldRoad descarrega a fila depois de props+grama completos — a
-- sombra escurece a grama em que cai (e o pé de quem estiver dentro
-- dela, como sombra real faria). Ordem de submit = far→near (painter).
-- ----------------------------------------------------------------------------
local squeue = {}
function ShadowEngine.queue(img, feetX, feetY, s, opts)
    if not img or not ShadowEngine.isActive() then return false end
    squeue[#squeue + 1] = { img = img, x = feetX, y = feetY, s = s, o = opts }
    return true
end

function ShadowEngine.flush()
    for i = 1, #squeue do
        local q = squeue[i]
        ShadowEngine.sprite(q.img, q.x, q.y, q.s, q.o)
        squeue[i] = nil
    end
end

return ShadowEngine
