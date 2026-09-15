-- tools/bake_orb_anim.lua
-- Gera os frames do loop idle das GEMAS do mago (assets/sprites/orbs_anim/).
--
--   love . bake_orb_anim [halfW] [frames] [fps]
--   -> saída no diretório de save, em bake/orbs_anim/<tipo>/frame_NNN.png
--      (copiar pra assets/ SÓ depois de olhar o contact sheet)
--
-- POR QUE ISTO EXISTE, e não um job de PixelLab (Set/2026)
-- ============================================================================
-- O pedido do dono foi "animações bem sutis ali na arte delas, bem sutíssimas".
-- O caminho normal do projeto (animate_object v3, memory/card_icon_animation.md)
-- foi tentado PRIMEIRO, nas cinco gemas, com a redação que a memória registra
-- como vencedora (ciclo curto de 4 + movimento positivo mínimo). As cinco foram
-- REPROVADAS no contact sheet, cada uma pelo mesmo motivo de fundo — o v3
-- redesenha o sprite inteiro a cada frame e num canvas de 48px com interior
-- facetado ele tem liberdade demais:
--   lightning — a pedra inteira bombeava de âmbar pra amarelo claro;
--   ice       — o interior virava uma mancha branca e o contorno mexia;
--   fire      — o frame do meio desbotava pra pêssego (cor fora da paleta);
--   dark      — as facetas ferviam, com um buraco preto no meio do ciclo;
--   holy      — os RAIOS encolhiam (silhueta mudando, o veto mais claro).
-- Nenhuma delas é "sutilíssima", e três violam a regra de que a informação não
-- pode piorar (cor do elemento = identidade que o jogador lê).
--
-- A resposta não foi insistir no adjetivo proibitivo (a memória já registra que
-- isso não resolve), foi TROCAR O MÉTODO: aqui o frame não é redesenhado, é
-- DERIVADO do PNG que já está no jogo. Cada pixel só pode andar UM degrau pra
-- cima na rampa de cor DO PRÓPRIO SPRITE — a paleta do frame animado é um
-- subconjunto da paleta do frame parado. Isso torna impossível, por
-- construção:
--   * inventar cor nova (não existe cor fora da paleta original);
--   * mudar a silhueta (nenhum pixel transparente vira opaco, e vice-versa);
--   * mexer no contorno (pixel escuro, abaixo de MIN_LUM, nunca é tocado).
--
-- O que se move é UMA coisa só: uma faixa diagonal de luz atravessando a pedra
-- devagar, como a luz pegando a faceta. Frame 0 é byte a byte o PNG estático
-- (a faixa nasce FORA da gema), e o último frame também — a emenda do loop é
-- zero por construção, não por medida.

local M = {}

local ELEMS = { "lightning", "ice", "fire", "dark", "holy" }
local SRC   = "assets/sprites/orbs/%s.png"
local OUT   = "bake/orbs_anim/%s"

-- Pixel abaixo disto é contorno/sombra: NUNCA é promovido. É o que mantém a
-- borda escura da gema idêntica em todos os frames (a silhueta lida de longe
-- é a borda, não o miolo).
local MIN_LUM = 0.30
-- Degrau máximo de luminância que ainda conta como "a mesma cor, mais clara".
-- Acima disso o vizinho na rampa é outra família de tom e a promoção viraria
-- troca de cor.
-- 0.16 foi MEDIDO, não escolhido: com 0.34 (o primeiro corte) a rampa grossa da
-- gema de raio dava saltos de meio tom e a faixa lia como "metade da pedra
-- acendeu". Limitar o degrau faz a dosagem se adaptar sozinha a cada pedra —
-- gema de rampa fina (gelo, sombra) cintila, gema de rampa grossa quase não
-- muda, que é exatamente o certo: onde o degrau é grande, mexer é gritar.
local MAX_STEP = 0.16

local function lumOf(r, g, b) return 0.299 * r + 0.587 * g + 0.114 * b end

local function toHsv(r, g, b)
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    local d = mx - mn
    local h = 0
    if d > 0 then
        if mx == r then h = ((g - b) / d) % 6
        elseif mx == g then h = (b - r) / d + 2
        else h = (r - g) / d + 4 end
        h = h / 6
    end
    return h, (mx > 0 and d / mx or 0), mx
end

local function hueDist(a, b)
    local d = math.abs(a - b) % 1
    return math.min(d, 1 - d)
end

