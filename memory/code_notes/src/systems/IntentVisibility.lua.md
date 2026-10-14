---
name: code_notes/src/systems/IntentVisibility.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/IntentVisibility.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/IntentVisibility.lua`

Origem: `src/systems/IntentVisibility.lua` em `7dbdb60d` (14 de 21 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-33 (junto a `local IntentVisibility = {}`)

> src/systems/IntentVisibility.lua
> ============================================================================
> VISIBILIDADE DO INTENT — névoa do bioma + véu do inimigo + revelações
> ============================================================================
> Ideia do dono (Out/2026): nos biomas do fim da jornada a nevasca esconde
> parte do que o inimigo anuncia. Isto é a camada GERAL que decide, a cada
> anúncio de intent, quanto o HUD pode mostrar:
>
> "full"       tudo (como sempre foi)
> "type_only"  o ÍCONE do golpe aparece, o NÚMERO vira "?"
> "hidden"     nem o tipo: ícone de desconhecido + "A névoa esconde a intenção"
>
> Três fontes, combinadas pelo PIOR nível (menor), e uma que vence tudo:
> 1. NÉVOA DO BIOMA  (src/data/intent_fog.lua, por bioma; rolada por turno)
> 2. VÉU DO INIMIGO  (campo `veil` do kit ou da fase, src/data/enemies.lua)
> 3. REVELAÇÃO       (carta/efeito `reveal_intent`, pulso do orbe de Raio):
> força "full" neste turno e nos N seguintes.
>
> INVARIANTES
> * O intent continua CONGELADO no anúncio (CLAUDE.md §6). Esta camada só
> muda o que se MOSTRA; `Enemy:intentHitDamage` não sabe que ela existe.
> * Decidido UMA vez por anúncio (`Enemy:rollIntent`) e guardado em
> `enemy.intentVisibility`: nunca pisca durante a decisão do jogador.
> * A rolagem usa o stream "misc" do Rng (a seed reproduz; "enemy" ficou
> intocado pra não deslocar os golpes já medidos pelo piloto).
> * O mundo ACOMPANHA o estado, não o contrário: o WeatherEngine lê
> `worldFog()` e engrossa a nevasca quando o número some. O relógio do
> clima é visual, por isso não pode ser a regra.
>
> Quem usa: Enemy (resolve), EnemyHud/IntentVeil (desenho), EffectSystem
> (reveal), RunModifiers.decorateEnemy (contexto do bioma), pilotos
> (`Enemy:getKnownIntent` — não podem espiar). Ver memory/intent_visibility.md.
> ============================================================================

## L51-55 (em `IntentVisibility.worst`, junto a `local function smooth(a, b, x)`)

> Curva da névoa: a MESMA do clima na tela (WeatherEngine.intensityFor).
> Copiada aqui de propósito — este módulo roda sem o motor gráfico (pilotos,
> testes); test_intent_visibility exige que as duas batam.

## L64-65 (em `IntentVisibility.fogCurve`, junto a `function IntentVisibility.biomeIdFor(run)`)

> Bioma (id de src/data/biomes.lua) do ato da run — mesmo wrap do endless que
> EnemyRoster.biomeAct / WorldRoad.rawBiome usam (4,5,6,1,2,3,...).

## L79 (em `IntentVisibility.biomeIdFor`, junto a `function IntentVisibility.ruleFor(biomeId)`)

> Regra do bioma (nil = céu limpo).

## L84-87 (em `IntentVisibility.ruleFor`, junto a `function IntentVisibility.contextFor(run, nodeType)`)

> Contexto de névoa de UMA batalha. nil quando o bioma não tem névoa — o
> inimigo então nem rola (atos 1-3 ficam idênticos ao que eram).
> progress  0..1 pela chegada ao castelo (andar 1 → 8), igual ao clima
> hall      chefe luta no salão: bruma do interior, densidade fixa

## L101-103 (em `ctx`, junto a `function IntentVisibility.stormCurve(ctx)`)

> Quanto do "pico" da nevasca o contexto tem (0..1): a MESMA janela do
> stormFor do WeatherEngine (tempestade só no trecho final do ato). Salão =
> pico cheio. Multiplica a fração `heavy` (tipo escondido).

## L110-111 (em `IntentVisibility.stormCurve`, junto a `function IntentVisibility.expectedShares(ctx)`)

> Fração esperada de anúncios por nível num contexto (analítico, pro
> relatório e pra trava): { full, type_only, hidden }.

## L119-120 (em `IntentVisibility.expectedShares`, junto a `IntentVisibility.FOG_THRESHOLD = FogData.fogThreshold or 0.3`)

> Bruma de tela "visível" (WeatherEngine.renderedFog >= isto) — fonte única
> com a trava.

## L130-131 (em `IntentVisibility.density`, junto a `local n = (k - 0.12) / 0.88`)

> a curva começa em 0.12 (céu quase limpo) e chega a 1: normaliza pra que
> `base` seja exatamente o 1º andar e `peak` a porta do castelo

## L136-141 (em `IntentVisibility.density`, junto a `function IntentVisibility.resolve(enemy, roll)`)

> Resolução por anúncio
>
> `roll` = função que devolve [0,1) (padrão: Rng stream "misc"). Só é chamada
> quando há o que sortear — sem névoa e sem véu probabilístico o Rng não anda.
> Devolve (nível, causa) com causa ∈ "fog" | "veil" | "reveal" | nil.

## L161-162 (em `IntentVisibility.resolve`, junto a `local heavy = (rule.heavy or 0) * IntentVisibility.stormCurve(ctx)`)

> o TIPO só some no pico da nevasca (curva de tempestade do
> clima; salão = pico): "subjetivo, não cego"

## L192-198 (em `IntentVisibility.reset`, junto a `local function fogOf(e, wantHall)`)

> 0..1 de névoa EXTRA que o mundo deve mostrar agora. Zero fora de luta, com
> o inimigo morto ou com o número à mostra. Dois consumidores, um por cena:
> worldFog  → WeatherEngine (estrada: nevasca + bruma de tela)
> hallFog   → InteriorFX (salão do chefe: névoa do chão + camada na frente
> do chefe, hook de chefes-visual-3, e37a148)
> Cada um só responde na SUA cena, para o outro motor não puxar névoa de
> um estado que não é dele.

## L209-210 (em `IntentVisibility.hallFog`, junto a `local VEIL_DEFAULT = { 0.62, 0.52, 0.72 }`)

> Cor do véu desenhado sobre o intent (tinta do bioma; véu do inimigo sem
> bioma de névoa usa violeta neutro).

## L218-219 (em `IntentVisibility.veilColor`, junto a `do`)

> Instala o hook no motor de clima (sem ciclo: o WeatherEngine não conhece
> src/). Fora do LÖVE gráfico (pilotos) o require pode falhar — tudo bem.

