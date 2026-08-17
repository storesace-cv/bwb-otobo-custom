# Catálogo funcional BWB (desenvolvimento específico)

Inventário do comportamento **já implementado** nesta camada. Para o modelo genérico OTOBO, usar [REFERENCES.md](REFERENCES.md). Para o mapa de ficheiros, ver também [ARCHITECTURE.md](ARCHITECTURE.md).

Caminhos abaixo são relativos a `otobo/Custom/`, salvo indicação em contrário.

## Separação BWB / StoresAce ↔ ZS Angola

- Isolamento por filas, propriedade de cliente e módulos de permissão/pesquisa.
- Agentes ZS não podem ver clientes, tickets ou filas BWB.
- Código: `Kernel/System/BWBAccess.pm`, `Kernel/System/Ticket/Permission/BWBCustomerOwnerCheck.pm`, `Kernel/System/Ticket/TicketSearch.pm`, pesquisas de cliente (`AgentCustomerSearch.pm`, etc.).

## Clientes, lojas e colaboradores

- Empresa cliente com várias lojas; loja `S - Sede` criada por defeito.
- Utilizadores cliente associados a loja; clientes a agente responsável.
- Colaboradores com acesso por cliente ou por loja.
- `AdminUser` (módulo «Agentes e colaboradores») está aberto a `admin` e `bwb_customer_managers`. Após criar utilizador, o redirect fica em `AdminUser` (edição do novo user) — **não** em `AdminUserGroup`/`AdminRoleUser` (só `admin`); caso contrário gestores como Amadeu viam «Sem permissões para utilizar este módulo!» embora o utilizador tivesse sido criado.
- **E-mails alternativos do utilizador de cliente:** até **dois** endereços adicionais (`bwb_customer_user_email`), geridos na ficha `AdminCustomerUser`. Servem **só** para reconhecer correio de entrada (novo ticket / follow-up) via `PostMaster::PreFilterModule###090-BWBCustomerUserEmail` + `BWBCustomerUserEmail.pm`. A **saída** de e-mails do sistema continua exclusivamente para o e-mail principal (`UserEmail`).
- **Associar e-mail no zoom do ticket:** menu `Associar e-mail a utilizador de cliente` (`TicketMenu/BWBAddCustomerEmail`) quando o remetente ainda não é reconhecido. Modal nativo `Core.UI.Dialog.ShowContentDialog` (JS `Core.Agent.BWBAddCustomerEmailDialog.js`): Cliente → Utilizadores desse cliente (filtrados por `BWBAccess`) → grava alias + `TicketCustomerSet` + recarrega o zoom. Endpoint `AgentBWBAddCustomerEmail` devolve fragmento HTML (`Dialog=1`) ou JSON (`Subaction=CustomerUsers|Add`).
- Código: `Kernel/System/BWBStore.pm`, `Kernel/Modules/AdminBWBStore.pm`, `Kernel/Modules/AdminUser.pm`, `Kernel/Modules/AdminCustomerUser.pm`, `Kernel/Modules/AgentBWBAddCustomerEmail.pm`, `Kernel/System/BWBCustomerUserEmail.pm`, `PostMaster/Filter/BWBCustomerUserEmail.pm`, eventos `CustomerCompany/Event/BWB*.pm`, XML `BWBStores.xml` / `BWBCustomerUserEmail.xml` / `BWBAddCustomerEmail.xml`.
- Tabelas: `bwb_store`, `bwb_customer_owner`, `bwb_collaborator_customer`, `bwb_collaborator_store`, `bwb_agent_hierarchy`, `bwb_customer_user_email`.

## Filas e correio ZS

- `bwb-in` — suporte BWB / StoresAce.
- `zsangola-in` — remetentes ZS reconhecidos.
- `zs-postmaster` — remetentes ZS ainda não reconhecidos.
- Encaminhamentos autorizados: assunto `CODIGO_CLIENTE | email@cliente | Fwd: título`.
- Código: `Kernel/System/BWBZSIMAP.pm`, `Kernel/System/MailAccount/IMAPSZS.pm`, `Kernel/System/PostMaster/Filter/ZSAKnownCustomer.pm`, `Maint/PostMaster/ZSPendingArchive.pm`, XML `BWBZSIMAP.xml`.
- Conversão de cliente a partir de postmaster: `BWBConvertCustomer.pm`, `AgentBWBConvertCustomer.pm`.

## Folhas de trabalho

