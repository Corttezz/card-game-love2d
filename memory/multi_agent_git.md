---
name: multi_agent_git
description: Commit seguro com vários agentes no mesmo repo/branch — índice PRIVADO (GIT_INDEX_FILE), nunca `git add -A`/`commit -a`; como detectar revert silencioso. Out/2026.
type: project
---

# Git com agentes em paralelo (mesmo checkout, mesma `main`)

## O defeito (Out/2026)

Vários agentes commitam na `main` do MESMO checkout e dividem UM índice
(`.git/index`). O `aed62ee` (Combo v3) foi montado a partir de um índice/árvore
velho e, sem nenhuma linha na mensagem, devolveu 8 arquivos do inimigo
(`enemies.lua`, `EnemyRoster.lua`, `Player.lua`, `Config.lua`, `Game.lua`,
`test_enemies.lua`, `memory/enemies.md`, `memory/balance_curves.md`) ao estado
EXATO de `6c9c6d2^` — o commit da calibração, 1 minuto antes, sumiu. Ninguém
viu porque a suíte passa nas duas versões. Reaplicado em `7b7bfa7`.

Mecânica: o agente fez `git add` de um arquivo inteiro (ou `commit -a`) cuja
cópia de trabalho/índice ainda era a de antes do commit do vizinho. O diff do
commit "desfaz" o vizinho e parece edição normal.

## Procedimento de commit (obrigatório com agentes em paralelo)

Commit por índice PRIVADO, só com o SEU patch, em cima do HEAD atual:

```sh
old=$(git rev-parse HEAD)
export GIT_INDEX_FILE=$(mktemp)
git read-tree HEAD                       # índice = HEAD, não o índice sujo
git apply --cached meu.patch             # ou: git update-index --add <arquivo> SÓ se o arquivo inteiro é seu
tree=$(git write-tree)
c=$(git commit-tree "$tree" -p "$old" -F msg.txt)
git update-ref HEAD "$c" "$old"          # falha se alguém commitou no meio -> refaça
unset GIT_INDEX_FILE
```

- `meu.patch` = `git diff -- <seus arquivos>` revisado hunk a hunk: arquivo
  compartilhado (Config.lua, Game.lua, locales, CLAUDE.md, MEMORY.md) quase
  sempre tem hunks de OUTRO agente na cópia de trabalho.
- NUNCA `git add -A`, `git add .`, `git commit -a`, `git stash`, `git checkout -- <arq>`,
  `git reset --hard` — mexem no trabalho dos outros.
- Depois do commit, o índice COMPARTILHADO ainda guarda a versão velha dos
  seus arquivos: um `git commit` simples de outro agente desfaria você (é
  exatamente o defeito do aed62ee). Sincronize SÓ os seus caminhos:
  `git reset -q -- <seus arquivos>` (põe o índice = HEAD nesses paths, não
  toca a cópia de trabalho nem os paths dos outros).
- `update-ref` com o valor antigo é o "compare-and-swap": se recusar, outro
  agente entrou; refaça `read-tree HEAD` + apply.

## Antes de commitar: o diff não pode DESFAZER ninguém

`git diff --cached --stat` (no índice privado) e leia toda linha `-`. Linha
removida que você não escreveu/não pretendia remover = árvore velha. Detector
usado na auditoria: para cada hunk removido, `git blame -L a,b <commit>^ -- arq`;
se a linha vem de commit recente de outra frente e a mensagem não explica,
é revert silencioso. Conferir também se a versão do arquivo no commit é
IDÊNTICA a `<commit-do-vizinho>^` (assinatura do revert puro).

## `git apply --cached --unidiff-zero` com hunks FILTRADOS desloca inserções

Medido (Out/2026, ce02e63 → refeito em e2de850): filtrar hunks `-U0` de um
arquivo com mudanças de várias frentes e aplicar só os seus com
`--unidiff-zero` jogou uma inserção pura (`@@ -N,0 +M @@`) ~30 linhas fora do
lugar — `Game.lua` commitado com erro de sintaxe, e `PauseMenu`/`TopBar` com
linhas duplicadas. O apply verde não prova nada. **Faça assim:** gere o
conteúdo final por arquivo = base + SÓ os seus blocos (difflib sobre
base × cópia de trabalho, bloco a bloco por regex) e grave com
`git hash-object -w` + `git update-index --cacheinfo`. E **teste a árvore
do commit** antes de dar update-ref: `git checkout-index -a --prefix=<wt>/`
num diretório limpo + `love . test_all` lá dentro.
