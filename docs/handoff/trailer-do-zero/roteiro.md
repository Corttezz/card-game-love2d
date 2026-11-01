# Etapa 3: roteiro (trailer-do-zero)

_Diretora, 01/11/2026. Parte do diagnóstico aprovado (§6 e §7) e das ferramentas (§5). Nome de trabalho: **"Contra as regras"**. Alvo: 1º vídeo da página da Steam, **68 s**, 1920×1080, 60 fps._

## 1. Conceito

**Gancho (uma frase):** "Cada chefe quebra as regras da luta, e o seu baralho vivo é o que quebra de volta."

O filme conta **uma jornada** em ordem (ato 1 → castelo → chefe), sempre **de dentro do jogo**: câmera a ×2 na mão quando a carta é o assunto, ×1 quando o mundo é o assunto. As cartas aparecem vivas e legíveis desde o quadro 0. O meio acelera pelos 6 atos e pelas criaturas, a música **some de verdade** na entrada do Rei-Carniça, volta no drop com a frase do gancho, e três chefes provam a frase (cada um quebrando uma regra, visível na imagem). O pico é uma **jogada LETAL** de vida baixa contra o chefe, a 80% do filme, seguida do coringa do chefe subindo do corpo, que vira a ponte para o logo.

Arco de energia (alvo, loudness de curto prazo 3 s): gancho alto (−14) → jornada média (−16) → descida (−20) → **silêncio** (≤ −32, entrada do chefe) → drop (−13) → provas (−15) → **respiro** de 0,6 s (≤ −30) → **pico** (−11, golpe LETAL a 54,5 s = 80%) → fim (−16 → fade).

## 2. Música

**Uma faixa, contínua, sem emenda** (regra do Daniel): `audio/music/boss-carrion_king.mp3` (ACE-Step, 95,1 s), ligada ao chefe que o filme mostra. Deslocamento fixo: **tempo do filme = tempo da faixa − 15,50 s**. A música entra num grave da faixa e segue sem cortes; nos silêncios ela é **abaixada a −∞** (mute com rampa curta) e volta onde naturalmente estaria (como o v4 que o Daniel aprovou: "música que para e volta sincronizada").

Marcos medidos (`build/trailer/music/boss-carrion_king_beats.json`):

| faixa (s) | filme (s) | o que é na faixa | uso |
|---|---|---|---|
| 16,35 | **0,85** | grave (entra a música) | TV terminou de abrir; carta selecionada |
| 16,35 → 35,19 | 0,85 → 19,69 | groove, grave a cada ~1,25 s, −15 a −17 | gancho, luta, espólio |
| 35,19 → 55,07 | 19,69 → 39,57 | trecho calmo (−21/−22), sem graves | atos e criaturas (corte no som do jogo), castelo, **silêncio** do chefe |
| **55,07 / 55,26** | **39,57 / 39,76** | volta do groove (drop) | música volta com o nome do chefe e a frase do gancho |
| 55,26 → 70,01 | 39,76 → 54,51 | groove (−18 a −22) | provas: corvos, Geada, Correntes |
| **70,01** | **54,51** | entrada do clímax (−12/−13) | **golpe LETAL** (pico, 80%) |
| 70,01 → 81,0 | 54,51 → 65,5 | clímax | morte do chefe, coringa sobe, logo |
| 79,12 / 80,07 | 63,62 / 64,57 | graves | WISHLIST / selo |
| 81 → | 65,5 → 68,0 | queda da faixa (−20) | fade de 2,5 s, último som = carta |

Risco declarado: o trecho calmo da faixa (19,7 a 39,6 s do filme) não tem graves. Os cortes dali caem em **sons do jogo** (passo, chegada da criatura, trovão, porta), não na música; e a música fica atrás do som do jogo. Se na escuta ficar morno, a alternativa é a faixa do Tirano (`boss-abyss_tyrant.mp3`, frases de ~9,2 s com graves fortes); decisão de escuta no corte 1.

## 3. Regras do corte (herdadas e verificáveis)

