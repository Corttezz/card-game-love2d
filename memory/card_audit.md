---
name: Auditoria carta a carta
description: Como a trava test_card_audit garante que cada carta FAZ o que DIZ (comportamento x dados x descricao nos 5 idiomas), o vocabulario canonico por idioma e como estender ao criar carta/efeito novo
type: project
---

# Auditoria carta a carta (Out/2026)

Ferramenta: `tools/audit_cards.lua`. Trava: `tools/test_card_audit.lua`
(registrada em `run_all_tests`). Relatorio completo:
`love . test_one audit_cards` (com `AUDIT_CARDS_OUT=caminho.md` grava arquivo).

## As tres camadas

1. **Comportamento x dados.** Cada carta nao-joker e jogada num `Game` de
   verdade (`selectCard -> playSelectedCards -> fila de beats`), sozinha, em
   estado neutro (inimigo 900 HP, sem passiva de classe, sem coringa, 5
   cartas-filler na mao e 12 no baralho). Mede: dano, bloqueio, vida, mana,
   mana maxima, Forca/Destreza/Foco/Espinhos, compra, descarte, exaurir,
   orbes, debuffs. Compara com o MODELO derivado so dos dados da carta
   (`expectedFor`). Repete com Forca/Destreza 3 e forjada +1/+2 (o ganho da
   forja TEM que aparecer no efeito). Inato vai pro topo, Retencao fica na mao.
   Jokers: cartas-sonda (ataque 10, defesa 10, Pocao 15) + um turno inimigo
   inteiro (gatilhos de inicio de turno, espinhos, Bloqueio retido).
2. **Descricao x dados (5 idiomas, base e forjada).** Placeholder cru; numero
   que nao existe nos dados; numero CRAVADO no template (use placeholder:
   `{atk} {def} {value..value4} {stacks..} {duration..} {pct..}`); efeito dos
   dados sem palavra na descricao; palavra-chave sem efeito; vocabulario
   proibido; formato fora do padrao; placeholders iguais nos 5 idiomas; linha
   de efeito (painel de detalhe) traduzida e sem numero inventado.
3. **Curva de poder** (heuristica, `M.WEIGHTS`): pontos/mana por raridade com
   z-score. Informativa — o veredito de forca e do simulador
   (`tools/balance_sim.lua`, ver [[balance_curves]]).

## Vocabulario canonico (o que a trava cobra)

| conceito | pt_BR | en | es | fr | de |
|---|---|---|---|---|---|
| verbo | Causa/Ganha/Compra/Cura/Perde | Deal/Gain/Draw/Heal/Lose | Causa/Gana/Roba/Cura/Pierde | Inflige/Gagne/Pioche/Soigne/Perd | Verursache/Erhalte/Ziehe/Heile/Verliere |
| bloqueio | Bloqueio | Block | Bloqueo | Blocage | Block |
| espinhos | Espinhos | Thorns | Espinas | Epines | Dornen |
| orbes | Raio/Gelo/Sombra/Fogo/Sagrado | Lightning/Ice/Shadow/Fire/Holy | Rayo/Hielo/Sombra/Fuego/Sagrado | Foudre/Glace/Ombre/Feu/Sacre | Blitz/Eis/Schatten/Feuer/Heilig |
| vida | de HP | HP | PV | PV | LP |
| bonus fixo | em cartas de ataque/defesa | on attack/defense cards | en cartas de ataque/defensa | sur les cartes d'attaque/de defense | auf Angriffs-/Verteidigungskarten |
| por turno | no inicio de cada turno | at the start of each turn | al inicio de cada turno | au debut de chaque tour | zu Beginn jedes Zuges |

"nesta batalha" so em mana maxima (Cristal de Mana): Forca/Destreza/Foco ja
duram a batalha toda, repetir em umas cartas e nao em outras era ruido.

## Mecanicas que a auditoria fixou

- **Forca vale POR GOLPE** em `multi_hit` (`EffectSystem.hitCount`): "Causa X
  de dano 2 vezes" com 3 de Forca da (X+3)x2. Golpe Duplo perdeu o
  `strength_scaling` (daria Forca 4x).
- **Espinhos de coringa** (Guardiao do Escudo, Juggernaut, Baluarte Eterno,
  Estrepes): a PRIMEIRA DEFESA jogada no turno arma N de Espinhos (P2.3). Sem
  defesa, nada. Espinhos de carta armam por carta. O reflexo sai no golpe.
- **Auto-combo**: carta com a tag `combo` conta as outras tags em DOBRO, entao
  Golpe Rapido/Estilete/Medalhao sozinhos disparam o Combo de Ataques (x1.4).
  E regra documentada (banner aparece); o modelo da auditoria inclui.
- **Vulneravel** amplia TODO dano que passa por `Enemy:takeDamage` (carta,
  magia, orbe, espinhos) — so veneno/queimadura (DoT) ficam de fora.
- O `passive` de carta de efeito/joker e compilado sobre a COPIA dos efeitos
  (forja), nao sobre o catalogo.

## Ao criar carta ou efeito novo

1. Rode `love . test_one audit_cards`. Efeito novo sem modelo aparece como
   divergencia de comportamento: estenda `expectedFor` (carta) ou
   `jokerExpected` (coringa) com a semantica PRETENDIDA.
2. Conceito novo na descricao: adicione em `VOCAB` (5 idiomas) e, se for
   palavra-chave de status, em `CLAIM_CHECK`.
3. Linha de efeito: chave `effects.<tipo>` (ou `<tipo>_<orbType|value|debuffName>`)
   nos 5 locales.

## Ligacoes

[[balance_curves]] · [[defect_doctrine]] · [[i18n_discipline]] · [[card_database]]
