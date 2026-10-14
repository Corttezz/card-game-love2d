---
name: code_notes/tools/sheet.lua
description: Comentários com decisão/regra/histórico colhidos de tools/sheet.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/sheet.lua`

Origem: `tools/sheet.lua` em `7dbdb60d` (2 de 3 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-23 (junto a `local M = {}`)

> tools/sheet.lua
> Monta um CONTACT SHEET de PNGs numa tira horizontal (ou grade), pra olhar
> frames de animação e variações de arte lado a lado.
>
> Existe porque validar arte aqui SEMPRE foi feito com um script Python + PIL,
> e em Set/2026 o Python da máquina quebrou no meio da sessão (o interpretador
> principal perdeu o .exe e o do launcher não tem pip). A validação visual é
> parte do processo — "olhar o PNG antes de aprovar" é regra do projeto — e
> não pode depender de um runtime externo quando o jogo já tem tudo o que
> precisa pra desenhar.
>
> Uso:
> love . sheet <dir> [escala] [saida.png]
> love . sheet assets/sprites/world/anim/abyss_castle_door 3
> love . sheet assets/sprites/icons_anim/warrior_taunt 4 taunt.png
>
> love . sheet <a.png,b.png,c.png> [escala] [saida.png]
> compara arquivos soltos, na ordem dada
>
> Saída no diretório de save (o mesmo dos outros tools). Fundo escuro de
> propósito: quase todo asset do jogo é desenhado sobre fundo escuro, e
> validar sobre branco já enganou uma leva inteira de ícones (ver
> memory/ui_rendering.md).

## L88-89 (em `M.run`, junto a `local x = (i - 1) * cw + (cw - e.img:getWidth() * escala) / 2`)

> centraliza e apoia no BASE da célula: frames de tamanhos
> diferentes ficam alinhados pelo pé, como na tela.

