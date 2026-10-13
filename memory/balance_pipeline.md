---
name: Pipeline de balanceamento instantânea (relógio por saltos, pilotos, bateria paralela, sweep)
description: Out/2026. Como medir o jogo em minutos — tools/instant_engine.lua (mesma regra do jogo, fila drenada por saltos, paridade travada por teste), pilotos naive/average/expert como PERFIL em tools/autoplay.lua, `python tools/balance.py` (todos os cores, JSON + Markdown em reports/balance/), `tools/balance_tune.py` (sweep de knobs contra as bandas de memory/sts_difficulty_targets.md). Throughput medido, o que cada piloto representa, armadilhas.
type: project
---

# Pipeline de balanceamento (Out/2026)

Pedido do dono: *"como controlamos tudo, podemos deixar tudo INSTANTÂNEO…
simular número de cartas no deck, sinergias, coringas, forja, escolhas de
loja… montar a pipeline perfeita"*. Antes: `balance_sim` jogava 1 run em
~160 s (relógio de quadros a 1/30 s + ~900 batalhas rejogadas pela
simulação de deck). Agora: 270 runs dos pilotos rápidos em **28 s de parede**
nos 16 cores; o expert com simulação de deck em ~20–35 s de CPU por run.

## As peças

| peça | arquivo | o que faz |
|---|---|---|
| relógio instantâneo | `tools/instant_engine.lua` | `pump(game, secs)` do piloto vira `drain(game)`: `EventManager.update(DT=1,0)` + `EnemyRenderer/Enemy/CombatSequence.update` em loop até a fila esvaziar e `isBlocking()` cair. **Mesma regra**: mesmos beats, mesma ordem causal — só o tempo de espera morreu. `Autoplay.pumpImpl` plugável; `install/uninstall`. |
| paridade | `tools/test_instant_parity.lua` | joga as mesmas seeds pelo relógio de quadros (speed 1,0) e pelo instantâneo; exige traço IDÊNTICO turno a turno (vida/escudo/mana dos dois lados, intent, status, buffs, orbes, mão em ordem, ouro, **estado exato dos 6 streams do Rng**) e mesmo resultado. 361 turnos / 6 runs / 3 classes iguais na primeira rodada. |
| pilotos | `tools/autoplay.lua` (`M.PILOTS`, `M.setPilot`) | perfil = dado: `combat` (naive/steps/search), `build` (greedy/v5/heuristic/sim), `path`, `shop`, `rest`, `event`, `bench`, `buildMargin`, `simPerFight`, `simCandidates`. Nomes legados v5/v6/v6b/v6c mapeiam pra perfis. |
| registro por run | `runRec` (autoplay) → JSON (`BALANCE_JSON`, `tools/jsonlite.lua`) | resultado, morte (ato/andar/nó/inimigo), `battleLog` (uma linha por batalha: inimigo, turnos, vida perdida, deck no início, dano por fonte), `dmg`/`dmgParts` (livro de dano), `deckByBattle`, `forges`, `purchases`, economia por ato, ofertas/aquisições, coringas, `cpuSeconds`. |
| bateria paralela | `tools/balance.py` | `python tools/balance.py --runs 200 --classes all --pilots naive,average,expert_fast --seeds 1000 --seal 0` → N processos `lovec . balance_sim n classe seed piloto` (um bloco contíguo de seeds cada, `CARDGAME_IDENTITY` próprio), junta os JSON, escreve `reports/balance/<label>/report.md` + `results.json` + `records.json`. Substitui `tools/balance_par.py`. |
| relatório | `tools/balance_report.py` | winrate com IC 95% (Wilson) por classe×piloto×selo; mortes por ato/nó/inimigo; turnos e vida perdida por luta por ato (e por piloto); dano por fonte (carta/orbe/magia/DoT/espinhos) e composição da carta (base/efeitos/Força/combo/coringa/edição/debuff, via `DamagePreview.cardValue` — fonte única da conta); deck ao longo da run; poder de carta (vivas no corte, com × sem, mesma classe); taxa de escolha; coringas (lift); forja; compras; **duração estimada em minutos** (constantes à vista no topo do arquivo — é estimativa, calibrar com telemetria). Re-renderiza: `python tools/balance_report.py reports/balance/<label>/records.json`. |
| sweep | `tools/balance_tune.py` + `tools/balance_targets.json` | grade de knobs (`--enemy-power d,h` · `--boss-hp m` · `--combo volley=3,wall=5` · `--player-hp n`) × bateria paralela; pontua a distância das taxas de vitória por piloto às bandas-alvo ([[sts_difficulty_targets]]); imprime as melhores configurações. **Não altera o jogo** — entrega números pro dono dos números. |
| knobs no `balance_sim.setup` | `tools/balance_sim.lua` | `BALANCE_ENEMY_POWER`, `BALANCE_BOSS_HP` (wrap de `ActSystem.getEnemyStats` só em boss/mini), `BALANCE_COMBO` (`RULE_BY_ID[id].step`), `BALANCE_PLAYER_HP`, `BALANCE_SEAL`, `BALANCE_ENDLESS`, `BALANCE_CLOCK=frames` (volta ao relógio de quadros), `BALANCE_PILOT`. Cada knob AVISA o valor aplicado. |

