---
name: boss_visuals
description: Visual dos 6 chefes (Out/2026) — idle assado em loop de 12 quadros, passe de arte por regra, aura assinatura (BossAura), contorno de chefe, eixo do corpo do winter_monarch. Como mexer sem reabrir as queixas.
type: project
---

# Visual dos chefes

> "Boss 2 é meio estático flutuando, não intimida. Boss 1 não tem nada de
> especial. Boss 3 está bom. Boss 4 meio torto. Boss 5 melhor mas pode
> melhorar. Boss 6 gostei, mas dá pra pôr mais detalhe de pixel art."
> (dono, Out/2026)

## Diagnóstico (medido, não chutado)

- **Idles antigos = chuvisco.** 4 quadros com 37-46% dos pixels mudando
  entre quadros vizinhos: regeração do PixelLab, não movimento. O lich (6
  quadros assados em Set/2026) mexia 2-4% — e com `bobSpeed 0.55` (ciclo de
  11s) o corpo estava, na prática, parado.
- **No salão o LightEngine não tem lightmap**: os emissivos
  (`enemy_emissives`) não acendem nada lá. Olho/orbe pintado ficava apagado
  justamente onde TODO chefe luta.
- **winter_monarch "torto"**: não é inclinação da arte (cabeça x≈56, cinto
  x≈55, meio das botas x≈58 — vertical). O cajado à esquerda e a capa
  esvoaçando à direita puxavam o centro do BBOX pra x 63.5; centrado por
  bbox, o CORPO caía ~20px de tela à esquerda da porta e da barra de vida.

## O que foi feito

| chefe | idle | arte | aura |
|---|---|---|---|
| carrion_king | 12q @8fps: asas BATEM (rotação no ombro ±10°), peito, talões atrasados; bob na frequência da asa | penas cinza-pardo → brilho azul-violeta de corvo (todos os clips) | 4 corvos rondando (frente/trás), penas, brasas, coração tum-tum, contorno brasa |
| tower_lich | 12q @6fps: abas da capa com atraso, barra, botas pêndulo, tronco respira | — | círculo rúnico no chão, 5 runas na cintura, faíscas no orbe, almas subindo, contorno ciano; bob 2x + deriva |
| abyss_tyrant | 12q @6fps: respiração de fornalha, capa | — | fagulhas, cinza escura (recorta na lava), fumaça rasteira, contorno ESCURO |
| winter_monarch | 12q @6fps: capa tremula, peito | — | redemoinho de neve, sopro gelado, névoa, brilho no cajado; **axisX = 56** |
| rot_colossus | 12q @5fps: fôlego, braços balançam | — | esporos, moscas (asinha clara), gosma pingando até o chão, contorno tóxico |
| eclipse_queen | 12q @5fps: asas abrem/fecham, barra ondula | capa vira céu noturno (dobras, estrelas, barra violeta), luz na borda da membrana | disco do eclipse com coroa de raios, pétalas, brilho correndo na asa, contorno magenta |

## Onde mora

- `tools/bake_boss_idle.py` — idle por DESLOCAMENTO a partir do quadro 0
  (deriva zero; quadro 0 = base = o mesmo do hurt/death). Regiões em px do
  canvas, `lag` por movimento (pano atrasado = movimento secundário), loop
  fechado (não ping-pong). **Região tem que passar da borda** (amostragem
  inversa: cobre onde o pano CHEGA).
- `tools/boss_art_pass.py` — detalhe por REGRA de cor/vizinhança, vale em
  todos os clips + `south.png`. Rodar UMA vez sobre a arte original (a
  rainha não é idempotente); depois `bake_boss_idle.py run <id>`.
- `src/data/enemy_poses.lua` — `idle = { fps, cycle = true }`, `drift`,
  `axisX`.
- `src/data/boss_auras.lua` (dados) + `src/ui/BossAura.lua` (motor) —
  chamado só pelo `EnemyRenderer` com `enemy.isBoss`. Camadas: `rim`,
  `glows`, `orbit(s)`, `emit`, `floor`, `corona`, `glint`.
- Prova visual: `love . test_one shot_boss_aura all` (ou `2:death`,
  `1:hurt`) → `boss_aura_<ato>.png` + `boss_full_<ato>.png`.
- Trava: `love . test_one test_boss_visuals`.

## Regras aprendidas

1. **Efeito em pixel da ARTE, e em bloco legível.** Chefe a ~2x na tela tem
   pixel da arte de ~2px; partícula de 1 bloco era cisco invisível. `px = 2`
   (corvo `px = 3`) continua múltiplo inteiro da grade do sprite.
