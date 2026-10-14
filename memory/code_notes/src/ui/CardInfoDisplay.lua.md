---
name: code_notes/src/ui/CardInfoDisplay.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/CardInfoDisplay.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/CardInfoDisplay.lua`

Origem: `src/ui/CardInfoDisplay.lua` em `7dbdb60d` (17 de 29 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-11 (junto a `local FontManager = require("src.ui.FontManager")`)

> src/ui/CardInfoDisplay.lua
> Tooltip de carta no hover (mão, rewards, coleção via Card.lua).
>
> v2 (design system Jul/2026 — playtest: "o tooltip quebra, texto passa do
> painel, letter spacing ruim"): a fonte 16 era grande demais pro painel, a
> largura era chutada (não media o conteúdo) e a linha de forja usava print
> cru. Agora: TODO o conteúdo é MEDIDO antes (a maior linha define a largura,
> com teto), tipografia na escala do design system (nome 13 / corpo 10 com
> line-height 1.35 / meta 9), painel escuro-dourado do grimório (era cinza
> azulado legado) e a forja mostra APENAS os ganhos reais da carta
> (RunManager.getForgeGains — carta de ataque puro nunca anuncia DEF).

## L23 (em `CardInfoDisplay`, junto a `local LINE_K = 1.35`)

> line-height (respiro pedido no playtest)

## L55-56 (em `CardInfoDisplay:configure`, junto a `local function buildForgeLine(inst)`)

> Linha de forja com os ganhos REAIS da carta (fonte única getForgeGains).
> nil quando a carta não é forjada.

## L73-76 (em `parts`, junto a `local TextCase = require("src.i18n.TextCase")`)

> Keywords da descrição (glossário F5) — até 3 hits, texto composto.
> Casa as palavras do LOCALE ATUAL contra a descrição já traduzida, e o
> verbete exibido vem do i18n (`keyword.<id>.name/text`). Antes o glossário
> era português em todo idioma (Out/2026).

## L79-81 (em `parts`, junto a `local function hasWord(lower, word)`)

> Palavra começa aqui? (antes dela não pode haver letra ASCII: "gelo" não
> casa dentro de "Congelar", "ice" não casa dentro de "twice"). O fim fica
> livre para pegar plural/flexão ("Raios", "Orbs").

## L107 (em `hits`, junto a `if not CardInfoDisplay._warnedKeywords then`)

> Chamado a cada hover: require quebrado avisaria todo quadro.

## L115-117 (em `hits`, junto a `local groupHit = {}`)

> group: no maximo UM verbete por grupo (orbes por elemento — a carta
> de Fogo explica so o orbe de Fogo, e o generico "Orbes" vira
> fallback em vez de segundo verbete; feedback Jul/2026).

## L121-123 (em `groupHit`, junto a `local ctxOk = (kw.requires == nil) or anyWord(lower, kw.requires, loc)`)

> requires: verbete só vale se a desc TAMBÉM contém uma das
> palavras-contexto (ex: "fogo" sozinho não é orbe de Fogo —
> precisa de "canaliza/evoca/orbe/valor" junto).

## L175 (em `CardInfoDisplay:draw`, junto a `local _, nameLines = nameFont:getWrap(name or "", MAX_INNER)`)

> ===== 2. MEDIDA (a maior linha define a largura; nada vaza) =====

## L213-219 (em `kwBlocks`, junto a `local GAP = 6`)

> ===== 3. POSIÇÃO (gap ADAPTATIVO — playtest Jul/2026: o painel gruda
> a 6px da carta; clamp segura dentro da tela). Default ACIMA (cartas
> da mão, no rodapé). options.below = ABAIXO — para cartas no TOPO da
> tela (coringas ativos do combate, 1ª fileira do Gerenciador): acima,
> o clamp fazia o painel COBRIR o topo da própria carta (feedback
> Jul/2026 "o topo deles tá sendo cortado"). No modo below, y é a
> âncora INFERIOR da carta.

## L221-223 (em `kwBlocks`, junto a `local topMin = localOptions.minY or 8`)

> options.minY: teto do painel (espólios: a TopBar é camada chrome e
> desenha DEPOIS — painel preso no topo da tela ficava com o nome
> escondido atrás dela). Sem a opção, 8 px da borda como sempre.

## L235-242 (em `kwBlocks`, junto a `local cx0 = localOptions.cardX or x`)

> AO LADO da carta (mão do combate, Out/2026): acima da carta
> levantada o painel caía sobre o tronco do inimigo, que fica no
> meio da tela. De lado, topo alinhado ao topo da carta: o painel
> ocupa a faixa da própria carta levantada e não sobe pro palco.
> Lado preferido = ESQUERDO: à direita moram Jogar/Encerrar, que
> desenham DEPOIS da mão e engoliam o painel (visto em 1024x768).
> Sem espaço (cartas da ponta esquerda), vira pra direita — perto do
> centro, longe dos botões.

## L255-256 (em `kwBlocks`, junto a `self.lastRect = { x = panelX, y = panelY, w = panelW, h = panelH }`)

> Retângulo efetivamente desenhado: a régua do palco da batalha
> (tools/test_enemy_stage) mede o inimigo contra ESTE painel.

## L286 (em `self.lastRect`, junto a `if forgeLine then`)

> Forja: só os ganhos REAIS (verde, com fit — nunca vaza)

## L311-314 (em `self.lastRect`, junto a `local head = (kw.name .. kwSep):gsub("%s+$", "")`)

> Nome dourado + corpo pergaminho, a partir do bloco pré-wrapado.
> O wrap apara o espaço do fim da linha, então compara sem ele; e só
> corta quando o nome inteiro está na linha (nunca no meio de um
> caractere UTF-8). Nome quebrado no wrap sai todo em pergaminho.

## L347-349 (em `self.lastRect`, junto a `if showStats then`)

> Stats (ícones + valores reais da instância — forjada mostra o número real).
> Ícone escalado pra MESMA altura do número e ambos no MESMO topo de linha
> (playtest: o scale fixo 0.022 deixava ícone e valor desalinhados).

## L372 (em `statPair`, junto a `if require("src.ui.CardFrame").showsManaCost(cardInstance) then`)

> Coringa nao tem custo de mana — regra unica em CardFrame.showsManaCost.

