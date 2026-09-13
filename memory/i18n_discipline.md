---
name: Disciplina de i18n (nada de PT cravado em UI)
description: Por que telas saíam bilíngues, onde o português costuma se esconder (tabelas de dados, toasts, mocks de tool), e a trava automática que impede a regressão.
type: project
---

# Disciplina de i18n

## O defeito, duas vezes

Set/2026, dois agentes independentes acharam o MESMO padrão:

- `Config.Acts[n].name` era PT cravado → o Roteiro exibia **"AKT 1 — Catacumbas"**.
- `RoundEvalScreen:_buildDynaTexts` tinha o título em PT enquanto o botão usava
  `I18n.t` → a tela saía metade alemã, metade portuguesa.

Duas ocorrências independentes não são coincidência: são um **padrão**. A varredura
achou mais 100+ strings, quase todas em lugares que ninguém pensa como "UI".

## Onde o português se esconde

O literal dentro de `love.graphics.print` é o caso fácil, e quase nunca é o problema.
Os difíceis:

| Lugar | Exemplo |
|---|---|
| **Tabela de dados exibida** | `Config.Acts[].name`, `MapManager.NODE_META[].label/desc`, `ShopSystem` packs/upgrades |
| **Toasts** (`game:addMessage`) | ~70 em `Game.lua`/`EffectSystem.lua`/`ComboSystem.lua` — o feed lateral é UI |
| **Rótulos construídos em sistema** | `Game:_buildRoundEvalSources` (`"Vitória"`), `ScoreSystem` (recibo do score) |
| **Mock de tool** | `screenshot_round_eval` montava o breakdown com rótulos PT — a **captura mentia**, mostrava PT com o código já traduzido |

Regra prática: **se um humano lê, vai pro i18n** — mesmo que esteja numa tabela
de dados. `print`/`Debug.*`/`error`/`assert` são ferramenta e ficam em PT
(convenção do projeto, CLAUDE.md §9).

## Os dois padrões corretos

**1. Resolver no momento de EXIBIR** (preferido):

```lua
function MapManager.labelFor(nodeType)
    local meta = MapManager.NODE_META[nodeType] or {}
    return I18n.t("node_type." .. nodeType .. ".label", nil, meta.label or nodeType)
end
```

O texto na tabela de dados vira **fallback de dev**, não fonte.

**2. Resolver na CONSTRUÇÃO** — só quando o objeto é efêmero e não viaja no save.
É o caso das ofertas de loja (regeradas a cada visita). Uma string resolvida na
construção de algo **persistido** congela no idioma de então: por isso os nós do
mapa também têm `labelFor` além da resolução em `_makeNode`.

### Armadilhas

- **`local function` só existe abaixo da definição.** Os helpers `itemName`/
  `itemDesc` foram postos no meio do `ShopSystem` e `generateUpgradeOffer` (mais
  acima) quebrou com `attempt to call global 'itemName'`. Mesma armadilha do
  `notifyOrbUI` no EffectSystem. Helper vai no TOPO.
- **Traduzir de verdade.** Repetir a string PT nos 5 locales passa no teste de
  paridade e continua errado na tela. `smoke_acts` agora exige que
  `getActName(1)` seja *diferente* em pt_BR e de.
- **Teste que assume locale.** `smoke_acts` comparava com `"Catacumbas"` sem
  fixar idioma; virou falha intermitente assim que o nome passou pelo i18n.
  Teste que depende de idioma **fixa o locale e restaura no fim**.

## A trava: `tools/test_no_hardcoded_pt.lua`

Roda no `test_all`. Varre ~147 arquivos de UI e falha se achar literal
**acentuado** fora do i18n.

- Sinal = acentuação (bytes `0xC3` + segundo byte), exceto `×`/`÷`, que são
  sinais matemáticos usados de propósito.
- Ignora comentário, saída de dev (`print`/`Debug.*`/`warn*`/`error`/`assert`/
  par `return false, "motivo"`) e o **fallback** de `I18n.t(k, v, "texto")`.
- Varre por **linha LÓGICA** (junta continuações até fechar os parênteses) — na
  primeira execução, chamadas quebradas em duas linhas deram 6 falsos positivos.
- `ALLOW` é a lista de exceções auditadas, cada uma com motivo. O teste **avisa
  quando uma entrada fica obsoleta** — exceção morta afrouxa a regra sem ninguém
  notar.

**Limite conhecido, de propósito:** não pega PT sem acento ("Batalha", "Loja",
"Descanso"). Lista de palavras PT daria falso positivo em identificador e nome
de asset. Foi exatamente esse buraco que a **captura em alemão** pegou: o recibo
do `ScoreSystem` (`"Inimigo derrotado"`, `"Nao tomou NENHUM dano"`) passava
limpo pela trava e aparecia em PT na tela alemã.

## Valide em OUTRO idioma

Capturar em pt_BR esconde o defeito por construção — os dois casos ficam iguais.
`screenshot_journal` e `screenshot_round_eval` aceitam um locale:

```
love . screenshot_journal - de
love . screenshot_round_eval 3 de
```

(As tools de `screenshot_*`/`preview_*` forçam pt_BR por padrão, porque o
`test_i18n` restaura o locale de ENTRADA e o sandbox se auto-perpetuava em
alemão.)

## Conquistas: traduzidas (Set/2026)

As 20 conquistas (`src/data/achievements.lua`) foram pro i18n em
`achievements.list.<id>.{name,desc}`. `AchievementSystem.all()` e `unlock()`
passam pelo MESMO helper, então galeria e toast nunca divergem — o catálogo
virou fallback de dev, sem acento.

Duas lições dessa leva:

- **Traduza pelo EFEITO.** O catálogo inteiro vive numa metáfora de escriba
  (página, tinta, rascunho, vela) e é ela que tem de sobreviver, não a palavra.
  "Sem Rascunhos" (vencer sem nunca revisar o texto) virou *No Drafts* /
  *Sin Borradores* / *Sans Brouillon* / *Ohne Entwurf* — a palavra de rascunho
  LITERÁRIO em cada idioma, não a de "esboço". "Fio da Navalha" usa a
  expressão idiomática nativa de cada um (*Razor's Edge*, *Auf Messers
  Schneide*).
- **Texto traduzido cacheado congela no idioma da abertura.**
  `AchievementsScreen:show()` guardava `AchievementSystem.all()` em
  `self.entries` e nunca remontava: o título traduzia e as 20 conquistas não.
  Agora guarda o locale de construção e o draw remonta quando ele muda. Vale
  para QUALQUER tela que cacheie string já resolvida.

`tools/test_achievements_i18n.lua` trava: chave presente nos 5 locales, texto
DIFERENTE entre idiomas (2+ valores distintos — não a string PT copiada 5×),
acento só em pt_BR, e `all()` devolvendo o traduzido e não o fallback.
`tools/screenshot_achievements.lua all` captura o grid nos 5 (alemão é o pior
caso de largura; o `TextFit` deu conta).

## Ainda em PT (mapeado, não feito)

- `components/RestScreen.lua`, `components/EventScreen.lua`,
  `components/CardRewardScreen.lua` (1 toast), `src/ui/PackThemes.lua` —
  arquivos com outros agentes ativos em Set/2026.

## Ligações

[[conventions]] · [[ui_layout_invariants]] · [[run_journal]]
