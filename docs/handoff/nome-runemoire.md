# Frente: nome-runemoire (Grimoire → Runemoire)

## Frente
_Decisão do Daniel em 10/11/2026, pelo chat do Grimoire Lead ("quero"). Nível M. Executor: Grimoire Dev._

### Por quê
Já existe "Grimoire" (Topius, app 2654660) na Steam. O Daniel escolheu **RUNEMOIRE**. Checagem do Lead em 10/11: sem jogo na Steam nem na web, sem marca na base mundial da OMPI (inclui INPI, USPTO e EUIPO), domínios e @ livres. Estudo: `C:\Users\corte\OpenBot\Agents\agent-94a829b6-cd14-459f-8452-ca6c69a704f7\estudos\nome-do-jogo-2026-11-10.md`.

### Objetivo
O **título** do jogo passa a ser **RUNEMOIRE** em tudo que o jogador e a loja veem. A palavra "grimório" como conceito do jogo continua (o deck é o "grimório", "Selos do Grimório", "Escolha 1 carta para o seu grimório").

### Passos
1. **Inventário primeiro:** listar onde o título "Grimoire"/"GRIMOIRE" aparece como **nome do jogo**: `menu.title` nos 5 idiomas, logo do menu (`tools/menu_brand.py` → selo + palavra assados, `src/ui/MenuBrand.lua`), abertura datilografada (`IntroTube`), título da janela, `tools/build_release.py` (`Grimoire.exe`, nome do .love e do depot), textos de conquistas (`tools/achievement_text.py`), tela de erro/crash, créditos, README, CLAUDE.md. Separar do uso de "grimório" como conceito (não muda).
2. **Logo:** refazer o logo do menu com RUNEMOIRE no mesmo estilo (mesmo selo, mesma fonte e efeitos). Mostrar antes/depois em imagem ao Lead **antes** de aplicar.
3. **Trocar** o título nos pontos do inventário, nos 5 idiomas (o nome não se traduz).
4. **Não mudar:** `identity` do `conf.lua` (pasta do save; nunca tocar o save real), ids e API names `ACH_*` das conquistas (eternos), nomes de arquivos internos/branches, histórico de handoffs.
5. **Trailer:** só listar onde o logo/nome aparece nos cortes (gameplay e 13c). Não renderizar nada nesta frente.
6. Rodar a suíte (`suite_lock.sh`) e as travas afetadas (`test_menu_brand`, `test_intro_tube`, `test_no_hardcoded_pt`, `test_achievements`).

### Limites
- Só headless, 1 `lovec` por vez, nunca o save real, nunca matar processo por nome.
- Branch própria, commits em nome de Daniel Cortez, sem Co-Authored-By nem menção a Claude/Grok/Codex, sem push, sem merge na main sem o Lead revisar.
- Nada pago, nada na Steam, nada publicado. Não registrar domínio nem criar contas.

### Pronto quando
Inventário com o que mudou e o que ficou (e por quê), imagem antes/depois do logo e do menu, suíte passando, lista dos pontos do trailer, branch e commits.

## Ampliação (Daniel, 10/11/2026): "trocar em todos os lugares, até nos trailers, tudo de tudo, revisão completa"
Substitui o passo 5 (trailer só listar). Agora a troca é **completa**, em frentes (regra 19, no máximo 3 ao mesmo tempo, nunca duas nos mesmos arquivos):

- **Frente A — jogo (primeiro):** passos 1 a 4 e 6 acima. O logo novo do menu é a fonte única do nome para o resto. Mandar antes/depois ao Lead.
- **Frente B — trailers (depois que o logo da A for aprovado pelo Lead):** trocar o nome/logo em **todos** os trailers vigentes e re-renderizar com nomes novos, sem sobrescrever os antigos: trailer de gameplay (`grimoire_gameplay_*` → `runemoire_gameplay_*`, 1080p/720p/mobile < 25 MB) e o corte cinematográfico 13c (`runemoire_trailer_c13c_*`). Render **um por vez**. Mesmas medidas de som (LUFS/true peak). Os pipelines (`tg_build.py`, `edl.py`, `build_video.py`, gerador do cartão de logo) passam a usar RUNEMOIRE por padrão, para os trailers futuros já saírem certos.
- **Frente C — documentos do projeto (pode correr junto com a A, arquivos diferentes):** README, CLAUDE.md (§1 e onde o nome do jogo aparece), `memory/*.md` do repo (MEMORY.md, menu_branding, release_pipeline, steam_achievements etc.), roteiros e textos aprovados do trailer, página da loja/descrições em `tools/`. Escrever "Runemoire (antes Grimoire)" na primeira menção de cada arquivo. Não reescrever histórico de handoffs/revisões antigas: só um aviso no topo do handoff principal de cada trailer.
- **Fora do repo (o Lead faz):** status, spec do bot, memória do projeto, avisos.

### Revisão completa (obrigatória antes de "pronto")
1. Busca final no repo e nos pipelines do trailer por `Grimoire|GRIMOIRE|grimoire` (inclusive em imagens/fontes assadas: logo, cartões, ícones, splash) e classificar cada ocorrência que sobrou: **nome do jogo** (erro, trocar) ou **conceito/id interno** (fica, com motivo).
2. Capturas headless do menu, abertura, tela de erro e conquistas em pt_BR e em mais 1 idioma, mostrando RUNEMOIRE.
3. Quadros dos trailers novos nos momentos do logo/nome.
4. Revisão independente (revisor sem o seu contexto) com nota ≥ 9 em: nome certo em tudo que o jogador e a loja veem; logo fiel ao estilo antigo; nada quebrado (suíte); trailers sem resto de "Grimoire".
