---
name: enemy_immunities
description: Imunidade, resistência e fraqueza por criatura (24/Out/2026): tipos de dano (físico/fogo/gelo/raio/sombra/arcano/veneno), tabela por lore em src/data/enemies.lua (RESIST), conta única em src/systems/Resistances.lua (combate, prévia, piloto e HUD leem a MESMA função), ícones na barra de vida, "IMUNE" no tique, trava test_immunities
type: project
---

# Imunidades e resistências (24/Out/2026)

Pedido do dono: *"olhar monstro por monstro, ato por ato, e definir regras.
Alguns monstros não fazem sentido tomar veneno... eles podem ficar verdes porque
demos veneno, mas quando vem o dano parece que são imunes... mesmo com fogo, com
gelo... talvez alguns chefes sejam imunes a outras coisas. O chefe final pode ser
imune a quase tudo, não tudo, senão fica impossível matar. Pense também no
balanceamento do jogo."*

## Regra

- Três níveis: **imune** (×0: o golpe vira 0, o tique de status não tira vida),
  **resiste** (×0,5, arredonda para baixo, nunca abaixo de 1 quando havia dano),
  **fraco** (×1,5, arredonda para baixo).
- A resistência entra ANTES de Vulnerável e do Bloqueio do inimigo:
  `dano → resistência → Vulnerável ×1,5 → Bloqueio`.
- O STATUS sempre entra (a criatura fica verde com veneno, queima com
  queimadura): só o TIQUE é que sai 0 ou pela metade. O veneno decai normal.
- Tipos de dano:

| tipo | de onde vem |
|---|---|
| `physical` | ataque sem tag de elemento, espinhos |
| `fire` | ataque com tag `fire`, orbe de Fogo (pulso e evocação), magia de carta `fire`, tique de Queimadura |
| `ice` | ataque/magia com tag `ice` (o orbe de Gelo não causa dano) |
| `lightning` | ataque/magia `lightning`, orbe de Raio |
| `dark` | ataque/magia `dark`, orbe de Sombra |
| `arcane` | ataque com só a tag `magic`, magia de carta sem elemento |
| `poison` | tique de Veneno e, desde 25/Out/2026, o GOLPE das cartas de veneno do ladino (dardo, lâmina suja, presas, frasco, cadáver) |
| `holy` | só elemento de exibição (orbe Sagrado cura); nenhuma carta causa dano sagrado, nenhuma criatura reage a ele |

  O tipo de cada carta é o campo explícito `damageType` (tabela em memory/card_damage_types.md); a tag só vale de reserva para carta sem o campo, com prioridade fire > ice > lightning > dark > (magic = arcane) > physical.
  `holy` entrou em `Resistances.TYPES` (25/Out/2026) só para o selo das 3 cartas
  sagradas do mago, que curam. Como nenhuma carta causa dano sagrado, NENHUMA
  criatura ganhou regra de sagrado (mortos-vivos e fantasmas ficariam com uma
  fraqueza que ninguém consegue usar). Se um dia surgir dano sagrado, lich,
  esqueleto, cavaleiro espectral, sombra do crepúsculo e dullahan são os candidatos.

## Tabela por criatura (o porquê é de lore, os números são da bateria)

| ato | criatura | tipo | imune | resiste | fraco | por quê |
|---|---|---|---|---|---|---|
| 1 | cursed_scarecrow | comum | | | fogo | palha seca costurada |
| 1 | hollow_farmer | comum | | | | ainda é carne e raiz: o inimigo "de base" do ato |
| 1 | plague_rats | comum | | veneno | fogo | carregam a peste no sangue |
| 1 | harvest_reaper | elite | | sombra | | ceifa almas |
| 1 | blight_bull | elite | | veneno | | a praga já mora no couro podre |
| 1 | wicker_effigy | mini | fogo | | gelo | queima por dentro desde a festa da colheita |
| 1 | carrion_king | chefe | | sombra | fogo | rei dos mortos; penas queimam |
| 2 | moon_gargoyle | comum | | veneno | | pedra de dia |
| 2 | ram_cultist | comum | | sombra | | protegido pelos hinos da torre |
| 2 | storm_harpy | comum | | raio | gelo | nasce dos raios; o frio derruba a asa |
| 2 | rune_golem | elite | veneno | arcano | raio | constructo; as runas bebem magia e sobrecarregam com raio |
| 2 | spectral_knight | elite | veneno | físico | arcano | fantasma: a lâmina passa através, a magia não |
| 2 | storm_griffin | mini | | raio | gelo | ninho onde os raios caem primeiro (era imune: derrubou o mago, ver Medição) |
| 2 | tower_lich | chefe | veneno, gelo | | fogo | morto-vivo do Escudo de Gelo |
| 3 | ember_imp | comum | fogo | | gelo | feito de brasa |
| 3 | hellhound | comum | | fogo | gelo | bafo de fogo |
| 3 | abyss_acolyte | comum | | sombra | | lê o tomo sombrio |
| 3 | obsidian_sentinel | elite | veneno, fogo | | físico | vidro vulcânico: não sangra, não queima, racha |
| 3 | pit_brute | elite | | | | só músculo |
| 3 | abyss_watcher | mini | sombra | | raio | o abismo olha de volta |
| 3 | abyss_tyrant | chefe | fogo | | gelo | selado com fogo |
| 4 | frost_wight | comum | gelo | veneno | fogo | morreu congelado, sangue parado |
| 4 | frost_wolf | comum | gelo | | fogo | pelagem do gelo |
| 4 | rime_shaman | comum | gelo | | | fala com o frio |
| 4 | glacier_knight | elite | gelo | | fogo | armadura de gelo |
| 4 | frost_troll | elite | | gelo | fogo | troll: fogo fecha a regeneração (clássico) |
| 4 | ice_wyrm | mini | gelo | | fogo | escamas de inverno |
| 4 | winter_monarch | chefe | gelo | veneno | fogo | rei do inverno; fogo derrete a Geada (mesma lógica da mecânica) |
| 5 | bog_ghoul | comum | | veneno | fogo | come carniça |
| 5 | plague_toad | comum | veneno | | raio | inchado de veneno; pele molhada |
| 5 | leech_horror | comum | | | fogo | sanguessugas fogem do fogo |
| 5 | mire_hag | elite | | veneno | | conhece cada erva do pântano |
| 5 | croc_warrior | elite | | | | casco e lança, sem truque |
| 5 | spore_mother | mini | veneno | | fogo | fungo que nasceu de cadáver |
| 5 | rot_colossus | chefe | | raio | fogo | madeira encharcada aterra o raio; tronco queima |
| 6 | dusk_shade | comum | sombra | veneno | | sombra pura |
| 6 | dusk_bat | comum | | | | carne de morcego |
| 6 | grave_thrall | comum | veneno | | | esqueleto |
| 6 | blood_duke | elite | | sombra | fogo | vampiro nobre |
| 6 | dullahan | elite | veneno | | | sem cabeça, sem sangue |
| 6 | fallen_angel | mini | | arcano | | magia celeste |
| 6 | eclipse_queen | chefe | sombra | veneno, gelo, arcano | fogo, raio | o eclipse engole a sombra; luz (fogo e raio) é o que a fere |

