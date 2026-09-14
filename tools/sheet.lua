-- tools/sheet.lua
-- Monta um CONTACT SHEET de PNGs numa tira horizontal (ou grade), pra olhar
-- frames de animação e variações de arte lado a lado.
--
-- Existe porque validar arte aqui SEMPRE foi feito com um script Python + PIL,
-- e em Set/2026 o Python da máquina quebrou no meio da sessão (o interpretador
-- principal perdeu o .exe e o do launcher não tem pip). A validação visual é
-- parte do processo — "olhar o PNG antes de aprovar" é regra do projeto — e
-- não pode depender de um runtime externo quando o jogo já tem tudo o que
-- precisa pra desenhar.
--
-- Uso:
--   love . sheet <dir> [escala] [saida.png]
--     love . sheet assets/sprites/world/anim/abyss_castle_door 3
--     love . sheet assets/sprites/icons_anim/warrior_taunt 4 taunt.png
--
--   love . sheet <a.png,b.png,c.png> [escala] [saida.png]
--     compara arquivos soltos, na ordem dada
--
-- Saída no diretório de save (o mesmo dos outros tools). Fundo escuro de
-- propósito: quase todo asset do jogo é desenhado sobre fundo escuro, e
-- validar sobre branco já enganou uma leva inteira de ícones (ver
-- memory/ui_rendering.md).

local M = {}

local BG = { 0.10, 0.08, 0.07, 1 }

local function listaDe(alvo)
    local arquivos = {}
    if alvo:find(",", 1, true) or alvo:match("%.png$") then
        for p in alvo:gmatch("[^,]+") do
            arquivos[#arquivos + 1] = p
        end
        return arquivos
    end
    -- diretório: ordena numericamente quando os nomes são números
    local itens = love.filesystem.getDirectoryItems(alvo)
    local nums = {}
    for _, it in ipairs(itens) do
        if it:match("%.png$") then
            arquivos[#arquivos + 1] = alvo .. "/" .. it
            nums[alvo .. "/" .. it] = tonumber(it:match("(%d+)")) or math.huge
        end
    end
    table.sort(arquivos, function(a, b)
        if nums[a] ~= nums[b] then return nums[a] < nums[b] end
        return a < b
    end)
    return arquivos
end

function M.run(alvo, escalaArg, saidaArg)
    if not alvo then
        print("uso: love . sheet <dir|a.png,b.png> [escala] [saida.png]")
        love.event.quit(1)
        return false
    end
    local escala = tonumber(escalaArg) or 3
    local saida = saidaArg or "sheet.png"

    local arquivos = listaDe(alvo)
    if #arquivos == 0 then
        print("[sheet] nenhum PNG em " .. alvo)
        love.event.quit(1)
        return false
    end

    local imgs, maxW, maxH = {}, 0, 0
    for _, p in ipairs(arquivos) do
        local ok, img = pcall(love.graphics.newImage, p)
        if ok then
            img:setFilter("nearest", "nearest")
            imgs[#imgs + 1] = { img = img, path = p }
            maxW = math.max(maxW, img:getWidth())
            maxH = math.max(maxH, img:getHeight())
        else
            print("[sheet] falhou: " .. p)
        end
    end
    if #imgs == 0 then love.event.quit(1); return false end

    local cw, ch = maxW * escala, maxH * escala
    local cv = love.graphics.newCanvas(cw * #imgs, ch)
    love.graphics.setCanvas(cv)
    love.graphics.clear(BG)
    for i, e in ipairs(imgs) do
        -- centraliza e apoia no BASE da célula: frames de tamanhos
        -- diferentes ficam alinhados pelo pé, como na tela.
        local x = (i - 1) * cw + (cw - e.img:getWidth() * escala) / 2
        local y = ch - e.img:getHeight() * escala
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(e.img, x, y, 0, escala, escala)
    end
    love.graphics.setCanvas()
    cv:newImageData():encode("png", saida)

    print(string.format("[sheet] %d imagem(ns) -> %s (%dx%d, escala %d)",
        #imgs, saida, cw * #imgs, ch, escala))
    for i, e in ipairs(imgs) do print(string.format("  %2d  %s", i, e.path)) end
    love.event.quit(0)
    return true
end

return M
