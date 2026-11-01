# Resposta à revisão do diagnóstico

_Diretora, 01/11/2026. Responde a `revisao-diagnostico.md` (rodada 1, nota 7,5). O `diagnostico.md` foi corrigido no texto e ganhou a seção 6 com as decisões._

| # | ponto da revisora | resposta | onde ficou |
|---|---|---|---|
| 1 | "137 LIVING CARDS" desatualizado | **Aceito.** Recontei: 145 cartas (basic 27, boss 6, mage 42, rogue 37, warrior 33), 139 sem os coringas de chefe; 42 criaturas únicas no `ROSTER` (bate com as 42 pastas de voz); 6 atos (`Config.lua:141`). Regra "número na tela = número contado no código", com os comandos. | diag. §3 (tabela), §4 (Vampire Survivors), §6.1 |
| 2 | pausa subestimada (3 a 5 dB) | **Aceito, errei a leitura da minha própria curva.** Na curva de curto prazo do B_som: 28 a 29 s = −11/−12; 30 a 37 s = −15 a −19. São 5 a 9 dB. Meta fixada: ≥ 15 dB abaixo do trecho anterior, curto prazo de 3 s, e o impacto volta ao nível anterior ou acima. | diag. §1, §6.2 |
| 3 | TV antes da música × carta viva no quadro 0 | **Aceito.** Regra: o filme começa no meio do liga-TV (vidro ~60% aberto já com a carta viva), a TV termina em ≤ 0,8 s com o som de ligar do jogo sozinho, e a música entra no 1º grave depois. Cumpre os dois pedidos. | §6.3 |
| 4 | salões do Higgsfield sem decisão | **Aceito a proposta.** Corte 1 só com `castle_hall_*` reais com o chefe dentro; IA fora, e se o Daniel quiser manter o pedido 9, volta só como ponte ≤ 1 s re-pixelizada e declarada. Marcado como pendência para ele na Entrega. | §6.4 |
| 5 | gancho não escolhido | **Aceito, com um ajuste na sua leitura.** Frase: "Cada chefe quebra as regras da luta, e o seu baralho vivo é o que quebra de volta." Mostrado 3×: corvos (Rei-Carniça), Geada do Monarca congelando cartas **na mão** (a regra do chefe aparece na carta: liga os dois lados do gancho) e correntes do Tirano ou runas do Lich. Carta viva é a textura, não um 2º gancho. | §6.5 |
| 6 | viabilidade do close | **Aceito e medido.** Tomadas atuais = 1920×1080 com CRT embutido; a mão não escala com a resolução, então 4K **não** aumenta a carta. O gravador aceita `TRAILER_CRT=0`, `TRAILER_NOBEZEL=1`, `TRAILER_SIZE`. Caminho: capturar sem CRT, recortar 960×540 (×2) ou 640×360 (×3) e ampliar por vizinho mais próximo (carta a 36% ou 53% da altura), CRT aplicado depois na escala do filme; Coleção para o close máximo. Teste em 1 tomada na etapa 2, antes do roteiro. | §6.7 |
| 7 | microtrailer simulado | **Feito.** Usei as frações do único relato medido (0,33 a 0,87 da duração). 18 fatias, 0 com carta legível, 3 de bússola no escuro. Regra nova: entre 30% e 90% da duração, todo segundo tem carta grande ou criatura em ação; logo só depois de 90%. | §6.9 |
| 8 | alvo e formato | **Aceito.** Corte 1 = 1º vídeo da página, 60 a 70 s; o 30 s sai depois como recorte. | §6.6 |
| 9 | luta encenada | **Aceito.** Dependência registrada para a etapa 2 (modo cheat: vida baixa, mão escolhida, LETAL na prévia, mecânica de chefe ativa). | §6.8 |

Todos os itens do checklist estão atendidos, inclusive o opcional (microtrailer). Sigo para `ferramentas.md`; o teste de recorte em escala inteira (item 6) vai junto com ela.
