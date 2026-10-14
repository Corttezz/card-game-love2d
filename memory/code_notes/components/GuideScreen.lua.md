---
name: code_notes/components/GuideScreen.lua
description: Comentários com decisão/regra/histórico colhidos de components/GuideScreen.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `components/GuideScreen.lua`

Origem: `components/GuideScreen.lua` em `7dbdb60d` (3 de 13 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-15 (junto a `local I18n = require("src.i18n.I18n")`)

> components/GuideScreen.lua
> GUIA DO GRIMÓRIO (onboarding, Out/2026): a referência que faltava.
>
> Auditoria de jogabilidade: 13 combos e nenhuma lista deles no jogo; o
> glossário de palavras-chave só existia em pedaços, dentro do tooltip da
> carta. Duas abas, ambas GERADAS dos dados (texto e regra nunca divergem):
> Combos     ComboSystem.RULES → nome (combos.<id>), regra + efeito
> (DamagePreviewPanel.comboDescription — o MESMO texto da prévia
> de dano, que já diz o requisito) e cartas de exemplo com a tag,
> da classe da run primeiro.
> Glossário  src/data/keywords.lua → keyword.<id>.name / .text.
>
> Abre pelo atalho "Guia" da Pausa ou pela tecla G em qualquer tela da run
> (main.lua). Navega sozinha (ownsNavigation): ←/→ ou LB/RB trocam a aba,
> ↑/↓ e a roda rolam, Esc/B/G fecham.

## L31-32 (em `TABS`, junto a `local navWarned = false`)

> Alvo do foco de teclado/pad (src/ui/NavCursor). O módulo é de outra frente;
> se faltar, o Guia segue funcionando pelo teclado próprio e AVISA uma vez.

## L166 (em `L.content`, junto a `function GuideScreen:_rows(L)`)

> Linhas do conteúdo medidas na largura dada.

