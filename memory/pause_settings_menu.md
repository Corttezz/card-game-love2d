---
name: Pausa e Configurações v3
description: PauseMenu (zonas + resumo da run + atalhos D/J/M + Continuar primário + abandono em 2 etapas) e SettingsMenu (abas Áudio/Vídeo/Jogo, controles [<] valor [>], VOLTAR devolve à pausa) — navegação por teclado/gamepad via src/ui/MenuKit.lua. Out/2026.
type: project
---

# Pausa e Configurações v3 (Out/2026)

Pedido do dono: "os menus de pausa e o que eles abrem podem melhorar seguindo
nosso padrão de hoje". Arquivos: `components/PauseMenu.lua`,
`components/SettingsMenu.lua`, `src/ui/MenuKit.lua` (novo),
`tools/test_pause_menu.lua`, `tools/screenshot_pause.lua`.

## O que estava fora do padrão (auditoria)

| Tela | Defeito |
|---|---|
| Config | **Sobreposição real**: linhas com Y fixo (`gap = 50`) — em 800×600 o botão FECHAR desenhava em cima da linha do Idioma |
| Config | Dois dialetos: título/rodapé OSD âmbar ("◼ MENU", "AV-1 · GRIMOIRE" cravado) + botões sépia + painel sem a gramática do `UiPanel` |
| Config | 9 linhas numa lista plana, barras de volume começando em X diferente por rótulo, dropdown de idioma abrindo pra FORA do painel em janela baixa |
| Config | Fechar devolvia pro JOGO, não pra pausa (Balatro: `back_func = 'options'`) |
| Ambas | Zero teclado além de ESC; zero gamepad; nenhuma animação de entrada |
| Pausa | Rows de Button `invisible` = **mudas** (o variant não toca menuHover) e o clique chamava `onClick` direto, sem som |
| Pausa | Nenhuma hierarquia: Continuar com o mesmo peso de "Salvar e sair" |
| Pausa | Classe vinha de `run.className` (PT cravado) — em DE aparecia "Guerreiro" |
| Pausa | Só ato/andar; sem seed, vida, ouro, baralho; sem atalho pro Deck/Coringas/Roteiro |

## Desenho

**Pausa — zonas** (`PauseMenu:rebuild`, `validate()`):
CABEÇALHO → RESUMO (2×3: classe, jornada, seed / vida, ouro, baralho) →
ATALHOS (Deck [D], Coringas [J], Roteiro [M]) → AÇÕES (Continuar PRIMÁRIA
dourada, Configurações, Salvar e sair, Abandonar em vermelho) → RODAPÉ.
Sem altura: modo `full` → `nodesc` (some descrição) → `compact` (somem os
atalhos, o resumo vira 1 linha). Quem cede é o conteúdo, nunca as zonas.

**Config — abas de altura fixa** (`MAX_ROWS = 4`, o painel não pula ao
trocar de aba, = `tab_h` do Balatro): Áudio (Geral/Música/Efeitos), Vídeo
(Tela cheia/VSync/CRT/Iluminação), Jogo (Ritmo do combate/Tremor/Movimento
reduzido/Idioma). Todo controle é `[<] valor [>]` (option cycle do Balatro):
slider em segmentos dourados + %, toggle com "lâmpada" + LIGADO/DESLIGADO,
cycle com o texto. Clique no corpo do slider pula pro ponto.

**Teclado/gamepad** (`MenuKit.intent`): setas/WASD, Enter/Espaço, ESC;
Tab/Q/E/1-2-3 trocam aba; `love.gamepadpressed` (main.lua) traduz botão em
tecla SÓ quando há modal no InputFocus (START/BACK abrem a pausa em estado
de run; nunca no menu principal, onde ESC fecha o jogo). Mouse que MEXE puxa
o foco; mouse parado não rouba o foco do teclado.

**Abandono**: 1º Enter/clique ARMA; foco cai no **Não** (default seguro);
ESC desarma sem fechar; só "Sim" chama `onAbandon`.

**Entrada**: painel cai do topo com overshoot leve (0,24s) + véu em fade;
`reducedMotion` tira o deslocamento, mantém o véu.

## Settings novas (SaveManager.DEFAULT_SETTINGS)

- `vsync` (bool) → `love.window.setVSync` (pulado sob `_G.HEADLESS_TOOL`)
- `combatSpeed` (1 / 1.5 / 2 / 3, multiplicador de VELOCIDADE) →
  `CombatBeats.speed = 1 / x` (o knob é de DURAÇÃO). Aplicado no boot por
  `SettingsMenu.applyRuntime(persistedSettings)` no `love.load`.

## Armadilhas

- **A Press Start 2P não tem Õ/Í maiúsculos** — "CONFIGURAÇÕES" vira
  "CONFIGURAÇöES" e "VÍDEO" vira "VíDEO". O título pt fica "CONFIGURACOES" e
  as abas em caixa mista ("Áudio", "Vídeo"). Minúsculas acentuadas existem.
- O teste grava `settings.tool.lua` de verdade e o RESTAURA byte a byte,
  além de locale, `CombatBeats.speed`, `_G.gameSettings`; janela/vsync são
  stubs. Quem estender o teste mantém isso — senão o `test_beats` seguinte
  roda com o ritmo alterado.
- Não existe tempo de run no save. O resumo não mostra relógio; se um dia
  existir `run.playTime`, é uma célula a mais no `runSummary()`.

Validação: `love . test_one test_pause_menu` (145 asserções; validate() em 7
tamanhos × 2 idiomas × todos os estados, e teste-do-teste: sobreposição
forçada TEM que ser acusada) · `love . screenshot_pause [de]` (canvas com
janela falsificada, 5 tamanhos num processo, sem `setMode`).

## v4 (Out/2026) — "pausa poluída" e "idioma piorou"

**Pausa**: saíram as descrições das ações, a grade 2×3 do resumo (vida/ouro/
baralho repetiam a TopBar) e o rodapé de dica. Ficou: título com filetes →
"classe · jornada" + semente miúda → 3 ícones (os MESMOS da TopBar: deck.png,
jester_hat, scroll) → Continuar dourada / Configurações / Salvar e sair
(placas centradas, só o nome) → "Abandonar" como link vermelho discreto que,
armado, vira pergunta + Sim/Não no mesmo lugar. Zonas: title/info/shortcuts/
actions/danger. `runSummary()` segue com 6 células (dado), o desenho usa 3.

**Idioma**: o `[<] valor [>]` obrigava a passar idioma por idioma. Agora é a
4ª aba (tecla 4) com os 5 idiomas pelo NOME NATIVO (`I18n.labels`, com acento:
"Português (Brasil)", "Español", "Français") + selo do código; atual aceso,
1 clique/Enter escolhe, ←/→ não fazem nada nessa aba. `MAX_ROWS = 5`.
**Não voltar a pôr idioma em ciclo** — com 5 opções o ciclo é 4 cliques pro
pior caso, e quem não lê o idioma atual não sabe o que está ciclando.

**Escala**: pausa e configurações crescem com a altura (`sh/768`, teto 1.75 —
padrão das EndScreens). Em 2560×1440 o painel de 1× era um selo no meio.
Configurações: `U`/`S()` no módulo, setado no `rebuild`.

Sem rodapé de dica nas duas (regra do projeto); as chaves `pause.hint`/
`settings.hint` ficaram nos locales (o teste só confere existência).
Capturas: `love . screenshot_pause [de]` agora inclui 2560×1440.