- Captura sem CRT, carta a 2 px/pixel (`TRAILER_CARD_PX=2`), CRT do jogo aplicado no fim (`trailer_crt_post`), liga-TV do jogo.
- Escalas só ×1 e ×2; troca de escala só por corte seco no grave; pan só a 60 ou 120 px/s por número de quadro.
- Quadro 0 nunca preto; entre 30% e 90% (20,4 a 61,2 s) todo segundo tem carta grande ou criatura em ação; logo só depois de 61,2 s.
- Continuidade (§7 do diagnóstico): castelo centrado e horizonte na mesma altura entre atos (conferido nas tomadas `night_a1..6`: mesma linha do horizonte, lampião sempre à esquerda); jornada só para a frente; criatura entra sempre pelo mesmo lado numa sequência; chefe que pousou fica; luta que começa termina. **Saltos de luz intencionais** (não reprovar pela regra 2) marcados com ◆ no storyboard.
- Texto: inglês (página da Steam), Grimoire Pixel em escala inteira, contorno, **nunca sobre a carta que é o assunto** (zona de texto = terço superior quando a mão está embaixo); ≥ 1 s parado a cada 13 caracteres; ≤ 4 palavras por tela.
- Números na tela só os contados (§6.1 do diagnóstico): 145 cartas, 42 criaturas, 6 atos, 6 chefes.
- Som: SFX reais do jogo pelo `audio.jsonl` das tomadas novas (`remix_engine.py`); silêncio ≥ 15 dB abaixo do trecho anterior; marca "**não publicável até trocar ou licenciar os SFX**".
- Salões do Higgsfield nos acentos (decisão do Daniel), tratados (§5.6 das ferramentas), sempre como plano fechado **depois** do salão real do mesmo chefe.

## 4. Storyboard

Legenda das tomadas novas (gravador `card-game-trailer-zero`, `TRAILER_OUT=trailer_zero`): **H** = `zero_hand` (ladino, ato 1, Espantalho Amaldiçoado `cursed_scarecrow`, mão fixa; o Bruto do Fosso das tomadas antigas é do ato 3 e quebraria a ordem da jornada); **R** = `zero_reward` (espólio com carta rara + coringa); **N1..N6** = estrada de cada ato com a criatura do ato chegando (enquadramento fixo); **K** = `zero_carrion` (porta, olhos, corvos, pouso, nome); **M** = `zero_monarch`; **T** = `zero_tyrant`; **F** = `zero_fight` (guerreiro × Rei-Carniça, vida baixa, LETAL, morte, coringa do chefe). IA = salão Higgsfield tratado.

### Ato I: gancho (0 a 8 s)

| t (s) | imagem | escala | texto | som |
|---|---|---|---|---|
| 0,00 | TV do jogo **já 60% aberta** sobre a mão do ladino: 5 cartas vivas (animadas), em repouso | ×2 | — | `boot-tv-power-on` sozinho; brasas do ato 1 |
| 0,85 | TV assentada; cursor para numa carta de ataque, que sobe | ×2 | — | **música entra** (grave); hover do jogo |
| 2,10 | corte seco: plano inteiro com HUD (vida, mana, Espantalho e a barra); JOGAR; 3 cartas voam | ×1 | — | grave; `button-click` + `combo-trigger` |
| 3,36 | impacto no Espantalho: número de dano grande, **COMBO! Volley** | ×2 (no inimigo) | — | grave; `sword-sound`, voz do Espantalho |
| 4,67 | cartas voltam à mão; a mão dada de novo, uma a uma | ×2 | **145 LIVING CARDS.** (terço superior, entra no grave de 4,67, parado até 6,9) | `card-deal` do jogo |
| 5,85 → 8,0 | 2ª jogada rápida (2 golpes), o Espantalho cai | ×1 → ×2 no golpe final | — | graves 5,85 / 7,12; morte do Espantalho |

### Ato II: a jornada (8 a 31 s)

