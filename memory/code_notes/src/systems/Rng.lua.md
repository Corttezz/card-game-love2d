---
name: code_notes/src/systems/Rng.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/Rng.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/Rng.lua`

Origem: `src/systems/Rng.lua` em `7dbdb60d` (10 de 14 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-25 (junto a `local Rng = {}`)

> src/systems/Rng.lua
> RNG seedável da run com streams separados por categoria (padrão Slay the
> Spire: 1 seed → N geradores independentes; sortear uma carta nunca muda o
> resultado do próximo mapa). Ver memory/sts_progression_config.md.
>
> Diferença pro StS: lá o save guarda `counter` e reconstrói com fast-forward;
> aqui o RandomGenerator do LÖVE expõe getState()/setState() (string), então o
> save restaura o ESTADO EXATO. O contador fica só como telemetria/debug.
>
> Uso:
> local Rng = require("src.systems.Rng")
> Rng.setActive(Rng.new())            -- nova run (RunManager faz isso)
> local r = Rng.get()                 -- qualquer sistema de run
> r:random("card")                    -- float [0,1)
> r:random("card", 6)                 -- int [1,6]
> r:random("card", 2, 5)              -- int [2,5]
> r:pick("shop", lista)               -- elemento aleatório
> r:getState() / Rng.fromState(state) -- serialização pro save
>
> `meta` é uma tabela livre serializada junto (pity de raridade etc.) — o
> estado "psicológico" do RNG viaja com ele.
>
> IMPORTANTE: streams são só pra DECISÕES de run (ofertas, mapa, eventos).
> Efeito visual (partícula, jiggle, smoke) continua em love.math.random —
> poluir os streams com rolls cosméticos quebraria a reprodutibilidade.

## L30-31 (em `Rng`, junto a `Rng.STREAMS = { "card", "shop", "map", "event", "enemy", "misc" }`)

> Streams canônicos. Novos streams: adicionar AQUI (ordem importa pro offset
> de seed por stream — mudar a ordem muda todas as runs futuras, não as salvas).

## L34-36 (em `Rng.STREAMS`, junto a `local active = nil`)

> Instância ativa da run (padrão do projeto pra sistemas globais, cf.
> _G.EventManager). nil fora de run — Rng.get() cria efêmera sob demanda
> (classic mode/testes funcionam sem seed persistida).

## L43-44 (em `Rng.generateSeed`, junto a `local t = (love and love.timer and love.timer.getTime and love.timer.getTime()) or os.clock()`)

> Entropia do RNG global do LÖVE (auto-seedado no boot) + relógio.
> Só usado pra CRIAR seeds — nunca em decisões de run.

## L65-66 (em `self.meta`, junto a `function Rng.fromState(state)`)

> Reconstrói de um estado salvo. Tolerante a estado parcial (stream novo que
> não existia no save nasce da seed; contador ausente vira 0).

## L93 (em `states`, junto a `local counters = {}`)

> Cópia rasa dos counters (o save serializa a referência; evitar aliasing).

## L107-108 (em `Rng:_gen`, junto a `Rng._warnedStream = Rng._warnedStream or {}`)

> Stream desconhecido é bug de chamada — avisa (uma vez por nome) e
> cai no misc pra não crashar gameplay (mas o log denuncia).

## L121-124 (em `Rng:_gen`, junto a `function Rng:random(stream, m, n)`)

> Mesma assinatura de love.math.random:
> random(stream)        → float [0,1)
> random(stream, m)     → int [1,m]
> random(stream, m, n)  → int [m,n]

## L141-142 (em `Rng:pick`, junto a `function Rng:weighted(stream, entries)`)

> Roll ponderado: recebe { {item=..., weight=N}, ... } e retorna o item.
> Ordem da lista é respeitada (determinístico por seed — nunca usar pairs).

## L156-158 (em `Rng:weighted`, junto a `function Rng:getStreamState(stream)`)

> Estado de UM stream (retrato pontual: "o stream X estava aqui"). Usado
> pra luta retomada sortear exatamente o que a original sorteou, mesmo que
> outro código tenha consumido o stream no meio do caminho.

