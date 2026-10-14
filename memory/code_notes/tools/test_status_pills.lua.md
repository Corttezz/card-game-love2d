---
name: code_notes/tools/test_status_pills.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_status_pills.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_status_pills.lua`

Origem: `tools/test_status_pills.lua` em `7dbdb60d` (13 de 27 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-21 (junto a `local TK = require("tools.testkit")`)

> tools/test_status_pills.lua
> Trava dos ESTADOS VISÍVEIS (pills de status do jogador e do inimigo).
>
> POR QUE ESTE TESTE EXISTE
> Set/2026, queixa do dono sobre a carta "Barreira de Fogo": ela reflete dano
> ao defender e o jogador não tinha COMO SABER que estava com reflexo ativo.
> A auditoria achou mais seis estados que mudavam as regras sem nunca aparecer
> na tela (reflexo, roubo de vida, regen, sangria, Bloqueio retido, armadura
> do inimigo e o modo agressivo dele). Este teste cobre:
> 1. a pill APARECE quando o estado existe e SOME quando acaba;
> 2. estado de carta (buff com duração) e de coringa (permanente) somam na
> MESMA pill, e a duração finita vence a variante permanente;
> 3. o tooltip resolve nos 5 idiomas — inspecionando o MÓDULO de cada locale,
> não I18n.t (que cai no en e mascararia chave faltando);
> 4. nada se sobrepõe: a banda de pills é de altura FIXA (contrato que o
> OrbRow usa) e a row cabe na largura em qualquer tamanho de janela;
> 5. todo estado do vocabulário tem cor E ícone de verdade (sem o fallback
> silencioso "?" do PixelIcons — ui_layout_invariants §3).
>
> love . test_one test_status_pills
> love . test_all               (registrado em tools/run_all_tests.lua)

## L33 (em `M`, junto a `local realW, realH = love.graphics.getWidth, love.graphics.getHeight`)

> ===== Janela falsa (memory/ui_layout_invariants.md §2: nunca setMode aqui) =====

## L70-71 (em `M.run`, junto a `p:addBuff("thorn", 2, 7)`)

> Reflexo vindo de CARTA: contrato acertado com o dono do EffectSystem —
> a carta chama player:addBuff("thorn", duration, stacks).

## L97-98 (em `game`, junto a `t:eq("coringa de reflexo NAO vira pill sozinho", byName(list, "thorn"), nil)`)

> Reflexo é ESTADO ARMADO: o joker só vira pill depois de armar o buff
> (senão o mesmo reflexo apareceria somado duas vezes).

## L107-108 (em `game`, junto a `fresh:addBuff("thorn", 1, 4)`)

> Duas fontes de reflexo no mesmo turno (carta + coringa) armam o MESMO
> buff — a pill mostra o total refletido, não duas pills.

## L121 (em `game`, junto a `local ordered = PlayerBuffPills.collect((function()`)

> Ordem canônica: a pill não dança de lugar entre frames.

## L148 (em `e.statusEffects`, junto a `t:eq("collectPills nao muta statusEffects", #e.statusEffects, 1)`)

> Leitura pura: collectPills não pode escrever nada no inimigo.

## L151-152 (em `e.statusEffects`, junto a `e.statusEffects = {`)

> Forward-compat: quando a fúria/armadura virarem status de verdade, o
> statusEffects VENCE e o derivado some — nunca duas pills do mesmo estado.

## L174-177 (em `WITH_PERMANENT`, junto a `for _, code in ipairs(LOCALES) do`)

> (A antiga "convenção" de/es/fr SEM ACENTO caiu em Out/2026: a fonte
> Press Start 2P desenha Latin-1 inteiro — provado caractere a caractere
> por tools/test_locale_glyphs.lua, que é a trava de verdade agora.
> "Zurueck"/"dano"/"defense" liam como erro de digitação pro jogador.)

## L218 (em `keys`, junto a `local noIcon, noColor, ghostIcon = {}, {}, {}`)

> ===== 6. Cor + ícone de verdade pra todo estado do vocabulário =====

## L240-242 (em `keys`, junto a `local okGeom = pcall(function()`)

> ===== 7. Geometria: banda fixa + nada fora da tela =====
> A banda de pills tem altura CONSTANTE, independente de quantas pills
> existem. É esse contrato que deixa o OrbRow empilhar acima sem colidir.

## L287 (em `en.statusEffects`, junto a `local canvas = love.graphics.newCanvas(1024, 768)`)

> ===== 8. Desenho de verdade não quebra (canvas fora da tela) =====

## L307-309 (em `g`, junto a `StatusPill.clearCache()`)

> ===== 9. Estado desconhecido AVISA (nunca cai calado no cinza/'?') =====
> ui_layout_invariants §3. Sem esta trava, um estado novo sem cor/ícone
> desenharia uma bolinha cinza e ninguém saberia por semanas.

