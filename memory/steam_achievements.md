---
name: Steam Achievements
description: Conquistas (30) — catálogo, gatilhos, emblemas próprios, galeria por zonas, toast, ponte Steam (SteamBridge + luasteam), entregáveis em steam/achievements e checklist de cadastro no Steamworks.
type: project
---

# Conquistas + Steam (Out/2026)

## Mapa de arquivos

| Arquivo | Papel |
|---|---|
| `src/data/achievements.lua` | Catálogo (DADOS): id, `steam` (API name), tier, hidden, progress |
| `src/systems/AchievementSystem.lua` | Lógica: hooks, unlock (fonte única), progresso, data |
| `src/systems/SteamBridge.lua` | Espelho Steam: no-op AVISADO sem Steam; luasteam quando houver |
| `src/ui/AchievementIcons.lua` | Carrega `assets/sprites/achievements/<id>[_locked].png` |
| `src/ui/AchievementToast.lua` | Cartão de desbloqueio (fila, por cima de qualquer estado) |
| `components/AchievementsScreen.lua` | Galeria por ZONAS (cabeçalho / grade por categoria / detalhe) |
| `tools/achievement_text.py` | Texto-FONTE dos 5 idiomas → gera locales + metadados Steam |
| `tools/achievement_icons.py` | Emblemas: import do PixelLab → `_locked` derivado → 256×256 Steam |
| `tools/test_achievements.lua` | Cada gatilho, persistência, API names congelados, ícones, layout |
| `steam/achievements/` | ENTREGA: `achievements.json`, `CADASTRO.txt`, `icons/*.png` |

## Regras

- **id e API name são eternos.** `id` é a chave no profile.lua (renomear apaga a
  conquista de quem tinha); `steam` é o API name publicado (a Steam não renomeia).
  `test_achievements` tem a lista `FROZEN` — conquista nova entra lá.
- **Texto: edite `tools/achievement_text.py`**, rode `python -I tools/achievement_text.py locales`
  e `... steam`. Os blocos `achievements = {}` dos locales são GERADOS.
- **Limiar numérico mora em `AchievementSystem.T`** e no texto — mudar um exige o outro.
- **Hooks inline (padrão StS)**: cada sistema reporta o seu evento. Mapa no topo do
  AchievementSystem. Fiação travada por grep no teste (Game/EffectSystem/RestScreen).
- **UnlockSystem (frente progressão) é OPCIONAL**: `despertar` lê
  `isClassUnlockedReal` via `pcall(require)` e assina `UnlockSystem.onUnlock`; sem o
  módulo, avisa uma vez e a conquista fica sem progresso. Nunca escreve nele.
- **Bloqueada = mesmo emblema em silhueta** (escurecido + sépia), não cadeado:
  o alvo é reconhecível. Secreta bloqueada = silhueta + "?" e nome "???".

## Bugs corrigidos na revisão (Out/2026)

1. `alem_da_pagina` NUNCA disparava: lia `run.floorsInEndless`, campo que nada
   escreve. Agora `AchievementSystem.endlessFloor(run)` = `currentFloor − TotalActs×8`.
2. `tinta_crua` dava FALSO POSITIVO com deck forjado: `getCard(entry)` com entrada
   tabela (`{id, up}`) devolvia nil e a carta contava como comum. Usa `RunManager.entryId`.
3. `capitulo_final` ("chefe do Ato 3") disparava na VITÓRIA — com 6 atos era
   duplicata de `primeira_pagina`. Agora dispara no chefe do ato ≥3.
4. `bibliotecario` nunca contava o deck inicial (só `addCardToRun`) → `onRunStarted`.
5. `countUnlocked` contava ids aposentados do perfil.

## Integração Steam (quando o jogo for pra Steam)

LÖVE puro não fala Steamworks. Caminho: **luasteam** (github.com/uspgamedev/luasteam).
1. Baixar o binário do luasteam compatível com o LuaJIT do LÖVE 11.x (win64:
   `luasteam.dll`) + `steam_api64.dll` do Steamworks SDK (mesma versão do build).
2. Pôr os dois AO LADO do `love.exe` fundido (build de release), não no .love.
   `require("luasteam")` acha via `package.cpath` do diretório do executável.
3. `steam_appid.txt` com o AppID na pasta do executável **só em dev** (Steam
   injeta em produção).
4. Nada mais no código: `AchievementSystem.install()` (love.load) chama
   `SteamBridge.init()` → `syncAll` (espelha o que o perfil local já tem) e cada
   unlock chama `setAchievement + storeStats`. `love.update` roda `runCallbacks`.
5. Conferir no console: `[SteamBridge] Steam ATIVA`. Sem isso aparece
   `Steam INATIVA (motivo)` — nunca falha calado.
Teste de console Steam: `steam.exe -console` → `achievement_clear <appid> ACH_X`.

## Checklist de cadastro no painel (Steamworks → App Admin → Stats & Achievements)

- [ ] Criar as 30 conquistas na ORDEM de `steam/achievements/CADASTRO.txt`
      (API Name exatamente como lá — maiúsculas, `ACH_*`).
- [ ] Set by: **Client**. Sem stat vinculado (o progresso é exibido via
      `IndicateAchievementProgress` em 25/50/75%, não via stat).
- [ ] Hidden: **yes** em `ACH_FIO_NAVALHA`, `ACH_MAOS_LIMPAS`, `ACH_ALEM_DA_PAGINA`.
- [ ] Ícone conquistado = `icons/<API>.png`; não conquistado = `icons/<API>_locked.png`
      (256×256, fundo INK opaco, ampliação nearest ×4 do emblema 64×64).
      Conferir no painel se ainda pede 256×256 e se aceita PNG (fontes da
      comunidade citam 256→64; se exigir JPG, converter os 60 PNGs).
- [ ] Nome/descrição em english, brazilian, spanish, french, german — copiar de
      `CADASTRO.txt` (ou importar via `achievements.json`).
- [ ] **Publish** as mudanças (o painel tem rascunho e publicação separados).
- [ ] Limite padrão: 100 conquistas até o app ganhar Profile Features (temos 30).
- [ ] Antes do lançamento as conquistas não aparecem na comunidade — validar no
      próprio jogo (galeria) + console da Steam.

## Calibração atual (30)

Jornada 9 (natural: 1º chefe, chefe A3, vitória, 3 por classe, Trindade, Todos
Despertos, Coro de Coringas) · Restrição 6 · Maestria 10 (2 secretas) · Legado 5
(escriba 2500 cartas, ferreiro 25, veterano 10 vitórias, bibliotecário, infinito 10 — secreta).
