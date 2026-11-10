# Frente: nome-runemoire (Grimoire → Runemoire)

## Frente
_Decisão do Daniel em 10/11/2026, pelo chat do Grimoire Lead ("quero"). Nível M. Executor: Grimoire Dev._

### Por quê
Já existe "Grimoire" (Topius, app 2654660) na Steam. O Daniel escolheu **RUNEMOIRE**. Checagem do Lead em 10/11: sem jogo na Steam nem na web, sem marca na base mundial da OMPI (inclui INPI, USPTO e EUIPO), domínios e @ livres. Estudo: `C:\Users\corte\OpenBot\Agents\agent-94a829b6-cd14-459f-8452-ca6c69a704f7\estudos\nome-do-jogo-2026-11-10.md`.

### Objetivo
O **título** do jogo passa a ser **RUNEMOIRE** em tudo que o jogador e a loja veem. A palavra "grimório" como conceito do jogo continua (o deck é o "grimório", "Selos do Grimório", "Escolha 1 carta para o seu grimório").

### Passos
1. **Inventário primeiro:** listar onde o título "Grimoire"/"GRIMOIRE" aparece como **nome do jogo**: `menu.title` nos 5 idiomas, logo do menu (`tools/menu_brand.py` → selo + palavra assados, `src/ui/MenuBrand.lua`), abertura datilografada (`IntroTube`), título da janela, `tools/build_release.py` (`Grimoire.exe`, nome do .love e do depot), textos de conquistas (`tools/achievement_text.py`), tela de erro/crash, créditos, README, CLAUDE.md. Separar do uso de "grimório" como conceito (não muda).
2. **Logo:** refazer o logo do menu com RUNEMOIRE no mesmo estilo (mesmo selo, mesma fonte e efeitos). Mostrar antes/depois em imagem ao Lead **antes** de aplicar.
3. **Trocar** o título nos pontos do inventário, nos 5 idiomas (o nome não se traduz).
4. **Não mudar:** `identity` do `conf.lua` (pasta do save; nunca tocar o save real), ids e API names `ACH_*` das conquistas (eternos), nomes de arquivos internos/branches, histórico de handoffs.
5. **Trailer:** só listar onde o logo/nome aparece nos cortes (gameplay e 13c). Não renderizar nada nesta frente.
6. Rodar a suíte (`suite_lock.sh`) e as travas afetadas (`test_menu_brand`, `test_intro_tube`, `test_no_hardcoded_pt`, `test_achievements`).

### Limites
- Só headless, 1 `lovec` por vez, nunca o save real, nunca matar processo por nome.
- Branch própria, commits em nome de Daniel Cortez, sem Co-Authored-By nem menção a Claude/Grok/Codex, sem push, sem merge na main sem o Lead revisar.
- Nada pago, nada na Steam, nada publicado. Não registrar domínio nem criar contas.

### Pronto quando
Inventário com o que mudou e o que ficou (e por quê), imagem antes/depois do logo e do menu, suíte passando, lista dos pontos do trailer, branch e commits.

## Ampliação (Daniel, 10/11/2026): "trocar em todos os lugares, até nos trailers, tudo de tudo, revisão completa"
Substitui o passo 5 (trailer só listar). Agora a troca é **completa**, em frentes (regra 19, no máximo 3 ao mesmo tempo, nunca duas nos mesmos arquivos):

- **Frente A — jogo (primeiro):** passos 1 a 4 e 6 acima. O logo novo do menu é a fonte única do nome para o resto. Mandar antes/depois ao Lead.
- **Frente B — trailers (depois que o logo da A for aprovado pelo Lead):** trocar o nome/logo em **todos** os trailers vigentes e re-renderizar com nomes novos, sem sobrescrever os antigos: trailer de gameplay (`grimoire_gameplay_*` → `runemoire_gameplay_*`, 1080p/720p/mobile < 25 MB) e o corte cinematográfico 13c (`runemoire_trailer_c13c_*`). Render **um por vez**. Mesmas medidas de som (LUFS/true peak). Os pipelines (`tg_build.py`, `edl.py`, `build_video.py`, gerador do cartão de logo) passam a usar RUNEMOIRE por padrão, para os trailers futuros já saírem certos.
- **Frente C — documentos do projeto (pode correr junto com a A, arquivos diferentes):** README, CLAUDE.md (§1 e onde o nome do jogo aparece), `memory/*.md` do repo (MEMORY.md, menu_branding, release_pipeline, steam_achievements etc.), roteiros e textos aprovados do trailer, página da loja/descrições em `tools/`. Escrever "Runemoire (antes Grimoire)" na primeira menção de cada arquivo. Não reescrever histórico de handoffs/revisões antigas: só um aviso no topo do handoff principal de cada trailer.
- **Fora do repo (o Lead faz):** status, spec do bot, memória do projeto, avisos.