## Os pilotos (o que cada um representa)

| piloto | combate | deck | caminho / loja / descanso / evento | custo CPU por run | representa |
|---|---|---|---|---|---|
| **naive** | joga o que cabe na mana, ATAQUE primeiro, ignora o intent | pega SEMPRE uma carta (a mais rara) | ao acaso (RNG próprio seedado) / compra na ordem da vitrine / sempre descansa / 1ª opção pagável; coringa fica como chegou | ~0,3 s | quem abriu o jogo pela primeira vez |
| **average** | passos v5 (lethal > cura > emergência > dano > defesa contra o golpe anunciado) | raridade + afinidade + arquétipo; só pula com deck > 18 e carta comum | heurística / política de caixa + serviços / cura abaixo de 60% senão forja / valor esperado | ~0,4–0,7 s | jogador que entende intent e defesa mas "pega sempre algo" |
| **expert_fast** | busca v6 sobre os subconjuntos da mão (`balance_ai`) | `AI.wantsCard` com margem ×2 (entra quem melhora a média do deck) | idem average + bancada otimizada | ~0,6–0,9 s | expert sem a simulação de deck — pra baterias grandes e sweep |
| **expert** | busca v6 | **simulação**: joga as 2 próximas lutas (chefe do ato + comum) com e sem a carta, 1 replay cada, só as 2 melhores candidatas da heurística + pular (`SIM_PER_FIGHT=1`, `SIM_CANDIDATES=2`; `expert_full` = v6 original com 4 replays e todas as candidatas) | ~17–35 s | o jogador que SENTE o deck inchar |

Sanidade travada em `tools/test_balance_pipeline.lua` por **batalhas iguais**
(retratos de uma run rejogados por cada piloto, mesma seed, vida cheia — o
banco do `balance_bench`): naive perde mais vida que expert_fast; average não
perde mais que naive. Winrate de poucas runs é sorteio, não sanidade.

## Throughput medido (12/Out/2026, i7 16 threads)

| o quê | antes | agora |
|---|---|---|
| 1 run do piloto v6/expert (seed 720001, guerreiro) | 160 s (relógio de quadros) · 72 s (TURBO) | **17 s** (instant + pré-filtro + 1 replay) |
| 1 run average / expert_fast / naive | — | 0,6 s / 0,6–0,9 s / 0,3 s |
| bateria 30 runs × 3 classes × {naive, average, expert_fast} | — | **28 s de parede** (9,7 runs/s na parede, ~2 runs/s/core) |
| bateria 8 runs × 3 classes × expert | — | 2,7 min de parede com 8 processos (0,15 runs/s) |

A meta de "≥ 20 runs/s por core" **não foi atingida**: o relógio deixou de
ser o custo (parity test: quadros 2,8 s × instantâneo 1,7 s para 72 batalhas
curtas); o que resta é o CÉREBRO — `AI.simulate` a ~29 µs × ~60 subconjuntos
por decisão, `Game:nextPhase` a ~11 ms por batalha (instancia o deck inteiro
+ inimigo) e, no expert, as ~280 batalhas rejogadas pela simulação de deck.
Próximos levers se precisar de mais: memoizar `AI.simulate` por assinatura de
subconjunto, reaproveitar instâncias de carta entre replays, e podar a
enumeração da mão acima de 9 cartas.

## O que a primeira bateria ensinou (ver [[sts_difficulty_targets]] §5)

Só o `expert` (deck por simulação) vence (25%, n=24, deck final 10–13).
`average`/`expert_fast`/`naive` ficam em 0–7% com decks de 15–19 cartas e
morrem no A2–A3 (`tower_lich` sozinho = 62 das 270 mortes). A alavanca que
separa os pilotos é o TAMANHO DO DECK — informação pra frente de números, não
pra pipeline. O sweep (`balance_tune.py`, grade `--enemy-power 0.65,0.75`
etc.) mostrou que baixar o inimigo move pouco os pilotos heurísticos: o custo
de inchar o deck é que precisa de atenção.

