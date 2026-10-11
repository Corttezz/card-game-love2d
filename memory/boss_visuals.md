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

## Pendente

- Círculo rúnico do lich: em 1024x768 a laje do salão 2 cai atrás da mão de
  cartas (limitação de enquadramento já registrada em
  [[enemy_pose_and_scene_anchor]] §2) — aparece em telas mais altas.
- Ataque com clip próprio só o carrion_king (o resto usa a investida
  procedural).

[[enemy_pose_and_scene_anchor]] · [[enemy_pipeline]] · [[lighting_engine]]
