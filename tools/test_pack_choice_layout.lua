local TK = require("tools.testkit")
local M = {}

local SIZES = {
    { 1024, 768 }, { 1280, 720 }, { 1280, 800 }, { 1366, 768 },
    { 1600, 900 }, { 1920, 1080 }, { 2560, 1440 },
}

function M.run()
    TK.bootstrap()
    local t = TK.new("test_pack_choice_layout")
    local Layout = require("src.ui.PackChoiceLayout")
    local UiScale = require("src.ui.UiScale")
    local TOP = 52

    for _, sz in ipairs(SIZES) do
        local k = UiScale.k(sz[1], sz[2])
        local vw, vh = math.floor(sz[1] / k), math.floor(sz[2] / k)
        for _, n in ipairs({ 2, 3, 5 }) do
            local tag = ("%dx%d n=%d"):format(sz[1], sz[2], n)
            local z = Layout.compute(n, 96, 144, vw, vh, TOP)
            t:check(tag .. ": cabeçalho abaixo da barra superior (y=" .. z.header.y .. ")",
                z.header.y >= TOP)
            t:check(tag .. ": ação dentro da tela",
                z.action.y + z.action.h <= vh)
            local ok, errs = Layout.validate(z, vw, vh)
            t:check(tag .. ": zonas válidas" .. (ok and "" or (": " .. table.concat(errs or {}, "; "))), ok)
        end
    end

    local plain = Layout.compute(3, 96, 144, 1280, 720)
    local inset = Layout.compute(3, 96, 144, 1280, 720, 0)
    t:eq("sem barra: mesmo layout de antes", plain.header.y, inset.header.y)

    return t:done()
end

return M
