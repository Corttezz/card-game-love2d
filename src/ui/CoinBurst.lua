-- src/ui/CoinBurst.lua
-- Moedas que voam até o contador de ouro quando o jogador GANHA ouro.
--
-- Singleton global, no molde do FloatingText: `update`/`draw` são chamados uma
-- vez em `main.lua`, então funciona em QUALQUER estado — por cima da loja, do
-- evento, do cash out, do mapa. Uma tela que ganha ouro não precisa saber que
-- este módulo existe.
--
-- POR QUE ISTO EXISTE. O cash out (RoundEvalScreen) tinha moedas animadas e
-- todo o resto do jogo não: clicar "Continuar" na loja creditava o bônus de
-- pular com um texto subindo e mais nada ("ganha gold, então tem que ter a
-- animação que fizemos ao colher recompensa, SEMPRE que ganhar gold" — dono,
-- Set/2026). O mesmo evento econômico tinha dois pesos conforme a tela.
--
-- Por isso o disparo mora em `TopBar:_onGoldDelta`, que já é o funil por onde
-- TODO delta de ouro passa (a barra compara `currentGold` a cada frame). Ligar
-- tela por tela reabriria exatamente o buraco que motivou o componente: a
-- próxima fonte de ouro nasceria sem animação e ninguém perceberia.

local CoinBurst = {}

local coins = {}

-- Escala Balatro-ish: o número de moedas cresce com o ganho mas SATURA. Três
-- de ouro e quarenta de ouro têm pesos diferentes sem que quarenta vire festa
-- — a mesma dosagem que o som do ganho já usa logo acima.
local MIN_COINS, MAX_COINS = 3, 12

