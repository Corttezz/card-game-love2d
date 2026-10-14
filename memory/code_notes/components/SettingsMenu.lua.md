---
name: code_notes/components/SettingsMenu.lua
description: Comentários com decisão/regra/histórico colhidos de components/SettingsMenu.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `components/SettingsMenu.lua`

Origem: `components/SettingsMenu.lua` em `7dbdb60d` (19 de 47 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-30 (junto a `local FontManager = require("src.ui.FontManager")`)

> components/SettingsMenu.lua
> CONFIGURAÇÕES — overlay modal aberto pelo menu principal ou pela PAUSA.
>
> v3 (Out/2026 — "seguir o padrão de hoje"). Estrutura do create_UIBox_settings
> do Balatro (functions/UI_definitions.lua:2265): ABAS com conteúdo de altura
> FIXA (o painel não pula ao trocar de aba — tab_h do Balatro) e um botão
> VOLTAR que devolve pra quem abriu (back_func = 'options': aberto da pausa,
> volta pra pausa; aberto do menu, fecha).
>
> ÁUDIO   Geral · Música · Efeitos                          (sliders 0-100%)
> VÍDEO   Tela cheia · VSync · Shader CRT · Iluminação       (toggles)
> JOGO    Ritmo do combate · Tremor de tela · Movimento reduzido
> IDIOMA  os 5 idiomas pelo nome nativo — 1 clique/Enter escolhe
>
> Todo controle de ajuste tem a MESMA forma: [<] valor [>] — o "option
> cycle" do Balatro (←/→ ajusta, ↑/↓ escolhe a linha, Tab/Q/E troca aba,
> ESC volta). O IDIOMA não: no ciclo o dono tinha que passar idioma por
> idioma até chegar no seu (Out/2026, "piorou"). Agora é lista direta com
> o atual aceso, numa aba própria — não o dropdown da v2, que abria pra
> fora do painel em janela pequena.
>
> Visual: painel escuro-dourado canônico (UiPanel) + título dourado, igual à
> pausa/loja/roteiro. A v2 misturava o OSD âmbar de TV com os botões sépia
> ("dois dialetos na mesma tela") e tinha linhas de altura FIXA que, em
> 800x600, punham o botão FECHAR por cima da linha do Idioma.
>
> Persistência: toda mudança grava via engine/SaveManager.saveSettings e
> espelha em _G.gameSettings (lido por ScreenShake/Moveable/WorldRoad).
> SettingsMenu.applyRuntime(settings) aplica no boot o que não vive em
> módulo próprio (ritmo do combate, vsync).

## L50-51 (em `SettingsMenu`, junto a `SettingsMenu.COMBAT_SPEEDS = { 1, 1.5, 2, 3 }`)

> Ritmo do combate: multiplicador de VELOCIDADE exibido ao jogador. O
> CombatBeats.speed é multiplicador de DURAÇÃO, então speed = 1 / x.

## L64-66 (em `SettingsMenu.COMBAT_SPEEDS`, junto a `local U = 1`)

> Escala do painel (padrão das EndScreens/pausa): 768 de altura = 1, até
> 1.75 em telas grandes. Uma instância visível por vez, então mora no módulo
> e o rebuild a atualiza; S() vale pra layout E desenho.

## L74-76 (em `LANG_BADGE`, junto a `local function speedLabel(x)`)

> ===================================================================
> RUNTIME (estático): aplica settings que não moram em módulo próprio.
> ===================================================================

## L91 (em `SettingsMenu.applyRuntime`, junto a `if not _G.HEADLESS_TOOL and settings.vsync ~= nil`)

> VSync: só fora das ferramentas (captura tem que ser reproduzível).

## L107 (em `round1`, junto a `local VOL_FIELD = { master = "masterVolume", music = "musicVolume", sfx = "sfxVolume",`)

> ===== volumes (AudioManager quando há áudio; gameSettings sempre) =====

## L135-136 (em `setVolume`, junto a `if kind ~= "music" and kind ~= "ambient" then   -- ambiente se ouve sozinho (cama tocando)`)

> AMOSTRA no volume novo: a música se ouve sozinha (já está tocando);
> sfx/master tocam um clique pelo próprio grupo ajustado.

## L158-166 (em `speedIndex`, junto a `local function languageRows(menu)`)

> ===================================================================
> DEFINIÇÃO DAS ABAS (dados → linhas). Cada linha:
> kind  "slider" | "toggle" | "cycle"
> get() → valor (slider 0..1, toggle bool, cycle texto)
> step(dir) muda um passo (dir = -1/+1); slider também tem set(v)
> ===================================================================
> Uma linha "choice" por idioma: get() = é o atual?; step() = escolhe.
> I18n.setLocale já persiste (I18n.saveSetting); o snapshot do _persist
> leva o locale junto pro settings.

## L253-254 (em `step`, junto a `{ key = "crt", kind = "cycle", label = I18n.t("settings.crt_shader"),`)

> CRT em 3 níveis (Out/2026): Desligado / Baixo / Normal. Mesma
> linha do toggle antigo; Enter no Normal dá a volta pro Desligado.

## L284-285 (em `step`, junto a `{ key = "tips", kind = "toggle", label = I18n.t("tutorial.settings_tips"),`)

> Onboarding (src/systems/Tutorial): liga/desliga as dicas e
> "Rever as dicas" esquece as já vistas (perfil).

## L304-306 (em `step`, junto a `function SettingsMenu:new()`)

> ===================================================================
> CICLO DE VIDA
> ===================================================================

## L359-361 (em `SettingsMenu:setTab`, junto a `function SettingsMenu:rebuild()`)

> ===================================================================
> LAYOUT
> ===================================================================

## L367 (em `SettingsMenu:rebuild`, junto a `U = 1`)

> a escala mora no UiScale (espaço virtual); aqui é sempre 1:1

## L373-374 (em `SettingsMenu:rebuild`, junto a `local rowH = ROW_H`)

> Altura: conteúdo de altura FIXA (MAX_ROWS) — a aba não muda o painel.
> Janela baixa: quem cede é a altura da linha (até 30px), não as zonas.

## L494-497 (em `prev`, junto a `function SettingsMenu:_persist()`)

> ===================================================================
> AÇÕES
> ===================================================================
> Snapshot completo → disco (e espelho em _G.gameSettings).

## L550-552 (em `SettingsMenu:_clickValue`, junto a `function SettingsMenu:update(dt)`)

> ===================================================================
> UPDATE / INPUT
> ===================================================================

## L658-660 (em `SettingsMenu:keypressed`, junto a `local function drawSegments(r, value)`)

> ===================================================================
> DRAW
> ===================================================================

## L703-704 (em `drawArrow`, junto a `local function drawChoice(r, focused)`)

> Linha de idioma: selo do código + nome nativo; a ATUAL fica acesa
> (placa dourada + lâmpada cheia), as outras são só texto sobre o painel.

## L775-776 (em `SettingsMenu:_drawRow`, junto a `local d, gapL = S(8), S(8)`)

> lâmpada acesa/apagada COLADA no texto (grupo centralizado):
> lê o estado antes da palavra, sem depender do idioma.

