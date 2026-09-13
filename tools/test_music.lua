-- tools/test_music.lua
-- Testa a DECISÃO do MusicDirector — qual faixa cada contexto pede.
--
-- Roda sem áudio: `pick()` é pura, não toca em `Sfx`. O que se protege aqui
-- não é "a música tocou" (isso ninguém verifica em CI), é a REGRA — e a regra
-- que mais corre risco é a do `cardReward`, que serve dois contextos
-- diferentes com o mesmo state. Se alguém simplificar aquilo para "reward =
-- musicShop", a recompensa pós-batalha passa a trocar de música por quatro
-- segundos e voltar. Ninguém abre um bug com esse título.

local TK = require("tools.testkit")
local MD = require("src.systems.MusicDirector")

local M = {}

function M.run()
    local t = TK.new("music")

    -- Telas fora da run: sempre o tema do menu.
    for _, s in ipairs({ "boot", "menu", "classSelection", "collection",
                         "achievements", "gameOver", "victory" }) do
        t:eq("tela fora da run: " .. s, MD.pick(s, nil, nil), "menuMusic")
    end

    -- Ato manda no combate e no mapa.
    t:eq("ato 1 em combate", MD.pick("playing", { actNumber = 1 }, "battle"), "musicAct1")
    t:eq("ato 2 em combate", MD.pick("playing", { actNumber = 2 }, "battle"), "musicAct2")
    t:eq("ato 3 em combate", MD.pick("playing", { actNumber = 3 }, "battle"), "musicAct3")
    t:eq("mapa segue o ato",  MD.pick("mapSelection", { actNumber = 2 }, nil), "musicAct2")

    -- Endless passa de 3; não pode cair no tema do ato 1.
    t:eq("endless fica no tema do ato 3", MD.pick("playing", { actNumber = 7 }, "battle"), "musicAct3")

    -- Sem run, não estoura: assume ato 1.
    t:eq("sem run assume ato 1", MD.pick("playing", nil, nil), "musicAct1")

    -- Boss tem tema próprio em QUALQUER ato.
    t:eq("boss do ato 1", MD.pick("playing", { actNumber = 1 }, "boss"), "musicBoss")
    t:eq("boss do ato 3", MD.pick("playing", { actNumber = 3 }, "boss"), "musicBoss")
    -- Elite NÃO é boss (já foi confundido com boss uma vez, no destino de cena).
    t:eq("elite nao usa tema de boss", MD.pick("playing", { actNumber = 1 }, "elite"), "musicAct1")

    -- Descanso e loja.
    t:eq("descanso", MD.pick("rest", { actNumber = 2 }, "rest"), "musicRest")
    t:eq("loja",     MD.pick("cardReward", { actNumber = 2 }, "shop"), "musicShop")

    -- A regra que este arquivo existe para proteger.
    t:eq("recompensa pos-batalha NAO troca de musica",
         MD.pick("cardReward", { actNumber = 2 }, "battle"), nil)
    t:eq("recompensa pos-boss NAO troca de musica",
         MD.pick("cardReward", { actNumber = 1 }, "boss"), nil)

    -- Todo código que `pick` pode devolver precisa existir de verdade: ou na
    -- tabela de faixas, ou como o `menuMusic` que o main.lua registra à parte.
    -- Um typo ("musicAct1" vs "musicact1") não trava nada em runtime — o
    -- `resolve` cai no fallback e a tela fica com a música do ato anterior.
    local produced = {}
    for _, case in ipairs({
        { "menu", nil, nil }, { "playing", { actNumber = 1 }, "battle" },
        { "playing", { actNumber = 2 }, "battle" }, { "playing", { actNumber = 3 }, "battle" },
        { "playing", { actNumber = 1 }, "boss" }, { "rest", { actNumber = 1 }, "rest" },
        { "cardReward", { actNumber = 1 }, "shop" },
    }) do
        local code = MD.pick(case[1], case[2], case[3])
        if code then produced[code] = true end
    end
    for code in pairs(produced) do
        t:truthy("codigo '" .. code .. "' e uma faixa registravel",
                 code == "menuMusic" or MD.TRACKS[code] ~= nil)
    end

    -- E o inverso: faixa registrada que nenhum contexto pede é asset morto.
    for code in pairs(MD.TRACKS) do
        t:truthy("faixa '" .. code .. "' e alcancavel por algum contexto", produced[code])
    end

    -- Os arquivos precisam estar no disco. Ausência é legítima por contrato
    -- (o fallback cobre), mas no repo do jogo é regressão — alguém apagou.
    for code, file in pairs(MD.TRACKS) do
        t:truthy("audio/music/" .. file .. " existe",
                 love.filesystem.getInfo("audio/music/" .. file) ~= nil)
    end

    return t:done()
end

return M
