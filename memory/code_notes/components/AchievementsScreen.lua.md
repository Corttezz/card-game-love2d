---
name: code_notes/components/AchievementsScreen.lua
description: Comentários com decisão/regra/histórico colhidos de components/AchievementsScreen.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `components/AchievementsScreen.lua`

Origem: `components/AchievementsScreen.lua` em `7dbdb60d` (11 de 27 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-23 (junto a `local AchievementsScreen = {}`)

> components/AchievementsScreen.lua
> Galeria de conquistas. Abre pelo botao Conquistas do menu; ESC/clique fora
> fecha.
>
> LAYOUT POR ZONAS (CLAUDE.md, "layout de tela = zonas"):
> CABECALHO  titulo + contador global x/N + barra de progresso
> GRADE      emblemas agrupados por categoria (Jornada / Restricao /
> Maestria / Legado), cada grupo com o seu x/N
> DETALHE    a conquista em foco: emblema grande, nome, categoria, tags
> (SECRETA), condicao, barra de progresso "1840 / 2500" e a data
> de desbloqueio. NUNCA vazio: sem hover, mostra a selecionada
> (padrao = a bloqueada mais perto de sair).
> RODAPE     HintBar
> Janela larga: GRADE | DETALHE lado a lado. Estreita: DETALHE embaixo.
> Falta espaco -> quem cede e o TAMANHO do emblema, nunca a posicao das zonas.
>
> Referencias: grade de icones + tooltip do StS (screens/stats/AchievementGrid)
> e o painel de detalhe fixo das colecoes do Balatro. Bloqueada = o proprio
> emblema em silhueta (o alvo e reconhecivel); secreta = silhueta + "?".
>
> O layout e PURO (`layout(sw, sh)`): draw e mouse leem a mesma geometria,
> entao resize nao precisa de cache (tools/test_achievements audita em varios
> tamanhos).

## L57-58 (em `instance.entries`, junto a `function AchievementsScreen:_refresh()`)

> `entries` guarda TEXTO JA TRADUZIDO, valido so pro idioma em que foi
> montado: o draw remonta se o jogador trocou de idioma.

## L64 (em `AchievementsScreen:_refresh`, junto a `function AchievementsScreen:_defaultSelection()`)

> Bloqueada com maior fracao de progresso; senao a primeira bloqueada.

## L95-97 (em `AchievementsScreen:isVisible`, junto a `function AchievementsScreen:update(dt)`)

> Hover lido aqui (main.lua nao repassa mousemoved a esta tela). So conta
> quando o mouse MEXE: parado em cima de um emblema, nao rouba o foco de
> quem esta navegando pelas setas.

## L147-148 (em `L`, junto a `local closeS = 28`)

> X de fechar no canto do cabeçalho (como o Deck Viewer): ESC sozinho não
> se descobre, e o rodapé de dica está desligado (HintBar.ENABLED).

## L167-168 (em `L.detail`, junto a `local groups = tierGroups(entries)`)

> Maior celula que cabe (a ESCALA cede, nao as zonas). 64 = 1:1 com o
> PNG (pixel nitido) e o preferido; abaixo disso encolhe de 2 em 2.

## L221-223 (em `AchievementsScreen:_cellAt`, junto a `function AchievementsScreen.neighbor(L, from, dir)`)

> Vizinho ESPACIAL (as linhas sao balanceadas, entao "indice +- colunas" nao
> e mais a celula de cima/baixo). Escolhe a celula na direcao pedida com
> menor distancia, pesando o desvio lateral em dobro.

## L324 (em `AchievementsScreen:_drawCell`, junto a `if not e.unlocked and e.progress and e.progress.cur > 0 then`)

> progresso em andamento: filete sob o emblema

## L330-331 (em `AchievementsScreen:_drawCell`, junto a `local DESC_LH = 1.45`)

> Texto da condicao: Press Start 2P com entrelinha 1.0 encosta as linhas;
> 1.45 e o respiro usado nas outras telas de leitura.

## L345-346 (em `statusText`, junto a `local function detailText(e, tx, ty, tw, dry)`)

> Bloco de texto do detalhe (nome, categoria, condicao, progresso, status).
> `dry` so mede: o layout largo centraliza o bloco inteiro na vertical.

## L406-407 (em `AchievementsScreen:_drawDetail`, junto a `local big = (math.min(w - pad * 2, h * 0.42) >= 128) and 128 or 64`)

> Emblema grande (128 = 2:1 nitido; 64 quando a zona e baixa) e o
> bloco de texto, centralizados juntos na vertical (leve vies pro topo).

