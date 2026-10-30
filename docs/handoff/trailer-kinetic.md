# Frente: trailer-kinetic (Grimoire)

## Frente
_Escrita pelo grimoire em 29/10/2026. Pedido do Daniel (via chefe): "olhe as conversas que tivemos ja no grimoire sobre o trailer do nosso jogo etc quero que vc use isso ai parafazer um tariler e melhorar esse nosso ai"._

### Objetivo
1. **Trailer novo** do Grimoire feito com a skill **Kinetic Film** (tipografia cinética no ritmo da música, renderizada como código).
2. **Versão melhorada do trailer atual** (v8b), com a camada Kinetic Film por cima e os pontos fracos abaixo corrigidos.
- Saída: mp4 1920x1080 (60 fps como o v8), H.264 + AAC, loudnorm -14 LUFS.
- Skill: `~/.claude/skills/scenario-kinetic-film` (box), **sem a Scenario**; venv/playwright em `/home/box/agent-home/skills-externas/kinetic-film/`. Aguardar o chefe confirmar que o teste de instalação passou.

### Trailer atual (resumo)
> **O v8 (todas as versões: 1080p, 4K, review) NÃO é publicável** até o Daniel mostrar a licença da trilha `trailer_T4.wav` (decisão do Grimoire, 30/10/2026). Além disso, o áudio do v8 traz SFX do jogo (ElevenLabs free). Os clipes extraídos dele para o kinetic são só imagem, sem áudio.

- **Arquivo:** `E:\dev\projects\card-game-trailer\build\trailer\grimoire_trailer_v8.mp4` (1920x1080, 60 fps, 62,0 s); 4K: `grimoire_trailer_v8_4k.mp4`; revisão: `grimoire_trailer_v8_review.mp4`. Commit v8b `f68db8e5` (26/10, 01:02), branch `steam-store-v2` no worktree `card-game-trailer`.
- **Desenho:** `docs\steam\trailer-v8-design.md` (linha do tempo completa) e `docs\steam\trailer-v7-design.md` (regras e promessa). Editor: `tools\trailer_v3.py` com `TRAILER_CUT=trailer_v8_cut` (`tools\trailer_v8_cut.py`); graves medidos em `build\trailer\music\trailer_T4_beats.json` (`tools\trailer_beats.py`).
- **O que mostra:** TV CRT ligando sem música (0–3 s) → estrada + castelo "SIX ACTS" → cartas (ladino, salão de lava, JOGAR no grave) "BUILD A LIVING DECK" → encruzilhadas atos 2/4 → drop 1: 5 salões Higgsfield (4K) um por grave com nome do chefe → entradas (grifo, anjo caído, serpente de gelo) "YOUR CARDS DECIDE WHAT SURVIVES" → 2 telas pretas com frase do jogo ("Two cards, one road. Everything else is earned." / "The castle never moves. You do.") → porta do castelo (castleGateOpen +6 dB) + silêncio, Rei-Carniça entra "EVERY BOSS IS A PUZZLE" → drop 2 nome do chefe → luta sem corte (guerreiro) → glitch, logo + "WISHLIST ON STEAM".
- **Versões anteriores:** v3–v7 (+ `_review`), `grimoire_trailer_main.mp4` (77,7 s, 30 fps), `_book` (81 s, abertura com 8 s Veo re-pixelizados), `_bosses` (54 s), `grimoire_hook_20s.mp4` (21,9 s, redes).
- **Pontos fracos / feedback do Daniel (sobre o v7, aplicados no v8):** música começava no segundo 0 (quer TV ligando antes); cenas antigas (regravar no jogo atual); inimigo tem que aparecer pela entrada desde o quadro 0; **menos gameplay, mais animação**; sem o mago (chefe com guerreiro, cartas com ladino); som da porta do castelo audível; chefe entrando inteiro; música que para e volta **sincronizada** como no v4 (cada corte num grave); salões nos acentos da música; sons e sincronia no logo/WISHLIST; **mais sincronia com o áudio**, revisão quadro a quadro.
- **Feedback geral do Daniel (memória):** rejeita "cara de IA" (vetor suave sobre pixel art; vídeo IA só como ponte curta re-pixelizada); rejeitou música de chefe emendada de clipes diferentes e faixa "alegre" — música tem de ser UMA peça contínua, séria, ligada ao bioma; não usar cenários que não existem mais no jogo (só WorldRoad atos 1–6, `castle_hall_1..6`, `menu.png`); quer modo automático (decidir e entregar com o critério à mostra); "bem sutil" = muito sutil.
- **Não encontrado:** feedback do Daniel sobre o **v8** em si (nenhum registro nos chats dos bots nem nos docs). Tratar v8 como base aceita.

