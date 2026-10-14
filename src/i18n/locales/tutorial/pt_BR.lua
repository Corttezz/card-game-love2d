-- Onboarding v2 (src/systems/Tutorial + src/ui/Narrator + components/GuideScreen):
-- roteiro do corvo narrador (script.<conversa>.<fala>, *ênfase* em sangue),
-- rodapé do balão, Guia de combos/glossário, tooltip da mana. Arquivo próprio
-- por locale; plugado no principal como `tutorial = require(...)`.
return {
    narrator = { name = "Pena" },
    footer = {
        ["continue"] = "Continuar",
        skip = "pular conversa",
        disable = "Já sei jogar: desligar o tutorial",
    },
    act = {
        select = "Selecione uma carta",
        play = "Aperte Jogar Cartas",
        end_turn = "Aperte Encerrar Turno",
    },
    settings_tips = "Tutorial do corvo",
    settings_reset = "Recomeçar o tutorial",
    settings_reset_value = "{n} conversas vistas",
    settings_reset_done = "Do começo",
    script = {
        intro = {
            hello = "Croac! Eu sou o *Pena*, o corvo guardião deste grimório. Vou te ensinar a lutar. Prometo ser breve.",
            enemy = "Este é o seu adversário. A barra sob ele é a *vida*: zere-a e a luta acaba.",
            intent = "Este ícone é a *intenção* dele: o que ele fará quando o seu turno acabar. O número é o dano que vem aí.",
            hero = "Aqui ficam a SUA *vida* e o seu *Bloqueio*. Se a vida chegar a zero, a jornada termina.",
            hand = "Estas são as suas cartas. O grimório começa com só duas. *Selecione uma* para prepará-la.",
            mana = "Cada carta custa *mana*: o número no canto dela. A mana enche de novo a cada turno, então gaste sem dó.",
            preview = "Esta é a *prévia*: quanto dano e quanto Bloqueio a seleção vai render, já com todos os bônus.",
            play = "Pronto? Mande ver: aperte *Jogar Cartas*!",
        },
        end_turn = {
            ["end"] = "Belo golpe! Quando acabar a mana ou as ideias, aperte *Encerrar Turno*. Aí o inimigo age, exatamente como a intenção avisou.",
        },
        second_turn = {
            kept = "Viu? Ele fez o que anunciou. Leia a *intenção* a cada turno e se proteja quando o golpe for grande.",
            loop = "Mão nova a cada turno, mana cheia de novo. Agora é com você. Eu apareço quando houver novidade. Croac!",
        },
        boss = {
            arrive = "Este é o *chefe* do ato. Vença-o e a estrada segue para a próxima terra.",
            signature = "Todo chefe tem um golpe próprio: invocação, carga, golpe que fura o Bloqueio... Leia a *intenção* a cada turno.",
        },
        elite = {
            warn = "Cuidado: um *Elite*. Mais forte que um inimigo comum, mas o prêmio também é melhor.",
        },
        block = {
            reset = "Você ganhou *Bloqueio*: ele absorve o próximo golpe. Mas atenção: o Bloqueio *zera no começo do seu turno*. Não dá para guardar.",
        },
        combo = {
            seal = "Jogue várias cartas JUNTAS: cada ataque depois do primeiro ganha dano (*Saraivada*), cada defesa depois da primeira ganha Bloqueio (*Muralha*) e cartas iguais valem mais (*Par*).",
            guide = "O selo em cima da carta mostra o bônus que ela ganharia agora. A lista completa está no *Guia*, no menu de Pausa.",
        },
        conduit = {
            passive = "Você é um *Mago*. Sua passiva, *{passive}*, abre toda luta com um *orbe de Raio* já na fileira. Orbe é um feitiço que fica armado e age sozinho.",
            row = "Esta é a sua *fileira de orbes*: {slots} vagas. Vaga vazia é um aro apagado. Orbe novo entra pela direita.",
            number = "O número sob o orbe diz o que ele faz sozinho no fim de cada turno seu: o *pulso*. Este Raio pulsa *{pulse}* de dano.",
        },
        channel = {
            card = "Esta carta *canaliza*: além do efeito escrito, cria um orbe novo na fileira. Passe o mouse nela e a vaga que vai recebê-lo pisca.",
            made = "Você *canalizou*: a carta fez o efeito escrito E criou um orbe novo, que entrou pela direita da fileira.",
            oldest = "O da esquerda, com a moldura clara, é o *mais antigo*. A seta no trilho marca a saída: quando um orbe sai, é sempre ele primeiro.",
            hover = "Passe o mouse num orbe para ver os números exatos: quanto ele pulsa por turno e quanto rende ao *evocar*. Já chego lá.",
        },
        pulse = {
            happened = "Viu o fim do seu turno? Os orbes *pulsaram*: cada um fez o que o número dizia, sem gastar carta nem mana. É assim todo turno, enquanto estiverem na fileira.",
            kinds = "Cada elemento pulsa de um jeito: *Raio* e *Fogo* ferem o inimigo, *Gelo* dá Bloqueio, *Sagrado* cura. *Sombra* não pulsa: cresce a cada turno e evoca em dobro.",
            reveal = "E o clarão do *Raio* tem um bônus: quando a intenção do inimigo estiver escondida pela névoa, o pulso dele revela o próximo anúncio.",
        },
        evoke_card = {
            card = "Esta carta *evoca*: o orbe mais antigo, o da moldura, sai da fileira e dispara de uma vez o efeito *cheio*. Mais forte que o pulso, mas o orbe se vai.",
            preview = "Passe o mouse na carta: o orbe que vai sair acende em *ciano* e o número vira o valor da evocação.",
            all = "*Evocar todos* esvazia a fileira inteira, um orbe por vez, do mais antigo ao mais novo.",
        },
        overflow = {
            full = "Fileira cheia e você canalizou mais um: o orbe *mais antigo* foi expulso e, ao sair, *evocou* com o valor cheio. Nada se perde.",
            plan = "Ou seja: com as {slots} vagas cheias, cada canalização nova também é uma evocação. Encha a fileira e cada carta vira um disparo.",
        },
        focus = {
            what = "Você tem *Foco*: cada ponto soma no valor de todos os seus orbes, no pulso e na evocação. Os números nos orbes já contam o Foco.",
            conduit = "Daqui em diante o *{passive}* também dá {f} de Foco no começo de cada luta. Quanto mais fundo na jornada, mais Foco.",
        },
        jokers = {
            passive = "Um *Coringa*! Ele age sozinho pela jornada inteira, sem gastar mana.",
            bench = "Só os *ativos* deste quadro funcionam; os outros esperam na bancada. Abra o quadro para trocá-los.",
        },
        rewards = {
            pick = "Vitória! Escolha *uma* carta para o grimório.",
            skip = "Ou pule: um grimório enxuto compra as melhores cartas mais vezes. Às vezes, menos é mais.",
        },
        dice_help = {
            what = "Os *Dados do Escriba* são uma aposta opcional: você dá um palpite sobre a soma de dois dados e arrisca ouro nele.",
            bets = "*Baixo* (soma 2 a 6) e *Alto* (8 a 12) acertam 42% das vezes e pagam 2,5× a ficha. O *Sete* acerta 17% e paga 6×.",
            stakes = "A *ficha* é quanto você arrisca, e os valores sobem a cada ato. Se errar, a ficha fica com a casa.",
            once = "Uma jogada por visita à loja, e o resultado vale na hora, mesmo se você sair e voltar. Na média a mesa empata: serve para arriscar quando falta pouco para uma compra.",
        },
        dice = {
            odds = "Dois dados, uma aposta. *Baixo* (2 a 6) e *Alto* (8 a 12) pagam 2,5×; o *Sete* paga 6×.",
            bet = "Escolha a aposta e o valor da ficha, depois lance. A chance de cada aposta está escrita nela.",
        },
        shop = {
            offers = "A *loja*! Cartas nos cavaletes, relíquias e um pacote sobre o balcão, a troco de ouro.",
            price = "O *preço* está em cada peça: placa de latão sob a carta, etiqueta pendurada na frente do balcão para o resto. Em vermelho, o que você ainda não pode pagar.",
            buy = "Clique numa peça para lê-la no *pergaminho*; a compra é na fita *COMPRAR*. Passe o mouse e os objetos contam o que fazem.",
            refresh = "Nada agradou? *Novas ofertas* troca a vitrine, mas fica mais caro a cada vez.",
            dice = "E ali, os *Dados do Escriba*: aposte ouro num lance de dois dados. Uma jogada por loja.",
            interest = "Ah: ouro guardado rende *juros*. Cada $5 no bolso vale +$1 ao vencer uma batalha, até +$5.",
        },
        forge = {
            pick = "Na *forja*, escolha uma carta para melhorar. Cada cópia evolui separada.",
        },
        rest = {
            choose = "Uma *fogueira*. Descanse para recuperar vida, ou use o tempo para *forjar* uma carta.",
        },
        event = {
            read = "Um *evento*! Leia com calma: cada escolha mostra o que custa [-] e o que dá [+].",
        },
        fork = {
            paths = "Uma *encruzilhada*. Cada marco é um caminho: batalha, *Elite*, descanso, loja ou evento. Escolha o seu.",
        },
        endless = {
            cycle = "Além do último chefe, o *Sem Fim*. A cada ciclo de oito andares, você escolhe uma *maldição*.",
            grow = "Os inimigos crescem a cada ciclo, sem limite. Até onde o seu grimório aguenta?",
        },
        class_select = {
            welcome = "Croac! Antes da jornada, escolha quem vai empunhar o grimório. Para começar, ninguém melhor que o *Guerreiro*.",
            warrior = "O Guerreiro bate firme e aguenta pancada. A passiva dele é *{passive}*: {rule}",
            start = "Comece por aqui. Quando estiver pronto, é só abrir a jornada nesta fita.",
            locked = "As outras classes estão acorrentadas e se libertam jogando. {list}",
            details = "E este marcador abre os *detalhes* da classe: as cartas iniciais e os números.",
        },
        fog = {
            veil = "A *névoa* fechou. Você ainda vê o TIPO do golpe dele, mas não o número. O golpe já está decidido, só a leitura sumiu.",
            counter = "Quando a nevasca abre, o número volta. Cartas de *Revelar* e o pulso do orbe de Raio também dissipam a névoa por um turno.",
        },
        seals = {
            unlocked = "Você venceu! Agora pode romper os *Selos do Grimório*: cada selo é uma regra mais dura, e eles se acumulam.",
            score = "Mais selos, mais pontos. Vença num selo para liberar o próximo, com a mesma classe.",
        },
    },
    guide = {
        title = "GUIA DO GRIMÓRIO",
        tab_combos = "Combos",
        tab_glossary = "Glossário",
        examples = "Ex.: {cards}",
        intro = "Combos valem entre cartas jogadas JUNTAS, na mesma leva. O selo em cima da carta da mão mostra quanto ela ganharia de combo.",
        close_hint = "Esc / B fecha · < > abas",
        pause_shortcut = "Guia [G]",
    },
    status = {
        mana = { name = "Mana",
            desc = "{stacks} de {duration} disponível. Cada carta custa o número do canto dela. Enche de novo no começo do seu turno; sobra não acumula." },
    },
}
