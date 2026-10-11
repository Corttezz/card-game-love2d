-- src/ui/RunJournalLayout.lua
-- PLANO DE ZONAS do Roteiro da jornada (components/RunJournalScreen.lua).
--
-- POR QUE ESTE MÓDULO EXISTE
-- A primeira versão da tela posicionava tudo dentro do draw: o castelo crescia
-- com a folga da janela (chegava a 280px, maior que a trilha inteira), o
-- tooltip subia e invadia a faixa do ato de cima, e nada disso era testável sem
-- olhar a captura. Aqui o layout é uma função PURA da janela + quantos nós
-- cada ato tem; o draw só lê o resultado, e `validate()` confere as zonas por
-- construção (mesmo molde do src/ui/PackChoiceLayout.lua).
--
--   ┌──────────────────────────────────────────────┐
--   │ CABEÇALHO  título · progresso · resumo   [X] │ altura fixa
--   ├──────────────────────────────────────────────┤
--   │ CAPÍTULOS (rolável)                          │ flex
--   │  ┌ ATO 1 · CATACUMBAS ........ CONQUISTADO ┐ │  título do capítulo
--   │  │ [1] [2] [3] [4] [5] [6] [7] [8]  castelo│ │  8 colunas = 8 andares
--   │  │ res res res res res res res res         │ │  resultado SOB cada parada
--   │  └─────────────────────────────────────────┘ │
--   ├──────────────────────────────────────────────┤
--   │ RODAPÉ     HintBar                           │ altura fixa
--   └──────────────────────────────────────────────┘
--
-- Uma COLUNA POR ANDAR: o andar 6 de todo ato fica na mesma vertical, então a
-- run inteira lê como uma grade — dá pra comparar atos de relance. Em endless
-- (o ato trava e o andar cicla) a faixa ganha linhas de 8.
--
-- Quando aperta, quem cede é a ESCALA da célula (disco/fonte), nunca a posição
-- das bandas. O castelo tem teto: é o marco do fim da linha, não a protagonista.

local RunJournalLayout = {}

RunJournalLayout.COLS        = 8      -- MapManager.FLOORS_PER_ACT
RunJournalLayout.HEADER_H    = 92
RunJournalLayout.FOOTER_H    = 44
RunJournalLayout.MAX_W       = 1400   -- além disso as colunas viram vãos
RunJournalLayout.TITLE_H     = 24     -- título do capítulo
RunJournalLayout.BAND_PAD_B  = 10
RunJournalLayout.BAND_GAP    = 14
RunJournalLayout.ROW_GAP     = 8
RunJournalLayout.DISC_MIN    = 24
RunJournalLayout.DISC_MAX    = 56
RunJournalLayout.SMALL_DISC  = 0.74   -- parada comum = 74% do disco de chefe/elite
RunJournalLayout.TIP_GAP     = 6
RunJournalLayout.TOP_PAD     = 10

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- Tamanho da fonte das linhas de resultado, pela largura da coluna. Press
-- Start 2P tem glifo quadrado: 8px de fonte = 8px por letra.
local function lineSizeFor(cellW)
    if cellW >= 150 then return 10 end
    if cellW >= 104 then return 9 end
    return 8
end

