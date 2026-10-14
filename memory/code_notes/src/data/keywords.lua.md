---
name: code_notes/src/data/keywords.lua
description: Comentários com decisão/regra/histórico colhidos de src/data/keywords.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/data/keywords.lua`

Origem: `src/data/keywords.lua` em `7dbdb60d` (4 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-13 (junto a `local ORB_CTX = {`)

> src/data/keywords.lua
> Glossário de keywords (F5 do gameplay-overhaul-v1): detectadas na
> descrição da carta e explicadas no tooltip (CardInfoDisplay) — resolve
> "orbs jamais explicados" e ensina as regras novas (bloqueio zera,
> exaurir remove da batalha). Ordem = prioridade (máx 3 por tooltip).
>
> Out/2026: o glossário era PORTUGUÊS em todos os idiomas (nome/texto
> cravados aqui). Agora este arquivo guarda só a ESTRUTURA — id, grupo e as
> palavras que disparam o verbete, POR LOCALE, do jeito que aparecem na
> descrição TRADUZIDA (minúsculas, com acento). Nome e texto exibidos vêm do
> i18n: `keyword.<id>.name` / `keyword.<id>.text` nos 5 locales.
> Trava: love . test_one test_locale_accents (cada verbete casa a própria
> carta-exemplo em cada idioma).

## L15-16 (junto a `local ORB_CTX = {`)

> Contexto de orbe: "fogo" sozinho não é orbe de Fogo — a descrição precisa
> falar de canalizar/evocar/orbe/valor junto.

## L26-32 (em `de`, junto a `{ id = "orb_lightning", group = "orb", requires = ORB_CTX,`)

> ===== ORBES: verbete POR ELEMENTO (feedback Jul/2026: "explicacao
> apenas da orbe que tem relacao com a carta, nao de todas"). Todos no
> group="orb": o primeiro que casar EXCLUI os demais do grupo — carta
> de Fogo explica so o orbe de Fogo; o generico e fallback pra cartas
> de orbe sem elemento (Evocar, Dualcast). Semantica canonica:
> EffectSystem.orbPulseValue/orbEvokeValue (pulso no fim do SEU turno,
> evocar = efeito cheio).

## L61 (em `fr`, junto a `{ id = "retain",`)

> Rebalance v2 (Jul/2026): "retenção" — desc do Escudo Templário usa o termo