| t (s) | imagem | escala | texto | som |
|---|---|---|---|---|
| 8,4 | espólio: 2 cartas viram, a 3ª entra por último com o **brilho de achado raro** (coringa) | ×2 | — | grave; `pack-seal-break`, `card-discovered` |
| 11,0 | escolha: a carta rara sobe para o baralho | ×2 | **BUILD A LIVING DECK.** (aprovado no v8) | grave; assinatura do coringa |
| 13,4 | corte seco para a estrada do ato 1, câmera do jogo andando, castelo ao centro | ×1 | — | grave; vento e grilos |
| 15,9 → 19,7 | encruzilhada do ato 1: as placas surgem; escolha; a viagem gira o domo | ×1 | — | graves 15,9 / 17,1 / 18,4; som da encruzilhada |
| 19,7 ◆ | **Montagem dos atos, corte de correspondência** (mesmo enquadramento, só a luz e o bioma mudam): N2 crepúsculo roxo, a gárgula surge pela curva | ×1 | **6 ACTS.** (entra em 19,7, até 22,0) | trecho calmo da faixa; ambiente de cada ato em 1º plano; cada corte no som de chegada da criatura |
| 21,0 ◆ | N3 vermelho: cão do inferno | ×1 | | brasas |
| 22,3 ◆ | N4 neve: serpente de gelo emergindo | ×1 | **42 CREATURES.** (22,3 a 24,6) | vento, sopro de gelo |
| 23,6 ◆ | N5 pântano: mãe-esporo | ×1 | | chuva, trovão |
| 24,9 ◆ | N6 crepúsculo: anjo caído pousa | ×1 | | pouso do anjo |
| 26,2 | o anjo ataca: cartas na mão ×2 respondem (uma defesa sobe e incha) | ×2 | — | `armor`, impacto |
| 28,0 | estrada do ato 6 escurece; o castelo cresce; **porta do castelo** vista de fora | ×1 | — | música desce (−8 dB, abafada); noite; `castle-gate-open` começa |

### Ato III: as regras (31 a 54,5 s)

| t (s) | imagem | escala | texto | som |
|---|---|---|---|---|
| 31,0 ◆ | a porta abre; corte para o **salão vazio e escuro** do Rei-Carniça | ×1 | — | baque do portão no corte; música **some** (rampa de 0,4 s) |
| 31,5 → 37,0 | **silêncio**: dois olhos acendem; piscam; três rasantes de corvo; o Rei pousa no trono (entra pela **direita**, como no B) | ×1 → ×2 no pouso | — | só o salão: `boss-room`, olhos, asas, corvos, pouso; nada de música (≤ −32 LUFS de curto prazo) |
| 37,0 → 39,5 | cartão de nome do jogo: **CARRION KING / Sovereign of Crows**; corvos circulam o trono | ×1 | (o cartão do jogo é o texto) | `boss_reveal_sting`; respiração do salão |
| **39,76** | **drop**: o Rei ordena a **Revoada**: cada golpe é um corvo da órbita mergulhando no painel do herói (a contagem de corvos ao redor dele é o status `swarm`, visível) | ×2 | **EVERY BOSS / BREAKS THE RULES.** (2 telas: 39,76 e 41,0; até 43,2) | **música volta no grave** com o corvo do jogo |
| 41,0 | IA: plano fechado do trono do Rei (hall1 tratado), corvos | ×1 | (2ª tela do texto) | grave |
| 42,3 ◆ | **Monarca do Inverno**: salão real com o chefe; geada sobe na barra | ×1 | — | grave; vento do salão |
| 43,5 | a mão: **duas cartas congelam** (as mais caras); o jogador joga um ataque e uma derrete | ×2 | **FROST.** (uma palavra, no grave de 43,5; até 45,0) | gelo do jogo, derretimento |
| 46,0 | IA: plano fechado do salão de gelo (hall4 tratado) | ×1 | — | grave |
| 47,3 ◆ | **Tirano do Abismo**: salão real com o chefe e as 3 marcas douradas na barra | ×1 | — | grave; corrente |
| 48,5 | um golpe cruza 75%: **a corrente rompe**, o golpe anunciado cai pela metade | ×2 (na barra e no intent) | **CHAINS.** (48,5 a 50,0) | rompimento da corrente, ganho de força |
| 50,8 | IA: plano fechado do trono de lava (hall3 tratado) | ×1 | — | grave |
| 52,0 ◆ | volta ao salão do **Rei-Carniça**, o guerreiro com **9 de vida** (barra vermelha); mão dada | ×1 | — | grave; batimento de vida baixa do jogo |
| 53,1 | hover nas cartas: o painel da prévia acende **LETHAL** | ×2 (painel + mão) | (o LETHAL do jogo é o texto) | hover; música −6 dB |
| 53,9 → 54,5 | JOGAR; as cartas sobem | ×2 | — | **respiro**: música fora 0,6 s (≤ −30), só o clique e o voo |

