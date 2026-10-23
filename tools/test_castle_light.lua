local TK = require("tools.testkit")

local M = {}

M.MAX_STEP = 7
M.MAX_DIP_K = 0.2
M.MAX_RISE_K = 0.12

local function patchDims(w, h)
    local o = { love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions }
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    return function()
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = o[1], o[2], o[3]
    end
end

function M.run()
    local t = TK.new("test_castle_light")
    local S = require("tools.screenshot_castelo_luz")
    local LightEngine = require("engine.LightEngine")
    local WorldRoad, restoreT = S.setup()

    LightEngine.setEnabled(true)
    local W, H = 1280, 720
    local restore = patchDims(W, H)
    local cv = love.graphics.newCanvas(W, H)
    local ok, err = pcall(function()
        t:eq("sem luz do castelo no chao antes da chegada", WorldRoad.castleSpillK(0.59), 0)
        t:eq("luz inteira no andar do chefe", WorldRoad.castleSpillK(0.875), 1)
        for act = 1, 6 do
            for _, tod in ipairs({ 0.65, 1.0 }) do
                for _, p in ipairs({ 0, 0.3, 0.55 }) do
                    S.prepare(WorldRoad, act, p, tod)
                    local ct = S.draw(WorldRoad, cv, W, H, act, nil, false)
                    local dOff = cv:newImageData()
                    ct = S.draw(WorldRoad, cv, W, H, act, nil, true)
                    local dOn = cv:newImageData()
                    local mx = S.diff(WorldRoad, W, H, ct, dOn, dOff, 4)
                    t:truthy(string.format("ato %d tod %.2f p %.2f: castelo longe nao acende o chao (%.1f/255)", act, tod, p, mx), mx <= 1.0)
                    local step, dip, far, rise = S.bandStep(S.roadProfile(WorldRoad, W, H, dOn))
                    t:truthy(string.format("ato %d tod %.2f p %.2f: fim da estrada sem faixa escura (degrau %.1f, subida %.1f, queda %.1f de %.1f)", act, tod, p, step, rise, dip, far),
                        step <= M.MAX_STEP and rise <= M.MAX_RISE_K * far + 1 and dip <= M.MAX_DIP_K * far + 1)
                    dOn:release()
                    dOff:release()
                end
            end
            local prev, final, worstJump = nil, 0, 0
            local seq = {}
            for i = 0, 14 do
                local p = 0.70 + i * 0.0125
                S.prepare(WorldRoad, act, p, 1.0)
                local ct = S.draw(WorldRoad, cv, W, H, act, nil, false)
                local dOff = cv:newImageData()
                ct = S.draw(WorldRoad, cv, W, H, act, nil, true)
                local dOn = cv:newImageData()
                local _, mean = S.diff(WorldRoad, W, H, ct, dOn, dOff, 4)
                seq[#seq + 1] = mean
                dOn:release()
                dOff:release()
            end
            final = seq[#seq]
            local mono = true
            for i = 2, #seq do
                if seq[i] < seq[i - 1] - 0.03 - 0.05 * seq[i - 1] then mono = false end
                worstJump = math.max(worstJump, seq[i] - seq[i - 1])
            end
            t:truthy(string.format("ato %d: luz da chegada acende sem recuar", act), mono)
            t:truthy(string.format("ato %d: luz da chegada sem salto (%.3f de %.3f)", act, worstJump, final),
                worstJump <= math.max(0.05, 0.35 * final))
            collectgarbage()
        end
    end)
    cv:release()
    restore()
    restoreT()
    LightEngine.setEnabled(nil)
    t:truthy("execucao sem erro: " .. tostring(err), ok)
    return t:done()
end

return M
