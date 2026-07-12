-- tools/run_i18n_test.lua
-- Entry point alternativo (substitui main.lua) que so roda o teste de i18n.
-- Mais simples: rode direto com o dispatcher do main.lua:
--   love . test_i18n

function love.load()
    local ok = require("tools.test_i18n").run()
    love.event.quit(ok and 0 or 1)
end
