# Conceito B (grimoire_kinetic_new): render e métricas

_30/10/2026, frente trailer-kinetic. **2ª versão (mesmo dia):** coringas com rosto tapados, loja só por fora e escuro clareado, a pedido do Grimoire; a tabela abaixo é do master novo, e a 1ª versão está no fim. Mesmo método do C (`trailer-kinetic-C-metrics.md`): camada de tipografia pelo motor Kinetic Film (Grimoire Pixel inteira, fundo transparente, 1 amostra por quadro) + composição e moldura do CRT por script. Sem Scenario, 0 crédito, nada publicado, nenhum `lovec` rodado, tomadas brutas intocadas (só lidas)._

## Arquivos

| O quê | Caminho |
|---|---|
| **Master 4K** | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_kinetic_new.mp4` (3840x2160, 60 fps, H.264 High L5.2 + AAC 320k, **65,30 s**, 3918 quadros, 0,93 GB, −14,3 LUFS) |
| Versão 1080p (do master) | `...\build\trailer\grimoire_kinetic_new_1080p.mp4` (0,17 GB, L4.2) |
| Folha de contato (1 quadro/s, do master) | `...\build\trailer\kinetic\B_review\contact_sheet.jpg` |
| Métricas brutas | `...\build\trailer\kinetic\B_review\metrics.json` (cópia: `docs/handoff/trailer-kinetic-B-metrics.json`) |
| EDL | `...\build\trailer\kinetic\B_edl.json` (cópia: `docs/handoff/trailer-kinetic-B-edl.json`), gerada por `kscripts/make_edl.py` |
| Fonte do filme | `E:\dev\_orquestracao\skills-externas\kinetic-film\grimoire_b`; cópia de `spec.js`, `index.html` e `kscripts/` em `docs/handoff/trailer-kinetic-B-film/` |
| Tomadas usadas (só leitura) | `%APPDATA%\LOVE\card-game-trailer-v9\trailer\` (TGA 1080p; proxies mp4 dos trechos usados em `grimoire_b\out\proxy`) |

**Tempo do render 4K: 946 s (15 min 46 s)** na 2ª versão (camada + mixagem + composição/encode x264 `slower` CRF 12,4, 902 s de composição); a 1ª versão levou 962 s. As tomadas são 1080p e entram no 4K ampliadas 2x por vizinho mais próximo, como o v8. `finish.py` levou mais ~5 min.

## Corte (t = p − 17,86; graves medidos de `boss-carrion_king_beats.json`)

| t | tomada (quadros) | âncora | texto |
|---|---|---|---|
| 0,00–8,52 | `deck8` 560→1083, remapeado por trecho: JOGAR 830 em 3,49, golpes 868/946/989 em 4,76/6,02/6,96 (0,5x a 1,3x entre eles); TV liga sintetizada sobre o combate (0 a 1,0: linha, abertura vertical, brilho que assenta) | graves | BUILD (3,49) · A LIVING (4,76) · DECK. (6,02) |
| 8,52–11,05 | `reward` 548→700, clarão da revelação rara (624) no grave 9,78 | graves | EVERY CARD (8,52) · IS ALIVE. (9,78) |
| 11,05–20,40 | `night_a1`…`night_a6` do quadro 110 (sem o clarão do início), um ato por grave; ato VI segura até 20,40 | graves | SIX (11,05) · ACTS. (12,29); ONE ROAD / TO THE CASTLE. (17,33) |
| 20,40–27,10 | `entr_storm_griffin` 540→678 (pouso 661 em 22,42), `entr_fallen_angel` 520→658 (pouso ~620 em 24,37), `entr_ice_wyrm` 470→596 | pad sem grave: pousos | YOUR CARDS (21,30) · DECIDE (pouso do grifo) · WHAT SURVIVES. (pouso do anjo) |
| 27,10–29,29 | `shop` 40→171: só a chegada ao mercador por fora (o balcão com a carta de caveira e os coringas de rosto entra em ~180 e ficou fora) | pad | BEND (27,10) · EVERY HAND. (27,80) |
| 29,29–38,66 | `boss8` 497→1091: **porta vista de fora** (portão 564 em 30,41, baque da porta sintetizada), escuro comprimido (695→745 em 0,3 s), olhos, rasantes, pouso, cartão do nome no grave 37,40 | pad + grave | — |
| 38,66–46,18 | salões 4K `hall2/3/4/5` + `hall1_carrion` (2 graves) | graves | EVERY BOSS (38,66) · IS A PUZZLE. (39,91) |
| 46,18–54,99 | `boss8` 1160→1640: luta do guerreiro sem corte, já sem o cartão do nome (0,87x até o JOGAR 1422 no grave 51,20); **golpe de 42 (o maior número) no pico 52,15 = drop p 70,01**; golpes 33 e 27+COMBO em 53,13 e 53,72 (grave); cauda limpa até 1640, antes do tooltip (1661) | graves | — |
| 54,99–55,29 | glitch sobre o último quadro da luta | grave | — |
| 55,29–65,30 | `logo_sting` a 1,386x (impacto da arte no grave 57,18; termina em 59,98) e segura | graves | WISHLIST ON STEAM. (60,01, até o fim) |

Pôster no quadro 0: o quadro de 6,60 s (combate do ladino com BUILD A LIVING DECK.).

## Coringas com rosto e escuro (2ª versão)
- **Coringas com rosto:** a faixa "JOKERS 3/3" do HUD de combate (`deck8` e `boss8`) é trocada pelos pixels do mesmo plano antes de o HUD aparecer, com ganho casado e emenda suave; a faixa "COMBO!" é reconstruída por linha quando passa por cima (detalhes em `trailer-kinetic-A-metrics.md`). A loja ficou só por fora (quadros 40 a 171). Conferido na folha de contato do master e em recortes 1:1 do deck, da luta e do pôster.
- **Escuro:** gamma adaptativo só na tela até a média de 6,2 %: 229 quadros (salão do Rei antes dos olhos e anel do logo), gamma mínimo **0,715**. O salão continua escuro, com os olhos como única luz forte; o fundo roxo do logo fica um pouco mais aberto.

## Os 10 critérios (master 4K, 2ª versão)

| # | Critério | Meta | Medido | Resultado |
|---|---|---|---|---|
| 1 | Gameplay até | ≤ 2 s | quadro 0 = captura (pôster); captura contínua em **0,33 s** | PASS |
| 2 | Sem preto | < 3 % | **0,0 %** fora da TV/glitch (0,38 % no total, dentro da TV ligando); 1ª versão: 4,6 % | PASS |
| 3 | Sincronia nos graves | mediana ≤ 1 quadro, máx ≤ 3 | cortes: mediana **0,2**, máx **0,8** quadro (12 de 13 medidos); palavras: mediana **0,4**, máx **0,8** | PASS |
| 4 | Legibilidade | ≥ 1 s/13 car., glifo ≥ 64 px, ≤ 30 car./linha, 1 texto por vez | 8 frases passam (a mais justa: BEND EVERY HAND. 2,05 s para 1,23); glifo mín. **70 px**; maior linha 18 car. Teste mudo pendente | PASS |
| 5 | Ritmo | plano médio 2–4 s, ≤ 2 rajadas < 1 s | 20 planos, média **3,25 s**; nenhum < 1 s | PASS |
| 6 | Pico | 75–82 % | golpe de 42 em **52,15 s = 79,9 %**, no drop | PASS |
| 7 | Regra de 3 | 2–3 vezes | chefe 3×; deck vivo 3× (cartas + BUILD A LIVING DECK, carta rara + EVERY CARD IS ALIVE, loja + BEND EVERY HAND) | PASS |
| 8 | Fecho | 3–8 s | **5,29 s** de WISHLIST ON STEAM. até o último quadro | PASS |
| 9 | Conformidade | 0 asset proibido, ≤ 3 flashes/s, moldura 100 %, cenários válidos, −14 LUFS | só Rei-Carniça + `sfx_synth`; **1 flash/s**; moldura **100 %**; 19 fontes válidas; **−14,3 LUFS**, pico −0,8 dBFS; nenhum coringa com rosto | PASS |
| 10 | Checklist Daniel | ver abaixo | 11 ok, 2 parciais | parcial |

### Gates da skill (`finish.py`)
Técnicos: quadros 3918/3918, 0,93 GB (< 1 GB), nível 5.2, −14,3 LUFS: **PASS** no 4K e no 1080p. Dinamismo: **FAIL** (78 % de quadros parados, movimento mediano abaixo de 0,5 px/quadro), pelo mesmo motivo do C: os limites são de reel de tipografia, a imagem é captura pixel-art e o texto fica parado para ser lido. Os quatro "parados" são a mão do ladino entre golpes e o Spoils of Battle antes da revelação.

### Checklist Daniel (critério 10)

| Item | B |
|---|---|
| 1. TV liga antes da música | ok (0 a 1,0 s; música em 1,00) |
| 2. Cenas regravadas no jogo atual | parcial: regravadas em 30/10, mas no código da `steam-store-v2`, 2 commits de código atrás da `main` (Mãe dos Esporos, estrada sem mato) |
| 3. Inimigo desde o quadro 0 da entrada | ok (grifo e anjo já em quadro, serpente emergindo) |
| 4. Menos gameplay, mais animação | ok (entradas, porta, cinemática do chefe e salões ocupam 29 s) |
| 5. Sem o mago | ok (ladino no deck/recompensa/loja, guerreiro no chefe) |
| 6. Porta do castelo audível | ok: porta vista de fora + porta sintetizada (baque no quadro do portão) |
| 7. Chefe entrando inteiro | ok (rasantes, pouso, cartão) |
| 8. Música para e volta sincronizada | ok (pad sem grave de 20,4 a 37,4 s ancorado em pousos/portão; graves antes e depois) |
| 9. Salões nos acentos | ok (5 salões, Δ ≤ 0,4 quadro) |
| 10. Sons e sincronia no logo/WISHLIST | ok (impacto do logo e selo nos graves) |
| 11. Revisão quadro a quadro | parcial: folhas de contato + medição de graves; falta escuta humana dos SFX |
| Sem cara de IA | ok (texto em pixel inteiro; salões Higgsfield = IA declarada) |
| Música contínua, séria, do bioma | ok |

### Ressalvas das tomadas, como foram tratadas
- **Cauda da luta (1,5 s limpo):** a luta termina no quadro 1640, 20 quadros antes do tooltip "Twin Strike" (1661); o glitch entra no grave 54,99. Não precisou segurar quadro parado: o remapeamento põe 1564→1640 em 1,27 s (1,0x).
- **Coringas com rosto:** loja só por fora (40 a 171) e faixa de coringas do HUD tapada no deck e na luta (2ª versão).
- **Clarão no início das viagens:** cada ato começa no quadro 110.
- **Mão sendo dada:** o deck começa no quadro 560 (inimigo surgindo, 1ª carta dada); o remapeamento até o JOGAR roda a ~1,3x.

## O que as tomadas novas melhorariam no C (não refeito)
> Atualização: o C foi refeito no mesmo dia com grifo, porta vista de fora, cauda da luta e `fork_a1` (ver o "2º corte" em `trailer-kinetic-C-metrics.md`). A lista abaixo fica como registro do raciocínio.
- **Grifo** (`entr_storm_griffin`, pouso limpo em 661): devolve ao C a entrada que saiu por ter texto queimado no v8; caberia antes do anjo no trecho YOUR CARDS DECIDE (17,8–22,9) e daria às três criaturas um pouso por grave.
- **Porta vista de fora** (`boss8` 1–620, portão em 564): hoje o C só tem a porta no som (o rangido sobre o salão do pad); com ela o baque cai no quadro do portão, como pedido no v7.
- **Cauda da luta** (`boss8` 1564–1650 limpo): o C corta 0,03 s depois do 3º golpe; com 1,3 s de cauda o número fica legível antes do glitch. O maior número da luta nova é o do 1º golpe (42), então o pico do C passaria para esse golpe.
- **`fork_a1`** também existe agora (encruzilhada do ato 1 sem texto): substituiria o `fork_a4` que entrou no lugar dele.
- Ressalva para refazer o C: as tomadas são do código da `steam-store-v2` (2 commits atrás da `main`) e trocam o desenho do v8 (base aceita) por planos novos; seria uma decisão do Daniel, não ajuste técnico.

## Origem do áudio
| Arquivo | Origem / licença |
|---|---|
| `audio/music/boss-carrion_king.mp3` (p 18,86 a 83,16, fade de 0,64 s) | ACE-Step 1.5 local, uso comercial |
| `build/trailer/sfx_synth/{tv_on, whoosh_1, whoosh_2, impact_1, impact_2, impact_heavy, castle_door, glitch, logo_seal}.wav` | síntese local (`tools/synth_trailer_sfx.py`), ganhos já com o ajuste medido no C (whooshes +10/11 dB) |

Imagem: tomadas regravadas do jogo (`card-game-trailer-v9`), salões `ai_4k/hall1..5` (Higgsfield, IA: declarar na Steam), `logo_sting`. Fonte: Grimoire Pixel (OFL).

## Reproduzir
```
cd E:\dev\_orquestracao\skills-externas\kinetic-film\grimoire_b
..\venv\Scripts\python.exe kscripts\make_edl.py
..\venv\Scripts\python.exe kscripts\layer.py . 4
..\venv\Scripts\python.exe kscripts\mixdown.py .
..\venv\Scripts\python.exe kscripts\compose.py . --res 4k
..\venv\Scripts\python.exe C:\Users\corte\.claude\skills\scenario-kinetic-film\scripts\finish.py . --video out\video_4k.mp4 --audio out\mix.wav --no-vertical --dest out\final4k
..\venv\Scripts\python.exe -I E:\dev\projects\card-game-love2d\tools\trailer_kinetic_metrics.py <mp4> --edl <B_edl.json> --trim 0 --spec spec.js --sources out\mix_sources.json --layer out\layer --json metrics.json --sheet contact_sheet.jpg
```
O medidor agora lê da EDL, quando existem, `tv_on`, `peak`, `hooks` e `valid_scenes`. Rodado de novo sobre o C, os resultados se mantêm; só a média de plano foi de 3,57 para 3,60 s, porque o último plano passou a contar até o fim real.

## 1ª versão (antes da correção do Grimoire)
Mesmo corte, loja até o quadro 221 (carta de caveira no balcão) e faixa de coringas visível no deck e na luta, sem clareamento: critério 2 em **4,6 %** (FAIL), o resto igual. Substituída no mesmo caminho pelo master acima.
