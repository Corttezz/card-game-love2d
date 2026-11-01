# Frente: trailer-do-zero (Grimoire)

## Frente
_Pedido do Daniel em 01/11/2026 14:15, prioridade ALTA. Sessão diretora: `grimoire-trailer-diretora`; revisora independente: `grimoire-trailer-revisora`._

O Daniel assistiu aos `*_som` (remix de som de 01/11 dos trailers A, B e C) e achou o trailer muito ruim. Quer o trailer **refeito do zero**: melhorar tudo, aproveitar o que for bom das versões anteriores, revisar tudo e usar todas as ferramentas disponíveis.

### Regras
- Só headless: nunca abrir janela, nunca roubar o foco do PC. Captura só headless, 1 `lovec` por vez, identidade `card-game-trailer-v9`, nunca o save real, nunca abrir o jogo na tela. Nunca matar processo por nome.
- Pode usar todos os SFX atuais (liberação do Daniel, só para ver como fica): o resultado sai marcado **"não publicável até trocar ou licenciar os SFX"**.
- Nada pago: 0 crédito, sem Scenario, sem gerar no ElevenLabs.
- Não sobrescrever os masters antigos (nomes novos). Nada para Steam ou depot.
- Commits em nome de Daniel Cortez, sem Co-Authored-By nem menção a Claude/Grok/Codex, sem push. Suíte completa só via `suite_lock.sh`.

### Insumos
- Worktree `E:\dev\projects\card-game-trailer`; versões em `build\trailer\` (`grimoire_trailer_v3..v8*.mp4`; A = `grimoire_kinetic_hook30*.mp4`; B = `grimoire_kinetic_new*.mp4`; C = `grimoire_trailer_v9_kinetic*.mp4`; `*_som*.mp4` = remix de som de 01/11).
- Docs: `docs/handoff/trailer-kinetic.md`, `trailer-kinetic-referencias.md` (10 critérios), `trailer-kinetic-prep.md`, `trailer-revisao-som.md` (+ pasta).
- Tomadas: `%APPDATA%\LOVE\card-game-trailer-v9\trailer\<shot>\` (+ `audio.jsonl`). Kinetic Film local: `E:\dev\_orquestracao\skills-externas\kinetic-film\`.

### Etapas e protocolo
Cada etapa grava o entregável em `docs/handoff/trailer-do-zero/<etapa>.md` (`diagnostico`, `ferramentas`, `roteiro`, `corte1`). A revisora escreve `revisao-<etapa>.md`; a diretora responde ponto a ponto em `resposta-<etapa>.md`, ajusta o entregável e só então segue. Commit a cada etapa.
1. **diagnostico**: todas as versões por quadros, forma de onda e loudness; o que funciona e o que não (ritmo, leitura das cartas, gancho, clareza do gameplay, emoção, som, texto, final); trailers de referência do gênero e o que os faz prender.
2. **ferramentas**: inventário de skills, PixelLab MCP, ACE-Step, síntese local de SFX, captura headless e o resto; o que cada uma acrescenta.
3. **roteiro**: do zero; gancho nos 2 primeiros segundos, arco com pico perto de 80%, momentos sem música, som do jogo nos pontos-chave, chamada final; storyboard com timestamps.
4. **corte1**: animatic ou 1º corte em 1080p + 720p leve. Para aí, sem master 4K.

## Régua (01/11 14:27)
Responda e relate sempre em português. Regra nova do Daniel: a régua é MUITO alta. Depois de cada corte, revisar tudo de tudo e seguir refinando em ciclos: continuidade entre planos (posição, luz, cor, direção do movimento, nada pulando), se está bom, se é legal de assistir e se prende do início ao fim. A revisora só aprova com nota alta (>=9) em TODOS os critérios; se algum estiver mediano, faz outra rodada de correção antes de liberar. Só marcar ===CORTE1_PRONTO=== depois da aprovação da revisora. O Grimoire também vai revisar o corte antes do Daniel e pode devolver para mais rodadas. Anexe este texto, literal, em docs/handoff/trailer-do-zero.md numa seção '## Régua (01/11 14:27)' e commite (Daniel Cortez, sem push).

## Decisão salões (01/11 14:31)
Responda e relate sempre em português. Decisão do Daniel: MANTER os salões do Higgsfield nos acentos da música, como no pedido original. Não substituir pelos salões reais castle_hall_1 a 6. Os salões reais podem entrar como complemento onde ajudar a leitura do jogo, mas os acentos ficam com o Higgsfield. A declaração de IA na Steam continua pendente com o Daniel; não é bloqueio. Ajustem o diagnóstico/roteiro de acordo; a revisora não deve mais tratar isso como pendência. (Isto substitui a mensagem anterior do Grimoire sobre usar só os salões reais.) Anexe este texto, literal, em docs/handoff/trailer-do-zero.md numa seção '## Decisão salões (01/11 14:31)' e commite (Daniel Cortez, sem push).

## Estado
- [x] diagnostico (revisado, `resposta-diagnostico.md`)
- [ ] ferramentas (entregue, em revisão)
- [ ] roteiro
- [ ] corte1
