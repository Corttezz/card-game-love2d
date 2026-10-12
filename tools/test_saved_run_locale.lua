-- tools/test_saved_run_locale.lua
-- Texto de UI guardado no SAVE não pode prender a tela no idioma antigo:
-- uma run salva em pt_BR e reaberta depois de trocar pra alemão mostra os
-- marcos da encruzilhada e a escolha de evento do Roteiro em ALEMÃO.
-- (Os nós e as entradas do roteiro gravam `label`/`optionLabel` do idioma
-- daquela hora; a tela resolve pelo tipo/id via I18n e só usa o gravado
-- como fallback.)
--
--   love . test_one test_saved_run_locale

local TK = require("tools.testkit")

local M = {}

function M.run()
    TK.bootstrap()
    local t = TK.new("run salva x troca de idioma")
    local I18n = require("src.i18n.I18n")
    local saved = I18n.getLocale()
    local ok, err = pcall(function()
        I18n.setLocale("pt_BR")
        local game = TK.newRunGame("warrior")
        local rm = game.runManager
        local nodes = rm:generateNextNodes(3)
        t:truthy("nós gerados", nodes and #nodes > 0)
        -- simula o save → load: a tabela da run é o que o disco guarda
        local node = { type = nodes[1].type, label = nodes[1].label, desc = nodes[1].desc }
        local ptLabel = node.label

        -- roteiro: entrada de evento com a opção gravada em PT
        local Events = require("src.data.events")
        local ev
        for _, id in ipairs({ "altar", "forge_spirit", "strange_bet" }) do
            ev = ev or Events.get(id)
        end
        ev = ev or Events.roll(1)
        rm:journalBegin({ type = "event" }, {})
        rm:journalEvent(ev.id, 1, ev.options[1].label)
        local entry = rm.currentRun.journal[#rm.currentRun.journal]

        I18n.setLocale("de")
        local WorldRoad = require("src.ui.WorldRoad")
        local MapManager = require("src.systems.MapManager")
        local label, desc = WorldRoad.forkLabel(node)
        local deWant = I18n.t("node_type." .. node.type .. ".label", nil, "")
        t:truthy("o tipo tem rótulo em de", deWant ~= "")
        t:eq("marco da encruzilhada no idioma novo (" .. tostring(ptLabel) .. " → " .. tostring(label) .. ")",
            label, deWant)
        -- prova de que NÃO é o texto gravado: um nó com rótulo gravado falso
        t:eq("o texto gravado no nó é ignorado quando o tipo tem chave",
            (WorldRoad.forkLabel({ type = node.type, label = "GRAVADO-PT" })), deWant)
        t:eq("descrição do marco no idioma novo", desc, MapManager.descFor(node.type))
        t:eq("nó de tipo desconhecido cai no texto gravado",
            (WorldRoad.forkLabel({ type = "tipo_inexistente", label = "X" })), "X")

        local RunJournalScreen = require("components.RunJournalScreen")
        local want = I18n.t("events." .. ev.id .. ".opt1", nil, "")
        t:truthy("evento tem a opção traduzida em de", want ~= "")
        t:eq("roteiro: escolha do evento no idioma novo", RunJournalScreen.optionText(entry), want)
        t:eq("roteiro: entrada antiga sem índice usa o texto gravado",
            RunJournalScreen.optionText({ optionLabel = "Velho" }), "Velho")
    end)
    if not ok then print("  ERRO: " .. tostring(err)) end
    t:truthy("nenhuma excecao", ok)
    I18n.setLocale(saved)
    return t:done()
end

return M
