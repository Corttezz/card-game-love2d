---
name: art_direction_diorama
description: Direção de arte do dono para TODO prop do cenário (árvores, arbustos, pedras, prédios, objetos): cada sprite é um pequeno diorama em pixel art com volume, camadas, oclusão e sombra na direção da luz do bioma, nunca textura plana
type: feedback
---

Pedido do dono (18/Out/2026), texto dele resumido: corrigir a sensação de que árvores, vegetação e objetos estão presos num plano 2D. "Trate cada sprite como um pequeno diorama em pixel art, com volumes sobrepostos, e não como uma textura plana."

**Regras por sprite (no nível do pixel):**
- Copa em três planos (frente, meio, fundo), avançando e recuando no espaço; nunca uma massa uniforme.
- Grupos de folhas com tamanhos, alturas e valores de luz diferentes.
- Folhas à frente cobrem parcialmente galhos e tronco.
- Sombra pontilhada e irregular das folhas no tronco, nas folhas de baixo e no chão.
- Contorno seletivo: frente definida e contrastada; fundo da copa mais escuro, mais suave, menos contraste.
- Tronco, galhos e raízes com espessura: face iluminada e face em sombra.
- Mesma paleta limitada, mesma escala de pixel, mesmo estilo: nada de vetor, pintura lisa ou 3D realista.
- Vale igual para arbustos, pedras, prédios, landmarks e objetos: leitura de massa, camadas, oclusão e sombra coerentes com a luz global do bioma (`celestial.xr` em `src/data/biomes.lua`: sol/lua à direita na maioria dos biomas).

**Why:** o dono olhou o ato 1 com as árvores novas e disse que elas ainda parecem sprites planos colados lado a lado; quer o mundo "profundo e habitável".

**How to apply:** todo prompt de arte nova (PixelLab) carrega estas regras em inglês e a direção da luz do bioma; toda revisão de arte existente julga o PNG a 1:1 e 4x contra esta lista antes de aprovar; folha de candidatas sempre com antes|candidatas lado a lado no tamanho real da cena. Ver `memory/worldroad_scene.md` "Integração ao terreno".
