---
name: code_notes/engine/SaveManager.lua
description: Comentários com decisão/regra/histórico colhidos de engine/SaveManager.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `engine/SaveManager.lua`

Origem: `engine/SaveManager.lua` em `7dbdb60d` (19 de 35 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `local SaveManager = {}`)

> engine/SaveManager.lua
> Persistência de save (run) e settings. Inspirado em
> balatro-source/engine/save_manager.lua, mas síncrono e com formato Lua.
>
> Diferenças vs Balatro:
> Sem thread (LÖVE/OpenAL não justifica pra escala atual).
> Sem string_packer custom — usa serialize() para Lua source code.
> Atomic write real: .tmp verificado + rename + uma geração .bak (ver writeFile).
> Versioning + migrations runner integrado em loadRun.

## L15-20 (em `SaveManager`, junto a `local PATHS_PLAYER = {`)

> Caminhos relativos ao save directory do LÖVE.
> SANDBOX de ferramenta (_G.HEADLESS_TOOL, setado pelo main.lua quando o
> jogo roda com QUALQUER argumento): run/settings viram *.tool.lua — as
> tools de screenshot/teste chamam startNewRun+checkpointRun e SOBRESCREVIAM
> o save real do jogador ("abandonei a run e ela ressuscita" — o fantasma
> era o save das capturas de validação).

## L40-43 (em `DEFAULT_SETTINGS`, junto a `fullscreen   = true,`)

> Primeiro acesso entra em tela cheia: 1024x768 numa tela moderna lê como
> janelinha, e o jogador novo não sabe que existe a opção. Quem já jogou
> tem o valor no arquivo e este default não o alcança — por isso o
> `love.load` também aumenta a janela de quem escolheu NÃO usar fullscreen.

## L46-47 (em `DEFAULT_SETTINGS`, junto a `crtLevel     = "normal",`)

> CRT em níveis (Out/2026): "off" | "low" | "normal". `crtShader` fica
> como espelho booleano (save antigo só tinha ele: false → "off").

## L50-52 (em `DEFAULT_SETTINGS`, junto a `screenshake   = 1.0,`)

> Acessibilidade Balatro-style (G.SETTINGS.reduced_motion / screenshake).
> screenshake: multiplicador 0..1 da intensidade do shake (1 = full).
> reducedMotion: true desliga juice_up + ambient tilt + screen shake.

## L57-58 (em `DEFAULT_SETTINGS`, junto a `vsync         = true,`)

> Out/2026 (Configurações v3): vsync do monitor e ritmo do combate
> (multiplicador de VELOCIDADE exibido; CombatBeats.speed = 1/x).

## L65-68 (em `DEFAULT_SETTINGS`, junto a `previewDetails = false,`)

> Prévia de dano (src/ui/DamagePreviewPanel): false = só o resumo (dano,
> Bloqueio, LETAL, fichas de combo); true = a conta carta a carta.
> Alterna na própria placa (clique / V / foco+A); sem linha em
> Configurações → Jogo (aba de altura fixa, 5 linhas — test_pause_menu).

## L75-79 (em `DEFAULT_SETTINGS`, junto a `local LUA_KEYWORDS = {}`)

> Serializa table Lua para source code retornável via `return`.
> Suporta number/boolean/string/table com keys string ou number.
> Cycles não são suportados (saves do jogo são DAGs).
> Palavras reservadas não podem ser chave nua (`end = 1` não parseia — e o
> writeFile recusaria o save inteiro por causa de uma chave).

## L118-141 (em `parts`, junto a `SaveManager.quarantined = {}  -- path → arquivo .corrupt já gerado nesta sessão`)

