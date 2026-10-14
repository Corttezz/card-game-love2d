---
name: code_notes/src/systems/CardFeel.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/CardFeel.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/CardFeel.lua`

Origem: `src/systems/CardFeel.lua` em `7dbdb60d` (7 de 12 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-18 (junto a `local Sfx = require("src.systems.Sfx")`)

> src/systems/CardFeel.lua
> Identidade AUDIOVISUAL por tema de carta (game feel v1, Jul/2026).
> Inspiração: StS (cada golpe tem VFX no inimigo) + Balatro (cada evento soa).
>
> Toda carta resolve pra um TEMA via tags (TagSystem): elementos primeiro
> (fire/ice/lightning/dark/holy/magic), depois mecânicas (poison/heal/lifesteal).
> Cada tema define: SFX de impacto + paleta de partículas + física (gravity:
> fogo sobe, gelo cai, veneno borbulha). Sem tema → fallback do tipo
> (swordSound/armorSound), que continua sendo a identidade "física".
>
> USO (CombatSequence / Game / EffectSystem):
> CardFeel.themeOf(card)                 -- "fire" | ... | nil
> CardFeel.playImpact(card, pitch)       -- true se tocou som temático
> CardFeel.burst(theme, x, y, k)         -- burst de partículas na posição
> CardFeel.burstAtEnemy(theme, k)        -- burst no sprite do inimigo
> CardFeel.burstAtPlayer(theme, k)       -- burst no painel do jogador
>
> Headless-safe: Sfx é no-op sem áudio; partículas só spawnam se love.graphics.

## L25-29 (em `CardFeel`, junto a `CardFeel.THEMES = {`)

> ============================================================================
> CATÁLOGO DE TEMAS
> colours: paleta do burst | gravity: px/s² (neg = sobe) | speed/count: energia
> sfx: código registrado em main.lua (audio/sfx/impact-*.mp3, ElevenLabs)
> ============================================================================

## L64-65 (em `colours`, junto a `local RESOLVE_ORDER = {`)

> Ordem de resolução: elemento define a identidade antes da mecânica
> (Bola de Fogo com poison secundário SOA fogo; o veneno aparece no debuff).

## L92-94 (em `CardFeel.themeOf`, junto a `function CardFeel.playImpact(card, pitch)`)

> ============================================================================
> SOM
> ============================================================================

## L96-97 (em `CardFeel.themeOf`, junto a `function CardFeel.playImpact(card, pitch)`)

> Toca o SFX de impacto do tema da carta. Retorna true se havia tema com som
> (caller usa fallback físico sword/armor quando false).

## L106-108 (em `CardFeel.playImpact`, junto a `function CardFeel.burst(theme, x, y, k)`)

> ============================================================================
> PARTÍCULAS
> ============================================================================

## L139-140 (em `CardFeel.burstAtEnemy`, junto a `function CardFeel.burstAtPlayer(theme, k)`)

> Burst no painel do jogador (canto inferior-esquerdo, mesmo âncora dos
> FloatingText de dano recebido em Game:enemyTurn).

