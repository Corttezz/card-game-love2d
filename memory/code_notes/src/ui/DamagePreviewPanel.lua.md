---
name: code_notes/src/ui/DamagePreviewPanel.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/DamagePreviewPanel.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/DamagePreviewPanel.lua`

Origem: `src/ui/DamagePreviewPanel.lua` em `7dbdb60d` (19 de 57 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-26 (junto a `local DamagePreview = require("src.systems.DamagePreview")`)

> src/ui/DamagePreviewPanel.lua
> PREVIA DE DANO na batalha (Out/2026, pedido do dono: "nao fica claro quanto
> de dano vai dar — o jogador joga as cartas e ve um dano enorme sem entender
> o que aconteceu").
>
> Tres lugares, cada um ANCORADO no objeto de que fala (lei do projeto: nada
> de tarja de rodape):
> 1. PLACA acima do botao JOGAR (banda de ACAO da coluna direita). Dois
> estados, lembrados em Configuracoes (`previewDetails`):
> RESUMO (padrao, Out/2026 — dono: "grande e confuso"): so o que o
> clique produz — dano, Bloqueio, LETAL — e uma linha de combos/
> coringas em fichas pequenas; em hover numa carta, o total COM ela.
> DETALHES (clique na placa / tecla V / foco + A no pad): a conta
> carta a carta — base -> Forca -> combo (dourado) -> coringa
> (violeta) -> edicao/selo -> Fraco, com tooltip nas linhas.
> Durante a resolucao a placa congela a previa e mostra o total
> CORRENDO ate fechar. Bandas da placa em `Panel.layout` (puro, com
> `validate` — a trava tools/test_preview_plate.lua roda em 5 tamanhos).
> 2. BARRA DE VIDA do inimigo: o trecho que a leva vai arrancar pisca por
> cima da barra (e o numero "-34" ao lado). Letal = a barra inteira.
> 3. CARTAS DA MAO: a carta que fecharia um combo NOVO com a selecao atual
> ganha um selo "+COMBO" em cima; em hover, o painel mostra o total COM
> ela ("+ Pancada: 51").
>
> A conta vem de src/systems/DamagePreview.lua — a MESMA funcao que o combate
> usa (previa == resultado; trava em tools/test_damage_preview.lua).

## L47-49 (em `badges`, junto a `function Panel.detailsOn()`)

> ===========================================================================
> RESUMO x DETALHES (lembrado em _G.gameSettings.previewDetails)
> ===========================================================================

## L60-61 (em `Panel.setDetails`, junto a `local ok, err = pcall(function()`)

> mesmo caminho do Tutorial.disable: le o arquivo, muda UMA chave, grava
> (sem passar pelo snapshot do SettingsMenu, que so roda quando ele fecha)

## L80-82 (em `Panel.toggleDetails`, junto a `Panel.hitRect = nil`)

> Clique na placa (main.lua, estado playing, ANTES da cena): alterna. `x, y`
> em pixels reais — a placa guarda o proprio retangulo real no draw (mesmo
> truque do NavCursor.target: transformPoint dentro do UiScale).

## L100-101 (em `t`, junto a `local function plain(text, x, y, c, a)`)

> texto pequeno SEM contorno: o painel ja e escuro, e o contorno de 1px
> empasta a fonte pixel em corpo pequeno (o "8" virava "&").

## L133-135 (em `isBusy`, junto a `function Panel.update(game, hoverCard, dt)`)

> ===========================================================================
> UPDATE
> ===========================================================================

## L178-179 (em `state.hover`, junto a `state.badges = {}`)

> selo na mao: o bonus de combo que a carta GANHARIA se entrasse agora
> ("Saraivada +4"). So com selecao: e a selecao que define a fila.

## L197-199 (em `Panel.current`, junto a `local COL_ATK   = Palette.BLOOD`)

> ===========================================================================
> Linhas do painel (medidas e desenhadas pela mesma lista)
> ===========================================================================

## L334-338 (em `seenJ`, junto a `function Panel.comboDescription(combo, game)`)

> O que o combo FAZ, montado dos numeros da propria regra (texto e dado nunca
> divergem). Multiplicador ganha a lei do "maior vence" junto.
> O que o combo FAZ, montado dos numeros da propria regra (texto e dado nunca
> divergem): {v} = bonus por carta anterior, {max} = o teto. `game` (opcional)
> aplica os coringas de combo (ComboSystem.boostFor).

## L365-367 (em `rowTooltip`, junto a `local function chipsWidth(font, chips, iconS, gap)`)

> ===========================================================================
> DRAW — painel acima do botao Jogar
> ===========================================================================

## L386-394 (em `drawIcon`, junto a `function Panel.layout(m)`)

> ===========================================================================
> LAYOUT (puro): as bandas da placa, empilhadas de cima pra baixo
> ===========================================================================
> m = { anchor = {x, y, w}, topLimit, gap, pad, minW, maxW, headH, hintH,
> rows = { {kind, h}, ... } }
> Devolve { x, y, w, h, bands = { head, rows[i], hint } } com cada banda em
> { y, h }. Largura: a do botao (minW), ate maxW. A placa termina `gap` px
> acima do botao; quem cede quando falta altura sao as LINHAS (o chamador
> corta antes — ver `fitRows`), nunca o cabecalho nem a dica.

## L424-426 (em `rowsAvail`, junto a `function Panel.validate(L, m)`)

> Invariantes da placa (a trava roda isto em varios tamanhos de janela):
> dentro da tela, acima do botao, abaixo do limite, bandas sem sobreposicao
> e todas dentro da placa. Devolve (ok, motivo).

## L444-445 (em `seq`, junto a `local function fitRows(lines, avail, lineH, lh)`)

> Corta linhas ate caberem em `avail`: as de CARTA cedem primeiro (vira
> "+N cartas"), o resto cede do fim. Usa `lineH(l)`.

## L467-468 (em `fitRows`, junto a `local function summaryChips(R)`)

> Fichas da linha de RESUMO: um icone + o bonus por combo (dourado) e por
> coringa (violeta). Cada ficha guarda combo/joker pro tooltip.

## L500-501 (em `chipTooltip`, junto a `function Panel.draw(game, anchor, topLimit)`)

> `anchor` = { x, y, w } (topo e largura do botao Jogar). `topLimit` = y
> minimo que a placa pode ocupar (abaixo da top bar / quadro de coringas).

## L644-645 (em `m`, junto a `love.graphics.setFont(small)`)

> RESUMO: icone + "Nome +18" por combo/coringa; sem espaco cai
> pra "+18"; sem espaco de novo, so os icones (tooltip explica)

## L771-773 (em `Panel.hitRect`, junto a `function Panel.drawEnemyGhost(game, rect)`)

> ===========================================================================
> Barra de vida do inimigo: o trecho que a leva arranca
> ===========================================================================

## L800-802 (em `Panel.drawEnemyGhost`, junto a `function Panel.drawHandBadges(game)`)

> ===========================================================================
> Selos "+COMBO" nas cartas da mao
> ===========================================================================

## L822 (em `parts`, junto a `local room = cw - 4`)

> mao espremida: o selo nao pode invadir o vizinho — cai pro total

