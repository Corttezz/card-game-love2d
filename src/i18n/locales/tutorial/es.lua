-- Onboarding v2 (src/systems/Tutorial + src/ui/Narrator + components/GuideScreen):
-- roteiro do corvo narrador (script.<conversa>.<fala>, *ênfase* em sangue),
-- rodapé do balão, Guia de combos/glossário, tooltip da mana. Arquivo próprio
-- por locale; plugado no principal como `tutorial = require(...)`.
return {
    narrator = { name = "Pluma" },
    footer = {
        ["continue"] = "Continuar",
        skip = "saltar charla",
        disable = "Ya sé jugar: apagar el tutorial",
    },
    act = {
        select = "Selecciona una carta",
        play = "Pulsa Jugar Cartas",
        end_turn = "Pulsa Terminar Turno",
    },
    settings_tips = "Tutorial del cuervo",
    settings_reset = "Reiniciar el tutorial",
    settings_reset_value = "{n} charlas vistas",
    settings_reset_done = "Desde el principio",
    script = {
        intro = {
            hello = "¡Cruac! Soy *Pluma*, el cuervo guardián de este grimorio. Te enseñaré a luchar; prometo ser breve.",
            enemy = "Este es tu adversario. La barra bajo él es su *vida*: déjala en cero y la lucha termina.",
            intent = "Este icono es su *intención*: lo que hará cuando acabe tu turno. El número es el daño que se viene.",
            hero = "Aquí están TU *vida* y tu *Bloqueo*. Si la vida llega a cero, el viaje termina.",
            hand = "Estas son tus cartas; el grimorio empieza con solo dos. *Selecciona una* para prepararla.",
            mana = "Cada carta cuesta *maná*: el número de su esquina. El maná se recarga cada turno, así que gástalo sin miedo.",
            preview = "Esta es la *vista previa*: cuánto daño y cuánto Bloqueo dará tu selección, con todos los bonus.",
            play = "¿Listo? Adelante: ¡pulsa *Jugar Cartas*!",
        },
        end_turn = {
            ["end"] = "¡Buen golpe! Cuando se acaben el maná o las ideas, pulsa *Terminar Turno*. Entonces actúa el enemigo, tal como avisó su intención.",
        },
        second_turn = {
            kept = "¿Ves? Hizo lo que anunció. Lee la *intención* cada turno y protégete cuando venga un golpe fuerte.",
            loop = "Mano nueva cada turno y el maná lleno otra vez. Ahora te toca a ti; apareceré cuando haya novedades. ¡Cruac!",
        },
        boss = {
            arrive = "Este es el *jefe* del acto. Derrótalo y el camino sigue hacia la próxima tierra.",
            signature = "Cada jefe tiene un golpe propio: invocación, carga, golpes que atraviesan el Bloqueo. Lee la *intención* cada turno.",
        },
        elite = {
            warn = "Cuidado: un *Élite*. Más fuerte que un enemigo común, pero el premio también es mejor.",
        },
        block = {
            reset = "Ganaste *Bloqueo*: absorbe el próximo golpe. Pero ojo: el Bloqueo *se reinicia al empezar tu turno*; no se puede guardar.",
        },
        combo = {
            seal = "Mira: ¡cartas de tu mano *combinan*! Jugadas JUNTAS en el mismo turno rinden más; la vista previa muestra el sello *+COMBO*.",
            guide = "La lista completa de combos está en la *Guía*, en el menú de Pausa.",
        },
        orbs = {
            pulse = "¡Tus *orbes*! Cada uno pulsa al final de tu turno; el número escrito en él es el efecto.",
            evoke = "Canalizar con la fila llena *evoca* el más antiguo, el de la flecha, con un efecto mayor.",
        },
        jokers = {
            passive = "¡Un *Comodín*! Actúa solo durante toda la partida, sin gastar maná.",
            bench = "Solo funcionan los *activos* de este marco; los demás esperan en el banco. Abre el marco para cambiarlos.",
        },
        rewards = {
            pick = "¡Victoria! Elige *una* carta para el grimorio.",
            skip = "O sáltala: un grimorio ligero roba sus mejores cartas más a menudo. A veces, menos es más.",
        },
        dice_help = {
            what = "Los *Dados del Escriba* son una apuesta opcional: eliges un pronóstico para la suma de dos dados y arriesgas oro en él.",
            bets = "*Bajo* (suma 2 a 6) y *Alto* (8 a 12) aciertan el 42% de las veces y pagan 2,5× la ficha. El *Siete* acierta el 17% y paga 6×.",
            stakes = "La *ficha* es cuánto arriesgas, y sus valores suben en cada acto. Si fallas, la casa se la queda.",
            once = "Una tirada por visita a la tienda, y el resultado vale al instante, aunque salgas y vuelvas. De media la mesa empata: sirve para arriesgar cuando te falta poco para una compra.",
        },
        dice = {
            odds = "Dos dados, una apuesta. *Bajo* (2 a 6) y *Alto* (8 a 12) pagan 2,5×; el *Siete* paga 6×.",
            bet = "Elige la apuesta y la ficha, y lanza. Cada apuesta muestra su probabilidad.",
        },
        shop = {
            offers = "¡La *tienda*! Cartas, reliquias y sobres, a cambio de oro.",
            refresh = "¿Nada te gusta? *Actualizar* cambia el escaparate, y cuesta más cada vez.",
            dice = "Y allí, los *Dados del Escriba*: apuesta oro a una tirada de dos dados. Una tirada por tienda.",
            interest = "Ah, y el oro guardado da *intereses*: cada $5 en el bolsillo vale +$1 al ganar una batalla, hasta +$5.",
        },
        forge = {
            pick = "En la *forja*, elige una carta para mejorar. Cada copia evoluciona por separado.",
        },
        rest = {
            choose = "Una *hoguera*. Descansa para recuperar vida, o aprovecha el tiempo para *forjar* una carta.",
        },
        event = {
            read = "¡Un *evento*! Lee con calma: cada opción muestra lo que cuesta [-] y lo que da [+].",
        },
        fork = {
            paths = "Una *encrucijada*. Cada hito es un camino: batalla, *Élite*, descanso, tienda o evento. Elige el tuyo.",
        },
        endless = {
            cycle = "Más allá del último jefe está el *Infinito*. En cada ciclo de ocho pisos eliges una *maldición*.",
            grow = "Los enemigos crecen en cada ciclo, sin límite. ¿Hasta dónde llegará tu grimorio?",
        },
        seals = {
            unlocked = "¡Ganaste! Ahora puedes romper los *Sellos del Grimorio*: cada sello es una regla más dura, y se acumulan.",
            score = "Más sellos, más puntos. Gana con un sello para liberar el siguiente, con la misma clase.",
        },
    },
    guide = {
        title = "GUÍA DEL GRIMORIO",
        tab_combos = "Combos",
        tab_glossary = "Glosario",
        examples = "Ej.: {cards}",
        intro = "Los combos cuentan entre cartas jugadas JUNTAS, en la misma jugada. El sello +COMBO en la mano avisa cuando hay uno listo.",
        close_hint = "Esc / B cierra · < > pestañas",
        pause_shortcut = "Guía [G]",
    },
    status = {
        mana = { name = "Maná",
            desc = "{stacks} de {duration} disponible. Cada carta cuesta el número de su esquina. Se recarga al inicio de tu turno; lo que sobra no se acumula." },
    },
}
