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

## Entrega

### Conceito C (v9 kinetic), 30/10/2026
- **Master 4K:** `E:\dev\projects\card-game-trailer\build\trailer\grimoire_trailer_v9_kinetic.mp4` (3840x2160, 60 fps, H.264 L5.2 + AAC, 64,5 s, 0,52 GB, −14,4 LUFS); 1080p ao lado (`grimoire_trailer_v9_kinetic_1080p.mp4`). Render 4K em 1141 s.
- Métricas dos 10 critérios, folha de contato, o que mudou em relação ao v8 e a origem de cada áudio: `docs/handoff/trailer-kinetic-C-metrics.md`. Resumo: 8 PASS, critério 2 FAIL (escuro de conteúdo: salão do Rei no escuro e abertura do logo; 0 % de preto puro), checklist do Daniel com 3 itens parciais (regravação, porta vista de fora, escuta humana dos SFX).
- Áudio publicável: só `boss-carrion_king.mp3` (ACE-Step) + `sfx_synth` (síntese local). Salões Higgsfield = IA, declarar na Steam.
- Conceitos A e B: ainda não renderizados (B aguarda as tomadas regravadas).
