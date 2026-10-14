---
name: code_notes/tools/test_sim_memory.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_sim_memory.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_sim_memory.lua`

Origem: `tools/test_sim_memory.lua` em `7dbdb60d` (3 de 3 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-21 (junto a `local TK = require("tools.testkit")`)

> tools/test_sim_memory.lua
> Trava de MEMORIA do piloto de balanceamento (tools/autoplay.lua).
>
> O defeito (Out/2026): `love . balance_sim 30 mage` crescia sem parar — 1,4 GB
> em 5 min, 9 GB e travado na run 17 — enquanto a mesma seed num processo novo
> terminava em 22 s. O heap Lua, medido apos collect completo por run, ia de
> 3 MB a 191 MB na 1a run e 525 MB na 2a. Duas causas, ambas do SIMULADOR:
> 1. Singletons de APRESENTACAO (FloatingText, ParticlesManager, ComboBanner,
> OrbRow, CoinBurst) so esvaziam no update deles, que o love.update/HUD
> chama todo frame — e o piloto nunca chama. ~110 mil particulas por run
> ficavam presas, cada uma segurando a carta (e por ela o Game) a que
> estava atada.
> 2. Cada replay da simulacao de deck (evalDeckSim) monta um Game descartavel
> que deixa eventos BLOQUEANTES na fila global do EventManager; eles se
> acumulavam e rodavam por cima da run real.
> O jogo em si ficou limpo: com o piloto corrigido o heap fica em ~6 MB e a
> memoria de textura em ~52 MB por 4 runs seguidas (tools/leak_probe.lua).
>
> Como falha com o defeito presente: sem o dreno, as contagens dos singletons
> passam de zero depois das batalhas; sem o isolamento, a fila da run nao volta
> a ser a mesma tabela/tamanho; o heap cresce dezenas de MB entre as rodadas.

## L47 (em `M.run`, junto a `EM.queues = { base = {}, ui = {} }`)

> fila da run com um marcador: tem que sobreviver intacta aos replays

## L71 (em `evalOnce`, junto a `Autoplay.drainPresentation()`)

> singletons de apresentacao: o dreno do piloto zera todos

