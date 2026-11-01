# Revisão do Grimoire: corte 5 (01/11/2026 20:03)

**Veredito: REPROVADO.** Tirano 6,5 / Rei 8,0. Abrir o corte 6 nas duas versões.

## Antes de mexer
A diretora confere cada ponto quadro a quadro com o `medir2.py` e salva PNG de prova em `corte6_provas/`. O revisor do Grimoire é só visual e às vezes erra; ponto falso é contestado com prova (como no corte 4) e não é mexido.

## Pontos
1. **Zoom que recua (Tirano ~0:53):** logo após o golpe o zoom entra, dá um tranco para trás e volta. Só degraus inteiros para dentro, mesmo centro.
2. **Caminhada (Tirano 0:24–0:30):** 6 s antes do castelo; máximo 2 s. Conferir se Tirano e Rei divergem.
3. **Portão (~0:30):** no Rei parece zoom digital em imagem parada. O castleGateOpen real tem de estar visível, com as folhas se movendo.
4. **48 no golpe (52,83 s):** só aparece na UI pequena. Pôr um número de dano GRANDE saltando sobre o Rei no hit-stop.
5. **BREAK THEM BACK.:** entra durante a queda; deve entrar só depois que a poeira assenta (a queda continua ≤ 2,5 s).
6. **Espólio:** a Carrion Crown fica parada só ~1–1,5 s antes de girar (medimos 3,09 s; conferir o que conta como parada). Deve ficar parada e legível de 2,5 a 3 s.
7. **Coringa:** os dois revisores viram o verso (rosa dos ventos) virar logo, sem a face. A face precisa aparecer com clareza por no mínimo 0,5 s antes do logo.
8. **Texto:** conferir no quadro se "145 LIVING CARDS." tem o ponto final.
9. **Salões do Higgsfield (trono ~0:33, gelo ~0:20):** ficam (decisão do Daniel), mas fazer limpeza de paleta, ruído e bordas para casar com os sprites, sem trocar o salão.
10. **Batidas do Rei:** medir os onsets (librosa ou similar) nos 5 cortes (LETHAL do gancho, Revoada, queda, coringa, logo). Corte a mais de 2 quadros de um ataque forte deve ser movido, exceto silêncios intencionais. Gerar tabela (tempo do corte, onset mais próximo, distância em quadros, força, ação) e anexar.

## Avaliação
A revisora avalia o corte 6 contra esses 10 pontos, além dos critérios de sempre (≥ 9 em todos, incluindo Q), nas duas versões, e registra real/falso de cada ponto com o PNG.

## Regras
Nenhuma troca de faixa, texto ou salão: se surgir, parar e reportar ao Grimoire. Um lovec, headless, sem 4K, push, Steam ou save real; não sobrescrever masters antigos (saídas `grimoire_zero_corte6_*`). Commits como Daniel Cortez, sem Co-Authored-By.