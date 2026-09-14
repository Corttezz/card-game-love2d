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
local GRAVITY   = 620
local ATTRACT   = 12      -- força da atração ao contador (cresce com o tempo)
local ARRIVE_R  = 14      -- distância em que a moeda "entra no cofre"

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
            x = ox + rand(-26, 26),
            y = oy + rand(-10, 10),
            vx = rand(-120, 120),
            vy = rand(-260, -140),   -- sobe primeiro: dá o arco
            rot = rand(0, math.pi * 2),
            vrot = rand(-6, 6),
            s = rand(0.85, 1.15),
            a = 1,
            tx = tx, ty = ty,
            t = 0,
            delay = (i - 1) * 0.045,  -- leque, não salva de canhão
            landed = false,
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
        else
            c.t = c.t + dt
            c.vy = c.vy + GRAVITY * dt

            -- A atração ao contador entra CRESCENDO. Se fosse constante desde
            -- o frame 0, a moeda iria reto e o arco sumiria; o arco é o que
            -- faz a moeda parecer arremessada em vez de teleportada.
            local pull = ATTRACT * math.min(1, c.t / 0.35)
            c.vx = c.vx + (c.tx - c.x) * pull * dt
            c.vy = c.vy + (c.ty - c.y) * pull * dt

            c.x = c.x + c.vx * dt
            c.y = c.y + c.vy * dt
            c.rot = c.rot + c.vrot * dt

            local dx, dy = c.tx - c.x, c.ty - c.y
            if (dx * dx + dy * dy) < (ARRIVE_R * ARRIVE_R) then
                if not c.landed then
                    c.landed = true
                    -- Pitch sobe com a ordem de chegada: a fileira soa como
                    -- uma escala subindo, que é o que o cash out já faz.
                    Sfx.play("coinClink", {
                        pitch = 1.0 + math.min(0.5, (#coins - i) * 0.045),
                        volume = 0.28,
                    })
                end
                c.a = c.a - dt * 7
            elseif c.t > 2.5 then
                -- Rede de segurança: moeda que por algum motivo não converge
                -- não pode ficar viva para sempre.
                c.a = c.a - dt * 3
            end
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
function CoinBurst.count() return #coins end

return CoinBurst
