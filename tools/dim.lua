local M = {}
function M.run(dir)
    for _, f in ipairs(love.filesystem.getDirectoryItems(dir)) do
        if f:match("%.png$") then
            local ok, d = pcall(love.image.newImageData, dir .. "/" .. f)
            if ok then print(("%-28s %dx%d"):format(f, d:getWidth(), d:getHeight())) end
        end
    end
    love.event.quit(0); return true
end
return M
