---
name: card_damage_types
description: Tipo de dano/elemento POR CARTA (25/Out/2026): campo explícito `damageType` em src/data/cards/*.lua, lido primeiro por Resistances.ofCard/ofSpell (tag só de reserva), selo do elemento no canto inferior direito da arte (CardElementBadge, dentro do canvas cacheado), linha "Tipo de dano"/"Elemento" no tooltip, auditoria das 145 cartas, trava test_card_damage_types
type: project
---

# Tipo de dano por carta (25/Out/2026)

Pedido do dono: *"revisar todas as cartas... algumas, mesmo não sendo do mago, dão
ataque de veneno e deveriam entrar nisso; outras do guerreiro dão dano físico mas
algumas poderiam contar como elemento. Dá para pôr na carta, num cantinho, o
efeito dela: se é carta de gelo, de fogo etc. O mesmo para os efeitos."*

## Regra

- Toda carta que causa dano (ataque com `attack > 0`, `magic_damage`,
  `aoe_magic_damage`, `apply_debuff` de veneno/queimadura, `on_attack_debuff`)
  TEM `damageType` explícito. Trava: `love . test_one test_card_damage_types`.
- Tipos: `physical`, `fire`, `ice`, `lightning`, `dark`, `arcane`, `poison`, `holy`
  (`Resistances.TYPES`).
- `Resistances.ofCard(card)` lê `damageType` primeiro; sem o campo, cai na tag
  (fire > ice > lightning > dark > magic=arcane > physical). `ofSpell` usa o
  `damageType` quando não é físico.
- Carta SEM dano mas claramente elemental (canaliza orbe de um elemento, aplica
  veneno, coringa que queima/envenena) também ganha `damageType`: é o elemento
  que o selo mostra. Carta de vários elementos (Arco-íris, Tempestade
  Primordial), de evocar orbe qualquer (Colheita Sombria, Consumir, Fissão),
  contador defensivo (Brasa de Bolso, Antídoto, Escama Ígnea) e defesa "arcana"
  ficam SEM selo: o selo leria errado.
- `Resistances.elementOfCard(card)` devolve `(tipo, causaDano)`;
  `Resistances.badgeOf(card)` devolve o tipo do selo (nil para físico/sem tipo).
- Tags corrigidas: só `warrior_immolate` ganhou `fire` (som e partícula de fogo
  pelo CardFeel). As cartas de veneno já tinham `poison`; nenhuma regra de combo
  usa tag de elemento (Saraivada/Muralha/Par), e a afinidade de oferta só muda
  para Imolar.

## Selo na carta

- `src/ui/card/components/CardElementBadge.lua`: disco de 11 px (mesmo tamanho e
  contorno INK do selo de raridade) com glifo 7x7 desenhado à mão, cor da
  `Palette` por elemento (fogo laranja/amarelo em sangue escuro, gelo ciano em
  azul fundo, raio amarelo em azul-noite, sombra lua lilás em preto, arcano
  runa lilás/rosa em roxo, veneno gota verde em tinta, sagrado cruz
  pergaminho/ouro em ouro escuro), sombra de 1 px e dois pixels de ouro velho.
- Posição: canto inferior DIREITO da janela da arte, 2 px acima do rodapé. O
  custo fica no canto superior esquerdo, a raridade no superior direito, as
  gemas de forja no inferior esquerdo e a dica de resistência da mão
  (DamagePreviewPanel) no alto da borda direita: nada se cruza.
- Desenhado DENTRO de `drawChrome` (renderStandard/renderJoker), então entra na
  camada `over` e aparece em TODO quadro animado (carta viva) e no estático.
- **Físico não tem selo**: 21 das 45 cartas de dano são físicas (quase o
  guerreiro inteiro); uma espada em todas era ruído, e a ausência já lê como
  "golpe comum". O tooltip continua dizendo "Tipo de dano: Físico".
- Ícones PNG de 64 px (`Resistances.ICON`) reduzidos a 9 px viravam borrão; por
  isso glifo próprio. `Resistances.ICON.holy = "star"` só para a HUD.

## Tooltip

`CardInfoDisplay` mostra, logo abaixo do nome/forja, o selo + "Tipo de dano: X"
(carta que causa dano) ou "Elemento: X" (carta elemental sem dano), na cor do
glifo. Chaves `card_info.damage_type`/`card_info.element` e `resist.type.holy`
nos 5 idiomas.

## Pontos fracos conhecidos

- **Barreira de Fogo** ficou sem selo: o dano dela é de Espinhos, que é um buff
  único do jogador e sai sempre como físico (`EffectSystem:fireThornReflect`).
  Dar fogo exigiria Espinhos tipados por origem (prévia e piloto juntos).
- `holy` não tem dano em carta nenhuma, então nenhuma criatura reage a sagrado.
- Golpe de veneno contra imunes (lich, golem, cavaleiro espectral, sentinela,
  sapo, mãe-esporo, esqueleto, dullahan) agora sai 0: o ladino depende do golpe
  físico nessas lutas (bateria abaixo).

## Bateria

`python tools/balance.py --runs 30 --classes all --pilots expert_full --procs 3`
(seeds padrão, selo 0). "Antes" rodou num snapshot limpo de main 9ed1775c
(`--dir`), "depois" nesta árvore:

| classe | antes | depois | delta |
|---|---|---|---|
| guerreiro | 47% (14/30) | 50% (15/30) | +3 pp |
| mago | 40% (12/30) | 40% (12/30) | 0 |
| ladino | 50% (15/30) | 47% (14/30) | -3 pp |
| total expert_full | 46% [36 a 56] | 46% [36 a 56] | 0 |

O ladino perde pouco porque os golpes de veneno são baratos (2 a 8 de dano) e
o grosso do dano dele segue físico; o guerreiro só mudou Imolar (fogo, fraco em
muita criatura, imune no tirano/diabrete/sentinela/efígie). Ruído de 30 runs:
±17 pp por classe; nenhuma carta precisou voltar.

## Auditoria completa (145 cartas)

"antes" = tipo que a tag dava ao golpe (— = sem dano). "selo" = aparece o selo na carta.

| arquivo | carta | id | antes (tags) | agora | selo | motivo |
|---|---|---|---|---|---|---|
| basic | The Rock | `attack_001` | físico | físico | não | golpe de arma/corpo sem elemento |
| basic | Blood Sword | `attack_002` | físico | físico | não | espada de sangue: o sangue é roubo de vida, não elemento |
| basic | Cutilada | `attack_cleave` | físico | físico | não | golpe de arma/corpo sem elemento |
| basic | Iron Shield | `defense_001` | — | — | não | sem dano e sem elemento |
| basic | Baluarte | `defense_bulwark` | — | — | não | sem dano e sem elemento |
| basic | Carta Misterio | `effect_mystery_card` | — | — | não | sem dano e sem elemento |
| basic | Pergaminho da Sabedoria | `effect_scroll_wisdom` | — | — | não | sem dano e sem elemento |
| basic | Deus do Abismo | `joker_001` | — | — | não | sem dano e sem elemento |
| basic | Guardiao do Escudo | `joker_002` | — | — | não | sem dano e sem elemento |
| basic | Senhor Vampiro | `joker_003` | — | — | não | sem dano e sem elemento |
| basic | Bobo da Corte | `joker_004` | — | — | não | sem dano e sem elemento |
| basic | Chapeu do Bufao | `joker_005` | — | — | não | sem dano e sem elemento |
| basic | Espelho Gemeo | `joker_combo_pair` | — | — | não | sem dano e sem elemento |
| basic | Chuva de Laminas | `joker_combo_volley` | — | — | não | sem dano e sem elemento |
| basic | Muro de Escudos | `joker_combo_wall` | — | — | não | sem dano e sem elemento |
| basic | Frasco Antídoto | `joker_counter_antidote` | — | — | não | sem selo: antídoto contra veneno; selo de veneno leria o contrário |
| basic | Brasa de Bolso | `joker_counter_brazier` | — | — | não | sem selo: contador defensivo (anula Geada); selo de fogo leria como dano |
| basic | Casco de Jabuti | `joker_counter_frail` | — | — | não | sem dano e sem elemento |
| basic | Lanterna Velha | `joker_counter_lantern` | — | — | não | sem dano e sem elemento |
| basic | Escama Ígnea | `joker_counter_salamander` | — | — | não | sem selo: contador defensivo contra Queimadura |
| basic | Pele de Pedra | `joker_counter_vulnerable` | — | — | não | sem dano e sem elemento |
| basic | Chifre do Touro | `joker_counter_weak` | — | — | não | sem dano e sem elemento |
| basic | Pedra de Amolar | `joker_counter_whetstone` | — | — | não | sem dano e sem elemento |
| basic | Furia | `warrior_rage` | físico | físico | não | fúria é estado de espírito; a arte de chamas é fundo, o golpe é de punho |
| basic | Segundo Folego | `warrior_second_wind` | — | — | não | sem dano e sem elemento |
| basic | Ver Vermelho | `warrior_seeing_red` | — | — | não | sem dano e sem elemento |
| basic | Achar a Brecha | `warrior_spot_weakness` | — | — | não | sem dano e sem elemento |
| warrior | Adrenalina | `warrior_adrenaline_rush` | — | — | não | sem dano e sem elemento |
| warrior | Pancada | `warrior_bash` | físico | físico | não | golpe de arma/corpo sem elemento |
| warrior | Bastiao | `warrior_bastion` | — | — | não | sem dano e sem elemento |
| warrior | Grito de Comando | `warrior_battle_orders` | — | — | não | sem dano e sem elemento |
| warrior | Berserk | `warrior_berserk` | — | — | não | sem dano e sem elemento |
| warrior | Sangria | `warrior_bloodletting` | — | — | não | sem dano e sem elemento |
| warrior | Brutalidade | `warrior_brutality` | — | — | não | sem dano e sem elemento |
| warrior | Golpe Colossal | `warrior_colossus_blow` | físico | físico | não | golpe de arma/corpo sem elemento |
| warrior | Abraco Sombrio | `warrior_dark_embrace` | — | sombra | sim | abraço sombrio: elemento sombra (sem dano), mesma tag que já tinha |
| warrior | Defender | `warrior_defend` | — | — | não | sem dano e sem elemento |
| warrior | Forma Demoniaca | `warrior_demon_form` | — | — | não | forma demoníaca dá Força por turno: sem dano nem elemento |
| warrior | Baluarte Eterno | `warrior_eternal_bulwark` | — | — | não | sem dano e sem elemento |
| warrior | Alimentar | `warrior_feed` | físico | físico | não | golpe de arma/corpo sem elemento |
| warrior | Barreira de Fogo | `warrior_flame_barrier` | — | — | não | sem selo: o dano é de Espinhos, que hoje é um buff físico único do jogador (ver Pontos fracos) |
| warrior | Armadura Fantasma | `warrior_ghostly_armor` | — | — | não | sem dano e sem elemento |
| warrior | Lamina Pesada | `warrior_heavy_blade` | físico | físico | não | golpe de arma/corpo sem elemento |
| warrior | Elmo do Valor | `warrior_helm_of_valor` | — | — | não | sem dano e sem elemento |
| warrior | Imolar | `warrior_immolate` | físico | fogo | sim | MUDOU: 'Imolar' é queimar vivo (arte e fundo de fogo); tag `fire` adicionada (som e partícula de fogo) |
| warrior | Inflamar | `warrior_inflame` | — | — | não | 'Inflamar' o ânimo: ganha Força/Destreza, não há efeito de fogo |
| warrior | Disciplina de Ferro | `warrior_iron_discipline` | — | — | não | sem dano e sem elemento |
| warrior | Onda de Ferro | `warrior_iron_wave` | físico | físico | não | onda de FERRO: golpe de escudo, físico |
| warrior | Juggernaut | `warrior_juggernaut` | — | — | não | sem dano e sem elemento |
| warrior | Escudo Templario | `warrior_kite_guard` | — | — | não | sem dano e sem elemento |
| warrior | Cota de Malha | `warrior_plate_mail` | — | — | não | sem dano e sem elemento |
| warrior | Forca Interior | `warrior_power_through` | — | — | não | sem dano e sem elemento |
| warrior | Golpe Rapido | `warrior_quick_strike` | físico | físico | não | golpe de arma/corpo sem elemento |
| warrior | Coracao Dilacerado | `warrior_second_heart` | — | — | não | sem dano e sem elemento |
| warrior | Escudo de Espinhos | `warrior_shield_slam` | — | — | não | sem dano e sem elemento |
| warrior | Porta-Estandarte | `warrior_standard_bearer` | — | — | não | sem dano e sem elemento |
| warrior | Golpe | `warrior_strike` | físico | físico | não | golpe de arma/corpo sem elemento |
| warrior | Provocar | `warrior_taunt` | — | — | não | sem dano e sem elemento |
| warrior | Golpe Duplo | `warrior_twin_strike` | físico | físico | não | golpe de arma/corpo sem elemento |
| warrior | Grito de Guerra | `warrior_war_cry` | — | — | não | sem dano e sem elemento |
| mage | Pocao de Cura | `effect_healing_potion` | — | — | não | sem dano e sem elemento |
| mage | Cristal de Mana | `effect_mana_crystal` | — | — | não | sem dano e sem elemento |
| mage | Agregar | `mage_aggregate` | — | sombra | sim | canaliza orbe de Sombra |
| mage | Foco Arcano | `mage_arcane_focus` | — | — | não | sem selo: ganha Foco, sem dano |
| mage | Orbe Arcano | `mage_arcane_orb` | — | sombra | sim | canaliza orbe de Sombra (o nome é 'Arcano', o orbe é sombra): sombra |
| mage | Visao Arcana | `mage_arcane_sight` | — | — | não | sem dano e sem elemento |
| mage | Torrente Arcana | `mage_arcane_torrent` | arcano | arcano | sim | torrente arcana: arcano |
| mage | Escudos Automaticos | `mage_auto_shields` | — | — | não | sem dano e sem elemento |
| mage | Raio Esferico | `mage_ball_lightning` | raio | raio | sim | elemento já certo pela tag |
| mage | Nevasca | `mage_blizzard` | gelo | gelo | sim | dano mágico de gelo + orbe de gelo |
| mage | Sequencia de Boot | `mage_boot_sequence` | — | raio | sim | canaliza Raio |
| mage | Buffer | `mage_buffer` | — | — | não | sem dano e sem elemento |
| mage | Congelar | `mage_chill` | — | gelo | sim | canaliza Gelo |
| mage | Consumir | `mage_consume` | — | — | não | sem selo: evoca todos os orbes, cada um com o seu tipo |
| mage | IA Criativa | `mage_creative_ai` | — | — | não | sem selo: compra/regeneração |
| mage | Cristal de Sangue | `mage_crystal_shard` | arcano | arcano | sim | cristal de mana que drena: magia sem elemento, arcano |
| mage | Colheita Sombria | `mage_dark_harvest` | — | — | não | sem selo: evoca o orbe mais antigo, cujo tipo é o do orbe (raio/fogo/sombra) |
| mage | Perdicao e Melancolia | `mage_doom_and_gloom` | sombra | sombra | sim | elemento já certo pela tag |
| mage | Conjuracao Dupla | `mage_dualcast` | — | raio | sim | canaliza Raio |
| mage | Forma de Eco | `mage_echo_form` | — | — | não | sem selo: dobra o 1º ataque, sem tipo próprio |
| mage | Eletrodinamica | `mage_electrodynamics` | — | raio | sim | canaliza Raio todo turno: raio |
| mage | Bola de Fogo | `mage_fireball` | fogo | fogo | sim | elemento já certo pela tag |
| mage | Fissao | `mage_fission` | — | — | não | sem selo: evoca todos os orbes, cada um com o seu tipo |
| mage | Lingua de Chamas | `mage_flame_tongue` | fogo | fogo | sim | elemento já certo pela tag |
| mage | Campo de Forca | `mage_force_field` | — | — | não | sem selo: defesa; idem |
| mage | Nova de Gelo | `mage_frost_nova` | gelo | gelo | sim | elemento já certo pela tag |
| mage | Gota Curativa | `mage_healing_drop` | — | sagrado | sim | MUDOU: orbe Sagrado (cura); antes caía em arcano pela tag magic |
| mage | Relampago | `mage_lightning` | raio | raio | sim | elemento já certo pela tag |
| mage | Aprendizado de Maquina | `mage_machine_learning` | — | — | não | sem dano e sem elemento |
| mage | Amuleto Arcano | `mage_magic_barrier` | — | — | não | sem selo: defesa; o selo arcano só entra em carta de dano (arcano sem dano é só sabor) |
| mage | Chuva de Meteoros | `mage_meteor_strike` | fogo | fogo | sim | elemento já certo pela tag |
| mage | Estaca Mental | `mage_mind_spike` | arcano | arcano | sim | estaca mental: magia pura, arcano |
| mage | Sobrecarga | `mage_overcharge` | raio | raio | sim | elemento já certo pela tag |
| mage | Tempestade Primordial | `mage_primordial_storm` | — | — | não | sem selo: três elementos de uma vez (raio, gelo, sombra) |
| mage | Prece Radiante | `mage_radiant_prayer` | — | sagrado | sim | MUDOU: prece + orbe Sagrado; antes caía em arcano pela tag magic |
| mage | Arco-iris | `mage_rainbow` | — | — | não | sem selo: três elementos de uma vez (raio, gelo, sombra) |
| mage | Runa do Poder | `mage_rune_of_power` | — | — | não | sem selo: bônus de dano em qualquer ataque |
| mage | Calice do Sabio | `mage_sacred_chalice` | — | sagrado | sim | MUDOU: cálice sagrado (aumenta curas): sagrado, sem dano |
| mage | Gema do Sabio | `mage_sages_gem` | — | — | não | sem selo: bônus de dano em qualquer ataque |
| mage | Paginas Rasgadas | `mage_torn_pages` | — | — | não | sem dano e sem elemento |
| mage | Raios Gemeos | `mage_twin_bolts` | raio | raio | sim | elemento já certo pela tag |
| mage | Descarga | `mage_zap` | raio | raio | sim | elemento já certo pela tag |
| rogue | Mil Cortes | `rogue_a_thousand_cuts` | — | — | não | sem dano e sem elemento |
| rogue | Precisao | `rogue_accuracy` | — | — | não | sem dano e sem elemento |
| rogue | Acrobacias | `rogue_acrobatics` | — | — | não | sem dano e sem elemento |
| rogue | Adrenalina | `rogue_adrenaline` | — | — | não | sem dano e sem elemento |
| rogue | Pos-imagem | `rogue_after_image` | — | — | não | sem selo: defesa |
| rogue | Punhalada pelas Costas | `rogue_backstab` | físico | físico | não | golpe de arma/corpo sem elemento |
| rogue | Elixir Azul | `rogue_blue_elixir` | — | — | não | sem selo: poção de mana (fundo de veneno é só arte) |
| rogue | Borrao | `rogue_blur` | — | — | não | sem selo: defesa |
| rogue | Frasco Ricochete | `rogue_bouncing_flask` | físico | veneno | sim | MUDOU: frasco de veneno arremessado: o golpe é veneno |
| rogue | Tempo-bala | `rogue_bullet_time` | — | — | não | sem dano e sem elemento |
| rogue | Aposta Calculada | `rogue_calculated_gamble` | — | — | não | sem dano e sem elemento |
| rogue | Estrepes | `rogue_caltrops` | — | — | não | sem dano e sem elemento |
| rogue | Catalisador | `rogue_catalyst` | físico | veneno | sim | MUDOU (selo): só aplica Veneno (o tique já era veneno; agora o selo mostra) |
| rogue | Explosao de Cadaver | `rogue_corpse_explosion` | físico | veneno | sim | MUDOU: cadáver podre que explode e envenena: veneno |
| rogue | Marca da Morte | `rogue_death_mark` | — | — | não | sem dano e sem elemento |
| rogue | Esquiva | `rogue_defend` | — | — | não | sem dano e sem elemento |
| rogue | Lamina Suja | `rogue_dirty_blade` | físico | veneno | sim | MUDOU: lâmina suja de veneno: veneno |
| rogue | Sosia | `rogue_doppelganger` | — | — | não | sem dano e sem elemento |
| rogue | Envenenar | `rogue_envenom` | físico | veneno | sim | MUDOU (selo): coringa que envenena a cada ataque |
| rogue | Carrasco | `rogue_executioner` | físico | físico | não | golpe de arma/corpo sem elemento |
| rogue | Expor Fraqueza | `rogue_expose_weakness` | — | — | não | sem dano e sem elemento |
| rogue | Lamina Sanguessuga | `rogue_leech_blade` | físico | físico | não | golpe de arma/corpo sem elemento |
| rogue | Sombra da Lua | `rogue_moonshadow` | — | — | não | sem selo: defesa com compra; 'sombra' é furtividade, sem efeito de sombra |
| rogue | Neutralizar | `rogue_neutralize` | físico | físico | não | fundo verde, mas o efeito é Fraqueza, não veneno: físico |
| rogue | Dardo Envenenado | `rogue_poison_dart` | físico | veneno | sim | MUDOU: dardo envenenado: veneno |
| rogue | Garra Rapida | `rogue_rake` | físico | físico | não | golpe de arma/corpo sem elemento |
| rogue | Danca das Sombras | `rogue_shadow_dance` | — | — | não | sem selo: ganha Destreza |
| rogue | Medalhao Estelar | `rogue_shooting_star` | físico | físico | não | medalhão arremessado: físico |
| rogue | Estilete | `rogue_stiletto` | físico | físico | não | golpe de arma/corpo sem elemento |
| rogue | Tempestade de Aco | `rogue_storm_of_steel` | físico | físico | não | tempestade de AÇO (lâminas): físico |
| rogue | Golpe Furtivo | `rogue_strike` | físico | físico | não | golpe de arma/corpo sem elemento |
| rogue | Sobrevivente | `rogue_survivor` | — | — | não | sem dano e sem elemento |
| rogue | Manto de Espinhos | `rogue_thorn_cloak` | — | — | não | sem dano e sem elemento |
| rogue | Mestre das Toxinas | `rogue_toxin_master` | físico | veneno | sim | MUDOU (selo): coringa que envenena a cada ataque |
| rogue | Presas Gemeas | `rogue_twin_fangs` | físico | veneno | sim | MUDOU: presas que injetam veneno: veneno |
| rogue | Lamina Envenenada | `rogue_venom_coating` | físico | veneno | sim | MUDOU (selo): só aplica Veneno (o tique já era veneno; agora o selo mostra) |
| rogue | Presa Venenosa | `rogue_venom_fang` | físico | veneno | sim | MUDOU: presa venenosa: veneno |
| boss | Coroa da Carnica | `joker_boss_carrion` | — | sombra | sim | coroa do rei-carniça: sombra (já tinha a tag) |
| boss | Raiz do Colosso | `joker_boss_colossus` | — | — | não | sem selo: regeneração (raiz), sem elemento |
| boss | Halo do Eclipse | `joker_boss_eclipse` | — | sombra | sim | halo do eclipse: sombra (já tinha a tag) |
| boss | Filacterio do Lich | `joker_boss_lich` | — | gelo | sim | canaliza Gelo todo turno: gelo |
| boss | Coracao do Tirano | `joker_boss_tyrant` | fogo | fogo | sim | aplica Queimadura a cada ataque: fogo |
| boss | Egide do Inverno | `joker_boss_winter` | — | gelo | sim | égide do inverno: gelo |
