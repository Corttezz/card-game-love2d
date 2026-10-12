---
name: Release Pipeline — build limpo, modo DEV/RELEASE, executavel fundido e Steam
description: Como gerar o pacote de publicacao (tools/build_release.py), o que muda no jogo em RELEASE (src/core/Release.lua), tela de erro e crash log, identidade de save, smoke do executavel, riscos de licenca/segredo e checklist da loja Steam.
type: project
---

# Release Pipeline (Out/2026)

## Comando

```
python tools/build_release.py            # build completo (~5-8 min com test_all)
python tools/build_release.py --skip-tests   # iteracao rapida (~1 min)
python tools/build_release.py --bytecode     # pacote em bytecode LuaJIT (so Windows x64)
python tools/build_release.py --allow-dirty  # permite working tree sujo
```

Exige working tree limpo (o pacote sai dos arquivos RASTREADOS pelo git:
o que nao foi commitado nao entra). LOVE em `C:\Program Files\LOVE` (ou
`--love-dir` / `LOVE_DIR`). Icone do .exe: defina `RCEDIT=...\rcedit-x64.exe`
(https://github.com/electron/rcedit); sem ele o .exe fica com o coracao do
LOVE (a JANELA ja usa `assets/branding/icon.png` via conf.lua).

Saida:
- `build/release/<versao>/Grimoire.love` — zip (png/mp3 STORED, texto deflate)
- `build/release/<versao>/windows/` — `Grimoire.exe` (love.exe + .love
  concatenados), 7 DLLs do LOVE, `license.txt`, `THIRD_PARTY_NOTICES.txt`
- `build/steam/windows/content/` — copia identica, e o ContentRoot do depot
- `build/release/<versao>/build_report.txt` — tamanhos + assets suspeitos de
  nao terem referencia (heuristica, so relatorio — nada e podado sozinho)
- `build/release/<versao>/crash_screen_check.png` — a tela de erro do pacote

Tamanho em 0.9.2: .love 58,7 MB, pasta windows 68,4 MB.

## As 6 etapas (o script para no primeiro erro)

1. **Selecao**: `git ls-files` ∩ runtime (conf/main + components/ engine/ src/
   shaders/ assets/ audio/). Fora: tools/, docs/, memory/, scratchpads,
   .md/.py/.sh/.bat, .mp4 (modulo video desligado), README*, e
   `EXCLUDE_PREFIXES` (tileset act1_catacumbs, sem referencia).
2. **Strip de comentarios** com lexer Lua proprio (strings curtas com escape,
   longas `[[ ]]`/`[==[ ]==]`, comentarios longos, shebang). **Quebras de
   linha preservadas**: linha N do pacote = linha N do repo, entao o crash
   log do jogador aponta direto pro fonte. Indentacao e espaco final saem.
   O REPOSITORIO NUNCA perde comentario — decisao do dono: comentario e a
   documentacao viva; so a copia de build sai limpa.
3. **Prova de equivalencia**: o proprio lovec compila original e limpo e
   compara `string.dump(f, true)` byte a byte. Diferenca = build reprovado.
   (Testado com adulteracao proposital: pega.)
4. **test_all na copia limpa** (inclui tools/ so nessa copia, identidade
   `card-game-build-verify`).
5. **Empacota**: escreve `build_info.lua` (a flag de RELEASE), zip, funde.
6. **Smoke do executavel fundido**: `GRIMOIRE_SELFTEST=1` (boot real, pula o
   splash por tecla, renderiza as 128 cartas, abre run das 3 classes, desenha
   o menu ~4s, exit 0 + `selftest_result.txt`) e depois
   `GRIMOIRE_SELFTEST=crash` + `GRIMOIRE_CRASH_SHOT=1` (erro induzido → tela
   amigavel capturada + crash log, exit 1 esperado). Identidade
   `grimoire-selftest`, apagada no fim.

## Bytecode: avaliado, NAO e o default

`--bytecode` funciona (smoke verde): o bytecode e gerado pelo MESMO lovec
que vai no pacote, entao VM e flags batem no Windows x64. Nao e default
porque bytecode LuaJIT 2.1 nao e portavel entre builds (GC64/FR2): um pacote
mac/linux futuro exigiria gerar com o LOVE daquela plataforma. Ganho real e
so ofuscacao leve; o .love fica ate 0,3 MB MAIOR. Com debug info mantida, o
crash log continua com arquivo:linha.

## Modo DEV x RELEASE — `src/core/Release.lua`

**Flag unica = presenca de `build_info.lua` na raiz** (gitignored; so o build
escreve). Ausente = DEV. Presente mas quebrado = RELEASE + aviso (nunca vira
DEV em silencio). `test_release` trava que o repo e DEV.

| | DEV (`love .`) | RELEASE (pacote) |
|---|---|---|
| console (conf.lua `t.console`) | sim | nao |
| save dir | `%APPDATA%/LOVE/card-game` | `%APPDATA%/Grimoire` (fundido: sem `LOVE/`) |
| argumentos / dispatcher de tools | normal | `Release.filterArgs` → `{}` |
| atalhos `r`, `0-4` (GameplayScene) | sim | desligados |
| `print` | console (+ ring buffer) | `logs/last_session.log` (+ `previous_session.log`), buffer, teto 2 MB |
| `Debug.log/warn` | sim | silenciado (`Debug.err` vai pro log) |
| feel_debug.log / reward_debug.log | sim | nao gravam |
| GF_DEBUG (prova magenta da grama) | env var | ignorado |
| erro fatal | crash log + handler padrao do LOVE | crash log + tela traduzida (`crash.*`) com caminho do log; Esc fecha, C copia |

- `CARDGAME_IDENTITY` sobrepoe a identidade nos dois modos (frentes paralelas
  e smoke nao pisam no save real).
- `Release.install()` e a 1a linha do main.lua (sem `local`: teto de 60
  upvalues do love.load). Instala errorhandler, troca o print, migra save.
- **Migracao**: no 1o boot do RELEASE, se o save dir novo nao tem nenhum dos
  `Release.MIGRATE_FILES`, copia de `%APPDATA%/LOVE/card-game/` (quem jogou a
  versao de dev nao perde perfil/conquistas). Marca `migrated_from_dev.txt`.
  **Arquivo de save NOVO? acrescente em `Release.MIGRATE_FILES`.**
- Crash log: `crashes/crash_<data>.txt` = versao/commit/OS/GPU + stacktrace +
  ultimas 300 linhas impressas.

## Save e DADO, nao codigo

`SaveManager.loadDataChunk(path)`: le texto, recusa bytecode (`\27`),
`loadstring` + `setfenv(chunk, {})`. Antes, `love.filesystem.load` dava a um
save baixado da internet / sincronizado pelo Steam Cloud acesso a `os`/`io`.
I18n.loadSetting idem. ProfileStats le via `SaveManager.readDataFile` (mesma
regra, com recuperacao — secao abaixo).

## Escrita atomica e recuperacao (Out/2026)

`SaveManager.writeFile(path, text)` e o UNICO caminho de gravacao de perfil,
run e settings: `<path>.tmp` lido de volta (bytes + parse + tabela) → o
principal atual, se BOM, vira `<path>.bak` (uma geracao; principal ruim vai
pra `<path>.corrupt-<ts>` e nunca vira .bak) → promocao por `os.rename` no
`getSaveDirectory()` (love.filesystem nao tem rename). Fallback quando o
rename falha (Windows: destino existente, caminho nao-ASCII na codepage
ANSI): escreve o final direto e confere lendo de volta; .tmp e .bak cobrem a
janela. Leitura (`readDataFile`): principal → .tmp → .bak, aviso alto no
console. Perfil sem nenhuma geracao legivel = **modo recuperacao**
(`ProfileStats.isRecoveryMode()`): joga com defaults em memoria e NUNCA grava
por cima do arquivo danificado. `deleteRun`/`quarantineRun` apagam as tres
geracoes (senao a run abandonada voltava pelo .bak). Trava:
`love . test_one test_save_integrity`. (`i18n_settings.lua` ainda grava
direto — so guarda o locale; trocar quando a frente de i18n liberar o arquivo.)

**Steam Auto-Cloud** (configurar no app admin, root `WinAppDataRoaming`,
subdir `Grimoire/`):
- SINCRONIZAR: `profile.lua` (conquistas, desbloqueios, maestria, vitorias),
  `run.save.lua` (run em andamento), `unlocks.lua`/`achievements.lua` se
  existirem (legado do MIGRATE_FILES).
- NAO sincronizar: `settings.lua` e `i18n_settings.lua` (volume, fullscreen,
  vsync e idioma sao por maquina), `*.tmp`, `*.bak`, `*.corrupt*`,
  `logs/`, crash logs, `migrated_from_dev.txt`, `*_debug.log`,
  `selftest_result.txt`, e todo `*.tool.lua` (sandbox de ferramenta).
  Padroes de inclusao explicitos (`profile.lua`, `run.save.lua`), nunca `*`.

## Riscos de publicacao encontrados (Out/2026)

- **Token vazado**: `docs/conversas/b8adfea6_worldroad_castelos.md` tinha um
  Bearer JWT (Cognito us-east-1, conta PixelLab) colado de `~/.claude.json`.
  Redigido no arquivo; **continua no historico git (commit 3fc14ea)**. O JWT
  ja expirou (exp jun/2026), mas: encerrar sessoes/rotacionar na PixelLab, e
  se o repo for publico um dia, reescrever historico (git filter-repo).
- Chave ElevenLabs: NAO esta no repo (scripts leem `ELEVENLABS_API_KEY` do
  ambiente). Fica so na auto-memoria do Claude — o dono ja planeja rotacionar.
- **Licenca ElevenLabs (ALTO)**: SFX e as 9 faixas de musica foram gerados na
  conta FREE. O plano gratuito do ElevenLabs nao concede uso comercial (exige
  atribuicao e nao-comercial; licenca comercial vem com plano pago). Antes de
  vender: assinar plano pago e REGERAR (ou confirmar por escrito com o
  ElevenLabs que o conteudo antigo fica coberto).
- **PixelLab (MEDIO)**: ToS concede uso comercial a assinantes; confirmar que
  toda arte foi gerada com assinatura ativa.
- **Steam exige declarar conteudo gerado por IA** (Content Survey, "pre-
  generated AI content") — arte PixelLab + audio ElevenLabs entram nisso.
- **Proveniencia desconhecida**: `audio/music.mp3` (menu), `audio/hoverCard.wav`,
  os PNGs legados de `assets/cards/**`, `assets/icons/*.png`,
  `assets/backgrounds/step1.png`. Documentar origem ou substituir.
- Fonte `assets/fonts/pixel.ttf` = "Grimoire Pixel", versao MODIFICADA da
  Press Start 2P (OFL 1.1, Reserved Font Name "Press Start 2P" — por isso o
  nome novo; maiusculas acentuadas redesenhadas por `tools/font_latin_caps.py`,
  Out/2026): ok comercial, exige o aviso — vai em
  `dist/THIRD_PARTY_NOTICES.txt` (o build falha sem).
- LOVE/SDL/OpenAL Soft/mpg123: `license.txt` do LOVE vai junto; OpenAL e
  mpg123 sao LGPL e seguem como DLL separada (substituivel) — ok.
- `assets/backgrounds/202509071408.mp4` (62 MB) nao e referenciado e nunca
  vai no pacote (o modulo video esta desligado).
- `AudioManager` le `/proc/version` (detecao WSL): no Windows so falha o
  open, inofensivo.

## Steam — `steam/`

- `steam/app_build_windows.vdf` + `steam/depot_build_windows.vdf`: templates
  (trocar `APP_ID`/`DEPOT_ID`). ContentRoot = `build/steam/windows/content/`.
  Upload: `steamcmd +login <conta> +run_app_build <repo>\steam\app_build_windows.vdf +quit`.
  Primeira vez com `"Preview" "1"`. `SetLive` vazio: publicar pela pagina de
  Builds (ou branch beta).
- `steam/steam_appid.dev.txt` (480 = Spacewar): so serve se um dia o jogo
  usar a Steamworks API (hoje NAO usa — luasteam nao esta integrado, entao
  conquistas Steam/Cloud API nao existem). Para testar com API: copiar como
  `steam_appid.txt` ao lado do exe LOCAL. O depot exclui `steam_appid.txt`.
- Steam Cloud sem API: configurar "Steam Auto-Cloud" no Steamworks com root
  `WinAppDataRoaming`, subdir `Grimoire`, padroes `*.lua` (exclua `logs/`,
  `crashes/`).
- Launch option: executavel `Grimoire.exe`, sem argumentos (release ignora).

## Checklist da loja (a fazer pelo dono)

Arte da loja (tamanhos atuais do Steamworks — conferir no painel):
- [ ] Header capsule 920×430 · Small capsule 462×174 · Main capsule 1232×706
- [ ] Vertical capsule 748×896 · Page background 1438×810 (opcional)
- [ ] Library: capsule 600×900, header 920×430, hero 3840×1240, logo 1280×720 (PNG transparente)
- [ ] Community icon 184×184 (JPG) + client icon (.ico — `assets/branding/icon.ico` serve de base)
- [ ] Logo/nome final "Grimoire": checar marca registrada / colisao de nome na Steam
- [ ] 5+ screenshots 1920×1080 (sem UI de debug; usar o pacote de release)
- [ ] Trailer 1080p mp4 (30-90s, gameplay nos 5 primeiros segundos)
- [ ] Descricao curta (≤300 chars) e longa nos 5 idiomas (pt-BR, en, es, fr, de) — marcar os idiomas suportados (interface + legendas)
- [ ] Tags (Roguelike Deckbuilder, Card Game, Pixel Graphics, Strategy, Singleplayer)
- [ ] Requisitos de sistema: Windows 10 64-bit, OpenGL 3.3 (2.1 minimo do LOVE), ~100 MB, 4 GB RAM
- [ ] Content Survey: **conteudo gerado por IA** (ver riscos) + violencia fantasiosa
- [ ] Classificacao etaria IARC (questionario no Steamworks) — DJCTQ Brasil sai daqui
- [ ] Steam Direct (taxa) paga; pagina "Coming soon" no ar ≥2 semanas antes; revisao da build (~3-5 dias uteis)
- [ ] Pagina de creditos/licencas acessivel no jogo (frente "revisor" criando CreditsScreen)

## Pendencias de release conhecidas

- Icone do .exe depende de rcedit (nao instalado nesta maquina).
- Assinatura de codigo (Authenticode) do .exe: opcional na Steam, reduz
  alerta do SmartScreen fora dela.
- PNG legados enormes (`assets/icons/*.png` ~2 MB cada desenhados a escala
  0.05): reexportar menores reduziria o pacote em ~20 MB.
- Shaders (.glsl) vao com comentarios (strip de GLSL nao implementado — baixo
  valor, risco com `#define`).
