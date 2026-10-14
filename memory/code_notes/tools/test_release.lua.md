---
name: code_notes/tools/test_release.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_release.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_release.lua`

Origem: `tools/test_release.lua` em `7dbdb60d` (1 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-15 (junto a `local TK = require("tools.testkit")`)

> tools/test_release.lua
> Trava do modo DEV/RELEASE e da leitura segura de save.
>
> O que se protege aqui:
> * o REPOSITORIO e sempre DEV (build_info.lua so existe no pacote — se
> alguem commitar um, o jogo de desenvolvimento perde console e tools);
> * em DEV os argumentos chegam intactos ao dispatcher (senao test_all
> deixaria de rodar sem ninguem perceber);
> * save do usuario e DADO: bytecode recusado e chunk sem acesso a os/io
> (Steam Cloud / save baixado da internet nao executa codigo);
> * crash log grava stacktrace + ultimas linhas do log no save dir.
>
> love . test_one test_release
> O pacote em si (sem console, sem argumentos, tela de erro) e validado pelo
> smoke de tools/build_release.py, que boota o executavel fundido.

