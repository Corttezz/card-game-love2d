-- tools/test_card_audit.lua
-- TRAVA da auditoria carta a carta (tools/audit_cards.lua, Out/2026).
--
-- Falha se QUALQUER carta do catalogo:
--   * fizer algo diferente do que os DADOS prometem quando jogada num Game de
--     verdade (sozinha, com Forca/Destreza, e forjada +1/+2);
--   * tiver descricao (5 idiomas, base e forjada) com placeholder cru, numero
--     que nao existe nos dados, numero cravado no template, efeito sem palavra,
--     palavra sem efeito, vocabulario fora do padrao ou formato divergente;
--   * tiver efeito sem linha traduzida no painel de detalhe.
--
-- Verificada VERMELHA com defeitos reais reintroduzidos (Out/2026):
--   * Forca somada 1x em multi_hit -> 4 falhas (Golpe Duplo, Raios Gemeos,
--     Presas Gemeas, Medalhao Estelar: "dano medido 17, dados prometem 20");
--   * descricao antiga dos espinhos de joker ("Quando o inimigo atacar, ele
--     sofre 4") -> falha "nao menciona 'thorn'" nos 5 idiomas.
--
--   love . test_one test_card_audit

local TK = require("tools.testkit")
local Audit = require("tools.audit_cards")

local M = {}

function M.run()
    local t = TK.new("auditoria carta a carta (comportamento x dados x descricao)")
    local ok, res = xpcall(Audit.collect, debug.traceback)
    if not t:check("auditoria roda sem crash" .. (ok and "" or (": " .. tostring(res))), ok) then
        return t:done()
    end

    -- contagem: um loop que nao mediu nada passaria em todas as asserções
    t:check(("mediu >= 100 cartas nao-joker (mediu %d)"):format(res.counted.cards),
        res.counted.cards >= 100)
    t:check(("mediu >= 25 jokers (mediu %d)"):format(res.counted.jokers),
        res.counted.jokers >= 25)
    t:check(("mediu cartas forjadas (%d medicoes)"):format(res.counted.forged),
        res.counted.forged >= 100)
    t:check(("mediu ataque/defesa com Forca/Destreza (%d)"):format(res.counted.withStats or 0),
        (res.counted.withStats or 0) >= 50)

    for _, s in ipairs(res.behavior) do t:check("FAZ o que os dados dizem: " .. s, false) end
    t:eq("divergencias comportamento x dados", #res.behavior, 0)
    for _, s in ipairs(res.desc) do t:check("DIZ o que faz: " .. s, false) end
    t:eq("divergencias descricao x dados", #res.desc, 0)
    return t:done()
end

return M
