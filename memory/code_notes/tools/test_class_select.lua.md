---
name: code_notes/tools/test_class_select.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_class_select.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_class_select.lua`

Origem: `tools/test_class_select.lua` em `7dbdb60d` (8 de 22 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-22 (junto a `local TK = require("tools.testkit")`)

> tools/test_class_select.lua
> Trava da seleção de classe v4 ("página do grimório": uma classe em foco,
> detalhes sob demanda, Out/2026 — memory/class_emblems.md).
>
> O que garante:
> • o layout de ZONAS (ClassSelectLayout) é válido em todo tamanho de
> janela suportado (800×600 até 2560×1440) — nenhuma banda encosta;
> • o resize() de verdade (janela falsificada, cache de fonte limpo)
> reposiciona os botões no layout novo e o draw não explode;
> • a tela usa no máximo DUAS fontes (nome e corpo);
> • foco × início: o emblema pequeno só troca o foco, COMEÇAR inicia;
> • classe BLOQUEADA: selectClass devolve false e o callback NUNCA roda —
> nem por clique direto (mousepressed/released no painel);
> • classe LIBERADA: o callback roda com o id certo;
> • os assets dos emblemas e das correntes existem e carregam;
> • nenhuma referência sobrou aos heróis chibi aposentados.
>
> O UnlockSystem é dirigido por monkeypatch das 3 funções do CONTRATO —
> vale pro stub e pra versão real da frente progressão.
>
> love . test_one test_class_select
> love . test_all

## L66 (em `orig`, junto a `for _, id in ipairs({ "warrior", "mage", "rogue" }) do`)

> 0. contrato do UnlockSystem (stub ou real) responde pras 3 classes

## L85-86 (em `orig`, junto a `local UiScale = require("src.ui.UiScale")`)

> 2. layout puro em todos os tamanhos (no espaço VIRTUAL do UiScale,
> que é onde a tela desenha)

## L152-154 (em `click`, junto a `do`)

> 3b. CARTAS INICIAIS nos DETALHES: carta de verdade (hover = lift +
> tooltip ao lado), clique/botão direito = inspeção da Coleção,
> Esc fecha sem voltar ao menu, setas passam entre as iniciais.

## L162-163 (em `click`, junto a `s3:focusClass("mage")`)

> mago em foco: as iniciais dele têm ícone ANIMADO (o canvas vivo
> do CardFrame entra no hover — é o que a trava abaixo mede)

## L167-171 (em `click`, junto a `local simNow = 1000`)

> TUDO em tempo SIMULADO (padrão do test_discovery_mark, e8ff073):
> o relógio de parede entrava pelo CardFrame (índice do frame,
> ressincronização "stale") e pela ondulação da carta; sob carga
> (test_all com a máquina ocupada) o resultado mudava de rodada
> pra rodada. Aqui cada frame() avança 1/60 s, sempre.

## L202-208 (em `love.timer.getTime`, junto a `do`)

> CARTA VIVA: o set monta sob orçamento por quadro (9 PNGs + 8
> composições ≈ 20 quadros) e a imagem estática VOLTA ao fim de
> cada draw (swap temporário de instance.image — a carta é viva
> em toda tela desde 13/Out/2026, mas o estado nunca guarda o
> quadro vivo).
> Era aqui que o test_all caía em CardFrame.lua:423 quando o
> CardFrame.render chegava estubado de uma suite anterior.

## L283-284 (em `drawn`, junto a `lockOnly(US, { mage = true, rogue = true })`)

> 4. resize real: botões acompanham o layout + draw sem erro +
> só DUAS fontes na tela (nome e corpo)

