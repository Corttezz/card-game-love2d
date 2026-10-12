---
name: Onboarding v2 — o corvo narrador (Pena), roteiro da 1ª corrida, foco com recorte, Guia
description: Out/2026. Tutorial guiado por um corvo narrador (PixelLab + quadros pintados), máquina de escrever com blip sintetizado, véu com recorte no objeto, falas de AÇÃO que só deixam passar o clique no recorte, roteiro por momento (chefe só depois da porta), vistas no perfil; Guia (G/Pausa) e tooltip da mana.
type: project
---

# Onboarding v2 (Out/2026)

v1 eram placas ancoradas soltas. O dono: "precisa ser bem mais parecido com o
Balatro — um personagenzinho falando, letras enchendo a tela com um blip tipo
Sans, um CORVO que lembre o grimório; mais claro, chamar atenção, a tela FOCAR
no que é explicado; e aparecer na hora certa — no chefe apareceu numa hora
sem sentido".

## Peças

| peça | arquivo |
|---|---|
| roteiro + gatilhos + entrada | `src/systems/Tutorial.lua` (`SCRIPT`, `ACTIONS`, `update`, `draw`, `blocksPointer`, `blocksKey`, `overlay`) |
| apresentação (corvo, balão, voz, véu/recorte, lugar) | `src/ui/Narrator.lua` (`layout`/`validate` puros) |
| arte do corvo | `assets/sprites/narrator/raven_{idle,talk,blink}[_breathe].png` — base PixelLab (`tools/pixellab_raven.py base/pick`), bico aberto/olho fechado/respiro PINTADOS da base (`frames`, rig medido no PNG): zero deriva |
| voz | `audio/sfx/narrator/blip_1..6.wav` sintetizados (`tools/synth_narrator_blips.py`) — sem serviço externo, sem pendência de licença. POOL FIXO de 6 fontes no Narrator (stop+play, volume = master×sfx do AudioManager), solto no fim da conversa (`Narrator.releaseVoice`). NÃO usar o pool do AudioManager pra blip: lá cada som cresce até 8 clones e nunca devolve — 48 vozes presas esgotavam o OpenAL e a música calava (test_music falhava na suíte cheia) |
| textos | `src/i18n/locales/tutorial/<loc>.lua` → `script.<conversa>.<fala>` (`*ênfase*` sai em sangue), `footer`, `act`, `narrator.name` (Pena/Quill/Pluma/Plume/Feder) |
| âncoras | `Tutorial.anchor/anchorList` no draw do objeto: HudManager (mana, painel, orbes), EnemyHud (intent), GameplayScene (mão, JOGAR, ENCERRAR, coringas, inimigo + barra de vida), DamagePreviewPanel (prévia), CardRewardScreen (ofertas, pular, renovar, dados), RestScreen (opções / forja), EventScreen, ScribeDiceScreen, EndlessCurseScreen, ClassSelectionScreen (faixa de selos) |
| persistência / config | `ProfileStats.tipsSeen` por CONVERSA; Configurações → Jogo: "Tutorial do corvo" (gameSettings.tipsEnabled) e "Recomeçar o tutorial" |
| Guia | `components/GuideScreen.lua` (combos gerados do ComboSystem + glossário), tecla G / "Guia [G]" na Pausa |
| trava | `tools/test_tutorial.lua` (roteiro, chefe pós-porta, entrada, pular/desligar/recomeçar, disco, layout de 37 falas × 4 tamanhos × pt/de, Guia) |
| capturas | batalha: `TUT_TIP=<conv>:<fala> [TUT_SELECT=1] [TUT_LOCALE=de] [ENEMY_SCENE_VIRTUAL=WxH] [ENEMY_SCENE_CLASS=mage] love . screenshot_enemy_scene 1_battle`; telas: `love . test_one screenshot_tutorial <rewards|shop|dice|rest|forge|endless|seals>:<loc>:<WxH>`; evento: `TUT_TIP=event:read love . screenshot_event pt_BR`; encruzilhada: `TUT_TIP=fork:paths love . screenshot_worldroad fork` |

## Roteiro (ordem = prioridade)

1ª batalha: `intro` (apresentação → inimigo+vida → intenção → herói → mão
[AÇÃO selecionar] → mana → prévia → JOGAR [AÇÃO]) · `end_turn` (ENCERRAR
[AÇÃO]) · `second_turn` (a intenção se cumpriu; o ciclo). Depois, cada um na
1ª vez: `boss` e `elite` (1º turno, depois da entrada), `block` (zera no seu
turno), `combo`, `orbs` (mago), `jokers`, `rewards`, `dice`, `shop`, `forge`,
`rest`, `event`, `fork`, `endless`, `seals` (com selo liberado).

## Regras

- **Momento**: batalha só com `battleIdle` = vez do jogador, fila de beats
  vazia, mão na mesa e `GameplayScene.isQuiet()` (sem viagem, sem cerimônia
  da porta — no chefe só com `bossEntered` —, sem banner de turno, sem
  investida, sem pouso). Telas: tela visível com a âncora desenhada. A
  condição precisa valer 0,45 s; uma conversa por vez; 0,4 s de respiro.
- **Fala** (modo talk): a conversa é o modal mais alto do InputFocus
  (`tutorialTip`, registrado por último) — combate congela; clique/A/Enter/
  Espaço: 1º completa o texto, 2º avança; Esc/B pula a conversa (fica vista);
  na 1ª fala, X/Q (ou o link) desliga o tutorial.
- **Ação** (modo action, texto já completo): o overlay LARGA o modal (o jogo
  recebe a entrada) e o main.lua consulta `Tutorial.blocksPointer` (clique
  fora do recorte não passa, nem o release dele) e `blocksKey` (Q/E e X/Y que
  não são a ação pedida não passam; navegação passa). A ação mede contra a
  mão do COMEÇO da conversa: jogar direto na fala de "selecione" não trava a
  fala de jogar.
- **Lugar**: `Narrator.layout` tenta 6 cantos (inferior esquerdo primeiro, à
  la Jimbo) e fica com o que não cobre o recorte nem a TopBar; o corvo vira
  pro balão. Fala sem `spot` = véu inteiro.
- Estado mudou no meio (fim da luta, troca de tela) → a conversa fecha SEM
  ficar vista e volta na próxima oportunidade.
- Ferramentas (`_G.HEADLESS_TOOL`) não disparam nada sozinhas; capturas usam
  `Tutorial._show(conv, fala, game)`.
- Conversa nova = entrada no `SCRIPT` + `script.<conv>.<fala>` nos 5 locales
  + âncora reportada no draw do objeto + linha no recorte do teste de layout.

Ver também: [[combo_rules]], [[ui_layout_invariants]], [[nav_cursor]].
