---
name: code_notes/src/ui/UiScale.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/UiScale.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/UiScale.lua`

Origem: `src/ui/UiScale.lua` em `7dbdb60d` (17 de 30 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-30 (junto a `local UiScale = {}`)

> src/ui/UiScale.lua
> ESCALA GLOBAL DA INTERFACE (Out/2026 — auditoria de UI: "em 1080p pouco
> escala e em 1440p nada escala"; carta ~7% da altura, texto ilegível,
> miniaturas de 60px numa estante vazia).
>
> A ideia: as telas de UI foram desenhadas pra ~1280x720. Em vez de reescrever
> o layout de cada uma com um fator, elas passam a viver num ESPAÇO VIRTUAL
> do tamanho da janela dividido por k, desenhado com love.graphics.scale(k).
> Dentro do contexto:
> * love.graphics.getWidth/getHeight/getDimensions devolvem o tamanho
> VIRTUAL (todo layout das telas deriva deles — as zonas continuam zonas);
> * love.mouse.getPosition/getX/getY devolvem o mouse VIRTUAL (o hover por
> polling — 40+ call sites — funciona sem mudar nenhum);
> * setScissor/intersectScissor/getScissor convertem pra pixels reais
> (scissor ignora a transformação — o defeito clássico de UI escalada);
> * FontManager rasteriza a fonte com dpiscale = escala corrente, então o
> texto sai NÍTIDO no tamanho final, não um bitmap pequeno esticado.
>
> k = clamp(min(W/1280, H/720), 1, 2.5) × multiplicador do jogador
> (Configurações → Vídeo: 80% / 90% / Auto / 125% / 150%)
>
> Quem entra no contexto: as telas ADOTADAS (UiScale.adopt) — todo método da
> classe roda dentro dele (show/resize/update/draw/input), então layout
> calculado no show() e hit-test no clique enxergam o mesmo espaço. Mouse
> handlers (mousepressed/released/moved) recebem as coordenadas convertidas
> quando a chamada vem de FORA do contexto (main.lua passa pixels reais).
>
> Quem NÃO entra (por enquanto): o HUD de batalha e a mão (GameplayScene) —
> outras frentes estão mexendo lá. `UiScale.k()` já está exposto pra quando
> a batalha adotar. A TopBar escala fora da batalha (predicado chrome).

## L36-37 (em `UiScale`, junto a `UiScale.OPTIONS = { 0.8, 0.9, 1, 1.25, 1.5 }`)

> Multiplicadores oferecidos nas Configurações (1 = Auto). Relativos ao Auto
> de propósito: um "150%" ABSOLUTO seria MENOR que o Auto num monitor 4K.

## L41-44 (em `UiScale.OPTIONS`, junto a `local deviceMul = (os.getenv("SteamDeck") == "1") and 1.25 or 1`)

> Aparelho de tela pequena e densa: o Steam Deck (1280x800 em 7") dá k=1 pela
> conta da janela, e o texto de 8px fica com ~1mm. O Steam exporta
> SteamDeck=1 no Deck: lá o Auto já começa em 125% (8px → 10px efetivos).
> O jogador ainda ajusta por cima (multiplicador das Configurações).

## L76-77 (em `UiScale.auto`, junto a `function UiScale.k(w, h)`)

> Fator efetivo para a janela atual (ou w,h dados). Fora do contexto lê a
> janela de verdade (ou a falsificada pelos tools/testes).

## L84-85 (em `UiScale.k`, junto a `local k = math.floor(UiScale.auto(w, h) * deviceMul * userMul * 4 + 0.001) / 4`)

> degraus de 1/4: fonte pixel e arte nearest ficam com blocos iguais
> (1366x768 daria 1.067 — tudo 7% maior e serrilhado à toa → 1)

## L131-133 (em `g.getScissor`, junto a `local function rawMouse()`)

> a leitura crua passa pela lente do CRT (InputFocus.installMouseGate →
> CRTShader.screenToContent), que mede a JANELA: ela precisa ver as
> dimensões reais durante a leitura, senão o mapeamento entorta

## L159-160 (em `unpatch`, junto a `function UiScale.begin(k)`)

> Entra no contexto (aninhável). `k` opcional força o fator (tooltip que
> nasceu num contexto e desenha depois, fora dele).

## L163 (em `UiScale.begin`, junto a `activeK = k or UiScale.k()`)

> ANTES de subir a profundidade (k() lê activeK dentro)

## L182-183 (em `UiScale.finish`, junto a `function UiScale.reset()`)

> Higiene de frame (como InputFocus.resetLayers): um erro no meio de um
> método adotado deixaria as funções globais trocadas pra sempre.

## L195-198 (em `UiScale.reset`, junto a `function UiScale.outside(fn, ...)`)

> Roda fn FORA do contexto (de dentro de um método adotado). Uso: chamar
> love.resize a partir das Configurações — o resize global recria canvases
> e layouts da batalha, que precisam da janela REAL. Só de input/update
> (nunca no meio de um draw com push próprio por cima do nosso).

## L207-208 (em `UiScale.outside`, junto a `suspended = suspended + 1`)

> função ADOTADA chamada aqui dentro (ex.: GameplayScene._drawWorldOnlyReal)
> não pode reabrir o contexto — o mundo é desenhado na janela real

## L240-243 (em `MOUSE`, junto a `function UiScale.adopt(tbl, opts)`)

> Embrulha TODOS os métodos de `tbl` pra rodarem no contexto.
> opts.method    true (default) = funções chamadas com ':' (self primeiro)
> opts.predicate função opcional: só escala quando devolve true
> Idempotente (marca a tabela).

## L257-258 (em `names`, junto a `if depth > 0 or suspended > 0 or (pred and not pred()) then return fn(...) end`)

> já dentro do contexto (chamada aninhada): nada a fazer — as
> coordenadas já são virtuais

## L280-282 (em `res`, junto a `UiScale.SCREENS = {`)

> As telas de UI do jogo (a batalha entra por MODULES). A TopBar tem
> predicado (chromeScaled) — hoje sempre ligado. TELA NOVA DE UI: entra aqui
> no mesmo commit.

## L295-296 (em `UiScale.MODULES`, junto a `"src.scenes.GameplayScene" }`)

> batalha: a CENA é adotada (mão/HUD/botões); o mundo dentro dela roda
> em UiScale.outside (ver o cabeçalho de GameplayScene)

## L311-312 (em `UiScale.adoptDefaults`, junto a `function UiScale.fontDpi()`)

> Escala de transformação corrente (para a fonte nítida). Só consultada
> dentro do contexto — fora dele (batalha) a fonte não muda.

## L318-319 (em `UiScale.fontDpi`, junto a `return math.max(1, math.min(3, math.floor(s * 4 + 0.5) / 4))`)

> degraus de 0.25: animação de escala (hover, entrada) não cria uma fonte
> por frame; e nunca abaixo de 1 (canvas com origin() desenha em 1:1)