2. **Contraste com a SALA, não com o vazio.** Corvo preto sumia na parede
   escura (ganhou reflexo violeta e corpo cinza-violeta); fagulha laranja some
   na lava (o tirano ganhou cinza escura e contorno escuro); luz aditiva some
   no feixe branco da sala 6 (coroa do eclipse em mistura normal).
3. **`SpriteAnimation:draw` reseta a cor pra branco** — cor de silhueta vai
   como `tint`, nunca por `setColor` antes de várias chamadas.
4. Emissor que depende do chão (gota) pousa no UPDATE com o chão medido no
   último draw — pousar no draw quebra quando há vários updates por draw.

## Revisão combinada (Out/2026)

- Corvo de asa de 1 pixel com ponta clara lia como "risquinhos roxos
  soltos". Virou silhueta de pássaro de frente ("m", 9x5, corpo de 3px, asa
  de 2px, 3 quadros) desenhada a partir de máscara ASCII em `BossAura`
  (`parseShape`). Pena = diagonal de 3px que tomba; pétala = gota 2x2.
  **Partícula que é um traço reto de 2-3px lê como glitch, não como coisa.**
- A sala 6 ganhou um eclipse pintado na abertura do fundo: o disco da aura
  saiu (`corona.disc = false`), fica só uma coroa curta de raios na cabeça.
  Uma cena, um eclipse.

## Rodada 2 do dono (Out/2026)

- **Contorno colorido SAIU** de todos ("a arte já tem o contorno dela").
  Brilhos ficaram só pequenos (raio <= 8 px da arte; maior lê como bola de
  luz). `test_boss_visuals` trava os dois.
- **Natural > mecânico.** Emissor com intervalo FIXO (acumulador) virou
  chegada de Poisson; rajada com ±35%; órbitas com raio/velocidade/fase por
  corpo (exceto `regular = true`, runas); balanço com frequência própria.
- Colosso: moscas viraram ENXAME de agentes (alvo sorteado, aceleração
  limitada, tremido perpendicular — `swarm`); gosma `ooze` nasce em pontos
  PINTADOS (lábio, garras), forma → estica → cai com gravidade → espirra uma
  vez; esporos raros, lentos, foscos.
- Pés dos apoiados: a capa que balança passava rente às botas e a borda
  macia arrastava pixel do pé — `TYRANT_FEET`/`MONARCH_FEET` excluídos no
  bake (pé idêntico ao quadro 0 em todos os quadros).

## Queda na morte (Out/2026)

Quem voa (`pose = "floating"`), quando morre, CAI: `poseSink = (t/FALL_DUR)²`
(0.42s; reducedMotion 0.18s sem quique), quique curto + poeira no impacto, e
a margem de pé passa a ser a do QUADRO da death com o mesmo `FOOT_SINK` de
quem pisa — o cadáver repousa com o pixel mais baixo 2px dentro da linha de
chão que a cena passou (salão: scene_anchors; estrada: getRoadAnchor) e fica.
A descida linear antiga (0.7s) usava a margem do 1º quadro da death e sem
afundar: o corpo deitado terminava acima do chão. Trava `test_enemy_fall`
(todo flutuante × 6 salões × 3 tamanhos + estrada × 3 escalas de palco);
prova `SHOT_SIZE=1920x1080 love . test_one shot_boss_aura 2:death`.

**Chão do cadáver ≠ chão do vivo.** No salão 2 a linha do vivo (0.83) é a
faixa estreita colada na base da balaustrada; o lich morto deitado ali lia
"em cima do parapeito". `scene_anchors.deathYr` (só hall 2: 0.885, meio do
mosaico) → `GameplayScene` passa `opts.deathCy` → o flutuante escorrega a
linha de chão de cy pra deathCy junto da queda (cai pra frente). Como esse
chão fica abaixo do topo da mão, a MÃO DESCE e sai da tela quando o inimigo
morre nesse caso (`corpseUnderHand`). Demais salões e estrada: sem deathYr.

## Pendente

- Círculo rúnico do lich: em 1024x768 a laje do salão 2 cai atrás da mão de
  cartas (limitação de enquadramento já registrada em
  [[enemy_pose_and_scene_anchor]] §2) — aparece em telas mais altas.
- Ataque com clip próprio só o carrion_king (o resto usa a investida
  procedural).

[[enemy_pose_and_scene_anchor]] · [[enemy_pipeline]] · [[lighting_engine]]
