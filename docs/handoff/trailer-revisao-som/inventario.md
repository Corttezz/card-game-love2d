# Inventário de skills e MCPs para a revisão de SOM dos trailers

Data: 01/11/2026. Levantamento somente leitura. Regras da revisão: nada pago (0 crédito), sem Scenario e sem gerar nada no ElevenLabs.

## 1. Skills

### Globais (`C:\Users\corte\.claude\skills\`)
| Skill | Descrição (frontmatter, resumida) |
|---|---|
| animation-vocabulary | Glossário que dá o nome técnico de efeitos de animação web |
| emil-design-eng | Filosofia de polimento de UI e animação (Emil Kowalski) |
| frontend-design | Direção visual para UI nova ou reformulada |
| improve-animations | Auditoria de animação/motion de um codebase, só planos |
| redesign-existing-projects | Upgrade visual de sites/apps existentes |
| reverse-engineer-anything | Engenharia reversa com REA |
| scenario-kinetic-film | Filme kinetic typography como código (grade de beats, render 4K, mix, finish); a nota local diz modo SEM Scenario |
| slack-pr-watch | Watcher de PRs no Slack do Daniel |
| slack-rascunho | Rascunho de mensagem de Slack, nunca envia |
| web-design-guidelines | Revisão de UI contra guidelines web |

### Projeto `card-game-love2d\.claude\skills\`
ai-behavior-trees-utility-ai, **audio-design**, camera-systems, card-game, create-game-assets, dialogue-systems, **elevenlabs-music-generation** (link para `.agents/skills`), game-ai, gamedev-router, **game-feel**, **game-trailer-production** (link para `.agents/skills`), game-ui-ux, input-systems, level-design, love2d-core, love2d-gamedev, performance-optimization, physics-tuning, pixel-art-sprites, procedural-gen, prototype-fast, roguelike, save-systems, shader-programming, **sound-effects** (ElevenLabs), steam-publish.

### Projeto `card-game-trailer\.claude\skills\`
Não existe.

### Plugins (`C:\Users\corte\.claude\plugins`), só os de áudio/vídeo/motion
- ecc: `video-editing`, `remotion-video-creation`, `videodb`, `manim-video`, `motion-foundations/patterns/advanced/ui`, `make-interfaces-feel-better`, `blender-motion-state-inspection`.
- figma: `figma-use-motion`, `figma-implement-motion`, `video-interaction-mapper`.
- Nenhum plugin específico de mixagem ou música.

### `E:\dev\_orquestracao\skills-externas\`
- `kinetic-film/`: instalação local da kinetic-film com os filmes `grimoire_a`, `grimoire_b`, `grimoire_c`, `grimoire_v9`, `teste-starter`, `patches/` (fx.py, limpezas de quadro), `venv/`, `render_all_4k.sh`. Os `kscripts/` de cada filme têm `compose.py`, `layer.py`, `make_edl.py`, `mixdown.py`, `render_layer.mjs`. O `mixdown.py` atual já faz loudnorm em dois passos para **-14 LUFS, TP -1, LRA 11**, com ganhos por SFX vindos da EDL e `mix_sources.json` com licença por fonte (hoje os SFX são "síntese local, tools/synth_trailer_sfx.py"). Os `spec.js` estão com `sounds: {}`.
- `whatsapp-mcp/`: não relacionado.

## 2. MCPs (só nomes e tipo; nenhum env/header/token)

Global (`~/.claude.json`, `mcpServers`): atlassian-panda (http), atlassian-mamute (http), bitbucket-panda (stdio node), bitbucket-mamute (stdio node), datadog (http), panda-video (http), foxform (http), github (stdio), lambdatest (http), clarity (stdio npx), slack-mamute (http), slack-panda (http), rea (stdio node), google-ads (stdio), panda-tester-dev (stdio node), chrome-devtools (stdio npx).

Projeto `E:/dev/projects/card-game-love2d`: **pixellab** (http). Projeto `card-game-trailer`: nenhuma entrada. Nenhum dos dois repositórios tem `.mcp.json`. **Não há MCP de Scenario nem de ElevenLabs configurado** (asaas aparece como ferramenta da sessão, não nas entradas lidas).

## 3. Relevância para a revisão de som

