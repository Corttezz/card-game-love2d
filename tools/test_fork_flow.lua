local TK = require("tools.testkit")

local M = {}

M.CASES = {
    { act = 5, tag = "3_loja" },
    { act = 5, tag = "3_descanso" },
    { act = 1, tag = "3_evento" },
    { act = 3, tag = "2_loja" },
    { act = 6, tag = "3_semluta_lado" },
    { act = 2, tag = "3_batalha" },
}

local function planOf(Flow, tag)
    for _, p in ipairs(Flow.PLANS) do if p.tag == tag then return p end end
end

local function layout(t, WorldRoad)
    local function dirs(types)
        local nodes = {}
        for i, ty in ipairs(types) do nodes[i] = { type = ty } end
        return table.concat(WorldRoad.forkDirs(nodes, #types), ",")
    end
    t:eq("3 opcoes: a batalha vai para o meio", dirs({ "rest", "shop", "battle" }), "-1,1,0")
    t:eq("3 opcoes: elite sem batalha vai para o meio", dirs({ "shop", "elite", "rest" }), "-1,0,1")
    t:eq("3 opcoes: batalha ganha da elite no meio", dirs({ "elite", "rest", "battle" }), "-1,1,0")
    t:eq("3 opcoes sem luta: o do meio fica no meio", dirs({ "rest", "shop", "event" }), "-1,0,1")
    t:eq("2 opcoes: batalha no meio, a outra do lado dela", dirs({ "battle", "shop" }), "0,1")
    t:eq("2 opcoes: batalha no meio (ordem inversa)", dirs({ "shop", "battle" }), "-1,0")
    t:eq("2 opcoes sem luta: esquerda e direita", dirs({ "rest", "event" }), "-1,1")
end

function M.run()
    local t = TK.new("fluxo real da encruzilhada: escolher, entrar no no, sair e chegar na proxima")
    local WorldRoad = require("src.ui.WorldRoad")
    layout(t, WorldRoad)
    local Flow = require("tools.estrada_fluxo")
    local ok, err = pcall(function()
        local okBoot, errBoot = Flow.boot(1920, 1080)
        t:truthy("boot completo do jogo " .. tostring(errBoot or ""), okBoot)
        if not okBoot then return end
        for _, c in ipairs(M.CASES) do
            local plan = planOf(Flow, c.tag)
            local log = Flow.capture(c.act, plan)
            local flags = Flow.analyze(log)
            local label = ("ato %d %s"):format(c.act, c.tag)
            t:truthy(label .. ": fluxo roda " .. tostring(log.err or ""), log.ok and log.n > 200)
            local parked, covered = 0, 0
            for _, fl in ipairs(flags) do
                if fl.what == "parado_na_frente" then parked = parked + 1 end
                if fl.kind == "opcao" then covered = covered + 1 end
            end
            t:eq(label .. ": nenhum marco visitado parado na frente da proxima encruzilhada", parked, 0)
            t:eq(label .. ": todas as opcoes da proxima encruzilhada visiveis", covered, 0)
            local first = flags[1]
            t:eq((label .. ": 0 estalos quadro a quadro (%s)"):format(first and
                string.format("f%d %s %s %s", first.f, first.kind, first.what, first.info or "") or "-"), #flags, 0)
            local walk = Flow.WALK[plan.pick]
            if not walk and log.pickDir and log.pickDir ~= 0 then
                local cmax = 0
                for f = 1, log.n do
                    local cd = log.castle[f]
                    if cd then cmax = math.max(cmax, math.abs(cd)) end
                end
                t:truthy(label .. ": castelo desvia para o lado oposto e volta", cmax > 0.02
                    and math.abs(log.castle[log.n] or 1) < 0.002)
            end
            collectgarbage()
        end
    end)
    Flow.shutdown()
    t:truthy("execucao sem erro: " .. tostring(err), ok)
    WorldRoad.resetRun()
    return t:done()
end

return M
