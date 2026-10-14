---
name: code_notes/tools/test_preview_plate.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_preview_plate.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_preview_plate.lua`

Origem: `tools/test_preview_plate.lua` em `7dbdb60d` (2 de 11 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-21 (junto a `local TK = require("tools.testkit")`)

> tools/test_preview_plate.lua
> A PLACA da previa de dano (src/ui/DamagePreviewPanel, Out/2026): resumo
> por padrao, detalhes sob demanda, lembrado em settings, e as bandas nunca
> se sobrepoem em nenhum tamanho de janela.
>
> Historico: o painel nasceu mostrando a conta inteira (carta a carta, fichas,
> combos, coringas) o tempo todo — o dono: "grande e confuso". Agora:
> • RESUMO (default): dano, Bloqueio, LETAL + fichas de combo/coringa;
> • DETALHES: a conta inteira — clique na placa, tecla V (main.lua) ou
> foco + A no pad (a placa e alvo do NavCursor);
> • a escolha persiste em `previewDetails` (SaveManager/SettingsMenu).
>
> O que trava aqui:
> • Panel.layout + Panel.validate em 6 tamanhos (janela falsificada), pelo
> caminho REAL (Panel.draw com uma leva de verdade), resumo e detalhes;
> • resumo e mais BAIXO que detalhes com a mesma leva;
> • toggle persiste no arquivo de settings (sandbox *.tool.lua);
> • clique dentro da placa alterna; fora nao; sem draw no quadro, nao;
> • chaves i18n nos 5 locales.
>
> love . test_one test_preview_plate

## L157-158 (em `sizes`, junto a `local sm = love.filesystem.read("components/SettingsMenu.lua") or ""`)

> (sem linha em Configuracoes: a aba Jogo tem altura fixa e 5 linhas
> — test_pause_menu trava isso; a placa e a tecla V sao o controle)