-- bands: lista de { count = nº de paradas }.
-- scroll: deslocamento vertical pedido (é clampado e devolvido em L.scroll).
function RunJournalLayout.compute(sw, sh, bands, scroll)
    local R = RunJournalLayout
    local margin   = clamp(math.floor(sw * 0.035), 14, 48)
    local contentW = math.min(sw - margin * 2, R.MAX_W)
    local contentX = math.floor((sw - contentW) / 2)

    -- Castelo: ~1 coluna de largura, com teto. Sai da largura do conteúdo (não
    -- da célula) pra conta não ficar circular.
    local castleW = clamp(math.floor(contentW * 0.10), 48, 132)
    local castleGap = clamp(math.floor(contentW * 0.015), 8, 20)
    local gridW = contentW - castleW - castleGap
    local cellW = math.floor(gridW / R.COLS)

    local disc  = clamp(math.floor(cellW * 0.46), R.DISC_MIN, R.DISC_MAX)
    local lineSize = lineSizeFor(cellW)
    local lineH = lineSize + 5
    local cellH = disc + 6 + lineH * 2

    local zone = {
        x = 0, y = R.HEADER_H, w = sw,
        h = math.max(40, sh - R.HEADER_H - R.FOOTER_H),
    }

    local L = {
        sw = sw, sh = sh,
        header = { x = 0, y = 0, w = sw, h = R.HEADER_H },
        footer = { x = 0, y = sh - R.FOOTER_H, w = sw, h = R.FOOTER_H },
        zone = zone,
        contentX = contentX, contentW = contentW,
        gridX = contentX, gridW = cellW * R.COLS,
        cellW = cellW, cellH = cellH,
        disc = disc, smallDisc = math.floor(disc * R.SMALL_DISC),
        lineSize = lineSize, lineH = lineH,
        castleW = castleW,
        bands = {},
    }

    -- 1ª passada: alturas.
    local contentH = 0
    for i, b in ipairs(bands) do
        local rows = math.max(1, math.ceil((b.count or 0) / R.COLS))
        local h = R.TITLE_H + rows * cellH + (rows - 1) * R.ROW_GAP + R.BAND_PAD_B
        L.bands[i] = { rows = rows, h = h, count = b.count or 0 }
        contentH = contentH + h + R.BAND_GAP
    end
    contentH = math.max(0, contentH - R.BAND_GAP)
    L.contentH = contentH
    L.maxScroll = math.max(0, contentH - zone.h)
    L.scroll = clamp(scroll or 0, 0, L.maxScroll)

    -- 2ª passada: posições (scroll embutido — hit-test fica trivial). O bloco
    -- ANCORA NO TOPO, como página de diário: roteiro curto centrado deixava um
    -- vão morto entre o cabeçalho e o ato 1.
    local slack = (L.maxScroll > 0) and 0 or math.min(R.TOP_PAD, zone.h - contentH)
    local y = zone.y + slack - L.scroll
    for _, lb in ipairs(L.bands) do
        lb.x, lb.y, lb.w = contentX, y, contentW
        lb.gridY = y + R.TITLE_H
        lb.cells = {}
        for n = 1, lb.count do
            local r = math.floor((n - 1) / R.COLS)
            local c = (n - 1) % R.COLS
            local cx0 = contentX + c * cellW
            local cy0 = lb.gridY + r * (cellH + R.ROW_GAP)
            lb.cells[n] = {
                x = cx0, y = cy0, w = cellW, h = cellH, row = r, col = c,
                -- centro do disco (o disco de chefe e o comum compartilham o
                -- centro, então a linha da trilha passa reta pelos dois)
                cx = cx0 + math.floor(cellW / 2),
                cy = cy0 + math.floor(disc / 2),
                textY = cy0 + disc + 6,
            }
        end
        -- O castelo FECHA a última linha (é o fim do caminho do ato).
        local lastRow = lb.rows - 1
        lb.castle = {
            x = contentX + contentW - castleW,
            y = lb.gridY + lastRow * (cellH + R.ROW_GAP),
            w = castleW, h = cellH,
        }
        y = y + lb.h + R.BAND_GAP
    end
    return L
end

-- Largura disponível pro detalhe ao lado da célula (o maior dos dois lados).
-- O chamador limita a largura do detalhe a isto; em janela estreita as
-- linhas encolhem/cortam (TextFit) em vez de o detalhe tapar a parada.
function RunJournalLayout.tipRoom(L, cell)
    local R = RunJournalLayout
    local right = L.sw - 6 - (cell.x + cell.w + R.TIP_GAP)
    local left = cell.x - R.TIP_GAP - 6
    return math.max(right, left)
end

