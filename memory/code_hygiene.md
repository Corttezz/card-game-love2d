---
name: Higiene do código: zero comentário, zero print (Out/2026)
description: Regra do dono (14/Out/2026): código Lua/GLSL do jogo e das tools sem nenhum comentário e sem print() no caminho de jogo; diagnóstico só por src/core/Debug.lua, mudo por padrão (CARDGAME_DEBUG=1); conhecimento dos comentários antigos em memory/code_notes; trava test_no_comments_no_prints; como remover comentário por script com prova de bytecode.
type: project
---

# Higiene do código (Out/2026)

## O pedido

14/Out/2026, depois de ver o console de `love . demo_worldroad` cheio de
"[AudioManager] AVISO: som não carregado", "[worldroad] bioma sem arte própria",
"[toast] ...", "Button clicked: ..." e o cabeçalho de comentários de
`tools/boss_rooms.lua`: "Eu quero que você tire todos esses logs que estão aí.
Tem logs de som, de clique, de hover. Você disse que tinha tirado, feito a
limpo, mas não fez. Todos os comentários também: você segue fazendo um milhão
de comentários. Tem que tirar esses comentários também."

Isto REVOGA duas regras antigas do CLAUDE.md: "print() é o logger do projeto,
não remova em massa" e "fallback silencioso é PROIBIDO (um print por chave
desconhecida basta)". O aviso continua existindo, mas passa pelo `Debug` e
fica mudo por padrão.

## A regra

1. **Zero comentário** em `main.lua`, `conf.lua`, `src/**`, `components/**`,
   `engine/**`, `shaders/**` e `tools/**` (Lua: `--` e `--[[ ]]`; GLSL: `//`
   e `/* */`). A razão de ser de cada coisa mora em `memory/*.md`
   (subsistema) e, para o histórico, em `memory/code_notes/` (ver abaixo).
   Nome de função, de constante e de chave de i18n carregam o significado.
2. **Nenhum `print()` em caminho de jogo.** Diagnóstico passa por
   `src/core/Debug.lua`:
   - `Debug.log(...)` informação (seed da run, migração, conquista);
   - `Debug.trace(...)` rastro denso (hover, posição), só com nível 2;
   - `Debug.warn(...)` fallback: recurso ausente, chave desconhecida, shader
     que não compilou (é o antigo "fallback silencioso é proibido", agora
     silencioso NO CONSOLE e visível quando se pede);
   - `Debug.err(...)` erro recuperado.
   Tudo MUDO por padrão. `CARDGAME_DEBUG=1` liga log/warn/err; `=2` liga
   também trace. `Debug.setEnabled(true)` para ferramenta/teste que precisa
   capturar o aviso (ver `test_status_pills`, `test_card_live_hover`).
   Em RELEASE `warn`/`err` continuam indo para `logs/last_session.log` (o
   `print` lá é redirecionado pelo `Release.lua`), que alimenta o crash log.
   Erro fatal continua subindo por `error()`.
   `src/core/Release.lua` é o único outro arquivo com `print`: ele instala o
   `_G.print`, imprime o trace de ferramenta que quebrou e o selftest.
   Ruído de EVENTO (clique, hover, toast, "comprou", "tela aberta") não vira
   Debug.log: foi apagado e não volta.
3. **Tools** (`tools/**`): também sem comentário. `print` só de RESULTADO:
   `[ok]`/`[FAIL]`/`TOTAL`, tabelas de medição, caminho do arquivo gerado,
   veredito, e "não consegui fazer X" (falha do próprio tool). Nada de
   "modo ferramenta", eco de parâmetro, progresso, aviso de som. Tool novo
   que imprime resultado entra na lista `TOOL_RESULT_PRINTERS` de
   `tools/test_no_comments_no_prints.lua` (`test_*`/`smoke_*` já passam).
4. **Trava:** `love . test_one test_no_comments_no_prints` (no `test_all`).
   Varre todos os arquivos, lexa Lua de verdade (`--` dentro de string não
   conta), confere a lista de tools, que o Debug está mudo e que os 18
   shaders compilam.
5. **Logs de caça em arquivo** (`reward_debug.log`, `feel_debug.log`) só
   gravam com `CARDGAME_DEBUG`, não mais em todo boot de DEV.

## Como foi feito (e como refazer)

- `tools/luastrip.py`: lexer Lua/GLSL compartilhado com
  `tools/build_release.py`. `strip_lua(src, name, keep_indent=True,
  drop_blank=True)` é o modo do repositório (indentação preservada, linha que
  era só comentário desaparece, no máximo uma linha em branco seguida). O modo
  do build (`keep_indent=False, drop_blank=False`) preserva o número de linhas
  para o crash log apontar a linha certa.
- Prova: o próprio `lovec` compila original e limpo e compara
  `string.dump(f, true)` byte a byte (492 arquivos Lua, 0 divergência em
  14/Out/2026); GLSL por igualdade de tokens + `love.graphics.newShader`.
- Colheita antes de apagar: script que extraiu cada bloco de comentário com
  marcador de decisão/regra/bug/data/feedback (ou com 2+ linhas) para
  `memory/code_notes/<caminho>.md`, com linha e função de origem no commit
  `7dbdb60d` (o último com comentários). 5775 blocos de 12264.
- O número de linhas dos arquivos mudou (155k → 125k). Teste que lê o FONTE
  por regex contando linhas de comentário quebra (foi o caso de
  `test_weather`, corrigido); teste novo que grepa fonte deve casar só código.
- `demo_worldroad` passou a ser despachado no FIM do `love.load` (como
  `boss_rooms` e `nav_flow`): no topo o `audioSystem` não tinha os sons do
  jogo e cada efeito virava "som não carregado". Tool novo que toca som do
  jogo entra lá, não no topo.

## Armadilhas

- `main.lua`: nenhum `local` novo no escopo de arquivo (teto de 60 upvalues);
  `Debug` já é local lá. `BossCinematic.lua` e `WorldRoad.lua` vivem no teto
  de 200 locais por função: usam `require("src.core.Debug").warn(...)` inline.
- Teste que intercepta `print` para ler um aviso precisa de
  `Debug.enabled = true` em volta da captura, e ler TODOS os argumentos
  (`Debug.warn` imprime `"[WARN]", msg`, o aviso é o 2º argumento).
- O Edit tool grava CRLF neste checkout; o strip reescreve LF. Arquivo novo:
  conferir `git ls-files --eol`.
