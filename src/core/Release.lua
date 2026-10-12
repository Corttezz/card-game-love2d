-- src/core/Release.lua
-- Modo DEV x RELEASE, log em arquivo, tela de erro amigavel e self-test.
--
-- FLAG UNICA: a presenca do arquivo `build_info.lua` na RAIZ do jogo. Ele nao
-- existe no repositorio (esta no .gitignore) — so o `tools/build_release.py`
-- o escreve dentro da copia de release. Sem ele, o jogo e DEV. Assim nao ha
-- "esqueci de desligar o debug antes de publicar": o build e quem decide.
--
-- Este modulo e carregado pelo conf.lua (antes de qualquer modulo love.*
-- existir) — por isso nada aqui toca `love.*` no escopo do arquivo.
--
-- O que muda em RELEASE:
--   * conf.lua: sem console, identidade "Grimoire" (save dir proprio);
--   * argumentos de linha de comando sao ignorados (dispatcher de tools/
--     testes inacessivel — e tools/ nem vai no pacote);
--   * atalhos de dev desligados (Release.isDev() nos pontos de teclado);
--   * print() vira log em arquivo no save dir (logs/last_session.log);
--   * erro fatal mostra tela traduzida + caminho do crash log, nao o
--     stacktrace azul do LOVE (o crash log tem o stacktrace completo).
--
-- Self-test (qualquer modo): variavel de ambiente GRIMOIRE_SELFTEST=1. O
-- jogo boota de verdade, pula o splash, renderiza todas as cartas, abre uma
-- run de cada classe, desenha o menu por alguns segundos e sai com codigo
-- 0 (ok) ou 1 (falha), gravando selftest_result.txt no save dir. E o que o
-- smoke do executavel fundido usa (sem console nao ha stdout pra ler).

local Release = {}

local okInfo, info = pcall(require, "build_info")
if not okInfo then
    -- Ausente = DEV (estado normal do repositorio). Presente mas quebrado
    -- NAO pode virar DEV em silencio: o pacote sairia com console e atalhos.
    if not tostring(info):find("build_info' not found", 1, true)
       and not tostring(info):find("module 'build_info' not found", 1, true) then
        print("[Release] build_info.lua existe mas falhou ao carregar: " .. tostring(info))
        info = { release = true, broken = true }
    else
        info = {}
    end
end
if type(info) ~= "table" then info = {} end

Release.info    = info
Release.RELEASE = info.release == true
Release.DEV     = not Release.RELEASE

-- Nome do jogo (janela, save dir de release, pasta do build).
Release.GAME_NAME = "Grimoire"
-- Identidade (pasta de save). DEV mantem a historica pra nao orfanar os
-- saves de quem ja joga pelo `love .`; RELEASE usa o nome do jogo.
Release.IDENTITY_DEV     = "card-game"
Release.IDENTITY_RELEASE = "Grimoire"

function Release.isDev() return Release.DEV end
function Release.isRelease() return Release.RELEASE end

function Release.identity()
    local env = os.getenv("CARDGAME_IDENTITY")
    if env and env ~= "" then return env end
    return Release.RELEASE and Release.IDENTITY_RELEASE or Release.IDENTITY_DEV
end

function Release.selftestRequested()
    local v = os.getenv("GRIMOIRE_SELFTEST")
    return v ~= nil and v ~= "" and v ~= "0"
end

-- Em release, NENHUM argumento chega ao dispatcher do love.load: o Steam e o
-- Windows podem passar flags proprias, e o dispatcher inteiro (tools/testes)
-- nao existe no pacote — um `require("tools.x")` derrubaria o jogo.
function Release.filterArgs(args)
    if Release.DEV then return args end
    if args and #args > 0 then
        print("[Release] argumentos ignorados em release: " .. table.concat(args, " "))
    end
    return {}
end

---------------------------------------------------------------------------
-- LOG
---------------------------------------------------------------------------
-- Ring buffer das ultimas linhas impressas (dev e release): o crash log
-- anexa o que aconteceu logo antes do erro.
local RING_MAX = 300
local ring, ringHead = {}, 0

