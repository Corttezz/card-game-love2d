-- Onboarding v2 (src/systems/Tutorial + src/ui/Narrator + components/GuideScreen):
-- roteiro do corvo narrador (script.<conversa>.<fala>, *ênfase* em sangue),
-- rodapé do balão, Guia de combos/glossário, tooltip da mana. Arquivo próprio
-- por locale; plugado no principal como `tutorial = require(...)`.
return {
    narrator = { name = "Pena" },
    footer = {
        click = "Clique para seguir",
        ["continue"] = "seguir",
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
            seal = "Olha só: cartas da sua mão *combinam*! Jogadas JUNTAS, no mesmo turno, rendem mais. A prévia mostra o selo *+COMBO*.",
            guide = "A lista completa de combos mora no *Guia*, no menu de Pausa.",
        },
        orbs = {
            pulse = "Seus *orbes*! Cada um pulsa no fim do seu turno, e o número escrito nele é o efeito.",
            evoke = "Canalizar com a fileira cheia *evoca* o mais antigo, o da seta, num efeito maior.",
        },
        jokers = {
            passive = "Um *Coringa*! Ele age sozinho pela jornada inteira, sem gastar mana.",
            bench = "Só os *ativos* deste quadro funcionam; os outros esperam na bancada. Abra o quadro para trocá-los.",
        },
        rewards = {
            pick = "Vitória! Escolha *uma* carta para o grimório.",
            skip = "Ou pule: um grimório enxuto compra as melhores cartas mais vezes. Às vezes, menos é mais.",
        },
        dice = {
            odds = "Dois dados, uma aposta. *Baixo* (2 a 6) e *Alto* (8 a 12) pagam 2,5×; o *Sete* paga 6×.",
            bet = "Escolha a aposta e o valor da ficha, depois lance. A chance de cada aposta está escrita nela.",
        },
        shop = {
            offers = "A *loja*! Cartas, relíquias e pacotes, a troco de ouro.",
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
        intro = "Combos valem entre cartas jogadas JUNTAS, na mesma leva. O selo +COMBO na mão avisa quando um está montado.",
        close_hint = "Esc / B fecha · < > abas",
        pause_shortcut = "Guia [G]",
    },
    status = {
        mana = { name = "Mana",
            desc = "{stacks} de {duration} disponível. Cada carta custa o número do canto dela. Enche de novo no começo do seu turno; sobra não acumula." },
    },
}
