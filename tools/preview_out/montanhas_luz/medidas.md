# Montanhas: lado da luz pintada × astro, e poça do ato 4

## Medida (`face_esq` × `face_dir`)
Crista lida pelo alfa da `_front`, suavizada; faixa de 18 px logo abaixo da crista; face esquerda = coluna onde a
crista sobe para a direita. Luminância média (0 a 255) da PNG.

| bioma | astro (xr) | face esq | face dir | delta | luz pintada | coerente? | ação |
|---|---|---|---|---|---|---|---|
| fields | sol 0,79 | 151,8 | 202,6 | -50,8 | direita | sim | nenhuma |
| highlands | lua 0,74 | 98,7 | 115,7 | -17,0 | direita | sim | nenhuma |
| abyss | sol pintado 0,655 | 92,9 | 91,0 | +1,9 | contraluz (simétrica) | sim | nenhuma |
| frost | sol 0,80 | 204,6 | 203,1 | +1,6 | frontal (simétrica) | sim | nenhuma |
| marsh | lua 0,72 | sem `_front` | | | árvores em silhueta na névoa, sem encosta | n/a | nenhuma |
| dusk | sol pintado 0,40 | 94,9 | 87,5 | +7,4 | esquerda, contraluz | sim | nenhuma |

A rodada 4 apontou o fields como "iluminado pela esquerda". A medida e o recorte a 4x dizem o contrário: o pico
grande tem a face esquerda azul-ardósia e a direita creme. O que a rodada 4 viu era a cópia ESPELHADA do ladrilho
antigo (corrigida no `dec10052`); com o ladrilho reto a luz pintada já cai do lado do sol (captura
`antes/b1_tod0.65.png`: os dois picos acesos à direita). Nenhuma faixa foi espelhada, então costura, alinhamento
fundo × frente e `celestial.painted` ficam como estão.

## Poça do ato 4
O mapa de luz é só multiplicação: a luz âmbar somada ao ambiente frio satura em branco e só devolve a cor da neve
(azul). A poça lia como clareira pálida (delta +30/+25/+12, R-B +17,6). A cor quente só vem da camada emissiva
aditiva. Motor (genérico): `pool.color` e `pool.emit` opcionais em `LuminaireEngine` (ausentes = como antes).
Frost: lanterna `pool = { radiusK 1,25, intensity 0,45, emit 4,5, color 1,00/0,46/0,12 }` (mapa de luz da poça
mais fraco, emissão mais forte e mais laranja), braseiro `intensity 0,70, emit 2,2`, mesma cor.
Medida em tod 0,85 (`depois/b4_tod0.85.png`): delta +40/+27/+7, R-B +32,5. Folha: `frost_poca_antes_depois_2x.png`.
Em tod 0,65 a poça não acende (`dayK` 0), nada muda. Os montinhos de neve do pé do poste ficam brancos (são do
sprite, desenhados depois da poça).

Arquivos: `antes/` (seis biomas, tod 0,65 e 0,85), `depois/` (fields de controle e frost), `faixa_2x_<n>_<bioma>.png`.
