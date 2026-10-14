---
name: code_notes/components/EventScreen.lua
description: Comentários com decisão/regra/histórico colhidos de components/EventScreen.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `components/EventScreen.lua`

Origem: `components/EventScreen.lua` em `7dbdb60d` (32 de 44 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-8 (junto a `local EventScreen = {}`)

> components/EventScreen.lua
> Narrativa: titulo + corpo + 2-4 opcoes. Executa option.apply(game) e fecha.
>
> F4 do UI Overhaul (docs/plan/ui-ux-overhaul-v1.md): cena real de fundo
> (path_event), painel grimório (Panel9) com ILUSTRAÇÃO do evento
> (assets/sprites/ui/event_<id>.png, geradas via PixelLab) e opções dentro
> do painel — no lugar do miolo vazio da tela antiga (nota D+ no
> levantamento).

## L33-36 (em `reducedMotion`, junto a `local _sfxWarned = {}`)

> Toca o primeiro código registrado da lista (contrato de som novo do
> projeto: o call site nasce pronto e o arquivo passa a tocar sozinho quando
> cair em audio/sfx/). Avisa só quando HÁ sistema de áudio — sem ele nenhum
> código resolve e o aviso seria ruído garantido em todo run headless.

## L73-74 (em `getIllustration`, junto a `local FXQ = "event_fx"`)

> Fila PRÓPRIA (memory/eventmanager_queues.md, regra de ouro): a `base`
> pertence ao combate e prende eventos de tela atrás do rabo dele.

## L77-80 (em `getIllustration`, junto a `local ENTER_DUR   = 0.34`)

> Entrada/saída: o painel sobe um pouco e assenta; o véu da cena escurece
> junto. Dose pequena de propósito — o dono pediu "efeitos sutis", e uma tela
> de LEITURA não pode chegar saltitando: o jogador precisa ler o texto, não
> assistir a ele.

## L94-96 (em `instance.buttons`, junto a `instance.panelOy = 0     -- deslocamento vertical da entrada/saída`)

> Estado de animação. Vive aqui (e não em locals do módulo) porque o
> resize precisa saber que existe — invariante §2: estado cacheado novo
> obriga a estender o resize NO MESMO commit.

## L125-126 (em `EventScreen:show`, junto a `playFirstSfx({ "eventEnterWind", "menuOpen" })`)

> O vento chega com a encruzilhada. Sustenta 1,5s por baixo da leitura,
> que é o tempo de o jogador olhar a ilustração e o texto.

## L130-132 (em `EventScreen:show`, junto a `function EventScreen:_closeWithFade()`)

> Saída com fade. Um evento é a decisão mais irreversível da run e terminava
> com um corte seco pro mapa; agora a tela se retira. O callback do fluxo vem
> DEPOIS, e só uma vez (_closing), pelo mesmo motivo da saída da loja.

## L165-169 (em `EventScreen:isVisible`, junto a `function EventScreen:_buildTitle()`)

> O DynaText do título nasce no SHOW (e no resize), não no primeiro draw.
> Criando-o em draw, o pop_in só começava a contar quando a tela já estava
> desenhando: o update() dos frames anteriores não tinha em que tickar, e num
> frame capturado logo após o show saía UMA letra ("Q" em vez de "Quelle des
> Lebens"). Com ele criado aqui, a cascata roda junto com a entrada.

## L176-178 (em `EventScreen:_buildTitle`, junto a `bump = false,`)

> bump DESLIGADO: título de evento é TEXTO DE LEITURA e o jogador
> precisa lê-lo parado — mesma decisão que o RoundEval tomou pro
> `totalText`. A ENTRADA pode ser animada; a leitura, não.

## L191-193 (em `EventScreen:resize`, junto a `self:_buildTitle()`)

> Estado cacheado que o resize TEM que recalcular junto: o DynaText do
> título deriva da fonte responsiva, então numa troca de resolução ele
> ficaria com a métrica antiga. panelOy/fade são relativos e sobrevivem.

## L208-216 (em `EventScreen:panelRect`, junto a `local function deltaText(d)`)

> Label da opção com custo/ganho EXPLÍCITO entre colchetes (padrão StS: o
> botão declara a troca, nunca é pegadinha). Campos data-driven da opção:
> gains = { "$45", "carta rara" }  →  [+$45 / +carta rara]
> costs = { "12 HP", "20 ouro" }   →  [-12 HP / -20 ouro]
> Sem esses campos o label sai como está (opções "ir embora" etc).
> Resolve UM delta. Aceita as duas formas:
> { k = "hp", n = 8, fb = "8 HP" }   → token traduzido, com {n}/{pct}
> "8 HP"                             → string crua (compat)
> A tabela inteira vai como `vars`, então {n} e {pct} interpolam sozinhos.

## L237-239 (em `parts`, junto a `function EventScreen:optionLabel(opt, index)`)

> Exposto pra ferramenta de verificação (tools/check_event_i18n.lua) medir
> o rótulo FINAL em todos os idiomas sem redesenhar a tela. Fonte única: é o
> mesmo texto que o botão recebe.

## L259-261 (em `onClick`, junto a `local rm = self.game and self.game.runManager`)

> ROTEIRO: registra a opção ANTES do apply — as aquisições do
> apply (carta, forja, remoção) caem na mesma entrada do nó e
> assim aparecem sob a opção que as causou.

## L270-272 (em `onClick`, junto a `local run = rm and rm.currentRun`)

> Escolha FEITA: um "Salvar e sair" durante o texto de resultado
> não pode reabrir este evento no Continuar (a opção seria
> aplicada duas vezes). O resume lê "event_done" → encruzilhada.

## L278 (em `onClick`, junto a `self.buttons = {}`)

> Limpa botoes enquanto feedback e exibido (impede duplo-click)

## L281-282 (em `self.buttons`, junto a `playFirstSfx({ "eventChoiceSeal", "buttonClick" })`)

> O LACRE: a escolha do evento é a decisão mais irreversível da
> run e não tinha marca nenhuma. Carimbo + tremor curto.

## L286-289 (em `self.buttons`, junto a `self:_spawnDeltas(opt, x + btnW * 0.5, y)`)

> O que a opção COBRA e o que ela PAGA sobe em número, do jeito
> que o combate já faz. O dado já existia estruturado em
> opt.gains/opt.costs (é o que monta o rótulo "[+$45 / -12 HP]");
> até agora só era texto dentro do botão, nunca um evento.

## L294-295 (em `self.buttons`, junto a `if not require("src.data.events").canAfford(opt, self.game) then`)

> Opção impagável (ouro/vida) nasce DESABILITADA: o rótulo já diz o
> custo, o botão cinza diz "agora não dá".

## L303-305 (em `self.buttons`, junto a `function EventScreen:_spawnDeltas(opt, cx, cy)`)

> Ganhos e custos da opção escolhida sobem como FloatingText, escalonados.
> Ganho em dourado, custo em vermelho — a MESMA leitura direcional do ouro na
> TopBar, pra não ensinar dois vocabulários de cor pro jogador.

## L313-318 (em `emit`, junto a `local texto = deltaText(txt)`)

> `txt` e um DESCRITOR { k, n, fb }, nao uma string: a migracao
> de i18n trocou o formato de gains/costs e atualizou o rotulo do
> botao (composeOptionLabel), mas este caminho ficou concatenando
> a tabela — crash ao escolher qualquer opcao com ganho ou custo.
> Passou despercebido porque a trava check_event_i18n mede o
> ROTULO, e o FloatingText nao tinha cobertura nenhuma.

## L331-337 (em `emit`, junto a `function EventScreen:_isAnimating()`)

> O painel é TRANSLADADO no desenho, mas o Button faz hit-test na posição
> real (love.mouse.getPosition contra self.x/y). Enquanto a entrada/saída
> corre, os dois discordam em até 26px — o jogador veria o realce numa opção
> e clicaria noutra. Então durante a animação a tela simplesmente não aceita
> input, e o hover fica limpo. Dura 0,34s; ninguém decide um evento nesse
> tempo, e a alternativa (compensar o offset em cada handler) espalharia a
> mesma constante por quatro lugares.

## L372-376 (em `EventScreen:draw`, junto a `love.graphics.push()`)

> MOVIMENTO do painel: translate no desenho, NUNCA somado em panelRect().
> panelRect é a âncora imutável do layout (lição das "cartas invisíveis":
> offset somado na posição-base vira feedback loop porque draw grava
> estado). Assim o botão continua sabendo onde ele mora, e a entrada é só
> uma camada de apresentação por cima.

## L383-385 (em `EventScreen:draw`, junto a `local ev = self.event`)

> Titulo via DynaText (pop-in cascata), no lugar do print estático.
> Título (DynaText montado no show) e corpo vêm do locale; os literais
> que sobraram em events.lua são o fallback.

## L387-388 (em `EventScreen:draw`, junto a `if self.titleDyna then`)

> DynaText:draw recebe o CENTRO vertical; o print antigo recebia o TOPO.
> +10 (meia altura da fonte 20) mantém o título no mesmo lugar de antes.

## L405-414 (em `EventScreen:draw`, junto a `local bodyLH = math.floor(bodyFont:getHeight() * 1.3 + 0.5)`)

> ENTRELINHA medida, não chutada (`love . check_font_metrics`): na fonte
> do projeto em corpo 10, `getHeight()` reporta 10px mas a TINTA dos
> glifos ocupa 11px — acento e descendente moram FORA da métrica. Como o
> printf empilha por getHeight(), a segunda linha subia por cima da
> primeira. Só aparecia em idioma de texto longo (o alemão), porque em PT
> quase todo corpo cabe numa linha.
>
> 1.1 não resolvia: dava exatamente 11px, ou seja, as linhas passavam a
> se encostar em vez de se sobrepor. 1.3 = 13px deixa 2px de respiro, que
> é o mínimo para 'Ç' de uma linha não beijar o 'p' da linha de cima.

## L418-420 (em `EventScreen:draw`, junto a `local function drawBody(x, y)`)

> Desenha as linhas JÁ QUEBRADAS, com a mesma entrelinha que o cálculo de
> altura acima usa. Antes o layout reservava 1.1 e o printf desenhava 1.0:
> dois números para a mesma coisa, e por isso um deles estava sempre errado.

## L444-445 (em `fill`, junto a `local contentY = math.floor(areaTop + math.max(0, (areaH - bodyH) / 2))`)

> sem ilustração: corpo CENTRALIZADO verticalmente (a tela antiga
> deixava um vazio enorme de pergaminho)

## L454 (em `fill`, junto a `if self.resultText then`)

> Feedback apos escolha

## L470-477 (em `fill`, junto a `local f = self.fade or 1`)

> CORTINA da transição. Um retângulo escuro por cima de tudo, abrindo na
> entrada e fechando na saída.
>
> Escolhi isto em vez de multiplicar alpha em cada setColor da tela: o
> fade por alpha exigiria tocar em ~15 pontos de desenho e qualquer um
> esquecido ficaria opaco no meio da transição — defeito que só aparece
> em 3 frames e ninguém acha depois. A cortina é uma linha, não tem como
> ficar pela metade, e lê como a encruzilhada emergindo do escuro.

## L490-491 (em `EventScreen:mousepressed`, junto a `for _, b in ipairs(self.buttons) do`)

> ARMA o pressed de cada botão. Sem isto o Button:mousereleased abaixo
> não dispara (ele exige self.pressed) — ver Button.lua:508.

## L501-505 (em `EventScreen:mousereleased`, junto a `for _, b in ipairs(self.buttons) do`)

> FIX Set/2026: esta tela chamava `b.onClick()` DIRETO, pulando o
> Button:mousereleased — e com ele o `buttonClick`, o `juice_up` e o
> jiggle que todo botão do jogo dá (Button.lua:516-528). Resultado: a
> escolha do evento, que é a decisão mais irreversível da run, era o
> único clique MUDO e sem reação do jogo inteiro.

## L519-521 (em `EventScreen:keypressed`, junto a `Sfx.playWithVariation("buttonClick", 1.0, 0.08)`)

> O atalho de teclado não passa pelo Button:mousereleased, então
> o feedback do clique é reproduzido aqui — escolher pelo 1-4 tem
> que soar igual a escolher pelo mouse.