- O técnico inicia intervenção (tipo), guarda rascunho interno, termina com resultado, visibilidade no portal e opção de e-mail ao cliente.
- Tempo contabilizado automaticamente; artigo final em canal **Internal**.
- Código: `Kernel/System/BWBWorkSession.pm`, `Kernel/System/BWBWorkSheet.pm`, `Kernel/Modules/AgentBWBWorkSession.pm`, menu `TicketMenu/BWBWorkSession.pm`, JS `var/httpd/htdocs/js/Core.Agent.BWBWorkSessionDialog.js`.
- Tipos/resultados: `BWBOperationType.pm`, `BWBResultType.pm` + Admin + XML `BWBResults.xml`.
- Tabelas: `bwb_work_session`, `bwb_work_sheet`, `bwb_operation_type*`, `bwb_result_type*`.

### Destinatários do e-mail da folha

| Opção no fecho | Efeito do código BWB |
|---|---|
| **Enviar por e-mail = sim** | Um e-mail **só** para o utilizador cliente do ticket (`UserEmail` / `CustomerUserID`). Remetente = endereço do sistema da fila. Assunto `[Ticket#…] Folha de trabalho: …`. Não envia para agentes. |
| **Enviar por e-mail = não** | A folha **não** é enviada por este caminho. |

Independentemente da opção BWB, notificações OTOBO podem disparar (ex.: fecho visível na fila ZS → notificação ao **cliente** «Ticket encerrado»). O agente que executa a acção normalmente **não** recebe notificação de si próprio.

## Convites e palavra-passe

- Ligações de utilização única com expiração; sem registo público no portal.
- Código: `Kernel/System/BWBInvite.pm`, `Kernel/Modules/PublicBWBInvite.pm`, XML `BWBInvites.xml`.
- Tabela: `bwb_invite`.

## Notificações e e-mail

- Transporte / templates personalizados: `Ticket/Event/NotificationEvent/Transport/Email.pm`, templates `NotificationEvent/Email/*.tt`.
- Regras de notificação em produção (SysConfig/DB) incluem, entre outras, notificações ZS para o grupo de gestão e fecho com anexos ao cliente — consultar sempre a configuração viva no servidor antes de alterar.
- Fila de correio OTOBO: `Maint::Email::MailQueue`; entrega via Sendmail/Postfix no servidor.
- Branding nos e-mails: texto visível usa **Helpdesk**, não «OTOBO». Notificações na BD: «Abrir o ticket/marcação no Helpdesk» (`db/migrations/2026-08-16-email-otobo-to-helpdesk.sql`). Corpos de palavra-passe/conta: `ZZZBWBEmailBranding.pm`. As tags internas `<OTOBO_*>` mantêm-se (são placeholders do motor, não marca).

## Dashboard e interface

- Trabalho aberto: `Output/HTML/Dashboard/BWBOpenWork.pm`, configs em `otobo/Kernel/Config/Files/ZZZBWBDashboard*.pm`.
- Recursos estáticos BWB/ZS: `otobo/var/httpd/htdocs/`.
- Interface em português de Portugal, UTF-8, responsiva (alvos de toque ≥ 44 px; folha/Field ≥ 48 px).
- Tema visual Agent (PC e mobile standard): `BWBAgentTheme.css` (loader `999`, por último) — cinzentos/pretos; PC `#NavigationContainer` transparente; mobile: header/toolbar claros, hamburger preto, sidebar direita (`.SidebarColumn`) e menu esquerdo claros; logo `bwb-black-compact.svg`. Login excluído. Sem alteração de menus/fluxos.
- Portal cliente (`CustomerDashboard`): a tile «Tickets recentes» tem altura fixa no skin Default com `overflow:hidden`, o que cortava linhas sem scroll. Override `BWBCustomerDashboard.css` (loader `Loader::Module::CustomerDashboard###999-BWBCustomerDashboard`) aplica `overflow-y: auto` no contentor da lista — XML `BWBCustomerPortal.xml`.
- Portal cliente (`CustomerTicketZoom`):
  - Ordem das comunicações: mais recente em cima (núcleo OTOBO, `reverse` na lista).
  - «Responder» contextual na **última comunicação do helpdesk** (`agent` ou `system`); o botão do cabeçalho fica oculto quando existe esse artigo (`BWBReplyContextual`). JS `Core.Customer.BWBTicketZoom.js` **injecta** o botão no DOM após o `TicketZoom` nativo (não altera a estrutura HTML do `MIMEBase`, para não partir a TOC/`iframe`).
  - «Fechar ocorrência» só se o estado for `Pendente a aguardar cliente` (rótulo PT: «A aguardar resposta do cliente»), preferencialmente no artigo «Folha de trabalho»; acção `CustomerBWBTicketClose` (ChallengeToken + `TicketCustomerPermission`, estado → `encerrado com êxito`, artigo cliente de confirmação).
  - Templates Custom: `CustomerTicketZoom.tt` (atributos `data-bwb-*`); CSS `BWBCustomerTicketZoom.css`.

