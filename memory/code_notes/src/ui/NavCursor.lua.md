---
name: code_notes/src/ui/NavCursor.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/NavCursor.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/NavCursor.lua`

Origem: `src/ui/NavCursor.lua` em `7dbdb60d` (16 de 41 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-27 (junto a `local NavCursor = {}`)

> src/ui/NavCursor.lua
> NAVEGAÇÃO POR TECLADO E GAMEPAD EM TODAS AS TELAS (Out/2026 — meta Steam
> Deck Verified).
>
> Em vez de ensinar 20 telas a navegar, o cursor de foco se apoia no que
> elas JÁ fazem: o hover deste jogo é por POLLING (`love.mouse.getPosition`,
> 40+ call sites) e o clique é `mousepressed/mousereleased`. Então:
>
> 1. ALVOS: quem desenha algo clicável registra o retângulo no quadro
> (`NavCursor.target`). Button:draw e Card:draw já registram — o resto
> (tiles da loja, nós do mapa, quadros...) chama `target` no draw. O
> retângulo é convertido pra PIXELS DA TELA na hora (transformPoint),
> então escala de UI, slide-in e scissor não importam pra navegação.
> A camada de foco (InputFocus) de quem registrou vai junto: só valem
> os alvos da camada que tem o foco (modal por cima apaga os de trás).
> 2. FOCO: no modo teclado/pad, o mouse "mora" no centro do alvo focado
> (InputFocus.setPositionOverride): hover, tooltip, lift de carta — tudo
> que já reage ao mouse reage ao foco, de graça. Foco = hover.
> 3. AÇÕES: A/Enter sintetiza o clique no foco (o MESMO caminho do mouse);
> gatilho = clique direito (inspecionar); B/Esc = a tecla Esc; X/Y e
> ombros = ações de contexto que a tela publica (`NavCursor.action`).
> 4. MOUSE E PAD CONVIVEM: mexer o mouse desliga o modo (some o anel);
> apertar tecla/botão religa, focando o que estava sob o mouse.
>
> Telas com navegação PRÓPRIA (pausa, configurações, confirmação, dados do
> escriba, fim de jogo, conquistas — MenuKit) declaram `ownsNavigation` e
> recebem as teclas como antes; o pad vira tecla pra elas.

## L44-46 (em `NavCursor.device`, junto a `function NavCursor.target(obj, x, y, w, h, opts)`)

> ===== registro (durante o draw) =====
> opts: key (identidade estável; default = obj/retângulo), group ("hand"...),
> px, py (ponto do cursor em fração do retângulo; default 0.5/0.5)

## L54-55 (em `NavCursor.target`, junto a `local sx, sy, sw, sh = g.getScissor()`)

> recorte do scissor corrente (em pixels reais — o UiScale devolve o
> scissor no espaço virtual: volta pra tela multiplicando pelo k)

## L74-76 (em `NavCursor.target`, junto a `function NavCursor.action(button, fn, x, y, w, h)`)

> Ação de contexto publicada pela tela neste quadro.
> button: "x" | "y" | "lb" | "rb"; fn: o que faz; rect opcional: onde
> desenhar o glifo (canto do botão que a ação aciona — nada de rodapé).

## L117-118 (em `under`, junto a `local function pickDefault(list)`)

> Alvo inicial: o que está sob o mouse; senão o mais perto do último foco;
> senão o primeiro em ordem de leitura (cima→baixo, esquerda→direita).

## L121-122 (em `pickDefault`, junto a `local IF = require("src.ui.InputFocus")`)

> a barra do topo (camada chrome) só ganha o foco se não houver mais nada:
> o conteúdo da tela é o que o jogador veio usar

## L155-157 (em `current`, junto a `if t and not focusExplicit and t.layer == require("src.ui.InputFocus").CHROME then`)

> foco AUTOMÁTICO parado na barra do topo enquanto o conteúdo da tela
> ainda não existia (botão que surge depois de uma animação): quando o
> conteúdo aparece, o foco vai pra ele

## L202-207 (em `NavCursor.position`, junto a `local function neighbor(list, from, dx, dy)`)

> ===== navegação =====
> Vizinho espacial: menor distância na direção, desvio lateral pesa 2x.
> Duas passadas: primeiro só dentro do cone de 45° (o que está "naquela
> direção" de verdade); sem ninguém no cone, qualquer um à frente — senão um
> alvo quase alinhado longe perdia pra um vizinho de outra fileira e havia
> botão que a seta nunca alcançava (Continuar da loja vindo do pacote).

## L256-257 (em `focusPt`, junto a `function NavCursor.cycle(step)`)

> Ombros: anda dentro do GRUPO do foco (a mão no combate); sem grupo, é
> esquerda/direita.

## L300-302 (em `NavCursor.runAction`, junto a `function NavCursor.intent(it, dev)`)

> ===== entrada =====
> Intenções: up/down/left/right/confirm/back/inspect/x/y/lb/rb
> Devolve true se consumiu.

## L318-319 (em `NavCursor.intent`, junto a `if t.layer == require("src.ui.InputFocus").CHROME and not focusExplicit then`)

> a barra do topo só recebe Enter se o jogador ANDOU até ela (o foco
> automático cai nela quando a tela ainda não tem conteúdo)

## L341-342 (em `NavCursor.noteDevice`, junto a `NavCursor.STATE_OWNS = { boot = true, gameOver = true, victory = true, achievements = true }`)

> Telas que NAVEGAM SOZINHAS (MenuKit/setas próprias): o cursor não toma
> as teclas delas. `extraOwned`: caso pontual do main (zoom da coleção).

## L395-397 (em `NavCursor.updateStick`, junto a `local PAD_COLORS = {`)

> ===== desenho =====
> Glifo de botão: pad = círculo com a letra (cores Xbox/Deck); teclado =
> tecla com o rótulo. Pixel art: retângulos e degraus, sem anti-alias.

## L440-442 (em `labelFor`, junto a `function NavCursor.draw()`)

> Anel de foco (gramática do MenuKit) + glifo de confirmação no canto do
> foco + glifos das ações de contexto nos botões que elas acionam. Desenha
> em PIXELS DA TELA, fora de qualquer escala (chamado no fim do love.draw).

## L447 (em `NavCursor.draw`, junto a `local size = math.max(26, math.floor(22 * k))`)

> glifo legível no Deck (7"): nunca menor que 26px de tela

## L452-453 (em `NavCursor.draw`, junto a `local lw = math.max(size, math.floor(size * 0.55) * #labelFor("confirm") + 8)`)

> glifo de confirmar POR FORA do canto superior direito (dentro ele
> cobria o selo de preço/custo das cartas)

