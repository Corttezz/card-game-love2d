local CoinBurst = {}

local coins = {}

local MIN_COINS, MAX_COINS = 3, 12

local FLIGHT   = 0.55
local STAGGER  = 0.04
local ARC      = 90
local FADE     = 0.16

local function rand(a, b) return a + love.math.random() * (b - a) end

function CoinBurst.spawn(amount, tx, ty, ox, oy)
    if not amount or amount <= 0 then return end
    if not tx or not ty then return end

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
            local e = 1 - (1 - k) * (1 - k)

            c.x = c.x0 + (c.tx - c.x0) * e
            c.y = c.y0 + (c.ty - c.y0) * e
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
                Sfx.play("coinClink", {
                    pitch = 1.0 + math.min(0.5, (c.order - 1) * 0.045),
                    volume = 0.28,
                })
            end
        else
            c.s = c.s * (1 + dt * 1.8)
            c.a = c.a - dt / FADE
        end

        if c.a <= 0 then table.remove(coins, i) end
    end
end

function CoinBurst.draw()
    if #coins == 0 then return end
    local icon = require("src.ui.IconLoader").get("ui_gold")
    for _, c in ipairs(coins) do
        if c.delay <= 0 and c.a > 0.01 then
            love.graphics.setColor(1, 1, 1, c.a)
            if icon and icon.image then
                local iw = icon.image:getWidth()
                local ih = icon.image:getHeight()
                icon.image:setFilter("nearest", "nearest")
                local base = 20 / iw
                love.graphics.draw(icon.image, c.x, c.y, c.rot,
                    base * c.s, base * c.s, iw * 0.5, ih * 0.5)
            else
                love.graphics.setColor(0.95, 0.80, 0.28, c.a)
                love.graphics.circle("fill", c.x, c.y, 7 * c.s)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function CoinBurst.clear() coins = {} end
function CoinBurst._coins() return coins end
function CoinBurst.count() return #coins end

return CoinBurst
