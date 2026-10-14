---
name: code_notes/tools/test_achievements_i18n.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_achievements_i18n.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_achievements_i18n.lua`

Origem: `tools/test_achievements_i18n.lua` em `7dbdb60d` (5 de 6 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-23 (junto a `local TK = require("tools.testkit")`)

> tools/test_achievements_i18n.lua
> As 20 conquistas estão traduzidas DE VERDADE nos 5 idiomas.
>
> POR QUE NÃO BASTA O test_i18n
> Paridade de chave só prova que a chave EXISTE. Copiar a string portuguesa
> para os cinco locales passa na paridade e continua errado na tela — foi
> exatamente o risco que o assert do `smoke_acts` passou a cobrir para os
> nomes de ato. Com 20 conquistas × 2 campos × 5 idiomas o risco cresce, e
> conferir no olho não escala.
>
> O QUE ESTE TESTE EXIGE
> 1. toda conquista tem name + desc em TODOS os locales (nada de cair no
> fallback do catálogo);
> 2. o texto MUDA entre idiomas — pelo menos 2 valores distintos entre os 5
> (permite acerto legítimo tipo "Miasma" em pt/en/es, que ainda difere de
> "Miasme" em fr);
> 3. a maioria dos nomes é de fato distinta entre pt_BR e en (guarda contra
> alguém colar o bloco PT inteiro num locale novo);
> 4. es/fr/de são ACENTUADOS de verdade (Out/2026 inverteu a regra antiga
> "acento só no pt_BR" — a fonte desenha o Latin-1 inteiro).
>
> love . test_one test_achievements_i18n
> love . test_all

## L74-77 (em `M.run`, junto a `if loc ~= "pt_BR" and loc ~= "en" and (hasAccent(n) or hasAccent(s)) then`)

> Out/2026: a regra antiga era o CONTRÁRIO ("acento só no
> pt_BR"). Agora todo idioma é acentuado de verdade; um texto
> transliterado é que é defeito (tools/test_locale_accents.lua).
> Aqui basta provar que es/fr/de TÊM acento em algum lugar.

## L85 (em `M.run`, junto a `if distinctCount(names) < 2 then`)

> Texto tem que MUDAR entre idiomas, não ser o PT copiado 5x.

## L114-116 (em `M.run`, junto a `t:truthy(("maioria dos nomes difere pt_BR vs en (%d/%d)")`)

> Guarda contra "colei o bloco PT no locale novo": a maioria dos NOMES
> tem de diferir entre pt_BR e en. Alguns coincidem de verdade
> ("Miasma", "Asceta"), por isso é maioria e não totalidade.

## L122-123 (em `M.run`, junto a `local AchievementSystem = require("src.systems.AchievementSystem")`)

> E o caminho REAL de exibição (AchievementSystem.all) tem que devolver o
> texto traduzido — não o fallback do catálogo.

