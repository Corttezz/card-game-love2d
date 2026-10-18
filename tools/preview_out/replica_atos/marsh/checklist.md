# Pântano da Podridão (marsh, ato 5): checklist (18/Out/2026, frente replica-45)

Capturas: `antes/` (main `ed2484f1`) e `depois/`, grade de 12 (`b5_*`), batalha 1080p em tod 0,65 e 0,95,
régua em `*/escala/` (com e sem sombra). Recortes antes|depois em `recortes/`. Candidatas de árvore em `arte/`
(1ª coluna = `marsh_deadtree_0` de referência).

As árvores novas mudam o sorteio da parede (8 variantes em vez de 3), então os recortes de árvore comparam
a mesma região da tela, não a mesma árvore. Os postes caem no mesmo lugar nos dois.

## Lista fixa do plano (Tarefa 10)

| # | pergunta | resposta | evidência |
|---|---|---|---|
| 1 | Temperatura única esverdeada; lanterna verde contrasta | **Sim.** Grade só matiz (dia 0,96/1/0,92, pôr 0,90/0,98/0,90; o pôr 0,60/0,72/0,58 escurecia tudo). A lanterna continua o verde mais vivo da cena. | `recortes/01_poste_meio_tod95.png` |
| 2 | Horizonte lavado pela névoa oliva, sem degrau | **Sim.** `fogCurve` 1,5 → 2,0 (névoa no fundo), `fogFar` 0,48, `fogDusk` mais escura. | `recortes/06_crista_castelo.png` |
| 3 | Contato esverdeado escuro, não preto | **Sim.** `shadowTint` verde; sombra de multiplicação 0,34/0,40/0,32 (verde-musgo). | `recortes/03_base_poste_sombra_tod65.png` |
| 4 | Tufos densos e altos (0,12 a 0,15, máx 7) | **Sim**, 0,13 / 4 a 7 (intocado). | `recortes/09_loja_encruzilhada_dia.png` |
| 5 | Névoa baixa espessa e lenta (0,26 a 0,32) | **Sim**, 0,28 (intocado). | `depois/b5_por_viagem.png` |
| 6 | Arbustos balançam mais que as árvores mortas | **Sim**, `bushSway` 0,050 > `canopySway` 0,028. | dado |
| 7 | A chuva fina continua lendo contra o chão | **Sim**: riscos visíveis sobre a grama nas batalhas e na viagem. | `depois/batalha_1080p_tod95.png` |

## As 9 lições do dono

| # | lição | resposta | evidência |
|---|---|---|---|
| 1 | Sombra natural, nítida, 3 degraus, nascendo da base | **Sim.** `alphaK` 1,0 → 2,0, `fade` 0,30, árvore ×1,45 com `lenK` 0,95 (2ª rodada: com 0,70 a sombra caía embaixo da própria árvore e o lead não a via), disco de copa 0,50. As sombras das árvores do meio agora aparecem na grama (antes: nenhuma); diff com `ESCALA_NOSHADOW=1` sem sombra sobre o inimigo nem sobre o poste. | `recortes/04_arvores_meio_esq.png`, `depois/escala/b5_tod65_nosh.png` |
| 2 | Árvore nunca mais clara/enevoada que a grama ao lado | **Sim.** `treeDepth.lift` 0,25 (curva do chão, névoa crua); as árvores do meio ficam mais escuras que a grama vizinha. | `recortes/04`, `05` |
| 3 | Escala contra o inimigo | **Sim.** Poste 0,85× (t 0,09) e 0,86× (t 0,53) o inimigo na mesma profundidade; árvore adulta acima do poste; castelo 247 px = 2,1× a maior árvore da crista. Totem 3,4 (~0,43×) é um marco baixo, não poste. | `objetos.md` |
| 4 | Árvores não todas iguais | **Corrigido.** 3 → 8 variantes (`marsh_deadtree_3..7`: inclinada com cortina de musgo, cipreste com raízes-joelho, tronco partido, tronco em forquilha, tronco com nó inchado), `variants.marsh_deadtree = 8`, `makeWall` não repete vizinha. | `arte/candidatas_arvores_*.png`, `recortes/05_arvores_meio_dir.png`, `14` |
| 5 | Lado iluminado para a lua | **Parcial.** As candidatas vêm com luz de cima; medi o lado claro no PNG e a assimetria é da forma (galhos, musgo), não da luz, então não marquei `lit` e o espelho segue sorteado como nas 3 originais. | `arte/` |
| 6 | Luz: acesa no entardecer, tinge o chão | **Sim.** Lanterna 1,35 → 1,60 de raio e 0,80 → 1,00 de intensidade, mais a poça no chão (`light.pool` 0,80/0,80, campo genérico da replica-23): a chama fica no alto e o círculo antigo não chegava à grama. Fogueira `selfLight` 0 → 0,12. | `recortes/01_poste_meio_tod95.png`, `08`, `11` |
| 7 | Chão mais escuro lá para frente | **Sim.** `groundFar` 0,8 → 0,55, `groundReach` 0,85. | `depois/batalha_1080p_tod65.png` |
| 8 | Colagem | **2ª rodada (revisão do lead):** o chão era verde-grama vivo e uniforme, não pântano: `biomes.lua` marsh `grassA/B` 0,37/0,50/0,15 → 0,26/0,31/0,15 e `grassTint` → 0,52/0,54/0,38 (oliva escuro dessaturado, lama). Poças de água escura com reflexo de lua, juncos e pedra/tronco meio afundado (`marsh_rock_0..3`, `sizeK` 1,40, peso de `rock` 0,7 → 7). O poste estava colado no ombro da estrada quase sobre o inimigo: `lane` 0,0..0,08 → 0,15..0,30 (agora a caixa do poste começa 7 px depois da do inimigo). | `recortes/07_chao_perto_tod65.png`, `01`, `arte/candidatas_pocas.png` |
| 9 | Métrica não prova visual | Olhei cada recorte, a grade e as duas batalhas. | este arquivo |

## Direção "diorama" (adendo de 18/Out)

As árvores novas foram pedidas com o estilo da referência (tronco com face clara e escura, raízes com volume,
musgo em cortinas na frente dos galhos). São árvores sem folhas: a regra de copa em 3 planos vale pouco; o
volume vem do tronco torcido e do musgo cobrindo galhos. As 3 originais não foram regeradas (mesma linguagem).

## Leitura honesta do que ainda está feio

- O tronco partido (`marsh_deadtree_5`) perto da câmera mostra as lascas cor de palha muito grandes; lê
  como toco claro na borda da tela.
- A poça verde da lanterna é discreta na grama verde (lê de perto, some no quadro inteiro).
- As poças leem fracas: no chão escuro e na sombra das árvores viram só uma mancha escura; o reflexo da lua aparece só de perto.
- A estrada (lama) e a grama ficaram próximas em valor; a estrada se separa pela textura e pelas poças, não pela cor.
