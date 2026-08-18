# Manual de utilização — ZS Angola

Para o responsável (Amadeu) e a equipa no terreno. Descreve só o Helpdesk ZS Angola.

Entrar em **https://helpdesk.storesace.cv/otobo/** com a conta de agente.

---

## O que o sistema distingue

| Papel | No computador | No telemóvel / tablet |
|---|---|---|
| **Responsável (Amadeu)** | Painel de Controlo completo. Folha **opcional**. | Continua no Agent normal — **não** usa o modo de campo. |
| **Colaborador** (Paulo, David, Henriques, A. Angola, …) | Pode usar o Agent. | Entra no **modo de campo**: ecrã simples para tickets e folhas. |

Duas formas de trabalhar num ticket:

1. **Responder** (e-mail / nota) — conversa com o cliente, **sem** contar tempo. O responsável pode fazer isto sempre, sem abrir folha.
2. **Folha de trabalho** — intervenção com tipo, notas, tempo e resultado. É isto que aparece no painel «Folhas de trabalho abertas».

Sem folha **iniciada**, o responsável **não** vê o trabalho em curso nesse quadro. Um ticket aberto na lista de tickets não chega: o técnico tem de **iniciar a folha**.

---

## Responsável: ver o que está a ser feito agora

1. Abrir **Painel de Controlo**.
2. Ir ao bloco **«Folhas de trabalho abertas»**.
3. Cada linha é uma folha **em execução** ou **em pausa**: cliente, número do ticket, título, **técnico**, estado, início e duração.
4. Clicar na linha abre a folha desse técnico.

Nessa folha o responsável **consulta** (tipo, técnico, notas, se está em pausa). **Não** pode pausar, terminar nem cancelar — o técnico no terreno continua a ser quem edita.

No zoom do ticket, o menu equivalente chama-se **«Ver folha de trabalho»**.

Se o bloco não aparecer: no próprio painel, nas definições dos widgets, activar **«Folhas de trabalho abertas»** e actualizar a página.

**A lista só tem folhas a decorrer.** Quando o técnico termina, a linha desaparece. O trabalho feito fica no ticket (passo seguinte).

---

## Responsável: ver o que já foi feito

1. Abrir o **ticket** (pesquisa, lista de tickets abertos, ou o número no e-mail).
2. Nas comunicações, procurar o artigo **«Folha de trabalho»**: tipo, técnico, horas, notas, resultado e duração.
3. O histórico do ticket mostra mudanças de proprietário e de estado.

Para um cliente concreto (ex.: KITX): **Procurar** pelo nome ou código do cliente, ou filtrar a vista de tickets.

---

## Responsável: passar um ticket a um técnico

1. Abrir o ticket.
2. Alterar o **proprietário** para o colaborador que vai intervir.

Se o responsável tinha **iniciado uma folha** nesse ticket, essa folha passa para o novo proprietário (desde que ele não tenha já outra folha a decorrer). A folha de um técnico que **já está a trabalhar** nesse ticket **não** é retirada.

Não é obrigatório o responsável abrir folha para atribuir trabalho. Basta o proprietário; o técnico inicia a folha no terreno.

---

## E-mails que o responsável recebe

Remetente: **Helpdesk - ZS Angola \<assistencia@zsa-softwares.com\>**. Destino: o e-mail da conta do responsável.

Recebe aviso quando um **colaborador**:

- cria um ticket, ou
- inicia uma folha.

O botão no e-mail abre essa folha / ticket. Criar ticket e abrir folha no modo de campo no mesmo passo gera **um** e-mail, não dois.

**Não** recebe este aviso quando é o próprio responsável a criar o ticket ou a iniciar a folha. O **cliente** também **não** recebe este aviso.

O e-mail da folha **para o cliente** é outra coisa: só se o técnico, ao **terminar**, escolher «Enviar por e-mail ao cliente = Sim».

---

## Equipa no terreno (modo de campo)

No telemóvel, após o login, o painel de campo tem essencialmente:

- **Folhas** — tickets **já em seu nome**; ao escolher, abre ou inicia a folha.
- **Novo ticket** — Cliente → utilizador → título / problema → gravar **e abrir folha**.

Regras:

- Só se vê no painel do responsável o que tiver **folha iniciada**.
- Com folha **em execução**, o ecrã fica nessa folha até pausar ou terminar. A folha **não** deve recarregar sozinha.
- Em **pausa**, pode voltar ao painel; não pode abrir outra folha nem criar outro ticket até retomar ou terminar.
- **Um equipamento de cada vez**: entrar noutro telemóvel encerra a sessão no anterior.

Para o responsável acompanhar uma visita: o ticket tem de estar **no nome do técnico** e a folha **iniciada**.

---

## Tempo dispendido da equipa

Menu **Relatórios** → **Tempo dispendido**. Escolher as datas **De** e **Até** e **Mostrar**. **Gerar PDF** descarrega o mesmo relatório (capa Helpdesk, marca ZS Angola neste perfil), incluindo um **resumo por cliente** (uma secção por cliente com morada, trabalhos e totais).

Aparecem as folhas da equipa nesse período (em curso, em pausa e já terminadas), ordenadas por **cliente** e **loja**, com o tempo de cada uma e totais. O cliente de teste **1009** não entra neste relatório. Só entra trabalho com **folha iniciada**. Responder por e-mail sem folha não conta tempo.

O responsável vê toda a equipa; um colaborador vê só as suas folhas.

---

## O responsável também pode trabalhar

Pode responder ao cliente sem folha. Pode, se quiser, **Iniciar trabalho** no zoom e tratar a intervenção com tempo e resultado.

Enquanto tiver uma folha **sua** a decorrer, o sistema impede iniciar outra. Consultar a folha de um colaborador (só leitura) continua possível.

---

## Se não aparecer o que se espera

| Situação | O que verificar |
|---|---|
| Não vê a folha do técnico | A folha está iniciada? Já foi terminada? Actualizar o painel. |
| Só vê uma folha e faltam outras | Actualizar o painel. Devem aparecer **todas** as da equipa ZS que estejam abertas ou em pausa. |
| Clicou e não consegue editar | É a vista do responsável: só leitura. Quem edita é o técnico da folha. |
| Não chegou e-mail | Foi um colaborador a criar/iniciar? Ver pasta de spam. Acções do próprio responsável não geram este e-mail. |
| O técnico não tem o cliente na lista | O responsável tem de atribuir o cliente (ou a loja) a esse colaborador em **Agentes e colaboradores**. |
| «Já existe uma folha de trabalho em curso» | Outra pessoa já tem folha aberta nesse ticket. Abrir pelo painel «Folhas de trabalho abertas» ou pelo menu «Ver folha de trabalho». |
| Ticket *Delivery status notification* / e-mail não entregue | A mensagem não chegou ao cliente (endereço inválido, caixa inexistente, etc.). Abre-se no **ticket original**, não como ticket novo. Recebem aviso o técnico que enviou **e o agente responsável** (Amadeu). Na ficha do utilizador de cliente, o botão **Verificar** ao lado de cada e-mail confirma se o servidor de correio aceita o endereço (não envia mensagem ao cliente). Corrigir o e-mail e voltar a enviar se ainda for preciso. O cliente **não** vê esta devolução. |

Dúvidas de operação do Helpdesk: menu **Ajuda**. Comportamento nativo de tickets: [manual de utilizador OTOBO 11.0](https://doc.otobo.org/manual/user/11.0/en/content/index.html) (inglês; a interface desta instalação está em português).
