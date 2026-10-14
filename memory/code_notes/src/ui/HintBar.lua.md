---
name: code_notes/src/ui/HintBar.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/HintBar.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/HintBar.lua`

Origem: `src/ui/HintBar.lua` em `7dbdb60d` (4 de 7 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-8 (junto a `local FontManager = require("src.ui.FontManager")`)

> src/ui/HintBar.lua
> Barra de dicas PADRONIZADA (F1 do UI Overhaul — docs/plan/ui-ux-overhaul-v1.md §3.6).
> Regra: a dica SEMPRE cabe na tela — encolhe a fonte em degraus e, se ainda
> não couber, trunca com reticências. Mata a classe de bug "hint estourando
> dos dois lados" (loja). Pill centralizado, cores da paleta grimoire.
>
> Uso:  HintBar.draw("CLIQUE pra inspecionar · ESC volta")            -- rodapé
> HintBar.draw(texto, { y = 500, sizes = {14, 12, 10} })

## L15-16 (em `HintBar`, junto a `local function fit(text, maxW, sizes)`)

> Encaixa o texto na largura: tenta cada tamanho de fonte; no menor,
> trunca com "…" se preciso. Retorna font, texto final.

## L28-30 (em `fit`, junto a `local cut = require("utf8").offset(out, -1)`)

> remove UM CARACTERE inteiro (não um byte). A versão antiga parava
> no byte-líder de um caractere acentuado e deixava-o órfão: UTF-8
> inválido, e a LÖVE derruba o jogo no getWidth/print.

## L40-45 (em `fit`, junto a `HintBar.ENABLED = false`)

> DESLIGADA no jogo (pedido do dono, Out/2026: "tirar esses textos
> informativos... estão poluindo coisa demais"). As faixas de rodapé
> ("Passe o mouse pra ler · CLIQUE seleciona...") repetiam o que a própria
> tela já ensina pelo hover/botões. Um interruptor só, aqui, em vez de
> arrancar as 9 chamadas: religar é trocar pra true. Informação que o
> jogador PRECISA pra decidir não pode morar aqui — vai ancorada no objeto.

