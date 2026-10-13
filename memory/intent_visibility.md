---
name: intent_visibility
description: Out/2026. Névoa de intenção — nos biomas frost (ato 4) e dusk (ato 6) e em criaturas com `veil`, o HUD esconde o NÚMERO (type_only, "?") ou o TIPO (hidden) do intent; o golpe segue CONGELADO. Camada geral Enemy.intentVisibility (full|type_only|hidden) resolvida por anúncio no stream "misc"; contadores reveal_intent (4 cartas) + pulso do Raio; o WeatherEngine engrossa a nevasca pelo estado; pilotos leem getKnownIntent.
type: project
---

# Névoa de intenção (Out/2026)

**Ideia do dono:** nos biomas do fim da jornada a nevasca / a bruma esconde
parte do que o inimigo anuncia. O jogador vê o TIPO do golpe (espada, escudo,
punho) mas não o NÚMERO; na névoa fechada nem o tipo. Lê como o mundo (a
nevasca fecha quando o número some), não como um interruptor de UI.

## Onde mora

| peça | arquivo |
|---|---|
| dados por bioma (base/peak/heavy/hall/cor + worldBoost) | `src/data/intent_fog.lua` |
| camada geral (níveis, curva, contexto, resolução, hook do clima) | `src/systems/IntentVisibility.lua` |
| véu por criatura / fase | campo `veil = { level, chance }` em `src/data/enemies.lua` (frost_wight 1.0, rime_shaman 0.5, dusk_shade 0.7, eclipse_queen fase 2 hidden 0.5) |
| resolução no anúncio + API | `Enemy:refreshIntentVisibility / getIntentVisibility / veilSpec / revealIntent / revealNextIntent / getKnownIntent / getKnownIncomingDamage` |
| contexto do bioma no inimigo | `RunModifiers.decorateEnemy` (único ponto por onde todo inimigo de run passa: batalha nova e Continuar) |
| HUD | `EnemyHud.intentSpec` (visibility, "?", tooltip da névoa) + `src/ui/IntentVeil.lua` (bruma pixel sobre o box, aro pisca ao revelar) |
| clima | `WeatherEngine.fogHook` → `veilBoost()` soma à intensidade e à tempestade (persegue o alvo em ~0,7 s); `reset()` zera |
| contadores | efeito `reveal_intent` (EffectSystem.processEffectCard) em warrior_spot_weakness, rogue_expose_weakness, mage_arcane_sight, effect_scroll_wisdom; pulso do orbe de RAIO → `revealNextIntent(1)` |
| tutorial | conversa `fog` (Tutorial.SCRIPT, latch = número escondido na vez do jogador) + `script.fog.{veil,counter}` nos 5 locales |
| textos | `enemy_kit.intent.veil_*` / `unknown_value`, `status.intent_unknown`, `effects.reveal_intent`, `messages.intent_revealed` |
| trava | `tools/test_intent_visibility.lua` (223 asserções) |
| captura | `ENEMY_SCENE_VIRTUAL=1920x1080 ENEMY_SCENE_ID=frost_wolf ENEMY_SCENE_MOVE=lunge ENEMY_SCENE_VISIBILITY=type_only\|hidden\|full[:veil] love . screenshot_enemy_scene 4_battle` (imprime intensidade/boost do clima) |

## Regras que não podem quebrar

- **O intent continua CONGELADO** (CLAUDE.md §6). `intentHitDamage` /
  `getIncomingDamage` não sabem que a névoa existe; a trava executa um turno
  com intent `hidden` e exige dano == número congelado.
- **Decidido UMA vez por anúncio** (`Enemy:rollIntent` → `refreshIntentVisibility`)
  e guardado em `enemy.intentVisibility` + `intentVeilCause` ("fog" | "veil" |
  "reveal"). Nunca pisca durante a decisão do jogador.
- **Stream "misc"**: a rolagem só acontece quando há névoa ou véu
  probabilístico; o stream "enemy" fica intocado (atos 1-3 e toda seed já
  medida pelo piloto continuam idênticos). A mesma seed reproduz a sequência.
- **Combinação = o PIOR nível** (`IntentVisibility.worst`); revelação vence
  tudo e consome um turno da contagem (`_revealTurns`).
- **Nenhum número escondido vaza**: `intentSpec` zera `value`, troca o texto
  por "?" (type_only) ou tira texto/extras (hidden); tooltip vira
  veil_number / veil_all (+ veil_enemy com o nome da criatura quando a causa
  é véu, + veil_hint). `getKnownIntent` devolve só kind/pierce/charge/nomes
  de debuff (type_only) ou `{kind="unknown"}` (hidden).
- **O mundo acompanha o estado, não o contrário.** O relógio do clima é
  visual; a regra é a rolagem. `worldBoost` (0.45 / 0.75) soma à intensidade
  do WeatherEngine quando o inimigo ATIVO (último que resolveu) está vivo,
  fora do salão e encoberto. Salão não tem clima do domo (a bruma do
  InteriorFX é da frente chefes-visual).
- **Densidade pela chegada ao castelo**: `base` no andar 1, `peak` no andar
  8, pela MESMA curva do clima (`fogCurve` == `WeatherEngine.intensityFor`,
  copiada porque este módulo roda sem motor gráfico; a trava exige igualdade).
  Salão = `hall` fixo. Endless cicla 4,5,6,1,2,3 como o EnemyRoster.

## Pilotos

**DECISÃO usa o conhecido, MEDIÇÃO usa o real** (combinado com a frente
sim-instant, Out/2026). `AI.knownThreat(enemy, player)` em `tools/balance_ai.lua`
é a fonte única do golpe "como o jogador o vê" ({ perHit, hits, pierce, armor,
known }): full = números congelados; type_only = tipo conhecido, dano estimado
pela média do kit (`expectedDamagePerTurn`, 1 golpe) ou 0 pra defesa/buff/cura,
bloqueio padrão se o tipo é defender, perfurante segue conhecido; hidden = média
do kit, sem perfurante nem bloqueio. Quem usa: `AI.simulate` (busca v6) e
`autoplay.chooseBatch` (`incoming`, emergência, planDefense). O diário do turno
imprime "?" quando `getKnownIncomingDamage` é nil. O bloco `diag` do autoplay
(cobriu/furou, `incSum`) e o `stateSignature` da paridade continuam com
`getIncomingDamage`/`getIntent` reais — são métrica de regra, não de visão.
Trava em `test_intent_visibility` §9 (API + knownThreat + fonte do autoplay).
As baselines de `memory/balance_curves.md` foram medidas SEM névoa: o commit
dos pilotos é a fronteira se o A4/A6 mudar.

## Afinar

- Mais/menos névoa: `src/data/intent_fog.lua` (`base`/`peak`/`heavy`/`hall`).
  Ligar outro bioma = nova entrada (o teste cobra bioma real).
- Criatura que se esconde: `veil = { level, chance }` no kit ou na fase.
- Véu mais/menos opaco: `IntentVeil.ALPHA`.
- Clima mais/menos fechado: `worldBoost` no data.

Ver também: [[enemies]] · [[weather_engine]] · [[combat_beats]] · [[onboarding]].