### Revisão completa (obrigatória antes de "pronto")
1. Busca final no repo e nos pipelines do trailer por `Grimoire|GRIMOIRE|grimoire` (inclusive em imagens/fontes assadas: logo, cartões, ícones, splash) e classificar cada ocorrência que sobrou: **nome do jogo** (erro, trocar) ou **conceito/id interno** (fica, com motivo).
2. Capturas headless do menu, abertura, tela de erro e conquistas em pt_BR e em mais 1 idioma, mostrando RUNEMOIRE.
3. Quadros dos trailers novos nos momentos do logo/nome.
4. Revisão independente (revisor sem o seu contexto) com nota ≥ 9 em: nome certo em tudo que o jogador e a loja veem; logo fiel ao estilo antigo; nada quebrado (suíte); trailers sem resto de "Grimoire".

## Entrega (grimoire-dev, 2026-11-10)

**Revisão independente: PASSA na rodada 3, nota 9 nos 4 critérios** (nome, logo, nada quebrado, trailers). Rodada 1: não passou (trailers 8, pipelines ainda com o logo antigo). Rodada 2: não passou (suíte 8). Arquivos: `C:\Users\corte\OpenBot\Agents\agent-ea3ceccd-cade-4621-9506-561542dc2bf9\work\rev_rune\revisao-{1,2,3}.md`.

### Branches e commits (Daniel Cortez, sem Co-Authored-By, sem push, sem merge)
- **Jogo:** `nome-runemoire` (worktree `E:\dev\projects\card-game-runemoire`, base `998dbffe`). Commits:
  - `3a9ce110`: títulos.
  - `0e93ab3d`: logo.
  - `159676b2`: arte da loja.
  - `8a275682`: `build_video` do trailer-do-zero com o logo novo.
- **Documentos:** `nome-runemoire-docs` (worktree `E:\dev\projects\card-game-runemoire-docs`, base `972bcd3d`): `39e672e8`, `15e6d50a` e esta entrega.
- **Pipeline do trailer:** `runemoire-trailer` (worktree `E:\dev\projects\card-game-trailer`, criada a partir de `steam-store-v2`; **esse worktree agora está nessa branch**): `14f17c23`, `369b9316`.
- **Trailer de gameplay:** `trailer-gameplay` (worktree `E:\dev\projects\card-game-trailer-gameplay`): `c4b48ffd`, `4a7c4185`.

### O que mudou
- **Título RUNEMOIRE/Runemoire:**
  - `menu.title` e `window_title` nos 5 idiomas e `t.window.title`.
  - Tarja "AV-1 RUNEMOIRE" do menu.
  - `Release.GAME_NAME` (tela e log de erro: "== Runemoire crash ==").
  - `build_release.py` (`Runemoire.exe`/`.love`), `THIRD_PARTY_NOTICES` e o vdf.
- **Logo do menu:** mesmo selo, fonte, bisel, contorno e sombra (`store_art.TITLE`). A palavra tem 289 px e `wordMaxW` passou para 0,46. Aprovado pelo Lead antes de aplicar.
- **Loja (`steam/store`):**
  - Capsules e logo da biblioteca refeitos. O logo da biblioteca usa a escala inteira que cabe em 1280.
  - Ícone com "R".
  - `01_menu` en/pt_BR refeita; `screenshot_menu_v2` agora pula a vinheta.
