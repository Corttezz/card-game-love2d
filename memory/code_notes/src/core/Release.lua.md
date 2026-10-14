---
name: code_notes/src/core/Release.lua
description: Comentários com decisão/regra/histórico colhidos de src/core/Release.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/core/Release.lua`

Origem: `src/core/Release.lua` em `7dbdb60d` (16 de 21 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-25 (junto a `local Release = {}`)

> src/core/Release.lua
> Modo DEV x RELEASE, log em arquivo, tela de erro amigavel e self-test.
>
> FLAG UNICA: a presenca do arquivo `build_info.lua` na RAIZ do jogo. Ele nao
> existe no repositorio (esta no .gitignore) — so o `tools/build_release.py`
> o escreve dentro da copia de release. Sem ele, o jogo e DEV. Assim nao ha
> "esqueci de desligar o debug antes de publicar": o build e quem decide.
>
> Este modulo e carregado pelo conf.lua (antes de qualquer modulo love.*
> existir) — por isso nada aqui toca `love.*` no escopo do arquivo.
>
> O que muda em RELEASE:
> * conf.lua: sem console, identidade "Grimoire" (save dir proprio);
> * argumentos de linha de comando sao ignorados (dispatcher de tools/
> testes inacessivel — e tools/ nem vai no pacote);
> * atalhos de dev desligados (Release.isDev() nos pontos de teclado);
> * print() vira log em arquivo no save dir (logs/last_session.log);
> * erro fatal mostra tela traduzida + caminho do crash log, nao o
> stacktrace azul do LOVE (o crash log tem o stacktrace completo).
>
> Self-test (qualquer modo): variavel de ambiente GRIMOIRE_SELFTEST=1. O
> jogo boota de verdade, pula o splash, renderiza todas as cartas, abre uma
> run de cada classe, desenha o menu por alguns segundos e sai com codigo
> 0 (ok) ou 1 (falha), gravando selftest_result.txt no save dir. E o que o
> smoke do executavel fundido usa (sem console nao ha stdout pra ler).

## L31-32 (em `Release`, junto a `if not tostring(info):find("build_info' not found", 1, true)`)

> Ausente = DEV (estado normal do repositorio). Presente mas quebrado
> NAO pode virar DEV em silencio: o pacote sairia com console e atalhos.

## L49-50 (em `info`, junto a `Release.IDENTITY_DEV     = "card-game"`)

> Identidade (pasta de save). DEV mantem a historica pra nao orfanar os
> saves de quem ja joga pelo `love .`; RELEASE usa o nome do jogo.

## L68-70 (em `Release.selftestRequested`, junto a `function Release.filterArgs(args)`)

> Em release, NENHUM argumento chega ao dispatcher do love.load: o Steam e o
> Windows podem passar flags proprias, e o dispatcher inteiro (tools/testes)
> nao existe no pacote — um `require("tools.x")` derrubaria o jogo.

## L79-83 (em `Release.filterArgs`, junto a `local RING_MAX = 300`)

> LOG
>
> Ring buffer das ultimas linhas impressas (dev e release): o crash log
> anexa o que aconteceu logo antes do erro.

## L87-88 (em `Release.filterArgs`, junto a `local LOG_FILE      = "logs/last_session.log"`)

> Release: buffer em memoria, descarregado em lote (abrir arquivo a cada
> print custaria I/O por frame nos pontos ruidosos).

## L138-139 (em `openLog`, junto a `function Release.installLogging()`)

> Troca o print global. DEV: continua no console + ring. RELEASE: ring +
> arquivo (nao ha console).

## L169-175 (em `Release.version`, junto a `Release.MIGRATE_FILES = {`)

> MIGRACAO DE SAVE (release)
>
> O jogo fundido salva em %APPDATA%/Grimoire; o `love .` de desenvolvimento
> salva em %APPDATA%/LOVE/card-game. Quem jogou a versao de teste nao deve
> perder perfil/conquistas/configuracoes no primeiro boot do executavel.
> Copia UMA vez, so se o save dir novo estiver vazio dos arquivos conhecidos.

## L274-276 (em `utf8safe`, junto a `function Release.errorhandler(msg)`)

> love.errorhandler. DEV delega ao handler padrao do LOVE (stacktrace na
> tela e no console e o que o desenvolvedor quer), mas grava o crash log
> antes. RELEASE mostra a tela amigavel.

## L288-293 (em `Release.errorhandler`, junto a `local okArgs, gameArgs = pcall(function() return love.arg.parseGameArguments(arg) end)`)

> Tool/teste (`love . <arg>`) que quebra SAI com codigo 1: o handler
> padrao abre a tela azul e espera alguem fechar — uma suite quebrada
> ficava pendurada ate o timeout de quem a chamou.
> Erro ANTES do love.load (require quebrado no topo do main.lua) ainda
> nao tem HEADLESS_TOOL: olha o argumento cru — senao o build de release
> ficava 30 min pendurado na tela azul do test_all da copia limpa.

## L364-365 (em `fontCache`, junto a `local shotFrames = os.getenv("GRIMOIRE_CRASH_SHOT") and 0 or nil`)

> Validacao automatica da tela (o smoke nao enxerga janela): com
> GRIMOIRE_CRASH_SHOT=1 grava crash_screen.png no save dir e fecha.

## L393-394 (em `report`, junto a `local CardDatabase = require("src.systems.CardDatabase")`)

> 1) Todas as cartas instanciam e renderizam a moldura (pega PNG que
> faltou no pacote).

## L404-405 (em `report`, junto a `local prev = _G.HEADLESS_TOOL`)

> 2) Uma run de cada classe sobe e entra em batalha. Saves no sandbox
> *.tool.lua (o SaveManager le a flag na hora da escrita).

## L424-427 (em `report`, junto a `local function installSelftest()`)

> Envolve o love.run padrao: roda o jogo de verdade e injeta o roteiro.
> GRIMOIRE_SELFTEST=crash: em vez de passar, provoca um erro depois do boot
> pra exercitar a tela de erro e o crash log do PACOTE (com
> GRIMOIRE_CRASH_SHOT=1 a tela vira crash_screen.png e o processo sai com 1).

## L464-465 (em `love.run`, junto a `function Release.install()`)

> Chamado na PRIMEIRA linha do main.lua (antes dos requires do jogo), pra
> que um erro ja no carregamento dos modulos passe pelo handler.

## L473-474 (em `Release.install`, junto a `require("src.core.AppLoop").install()`)

> Laco com teto de quadros fora de foco + shutdown ordenado. ANTES do
> selftest, que envolve o love.run vigente (o smoke roda o laco real).

