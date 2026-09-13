-- tools/check_seal_sfx.lua
-- Confere que os 5 sons de lacre REGISTRAM e ficam visiveis pro Sfx.has.
-- Existe porque a integracao depende de um registro sob demanda: se ele
-- falhar, o jogo degrada calado pro som generico e ninguem percebe.
local M = {}

function M.run()
    local PackThemes = require("src.ui.PackThemes")
    local Sfx = require("src.systems.Sfx")

    -- Tools nao passam pelo boot que cria _G.audioSystem, entao instanciamos um
    -- AudioManager proprio: o que interessa validar e se os 5 arquivos CARREGAM
    -- e ficam visiveis pro Sfx.has, nao qual instancia os guarda.
    local audio = _G.audioSystem
    if not audio then
        local AudioManager = require("engine.AudioManager")
        audio = AudioManager:new()
        _G.audioSystem = audio
        _G.__sealToolAudio = true
        print("[check_seal] audioSystem proprio (contexto de tool)")
    end
    if not audio.isAudioAvailable or not audio:isAudioAvailable() then
        print("[check_seal] audio indisponivel nesta maquina -- inconclusivo")
        return true
    end

    local n = PackThemes.registerSealSounds(audio)
    print("[check_seal] registrados agora: " .. tostring(n))

    local ok = true
    for _, kind in ipairs({ "Standard", "Buffoon", "Arcana", "Celestial", "Spectral" }) do
        local th = PackThemes.get(kind)
        local has = Sfx.has(th.sealCode)
        local onDisk = love.filesystem.getInfo(th.sealFile) ~= nil
        print(string.format("  %-10s %-22s arquivo=%s  registrado=%s  vol=%.2f",
            kind, th.sealCode, tostring(onDisk), tostring(has), th.sealVolume or -1))
        if onDisk and not has then ok = false end
    end
    -- Idempotencia: e ela que torna seguro chamar o registro em toda abertura
    -- de pacote. Uma 2a passada tem que registrar ZERO.
    local again = PackThemes.registerSealSounds(audio)
    print("  2a chamada registrou " .. tostring(again) .. " (tem que ser 0)")
    if again ~= 0 then ok = false end

    -- O fallback generico e carregado por main.lua no boot; num contexto de
    -- tool ele nao existe, e isso NAO e falha.
    print("  fallback packSealBreak presente=" .. tostring(Sfx.has("packSealBreak"))
        .. (_G.__sealToolAudio and " (ausente e esperado fora do jogo)" or ""))
    print(ok and "[check_seal] OK" or "[check_seal] FALHOU")
    return ok
end

return M