- **Trailers** (nomes novos; os antigos ficaram intactos):
  - `build\trailer\runemoire_gameplay_{1080p,720p,mobile}.mp4`: 69,42 s, −14,1 LUFS; celular com 20,1 MiB em H.264.
  - `build\trailer\runemoire_trailer_c13c.mp4` e `_720p.mp4`: 79,92 s, −14,1 LUFS, −1,3 dBTP.
  - Projeto editável do 13c em `build\timeline_runemoire_c13c\`.
  - Cartão do logo em `build\trailer\brand_runemoire\`.
  - Fora do logo, o 13c novo difere do antigo só nas partículas aleatórias dos textos e transições.
- **Pipelines com RUNEMOIRE por padrão:**
  - `store_art.TITLE`, `trailer_brand` → `brand_runemoire`.
  - `trailer_v3` (`brand:logo_*`).
  - Cortes 13/13c com nomes `runemoire_*` e um som por letra.
  - `render_c13c.sh`, exportadores do projeto editável.
  - `tg_build`/`tg_edl` e `build_video`, com recorte do logo calculado.
- **Documentos:** README da loja, CLAUDE.md, `memory/*.md` e `docs/plan` com "Runemoire (antes Grimoire)" na 1ª menção. Aviso no topo de `trailer-do-zero.md`, `trailer-kinetic.md` e `trailer-gameplay.md`.

### O que ficou (e por quê)
- **Identidade do save** (`Release.IDENTITY_RELEASE = "Grimoire"`, identity do conf): trocar perde os saves.
- **Ids `ACH_*`:** são eternos.
- **"Grimório" como conceito:**
  - O deck do jogador.
  - "Selos do Grimório".
  - As conquistas "Grimoire Trinity", "Pocket Grimoire" e "…Grimoire Seal".
  - O item da loja "Grimoire" (+1 DRAW).
  - O contador do deck e os textos em alemão e francês sobre o deck.
- **Ids internos:**
  - `GrimoirePage`.
  - `GRIMOIRE_SELFTEST`/`GRIMOIRE_CRASH_SHOT`.
  - A família da fonte "Grimoire Pixel": é nome interno; a OFL só proíbe "Press Start 2P".
  - O metadado da fonte.
  - Os nomes de arquivo `grimoire_*`.
- **Histórico** de handoffs e revisões: não foi reescrito.

### Testes
- **Travas:**
  - `test_menu_brand` 164/0.
  - `test_intro_tube` 82/0.
  - `test_no_hardcoded_pt` 3/0.
  - `test_achievements` 777/0.
  - `test_release` 14/0.
  - `test_locale_glyphs` 9/0.
- **Suíte completa (`suite_lock.sh`):**
  - 1ª rodada: **172/172**.
  - 2ª rodada, no HEAD final: 169/3. As 3 que falham são `test_scene_continuity`, `test_fork_sequence` e `test_fork_flow` ("road chao_muda"). **Falham também no código anterior à troca de nome** (`998dbffe`, rodado no checkout da main), em quadros que mudam a cada rodada.
  - Instabilidade **anterior** à frente, fora do escopo. Precisa de uma frente própria.

### Capturas (antes/depois)
Ficam em `C:\Users\corte\OpenBot\Agents\agent-ea3ceccd-cade-4621-9506-561542dc2bf9\work\rune\`:
- `menu_antes_depois.png`, `logo_antes_depois.png`, `wordmark_antes_depois.png`.
- `loja_antes_depois.png`.
- `revisao_capturas.png`: abertura, menu e conquistas em pt_BR e en, e os quadros do logo nos dois trailers.
- `c13c_cmp.png`.

### Para o Lead e o Daniel
- **Merge** das 4 branches: com o Lead. A branch de documentos e a do jogo mexem em arquivos diferentes.
- **Teste da estrada instável:** abrir uma frente para ele.
- **Nada na Steam:** a arte nova da loja está só no repo.

### Hashes reescritos (10/11/2026, autor e committer corrigidos para Daniel Cortez <cortezjuninho@hotmail.com>)
Conteúdo e mensagens iguais (árvores idênticas); só os commits desta sessão mudaram, os antigos mantêm o hash.
- **nome-runemoire:**
  - 3a9ce110 → abaed706
  - 0e93ab3d → 24f12eaf
  - 159676b2 → 2d4fc154
  - 8a275682 → 3df4b1ac
- **nome-runemoire-docs:**
  - 39e672e8 → ac2682aa
  - 15e6d50a → ca37f2b6
  - 6062e71b → b17a1de2
- **runemoire-trailer:**
  - 14f17c23 → 92ce4907
  - 369b9316 → 0d1a818a
- **trailer-gameplay:**
  - ef4ae1b6 → b347b0da
  - 95d77404 → 7972e39e
  - 86f30da6 → 29eadb7a
  - b673fee2 → 94bf104a
  - ea65ab46 → 7f9f0ea7
  - cf6e7a86 → 2c4a6d04
  - 85d630b4 → fe7baffa
  - c4b48ffd → ae7dc304
  - 4a7c4185 → 9e4122d1
