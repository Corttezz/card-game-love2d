local I18n = require("src.i18n.I18n")
local RunModifiers = require("src.systems.RunModifiers")

local M = {}

function M.short(run, compact)
    if not run then return "" end
    local parts = {}
    local seal = RunModifiers.seal(run)
    if seal > 0 then parts[#parts + 1] = I18n.t("seal_ui.short", { n = seal }) end
    if run.endlessMode and RunModifiers.cycle(run) > 0 then
        parts[#parts + 1] = I18n.t("endless.short", { n = RunModifiers.cycle(run) })
        local k = RunModifiers.totalCurseStacks(run)
        if k > 0 and not compact then parts[#parts + 1] = I18n.t("endless.curses_short", { n = k }) end
    end
    return table.concat(parts, " · ")
end

function M.long(run)
    if not run then return "" end
    local out = {}
    local seal = RunModifiers.seal(run)
    if seal > 0 then
        local def = RunModifiers.SEALS[seal]
        out[#out + 1] = I18n.t("seal_ui.summary", { n = seal,
            name = I18n.t("seals." .. def.id .. ".name") }) .. "."
    end
    local list = RunModifiers.curseList(run)
    if #list > 0 then
        local parts = {}
        for _, c in ipairs(list) do
            parts[#parts + 1] = I18n.t("endless_curses." .. c.id .. ".name") .. " x" .. c.stacks
        end
        out[#out + 1] = I18n.t("endless.active", { list = table.concat(parts, " · ") }) .. "."
    end
    if #out == 0 then return "" end
    out[#out + 1] = I18n.t("endless.score_total", {
        n = string.format("%.2f", RunModifiers.scoreMul(run)) })
    return " " .. table.concat(out, " ")
end

return M
