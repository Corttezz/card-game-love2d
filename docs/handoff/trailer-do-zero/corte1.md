# Etapa 4: corte 1 (trailer-do-zero)

_Diretora, 01/11/2026. Primeiro corte do roteiro "Contra as regras" (rodada 2). **Nenhuma saída 4K** (os salões `ai_4k` entram só como insumo, reduzidos à grade de 400×225 do salão real)._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX.** O som usa SFX do jogo gerados no ElevenLabs free (liberação do Daniel de 01/11 13:00, só para ver). A música é ACE-Step local (uso comercial). Textos marcados ⚠️ no roteiro são novos e dependem do OK do Daniel; a reserva aprovada está ao lado de cada um.

## Arquivos

| | caminho | |
|---|---|---|
| **1080p** | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte1_1080p.mp4` | 1920×1080, 60 fps, H.264 High yuv420p CRF 18, AAC 320k 48 kHz, 68,50 s, 131 MB |
| **720p leve** | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte1_720p.mp4` | 1280×720 (redução por área), 60 fps, 55 MB |
| montagem sem CRT | `...\build\trailer\zero\zero_semcrt.mp4` | para conferir pixel |
| mix e stems | `...\build\trailer\zero\zero\` (`mix.wav`, `stem_music/game_sfx/game_amb/synth.wav`, `mix_sources.json` com cada som, ganho e licença) | |

Os masters antigos (v3 a v9, A, B, C e `*_som`) não foram tocados.

## Como foi feito (reproduzível)

Tudo em `docs/handoff/trailer-do-zero/corte/`:
1. **Tomadas** (worktree `E:\dev\projects\card-game-trailer-zero`, branch `trailer-do-zero`, `tools/trailer_record.lua`): headless, 1 `lovec` por vez, identidade `card-game-trailer-v9`, saída em `trailer_zero\` (as antigas em `trailer\` intactas), sem CRT, carta a 2 px por pixel lógico (`TRAILER_CARD_PX=2`), sem tooltip. Tomadas: `zero_hand`, `fork_a1`, `night_a1`, `entr_moon_gargoyle/hellhound/ice_wyrm/fallen_angel`, `zero_carrion` (1 ataque + 3 turnos passados para o Rei fazer a Revoada, LETAL encenado com 9 de vida, morte e coringa), `zero_monarch`, `zero_tyrant`.
2. **`edl.py`**: 27 clipes e 7 textos, cada corte num grave medido da faixa do Tirano (deslocamento −1,60 s); textos sempre dentro do próprio clipe.
3. **`build_video.py`**: recorte ×1 ou ×2 (vizinho mais próximo, inteiro), hit-stop de 3 quadros no LETAL, salões do Higgsfield tratados (percentis de luminância, camada emissiva, croma por matiz, paleta do salão real, §5.10 das ferramentas), textos na fonte do jogo (`pixel.ttf`, escala inteira, contorno), segmento do logo gerado (a carta "Carrion Crown" gira no mesmo sentido da subida, vira o selo, as letras GRIMOIRE entram coluna a coluna, "A ROGUELIKE DECKBUILDER", "WISHLIST ON STEAM").
4. **`crt_pass.py`**: o CRT **do jogo** (`shaders/crt.glsl` via `tools/trailer_crt_post.lua`) por cima de tudo, em blocos de 600 quadros, com o liga-TV do jogo (`powerOn(1.8)`) começando no quadro 54 da animação.
5. **`mix.py`**: o motor de remix de 01/11 (`trailer-revisao-som/remix_engine.py`) lendo só a última gravação de cada tomada; SFX reais do jogo pelo `audio.jsonl`; automação da música (silêncio, respiro, pico); normalização linear a −14 LUFS + limitador.
6. **`mux.py`**: 1080p e 720p.

## Medições

| critério | alvo | medido |
|---|---|---|
| quadro 0 | nunca preto, carta viva | a faixa da TV já aberta mostrando a mão do ladino (Backstab, Storm of Steel, Dirty Blade...) |
| gameplay / HUD | ≤ 2 s / ≤ 5 s | mão a 0 s; plano inteiro com HUD a 2,07 s |
| microtrailer (22,6 / 29,5 / 36,3 / 45,7 / 52,6 / 59,6 s) | sem preto, sem logo | trono IA, CARRION KING, luta com o Rei, serpente + "42 CREATURES.", LETAL com 9 de vida, coringa subindo (`zero\work\micro_final.png`) |
| loudness | −14 LUFS, ≤ −1 dBTP | **−14,1 LUFS, −1,2 dBFS** de pico (1080p e 720p) |
| silêncio do Rei | leito ≤ −30; eventos: olhos −24, rasantes −20, pouso −14, nome −15 (momentâneo 0,4 s); zero música | leito (stem de ambiente, curto prazo) **−32 a −45** a partir de 25 s; olhos **−25,0**; rasantes **−19,1**; pouso **−13,2**; nome **−12,6**; música −∞ de 22,6 a 28,3 s |
| pico | maior curto prazo entre 55 e 58 s, ≥ 2 dB acima do resto | janelas que fecham em 58–61 s: **−8,8 a −9,4**; o maior fora do clímax: −11,7 (42 s) → **+2,3 dB** |
| respiro antes do LETAL | música −∞ 0,6 s | 55,25 → 55,82 s, momentâneo −21,8 |
| rajadas < 1 s | ≤ 2 | **0** (o menor plano tem 1,00 s: o salão IA do Rei) |
| provas do gancho | ≥ 2,5 s contínuos | Revoada 4,25 s; correntes 2,86 s; Geada 3,50 s |
| textos | dentro do próprio plano | os 7 dentro do intervalo do clipe (conferido em `edl.py`) |

## Pontos fracos que eu mesma vejo (para a revisão)

1. **Quadro 0**: a TV está ~35% aberta (faixa central), não os 60% do roteiro; as cartas se leem, mas a imagem ainda tem o ruído do liga-TV. Ajuste simples: começar 6 quadros depois (`TV_SKIP` 60).
2. **Revoada**: a ×1 os corvos que mergulham no painel do herói são pequenos (sprites do jogo a 3 px). A regra se entende pelo "ENEMY TURN" + "WEAKNESS!" + corvos na órbita, mas não salta aos olhos. Candidato para ×2 entre o Rei e o painel, ou um plano mais curto.
3. **"EVERY BOSS / BREAKS THE RULES."** (30,64 s) está sobre o terço superior do plano ×2 da mão, onde aparece a parte de baixo do Rei; o Rei não é o assunto desse plano, mas o texto encosta nele.
4. **Logo**: o salão por trás está escurecido a 28%; lê como fundo escuro com o salão. Pode ganhar mais presença.
5. **Faixa**: a do Tirano (troca registrada no roteiro); decisão de escuta do Daniel.
6. **Ninguém ouviu a mixagem**: tudo foi conferido por medida. Precisa de escuta humana (fone e caixa).