## Armadilhas (medidas)

- **DT do relógio instantâneo tem teto**: `pushUntil` (investida do inimigo)
  soma `dt` ao `timer` ANTES de testar a condição; DT ≥ 2,5 s expiraria o beat
  por timeout antes do apex e o golpe cairia fora de ordem (depois dos
  espinhos, do veneno, do upkeep que zera o escudo). DT = 1,0 s: apex em 0,34 s
  na primeira `EnemyRenderer.update`, condição fecha na iteração seguinte.
- **Escolha "aleatória" do piloto NUNCA usa `love.math.random`**: cosméticos
  consomem dele por quadro, então o relógio de quadros e o instantâneo
  divergiriam. `M._pilotRng = love.math.newRandomGenerator(seed)`.
- **O livro de dano lê o RÓTULO do beat** (wrap de `CombatBeats.push`) pra
  saber de onde veio o `Enemy:takeDamage` (`orb.*`, `effect.magic_damage`,
  `player.thorn_reflect`, `card.impact.*`); DoT passa por `_applyDot`. Soma
  do livro == vida tirada do inimigo em toda batalha (trava).
- **Forja é por cópia**: o registro de forjas embrulha `upgradeCardAt` na
  instância do RunManager (o `upgradeCard(id)` legado delega pra ele).
- Herdado de [[balance_simulator]]: drenar FX singletons a cada pump, filas
  próprias por replay, `CardFrame.render`/`ComboBanner.show` stubados.
- Blocos de bateria com `CARDGAME_IDENTITY` próprio: saves `*.tool.lua`
  isolados; o save do jogador nunca é tocado.
- **Zero janela visível** (requisito do dono: "várias janelas do Grimoire"
  apareciam durante as baterias). `CARDGAME_HEADLESS=1` → `conf.lua` cria a
  janela 1×1, sem borda, em (−32000, −32000); `tools/headless_window.lua`
  (chamado no `balance_sim.setup`) troca o título por um único e esconde a
  própria janela via FFI `user32.ShowWindow(SW_HIDE)` — some da barra de
  tarefas. Esconder de FORA (balance.py/ctypes) e `love.window.minimize()` no
  load NÃO funcionam: o SDL re-mostra a janela se o hide chega antes do fim
  da criação (medido com user32 `IsWindowVisible`). Não dá pra
  `t.window = nil`: o jogo cria canvas/imagens, que exigem contexto gráfico.
  `balance.py` seta o env; `love . balance_sim` direto aceita o env também.
  **Solução real, ainda não feita:** `t.window = nil` + `t.modules.graphics =
  false` sob o env, com o caminho headless do jogo sem tocar em
  `love.graphics` (CardDatabase/CardFrame criam canvas por carta,
  ImageCache/IconLoader carregam PNG, CombatSequence lê `getWidth`,
  `balance_sim.setup` cria o canvas compartilhado). É refactor de guardas em
  ~6 módulos; até lá a janela 1×1 escondida é o que garante "zero visível".
- **Processos registrados e limitados**: `balance.py` usa por padrão
  `cores − 2` processos e grava `reports/balance/<label>/pids.txt` (o seu
  PID + cada `lovec`). Parar uma bateria = matar ESSES PIDs, nunca por nome
  (o `love.exe .` do dono pode estar aberto).

## Comandos

```
love . test_one test_instant_parity          # paridade quadros × instantâneo (PARITY_BATTLES/SEEDS pra ir mais fundo)
love . test_one test_balance_pipeline        # pilotos, determinismo, throughput, registro
love . balance_sim 20 warrior 720000 average # um processo, relógio instantâneo por padrão
python tools/balance.py --runs 60 --pilots naive,average,expert_fast      # ~1 min
python tools/balance.py --runs 20 --pilots expert --procs 16              # ~3-5 min
python tools/balance_tune.py --runs 30 --pilots average,expert_fast --enemy-power 0.8,0.85 0.7,0.8 --boss-hp 1.0 1.15
python tools/balance_report.py reports/balance/<label>/records.json       # re-renderiza
```

Ver [[sts_difficulty_targets]] (bandas), [[balance_curves]] (números atuais),
[[combo_rules]], [[enemies]], [[balance_simulator]], [[multi_agent_git]].
