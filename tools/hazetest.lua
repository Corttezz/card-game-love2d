local M = {}
function M.run()
    local ok, sh = pcall(love.graphics.newShader, "shaders/haze.glsl")
    print("[hazetest] compilou:", ok, tostring(sh))
    if not ok then print("[hazetest] ERRO:", sh) end
    if ok and sh then
        local ok2, err = pcall(function() sh:send("hazeColor", {1,0,0}) end)
        print("[hazetest] send hazeColor:", ok2, tostring(err))
    end
    love.event.quit()
end
return M