### Direção para o Kinetic Film
- Tipografia cinética **dentro da tela do CRT** (a moldura nunca sai do quadro: `build\trailer\brand\bezel_mask.png` + `bezel_ring.png`), com cara de runa/pixel: fonte do jogo **Grimoire Pixel** (`assets\fonts\pixel.ttf`, OFL, derivada de Press Start 2P — não chamar de "Press Start 2P"). Nada de vetor suave/gradiente "com cara de IA".
- Cartões de texto curtos (2–6 palavras, 1,5–3 s, máx. ~7), cada palavra/entrada num grave medido (`trailer_T4_beats.json`). Textos aprovados: SIX ACTS. ONE ROAD TO THE CASTLE. / BUILD A LIVING DECK. / YOUR CARDS DECIDE WHAT SURVIVES. / EVERY BOSS IS A PUZZLE. / WISHLIST ON STEAM.
- Regras Steam (pesquisa `docs\steam\research-2026-10-20.md`): gameplay antes de 4 s no trailer que for o 1º vídeo (os 6 s iniciais viram microtrailer sem som); logo só no fim; pico da música ~78% da duração; clímax com número grande de dano; cartão final 3–6 s. Sem citação inventada (frases do jogo, sem autor), sem claim de performance, flashes ≤ 3/s.
- Trailer novo: pode ser mais "kinetic" (tipografia protagonista sobre gameplay), mas continua captura do jogo real; serve como 2º vídeo da página ou peça de redes se abrir sem gameplay.