### Ato IV: o pico e o fim (54,5 a 68 s)

| t (s) | imagem | escala | texto | som |
|---|---|---|---|---|
| **54,51** | **golpe LETAL**: hit-stop de 3 quadros, número enorme, a barra zera | ×2 → ×1 | — | **clímax da faixa entra** com o impacto do jogo + voz do Rei + `boss_land_impact` |
| 55,8 → 59,0 | morte do chefe em câmera lenta (cinemática do jogo): dessaturação, rajada, corpo no salão | ×1 | **BREAK THEM BACK.** (56,5 a 58,8) | morte do chefe, corvos fugindo |
| 59,0 → 61,2 | o **coringa do Rei-Carniça sobe do corpo girando** com o brilho de conquista | ×2 (carta grande, parada no fim) | — | revelação do coringa |
| 61,2 → 63,6 | a carta gira e a face vira o selo; o fundo escurece; **GRIMOIRE** em letras de pixel | ×1 | GRIMOIRE / **A ROGUELIKE DECKBUILDER** | grave; `forge-reveal`, letras com `pack-card-reveal` |
| 63,62 | WISHLIST | ×1 | **WISHLIST ON STEAM** | grave; selo sintetizado |
| 65,5 → 68,0 | a moldura fica; o salão reaparece atrás do logo, escuro, com um corvo pousado | ×1 | (fica) | fade da música 65,5 → 68,0; **último som: carta puxada** |

## 5. Verificações programadas no corte 1

| critério | como vou medir |
|---|---|
| gameplay ≤ 2 s, quadro 0 não preto | quadro 0 e 2,1 s |
| microtrailer (0,33..0,87 × 68 = 22,4 / 29,2 / 36,0 / 45,6 / 52,2 / 59,0 s) | as 6 fatias: serpente na neve, porta, rasante de corvo, carta derretendo, LETAL/vida baixa, coringa subindo. Nenhuma preta, nenhum logo |
| silêncio | curto prazo (3 s) em 31,5 a 37 s ≥ 15 dB abaixo de 25 a 28 s; respiro de 54 s |
| pico | maior curto prazo do filme entre 54 e 57 s (75 a 84%) |
| continuidade | luma média por plano; saltos > 25% só nos ◆; folha de quadros a 4/s nos cortes |
| leitura | toda carta-assunto ≥ 30% da altura; texto ≥ 1 s/13 caracteres parado; nenhum texto sobre a carta-assunto |
| mudo | assistir a folha sem som: entende-se cartas → jornada → chefe que quebra regra → LETAL → logo |
| loudness | −14 LUFS integrado, ≤ −1 dBTP |

## 6. Tomadas a gravar para o corte 1

H, R (ladino); N1..N6 (estrada + criatura de cada ato no mesmo enquadramento); K (Rei-Carniça, entrada inteira, sem CRT); M (Monarca, Geada na mão); T (Tirano, corrente rompendo); F (guerreiro × Rei-Carniça, 9 de vida, LETAL, morte, coringa subindo). Todas com `TRAILER_CRT=0 TRAILER_NOBEZEL=1 TRAILER_PIPE=1 TRAILER_CARD_PX=2 TRAILER_OUT=trailer_zero`, 60 fps, uma por vez, folha de quadros revista antes da montagem.
