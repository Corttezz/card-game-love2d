local TK = require("tools.testkit")
local MD = require("src.systems.MusicDirector")
local Config = require("src.core.Config")

local M = {}

function M.run()
    local t = TK.new("music")

    for _, s in ipairs({ "boot", "menu", "classSelection", "collection",
                         "achievements", "gameOver", "victory" }) do
        t:eq("tela fora da run: " .. s, MD.pick(s, nil, nil), "menuMusic")
    end

    t:eq("ato 1 em combate", MD.pick("playing", { actNumber = 1 }, "battle"), "musicAct1")
    t:eq("ato 2 em combate", MD.pick("playing", { actNumber = 2 }, "battle"), "musicAct2")
    t:eq("ato 3 em combate", MD.pick("playing", { actNumber = 3 }, "battle"), "musicAct3")
    t:eq("mapa segue o ato",  MD.pick("mapSelection", { actNumber = 2 }, nil), "musicAct2")

    t:eq("endless fica no tema do ultimo ato",
         MD.pick("playing", { actNumber = Config.TotalActs + 4 }, "battle"),
         "musicAct" .. Config.TotalActs)

    t:eq("sem run assume ato 1", MD.pick("playing", nil, nil), "musicAct1")

    t:eq("boss do ato 1", MD.pick("playing", { actNumber = 1 }, "boss"), "musicBoss")
    t:eq("boss do ato 3", MD.pick("playing", { actNumber = 3 }, "boss"), "musicBoss")
    t:eq("elite nao usa tema de boss", MD.pick("playing", { actNumber = 1 }, "elite"), "musicAct1")

    local rainha = { actNumber = Config.TotalActs, currentNode = { type = "boss", enemyId = "eclipse_queen" } }
    local rei = { actNumber = 1, currentNode = { type = "boss", enemyId = "carrion_king" } }
    t:eq("rainha no salao = faixa do chefe final", MD.pick("playing", rainha, "boss", true), "musicBossEclipse")
    t:eq("rainha na estrada (porta fechada) = tema comum", MD.pick("playing", rainha, "boss", false), "musicBoss")
    t:eq("outro chefe no salao = tema comum", MD.pick("playing", rei, "boss", true), "musicBoss")
    t:eq("save antigo sem enemyId no ultimo ato = chefe final",
         MD.pick("playing", { actNumber = Config.TotalActs, currentNode = { type = "boss" } }, "boss", true),
         "musicBossEclipse")
    t:eq("endless sem enemyId nao e o chefe final",
         MD.pick("playing", { actNumber = Config.TotalActs, endlessMode = true, currentNode = { type = "boss" } }, "boss", true),
         "musicBoss")
    t:eq("cash out no salao da rainha mantem a faixa", MD.pick("roundEval", rainha, "boss", true), nil)
    t:eq("espolios no salao da rainha mantem a faixa", MD.pick("cardReward", rainha, "boss", true), nil)
    t:eq("sem probe de salao, boss = tema comum (apply sem cena)", MD.pick("playing", rainha, "boss"), "musicBoss")

    t:eq("descanso", MD.pick("rest", { actNumber = 2 }, "rest"), "musicRest")
    t:eq("loja",     MD.pick("cardReward", { actNumber = 2 }, "shop"), "musicShop")

    t:eq("recompensa pos-batalha NAO troca de musica",
         MD.pick("cardReward", { actNumber = 2 }, "battle"), nil)
    t:eq("recompensa pos-boss NAO troca de musica",
         MD.pick("cardReward", { actNumber = 1 }, "boss"), nil)
    t:eq("cash out pos-boss NAO troca de musica",
         MD.pick("roundEval", { actNumber = 1 }, "boss"), nil)
    t:eq("cash out pos-batalha NAO troca de musica",
         MD.pick("roundEval", { actNumber = 2 }, "battle"), nil)

    local produced = {}
    local casos = {
        { "menu", nil, nil },
        { "playing", { actNumber = 1 }, "boss" }, { "rest", { actNumber = 1 }, "rest" },
        { "cardReward", { actNumber = 1 }, "shop" },
        { "playing", { actNumber = Config.TotalActs, currentNode = { type = "boss", enemyId = "eclipse_queen" } }, "boss", true },
    }
    for a = 1, Config.TotalActs do
        casos[#casos + 1] = { "playing", { actNumber = a }, "battle" }
    end
    for _, case in ipairs(casos) do
        local code = MD.pick(case[1], case[2], case[3], case[4])
        if code then produced[code] = true end
    end
    for code in pairs(produced) do
        t:truthy("codigo '" .. code .. "' e uma faixa registravel",
                 code == "menuMusic" or MD.TRACKS[code] ~= nil)
    end

    for code in pairs(MD.TRACKS) do
        t:truthy("faixa '" .. code .. "' e alcancavel por algum contexto", produced[code])
    end

    for code, file in pairs(MD.TRACKS) do
        t:truthy("audio/music/" .. file .. " existe",
                 love.filesystem.getInfo("audio/music/" .. file) ~= nil)
    end

    local AudioManager = require("engine.AudioManager")
    local audio = AudioManager:new()
    if audio:isAudioAvailable() then
        audio:setGroupVolume("master", 0)
        MD.registerTracks(audio)
        audio:loadSound("menuMusic", "audio/music.mp3", {
            volume = 0.6, group = "music", stream = true, loop = true })

        local function tocando()
            local n, quais = 0, {}
            for code, e in pairs(audio.sources) do
                if e.group == "music" and e.template and e.template:isPlaying() then
                    n = n + 1; quais[#quais + 1] = code
                end
            end
            table.sort(quais)
            return n, table.concat(quais, "+")
        end

        audio:playMusic("musicAct1", { fadeDuration = 2.5 })
        audio:update(0.1)
        audio:playMusic("musicShop", { fadeDuration = 2.5 })
        audio:update(0.1)
        audio:playMusic("musicRest", { fadeDuration = 2.5 })
        audio:update(0.1)
        local n, quais = tocando()
        t:truthy("no meio da cadeia, no maximo 2 faixas (" .. quais .. ")", n <= 2)

        audio:playMusic("musicAct1", { fadeDuration = 2.5 })
        for _ = 1, 200 do audio:update(1 / 60) end
        local n2, quais2 = tocando()
        t:eq("depois de assentar, UMA faixa so (" .. quais2 .. ")", n2, 1)
        t:eq("e e a certa", audio.currentMusic, "musicAct1")

        for _, caso in ipairs({
            { nome = "menu ja assentado", framesAntes = 200 },
            { nome = "clique em cima do fade-in do menu", framesAntes = 3 },
        }) do
            audio:stopMusic()
            for _, e in pairs(audio.sources) do
                if e.group == "music" and e.template then e.template:stop() end
            end

            audio:playMusic("menuMusic", { fadeDuration = 1.5 })
            for _ = 1, caso.framesAntes do audio:update(1 / 60) end

            audio:playMusic("musicAct3", { fadeDuration = 2.5 })
            for _ = 1, 400 do audio:update(1 / 60) end

            local nc, quaisC = tocando()
            t:eq("Continuar (" .. caso.nome .. "): so a faixa do ato toca ("
                 .. quaisC .. ")", nc, 1)
            t:eq("Continuar (" .. caso.nome .. "): e e a do ato",
                 audio.currentMusic, "musicAct3")

            local menuEntry = audio.sources["menuMusic"]
            t:falsy("Continuar (" .. caso.nome .. "): a faixa do MENU esta parada",
                menuEntry and menuEntry.template and menuEntry.template:isPlaying())
        end

        audio:stopMusic()
    else
        t:truthy("audio indisponivel: sobreposicao nao pode ser medida aqui", true)
    end

    local AM = require("engine.AudioManager")
    local audio2 = AM:new()
    if audio2:isAudioAvailable() then
        _G.audioSystem = audio2
        audio2:setGroupVolume("master", 0)
        MD.registerTracks(audio2)
        audio2:loadSound("menuMusic", "audio/music.mp3", {
            volume = 0.6, group = "music", stream = true, loop = true })

        audio2:playMusic("menuMusic")
        MD.markCurrent("musicAct1")

        MD.apply("playing", { actNumber = 1 }, nil)
        t:eq("troca acontece mesmo com o espelho mentindo", audio2.currentMusic, "musicAct1")

        MD.markCurrent("menuMusic")
        MD.apply("playing", { actNumber = 1 }, nil)
        t:eq("nao redispara a faixa que ja toca", audio2.currentMusic, "musicAct1")
        t:eq("e o espelho se corrige sozinho", MD._current, "musicAct1")

        audio2:stopMusic()
    else
        t:truthy("audio indisponivel: espelho nao pode ser medido aqui", true)
    end

    return t:done()
end

return M