## Modo de campo (Field Mode)

- Terceiro modo de UI Agent para técnicos no terreno (colaboradores), sobre o responsive OTOBO — **não** é portal cliente.
- Activação por defeito: **apenas colaboradores** (`ResponsibleUserIDGet != UserID`) em dispositivo de campo; agentes responsáveis (ex.: Jorge) **nunca** entram em Field Mode (nem switch, nem Painel Field).
- Persistência: `localStorage.BWBFieldMode` + preferência `UserBWBFieldMode` (ignoradas se o utilizador não for colaborador).
- No Field **não há** switch Desktop; só **Field ↔ Mobile standard**.
- Menu reduzido (visível): Painel de Controlo, Calendário, Procurar, Ajuda — etiquetas fixas em português de Portugal; o menu Agent completo fica oculto.
- Painel (`AgentBWBFieldHome`): zona operacional (Folhas → tickets do técnico → folha; Tickets → Cliente → Utilizador → título/problema → prioridade → abrir folha) e dashboard informativo (tickets abertos + folhas abertas/pausadas).
- Criação de ticket no Field: selects tácteis (bottom-sheet ≥52px); utilizadores filtrados pelo cliente escolhido.
- Artigo inicial da criação Field: canal Email, `SenderType=customer`, `From` = nome/email do utilizador de cliente (mesmo princípio do encaminhamento `CODIGO | email | Fwd: título`); o colaborador fica só como proprietário/criador do sistema para abrir a folha.
- Lista de utilizadores de cliente: esgotar o cursor SQL antes de `CustomerUserAccessCheck` (e sessões abertas antes de `TicketAccessCheck`) — o mesmo handle `DB` não pode fazer `Prepare` aninhado durante `FetchrowArray`, senão só o primeiro utilizador aparece.
- Prioridade na criação rápida: select no formulário (prioridades válidas via `PriorityList`); por defeito a mais alta (maior `PriorityID`, nesta instalação `4 crítico`); `TicketCreate` usa `PriorityID` (evita nomes inglês vs PT).
- Visual Field: layout/táctil em `BWBFieldMode.css`; paleta partilhada com `BWBAgentTheme.css` (Agent PC); acções Cancelar/Pausa/Terminar da folha mantêm cores semânticas.
- Sessão Agent: idle `1200` s (20 min) e `SessionCheckRemoteIP=0` via `ZZZBWBSession.pm` (evita logout por mudança de IP móvel).
- **Um equipamento de cada vez (colaboradores):** `PreApplicationModule` `BWBAgentSessionGuard` — em cada pedido, elimina outras sessões `AgentInterface` do mesmo `UserID`. Responsáveis/admins não são afectados.
- Folha obrigatória em Field: após «Gravar e abrir folha» inicia sessão com tipo `Intervenção presencial` (ou primeiro disponível); links de tickets no painel vão para `AgentBWBWorkSession`; com folha **em execução** o guard `BWBFieldWorkGuard` força essa folha; em **pausa** pode usar o painel mas não abrir outra folha/ticket.
- Código: `Kernel/System/BWBFieldMode.pm`, `Kernel/Modules/AgentBWBFieldHome.pm`, `Kernel/Modules/BWBAgentSessionGuard.pm`, `Kernel/Modules/BWBFieldWorkGuard.pm`, `AgentBWBFieldHome.tt`, `js/Core.Agent.BWBFieldMode.js`, XML `BWBFieldMode.xml`, `ZZZBWBSession.pm`, `BWBAgentTheme.css`.
- Fila por defeito na criação rápida: `zsangola-in` se o responsável hierárquico for Amadeu (UserID 4); caso contrário `bwb-in`.

## Ao desenvolver funcionalidade nova ou alterar existente

1. Consultar sempre [KNOWLEDGE-BASE.md](KNOWLEDGE-BASE.md) e [REFERENCES.md](REFERENCES.md) antes de implementar (sem pedido explícito).
2. Actualizar **sempre** este ficheiro com o comportamento acordado no fim do trabalho.
3. Se criar tabelas, actualizar `db/current-schema.sql` e `db/migrations/`.
4. Se mudar isolamento BWB/ZS, documentar o teste de não-exposição cruzada.
5. Manter nomes `BWB*` e não renomear identificadores persistidos sem migração.
