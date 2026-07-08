---
name: card_creation_flow
description: Fluxo OBRIGATÓRIO e completo para criar qualquer carta nova (regra do dono, Jul/2026)
type: project
---

# Fluxo completo de criação de carta (OBRIGATÓRIO)

**Regra do dono (Jul/2026): NENHUMA carta entra no jogo pela metade.**
Toda carta nova passa por TODOS os passos abaixo, na ordem. Criar só os
dados (como aconteceu com as 17 do gameplay-overhaul antes da cobrança)
é considerado incompleto.

1. **Dados** em `src/data/cards/<classe>.lua`: id, name (PT), type, cost,
   attack/defense, rarity, `class` COERENTE com o arquétipo da classe
   (warrior=strike/armor/strength, mage=channel/magic, rogue=poison/strike/
   finisher), tags do `TagSystem.CATALOG`, effects de
   `PROCESSED_EFFECT_TYPES`, descrição = CONTRATO do comportamento.
2. **Ilustração única 64×64** via `tools/pixellab_generate_new_cards.py`
   (queue em ondas + poll; contrato de estilo em
   memory/sprite_design_queue.md) → `assets/sprites/icons/<card_id>.png`.
   REVISAR em contact sheet com os olhos; re-gerar as que erraram o tema.
3. **Atlas visual** em `src/data/card_art.lua`: icon = card_id, bg pattern,
   accent da classe (MOSS=poison, PURPLE=arcano, ATTACK/ORANGE=warrior),
   decoration. Acento tem que existir na Palette (GREEN não existe; é MOSS
   ou GREEN_BRIGHT).
4. **Traduções ×5** em `src/i18n/locales/{pt_BR,en,es,fr,de}.lua` na tabela
   `cards`: name + desc (o nome DENTRO da carta via CardFrame e FORA via
   tooltips/loja usam I18n.cardName/cardDesc).
5. **Preview visual**: adicionar em `tools/preview_cards.lua` →
   `love . preview_cards` → conferir moldura/custo/footer com Read.
6. **Validação**: `love . validate_cards` + `love . smoke_all`.
7. Tag nova → entra ANTES no `TagSystem.CATALOG`; effect novo → implementar
   no EffectSystem + registrar em PROCESSED_EFFECT_TYPES do validador.
8. Se possível, rodar `love . autoplay 2 all` — o piloto valida se a carta
   entra nos decks e como performa.

Gerador pronto: `python3 tools/pixellab_generate_new_cards.py queue|poll`
(adicionar as cartas novas no dict CARDS com prompt temático).