| Item | Veredito | Como |
|---|---|---|
| audio-design | **USAR** | Buses (música/SFX/ambiente), tudo em dB, ducking por sidechain ou automação, variação de SFX, headroom -1 dBTP |
| game-trailer-production | **USAR** | Checklist de áudio do trailer: SFX reais do jogo, sem sweetener que finja mecânica, inteligibilidade acima de loudness, testes em celular/fone/TV/mudo, direitos e proveniência |
| kinetic-film local (`skills-externas/kinetic-film`, `mixdown.py`) | **USAR** | Pipeline real dos trailers: EDL com ganhos, loudnorm -14 LUFS, `mix_sources.json` de proveniência; é onde entram os SFX/ambientes do jogo |
| scenario-kinetic-film (SKILL.md) | **CONSULTAR** | beat_grid, mix (lista hit mais baixo que a música), finish (4K nível 5.2, sem `-shortest`). Passos de Scenario (música/kit de SFX gerados): **NÃO USAR**, pago e proibido |
| game-feel | CONSULTAR | Camadas áudio-visuais de impacto (hit-stop + som) para casar SFX com o corte |
| ecc:video-editing / remotion / videodb | CONSULTAR (pouco) | Montagem/ffmpeg genérico; não acrescentam regra de mix |
| sound-effects (ElevenLabs) | **NÃO USAR** | Gera no ElevenLabs: proibido nesta revisão |
| elevenlabs-music-generation | **NÃO USAR** | Gera música via RunComfy/ElevenLabs, pago |
| pixellab (MCP) | NÃO USAR | Só arte; não ajuda no som |
| rea (MCP) | NÃO USAR | Engenharia reversa; não se aplica |
| chrome-devtools (MCP) | NÃO USAR (salvo depurar a página do filme) | O render é por scripts locais |
| github, atlassian, bitbucket, slack, datadog, panda-video, foxform, lambdatest, clarity, google-ads, panda-tester-dev | NÃO USAR | Sem relação com áudio; vários são de outras empresas (isolamento) |
| motion-*, figma-* | NÃO USAR | Movimento visual, não som |

## 4. Regras concretas de mixagem extraídas

**audio-design**
- Mixar em buses (`Master ← Music, SFX, Ambience, UI, Voice`), não por clipe; automação sempre em dB.
- True peak ≤ **-1 dBTP**; medir loudness integrada com medidor BS.1770. A skill cita -24 LUFS (console/TV) e -18 (mobile) como alvo de *jogo* e diz que -14 é alvo de streaming: para *trailer em plataforma* (YouTube/Steam) o -14 LUFS combinado é coerente.
- Ducking por sidechain: limiar ~-30 dB na fonte-chave, razão **4:1 a 8:1**, ataque ≤ 10 ms (rápido), release **300-500 ms**. Alternativa: automação de volume num bus de duck separado, rampa ~0,25 s.
- Evitar "pumping" (release curto/razão alta demais): alongar release, baixar razão. Não clipar o master (somas passam de 0 dBFS).
- Variação de SFX repetido: pitch/amostra aleatória, volume ±2 dB.
- Sincronizar no relógio do áudio, não no frame.
- Validar ouvindo: duck audível sem respirar, transições no beat.

**game-trailer-production**
- SFX reais do jogo sempre que possível (verdade e identidade); sweetener só se não sugerir mecânica/impacto inexistente.
- Mix: inteligibilidade acima de loudness; ouvir em alto-falante de celular, fone, TV e mudo; os 5-10 s iniciais têm de funcionar sem som.
- Música com direitos documentados (território, plataforma, anúncio pago, loja, perpétuo); nenhuma faixa temporária no final.
- Exportar M&E limpo (música+efeitos sem VO) se houver dublagem; legendas para sons significativos.
- QA de export: specs, loudness/inteligibilidade, YouTube AAC 48 kHz; conferir a prévia depois do upload (transcode muda sincronia).
- Proveniência de todo asset (ledger) e revisão de direitos: música, SFX e conteúdo gerado por IA (declarar na Steam/YouTube).

**scenario-kinetic-film**
- Áudio vem do usuário com licença comercial (perguntar a licença antes de usar). No caso do Grimoire os SFX/música do jogo foram feitos no ElevenLabs **free** (sem uso comercial, ver CLAUDE.md "Pendente"): registrar isso na proveniência; não resolve com geração nova aqui.
- Spec: `music: { offset, stopBeat, gain: -7 }` (música ~-7 dB, parada seca no stopBeat = silêncio antes do clímax), `sounds` com ganhos individuais (-7 a +1 dB); `mix.py` lista hit mais baixo que a música, subir em `spec.sounds`.
- Render 4K: H.264 `-level 5.2`, não usar `-shortest` no mux.

**kinetic-film local (mixdown.py)**
- loudnorm dois passos `I=-14:TP=-1:LRA=11`; ganhos na EDL; `mix_sources.json` com arquivo, tipo, licença, tempo e ganho de cada fonte.
