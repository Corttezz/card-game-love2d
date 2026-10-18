local TK = require("tools.testkit")
local MD = require("src.systems.MusicDirector")
local Config = require("src.core.Config")

local M = {}

function M.run()
    local t = TK.new("music")

    t:eq("abertura sem trilha", MD.pick("boot", nil, nil), nil)
    for _, s in ipairs({ "menu", "classSelection", "collection",
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

    local S = MD.SILENCE
    local function chefe(id, act) return { actNumber = act, currentNode = { type = "boss", enemyId = id } } end
    local rainha = chefe("eclipse_queen", Config.TotalActs)
    local rei = chefe("carrion_king", 1)

    t:eq("elite nao usa tema de boss", MD.pick("playing", { actNumber = 1 }, "elite"), "musicAct1")
    t:eq("mini-chefe segue com a faixa do ato",
         MD.pick("playing", { actNumber = 1, currentNode = { type = "mini_boss", enemyId = "wicker_effigy" } }, "mini_boss"),
         "musicAct1")

    t:eq("encruzilhada comum segue o ato",
         MD.pick("mapSelection", { actNumber = 1, pendingNodes = { { type = "battle" }, { type = "shop" } } }, nil),
         "musicAct1")
    t:eq("encruzilhada com a bandeira do chefe = silencio",
         MD.pick("mapSelection", { actNumber = 1, pendingNodes = { { type = "boss" } } }, nil), S)
    t:eq("chefe entre outras opcoes tambem silencia",
         MD.pick("mapSelection", { actNumber = 3, pendingNodes = { { type = "rest" }, { type = "boss" } } }, nil), S)
    t:eq("cash out do mini-chefe ainda nao silencia", MD.pick("roundEval", { actNumber = 1 }, "mini_boss"), nil)
    t:eq("espolios do mini-chefe ainda nao silenciam", MD.pick("cardReward", { actNumber = 1 }, "mini_boss"), nil)

    t:eq("viagem ate o castelo = silencio", MD.pick("playing", rei, "boss", false, false), S)
    t:eq("porta abrindo (salao nao entrado) = silencio", MD.pick("playing", rainha, "boss", false, false), S)
    t:eq("salao vazio / entrada do chefe = silencio", MD.pick("playing", rei, "boss", true, true), S)
    t:eq("entrada da rainha = silencio", MD.pick("playing", rainha, "boss", true, true), S)

    local esperado = {
        carrion_king = "musicBossCarrionKing", tower_lich = "musicBossTowerLich",
        abyss_tyrant = "musicBossAbyssTyrant", winter_monarch = "musicBossWinterMonarch",
        rot_colossus = "musicBossRotColossus", eclipse_queen = "musicBossEclipse",
    }
    local Enemies = require("src.data.enemies")
    for act = 1, Config.TotalActs do
        local id = Enemies.ROSTER[act].boss[1]
        t:truthy("chefe do ato " .. act .. " (" .. id .. ") tem faixa na tabela", MD.BOSS_TRACKS[id] ~= nil)
        t:eq("fim da entrada de " .. id .. " = faixa dele",
             MD.pick("playing", chefe(id, act), "boss", true, false), esperado[id])
        t:eq("Continuar na luta de " .. id .. " (salao, sem entrada) = faixa dele",
             MD.pick("playing", chefe(id, act), "boss", true), esperado[id])
        t:eq("save antigo sem enemyId no ato " .. act .. " = faixa do chefe do ato",
             MD.pick("playing", { actNumber = act, currentNode = { type = "boss" } }, "boss", true), esperado[id])
    end
    local vistos = {}
    for _, code in pairs(MD.BOSS_TRACKS) do
        t:falsy("faixa de chefe nao repete: " .. code, vistos[code])
        vistos[code] = true
    end

    t:eq("endless sem enemyId cai na faixa generica",
         MD.pick("playing", { actNumber = Config.TotalActs, endlessMode = true, currentNode = { type = "boss" } }, "boss", true),
         MD.GENERIC_BOSS)
    t:eq("endless com enemyId toca a faixa do chefe",
         MD.pick("playing", { actNumber = Config.TotalActs + 2, endlessMode = true, currentNode = { type = "boss", enemyId = "tower_lich" } }, "boss", true),
         "musicBossTowerLich")
    t:eq("chefe desconhecido cai na faixa generica",
         MD.pick("playing", chefe("chefe_inexistente", 2), "boss", true, false), MD.GENERIC_BOSS)

    t:eq("fase death da cinematica: mantem o que toca (nunca comeca a faixa na morte)",
         MD.pick("playing", rei, "boss", true, "death"), nil)
    t:eq("fase intro como texto = silencio", MD.pick("playing", rei, "boss", true, "intro"), S)
    t:eq("actTrack e a fonte unica da faixa do ato", MD.actTrack({ actNumber = 4 }), "musicAct4")
    t:eq("morte do chefe (fase death, salao) mantem a faixa dele",
         MD.pick("playing", rei, "boss", true, false), "musicBossCarrionKing")
    t:eq("cash out no salao da rainha mantem a faixa", MD.pick("roundEval", rainha, "boss", true), nil)
    t:eq("espolios no salao da rainha mantem a faixa", MD.pick("cardReward", rainha, "boss", true), nil)
    t:eq("encruzilhada do ato seguinte volta ao tema do ato",
         MD.pick("mapSelection", { actNumber = 2, pendingNodes = { { type = "battle" } } }, nil), "musicAct2")
    t:eq("sem probe de salao (sem cena) toca o chefe", MD.pick("playing", rainha, "boss"), "musicBossEclipse")

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
        { "playing", { actNumber = 1, endlessMode = true }, "boss" }, { "rest", { actNumber = 1 }, "rest" },
        { "cardReward", { actNumber = 1 }, "shop" },
    }
    for id in pairs(MD.BOSS_TRACKS) do
        casos[#casos + 1] = { "playing", { actNumber = 1, currentNode = { type = "boss", enemyId = id } }, "boss", true }
    end
    for a = 1, Config.TotalActs do
        casos[#casos + 1] = { "playing", { actNumber = a }, "battle" }
    end
    for _, case in ipairs(casos) do
        local code = MD.pick(case[1], case[2], case[3], case[4])
        if code and code ~= MD.SILENCE then produced[code] = true end
    end
    for code in pairs(produced) do
        t:truthy("codigo '" .. code .. "' e uma faixa registravel",
                 code == "menuMusic" or MD.TRACKS[code] ~= nil or MD.isBossCode(code))
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

        local function tocandoMusica()
            local n = 0
            for _, e in pairs(audio2.sources) do
                if e.group == "music" and e.template and e.template:isPlaying() then n = n + 1 end
            end
            return n
        end
        local prevHall, prevIntro = MD.hallProbe, MD.introProbe
        local hall, intro = false, false
        MD.hallProbe = function() return hall end
        MD.introProbe = function() return intro end

        local forkRun = { actNumber = 1, pendingNodes = { { type = "boss" } } }
        MD.apply("mapSelection", forkRun, nil)
        t:eq("bandeira do chefe: nenhuma faixa atual", audio2.currentMusic, nil)
        t:eq("bandeira do chefe: estado de silencio explicito", MD._current, MD.SILENCE)
        t:truthy("o ato some DEVAGAR (ainda tocando logo depois)", tocandoMusica() == 1)
        for _ = 1, 60 do audio2:update(1 / 60); MD.apply("mapSelection", forkRun, nil) end
        t:truthy("depois de 1 s ainda soa (fade de " .. MD.FADE_SILENCE .. " s)", tocandoMusica() == 1)
        for _ = 1, math.ceil(MD.FADE_SILENCE * 60) do audio2:update(1 / 60) end
        t:eq("no fim do fade, silencio de verdade", tocandoMusica(), 0)

        local bossRun = { actNumber = 1, currentNode = { type = "boss", enemyId = "carrion_king" } }
        MD.apply("playing", bossRun, "boss")
        t:eq("viagem/porta: segue o silencio", audio2.currentMusic, nil)
        hall, intro = true, true
        MD.apply("playing", bossRun, "boss")
        t:eq("entrada do chefe: segue o silencio", audio2.currentMusic, nil)
        hall, intro = true, false
        MD.apply("playing", bossRun, "boss")
        local esperado = audio2.sources["musicBossCarrionKing"] and "musicBossCarrionKing" or MD.GENERIC_BOSS
        t:eq("fim da entrada: entra a faixa do chefe", audio2.currentMusic, esperado)

        MD.apply("mapSelection", forkRun, nil)
        for _ = 1, 30 do audio2:update(1 / 60) end
        MD.apply("playing", { actNumber = 1 }, "battle")
        for _ = 1, 400 do audio2:update(1 / 60) end
        t:eq("faixa nova por cima de um fade-out: so ela toca", tocandoMusica(), 1)
        t:eq("e e a certa (" .. tostring(audio2.currentMusic) .. ")", audio2.currentMusic, "musicAct1")

        audio2:fadeOutMusic(2)
        for _ = 1, 30 do audio2:update(1 / 60) end
        audio2:playMusic("musicAct1", { fadeDuration = 1 })
        for _ = 1, 200 do audio2:update(1 / 60) end
        t:eq("voltar a mesma faixa no meio do fade a retoma", audio2.currentMusic, "musicAct1")
        t:eq("sem duplicar", tocandoMusica(), 1)

        audio2:fadeOutMusic(2)
        audio2:stopMusic()
        t:eq("stopMusic corta um fade-out em andamento", tocandoMusica(), 0)

        audio2:playMusic("menuMusic")
        MD.markCurrent("menuMusic")
        MD.apply("roundEval", { actNumber = 3 }, "battle")
        t:eq("Continuar no cash out com o menu tocando: entra a faixa do ato",
             audio2.currentMusic, "musicAct3")
        MD.apply("cardReward", { actNumber = 3 }, "battle")
        t:eq("espolios mantem a faixa do ato", audio2.currentMusic, "musicAct3")
        audio2:stopMusic()
        MD.markCurrent("musicAct3")
        MD.apply("cardReward", { actNumber = 3 }, "battle")
        t:eq("faixa parada por fora com o espelho mentindo: o diretor religa",
             audio2.currentMusic, "musicAct3")
        audio2:fadeOutMusic(1)
        MD.markCurrent(MD.SILENCE)
        MD.apply("roundEval", { actNumber = 3 }, "boss")
        t:eq("cash out depois de um silencio de chefe segue em silencio", audio2.currentMusic, nil)
        audio2:stopMusic()

        MD.hallProbe, MD.introProbe = prevHall, prevIntro
        audio2:stopMusic()
    else
        t:truthy("audio indisponivel: espelho nao pode ser medido aqui", true)
    end

    M.sectionsOff(t)
    M.loopPoints(t)

    return t:done()
end

function M.sectionsOff(t)
    local MS = require("src.systems.MusicSections")
    t:falsy("trilha em secoes desligada (rejeitada pelo dono em 76de8877)", MS.ENABLED)
    t:eq("nenhum chefe registrado em secoes", next(MS.BOSSES), nil)
    t:eq("scan nao registra secao nenhuma", MS.scan(MD.BOSS_TRACKS), 0)
    for id, code in pairs(MD.BOSS_TRACKS) do
        t:falsy("chefe " .. id .. " sem trilha em secoes", MS.has(code))
    end
    t:eq("as secoes rejeitadas sairam do repositorio", love.filesystem.getInfo(MS.DIR), nil)
    t:eq("chefe sem faixa propria cai na generica", MD.pick("playing",
        { actNumber = 1, currentNode = { type = "boss", enemyId = "chefe_inexistente" } }, "boss", true),
        MD.GENERIC_BOSS)
end

M.LOOP_BOSSES = {
    tower_lich = "musicBossTowerLich",
    winter_monarch = "musicBossWinterMonarch",
    abyss_tyrant = "musicBossAbyssTyrant",
}

function M.loopPoints(t)
    local FA = require("tools.fake_audio")
    local LOOPS = require("src.data.music_loops")
    for id, code in pairs(M.LOOP_BOSSES) do
        t:eq("faixa de " .. id .. " no codigo do MusicDirector", MD.BOSS_TRACKS[id], code)
        t:truthy("audio/music/" .. MD.bossFile(id) .. " instalada",
            love.filesystem.getInfo("audio/music/" .. MD.bossFile(id)) ~= nil)
        local lp = LOOPS[code]
        t:truthy(code .. " tem ponto de loop", lp ~= nil)
        if lp then
            t:truthy(code .. ": loopStart > 1 s (nunca volta ao comeco)", lp.loopStart > 1)
            t:truthy(code .. ": loop de pelo menos 40 s", lp.loopEnd - lp.loopStart >= 40)
        end
    end
    t:falsy("colosso sem faixa propria instalada",
        love.filesystem.getInfo("audio/music/" .. MD.bossFile("rot_colossus")) ~= nil)
    t:falsy("rainha sem boss-eclipse_queen.mp3 (fica com a dela)",
        love.filesystem.getInfo("audio/music/" .. MD.bossFile("eclipse_queen")) ~= nil)
    t:eq("rainha usa music-boss-eclipse", MD.TRACKS[MD.BOSS_TRACKS.eclipse_queen], "music-boss-eclipse.mp3")
    t:eq("rei-carnica sem ponto de loop (arquivo aprovado intocado)", LOOPS.musicBossCarrionKing, nil)
    for code in pairs(LOOPS) do
        t:truthy("ponto de loop de " .. code .. " e de uma faixa que o diretor conhece",
            MD.TRACKS[code] ~= nil or MD.isBossCode(code))
    end

    local prevAudio = _G.audioSystem
    FA.install()
    local ok, err = pcall(function()
        local AM = require("engine.AudioManager")
        local audio = AM:new()
        _G.audioSystem = audio
        MD.registerTracks(audio)
        audio:loadSound("menuMusic", "audio/music.mp3", {
            volume = 0.6, group = "music", stream = true, loop = true })

        local function audiveis()
            local n, quais = 0, {}
            for code, e in pairs(audio.sources) do
                if e.group == "music" then
                    for _, s in ipairs(e.instances) do
                        if s.playing and s.vol > 0.002 then n = n + 1; quais[#quais + 1] = code end
                    end
                end
            end
            table.sort(quais)
            return n, table.concat(quais, "+")
        end
        local function pump(secs, each)
            local el = 0
            while el < secs do
                audio:update(1 / 60)
                FA.advance(1 / 60)
                el = el + 1 / 60
                if each then each() end
            end
        end

        for _, code in pairs(M.LOOP_BOSSES) do
            local e = audio.sources[code]
            t:truthy(code .. " carregada", e ~= nil)
            if e then
                local ls, le = audio:getLoopPoints(code)
                local src = e.template
                t:near(code .. ": loopStart vem dos dados", ls, LOOPS[code].loopStart, 1e-9)
                t:near(code .. ": loopEnd vem dos dados", le, LOOPS[code].loopEnd, 1e-9)
                t:truthy(code .. ": arquivo vai alem do loopEnd (sobra para o atraso do quadro)",
                    src:getDuration() >= le + 1.0)

                audio:playMusic("musicAct1")
                pump(0.5)
                audio:playMusic(code, { fadeDuration = 1.2 })
                local okPar = true
                pump(2.0, function()
                    if audiveis() > 2 then okPar = false end
                end)
                t:truthy(code .. ": no maximo duas faixas durante o crossfade de entrada", okPar)
                t:eq(code .. ": assentou sozinha", select(2, audiveis()), code)
                t:falsy(code .. ": fonte com ponto de loop toca SEM loop nativo", src.looping)
                t:truthy(code .. ": comeca do inicio natural (posicao baixa)", src.pos < 3.0)

                local plays0, stops0, inst0 = src.plays, src.stops, #e.instances
                src.pos = le - 0.25
                local voltou, minPos, sempreSo = false, math.huge, true
                local lastPos = src.pos
                pump(1.0, function()
                    if src.pos < lastPos then
                        voltou = true
                        minPos = math.min(minPos, src.pos)
                    end
                    lastPos = src.pos
                    local n, quais = audiveis()
                    if n ~= 1 or quais ~= code then sempreSo = false end
                end)
                t:truthy(code .. ": ao passar do loopEnd volta", voltou)
                t:truthy(code .. ": volta para o loopStart, nunca para o 0 ("
                    .. string.format("%.3f", minPos) .. ")",
                    minPos >= ls - 1e-6 and minPos <= ls + 0.1)
                t:truthy(code .. ": segue tocando", src.playing)
                t:eq(code .. ": mesma fonte, sem play novo", src.plays, plays0)
                t:eq(code .. ": sem stop", src.stops, stops0)
                t:eq(code .. ": nenhuma instancia nova", #e.instances, inst0)
                t:truthy(code .. ": uma faixa so audivel na volta do loop", sempreSo)

                src.pos = le + 0.4
                audio:update(1 / 60)
                t:near(code .. ": atraso de quadro preserva a fase (loopStart + atraso)",
                    src.pos, ls + 0.4, 1e-6)

                audio:setFocused(false)
                pump(0.5)
                src.pos = le - 0.05
                pump(0.3)
                t:truthy(code .. ": fora da janela (mudo) o loop tambem volta", src.pos < le and src.pos >= ls)
                t:truthy(code .. ": fora da janela segue tocando", src.playing)
                audio:setFocused(true)
                pump(0.5)

                src.pos = le - 0.3
                audio:playMusic("musicAct2", { fadeDuration = 1.0 })
                local okCf = true
                pump(1.5, function()
                    if audiveis() > 2 then okCf = false end
                end)
                t:truthy(code .. ": crossfade de saida cruzando o loopEnd sem terceira faixa", okCf)
                t:eq(code .. ": saiu de vez", select(2, audiveis()), "musicAct2")
                t:falsy(code .. ": fonte do chefe parada", src.playing)

                audio:playMusic(code, { fadeDuration = 1.2 })
                pump(1.5)
                t:truthy(code .. ": voltar ao chefe recomeca do inicio natural", src.pos < 3.0)
                audio:fadeOutMusic(1.0)
                pump(1.5)
                t:eq(code .. ": silencio do chefe apaga a faixa", (audiveis()), 0)
                audio:stopMusic()
            end
        end

        local semLoop = audio.sources["musicAct1"]
        t:falsy("faixa sem dados de loop segue sem ponto de loop", audio:getLoopPoints("musicAct1"))
        audio:playMusic("musicAct1")
        pump(0.2)
        t:truthy("faixa sem dados de loop segue com loop nativo", semLoop.template.looping)
        audio:stopMusic()

        local rot = MD.BOSS_TRACKS.rot_colossus
        t:falsy("colosso: codigo dele nao carregado", audio.sources[rot] ~= nil)
        local prevHall, prevIntro = MD.hallProbe, MD.introProbe
        MD.hallProbe = function() return true end
        MD.introProbe = function() return false end
        MD._current, MD._lastWanted = nil, nil
        MD.apply("playing", { actNumber = 5, currentNode = { type = "boss", enemyId = "rot_colossus" } }, "boss")
        t:eq("colosso cai na faixa generica de chefe", audio.currentMusic, MD.GENERIC_BOSS)
        audio:stopMusic()
        MD.apply("playing", { actNumber = 6, currentNode = { type = "boss", enemyId = "eclipse_queen" } }, "boss")
        t:eq("rainha mantem a faixa dela", audio.currentMusic, "musicBossEclipse")
        audio:stopMusic()
        MD.apply("playing", { actNumber = 1, currentNode = { type = "boss", enemyId = "carrion_king" } }, "boss")
        t:eq("rei-carnica mantem a faixa dele", audio.currentMusic, "musicBossCarrionKing")
        audio:stopMusic()
        MD.hallProbe, MD.introProbe = prevHall, prevIntro
        MD._current, MD._lastWanted = nil, nil
    end)
    FA.uninstall()
    _G.audioSystem = prevAudio
    t:truthy("pontos de loop sem erro" .. (ok and "" or (": " .. tostring(err))), ok)
end

return M
