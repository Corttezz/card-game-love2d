---
name: code_notes/src/ui/ComboBanner.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/ComboBanner.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/ComboBanner.lua`

Origem: `src/ui/ComboBanner.lua` em `7dbdb60d` (24 de 39 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-46 (junto a `local Config         = require("src.core.Config")`)

> src/ui/ComboBanner.lua
> Banner de COMBO: faixa full-width que anuncia, com NUMERO na tela, todo
> combo disparado no turno. Nasceu de um pedido direto do dono: "so o texto
> ao lado no chat de log nao e claro o suficiente" — o toast de 12px do
> MessageSystem some no meio das outras mensagens e o jogador nunca ve de
> onde veio o dano/bloqueio extra.
>
> ESTRUTURA: clonada do src/ui/TurnBanner.lua (precedente ja validado
> visualmente) — faixa parada num canvas pre-renderizado que MATERIALIZA e
> DISSOLVE com o mesmo DissolveShader das cartas. O que muda:
> · acento proprio (violeta arcano do Palette) — nem ouro (turno do
> jogador) nem sangue (turno do inimigo);
> · altura variavel: titulo + uma linha por combo;
> · o GANHO aparece escrito (x1.4 / +6 / +4 HP) — e o ponto do banner.
>
> ===== ZONA (v2, feedback do dono Set/2026) =====
> "pode subir mais... esta ficando debaixo em profundidade das cartas usadas
> no turno, da nem pra ler". Duas correcoes:
> (a) PROFUNDIDADE — a chamada de draw migrou pro FIM do frame de gameplay,
> depois da mao E depois do combatAnimationSystem (as cartas que voam).
> Ver src/scenes/GameplayScene.lua.
> (b) POSICAO — o banner deixou de ser "logo abaixo do TurnBanner" (ancora
> vizinho-a-vizinho, o anti-pattern do memory/ui_layout_invariants.md
> §1) e passou a morar numa ZONA DE ANUNCIO declarada: do rodape da
> TopBar ate a LINHA DE POUSO das cartas do turno. O rodape do banner
> encosta no teto do pouso e ele cresce PRA CIMA. Se o conteudo nao
> couber na zona (4 combos num turno), quem cede e a ESCALA do
> conteudo — as bandas nao se mexem.
>
> OCUPANTE UNICO: TurnBanner e ComboBanner dividem a mesma faixa de tela, e
> por isso NUNCA aparecem juntos — a fila abaixo segura o combo enquanto o
> banner de turno estiver no ar. Nao e ajuste fino de pixel, e exclusao por
> construcao. (Na pratica quase nunca espera: o combo so dispara no IMPACTO
> da carta, bem depois do banner de turno ter cumprido a funcao.)
>
> FILA (decisao): combos do MESMO turno viram UM banner de varias linhas,
> nao N banners em sequencia. Motivo: eles nao sao eventos separados — se
> compoem sobre as MESMAS cartas (x1.4 e depois +6 no mesmo golpe), entao
> ler os dois juntos e o que explica o numero final. Em fila, 3 combos
> custariam ~3s e o ultimo cairia depois da animacao de combate que ele
> deveria estar explicando. Turnos DIFERENTES enfileiram de verdade, um apos
> o outro — dois banners nunca dividem a tela.
>
> Uso: ComboBanner.show(combos) · update(dt) · draw(topBarH) · isActive()
> · clear()
> combos = lista de regras do ComboSystem ({ id, label, bonus })

## L62-64 (em `canvasCache`, junto a `local PAD_V      = 10`)

> Metricas do conteudo em escala 1 (px logicos). A escala efetiva sai de
> fitScale(), aplicada as fontes E as alturas — nunca um scale no draw, que
> estreitaria a faixa full-width e borraria o pixel art.

## L70 (em `canvasCache`, junto a `local VALUE_FONT = 26`)

> o GANHO e o motivo do banner existir: vem maior

## L72-78 (em `canvasCache`, junto a `local TOP_BAR_H_DEFAULT = 52`)

> ===== ZONA DE ANUNCIO =====
> Teto: rodape da TopBar (draw() recebe a altura real; 52 e o valor de
> components/TopBar.lua, barra de altura FIXA — serve de default no 1o frame
> e nas ferramentas que desenham sem TopBar).
> Piso: topo das cartas que pousam no centro. O pouso vem do CombatSequence
> (centro em screenH * 0.45); a carta e o canvas 144px do CardFrame na
> BASE_SCALE, e HOP_MARGIN cobre o pulinho do impacto (Moveable.hop_up).

## L95-97 (em `announceZone`, junto a `local FADE_IN, FADE_OUT = 0.30, 0.30`)

> Envelope temporal, igual em espirito ao TurnBanner:
> materialize 0.30 · hold · dissolve 0.30. O hold cresce com o numero de
> linhas (mais texto = mais tempo de leitura).

## L101-103 (em `announceZone`, junto a `local STALE_AFTER = 5.0`)

> Guarda-chuva anti-fantasma: se a cena parar de tickar (batalha acabou no
> meio do banner e o jogo foi pro cardReward), a entrada nao pode reaparecer
> na batalha seguinte. Expira por relogio de parede.

## L114-116 (em `now`)

> ============================================================================
> TEXTO DO GANHO — o que o dono quer enxergar
> ============================================================================

## L118-121 (em `now`, junto a `local function formatBonus(b)`)

> Formata o bonus da regra do jeito que o jogador le no resto do jogo:
> multiplicador vira "×1.4" (mesma convencao dos procs de joker no
> EffectSystem), bonus plano vira "+6". Tipos de evento (debuff/cura/evoke)
> dizem o que ganharam.

## L141-143 (em `formatBonus`, junto a `local function comboName(combo)`)

> Nome do combo: i18n primeiro (combos.<id>), rule.label como fallback —
> os dois existem hoje e a tabela do locale estava orfa; com o banner dando
> destaque ao texto, a fonte de verdade passa a ser o i18n.

## L149-151 (em `comboName`)

> ============================================================================
> GEOMETRIA — recalculada sempre que a janela muda de tamanho
> ============================================================================

## L153-157 (em `comboName`, junto a `local function ensureGeometry(entry)`)

> Resolve as metricas do banner pra tela ATUAL. Invariante 2 do
> memory/ui_layout_invariants.md: estado cacheado (canvas + alturas) tem que
> acompanhar o resize. Como esta scene nao tem resize() proprio, o recalculo
> mora aqui e e chamado por show() E por update() — os dois rodam FORA do
> love.draw, que e onde o canvas pode ser criado com seguranca.

## L169 (em `ensureGeometry`, junto a `local s = math.min(1, zoneH / natural)`)

> conteudo cede, banda nao (invariante 1)

## L191-193 (em `geo`, junto a `local function bannerCanvas(entry)`)

> ============================================================================
> CANVAS (pre-renderizado fora do frame de draw — ver TurnBanner)
> ============================================================================

## L199-200 (em `bannerCanvas`, junto a `local sx0, sy0, sw0, sh0 = love.graphics.getScissor()`)

> scissor herdado do frame recortaria o clear do canvas (glClear RESPEITA
> scissor) — mesma blindagem do TurnBanner.

## L262-263 (em `bannerCanvas`, junto a `if canvasCount > 24 then`)

> cache limitado: os combos possiveis sao poucos, mas resize gera chaves
> novas — nao deixa crescer pra sempre.

## L273-275 (em `canvasCache`, junto a `function ComboBanner.show(combos)`)

> ============================================================================
> API
> ============================================================================

## L277 (em `canvasCache`, junto a `function ComboBanner.show(combos)`)

> Enfileira UM banner com todos os combos recebidos.

## L297-298 (em `entry`, junto a `ensureGeometry(entry)`)

> pre-render AQUI (fora do love.draw): criar canvas no meio do frame,
> com o scissor do WorldRoad vivo, corrompia o conteudo (TurnBanner v2.1)

## L331 (em `ComboBanner.isActive`, junto a `function ComboBanner.clearCache()`)

> Resize/fullscreen apaga o conteúdo de todo Canvas — ver TurnBanner.clearCache.

## L344-345 (em `ComboBanner.clear`, junto a `local BURN = { { 0.55, 0.30, 0.85, 1.0 }, { 0.95, 0.65, 0.95, 1.0 } }`)

> Chamas do dissolve: mesma familia violeta/magenta do pack de booster —
> le como "arcano", nao como fogo (ataque) nem como ouro (turno).

## L348-349 (em `BURN`, junto a `function ComboBanner.draw(topBarH)`)

> topBarH: altura real da TopBar (GameplayScene passa a sua). Define o TETO
> da zona de anuncio; sem ela usa o default fixo de components/TopBar.lua.

## L358-360 (em `ComboBanner.draw`, junto a `local reduced = _G.gameSettings and _G.gameSettings.reducedMotion`)

> Acessibilidade: com reducedMotion o banner CONTINUA aparecendo (e
> informacao de jogo, nao enfeite) — some so a queima. No lugar dela,
> um fade curto, pra nao dar pop seco na tela.

## L384-385 (em `ComboBanner.draw`, junto a `if not reduced and not DissolveShader.isAvailable()`)

> lazy-load do shader (ferramentas de screenshot nao passam pelo
> love.load completo e caiam no fallback de fade silencioso)

## L398-399 (em `ComboBanner.draw`, junto a `local ns = { 5.5 * sw / geo.h, 5.5 }`)

> noise anisotropico: celula ~quadrada na faixa full-width (sem isso
> a queima estica em "faixas fantasmas")