### Insumos (todos no PC, `E:\dev\projects\card-game-trailer` = R)
- **Música:**
  - `R\build\trailer\music\trailer_T4.wav` (base do v7/v8, beats em `trailer_T4_beats.json`) e `trailer_T1.wav` (v3/v4). **Origem/licença não documentada** — ver lacunas.
  - `R\audio\music\boss-carrion_king.mp3` e `boss-abyss_tyrant.mp3`: geradas localmente com **ACE-Step 1.5, uso comercial ok** (`docs\steam\store-page-v2.md`). Também `boss-tower_lich.mp3`, `boss-winter_monarch.mp3` (provavelmente ACE-Step, confirmar).
  - `R\audio\music\music-act1..6.mp3`, `music-boss*.mp3`, `music-rest/shop.mp3`, `audio\music.mp3` e as mesmas em `E:\dev\projects\card-game-trilha\audio\music\`: **licença não documentada**; a pesquisa de 20/10 diz que "a música atual veio do plano gratuito do ElevenLabs" → tratar como **sem licença comercial** até prova em contrário.
- **SFX:** os SFX do jogo (`audio\sfx\**`, 97+ arquivos; `audio\sfx\boss\*` no trilha; `tools\stingers_src\*`; `tools\preview_out\vozes_inimigos\raw\el_*`) vêm do **ElevenLabs free = SEM uso comercial** (gerados por `tools\generate_sfx.py`/`gen_entrance_sfx.py`). Isso inclui o `castleGateOpen` (`castle-gate-open.mp3`). Permitidos: blips sintetizados localmente (`tools\synth_narrator_blips.py`, zero licença) e SFX sintetizados por código no próprio Kinetic Film. Os antigos `audio\clickselect2-92097.mp3`, `sword-sound-260274.mp3`, `punching-light-armour-87442.mp3` (padrão Pixabay pelo nome) e `deckStart.mp3`/`hoverCard.wav`: origem não documentada, não usar sem confirmar.
- **Capturas:** frames TGA 1080p em `%APPDATA%\LOVE\card-game-trailer\trailer\<shot>\` (act1_mage, act2_griffin, act3_hellhound, act4_wyrm, act5_spore, act6_dullahan, boss_carrion/lich/tyrant/monarch/eclipse, cards, hand_hover, fork, intro, menu, reward, shop, victory, collection, journal, classsel, ai_book) + `audio.jsonl`. Os takes do v8 (`entrances`, `deck8`, `boss8`, identidade `card-game-trailer-v8`) **não estão mais no disco**; se precisar, sair do próprio mp4 v8 ou regravar headless (`tools\trailer_record.lua`, ver `memory\trailer_capture.md`) — regravar roda `lovec` headless: 1 por vez, nunca com janela, e só se o Daniel não estiver jogando.
- **B-roll:** salões 4K `R\build\trailer\ai_4k\hall1..5_*.mp4` (Higgsfield, IA, declarar na Steam); `ai\castle_hall_*.mp4`. **Não usar** `ai\abyss/splash/catacumbs/stone_tower.mp4` (cenários que não existem mais no jogo).
- **Marca:** `R\build\trailer\brand\logo_final.png`, `logo_sting.mp4` (6,5 s), `tv_frame.png`, `tv_glass.png`, `bezel_mask.png`, `bezel_ring.png`; `tools\trailer_brand.py`.
- **Roteiro/tom:** `docs\steam\trailer-v7-design.md`, `trailer-v8-design.md`, `store-page-v2.md`, `research-2026-10-20.md`; promessa: "construir um grimório vivo e atravessar seis atos até o castelo, enfrentando chefes que são quebra-cabeças". Visual: pixel art, CRT do jogo, moldura sagrada, textos de runa.

### Critério de pronto
- 2 mp4 finais renderizados em 1080p: `R\build\trailer\grimoire_kinetic_new.mp4` e `R\build\trailer\grimoire_trailer_v9_kinetic.mp4` (+ folhas de contato de revisão).
- Duração alvo Steam: 45–90 s (mediana de referência 72 s; v8 tem 62 s). Gameplay antes de 4 s no que for candidato a 1º vídeo.
- Nenhum asset pago e nenhum asset sem licença comercial: a música usada tem que ser comprovadamente de uso comercial (ACE-Step local) e os SFX sintetizados/permitidos; listar a origem de cada faixa e efeito na Entrega. Se não der para fechar sem ElevenLabs free, entregar marcado **"não publicável"** e dizer qual arquivo bloqueia.
- Tudo em nome de **Daniel Cortez**; sem Co-Authored-By, sem menção a Claude, Grok ou Codex (no vídeo, metadados e commits).
- Seção "## Entrega" com caminho dos mp4, duração, resolução, o que mudou em relação ao v8, origem/licença de cada áudio.

### Limites
- 0 crédito (sem Higgsfield, PixelLab, ElevenLabs, Veo), nenhuma conta nova, nada pago.
- Não abrir o jogo com janela, não matar processo por nome, 1 `lovec`, save real intocado.
- Não mexer em elemento aprovado: castelo no centro, arte-assinatura, moldura do CRT.
- Não ler arquivos com segredo (chave ElevenLabs, dados do parceiro Steam, `NEXT_SESSION.md`).
- Não publicar nada (Steam/redes): a subida do trailer na página da loja é com o Daniel.

### Lacunas conhecidas
1. `trailer_T4.wav`/`trailer_T1.wav` (música do trailer atual) sem origem/licença registrada; a pesquisa de 20/10 diz que a música atual veio do ElevenLabs free. Se for o caso, o v8 inteiro não é publicável como está e a versão melhorada precisa trocar a trilha (ACE-Step do Rei-Carniça/Tirano) e refazer o corte nos graves dela.
2. Todos os SFX do jogo são ElevenLabs free (incluindo o som da porta que o Daniel pediu audível).
3. Takes do v8 apagados do AppData.
4. Sem feedback registrado do Daniel sobre o v8.

Referências: docs/handoff/trailer-kinetic-referencias.md

## Entrega (grimoire-dev, 2026-10-30 04:00)

Três trailers renderizados com a skill Kinetic Film (sem Scenario) neste PC, pelo mesmo método de duas camadas: tipografia Grimoire Pixel pelo motor Kinetic (fundo transparente, escala inteira, passos de 15 fps, 1 amostra por quadro) + composição das tomadas por script, com a moldura do CRT em todo quadro. Áudio só ACE-Step (Rei-Carniça ou Tirano) + `build/trailer/sfx_synth` (síntese local), loudnorm −14 LUFS. **0 crédito gasto**, nada publicado, nenhum `lovec` rodado por esta frente, nenhuma tomada apagada.

### Masters

| | A: gancho (redes / 2º vídeo) | B: principal (1º vídeo) | C: v9, substituto do v8 |
|---|---|---|---|
| Arquivo 4K | `R\build\trailer\grimoire_kinetic_hook30.mp4` | `R\build\trailer\grimoire_kinetic_new.mp4` | `R\build\trailer\grimoire_trailer_v9_kinetic.mp4` |
| 1080p (do master) | `..._hook30_1080p.mp4` | `..._new_1080p.mp4` | `..._v9_kinetic_1080p.mp4` |
| Duração | 32,30 s | 65,30 s | 64,50 s |
| Formato | 3840x2160, 60 fps, H.264 High L5.2 + AAC | idem | idem |
| Tamanho | 0,42 GB | 0,93 GB | 0,77 GB |
| Loudness | −13,9 LUFS | −14,3 LUFS | −14,4 LUFS |
| Render 4K (final) | **490 s** | **946 s** | **893 s** |
| Faixa | Tirano p 13,38 → 44,23 | Rei-Carniça p 18,86 → 83,16 | Rei-Carniça p 10,05 → 73,55 |
| Imagem | tomadas novas + 3 salões + logo | tomadas novas + 5 salões + logo | TV/estrada do v8 + tomadas novas + 9 passadas de salão + logo |
| Detalhes | `trailer-kinetic-A-metrics.md` | `trailer-kinetic-B-metrics.md` | `trailer-kinetic-C-metrics.md` (2º corte) |

(R = `E:\dev\projects\card-game-trailer`. Folhas de contato: `R\build\trailer\kinetic\{A_review, B_review, v9_review}\contact_sheet.jpg`. Renders anteriores no mesmo dia: C 1º corte 1141 s, B 1ª versão 962 s, A 1ª versão 448 s, todos substituídos no mesmo caminho.)

### Os 10 critérios, remedidos nos masters finais (`tools/trailer_kinetic_metrics.py`)

| # | Critério | A | B | C |
|---|---|---|---|---|
| 1 | Gameplay até (≤ 2 s) | 0,33 s (pôster no quadro 0) | 0,33 s (pôster) | 0,77 s (pôster) |
| 2 | Sem preto (< 3 %) | **0,0 %** (antes 4,6 %) | **0,0 %** (antes 4,6 %) | **0,0 %** (antes 7,8 %) |
| 3 | Sincronia (mediana ≤ 1, máx ≤ 3 quadros) | cortes 0,2 / 0,8; palavras 0,4 / 0,8 | cortes 0,2 / 0,8; palavras 0,4 / 0,8 | cortes 0,0 / 0,8; palavras 0,3 / 0,6 |
| 4 | Legibilidade (1 s/13 car., glifo ≥ 64 px, 1 texto por vez) | 6 frases ok, glifo mín. 70 px | 8 frases ok, 70 px | 5 frases ok, 70 px |
| 5 | Ritmo (plano 2–4 s, ≤ 2 rajadas) | 2,46 s, 1 rajada | 3,25 s, 0 rajadas | 3,38 s, 1 rajada |
| 6 | Pico (75–82 %) | 76,2 % | 79,9 % (no drop) | 81,4 % |
| 7 | Regra de 3 | chefe 3×, cartas 2× | chefe 3×, deck vivo 3× | chefe 3×, deck 2× |
| 8 | Fecho (3–8 s) | 3,13 s | 5,29 s | 4,49 s |
| 9 | Conformidade (áudio, flashes, moldura, cenários, LUFS, sem coringa com rosto) | PASS: 1 flash/s, moldura 100 % | PASS: 1 flash/s, moldura 100 % | PASS: 1 flash/s, moldura 100 % |
| 10 | Checklist Daniel | 11 ok, 2 parciais | 11 ok, 2 parciais | 12 ok, 1 parcial |
| | **Resultado** | **9/9 medidos PASS** | **9/9 PASS** | **9/9 PASS** |

Teste mudo com pessoas (parte do critério 4): pendente nos três. Gates de dinamismo do `finish.py` (quadros parados ≤ 40 %, movimento ≥ 2,5 px/quadro): FAIL nos três (72 a 78 % parados). Esses limites são calibrados para reel de tipografia; aqui a imagem é captura pixel-art com texto parado para ser lido. Os gates técnicos (quadros, < 1 GB, nível 5.2, loudness) passam nos três.

Checklist do Daniel, itens parciais: tomadas regravadas no código da `steam-store-v2`, 2 commits de código atrás da `main` (A, B, C); escuta humana dos SFX (A, B, C). No C, porta audível e vista de fora, grifo e cauda da luta agora entram.

### O que mudou em relação ao v8
- **Trilha:** T4 (sem licença comprovada) sai; entra uma faixa ACE-Step contínua e séria, ligada ao chefe (Rei-Carniça em B e C, Tirano em A), cortada nos graves medidos.
- **Som:** nenhum SFX do jogo (ElevenLabs free). TV, whooshes, golpes, porta, glitch e selo são sintetizados localmente, com ganhos medidos contra a música.
- **TV:** de 3 s de TV sem música para 0,75 a 1,0 s, com **pôster de gameplay no quadro 0** (Steam mostra o 1º quadro antes do play).
- **Texto:** os cartões viraram tipografia kinetic palavra a palavra no grave, em Grimoire Pixel inteira, sem blur nem brilho. Nomes de chefe e as 2 telas pretas de frase saíram.
- **Moldura do CRT em 100 % dos quadros**, incluindo salões e logo (o v8 perdia a moldura no logo).
- **Tomadas regravadas** (`card-game-trailer-v9`): grifo, anjo, serpente, porta vista de fora, 6 atos, recompensa rara, loja por fora, deck do ladino e luta do guerreiro com o golpe de 42 no pico e 1,5 s de número legível.
- **Coringas com rosto** fora dos três: a faixa "JOKERS 3/3" do HUD de combate é tapada com os pixels do mesmo plano antes do HUD (câmera parada), com ganho casado e a faixa COMBO reconstruída; a loja aparece só por fora.
- **Escuro clareado** por gamma adaptativo só na tela (salão do Rei antes dos olhos, anel do logo). Gamma mínimo: A 0,864, B 0,715, C 0,63. O salão continua escuro, com os olhos como luz principal.
- Duração: A 32,3 s, B 65,3 s, C 64,5 s (v8: 62,0 s).

### Recomendação (pelos números)
- **B como 1º vídeo da página.** Gameplay em 0,33 s, o loop inteiro (jogar → recompensa → atos → criaturas → chefe) até 46 s, ritmo 3,25 s sem rajada, pico no drop (79,9 %), os dois ganchos 3× cada e cartão final de 5,3 s. É o único que mostra recompensa, atos e loja.
- **A como 2º vídeo e corte de redes / Next Fest.** 32 s, plano médio 2,46 s e o gancho de cartas logo de cara (PLAY. / BREAK.). O cartão final de 3,1 s está no mínimo da faixa.
- **C como substituto direto do v8**, se o Daniel quiser manter o desenho aprovado: mesma ordem do v8, agora com grifo, porta e cauda da luta. O pico em 81,4 % está no limite de cima, e o gameplay contínuo só começa em 0,77 s (a TV do v8).
- A hipótese do Grimoire se confirma: nenhum número a contradiz.

### Tomadas que seriam apagadas (só lista, nada apagado)
Pasta `C:\Users\corte\AppData\Roaming\LOVE\card-game-trailer-v9\trailer\` (caminho conferido, 104,7 GB no total). Usadas por pelo menos uma EDL (A_edl, B_edl, C2_edl), e portanto mantidas inteiras: `boss8`, `deck8`, `entr_fallen_angel`, `entr_ice_wyrm`, `entr_storm_griffin`, `fork_a1`, `fork_a2`, `fork_a4`, `night_a1` a `night_a6`, `reward`, `shop`.

| Pasta não usada | Tamanho | Quadros |
|---|---|---|
| `fork_a3` | 3.657 MB | 462 |
| `fork_a5` | 3.657 MB | 462 |
| `fork_a6` | 3.657 MB | 462 |
| `poweron` | 3.427 MB | 433 |
| **Total** | **14.398 MB (≈ 14,1 GB)** | |

O save `run.tool.lua` (e `.bak`) fica fora dessa pasta e não entra na lista.

### Suíte do merge (item à parte)
O merge da `main` na `steam-store-v2` foi **abortado** antes da regravação (seção 7 do prep). Nada foi commitado nem enviado na `steam-store-v2`. Suíte completa (`test_all` via `suite_lock.sh`, `CARDGAME_HEADLESS=1`): **167 PASS / 4 FAIL / 1 CRASH em 172 suítes.**
- **FAIL `test_landmark_fx`:** sombra do castelo na fila de contato. Já falha na `steam-store-v2` sem o merge.
- **FAIL `test_immunities`:** retorno IMUNE. Falha só na suíte inteira; passa isolada, com e sem o merge (depende da ordem).
- **FAIL `test_enemy_life`:** ember_imp. Mesmo padrão: só na suíte inteira.
- **FAIL `test_cheat_mode`:** FORÇAR CORINGA. Mesmo padrão: só na suíte inteira.
- **CRASH `test_scene_continuity`:** cai na suíte; isolada dá "1 cena com descontinuidade". Já falha na `steam-store-v2` sem o merge.

As tomadas usadas nos três trailers foram gravadas nesse código, 2 commits de código atrás da `main` (`e40c1249` Mãe dos Esporos, `14d5eba5` estrada sem mato e sombra do obelisco).

### Pendências
1. **Escuta humana dos SFX** nos três. Os ganhos foram medidos contra a música, mas ninguém ouviu.
2. **Teste mudo** com pessoas (critério 4).
3. **Coringas com rosto:** conferido pela folha de contato e em recortes 1:1. Resta um artefato pequeno: durante a faixa COMBO da luta (~0,5 s em A, B e C), a parte reconstruída da faixa mostra listras horizontais leves. Se incomodar, a saída é regravar com a faixa de coringas desligada no HUD.
4. **Merge da `main` / suíte:** os 4 FAIL e o CRASH acima. Depois de resolver, regravar se as 2 mudanças de estrada da `main` precisarem aparecer.
5. **Melhorias opcionais:** nenhuma pendente no C (grifo, porta de fora e cauda já entraram). Opcionais: textos novos de A/B (PLAY., BREAK., EVERY CARD IS ALIVE., BEND EVERY HAND.) passarem pelo Daniel; abrir o cartão final do A para ~4 s; conferir o microtrailer da Steam depois do upload.
6. **Licença da T4:** o v8 (todas as versões) continua **não publicável** até a licença de `trailer_T4.wav` aparecer. Nenhum dos três novos usa a T4.
7. **IA declarada:** os salões `ai_4k/hall1..5` (Higgsfield) aparecem em A, B e C e precisam ser declarados na Steam.
8. Apagar as 4 pastas listadas (14,1 GB) só com OK explícito.

Fontes no repo: `docs/handoff/trailer-kinetic-{A,B}-film/`, `trailer-kinetic-v9-film/` (C), `trailer-kinetic-fx/` (patch dos coringas, clareamento, render dos três), EDLs `trailer-kinetic-{A,B,C2}-edl.json`, medidor `tools/trailer_kinetic_metrics.py`.
