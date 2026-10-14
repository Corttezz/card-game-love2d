---
name: code_notes/tools/balance_sim.lua
description: Comentários com decisão/regra/histórico colhidos de tools/balance_sim.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/balance_sim.lua`

Origem: `tools/balance_sim.lua` em `7dbdb60d` (21 de 29 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-45 (junto a `local M = {}`)

> tools/balance_sim.lua
> BATERIA DE BALANCEAMENTO (Out/2026): muitas runs seedadas por classe pelo
> piloto (tools/autoplay.lua + tools/balance_ai.lua) e um relatorio
> AGREGADO — winrate por classe, onde se morre e contra o que, impacto de
> cada carta e coringa.
>
> love . balance_sim [runsPorClasse] [classes] [seedBase] [piloto]
> classes   = all | warrior | mage | rogue | warrior,rogue
> piloto    = expert (padrao) | expert_fast | average | naive | expert_full
> (v5/v6/v6b/v6c legados continuam valendo)
> ex: love . balance_sim 40 all 500000 average
>
> Saida: console + arquivo (BALANCE_OUT, padrao balance_sim_report.md no save
> dir). Com BALANCE_OUT apontando pra um caminho do projeto, grava la.
> BALANCE_JSON=<arquivo>: grava TODOS os registros de run em JSON (uma
> lista) — e o que tools/balance.py junta de varios processos.
>
> RELOGIO: por padrao a bateria roda no relogio INSTANTANEO
> (tools/instant_engine.lua — fila drenada por saltos, mesma regra, paridade
> travada em test_instant_parity). BALANCE_CLOCK=frames volta ao avanco por
> quadros (1/30 s) do piloto original.
>
> KNOBS de A/B sem editar o jogo (lidos no setup; o sweep de
> tools/balance_tune.py usa todos):
> BALANCE_ENEMY_POWER="dano,vida"    Config.Game.ENEMY_POWER (ex: "0.8,0.85")
> BALANCE_BOSS_HP=<mult>             vida de chefe e mini-chefe (ex: 1.15)
> BALANCE_COMBO="volley=3:3,wall=5"  `step[:cap]` das regras de combo por id
> BALANCE_COMBO_JOKER=<mult>         multiplicador dos coringas de combo (combo_boost)
> BALANCE_ENEMY_POWER_ACT="2:0.9,0.9;3:0.85,0.85"  Config.Game.ENEMY_POWER_BY_ACT (ato:dano,vida)
> BALANCE_BOSS_HP_ID="tower_lich=0.8" multiplica o hpMul do kit (chefe/criatura por id)
> BALANCE_MAGE_FOCUS=<n> / BALANCE_ROGUE_POISON=<n>  Game.MAGE_FOCUS_OFFSET / ROGUE_POISON_OFFSET
> BALANCE_PLAYER_HP=<n>              vida inicial do jogador
> BALANCE_HAND=<n> / BALANCE_MANA=<n>  mao+compra por turno / mana maxima
> BALANCE_SEAL=<n> / BALANCE_ENDLESS=<n>   selo da run / andares de endless
> BALANCE_SHOP_SALE=0 | 1[:pct]      oferta do dia (Config.Offers.DAILY_SALE, ligada por padrao): 0 desliga, 1[:pct] liga/ajusta
>
> O CATALOGO INTEIRO e medido: se o UnlockSystem (frente de progressao)
> existir, a bateria liga o override "tudo desbloqueado" — senao a amostra
> mediria so as cartas iniciais e o veredito de forca seria de outro jogo.
>
> Metodo do IMPACTO de carta (o vies obvio e "quem vai mais longe compra mais
> cartas"): compara so runs VIVAS num mesmo andar de corte. Para cada carta,
> entre as runs que chegaram ao andar F, separa quem a tinha adquirido ATE F
> de quem nao tinha e compara vitoria e profundidade final. F = 9 (fim do A1)
> e F = 17 (fim do A2).

## L71-73 (em `writeOut`, junto a `local CUTS = { 9, 17 }`)

> ============================================================
> Agregacao
> ============================================================

## L181-182 (em `classes`, junto a `p("## Combate por ato (todas as classes)")`)

> Ritmo do combate (kit dos inimigos, Out/2026): turnos por luta, dano
> SOFRIDO por turno (tensao) e duracao das lutas de chefe, por ato.

## L207-209 (em `acts`, junto a `p("")`)

> JOGADAS (Out/2026, combo-clareza): o tamanho da leva e quanto do valor
> das cartas veio de COMBO. "Spam" = muitas cartas por leva + combo
> carregando o dano.

## L304-306 (em `pr`, junto a `p("")`)

> ECONOMIA (Out/2026): renda e gasto por ato, ouro na porta da loja e o
> alcance da bancada extra de coringa. Medias sobre as runs que CHEGARAM
> ao ato (quem morreu no A2 nao puxa a media do A4 pra zero).

## L365-366 (em `parts`, junto a `local endl = {}`)

> ENDLESS (BALANCE_ENDLESS=N): ate onde os vencedores chegam depois da
> vitoria — o ciclo em que a curva exponencial encerra a corrida.

## L417-419 (em `jl`, junto a `function M.setup(policy)`)

> ============================================================
> Entrada
> ============================================================

## L421-422 (em `jl`, junto a `function M.setup(policy)`)

> Prepara o processo pra bateria (tambem usado por tools/leak_probe.lua).
> Devolve o modulo do piloto pronto.

## L424-425 (em `M.setup`, junto a `require("tools.headless_window").hide()`)

> CARDGAME_HEADLESS=1: janela 1x1 fora da tela (conf.lua) + escondida da
> barra de tarefas (tools/headless_window.lua). Primeiro de tudo.

## L433-440 (em `M.setup`, junto a `M._saved = M._saved or {}`)

> A bateria nao desenha nada: a moldura procedural de cada carta (um
> canvas por instancia, refeito a cada replay da simulacao de deck)
> era o maior custo de CPU e de memoria. Uma moldura unica compartilhada
> mantem largura/altura validas pra geometria do CombatSequence.
> Os originais ficam guardados pra M.teardown(): as suites que chamam
> setup() (test_instant_parity, test_balance_pipeline) rodam no MESMO
> processo que as seguintes, e um render que nunca enche o cache do
> CardFrame vazava pra elas (test_class_select flake, Out/2026).

## L448-452 (em `CardFrame.render`, junto a `local ComboBanner = require("src.ui.ComboBanner")`)

> A faixa de combo pre-renderiza um canvas por combo anunciado. Sem
> love.graphics.present (a bateria nunca apresenta frame), o driver
> acumulava esses comandos de desenho e o processo crescia em degraus de
> dezenas de MB por run ate passar de 1 GB — com o heap Lua em ~10 MB.
> Medido: com a faixa desligada o working set fica plano entre runs.

## L458-461 (em `ComboBanner.show`, junto a `local ep = os.getenv("BALANCE_ENEMY_POWER")`)

> TURBO (BALANCE_TURBO=1): relogio em passos de 0,1s e beats do combate
> 4x mais curtos. So muda QUANTAS vezes a fila e bombeada, nao a regra.
> A/B rapido da forca do inimigo sem editar o Config:
> BALANCE_ENEMY_POWER="dano,vida" (ex: "0.72,0.8")

## L487 (em `AS.getEnemyStats`, junto a `local combo = os.getenv("BALANCE_COMBO")`)

> BALANCE_COMBO="volley=1:2,wall=1:2,pair=3" — step[:cap] por regra

## L501-502 (em `AS.getEnemyStats`, junto a `local cj = tonumber(os.getenv("BALANCE_COMBO_JOKER") or "")`)

> BALANCE_COMBO_JOKER=<mult>: os coringas de combo (combo_boost) passam
> a valer este multiplicador em vez do da carta (ComboSystem.boostFor).

## L533-534 (em `t`, junto a `local mf = tonumber(os.getenv("BALANCE_MAGE_FOCUS") or "")`)

> BALANCE_MAGE_FOCUS / BALANCE_ROGUE_POISON: deslocamento das passivas
> que crescem com a run (Game.MAGE_FOCUS_OFFSET / ROGUE_POISON_OFFSET).

## L547-548 (em `t`, junto a `local hand = tonumber(os.getenv("BALANCE_HAND") or "")`)

> BALANCE_HAND=<n>: mao inicial = compra por turno (sao o mesmo numero
> por design); BALANCE_MANA=<n>: mana maxima do jogador.

## L558-562 (em `t`, junto a `do`)

> wip/sustain (Out/2026): as 3 propostas de sustento, cada uma por flag.
> BALANCE_REST_HEAL=0.4 (fogueira), BALANCE_POTIONS=1 (poção de elite),
> BALANCE_ELITE_RAMP=1 (vida da elite cresce com o andar),
> BALANCE_SUSTAIN=1[:bonus] (vaga de sustento em elite/chefe + peso
> extra pra sustento com < 2 fontes; bonus default 1.0).

## L580-581 (em `t`, junto a `local ss = os.getenv("BALANCE_SHOP_SALE")`)

> Loja v3 F4: BALANCE_SHOP_SALE=0 desliga a oferta do dia (ligada
> por padrao desde 13/Out); 1[:pct] liga/ajusta o desconto.

## L604-605 (em `t`, junto a `function M.teardown()`)

> Desfaz os stubs de setup() (CardFrame.render, ComboBanner.show) — pra suite
> que roda outros testes depois no mesmo processo. Idempotente.

## L614-616 (em `M.teardown`, junto a `local function writeJson(records, meta)`)

> Grava os registros em JSON (BALANCE_JSON). Cada registro e o `runRec` do
> piloto: resultado, morte, batalhas (battleLog), dano por fonte, deck,
> coringas, ofertas/aquisicoes, forjas, compras, economia por ato.

## L645-647 (em `classes`, junto a `pcall(function() io.stdout:setvbuf("line") end)`)

> silencia o print do jogo durante a bateria (milhares de toasts por run
> deixavam a bateria lenta e o log ilegivel); o resumo por run sai aqui.
> progresso visivel em bateria longa (stdout em arquivo e bufferizado)

