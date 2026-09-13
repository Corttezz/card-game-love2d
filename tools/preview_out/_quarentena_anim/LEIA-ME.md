# Animações reprovadas na inspeção visual (Set/2026)

Estas três NÃO estão em `assets/sprites/icons_anim/` de propósito. As cartas
ficam com o ícone estático, que é o estado seguro — animação quebrada é pior
que animação nenhuma.

Passaram no `check` de md5 ("9 frames, 9 distintos — OK") e foram registradas
como aprovadas na memória. Não estavam. O contact sheet a 3x e 6x
(`tools/preview_out/anim_grid_v2.png` e `anim_zoom_v2.png`) mostra:

- **warrior_eternal_bulwark** — as portas do portão DESAPARECEM no meio do
  loop; frames 4 a 6 são um arco vazio, e voltam a ser sólidas no fim. É um
  "Baluarte Eterno" que se abre sozinho. Mesmo defeito da v1, que o prompt v2
  deveria ter corrigido com "the doors are a solid stone wall that never
  opens".
- **mage_primordial_storm** — os dois orbes de fogo CARBONIZAM: laranja
  brilhante no frame 0, preto/carvão no frame 8. O loop não fecha; a volta é
  um pop de carvão para fogo.
- **mage_radiant_prayer** — o sol migra de amarelo pálido (frame 0) para
  laranja-vermelho saturado (frame 8). Também não fecha o loop, e a amplitude
  de mudança é grande demais para a raridade.

Para regerar: `tools/pixellab_animate_card_icons.py` com `replace_existing=true`.
O vocabulário que funciona está em `memory/card_icon_animation.md` — e a regra
que este diretório existe para lembrar é que **`check` verde é pré-requisito,
nunca aprovação**. Só o contact sheet olhado aprova.
