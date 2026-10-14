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
`--love-dir` / `LOVE_DIR`). Icone + versao do .exe via rcedit, procurado em
`RCEDIT=...\rcedit-x64.exe`, no PATH ou em `tools/vendor/rcedit-x64.exe`
(gitignored; baixar de https://github.com/electron/rcedit/releases — v2.0.0
em Out/2026). Sem ele: aviso e o .exe fica com o coracao do LOVE (a JANELA
usa `assets/branding/icon.png` via conf.lua de qualquer jeito).

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
   .md/.py/.sh/.bat, .mp4 (modulo video desligado), .ico (so serve ao
   rcedit), README*, e `EXCLUDE_PREFIXES` (vazio desde a limpeza de assets).
2. **Strip de comentarios** com lexer Lua proprio (strings curtas com escape,
   longas `[[ ]]`/`[==[ ]==]`, comentarios longos, shebang). **Quebras de
   linha preservadas**: linha N do pacote = linha N do repo, entao o crash
   log do jogador aponta direto pro fonte. Indentacao e espaco final saem.
   Desde Out/2026 o REPOSITORIO tambem nao tem comentario (pedido do dono,
   ver [[code_hygiene]]); o lexer mora em `tools/luastrip.py`, compartilhado
   com a trava `test_no_comments_no_prints`. O strip do build continua
   rodando (idempotente) e preserva o numero de linhas.
3. **Prova de equivalencia**: o proprio lovec compila original e limpo e
   compara `string.dump(f, true)` byte a byte. Diferenca = build reprovado.
   (Testado com adulteracao proposital: pega.)
4. **test_all na copia limpa** (inclui `VERIFY_EXTRA_PREFIXES` = tools/ +
   steam/achievements/ so nessa copia — test_achievements le os icones e o
   json da Steam; identidade `card-game-build-verify`). Teste novo que le
   arquivo fora do runtime? Acrescente o prefixo la, NAO enfraqueca o teste.
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
| `print` (so Release.lua/Debug.lua/tools) | console (+ ring buffer) | `logs/last_session.log` (+ `previous_session.log`), buffer, teto 2 MB |
| `Debug.log/trace/warn/err` | MUDO; `CARDGAME_DEBUG=1` liga (2 = trace) | `warn`/`err` vao pro log sempre; log/trace so com a variavel (Out/2026, [[code_hygiene]]) |
| feel_debug.log / reward_debug.log | sim | nao gravam |
| GF_DEBUG (prova magenta da grama) | env var | ignorado (`Release.isDev()` no WorldRoad) |
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

## Laco principal e encerramento — `src/core/AppLoop.lua` (Out/2026)

`Release.install()` troca o `love.run` ANTES do wrapper do selftest (que
envolve o laco vigente — o smoke do exe exercita o laco real). Medido no exe
de release, menu, 10 s por estado (`TotalProcessorTime` do PID lancado, com
outras frentes rodando balance_sim na maquina — foco oscila 18-44% entre
medicoes nos DOIS builds, e o mesmo caminho de codigo):

| estado | antes | depois |
|---|---|---|
| foco (menu, vsync) | 21-35% | igual (sem mudanca de proposito) |
| minimizado | 26-34% | **0,5-4%** (8 fps, sem draw) |
| visivel sem foco | 25-35% | **5,6%** (15 fps) |

Regras: foco+vsync = igual ao padrao; vsync DESLIGADO = teto na taxa do
monitor (60..240); `dt` com teto 0,25 s; ferramentas (`HEADLESS_TOOL`)
nunca estrangulam. Trava: `test_app_loop`. Testado e DESCARTADO: dormir
antes do `present` com foco (ate 1/hz - 4 ms) — a CPU subiu (28-36% vs
20-22%): o custo do menu e trabalho real da cena, nao spin do driver.

**Encerramento**: o evento `quit` passa por `AppLoop.shutdown()` depois de
`love.quit` (se alguem definir um e nao cancelar): grava monitor/posicao da
janela (`WindowPlacement.remember` → settings.lua), `SteamBridge.shutdown()`,
`Release.flushLog()`. Fica no laco e NAO num `function love.quit` do main.lua
(um love.quit definido depois por outra frente o apagaria em silencio).
Saves sao sincronos (atomicWrite) — nao ha escrita pendente a esperar.

