-- tools/run_i18n_test.lua
-- Entry point alternativo (substitui main.lua) que so roda o teste de i18n.
-- Uso: copie temporariamente para main.lua ou rode com:
--   love --console --fused . --i18n-test
-- Mais simples: execute via patch direto no love.load.

function love.load()
    require("tools.test_i18n")
end
