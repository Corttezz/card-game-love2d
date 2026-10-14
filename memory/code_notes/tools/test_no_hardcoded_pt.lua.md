---
name: code_notes/tools/test_no_hardcoded_pt.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_no_hardcoded_pt.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_no_hardcoded_pt.lua`

Origem: `tools/test_no_hardcoded_pt.lua` em `7dbdb60d` (9 de 15 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-29 (junto a `local TK = require("tools.testkit")`)

> tools/test_no_hardcoded_pt.lua
> TRAVA contra português cravado em código de UI.
>
> POR QUE ESTE TESTE EXISTE
> Duas telas multilíngues saíram BILÍNGUES em produção porque metade do texto
> vinha do i18n e a outra metade era literal PT no meio do desenho:
> • `Config.Acts[n].name` → "AKT 1 — Catacumbas" no Roteiro (Set/2026)
> • `RoundEvalScreen:_buildDynaTexts` → título PT com botão traduzido
> Consertar as duas não impede a terceira. Isto impede.
>
> O QUE ELE PEGA (e o que NÃO pega)
> O sinal é a ACENTUAÇÃO: um literal com ç/ã/õ/é/á/í/ó/ú/â/ê/ô/à dentro de um
> arquivo de código é quase sempre texto de jogador esquecido. É o mesmo sinal
> que um humano usa ao varrer o repo, só que automatizado.
>
> NÃO pega PT sem acento ("Batalha", "Loja", "Descanso"). Isso é limite
> conhecido, não descuido: uma lista de palavras PT daria falso positivo em
> identificador, nome de asset e chave de tabela. Quando um caso desses
> aparecer, o jeito é adicionar a ocorrência à revisão manual — não afrouxar
> a regra que funciona.
>
> O QUE ELE IGNORA (legitimamente)
> • comentários — PT é a convenção do projeto (CLAUDE.md §9);
> • saída de dev: print / Debug.* / error / assert — ferramenta, não UI;
> • o fallback de I18n.t(chave, vars, "texto PT") — esse é o padrão CERTO;
> • os próprios locales e os tools.
>
> love . test_one test_no_hardcoded_pt
> love . test_all

## L47 (em `DEV_PATTERNS`, junto a `"return%s+%w+%s*,%s*\"",`)

> par (ok, "motivo") — erro interno, não UI

## L50-51 (em `DEV_PATTERNS`, junto a `local ALLOW = {`)

> Exceções auditadas. Cada entrada precisa de motivo — a lista é o registro de
> "eu olhei e decidi", não um tapete pra empurrar sujeira.

## L61-65 (em `ALLOW`, junto a `}`)

> components/RestScreen.lua saiu daqui (Set/2026): a linha
> "Já no nível máximo" virou `rest.forge_capped` e o arquivo passa a
> varredura sem exceção. Exceção cumprida é exceção REMOVIDA — deixá-la
> aqui depois de resolvida transforma a lista de decisões auditadas num
> tapete, que é exatamente o que o comentário acima proíbe.

## L67-70 (em `ALLOW`)

> Nota: src/data/achievements.lua NÃO está aqui porque os nomes das conquistas
> não têm acento — a trava não os enxerga. Continuam em PT e sem chaves i18n;
> é uma superfície conhecida, registrada no relatório, não uma exceção desta
> lista (entrada morta aqui só afrouxaria a regra).

## L72-76 (em `ALLOW`, junto a `local MATH_SIGNS = { [151] = true, [183] = true }   -- 0x97, 0xB7`)

> Um literal entre aspas duplas contém byte de acentuação latina?
> Em UTF-8 as vogais acentuadas e o ç caem todas em 0xC3 + segundo byte.
> DUAS exceções no mesmo prefixo 0xC3 que NÃO são letras: × (0xC3 0x97) e
> ÷ (0xC3 0xB7) — sinais de multiplicação/divisão, usados de propósito nos
> popups de proc de coringa ("×2") e nas descrições de efeito.

## L88-90 (em `hasAccent`, junto a `local function stripComment(line)`)

> Remove o que está depois de um `--` fora de string (heurística suficiente:
> comentário com aspas antes do `--` é raro e só geraria FALSO POSITIVO, que
> é o lado seguro pra uma trava).

## L134-137 (em `parenDelta`, junto a `local function scanFile(path)`)

> Varre por LINHA LÓGICA, não física. Uma chamada quebrada em várias linhas
> (`print(...` ou `I18n.t(...` com o fallback na linha de baixo) tinha a
> continuação julgada sozinha e virava falso positivo — aconteceu em 6
> arquivos na primeira execução desta trava.

## L220-221 (em `targets`, junto a `for path in pairs(ALLOW) do`)

> A lista de exceções não pode virar tapete: se uma entrada deixou de ter
> ocorrência, ela sai (senão a trava afrouxa sem ninguém notar).