**Monitor**: `src/core/WindowPlacement.lua` — settings.lua ganha
`windowDisplay/windowX/windowY` (chaves extras, `loadSettings` preserva). No
boot a janela vai pro monitor salvo antes do setFullscreen/setMode; monitor
que sumiu cai no 1; posicao que nao cabe centraliza.

**Erro antes do love.load em DEV com argumento** (ex.: modulo novo NAO
rastreado pelo git → a copia do build nao o tem → `require` quebra na 1a
linha do main.lua): o errorhandler olha o argumento cru e sai com 1. Antes
abria a tela azul e o build ficava pendurado ate o timeout de 30 min.
Lembrete: o build so empacota arquivo RASTREADO — `git add` o modulo novo.

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
- `steam/steam_appid.dev.txt` (480 = Spacewar): pra testar a API num exe
  LOCAL, copiar como `steam_appid.txt` ao lado dele. O depot exclui
  `steam_appid.txt` (em producao a Steam injeta o AppID).
- Launch option: executavel `Grimoire.exe`, sem argumentos (release ignora).

### Steamworks / luasteam — o que o DONO precisa fazer

O codigo ja esta pronto (`SteamBridge` + `AchievementSystem.install` +
`runCallbacks` no love.update + shutdown no AppLoop). Falta binario e painel:

1. **luasteam** (github.com/uspgamedev/luasteam/releases): baixar o build
   **Windows x64 para LuaJIT** (o LOVE 11.x e LuaJIT 2.1) → `luasteam.dll`.
2. **Steamworks SDK** (partner.steamgames.com → SDK, conta de parceiro):
   `sdk/redistributable_bin/win64/steam_api64.dll` da MESMA versao de SDK
   contra a qual o luasteam foi compilado (ver release notes do luasteam).
3. Soltar os dois em `vendor/steam/` na raiz do repo (gitignored — nao
   commitar binario). O build copia pra `windows/` e pro depot e loga
   `Steamworks: ... incluidas`; sem eles imprime o bloco `[AVISO STEAM]`
   (nao e silencioso) e o jogo roda so com conquistas locais. So um dos
   dois presente = build REPROVADO.
4. Trocar `APP_ID` / `DEPOT_ID` em `steam/app_build_windows.vdf` e
   `steam/depot_build_windows.vdf` pelos do painel.
5. Teste local: `steam/steam_appid.dev.txt` (480) ou um com o AppID real
   copiado como `steam_appid.txt` ao lado do `Grimoire.exe` LOCAL, Steam
   aberta, e procurar `[SteamBridge] Steam ATIVA` em
   `%APPDATA%/Grimoire/logs/last_session.log`.
6. Cadastrar as conquistas (checklist em memory/steam_achievements.md).

### Steam Cloud — Auto-Cloud (sem API)

Steamworks → App Admin → Cloud: root `WinAppDataRoaming`, subdir `Grimoire`.
- **sincronizar**: `profile.lua`, `unlocks.lua`, `achievements.lua`,
  `run.save.lua`, `i18n_settings.lua` (perfil + run em andamento + idioma);
- **NAO sincronizar**: `settings.lua` (volume, fullscreen, vsync e MONITOR
  da janela sao da maquina — o monitor 2 do PC nao existe no notebook),
  `logs/`, `crashes/`, `*.tmp`, `*.tool.lua`, `migrated_from_dev.txt`.
Use padroes explicitos por arquivo (NAO `*.lua`, que pegaria settings.lua).
Conferir os nomes contra `Release.MIGRATE_FILES` e `PATHS` do
`engine/SaveManager.lua` antes de publicar — save novo entra nas duas listas.

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

- Icone do .exe: rcedit em `tools/vendor/` (gitignored) — maquina nova
  precisa baixar de novo (ver Comando).
- Assinatura de codigo (Authenticode) do .exe: opcional na Steam, reduz
  alerta do SmartScreen fora dela.
- PNG legados enormes (`assets/icons/*.png` ~2 MB cada desenhados a escala
  0.05): reexportar menores reduziria o pacote em ~20 MB.
- Shaders (.glsl) ja saem sem comentario do proprio repositorio (Out/2026);
  o build nao faz strip de GLSL e nao precisa.
