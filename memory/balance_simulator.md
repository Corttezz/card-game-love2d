---
name: Simulador de balanceamento — memória e isolamento
description: Por que balance_sim/autoplay vazava até 9 GB numa bateria longa (singletons de FX que só esvaziam no update por frame + eventos de replays na fila global) e as regras pra rodar o jogo headless em loop sem vazar. Sonda tools/leak_probe.lua, trava test_sim_memory.
type: project
---

# Simulador de balanceamento — memória e isolamento

`love . balance_sim N classe seed` (tools/balance_sim.lua + tools/autoplay.lua +
tools/balance_ai.lua) joga runs inteiras em sequência no MESMO processo, sem
desenhar e sem `love.update`. Out/2026: o processo crescia sem parar (330 MB em
15 s → 2,4 GB em 6 min; 9 GB e travado na run 17 de 30), enquanto a mesma seed
num processo novo terminava em 22 s.

## Causa (era do SIMULADOR, não do jogo)

Medido com `love . leak_probe 4 mage 500000` (heap após `collect` completo +
censo do grafo alcançável por run): heap Lua 3 MB → 191 MB na 1ª run → 525 MB na
2ª. O censo apontou só tabelas de módulo de **apresentação**:

| raiz | entradas após 2 runs |
|---|---|
| `engine.ParticlesManager` `instances` | ~110 mil (cada partícula atada a uma carta → segura a carta → segura o Game) |
| `src.ui.FloatingText` `active` | ~90 mil |
| `src.ui.OrbRow` `outbound` | ~25 mil |
| `src.ui.ComboBanner` `queue` | ~14 mil |
| `EventManager.queues.base` | ~2,3 mil eventos `after` BLOQUEANTES (Card.lua materialize/dissolve, Game:drawCard) |

1. Esses singletons só esvaziam no `update()` deles, que no jogo o
   `love.update` (FloatingText, CardParticles, CoinBurst) e o HUD da batalha
   (ComboBanner, OrbRow) chamam todo frame. O piloto nunca chama.
2. `evalDeckSim` (escolha de carta por simulação, piloto v6) roda ~4 replays por
   decisão, cada um num `Game:new()` descartável. Eles deixavam eventos na fila
   GLOBAL do EventManager. Como `after` é bloqueante por padrão, o resto
   serializava, a fila crescia (e a varredura O(n) por tick deixava tudo mais
   lento) e os eventos dos Games mortos **rodavam por cima da run real e dos
   replays seguintes**. Isso também enviesava a medição: com o defeito, o mesmo
   `evalDeckSim` devolvia perda 34,8 contra 14,75 isolado.

O jogo saiu limpo: com o piloto corrigido o heap fica em ~6 MB e a textura em ~52
MB (24-26 canvases, imagens carregadas sob demanda até ~236) por 4 runs seguidas.
No jogo, FloatingText/partículas são tickados no `love.update` global e
ComboBanner/OrbRow só recebem entradas durante o combate, onde também são
tickados, então não acumulam.

### Segunda causa: desenho sem `present()` (memória NATIVA)

Com o heap já em ~6 MB, a 1ª bateria de 30 runs terminou inteira, mas o working
set ainda oscilava entre 170 MB e 1,3 GB. Amostrando o próprio processo via FFI
(`K32GetProcessMemoryInfo`) no meio da run: heap Lua < 16 MB e textura < 53 MB
o tempo todo, enquanto o WS subia em DEGRAUS (196 → 228 → 293 MB). O único
desenho da bateria era a `ComboBanner`, que pré-renderiza um canvas por combo
(~250-350 por run, contando os replays). Com `ComboBanner.show` desligado o WS
ficou plano em 168 MB por 3 runs, e o resultado das runs foi idêntico. Soltar
os canvases com `:release()` NÃO mudou nada. A leitura é que, como a bateria
nunca apresenta frame, o driver de GL segura os comandos de desenho fora da tela
e solta quando quer. O jogo chama `present()` todo frame, então ficou intocado.
Correção: `balance_sim.setup` desliga `ComboBanner.show`, como já fazia com
`CardFrame.render`.

## Correção (tools/autoplay.lua)

- `drainPresentation()` (exposto como `Autoplay.drainPresentation`): limpa
  FloatingText, CardParticles/ParticlesManager, ComboBanner, OrbRow
  (`OrbRow.clear()` novo) e CoinBurst. Chamado no começo de todo `pump` e
  depois de cada replay. Nenhuma regra do jogo lê esses singletons.
- `evalDeckSim`: cada replay ganha `EventManager.queues = {base={}, ui={}}`
  novas, e as filas da run voltam (a MESMA tabela) no fim.
- `playRun`: `EventManager.clear()` + dreno antes de montar o Game da run nova.

## Regras pra quem rodar o jogo headless em loop

- **Todo singleton que só esvazia em `update()` precisa ser tickado ou limpo
  pelo harness.** Sem `love.update`, "efeito que some sozinho" nunca some.
- **Harness sem render não desenha em canvas.** Sem `love.graphics.present`
  o desenho fora da tela acumula memória nativa que nem o heap Lua nem
  `getStats().texturememory` mostram. Stube quem pré-renderiza
  (`CardFrame.render`, `ComboBanner.show`) e meça o WORKING SET do processo,
  não só o heap.
- **Game descartável = filas descartáveis.** O EventManager é global: um replay
  ou uma simulação que monta outro Game precisa trocar `EventManager.queues` e
  devolver as originais, senão vaza memória e contamina a medição.
- Pra medir: `love . leak_probe [runs] [classe] [seed] [v6|v5]` grava em
  `<save dir>/leak_probe.log` com flush por linha (heap, textura, canvases,
  filas por origem do evento, diff do censo do grafo, criação de objetos
  gráficos por origem). `LEAK_MIDRUN=1` amostra no meio da run (heap sem
  collect + WS/privado do processo via FFI + pico de heap com traceback). `LEAK_CENSUS=0` desliga o
  censo (que custa alguns segundos num heap grande).
- Trava: `love . test_one test_sim_memory` (fila da run intacta após replays,
  heap estável entre rodadas, singletons vazios após o dreno). Ficou vermelho
  com a correção revertida (4 falhas).

## Observação em aberto (jogo, não é vazamento)

Na run real do piloto a fila `base` ainda acumula algumas centenas de eventos
durante a run (`Card:start_materialize`/`start_dissolve` e `Game:drawCard` usam
`em.after`, que é BLOQUEANTE, para timers cosméticos). No jogo isso serializa a
materialização da mão: 5 compras somam ~2,5 s de fila bloqueada. Esvazia em tempo
real, então não vaza, mas é ritmo visual acoplado à fila do combate. Ver
[[eventmanager_queues]].

Ligações: [[eventmanager_queues]], [[particles_unified]], [[defect_doctrine]].
