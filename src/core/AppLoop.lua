-- src/core/AppLoop.lua
-- Laco principal (love.run) do jogo + encerramento ordenado.
--
-- Por que existe (auditoria de release, Out/2026): o love.run padrao roda
-- update+draw a toda velocidade em QUALQUER estado da janela. Medido no
-- executavel de release: ~21% de um nucleo no menu com foco, ~25% com a
-- janela visivel sem foco e ~29% MINIMIZADA (minimizada o vsync nao segura
-- nada — o present volta na hora). Jogo parado numa aba de fundo nao deve
-- custar isso.
--
-- Regras do laco:
--   * janela com foco + vsync ligado: igual ao padrao (o vsync dita o ritmo);
--   * vsync DESLIGADO (opcao em Configuracoes -> Video): teto na taxa do
--     monitor (60..240) em vez de girar livre a 100% de um nucleo;
--   * visivel SEM foco: BACKGROUND_FPS (update + draw, a cena segue viva);
--   * minimizada/oculta: HIDDEN_FPS e SEM draw (nada a mostrar). O update
--     continua — musica, crossfade e timers seguem coerentes, so mais
--     espacados (o dt real e entregue, com teto MAX_DT).
--   * ferramentas (_G.HEADLESS_TOOL): nunca estrangula — tool rodando em
--     segundo plano nao pode ficar 5x mais lento.
--
-- Encerramento: o evento "quit" (fechar a janela, love.event.quit, Alt+F4)
-- passa por AppLoop.shutdown() DEPOIS de love.quit (se algum modulo definir
-- um e ele nao cancelar). Fica aqui, e nao num `function love.quit` do
-- main.lua, porque (1) main.lua nao aceita mais locais de arquivo e (2) um
-- love.quit definido depois por outra frente sobrescreveria o nosso em
-- silencio. O shutdown: lembra monitor/posicao da janela, fecha a Steam e
-- descarrega o log de release (que so grava a cada 2 s / 64 linhas).
--
-- Instalado por Release.install() (1a linha do main.lua), ANTES do wrapper
-- do selftest — que envolve este laco, entao o smoke exercita o laco real.

local AppLoop = {}

AppLoop.BACKGROUND_FPS = 15
AppLoop.HIDDEN_FPS     = 8
AppLoop.MAX_DT         = 0.25
AppLoop.NOVSYNC_MIN    = 60
AppLoop.NOVSYNC_MAX    = 240

-- Teto de quadros pro estado atual da janela. nil = sem teto (vsync manda).
-- Segundo retorno: true = nao desenhar (janela minimizada/oculta).
-- Puro sobre `win` pra ser testavel (tools/test_app_loop.lua).
function AppLoop.frameCap(win, headless)
    if headless then return nil, false end
    if win.minimized or not win.visible then
        return AppLoop.HIDDEN_FPS, true
    end
    if not win.focused then
        return AppLoop.BACKGROUND_FPS, false
    end
    if not win.vsync then
        local hz = tonumber(win.refreshrate) or 0
        if hz <= 0 then hz = AppLoop.NOVSYNC_MIN end
        return math.max(AppLoop.NOVSYNC_MIN, math.min(AppLoop.NOVSYNC_MAX, hz)), false
    end
    return nil, false
end

-- Estado da janela, lido 1x por quadro. O modo (vsync/refreshrate) so muda
-- quando o jogador mexe nas Configuracoes; cacheado e relido a cada ~1 s.
local winState = { focused = true, visible = true, minimized = false,
                   vsync = true, refreshrate = 60 }
local modeCheckedAt = -math.huge

local function readWindow(now)
    local w = love.window
    if not (w and w.isOpen and w.isOpen()) then
        winState.visible = false
        return winState
    end
    winState.focused   = w.hasFocus()
    winState.visible   = w.isVisible()
    winState.minimized = w.isMinimized and w.isMinimized() or false
    if now - modeCheckedAt > 1 then
        modeCheckedAt = now
        local _, _, flags = w.getMode()
        winState.vsync = (flags.vsync or 0) ~= 0
        winState.refreshrate = flags.refreshrate
    end
    return winState
end

function AppLoop.run()
    if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
    if love.timer then love.timer.step() end
    local dt = 0
    return function()
        local frameStart = love.timer.getTime()
        if love.event then
            love.event.pump()
            for name, a, b, c, d, e, f in love.event.poll() do
                if name == "quit" then
                    if not love.quit or not love.quit() then
                        AppLoop.shutdown()
                        return a or 0
                    end
                end
                love.handlers[name](a, b, c, d, e, f)
            end
        end

        dt = math.min(love.timer.step(), AppLoop.MAX_DT)
        local cap, skipDraw = AppLoop.frameCap(readWindow(frameStart), _G.HEADLESS_TOOL)

        if love.update then love.update(dt) end
        if not skipDraw and love.graphics and love.graphics.isActive() then
            love.graphics.origin()
            love.graphics.clear(love.graphics.getBackgroundColor())
            if love.draw then love.draw() end
            love.graphics.present()
        end

        local rest = cap and (1 / cap - (love.timer.getTime() - frameStart)) or 0
        love.timer.sleep(rest > 0.001 and rest or 0.001)
    end
end

-- Idempotente: o laco chama no "quit"; testes podem chamar direto.
local didShutdown = false
function AppLoop.shutdown()
    if didShutdown then return end
    didShutdown = true
    local function step(name, fn)
        local ok, err = pcall(fn)
        if not ok then print("[AppLoop] AVISO: shutdown/" .. name .. " falhou: " .. tostring(err)) end
    end
    if not _G.HEADLESS_TOOL then
        step("janela", function()
            local settings = _G.persistedSettings
            if settings and require("src.core.WindowPlacement").remember(settings) then
                require("engine.SaveManager").saveSettings(settings)
            end
        end)
    end
    step("steam", function() require("src.systems.SteamBridge").shutdown() end)
    print("[AppLoop] encerrando")
    step("log", function() require("src.core.Release").flushLog() end)
end

function AppLoop.install()
    if AppLoop._installed then return end
    AppLoop._installed = true
    love.run = AppLoop.run
end

return AppLoop
