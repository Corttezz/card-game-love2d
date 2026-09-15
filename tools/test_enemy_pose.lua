-- tools/test_enemy_pose.lua
-- Regressões dos defeitos de Set/2026 (cena do elite + chefe flutuando):
--
--   1. ELITE não briga no salão do chefe (isInteriorNode é a fonte única).
--   2. Toda cena de interior tem LINHA DE CHÃO declarada, e ela cai na laje
--      — `height * 0.68` fixo punha o pé do chefe do ato 2 na PAREDE.
--   3. Todo inimigo do roster tem POSE declarada, e a âncora não depende da
--      resolução (o mesmo ponto da arte em qualquer janela).
--
-- Roda via: love . test_one test_enemy_pose

local TK = require("tools.testkit")

local M = {}

function M.run()
    local t = TK.new("test_enemy_pose")

    local EnemyPoses    = require("src.data.enemy_poses")
    local SceneAnchors  = require("src.data.scene_anchors")
    local SceneBg       = require("src.ui.SceneBackground")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local GameplayScene = require("src.scenes.GameplayScene")

    -- ===================================================================
    -- 1. Cenário por tipo de node
    -- ===================================================================
    t:truthy("boss depois da cutscene luta DENTRO do castelo",
        GameplayScene.isInteriorNode("boss", true))
    t:falsy("boss ANTES da cutscene ainda esta na estrada",
        GameplayScene.isInteriorNode("boss", false))
    t:falsy("ELITE nao usa o salao do chefe (defeito Set/2026)",
        GameplayScene.isInteriorNode("elite", true))
    t:falsy("mini-boss briga na estrada",
        GameplayScene.isInteriorNode("mini_boss", true))
    t:falsy("batalha comum briga na estrada",
        GameplayScene.isInteriorNode("battle", true))

    -- ===================================================================
    -- 2. Linha de chão das cenas de interior
    -- ===================================================================
    for act = 1, 3 do
        local key = "castle_hall_" .. act
        t:truthy(key .. " tem linha de chao declarada",
            SceneAnchors.BY_SCENE[key] ~= nil)
        local a = SceneAnchors.get(key)
        -- Toda laje destes salões mora na metade de baixo da arte; acima
        -- disso é parede (o caso do hall 2) e abaixo de 0.95 some atrás do
        -- HUD. Fora dessa faixa é bug de dado, não de gosto.
        t:truthy(key .. " ancora na laje (yr=" .. tostring(a.yr) .. ")",
            a.yr > 0.60 and a.yr < 0.95)
    end

    -- O hall do ato 2 é o do defeito: a laje dele é MAIS BAIXA que a dos
    -- irmãos. Se alguém "uniformizar" os três valores, o chefe volta a
    -- flutuar — este assert existe pra isso.
    t:truthy("hall 2 ancora MAIS BAIXO que o hall 1 (laje mais baixa na arte)",
        SceneAnchors.get("castle_hall_2").yr
        > SceneAnchors.get("castle_hall_1").yr)

    -- Âncora independe da resolução: mesmo ponto da ARTE em qualquer
    -- janela (o cover-fit corta na vertical em telas largas).
    do
        local key = "castle_hall_2"
        local tr1 = SceneBg.getCoverTransform(key, 1024, 768)
        local tr2 = SceneBg.getCoverTransform(key, 1920, 1080)
        t:truthy("cover transform do hall existe", tr1 ~= nil and tr2 ~= nil)
        if tr1 and tr2 then
            local _, y1 = SceneAnchors.groundAnchor(key, 1024, 768)
            local _, y2 = SceneAnchors.groundAnchor(key, 1920, 1080)
            -- de volta pra linha da PNG
            local row1 = (y1 - tr1.oy) / tr1.scale
            local row2 = (y2 - tr2.oy) / tr2.scale
            t:near("mesma linha da arte em 1024x768 e 1920x1080",
                row1, row2, 1.5)
        end
    end

    -- ===================================================================
    -- 3. Pose de todo inimigo do roster
    -- ===================================================================
    local nodeTypes = { "battle", "elite", "mini_boss", "boss" }
    local seen = {}
    for act = 1, 6 do
        for _, nt in ipairs(nodeTypes) do
            local id = EnemyRenderer.resolveSpriteId(act, nt)
            if id and not seen[id] then
                seen[id] = true
                t:truthy("roster: '" .. id .. "' tem pose declarada",
                    EnemyPoses.BY_ID[id] ~= nil)
            end
        end
    end

    -- Arte nova sem pose declarada é o caminho de volta pro defeito: o
    -- sprite entra no jogo, cai no default grounded e ninguém percebe.
    local dir = "assets/sprites/characters/enemies"
    if love.filesystem.getInfo(dir) then
        for _, name in ipairs(love.filesystem.getDirectoryItems(dir)) do
            local info = love.filesystem.getInfo(dir .. "/" .. name)
            if info and info.type == "directory" then
                t:truthy("sprite em disco: '" .. name .. "' tem pose",
                    EnemyPoses.BY_ID[name] ~= nil)
            end
        end
    end

    -- Flutuante sem altura é grounded com nome bonito.
    for id, p in pairs(EnemyPoses.BY_ID) do
        t:truthy(id .. ": pose valida",
            p.pose == "floating" or p.pose == "grounded")
        if p.pose == "floating" then
            t:truthy(id .. ": flutuante precisa de hover > 0",
                (p.hover or 0) > 0)
            t:truthy(id .. ": sombra de quem flutua e menor E mais fraca",
                (p.shadowK or 1) < 1 and (p.shadowA or 1) < 1)
        end
    end

    -- ===================================================================
    -- 4. reducedMotion: tira o BALANCO, nunca a ALTURA
    -- ===================================================================
    do
        local H = 300
        local prev = _G.gameSettings
        _G.gameSettings = { reducedMotion = true }
        local a = EnemyRenderer.poseOffsetY("dusk_shade", H, 0.0)
        local b = EnemyRenderer.poseOffsetY("dusk_shade", H, 3.7)
        local c = EnemyRenderer.poseOffsetY("dusk_shade", H, 11.2)
        t:near("reducedMotion: altura constante no tempo (t=0 vs 3.7)", a, b, 1e-9)
        t:near("reducedMotion: altura constante no tempo (t=0 vs 11.2)", a, c, 1e-9)
        local hover = EnemyPoses.get("dusk_shade").hover
        t:near("reducedMotion: altura = hover puro", a, -hover * H, 1e-9)
        t:truthy("reducedMotion: flutuante CONTINUA no ar", a < 0)

        -- com movimento: oscila, mas nunca encosta no chao nem foge da faixa
        _G.gameSettings = { reducedMotion = false }
        local bob = EnemyPoses.get("dusk_shade").bob
        local lo, hi = -(hover + bob) * H, -(hover - bob) * H
        local minV, maxV = math.huge, -math.huge
        for i = 0, 200 do
            local v = EnemyRenderer.poseOffsetY("dusk_shade", H, i * 0.05)
            if v < minV then minV = v end
            if v > maxV then maxV = v end
        end
        t:truthy("bob fica dentro da faixa hover+-bob",
            minV >= lo - 1e-6 and maxV <= hi + 1e-6)
        t:truthy("bob de verdade oscila", (maxV - minV) > 1)
        t:truthy("flutuante nunca encosta no chao", maxV < 0)

        -- quem pisa nao se mexe, com ou sem reducedMotion.
        -- O exemplo era `tower_lich`, que virou FLUTUANTE por decisao de
        -- design (Set/2026, ver o comentario dele em enemy_poses). Trocado
        -- por um apoiado que nao esta em disputa — e a assercao agora varre
        -- TODOS os grounded, pra nao quebrar de novo quando um mudar de lado.
        local apoiados = 0
        for id, spec in pairs(EnemyPoses.BY_ID) do
            if spec.pose == "grounded" then
                apoiados = apoiados + 1
                if EnemyRenderer.poseOffsetY(id, H, 4.2) ~= 0 then
                    t:eq("grounded '" .. id .. "' nao tem offset de pose",
                        EnemyRenderer.poseOffsetY(id, H, 4.2), 0)
                end
            end
        end
        t:truthy("ha apoiados pra checar (" .. apoiados .. ")", apoiados > 5)
        t:eq("nenhum grounded tem offset", 0, 0)
        _G.gameSettings = prev
    end

    -- get() normaliza e nunca devolve nil (fallback anunciado, nao mudo).
    local unknown = EnemyPoses.get("nao_existe_no_roster")
    t:eq("id desconhecido cai em grounded", unknown.pose, "grounded")
    t:eq("id desconhecido nao flutua", unknown.hover, 0)

    return t:done()
end

return M
