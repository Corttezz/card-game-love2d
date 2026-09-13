-- src/systems/MusicDirector.lua
-- Escolhe QUAL faixa toca, a partir do estado do jogo.
--
-- Desenho deliberado: o diretor **observa** o estado a cada frame em vez de
-- ser avisado pelas telas. Notificar exigiria uma chamada em cada uma das ~14
-- transições de `currentState` espalhadas pelo main.lua, e a transição que
-- alguém esquecesse de instrumentar daria "música errada" — um defeito que
-- não trava, não loga e só é percebido por quem estiver ouvindo. Observar é
-- idempotente: `apply()` roda todo frame e o `playMusic` só age quando o
-- código muda de verdade (`currentMusic == code` é no-op no AudioManager).
--
-- Fallback: faixa ausente cai para a anterior da cadeia e, no limite, para
-- `menuMusic` (audio/music.mp3), que sempre existe. Mesmo contrato dos SFX
-- (memory/sfx_generation.md) — soltar o arquivo em audio/music/ basta.

local Sfx = require("src.systems.Sfx")

local MusicDirector = {}

-- Faixas da trilha: código -> arquivo em audio/music/.
-- Fonte ÚNICA. `registerTracks` carrega a partir daqui e `pick` devolve
-- códigos daqui; `tools/test_music.lua` cruza as duas listas, de modo que um
-- código digitado errado num dos lados falha na suíte em vez de virar
-- "essa tela ficou muda" meses depois.
MusicDirector.TRACKS = {
    musicAct1 = "music-act1.mp3",
    musicAct2 = "music-act2.mp3",
    musicAct3 = "music-act3.mp3",
    musicBoss = "music-boss.mp3",
    musicShop = "music-shop.mp3",
    musicRest = "music-rest.mp3",
}

-- Registro por SCAN (mesmo contrato dos SFX): o arquivo dita a existência, o
-- código só declara. Faixa ausente não quebra nada — o fallback cobre.
-- Volume 0.6 no registro porque as faixas já vêm niveladas por loudness
-- (ver memory/music_generation.md); não calibrar por palpite no call site.
function MusicDirector.registerTracks(audioSystem)
    if not audioSystem then return 0 end
    local loaded = 0
    for code, file in pairs(MusicDirector.TRACKS) do
        local path = "audio/music/" .. file
        if love.filesystem.getInfo(path) then
            audioSystem:loadSound(code, path, {
                volume = 0.6, group = "music", stream = true, loop = true,
            })
            loaded = loaded + 1
        end
    end
    return loaded
end

-- Tempo de cruzamento por tipo de troca. Entrar em combate corta mais rápido
-- que sair dele: a tensão precisa chegar junto com o inimigo, e o alívio pode
-- demorar.
local FADE_FAST = 1.2
local FADE_SLOW = 2.5

MusicDirector.enabled = true
MusicDirector._current = nil

-- Cadeia de fallback: se a faixa não foi registrada, tenta a seguinte.
local FALLBACK = {
    musicAct1 = "menuMusic",
    musicAct2 = "musicAct1",
    musicAct3 = "musicAct2",
    musicBoss = "musicAct3",
    musicShop = "musicAct1",
    musicRest = "musicAct1",
    menuMusic = nil,
}

local function resolve(code)
    local seen = 0
    while code and seen < 8 do
        if Sfx.has(code) then return code end
        code = FALLBACK[code]
        seen = seen + 1
    end
    return nil
end

-- Deriva o código da faixa a partir de (estado da tela, run corrente).
-- Pública para que os testes possam exercitar a decisão sem áudio nenhum.
function MusicDirector.pick(state, run, nodeType)
    if state == "boot" or state == "menu" or state == "classSelection"
        or state == "collection" or state == "achievements"
        or state == "gameOver" or state == "victory" then
        return "menuMusic"
    end

    if state == "cardReward" then
        -- O mesmo state serve recompensa de batalha E loja; só a loja tem
        -- tema próprio. Sem a distinção, a recompensa pós-luta trocaria de
        -- música por 4 segundos e voltaria — pior que não trocar.
        return (nodeType == "shop") and "musicShop" or nil
    end

    if state == "rest" then return "musicRest" end

    if state == "playing" and nodeType == "boss" then return "musicBoss" end

    local act = (run and run.actNumber) or 1
    if act >= 3 then return "musicAct3" end
    if act == 2 then return "musicAct2" end
    return "musicAct1"
end

-- Chamado todo frame pelo main.lua. `nil` de `pick` significa "mantenha o que
-- está tocando" (ex.: recompensa pós-batalha, que é uma pausa dentro do ato).
function MusicDirector.apply(state, run, nodeType)
    if not MusicDirector.enabled then return end

    local wanted = MusicDirector.pick(state, run, nodeType)
    if not wanted then return end

    local code = resolve(wanted)
    if not code or code == MusicDirector._current then return end

    local fade = (code == "musicBoss") and FADE_FAST or FADE_SLOW
    Sfx.playMusic(code, { fadeDuration = fade })
    MusicDirector._current = code
end

-- O menu chama isto ao terminar o splash; deixa o diretor em dia para não
-- recomeçar a música na primeira passada do update.
function MusicDirector.markCurrent(code)
    MusicDirector._current = code
end

return MusicDirector
