---
name: code_notes/src/ui/Palette.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/Palette.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/Palette.lua`

Origem: `src/ui/Palette.lua` em `7dbdb60d` (11 de 69 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-6 (junto a `local Palette = {}`)

> src/ui/Palette.lua
> Paleta 16 cores fixa, derivada da "DR-Darkworld Neon" (Deltarune Dark World, Lospec)
> estendida com 4 tons ultra-escuros para fundos.
> Regra: TODA cor do jogo sai daqui. Nunca hardcode RGB em arquivos novos.
>
> Formato: {R, G, B, A} em 0..1 (formato LÖVE).

## L39-41 (em `hex`, junto a `Palette.PARCHMENT_LIGHT = hex("#e8d5a0")   -- pergaminho claro (highlights do papel)`)

> ===== GRIMOIRE SEPIA (nova direção visual estilo pergaminho envelhecido) =====
> Usadas pelo novo CardFrame (src/ui/card/). As cores acima ficam para
> retrocompatibilidade e para overlays neon opcionais.

## L56-59 (em `hex`, junto a `Palette.TOAST_DANGER = hex("#ff6e5c")   -- dano, perigo, erro`)

> ===== Avisos do combate (MessageSystem) =====
> Texto colorido por TIPO com contorno de tinta, sem placa (dono, Out/2026:
> "cores diferentes como era antes"). Claros o bastante pra ler sobre o
> cenário iluminado; o contorno INK separa do fundo.

## L61 (em `hex`, junto a `Palette.TOAST_WARN   = hex("#ffa851")`)

> aviso de regra (bloqueio no teto, fúria)

## L67-71 (em `hex`, junto a `Palette.ARCANE_INK      = hex("#120c1a")   -- tinta arcana (fundo da faixa)`)

> ===== ACENTO DE COMBO (ComboBanner) =====
> Violeta arcano: precisa ser lido EM UM PISCAR como "coisa diferente" ao
> lado do ouro (turno do jogador) e do sangue (turno do inimigo) do
> TurnBanner. Fica na familia da tinta cara do grimorio (pigmento de
> purpura), nao no neon legado.

## L76-81 (em `hex`, junto a `Palette.MANA_DEEP  = hex("#232c40")   -- faceta inferior (sombra da gema)`)

> ===== Gema de mana (CardCostBadge) — lápis-lazúli ENVELHECIDO.
> Feedback do dono (Jul/2026): a 1ª versão usava o azul vivo do ManaOrb e
> "gritava" sobre o pergaminho — a carta é relíquia, a gema também tem que
> ser. Tons dessaturados na família do STEEL (#4a5260), só um fio mais
> azuis pra ainda ler como mana. A FORMA (losango facetado + engaste ouro)
> é a aprovada — mexer só nas cores.

## L94-96 (em `hex`, junto a `Palette.TEXT         = Palette.CYAN_PALE`)

> ===== Aliases semânticos (direcionados ao grimório) =====
> UI states: continua compatível com DR-Darkworld,
> mas o Card compositor usa os aliases grimoire abaixo.

## L120 (em `hex`, junto a `Palette.SUCCESS = Palette.GREEN_BRIGHT`)

> Status feedback

## L126-127 (em `hex`, junto a `Palette.BUTTON_FILL             = Palette.PARCHMENT_DARK`)

> ===== UI Chrome (botões, painéis, modais pixelados) =====
> Estados semânticos — sempre referenciar por nome, não hardcodar cor no Button.

## L149-150 (em `hex`, junto a `Palette.INDEXED = {`)

> Retorna a cor por índice numérico (uso interno dos bitmaps de ícone).
> Convenção no PixelIcons: 0 = transparente.

## L177 (em `Palette.byIndex`, junto a `function Palette.set(color, alphaOverride)`)

> Aplica cor ao love.graphics (helper para evitar unpack manual).

