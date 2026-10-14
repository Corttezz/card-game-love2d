---
name: code_notes/src/scenes/EndScreens.lua
description: Comentários com decisão/regra/histórico colhidos de src/scenes/EndScreens.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/scenes/EndScreens.lua`

Origem: `src/scenes/EndScreens.lua` em `7dbdb60d` (18 de 37 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-28 (junto a `local FontManager = require("src.ui.FontManager")`)

> src/scenes/EndScreens.lua
> Telas terminais (gameOver, victory). Extraídas de main.lua.
>
> v2 (Out/2026 — auditoria de UX): antes as duas telas só aceitavam TECLA
> ("R"/"ESPAÇO"/"ESC" escritos num rodapé) — o mouse não fazia nada e o
> gamepad também não. Agora são telas de verdade, no padrão StS (resumo da
> run + botões) e Balatro (placa escura atrás de todo texto):
>
> ZONAS (de cima pra baixo; cada elemento pertence a UMA):
> TÍTULO    título animado + subtítulo (quem te matou / campanha vencida)
> + pontuação e recorde — tudo sobre placa escura (o título
> verde da vitória sumia na arte clara)
> RESUMO    grade classe · alcance · desfecho · turnos · tempo ·
> baralho · ouro · coringas
> REVELAÇÃO maestria + desbloqueios (UnlockReveal) — ocupa o que sobra;
> some se não couber (o conteúdo cede, as zonas não se mexem)
> AÇÕES     Game over: Tentar de novo / Menu principal
> Vitória:   Seguir no Endless / Tentar de novo / Menu principal
>
> Entrada: mouse (clique no release, só se o press nasceu no mesmo botão),
> teclado e gamepad via src/ui/MenuKit.lua (setas/WASD, Enter/Espaço, ESC =
> menu; R = tentar de novo). O gamepad chega aqui já traduzido em tecla pelo
> love.gamepadpressed do main.lua.
>
> Os callbacks (tentar de novo / menu / endless) são injetados pelo main.lua
> via EndScreens.setCallbacks — a tela não conhece a máquina de estados.
> Sem update externo: o relógio tica no draw (love.timer.getDelta), como o
> título DynaText sempre fez.

## L43-44 (em `EndScreens`, junto a `EndScreens.INPUT_DELAY = 0.5`)

> Segundos depois de a tela aparecer em que a entrada é ignorada: o clique
> ou a tecla que matou o chefe (ou o jogador) não pode cair num botão.

## L62-64 (em `EndScreens.setCallbacks`, junto a `local function currentRun(game)`)

> ===================================================================
> DADOS PUROS (testáveis sem desenhar)
> ===================================================================

## L70-71 (em `currentRun`, junto a `function EndScreens.canEndless(game)`)

> A vitória pode virar Endless? Só numa run que JÁ registrou a vitória
> (campaignWon) e ainda não está no endless.

## L127-128 (em `add`, junto a `local ur = game and game.unlockResult`)

> Vencer com o selo k abre o k+1 desta classe: o jogador PRECISA ler
> isso aqui, é o convite pra próxima corrida.

## L154 (em `add`, junto a `function EndScreens.actions(kind, game)`)

> Botões da tela, na ordem visual (o primeiro é o primário / foco inicial).

## L173-175 (em `action`, junto a `local function uiScale(sh)`)

> ===================================================================
> LAYOUT
> ===================================================================

## L184-185 (em `uiScale`, junto a `function EndScreens.layout(kind, game)`)

> Monta as zonas e os retângulos dos botões para (kind, game) no tamanho
> de tela corrente. Puro em relação ao estado de animação.

## L213 (em `L.title`, junto a `local acts = EndScreens.actions(kind, game)`)

> AÇÕES (medidas antes: a revelação fica com o que sobra no meio)

## L251-252 (em `L.buttons`, junto a `local revTop = y + 8`)

> REVELAÇÃO: o vão entre o resumo e as ações (UnlockReveal pinta a placa
> 8px acima da banda recebida — por isso o +8).

## L256-258 (em `L.buttons`, junto a `L.reveal = { x = x, y = revTop, w = colW, h = math.min(340, revBottom - revTop) }`)

> Teto: o conteúdo do UnlockReveal não passa de ~340px (cartas em
> escala 1.6 no máximo); sem teto, em 2560x1440 a placa virava um
> retângulo escuro quase vazio.

## L314 (em `prev`, junto a `local _, shown = TextFit.fit(b.title, L.sizes.btnTitle, b.w - L.pad * 2, 8)`)

> textos cabem no botão (TextFit garante; aqui confere a fonte mínima)

## L323-325 (em `prev`, junto a `local function tickEnter(kind)`)

> ===================================================================
> ESTADO / ENTRADA
> ===================================================================

## L327-328 (em `prev`, junto a `local function tickEnter(kind)`)

> Chamado pelo draw: detecta re-entrada na tela (outro tipo, ou a tela não
> era desenhada havia um tempo) e zera relógio e foco.

## L441-443 (em `trackHover`)

> ===================================================================
> DRAW
> ===================================================================

## L445-447 (em `trackHover`, junto a `local titleDyna = {}`)

> Cache de instâncias DynaText por chave (gameOver/victory). Recriadas se a
> fonte responsiva muda (resize) ou texto muda (locale). Trackeia lastDrawTime
> pra detectar "re-entrada" na cena → dispara :pulse() + reset do pop_in.

## L460-463 (em `entry`, junto a `bump_phase = 0.42,`)

> Mesma correção do título do pacote e do Round Eval: com o
> default (bump_phase=200) as letras vizinhas defasam ~-1,06
> rad e o título ESPALHA em vez de ondular. Fase pequena faz
> o salto viajar pela palavra.

## L492 (em `colours`, junto a `local function plate(r, alpha)`)

> Placa escura com filete dourado: TODO texto da tela final mora numa.

