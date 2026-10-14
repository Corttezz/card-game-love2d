local TK = require("tools.testkit")
local M = {}

function M.run()
    TK.bootstrap()
    local t = TK.new("test_collection_hover")
    local Screen = require("components.CollectionScreen")
    local realMouse = love.mouse.getPosition
    local realW, realH = love.graphics.getWidth, love.graphics.getHeight
    local mx, my = 1, 1
    local ok, err = pcall(function()
        love.graphics.getWidth = function() return 1280 end
        love.graphics.getHeight = function() return 720 end
        love.mouse.getPosition = function() return mx, my end
        local s = Screen:new()
        s:show(function() end)
        for _ = 1, 200 do s:update(1 / 60); if s._buildDone then break end end
        t:truthy("coleção montada", #s.filtered > 10)

        s.scrollY = 0
        mx, my = 640, 300
        s:update(1 / 60)
        t:truthy("sem rolagem: hover na carta da grade", s.hoverCard ~= nil)

        s.scrollY = math.min(s.maxScrollY or 0, 260)
        t:truthy("fixture: a coleção rola", s.scrollY > 100)
        for _, y in ipairs({ 40, 75, 100, 118 }) do
            mx, my = 640, y
            s:update(1 / 60)
            t:falsy(("rolada: mouse nas abas (y=%d) não pega carta escondida"):format(y), s.hoverCard)
        end
        local hitMage, armedDrag = false, false
        for x = 20, 1200, 4 do
            s.filter = "all"
            s.scrollY = math.min(s.maxScrollY or 0, 260)
            s._dragPendingIdx = nil
            mx, my = x, 84
            s:mousepressed(mx, my, 1)
            if s._dragPendingIdx then armedDrag = true end
            s:mousereleased(mx, my, 1)
            if s.filter == "mage" then hitMage = true break end
        end
        t:truthy("rolada: clique na aba MAGE troca o filtro", hitMage)
        t:falsy("clique nas abas nunca arma arrasto de carta escondida", armedDrag)
        s.filter = "all"

        s.scrollY = 0
        s:_applyFilter()
        mx, my = 640, 700
        s:update(1 / 60)
        t:falsy("abaixo da grade (rodapé) não pega carta cortada", s.hoverCard)

    end)
    love.mouse.getPosition = realMouse
    love.graphics.getWidth, love.graphics.getHeight = realW, realH
    if not ok then error(err, 0) end
    return t:done()
end

return M
