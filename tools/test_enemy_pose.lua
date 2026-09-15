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
    -- v11: varre TODOS os atos da campanha, não os 3 que tinham arte quando
    -- o teste nasceu. O ato novo sem salão (ou com salão sem âncora) passa a
    -- FALHAR aqui em vez de aparecer na cara do dono — foi exatamente assim
    -- que os atos 4-6 ficaram reusando o cenário do ato 1 sem ninguém ver.
    local Config = require("src.core.Config")
    local totalAtos = Config.TotalActs or 3
    t:truthy("campanha tem ao menos 3 atos (sanidade do proprio teste)",
        totalAtos >= 3)
    for act = 1, totalAtos do
        local key = "castle_hall_" .. act
        t:truthy(key .. " tem ARTE no disco",
            love.filesystem.getInfo("assets/sprites/scenes/" .. key .. ".png") ~= nil)
        t:truthy(key .. " tem linha de chao declarada",
            SceneAnchors.BY_SCENE[key] ~= nil)
        local a = SceneAnchors.get(key)
        -- Toda laje destes salões mora na metade de baixo da arte; acima
        -- disso é parede (o caso do hall 2) e abaixo de 0.95 some atrás do
        -- HUD. Fora dessa faixa é bug de dado, não de gosto.
        t:truthy(key .. " ancora na laje (yr=" .. tostring(a.yr) .. ")",
            a.yr > 0.60 and a.yr < 0.95)
    end

    -- Cada ato tem o SEU salão: dois atos apontando pro mesmo PNG é o defeito
    -- que o dono pegou jogando ("o cenário do boss de alguns atos está igual
    -- o do primeiro ato"). Comparação por conteúdo, não por nome de arquivo.
    do
        local vistos, repetido = {}, nil
        for act = 1, totalAtos do
            local p = "assets/sprites/scenes/castle_hall_" .. act .. ".png"
            if love.filesystem.getInfo(p) then
                local dados = love.filesystem.read(p)
                if vistos[dados] then
                    repetido = "atos " .. vistos[dados] .. " e " .. act
                end
                vistos[dados] = act
            end
        end
        t:falsy("nenhum salao de chefe se repete entre atos"
            .. (repetido and (" (" .. repetido .. ")") or ""), repetido ~= nil)
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

    -- ===================================================================
    -- 5. A ARTE do clip, nao so o dado da pose (Set/2026, 2a leva do dono:
    --    "o pezinho dele precisa ficar inclinado para baixo. A capa tambem
    --    precisa ficar mexendo um pouquinho, coisas sutis")
    -- ===================================================================
    local ART = "assets/sprites/characters/enemies"

    -- Margem transparente abaixo do conteudo do 1o frame de um clip. E
    -- exatamente o que `EnemyRenderer.clipMetrics` chama de `pad`, e o que
    -- posiciona o sprite na tela. Varre de baixo pra cima e para na 1a
    -- linha com conteudo — barato o bastante pra rodar em 21 inimigos.
    local function padDoClip(id, clip)
        local p = ART .. "/" .. id .. "/animations/" .. clip .. "/south/0.png"
        if not love.filesystem.getInfo(p) then return nil end
        local ok, data = pcall(love.image.newImageData, p)
        if not ok or not data then return nil end
        local w, h = data:getWidth(), data:getHeight()
        for y = h - 1, 0, -1 do
            for x = 0, w - 1 do
                local _, _, _, a = data:getPixel(x, y)
                if a > 0.1 then return (h - 1) - y end
            end
        end
        return nil
    end

    -- (a) O PE DO CONTEUDO tem que cair no mesmo lugar em idle/hurt/death.
    --
    -- `clipMetrics` mede o pad do 1o frame DE CADA CLIP e o usa pra
    -- posicionar o sprite. Se so um clip for regerado, o monstro PULA na
    -- vertical ao levar dano ou ao morrer. Foi o defeito que quase entrou
    -- nesta leva: corrigir o pe so no idle deixava idle=1 e hurt=4, ou seja
    -- ~7px de pulo na tela a cada golpe recebido.
    --
    -- `attack` fica FORA de proposito: esses clips vem com o canvas cru do
    -- PixelLab (176-256px, margem gorda) e o proprio EnemyRenderer conta
    -- com isso — a escala sai sempre do idle.
    do
        local checados = 0
        for _, id in ipairs(love.filesystem.getDirectoryItems(ART)) do
            local info = love.filesystem.getInfo(ART .. "/" .. id)
            if info and info.type == "directory" then
                local base = padDoClip(id, "idle")
                if base then
                    checados = checados + 1
                    for _, clip in ipairs({ "hurt", "death" }) do
                        local p = padDoClip(id, clip)
                        if p then
                            t:eq(id .. ": pe do '" .. clip
                                .. "' na mesma linha do idle", p, base)
                        end
                    end
                    -- (b) Conteudo encostando na ultima linha do canvas =
                    -- arte CORTADA. Aconteceu duas vezes ao desenhar o bico
                    -- da bota do lich: a ponta ficou sem fechar.
                    t:truthy(id .. ": idle nao encosta na borda de baixo",
                        base >= 1)
                end
            end
        end
        t:truthy("checou os clips de varios inimigos (" .. checados .. ")",
            checados > 15)
    end

    -- (c) Quem flutua tem PANO, e pano se mexe. O idle do lich era
    -- silhueta parada: media do deslocamento da borda entre frames = 1px,
    -- e o que sobrava era chuvisco de regeracao, nao balanco. Foi
    -- exatamente a queixa ("a capa precisa ficar mexendo um pouquinho").
    --
    -- A metrica soma tres deslocamentos da SILHUETA entre os frames do
    -- idle: o extremo direito do corpo e a barra de cada aba da capa.
    -- Medido nesta sessao: arte antiga = 3, arte nova = 7. O teto existe
    -- porque a outra metade do pedido foi "coisas sutis, bem pequenas" —
    -- capa esvoacando seria tao errado quanto capa parada.
    do
        local dir = ART .. "/tower_lich/animations/idle/south"
        local frames = {}
        for _, f in ipairs(love.filesystem.getDirectoryItems(dir)) do
            if f:match("%.png$") then table.insert(frames, dir .. "/" .. f) end
        end
        table.sort(frames)
        t:truthy("idle do lich tem varios frames (" .. #frames .. ")",
            #frames >= 4)

        local function amplitude(fn)
            local lo, hi
            for _, path in ipairs(frames) do
                local ok, data = pcall(love.image.newImageData, path)
                if ok and data then
                    local v = fn(data)
                    if v then
                        lo = (lo and math.min(lo, v)) or v
                        hi = (hi and math.max(hi, v)) or v
                    end
                end
            end
            return (lo and hi) and (hi - lo) or 0
        end
        local function opaco(data, x, y)
            local _, _, _, a = data:getPixel(x, y)
            return a > 0.1
        end
        -- extremo direito do corpo
        local bordaDir = amplitude(function(d)
            local w, h = d:getWidth(), d:getHeight()
            for x = w - 1, 0, -1 do
                for y = 0, h - 1 do if opaco(d, x, y) then return x end end
            end
        end)
        -- barra (ponto mais baixo) de cada aba da capa, em fracoes da
        -- largura pra nao cravar pixel de um canvas especifico
        local function barra(x0r, x1r)
            return amplitude(function(d)
                local w, h = d:getWidth(), d:getHeight()
                local x0 = math.floor(w * x0r)
                local x1 = math.min(w - 1, math.floor(w * x1r))
                for y = h - 1, 0, -1 do
                    for x = x0, x1 do if opaco(d, x, y) then return y end end
                end
            end)
        end
        local total = bordaDir + barra(0.09, 0.24) + barra(0.70, 0.92)
        t:truthy("capa do lich SE MEXE entre os frames (soma=" .. total
            .. ", arte parada dava 3)", total >= 5)
        t:truthy("...e se mexe POUCO, como pedido (soma=" .. total .. ")",
            total <= 14)
    end

    -- get() normaliza e nunca devolve nil (fallback anunciado, nao mudo).
    local unknown = EnemyPoses.get("nao_existe_no_roster")
    t:eq("id desconhecido cai em grounded", unknown.pose, "grounded")
    t:eq("id desconhecido nao flutua", unknown.hover, 0)

    return t:done()
end

return M
