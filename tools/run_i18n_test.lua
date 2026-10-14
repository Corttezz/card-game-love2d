function love.load()
    local ok = require("tools.test_i18n").run()
    love.event.quit(ok and 0 or 1)
end
