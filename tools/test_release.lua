local TK = require("tools.testkit")

local M = {}

function M.run()
    local t = TK.new("release")
    local Release = require("src.core.Release")

    t:truthy("repositorio roda em DEV", Release.isDev())
    t:falsy("repositorio nao e RELEASE", Release.isRelease())
    t:falsy("build_info.lua nao esta no repositorio",
        love.filesystem.getInfo("build_info.lua"))

    local args = { "test_one", "x" }
    t:eq("DEV: argumentos passam intactos", Release.filterArgs(args), args)

    Release.DEV, Release.RELEASE = false, true
    local okF, filtered = pcall(Release.filterArgs, { "test_all" })
    Release.DEV, Release.RELEASE = true, false
    t:truthy("RELEASE: filterArgs nao quebra", okF)
    t:eq("RELEASE: argumentos descartados", okF and #filtered, 0)

    t:eq("identidade de release", Release.IDENTITY_RELEASE, "Grimoire")

    local SaveManager = require("engine.SaveManager")
    local path = "release_probe.tool.lua"
    love.filesystem.write(path, "return { ok = true, n = 3 }")
    local chunk = SaveManager.loadDataChunk(path)
    local okC, v = pcall(chunk or error)
    t:truthy("save de dados carrega", okC and v and v.ok and v.n == 3)

    love.filesystem.write(path, "return { escape = (os ~= nil) or (io ~= nil) or (love ~= nil) }")
    chunk = SaveManager.loadDataChunk(path)
    okC, v = pcall(chunk or error)
    t:truthy("save nao enxerga os/io/love", okC and v and v.escape == false)

    love.filesystem.write(path, string.dump(function() return {} end))
    chunk = SaveManager.loadDataChunk(path)
    t:falsy("save em bytecode e recusado", chunk)
    love.filesystem.remove(path)

    print("release-probe linha de contexto")
    local rel, abs = Release.writeCrashLog("erro de teste", "stack de teste")
    t:truthy("crash log gravado", rel and love.filesystem.getInfo(rel))
    t:truthy("caminho absoluto pro jogador", abs and abs:find("crashes/crash_", 1, true))
    local body = rel and love.filesystem.read(rel) or ""
    t:truthy("crash log tem a mensagem", body:find("erro de teste", 1, true))
    t:truthy("crash log tem as ultimas linhas", body:find("release-probe linha de contexto", 1, true))
    if rel then love.filesystem.remove(rel) end

    return t:done()
end

return M