## Chefes: não quebrar a assinatura

- Lich: runa quebra com 12% da vida num turno. Fogo fraco ajuda a quebrar; gelo e
  veneno imunes. O ladino quebra com golpes físicos.
- Tirano: correntes por % de vida, nada muda.
- Monarca: a mecânica já diz que fogo derrete a Geada; fogo fraco reforça a mesma leitura.
- Colosso: corta raiz com golpe único de 4% da vida. Fogo fraco ajuda; raio só resiste.
- Rainha: imune/resiste a quase tudo, mas FÍSICO é normal e fogo/raio são fracos,
  então guerreiro (físico), ladino (físico + metade do veneno) e mago (fogo/raio)
  têm caminho.

## Balanceamento (regras de desenho)

- Nenhum comum dos atos 1-2 é IMUNE a veneno (só resiste: ratos e gárgula).
- Físico só é resistido por UMA criatura (cavaleiro espectral, elite do ato 2) e é
  fraco no sentinela de obsidiana: o guerreiro, 100% físico, quase não sente.
- O mago tem cinco elementos e sempre acha um que funciona; os fracos a fogo do
  ato 4 compensam o gelo imune do mesmo ato.
- Bateria e números: ver seção "Medição" abaixo.

## Medição (24/Out/2026)

`python tools/balance.py --runs 30 --classes all --pilots expert_full,average --procs 3`
(seeds padrão), mesma árvore, `BALANCE_IMMUNITIES=0` x ligado:

| classe | expert_full desligado | ligado (v1) | ligado (final) | average desl. | average lig. (v1) |
|---|---|---|---|---|---|
| guerreiro | 50% | 50% | 50% | 13% | 20% |
| mago | 53% | 37% | **53%** | 0% | 0% |
| ladino | 63% | 57% | 57% | 3% | 0% |

- v1 tinha o grifo da tempestade IMUNE a raio: o mago (raio é o dano do começo)
  morreu 12× no ato 2 (grifo 21 mortes no total, contra 4 sem imunidade). Grifo
  e harpia passaram a só resistir a raio e ficaram fracos a gelo: mago voltou a
  53% (rodada só do mago, 30 runs, mesmas seeds).
- Ladino -6 pp (dentro do teto de 8): o veneno é cortado no esqueleto, no
  dullahan e em metade dos atos 4-6, mas o golpe físico segue inteiro.
- Guerreiro inalterado (só o cavaleiro espectral resiste a físico; sentinela é fraco).
- O piloto lê a tabela por `Resistances.apply/factor` (mesma API da prévia e do HUD).

## Onde mora

| peça | arquivo |
|---|---|
| tabela | `src/data/enemies.lua` → `Enemies.RESIST` (por id de criatura) |
| conta e tipo de dano | `src/systems/Resistances.lua` (`ofCard`, `ofSpell`, `level`, `apply`, `entries`, `cardHint`); `Resistances.ENABLED` (knob `BALANCE_IMMUNITIES=0`) |
| aplicação | `Enemy:takeDamage(dano, tipo)` e o tique em `Enemy:onTurnEnd` (`enemy.lastDot`) |
| prévia | `DamagePreview.simulate` (`hitEnemy(dmg, tipo)`, passo `resist` na carta, LETAL já com a conta) |
| HUD | `src/ui/ResistBadges.lua` (ícones à direita da barra de vida, tooltip), pílula de veneno/queimadura com variante `desc_immune/desc_resist/desc_weak` |
| retorno | `src/ui/ResistFx.lua` ("IMUNE"/"RESISTE"/"FRAQUEZA!", som `armorSound`, faíscas, `EnemyStates.shrug`) |
| dica na mão | `DamagePreviewPanel.drawHandBadges` (selo pequeno com o ícone do tipo na carta que não pega) |
| piloto | `tools/balance_ai.lua` + `tools/autoplay.lua` via `Resistances.apply` (a mesma API da UI) |
| textos | `src/i18n/locales/resist/<loc>.lua` (`resist = require(...)`) |
| trava | `love . test_one test_immunities` |
