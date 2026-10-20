# Postes por ato depois de 00320ab2 (20/Out/2026, frente revisao-cenas)

Capturas 1920x1080 (`lovec . test_one revisao_cenas <ato>`, tag `postes`): encruzilhada tod 0,30/0,85 e B 0,65, chegada a loja/fogueira/evento, batalha 0,65/0,85 e elite 0,85. Folhas `atoN_postes.jpg` com cada poste visível a 1:1 (x2/x3 nos de fundo). Nenhum código de poste foi mexido.

| Ato | Base no chão | Sombra | Luz no fim do dia | Escala | Veredito |
|---|---|---|---|---|---|
| 1 campos | pé na grama, fora da estrada | contato leve; projetada não aparece (sol à frente da câmera, já documentado) | lanterna acesa, poça fraca | poste perto (t 0,82) = 576 px, ~2x o inimigo e pixel ~6x | ver item A |
| 2 terras altas | pedestal na grama, poça azul no chão | ok | ok | idem (567 px) | ver item A |
| 3 abismo | pedra-base na terra | ok | chama viva | idem (559 a 573 px) | pedra-base cinza esverdeada, fria contra a terra marrom (item B) |
| 4 gelo | monte de neve no pé, poça âmbar na neve | ok | ok | idem (576 px) | ok fora do item A |
| 5 pântano | pé na grama; não cobre mais os landmarks na chegada | ok | lanterna verde | idem (610 px) | ok fora do item A |
| 6 crepúsculo | pé na grama | ok | ok | idem (572 px) | ok fora do item A |

**A. Poste perto da câmera na batalha (todos os atos):** em t 0,82 o poste mede 560 a 610 px contra ~290 px do inimigo, com a lanterna a ~6x de escala (blocos visíveis). A regra de densidade de pixel (`PropCut.PIX`, teto 2x o pixel do inimigo) não parece valer para ele depois da volta dos postes; ocupa o terço direito do quadro de batalha.

**B. Ato 3:** a pedra-base da tocha tem tons verde-oliva frios; na terra queimada marrom lê levemente colada. Recolorir para basalto marrom-avermelhado do bioma resolveria.

Fora isso: nenhum poste na estrada, nenhum na frente das opções, nenhum cobrindo landmark na chegada, todos acesos no fim do dia.
