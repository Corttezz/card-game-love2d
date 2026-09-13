-- tools/check_music.lua
-- Percorre os contextos do jogo e diz QUAL faixa tocaria em cada um, usando o
-- caminho REAL: AudioManager de verdade, `MusicDirector.registerTracks` de
-- verdade, `MusicDirector.apply` de verdade.
--
-- Existe porque `tools/test_music.lua` testa só a decisão (`pick`, que é pura)
-- e a suíte nunca executa `love.update` — ou seja, nada na suíte exercita o
-- registro, o `resolve` com fallback, nem o `playMusic`. Foi assim que um
-- `local` a mais no topo do main.lua passou verde em 35 suites e derrubou o
-- jogo no boot ("more than 60 upvalues").
--
-- Roda com o MASTER EM ZERO: valida sem tocar som na máquina de ninguém.
--
--   love . check_music

local M = {}

local CONTEXTOS = {
    { "menu",         nil,               nil,      "Menu / splash" },
    { "classSelection", nil,             nil,      "Selecao de classe" },
    { "playing",      { actNumber = 1 }, "battle", "Ato 1 - combate" },
    { "mapSelection", { actNumber = 1 }, nil,      "Ato 1 - mapa" },
    { "cardReward",   { actNumber = 1 }, "battle", "Recompensa pos-batalha" },
    { "cardReward",   { actNumber = 1 }, "shop",   "Loja de reliquias" },
    { "rest",         { actNumber = 1 }, "rest",   "Fogueira / descanso" },
    { "playing",      { actNumber = 1 }, "elite",  "Elite do ato 1" },
    { "playing",      { actNumber = 1 }, "boss",   "Boss do ato 1" },
    { "playing",      { actNumber = 2 }, "battle", "Ato 2 - combate" },
    { "playing",      { actNumber = 2 }, "boss",   "Boss do ato 2" },
    { "playing",      { actNumber = 3 }, "battle", "Ato 3 - combate" },
    { "playing",      { actNumber = 3 }, "boss",   "Boss do ato 3" },
    { "playing",      { actNumber = 6 }, "battle", "Endless" },
    { "victory",      { actNumber = 3 }, nil,      "Vitoria" },
}

function M.run()
    local AudioManager = require("engine.AudioManager")
    local MD = require("src.systems.MusicDirector")

    local audio = AudioManager:new()
    _G.audioSystem = audio
    audio:setGroupVolume("master", 0)   -- mudo: isto e teste, nao playtest

    print("")
    print("=== TRILHA POR CONTEXTO ===")

    if not audio:isAudioAvailable() then
        print("Audio indisponivel neste ambiente — so a decisao pode ser conferida.")
        print("Use `love . test_one test_music` para isso.")
        love.event.quit(0)
        return true
    end

    local loaded = MD.registerTracks(audio)
    audio:loadSound("menuMusic", "audio/music.mp3", {
        volume = 0.6, group = "music", stream = true, loop = true })

    print(string.format("%d de %d faixas registradas em audio/music/.",
        loaded, (function() local n = 0; for _ in pairs(MD.TRACKS) do n = n + 1 end; return n end)()))
    print("")
    print(string.format("%-26s %-14s %s", "contexto", "faixa", "obs"))

    local fails = 0
    MD._current = nil
    for _, c in ipairs(CONTEXTOS) do
        local before = MD._current
        MD.apply(c[1], c[2], c[3])
        local now = MD._current

        local obs = ""
        if now == before then obs = "(mantem)" end

        -- A faixa que o diretor diz estar tocando tem que ser a que o
        -- AudioManager realmente pegou. Divergir aqui significa que o
        -- playMusic falhou em silencio.
        if now ~= audio.currentMusic then
            obs = obs .. "  DIVERGE! audioSystem=" .. tostring(audio.currentMusic)
            fails = fails + 1
        end

        -- Contexto caindo em fallback é legítimo, mas tem que aparecer.
        local wanted = MD.pick(c[1], c[2], c[3])
        if wanted and wanted ~= now then
            obs = obs .. "  fallback de " .. wanted
        end

        print(string.format("%-26s %-14s %s", c[4], tostring(now), obs))
    end

    audio:stopMusic()
    print(string.format("\n%s", fails == 0
        and "Diretor e AudioManager concordam em todos os contextos."
        or  (fails .. " contexto(s) divergindo — playMusic falhou calado.")))
    love.event.quit(fails == 0 and 0 or 1)
    return fails == 0
end

return M
