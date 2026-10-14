local M = {}

function M.run()
    local PackThemes = require("src.ui.PackThemes")
    local Sfx = require("src.systems.Sfx")

    local audio = _G.audioSystem
    if not audio then
        local AudioManager = require("engine.AudioManager")
        audio = AudioManager:new()
        _G.audioSystem = audio
        _G.__sealToolAudio = true
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
    local again = PackThemes.registerSealSounds(audio)
    print("  2a chamada registrou " .. tostring(again) .. " (tem que ser 0)")
    if again ~= 0 then ok = false end

    print("  fallback packSealBreak presente=" .. tostring(Sfx.has("packSealBreak"))
        .. (_G.__sealToolAudio and " (ausente e esperado fora do jogo)" or ""))
    print(ok and "[check_seal] OK" or "[check_seal] FALHOU")
    return ok
end

return M
