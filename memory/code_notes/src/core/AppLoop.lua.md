---
name: code_notes/src/core/AppLoop.lua
description: Comentários com decisão/regra/histórico colhidos de src/core/AppLoop.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/core/AppLoop.lua`

Origem: `src/core/AppLoop.lua` em `7dbdb60d` (4 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-31 (junto a `local AppLoop = {}`)

> src/core/AppLoop.lua
> Laco principal (love.run) do jogo + encerramento ordenado.
>
> Por que existe (auditoria de release, Out/2026): o love.run padrao roda
> update+draw a toda velocidade em QUALQUER estado da janela. Medido no
> executavel de release: ~21% de um nucleo no menu com foco, ~25% com a
> janela visivel sem foco e ~29% MINIMIZADA (minimizada o vsync nao segura
> nada — o present volta na hora). Jogo parado numa aba de fundo nao deve
> custar isso.
>
> Regras do laco:
> * janela com foco + vsync ligado: igual ao padrao (o vsync dita o ritmo);
> * vsync DESLIGADO (opcao em Configuracoes -> Video): teto na taxa do
> monitor (60..240) em vez de girar livre a 100% de um nucleo;
> * visivel SEM foco: BACKGROUND_FPS (update + draw, a cena segue viva);
> * minimizada/oculta: HIDDEN_FPS e SEM draw (nada a mostrar). O update
> continua — musica, crossfade e timers seguem coerentes, so mais
> espacados (o dt real e entregue, com teto MAX_DT).
> * ferramentas (_G.HEADLESS_TOOL): nunca estrangula — tool rodando em
> segundo plano nao pode ficar 5x mais lento.
>
> Encerramento: o evento "quit" (fechar a janela, love.event.quit, Alt+F4)
> passa por AppLoop.shutdown() DEPOIS de love.quit (se algum modulo definir
> um e ele nao cancelar). Fica aqui, e nao num `function love.quit` do
> main.lua, porque (1) main.lua nao aceita mais locais de arquivo e (2) um
> love.quit definido depois por outra frente sobrescreveria o nosso em
> silencio. O shutdown: lembra monitor/posicao da janela, fecha a Steam e
> descarrega o log de release (que so grava a cada 2 s / 64 linhas).
>
> Instalado por Release.install() (1a linha do main.lua), ANTES do wrapper
> do selftest — que envolve este laco, entao o smoke exercita o laco real.

## L41-43 (em `AppLoop`, junto a `function AppLoop.frameCap(win, headless)`)

> Teto de quadros pro estado atual da janela. nil = sem teto (vsync manda).
> Segundo retorno: true = nao desenhar (janela minimizada/oculta).
> Puro sobre `win` pra ser testavel (tools/test_app_loop.lua).

## L60-61 (em `AppLoop.frameCap`, junto a `local winState = { focused = true, visible = true, minimized = false,`)

> Estado da janela, lido 1x por quadro. O modo (vsync/refreshrate) so muda
> quando o jogador mexe nas Configuracoes; cacheado e relido a cada ~1 s.

## L119 (em `AppLoop.run`, junto a `local didShutdown = false`)

> Idempotente: o laco chama no "quit"; testes podem chamar direto.