> Escrita atômica de VERDADE (Out/2026 — auditoria de integridade de save).
>
> O que havia antes: escrevia <path>.tmp, validava e depois REESCREVIA o
> <path> final com `love.filesystem.write` — um crash nessa segunda escrita
> deixava o arquivo final truncado, e o perfil (que nem passava por aqui)
> era gravado direto. Perfil truncado → load caía nos defaults → o próximo
> save gravava os defaults por cima: conquistas, desbloqueios e vitórias
> perdidos de uma vez.
>
> Protocolo agora (para TODO arquivo persistente: perfil, run, settings):
> 1. escreve <path>.tmp e LÊ DE VOLTA: bytes iguais + parse + devolve tabela;
> 2. se o <path> atual é válido, ele vira <path>.bak (uma geração só);
> se é inválido, nunca vira .bak (o .bak é a última versão BOA) — vai
> pra <path>.corrupt-<timestamp> antes de ser substituído;
> 3. promove o .tmp com `os.rename` (rename é atômico no mesmo volume).
> love.filesystem não tem rename, então o caminho real sai de
> `getSaveDirectory()`. No Windows o rename falha com destino existente
> (por isso o destino é removido antes) e falha com caminho não-ASCII
> (os.rename usa a codepage ANSI; usuário "José" existe) — o FALLBACK
> escreve o final direto e confere lendo de volta. Nesse fallback a
> janela de risco é coberta pelos outros dois: o .tmp (novo, válido) e o
> .bak (anterior, válido) seguem no disco até o final conferir.
> Leitura (readDataFile): <path> → <path>.tmp → <path>.bak, o primeiro que
> parseia. Principal ilegível é copiado pra .corrupt-<ts> e AVISA alto.

## L178-179 (em `quarantine`, junto a `function SaveManager.writeFile(path, text, validate)`)

> Grava `text` em `path` com o protocolo acima. `validate(text)` opcional
> (default: decodeData). Devolve true ou false, motivo.

## L233-237 (em `atomicWrite`, junto a `function SaveManager.readDataFile(path)`)

> Lê um arquivo de dados com recuperação. Devolve value, info:
> info.source      "main" | "tmp" | "bak" | nil (nada legível)
> info.existed     algum dos três arquivos existia
> info.mainCorrupt o principal existia e não parseou
> info.corruptCopy caminho da cópia .corrupt-<ts>

## L265-268 (em `order`, junto a `function SaveManager.loadDataChunk(path)`)

> Carrega um arquivo de DADOS do save dir sem dar a ele poder de codigo.
> Save e arquivo do usuario (Steam Cloud, save compartilhado num forum): com
> love.filesystem.load ele rodaria com acesso a os/io. Aqui: so texto (bytecode
> recusado — o LuaJIT nao valida bytecode) e ambiente VAZIO.

## L279-280 (em `SaveManager.loadDataChunk`, junto a `local function safeRead(path, default)`)

> Lê arquivo Lua serializado (com recuperação .tmp/.bak), retorna `default`
> em caso de ausência ou corrupção total.

## L287-288 (em `safeRead`, junto a `local function shallowMerge(a, b)`)

> Merge raso: aplica valores de `b` em cima de `a` (cópia). Usado pra
> preencher settings antigos com keys novas sem perder o que o user tem.

## L307-308 (em `SaveManager.loadSettings`, junto a `return shallowMerge({}, DEFAULT_SETTINGS)`)

> Primeira execução: grava defaults (não obrigatório, mas evita
> inconsistência caso usuário só toque fullscreen sem ajustar volume).

## L340-343 (em `SaveManager.loadRun`, junto a `function SaveManager.quarantineRun()`)

> Save de run que NÃO carrega (corrompido, migration falhou): sai do caminho
> sem ser destruído — vai pra `<run>.corrupt` (o dono pode mandar o arquivo
> pra análise). Sem isto o botão Continuar ficava no menu pra sempre e cada
> clique falhava calado. Devolve true se havia algo pra mover.

## L351-353 (em `SaveManager.quarantineRun`, junto a `if p == base then`)

> Só o principal vira .corrupt (o legado que o dono manda pra
> análise); .tmp/.bak de um save que nem assim carregou saem
> junto, senão o Continuar "ressuscitaria" pelo fallback.

## L367-368 (em `SaveManager.quarantineRun`, junto a `function SaveManager.hasRun()`)

> Há run se QUALQUER geração existe: um crash entre a rotação e a promoção
> deixa só .tmp/.bak, e readDataFile sabe carregá-los.

## L376-377 (em `SaveManager.hasRun`, junto a `function SaveManager.deleteRun()`)

> Apaga TODAS as gerações: run abandonada/morta com .bak no disco voltaria
> no Continuar pelo fallback de leitura.