-- Release: buffer em memoria, descarregado em lote (abrir arquivo a cada
-- print custaria I/O por frame nos pontos ruidosos).
local LOG_FILE      = "logs/last_session.log"
local LOG_PREV      = "logs/previous_session.log"
local LOG_CAP_BYTES = 2 * 1024 * 1024
local pending, pendingN, logBytes, lastFlush = {}, 0, 0, 0
local logReady = false

local function nowSeconds()
    if love and love.timer and love.timer.getTime then return love.timer.getTime() end
    return os.clock()
end

local function pushRing(line)
    ringHead = ringHead % RING_MAX + 1
    ring[ringHead] = line
end

function Release.recentLines()
    local out = {}
    for i = 1, RING_MAX do
        local idx = (ringHead + i - 1) % RING_MAX + 1
        if ring[idx] then out[#out + 1] = ring[idx] end
    end
    return out
end

function Release.flushLog()
    if not logReady or pendingN == 0 then return end
    local chunk = table.concat(pending, "\n", 1, pendingN) .. "\n"
    pending, pendingN = {}, 0
    lastFlush = nowSeconds()
    if logBytes >= LOG_CAP_BYTES then return end
    logBytes = logBytes + #chunk
    pcall(love.filesystem.append, LOG_FILE, chunk)
end

local function openLog()
    if logReady or not (love and love.filesystem and love.filesystem.getSaveDirectory) then return end
    pcall(love.filesystem.createDirectory, "logs")
    -- Guarda a sessao anterior (um crash relatado "ontem" ainda tem log).
    if love.filesystem.getInfo(LOG_FILE) then
        local data = love.filesystem.read(LOG_FILE)
        if data then pcall(love.filesystem.write, LOG_PREV, data) end
    end
    pcall(love.filesystem.write, LOG_FILE, ("== %s %s (%s) %s ==\n"):format(
        Release.GAME_NAME, tostring(Release.version()),
        Release.RELEASE and "release" or "dev", os.date("%Y-%m-%d %H:%M:%S")))
    logReady = true
end

-- Troca o print global. DEV: continua no console + ring. RELEASE: ring +
-- arquivo (nao ha console).
function Release.installLogging()
    if Release._logInstalled then return end
    Release._logInstalled = true
    local rawPrint = print
    Release.rawPrint = rawPrint
    if Release.RELEASE then openLog() end
    _G.print = function(...)
        local n = select("#", ...)
        local parts = {}
        for i = 1, n do parts[i] = tostring((select(i, ...))) end
        local line = table.concat(parts, "\t")
        pushRing(line)
        if Release.DEV then
            rawPrint(...)
            return
        end
        if not logReady then openLog() end
        pendingN = pendingN + 1
        pending[pendingN] = line
        if pendingN >= 64 or nowSeconds() - lastFlush > 2 then Release.flushLog() end
    end
end

function Release.version()
    local ok, Config = pcall(require, "src.core.Config")
    if ok and type(Config) == "table" and Config.VERSION then return Config.VERSION end
    return info.version or "?"
end

---------------------------------------------------------------------------
-- MIGRACAO DE SAVE (release)
---------------------------------------------------------------------------
-- O jogo fundido salva em %APPDATA%/Grimoire; o `love .` de desenvolvimento
-- salva em %APPDATA%/LOVE/card-game. Quem jogou a versao de teste nao deve
-- perder perfil/conquistas/configuracoes no primeiro boot do executavel.
-- Copia UMA vez, so se o save dir novo estiver vazio dos arquivos conhecidos.
Release.MIGRATE_FILES = {
    "settings.lua", "i18n_settings.lua", "run.save.lua", "profile.lua",
    "unlocks.lua", "achievements.lua",
}

function Release.migrateDevSaves()
    if Release.DEV or os.getenv("CARDGAME_IDENTITY") then return end
    local fs = love.filesystem
    if fs.getInfo("migrated_from_dev.txt") then return end
    for _, name in ipairs(Release.MIGRATE_FILES) do
        if fs.getInfo(name) then return end
    end
    local base = fs.getAppdataDirectory and fs.getAppdataDirectory()
    if not base then return end
    local oldDir = base .. "/LOVE/" .. Release.IDENTITY_DEV .. "/"
    local copied = {}
    for _, name in ipairs(Release.MIGRATE_FILES) do
        local f = io.open(oldDir .. name, "rb")
        if f then
            local data = f:read("*a")
            f:close()
            if data and #data > 0 and fs.write(name, data) then
                copied[#copied + 1] = name
            end
        end
    end
    fs.write("migrated_from_dev.txt", ("from=%s\nfiles=%s\nat=%s\n"):format(
        oldDir, table.concat(copied, ","), os.date("%Y-%m-%d %H:%M:%S")))
    if #copied > 0 then
        print("[Release] saves migrados de " .. oldDir .. ": " .. table.concat(copied, ", "))
    end
end

---------------------------------------------------------------------------
-- CRASH
---------------------------------------------------------------------------
local function tr(key, fallback, vars)
    local ok, I18n = pcall(require, "src.i18n.I18n")
    if ok and type(I18n) == "table" and I18n.t then
        local ok2, s = pcall(I18n.t, key, vars, fallback)
        if ok2 and type(s) == "string" and s ~= "" and s ~= key then return s end
    end
    if vars then
        fallback = fallback:gsub("{(%w+)}", function(k) return tostring(vars[k] or "") end)
    end
    return fallback
end

local function systemInfo()
    local lines = {}
    lines[#lines + 1] = "game: " .. Release.GAME_NAME .. " " .. tostring(Release.version())
        .. " (" .. (Release.RELEASE and "release" or "dev") .. ")"
    if info.commit then lines[#lines + 1] = "build: " .. tostring(info.commit) .. " " .. tostring(info.date or "") end
    if love.getVersion then
        local a, b, c, cn = love.getVersion()
        lines[#lines + 1] = ("love: %d.%d.%d %s"):format(a, b, c, tostring(cn))
    end
    if love.system and love.system.getOS then lines[#lines + 1] = "os: " .. love.system.getOS() end
    if love.graphics and love.graphics.getRendererInfo then
        local ok, n, v, vendor, dev = pcall(love.graphics.getRendererInfo)
        if ok then lines[#lines + 1] = ("gpu: %s %s | %s | %s"):format(tostring(n), tostring(v), tostring(vendor), tostring(dev)) end
    end
    lines[#lines + 1] = "time: " .. os.date("%Y-%m-%d %H:%M:%S")
    return table.concat(lines, "\n")
end

-- Grava o crash log; devolve (nomeRelativo, caminhoAbsoluto) ou nil.
function Release.writeCrashLog(msg, trace)
    if not (love and love.filesystem and love.filesystem.write) then return nil end
    pcall(love.filesystem.createDirectory, "crashes")
    local name = "crashes/crash_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
    local body = table.concat({
        "== " .. Release.GAME_NAME .. " crash ==",
        systemInfo(),
        "",
        "error: " .. tostring(msg),
        "",
        tostring(trace or ""),
        "",
        "== ultimas linhas do log ==",
        table.concat(Release.recentLines(), "\n"),
    }, "\n")
    local ok = pcall(love.filesystem.write, name, body)
    if not ok then return nil end
    pcall(Release.flushLog)
    local dir = love.filesystem.getSaveDirectory and love.filesystem.getSaveDirectory() or ""
    return name, (dir .. "/" .. name):gsub("\\", "/")
end

local function utf8safe(s)
    local okU, utf8 = pcall(require, "utf8")
    s = tostring(s)
    if okU and utf8 and utf8.len and not utf8.len(s) then
        s = s:gsub("[\128-\255]", "?")
    end
    return s
end

-- love.errorhandler. DEV delega ao handler padrao do LOVE (stacktrace na
-- tela e no console e o que o desenvolvedor quer), mas grava o crash log
-- antes. RELEASE mostra a tela amigavel.
function Release.errorhandler(msg)
    msg = tostring(msg)
    local trace = debug.traceback("Error: " .. msg, 3)
    local _, absPath = Release.writeCrashLog(msg, trace)

    if Release._selftest and Release._selftest ~= "crash" then
        pcall(love.filesystem.write, "selftest_result.txt",
            "FAIL " .. tostring(Release.version()) .. "\n" .. trace .. "\n")
        return function() return 1 end
    end

    -- Tool/teste (`love . <arg>`) que quebra SAI com codigo 1: o handler
    -- padrao abre a tela azul e espera alguem fechar — uma suite quebrada
    -- ficava pendurada ate o timeout de quem a chamou.
    -- Erro ANTES do love.load (require quebrado no topo do main.lua) ainda
    -- nao tem HEADLESS_TOOL: olha o argumento cru — senao o build de release
    -- ficava 30 min pendurado na tela azul do test_all da copia limpa.
    local okArgs, gameArgs = pcall(function() return love.arg.parseGameArguments(arg) end)
    local toolRun = _G.HEADLESS_TOOL or (okArgs and type(gameArgs) == "table" and gameArgs[1] ~= nil)
    if Release.DEV and toolRun then
        print(trace)
        return function() return 1 end
    end

    if Release.DEV and Release._defaultErrorhandler then
        return Release._defaultErrorhandler(msg)
    end

    if not love.window or not love.graphics or not love.event then return end
    if not love.graphics.isCreated() or not love.window.isOpen() then
        local ok = pcall(love.window.setMode, 800, 600)
        if not ok then return end
    end
    if love.mouse then
        love.mouse.setVisible(true)
        love.mouse.setGrabbed(false)
        love.mouse.setRelativeMode(false)
        if love.mouse.isCursorSupported() then love.mouse.setCursor() end
    end
    if love.joystick then
        for _, j in ipairs(love.joystick.getJoysticks()) do pcall(j.setVibration, j) end
    end
    if love.audio then pcall(love.audio.stop) end
    love.graphics.reset()
    love.graphics.origin()

    local title = tr("crash.title", "Something went wrong")
    local body  = tr("crash.body", "The game hit an unexpected error and needs to close. Your progress up to the last floor is saved.")
    local where = tr("crash.log_path", "A report was saved to:")
    local hint  = tr("crash.hint", "Esc: close   C: copy report")
    local copied = tr("crash.copied", "Report copied to clipboard.")
    local pathText = utf8safe(absPath or "?")
    local copyText = utf8safe(trace)
    local justCopied = false
    local fontCache = nil

    local function draw()
        if not love.graphics.isActive() then return end
        local w, h = love.graphics.getDimensions()
        local s = math.max(1, math.min(w / 1024, h / 768))
        if not fontCache or fontCache.s ~= s then
            fontCache = { s = s,
                title = love.graphics.newFont(math.floor(28 * s)),
                body  = love.graphics.newFont(math.floor(16 * s)) }
        end
        local fTitle, fBody = fontCache.title, fontCache.body
        local pad = math.floor(48 * s)
        local wrapW = w - pad * 2
        love.graphics.clear(0.10, 0.07, 0.05)
        love.graphics.setColor(0.83, 0.69, 0.42)
        love.graphics.setFont(fTitle)
        love.graphics.printf(title, pad, pad, wrapW, "left")
        local y = pad + fTitle:getHeight() * 1.8
        love.graphics.setColor(0.93, 0.87, 0.74)
        love.graphics.setFont(fBody)
        love.graphics.printf(body, pad, y, wrapW, "left")
        local _, lines = fBody:getWrap(body, wrapW)
        y = y + (#lines + 1) * fBody:getHeight()
        love.graphics.printf(where, pad, y, wrapW, "left")
        y = y + fBody:getHeight() * 1.3
        love.graphics.setColor(0.83, 0.69, 0.42)
        love.graphics.printf(pathText, pad, y, wrapW, "left")
        love.graphics.setColor(0.65, 0.58, 0.48)
        love.graphics.printf(justCopied and copied or hint, pad, h - pad - fBody:getHeight(), wrapW, "left")
        love.graphics.present()
    end

    -- Validacao automatica da tela (o smoke nao enxerga janela): com
    -- GRIMOIRE_CRASH_SHOT=1 grava crash_screen.png no save dir e fecha.
    local shotFrames = os.getenv("GRIMOIRE_CRASH_SHOT") and 0 or nil

    return function()
        if shotFrames then
            shotFrames = shotFrames + 1
            if shotFrames == 2 then love.graphics.captureScreenshot("crash_screen.png") end
            if shotFrames > 4 then return 1 end
        end
        love.event.pump()
        for e, a in love.event.poll() do
            if e == "quit" then return 1 end
            if e == "keypressed" and (a == "escape" or a == "return" or a == "kpenter") then return 1 end
            if e == "keypressed" and a == "c" and love.system then
                pcall(love.system.setClipboardText, copyText .. "\n\n" .. systemInfo())
                justCopied = true
            end
        end
        draw()
        if love.timer then love.timer.sleep(0.1) end
    end
end

---------------------------------------------------------------------------
-- SELF-TEST
---------------------------------------------------------------------------
local function selftestDeep()
    local report = {}
    -- 1) Todas as cartas instanciam e renderizam a moldura (pega PNG que
    --    faltou no pacote).
    local CardDatabase = require("src.systems.CardDatabase")
    local db = CardDatabase:new()
    local n = 0
    for _, cd in pairs(db:getAllCards()) do
        assert(db:createCardInstance(cd), "carta nao instanciou: " .. tostring(cd.id))
        n = n + 1
    end
    assert(n > 0, "catalogo de cartas vazio")
    report[#report + 1] = "cards=" .. n
    -- 2) Uma run de cada classe sobe e entra em batalha. Saves no sandbox
    --    *.tool.lua (o SaveManager le a flag na hora da escrita).
    local prev = _G.HEADLESS_TOOL
    _G.HEADLESS_TOOL = true
    local okRun, errRun = pcall(function()
        local Game = require("src.core.Game")
        for _, cls in ipairs({ "warrior", "mage", "rogue" }) do
            local g = Game:new()
            g:startNewRun(cls)
            g:startGame()
            assert(g.player and g.enemy, "run sem player/enemy: " .. cls)
            assert(g.hand and #g.hand > 0, "mao vazia: " .. cls)
        end
    end)
    _G.HEADLESS_TOOL = prev
    if not okRun then error("selftest run: " .. tostring(errRun), 0) end
    report[#report + 1] = "runs=3"
    return table.concat(report, " ")
end

-- Envolve o love.run padrao: roda o jogo de verdade e injeta o roteiro.
-- GRIMOIRE_SELFTEST=crash: em vez de passar, provoca um erro depois do boot
-- pra exercitar a tela de erro e o crash log do PACOTE (com
-- GRIMOIRE_CRASH_SHOT=1 a tela vira crash_screen.png e o processo sai com 1).
local function installSelftest()
    Release._selftest = (os.getenv("GRIMOIRE_SELFTEST") == "crash") and "crash" or true
    local baseRun = love.run
    love.run = function()
        local loop = baseRun()
        local t0 = nil
        local frames = 0
        local skipped, deepDone, deepReport = false, false, ""
        return function()
            local r = loop()
            if r ~= nil then return r end
            frames = frames + 1
            t0 = t0 or love.timer.getTime()
            local t = love.timer.getTime() - t0
            if not skipped and t > 0.8 then
                skipped = true
                love.event.push("keypressed", "space", "space", false)
            end
            if Release._selftest == "crash" and t > 2.0 then
                error("selftest: erro induzido para validar a tela de crash")
            end
            if skipped and not deepDone and t > 2.0 then
                deepDone = true
                deepReport = selftestDeep()
            end
            if deepDone and t > 4.0 then
                local line = ("OK %s frames=%d %s\n"):format(tostring(Release.version()), frames, deepReport)
                love.filesystem.write("selftest_result.txt", line)
                print("[selftest] " .. line)
                Release.flushLog()
                return 0
            end
        end
    end
end

-- Chamado na PRIMEIRA linha do main.lua (antes dos requires do jogo), pra
-- que um erro ja no carregamento dos modulos passe pelo handler.
function Release.install()
    if Release._installed then return end
    Release._installed = true
    Release._defaultErrorhandler = love.errorhandler or love.errhand
    love.errorhandler = Release.errorhandler
    Release.installLogging()
    if Release.RELEASE then pcall(Release.migrateDevSaves) end
    -- Laco com teto de quadros fora de foco + shutdown ordenado. ANTES do
    -- selftest, que envolve o love.run vigente (o smoke roda o laco real).
    require("src.core.AppLoop").install()
    if Release.selftestRequested() then installSelftest() end
end

return Release
