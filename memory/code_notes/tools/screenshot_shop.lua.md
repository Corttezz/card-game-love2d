---
name: code_notes/tools/screenshot_shop.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_shop.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_shop.lua`

Origem: `tools/screenshot_shop.lua` em `7dbdb60d` (22 de 42 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-17 (junto a `local M = {}`)

> tools/screenshot_shop.lua
> Captura screenshots da CardRewardScreen em modo "shop" pra validação visual.
>
> love . screenshot_shop        → CONTACT SHEET, 5 PNGs num run só:
> shop_1_repouso.png        sem hover (painel em pré-foco)
> shop_2_hover_carta.png    mouse sobre uma CARTA do grid
> shop_3_hover_pack.png     mouse sobre um BOOSTER PACK
> shop_4_selecionada.png    oferta selecionada (botões no rodapé do painel)
> shop_5_comprada.png       pós-compra (slot VENDIDO + carta voando)
>
> love . screenshot_shop <n>    → fase única, pra iterar rápido
> love . screenshot_shop perf   → ms por quadro (SHOP_FRAMES, SHOP_W/H)
> love . screenshot_shop fx     → Loja v3: quadros de compra / recusa / sino
> (SHOP_TAG prefixa; prancha via
> python tools/pixellab_shop_props.py sheet)
>
> Saída: save dir do LÖVE (~/AppData/Roaming/LOVE/card-game/ no Windows).

## L35-41 (em `M`, junto a `local PHASE_TIMES = { [0] = 0.20, [1] = 1.20, [2] = 1.20, [3] = 1.20, [4] = 1.20 }`)

> phase 2 = compra a 1ª carta e captura 0.25s depois (valida F2: slot VENDIDO,
> carta voando pro deck, popup -$N, demais cartas paradas no lugar).
> phase 3 = SPLIT-VIEW com HOVER no grid (mouse sobre a 2ª carta): valida o
> painel de detalhe fixo populado + lift/scale da carta + marcadores
> de raridade/afinidade na faixa de rótulos.
> phase 4 = SPLIT-VIEW com oferta SELECIONADA: valida o halo no slot e os
> botões Comprar/Cancelar ancorados no RODAPÉ do painel de detalhe.

## L45-46 (em `M.run`, junto a `local resizeRun = (phase == "resize")`)

> SEM argumento = contact sheet (todos os frames num run só).
> "resize" = tortura de redimensionamento (ver bloco no fim).

## L48-49 (em `M.run`, junto a `local diceRun = (phase == "dice")`)

> "dice" = Dados do Escriba: loja com o botão + mesa aberta + rolando +
> resultado (SHOP_DICE_BET low|seven|high escolhe a aposta).

## L51-54 (em `M.run`, junto a `local fxRun = (phase == "fx")`)

> "fx" = Loja v3: quadros de uma COMPRA (hover → etiqueta arrancada →
> objeto voando → poeira + VENDIDO), de uma recusa SEM OURO (etiqueta
> tremendo) e de um toque no SINO (prateleiras saindo e voltando repostas
> uma a uma). Vira prancha com tools/pixellab_shop_props.py sheet.

## L56-58 (em `M.run`, junto a `local perfRun = (phase == "perf")`)

> "perf" = mede ms por quadro (update + draw) da loja parada e em hover,
> SHOP_FRAMES quadros (300). Mesmo tool na arvore antiga = comparacao
> justa (F5: <= loja antiga + 1 ms em 1440p).

## L63-65 (em `M.run`, junto a `local envW, envH = tonumber(os.getenv("SHOP_W")), tonumber(os.getenv("SHOP_H"))`)

> Tamanho de janela por ambiente (SHOP_W/SHOP_H) — uma chamada só, no
> começo: comparar a loja em 800x600 / 1280x720 / 1920x1080 sem editar o
> tool. SHOP_TAG prefixa os PNGs pra várias rodadas não se sobrescreverem.

## L96-97 (em `M.run`, junto a `do`)

> Seed fixa: as mesmas ofertas em todo tamanho/variante, pra comparar
> layout com layout (sem isto cada captura sorteava outra vitrine).

## L103-105 (em `M.run`, junto a `local topBar = require("components.TopBar"):new()`)

> TopBar real por cima, como no jogo (main.lua desenha a barra DEPOIS do
> overlay da loja): sem ela a captura mentia sobre o espaço disponível e
> escondia o ouro duplicado.

## L109-110 (em `M.run`, junto a `local dice = require("components.ScribeDiceScreen"):new()`)

> Dados do Escriba: o tool não passa pelo love.load, então a ponte que o
> main.lua instala é recriada aqui (sem ela a loja nem mostra o botão).

## L180-182 (em `snap`, junto a `local function snapZoom(name, rect, zoom, quitAfter)`)

> Zoom 2× numa região da tela — pra INSPECIONAR detalhe fino (moldura da
> carta expandida, entrelinha de texto pequeno) sem depender de abrir a
> imagem num editor. Renderiza a cena num canvas e reamostra o recorte.

## L210-211 (em `snapZoom`, junto a `local function hoverSlot(slot)`)

> Move o mouse pro centro de um slot e deixa o hover assentar. O hover é
> REAL (Card:updateMouse faz o hit-test), não um estado forçado na mão.

## L222-224 (em `hoverSlot`, junto a `for _, inst in ipairs(screen.cardInstances or {}) do`)

> Prova numérica da puladinha: retângulo REAL da carta em hover vs
> uma vizinha em repouso (topo mais alto = subiu; rodapé mais alto
> = não invadiu o rótulo de raridade, que fica em Y fixo).

## L252-257 (em `dumpActions`, junto a `if resizeRun then`)

> ===================== TORTURA DE RESIZE =====================
> O caminho que screenshot nenhum exercitava: a loja NASCE num tamanho e
> a janela MUDA com ela aberta (memory/ui_layout_invariants.md — "nascer
> grande != crescer"). Percorre pequeno -> fullscreen-ish -> médio ->
> pequeno de novo, COM uma oferta selecionada (o estado com mais
> geometria derivada), e valida a geometria em cada parada.

## L269-273 (em `steps`, junto a `require("src.ui.FontManager").clearCache()`)

> O jogo real passa por love.resize; reproduzimos o que ELE faz
> pra nao validar num caminho mais facil nem num mais dificil.
> CardFrame junto com FontManager: setMode invalida o CONTEUDO dos
> canvases de carta, e desde Set/2026 o love.resize limpa os dois
> (sem isso o teste acusaria um bug que o jogo real ja nao tem).

## L278-280 (em `steps`, junto a `if i == 1 then`)

> Seleciona uma carta na PRIMEIRA parada e mantém pelo resto:
> os botões de compra dependem do painel de detalhe, que muda de
> largura a cada passo.

## L307-312 (em `steps`, junto a `if i == 2 then`)

> SONDA DE REGRESSÃO (Set/2026): na 2ª parada captura de novo,
> agora depois de limpar o cache de canvas do CardFrame e
> reconstruir as instâncias. Se as DUAS imagens forem iguais, o
> cache sobreviveu à recriação da janela. Se só a segunda tiver
> arte, as cartas estão saindo em branco depois de alternar
> fullscreen — o defeito é de canvas, não de layout.

## L329 (em `steps`, junto a `if love.window.setVSync then love.window.setVSync(0) end`)

> sem vsync: com ele a medida vira 1/Hz do monitor (4,17 ms a 240 Hz)

## L435-436 (em `bets`, junto a `local Tutorial = require("src.systems.Tutorial")`)

> "?" dos dados: a conversa do corvo sob demanda, na fala das apostas
> (as âncoras vêm do quadro anterior, o do resultado).

## L444 (em `bets`, junto a `if phase == nil then`)

> ===== Modo CONTACT SHEET (sem argumento): todos os frames num run =====

## L479-480 (em `bets`, junto a `love.mouse.setPosition(6, 6)`)

> Zooms de inspeção: painel de detalhe (moldura + entrelinha) e a
> fileira 1 em hover (medalhão/rótulo acompanhando a carta).

## L486-487 (em `bets`, junto a `local vis = love.graphics.getHeight() / 2`)

> Pé do painel: valida entrelinha do texto pequeno (descrição,
> efeitos, rodapé de contexto) — o zoom de cima não alcança.