-- Cada moeda percorre um ARCO com tempo de chegada FIXO, em vez de física
-- livre com gravidade e atração.
--
-- A primeira versão era física (velocidade inicial aleatória + gravidade +
-- atração crescente ao contador) e gerou dois defeitos que o dono viu na
-- tela: moedas que já tinham chegado continuavam sendo integradas e ficavam
-- ORBITANDO o contador enquanto sumiam ("umas partículas de moeda ficam meio
-- que rodando e caindo"), e as que ainda vinham faziam curvas largas e lentas,
-- algumas DESCENDO antes de subir. Num efeito de recompensa isso lê como bug,
-- não como vida.
--
-- Com arco parametrizado, a chegada é garantida (t=1 é o contador, sempre),
-- toda moeda leva o mesmo tempo, e não existe estado depois do fim. O preço é
-- não ter variação emergente — que aqui não faz falta: quem dá variedade é o
-- leque de origem, o stagger e a rotação.
local FLIGHT   = 0.55      -- tempo de voo de cada moeda, em segundos
local STAGGER  = 0.04      -- atraso entre moedas: vira fileira, não salva
local ARC      = 90        -- altura do arco acima da reta origem→alvo
local FADE     = 0.16      -- tempo de sumiço depois de encostar no contador

local function rand(a, b) return a + love.math.random() * (b - a) end

-- amount  : quanto de ouro entrou (define quantas moedas)
-- tx, ty  : destino (o contador na TopBar)
-- ox, oy  : origem opcional; sem ela as moedas nascem logo abaixo do destino,
--           que é o comportamento certo quando não se sabe QUEM pagou.
function CoinBurst.spawn(amount, tx, ty, ox, oy)
    if not amount or amount <= 0 then return end
    if not tx or not ty then return end

    -- reducedMotion tira o MOVIMENTO, nunca a INFORMAÇÃO: o valor continua
    -- subindo como FloatingText na TopBar, que é quem informa. Aqui só há
    -- enfeite, então some inteiro.
    if _G.gameSettings and _G.gameSettings.reducedMotion then return end

    local n = math.max(MIN_COINS, math.min(MAX_COINS, math.ceil(amount / 4)))
    ox = ox or tx
    oy = oy or (ty + 90)

    for i = 1, n do
        coins[#coins + 1] = {
            x0 = ox + rand(-30, 30),
            y0 = oy + rand(-8, 8),
            tx = tx, ty = ty,
            x = ox, y = oy,
            -- Arco por moeda: lados alternados e alturas diferentes espalham
            -- o feixe sem nenhuma moeda sair da rota.
            arc = ARC * rand(0.55, 1.0) * (i % 2 == 0 and 1 or -1),
            rot = rand(0, math.pi * 2),
            vrot = rand(-7, 7),
            s = rand(0.85, 1.15),
            a = 1,
            t = 0,
            delay = (i - 1) * STAGGER,
            landed = false,
            order = i,
            total = n,
        }
    end
end

function CoinBurst.update(dt)
    if #coins == 0 then return end
    local Sfx = require("src.systems.Sfx")

    for i = #coins, 1, -1 do
        local c = coins[i]
        if c.delay > 0 then
            c.delay = c.delay - dt
        elseif not c.landed then
            c.t = c.t + dt
            local k = math.min(1, c.t / FLIGHT)
            -- easeOutQuad na posição: sai rápido e ASSENTA no contador, em vez
            -- de chegar a toda e precisar frear (frear era o que dava a
            -- impressão de órbita).
            local e = 1 - (1 - k) * (1 - k)

            c.x = c.x0 + (c.tx - c.x0) * e
            c.y = c.y0 + (c.ty - c.y0) * e
            -- O arco desloca PERPENDICULARMENTE à rota, não em Y. Como a
            -- origem fica logo abaixo do contador, deslocar em Y só esticaria
            -- a subida e as moedas viriam em coluna; perpendicular abre o
            -- leque de verdade, em qualquer direção que a origem esteja.
            -- sin(pi*k) vale 0 nas duas pontas, então o arco nasce e morre
            -- exatamente na origem e no alvo e nunca desloca a chegada.
            local dx, dy = c.tx - c.x0, c.ty - c.y0
            local len = math.sqrt(dx * dx + dy * dy)
            if len > 1 then
                local off = math.sin(math.pi * k) * c.arc
                c.x = c.x + (-dy / len) * off
                c.y = c.y + (dx / len) * off
            end
            c.rot = c.rot + c.vrot * dt

            if k >= 1 then
                c.landed = true
                c.x, c.y = c.tx, c.ty
                -- Pitch sobe com a ordem de chegada: a fileira soa como uma
                -- escala subindo, que é o que o cash out já faz.
                Sfx.play("coinClink", {
                    pitch = 1.0 + math.min(0.5, (c.order - 1) * 0.045),
                    volume = 0.28,
                })
            end
        else
            -- Encostou: um pop curto no lugar e some. Nada mais é integrado,
            -- então não há como sobrar movimento depois do fim.
            c.s = c.s * (1 + dt * 1.8)
            c.a = c.a - dt / FADE
        end

        if c.a <= 0 then table.remove(coins, i) end
    end
end

function CoinBurst.draw()
    if #coins == 0 then return end
    local icon = require("src.ui.IconLoader").get("coin")
    for _, c in ipairs(coins) do
        if c.delay <= 0 and c.a > 0.01 then
            love.graphics.setColor(1, 1, 1, c.a)
            if icon and icon.image then
                local iw = icon.image:getWidth()
                local ih = icon.image:getHeight()
                -- NEAREST, senão o PNG de 64px reduzido pra ~20 sai borrado e
                -- a moeda deixa de ser pixel art no meio de uma tela que é
                -- toda pixel art. O filtro é por-imagem no LÖVE e o default
                -- é linear, então não dá pra assumir que veio certo do loader.
                icon.image:setFilter("nearest", "nearest")
                local base = 20 / iw
                love.graphics.draw(icon.image, c.x, c.y, c.rot,
                    base * c.s, base * c.s, iw * 0.5, ih * 0.5)
            else
                -- Sem o PNG, disco dourado. Moeda que some porque o ícone não
                -- resolveu seria fallback silencioso (ui_layout_invariants §3).
                love.graphics.setColor(0.95, 0.80, 0.28, c.a)
                love.graphics.circle("fill", c.x, c.y, 7 * c.s)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function CoinBurst.clear() coins = {} end
-- Introspeccao para o teste de regressao: precisa olhar o estado de CADA
-- moeda (pousada? moveu depois de pousar?), nao so a contagem.
function CoinBurst._coins() return coins end
function CoinBurst.count() return #coins end

return CoinBurst