-- Rampa do sprite: cada cor opaca ganha um "gêmeo mais claro" escolhido entre
-- as cores que o PRÓPRIO sprite já usa. Critério: mesma família de tom (matiz e
-- saturação próximos), um degrau de luminância acima. Sem candidato, a cor é o
-- próprio gêmeo (pixel que não tem pra onde subir simplesmente não muda).
local function buildRamp(data)
    local w, h = data:getWidth(), data:getHeight()
    local seen, list = {}, {}
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local r, g, b, a = data:getPixel(x, y)
            if a > 0.5 then
                local key = string.format("%d,%d,%d",
                    math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
                    math.floor(b * 255 + 0.5))
                if not seen[key] then
                    local hh, ss, _ = toHsv(r, g, b)
                    local c = { r = r, g = g, b = b, l = lumOf(r, g, b), h = hh, s = ss }
                    seen[key] = c
                    list[#list + 1] = c
                end
            end
        end
    end

    for _, c in ipairs(list) do
        local best, bestScore = nil, math.huge
        for _, d in ipairs(list) do
            local dl = d.l - c.l
            if dl > 0.02 and dl <= MAX_STEP then
                -- Matiz pesa mais que tudo: é ele que separa "laranja mais
                -- claro" de "cinza da cravação" na mesma faixa de brilho.
                local score = hueDist(c.h, d.h) * 4.0
                    + math.abs(c.s - d.s) * 1.5
                    + dl
                if score < bestScore then best, bestScore = d, score end
            end
        end
        -- Matiz longe demais = famílias diferentes; melhor não mexer.
        c.twin = (best and hueDist(c.h, best.h) < 0.09) and best or c
    end
    return seen
end

-- A faixa de luz: uma reta diagonal (canto inferior-esquerdo -> superior-
-- direito) que atravessa a pedra ao longo do ciclo. `center` anda de fora a
-- fora, então os frames das pontas são idênticos ao original.
local function bandHit(x, y, center, halfW)
    local p = (x - y) * 0.70710678
    return math.abs(p - center) <= halfW
end

-- Os três números do ciclo, e por que são estes:
--   frames 24 @ fps 12 = 2,0s de volta completa. A faixa anda ~3,3px por
--   frame; com 16 frames ela pulava 5px e o brilho lia como degrau, não como
--   luz correndo (a pedra tem 48px — 5px é um décimo dela de uma vez).
--   halfW 5 = faixa de 10px: cada pixel fica aceso ~3 frames (0,25s), tempo de
--   o olho registrar um reflexo sem virar pisca-pisca.
function M.run(halfWArg, framesArg, fpsArg)
    local halfW = tonumber(halfWArg) or 5
    local frames = tonumber(framesArg) or 24
    local fps = tonumber(fpsArg) or 12

    love.filesystem.createDirectory("bake/orbs_anim")
    local relatorio = {}

    for _, el in ipairs(ELEMS) do
        local path = string.format(SRC, el)
        local ok, data = pcall(love.image.newImageData, path)
        if not ok or not data then
            print("[bake_orb_anim] nao abriu " .. path)
            love.event.quit(1)
            return false
        end
        local w, h = data:getWidth(), data:getHeight()
        local ramp = buildRamp(data)
        local dir = string.format(OUT, el)
        love.filesystem.createDirectory(dir)

        -- span = metade da diagonal projetada; +halfW+1 de margem garante faixa
        -- COMPLETAMENTE fora da pedra nos dois extremos do ciclo.
        local span = (w - 1) * 0.70710678
        local from, to = -span - halfW - 1, span + halfW + 1

        local totalOpacos, somaMudados, maxMudados = 0, 0, 0
        for f = 0, frames - 1 do
            local center = from + (to - from) * (f / (frames - 1))
            local out = love.image.newImageData(w, h)
            local mudados = 0
            for y = 0, h - 1 do
                for x = 0, w - 1 do
                    local r, g, b, a = data:getPixel(x, y)
                    if a > 0.5 then
                        if f == 0 then totalOpacos = totalOpacos + 1 end
                        local l = lumOf(r, g, b)
                        if l >= MIN_LUM and bandHit(x, y, center, halfW) then
                            local key = string.format("%d,%d,%d",
                                math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
                                math.floor(b * 255 + 0.5))
                            local c = ramp[key]
                            if c and c.twin ~= c then
                                r, g, b = c.twin.r, c.twin.g, c.twin.b
                                mudados = mudados + 1
                            end
                        end
                    end
                    out:setPixel(x, y, r, g, b, a)
                end
            end
            somaMudados = somaMudados + mudados
            maxMudados = math.max(maxMudados, mudados)
            out:encode("png", string.format("%s/frame_%03d.png", dir, f))
        end

        love.filesystem.write(dir .. "/meta.lua",
            string.format("return { fps = %d }\n", fps))
        relatorio[#relatorio + 1] = string.format(
            "%-9s %d frames | %d px opacos | pico %d px (%.1f%%) | media %.1f px",
            el, frames, totalOpacos, maxMudados,
            100 * maxMudados / math.max(1, totalOpacos), somaMudados / frames)
    end

    print(string.format("[bake_orb_anim] halfW=%d frames=%d fps=%d (%.2fs)", halfW, frames, fps, frames / fps))
    for _, l in ipairs(relatorio) do print("  " .. l) end
    print("[bake_orb_anim] saida: <save>/bake/orbs_anim/<tipo>/")
    love.event.quit(0)
    return true
end

return M