-- Retângulo do detalhe (tooltip) de uma parada: AO LADO da célula, nunca em
-- cima nem embaixo — assim fica dentro da faixa do próprio ato e não tapa o
-- ato vizinho. Prefere a direita; vai pra esquerda quando não cabe. Largura
-- já limitada a `tipRoom` e altura já cortada a `maxTipH` pelo chamador.
function RunJournalLayout.tipRect(L, lb, cell, w, h)
    local R = RunJournalLayout
    local right = cell.x + cell.w + R.TIP_GAP
    local x
    if right + w <= L.sw - 6 then
        x = right
    elseif cell.x - R.TIP_GAP - w >= 6 then
        x = cell.x - R.TIP_GAP - w
    elseif (L.sw - 6 - right) >= (cell.x - R.TIP_GAP - 6) then
        x = right
    else
        x = math.max(6, cell.x - R.TIP_GAP - w)
    end
    -- Vertical: alinha ao topo da célula e cabe na interseção faixa ∩ zona
    -- visível (a faixa pode estar meio rolada pra fora).
    local top = math.max(lb.y, L.zone.y)
    local bot = math.min(lb.y + lb.h, L.zone.y + L.zone.h)
    local y = clamp(cell.y, top, math.max(top, bot - h))
    return { x = x, y = y, w = w, h = h }
end

-- Altura máxima que o detalhe pode ter pra caber na faixa visível.
function RunJournalLayout.maxTipH(L, lb)
    local top = math.max(lb.y, L.zone.y)
    local bot = math.min(lb.y + lb.h, L.zone.y + L.zone.h)
    return math.max(0, bot - top)
end

-- Confere as invariantes de zona. Devolve lista de problemas (vazia = ok).
-- `tip` opcional: { rect = , band = índice } do detalhe aberto.
function RunJournalLayout.validate(L, tip)
    local R = RunJournalLayout
    local problems = {}
    local function bad(msg) problems[#problems + 1] = msg end

    if L.zone.y < L.header.y + L.header.h then bad("trilhas sobem no cabecalho") end
    if L.zone.y + L.zone.h > L.footer.y then bad("trilhas descem no rodape") end
    if L.contentX < 0 or L.contentX + L.contentW > L.sw then
        bad("conteudo estoura a largura da janela")
    end
    if L.cellW * R.COLS + L.castleW > L.contentW then
        bad("grade + castelo nao cabem no conteudo")
    end
    if L.disc > L.cellW then bad("disco maior que a coluna") end

    for bi, lb in ipairs(L.bands) do
        local gridR = L.gridX + L.gridW
        if lb.castle.x < gridR then bad("castelo invade a grade na faixa " .. bi) end
        for ni, c in ipairs(lb.cells) do
            if c.x < 0 or c.x + c.w > L.sw then
                bad(("parada %d/%d fora da janela"):format(bi, ni))
            end
            if c.x + c.w > lb.castle.x then
                bad(("parada %d/%d encosta no castelo"):format(bi, ni))
            end
            if c.y < lb.gridY or c.y + c.h > lb.y + lb.h then
                bad(("parada %d/%d fora da propria faixa"):format(bi, ni))
            end
        end
        local nb = L.bands[bi + 1]
        if nb and lb.y + lb.h > nb.y then bad("faixa " .. bi .. " encosta na seguinte") end
        if L.maxScroll == 0 then
            if lb.y < L.zone.y - 1 or lb.y + lb.h > L.zone.y + L.zone.h + 1 then
                bad("faixa " .. bi .. " fora da zona sem scroll")
            end
        end
    end
    if L.scroll < 0 or L.scroll > L.maxScroll + 0.001 then bad("scroll fora do conteudo") end

    if tip then
        local r, lb = tip.rect, L.bands[tip.band]
        if r.x < 0 or r.y < 0 or r.x + r.w > L.sw or r.y + r.h > L.sh then
            bad("detalhe sai da janela")
        end
        if r.y < L.zone.y - 0.5 or r.y + r.h > L.zone.y + L.zone.h + 0.5 then
            bad("detalhe sai da zona das trilhas")
        end
        if lb and (r.y < lb.y - 0.5 or r.y + r.h > lb.y + lb.h + 0.5) then
            bad("detalhe invade outra faixa")
        end
        if tip.cell then
            local c = tip.cell
            local overlap = r.x < c.x + c.w and c.x < r.x + r.w
                and r.y < c.y + c.h and c.y < r.y + r.h
            if overlap then bad("detalhe tapa a propria parada") end
        end
    end
    return problems
end

return RunJournalLayout
