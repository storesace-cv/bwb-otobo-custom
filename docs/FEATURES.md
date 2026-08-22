# Catálogo funcional BWB (desenvolvimento específico)

Inventário do comportamento **já implementado** nesta camada. Para o modelo genérico OTOBO, usar [REFERENCES.md](REFERENCES.md). Para o mapa de ficheiros, ver também [ARCHITECTURE.md](ARCHITECTURE.md).

Caminhos abaixo são relativos a `otobo/Custom/`, salvo indicação em contrário.

## Separação BWB / StoresAce ↔ ZS Angola

- Isolamento por filas, propriedade de cliente e módulos de permissão/pesquisa.
- Agentes ZS não podem ver clientes, tickets ou filas BWB.
- Código: `Kernel/System/BWBAccess.pm`, `Kernel/System/Ticket/Permission/BWBCustomerOwnerCheck.pm`, `Kernel/System/Ticket/TicketSearch.pm`, pesquisas de cliente (`AgentCustomerSearch.pm`, etc.).

## Clientes, lojas e colaboradores

- Empresa cliente com várias lojas; loja `S - Sede` criada por defeito. Em Admin → Lojas: **Latitude** / **Longitude** opcionais (`bwb_store`), usadas como fallback quando o GPS do fecho da folha falha.
- Utilizadores cliente associados a loja; clientes a agente responsável.
- **Loja no ticket:** a loja do utilizador de cliente e a loja do ticket são independentes. Na criação (PostMaster, Field, associar e-mail, converter remetente) copia-se a loja do utilizador reconhecido (`UserStoreID`, no mínimo `S | Sede`) para `bwb_ticket_store`. O agente pode **Alterar loja** no zoom (diálogo nativo, só lojas do Cliente do ticket, filtradas por `BWBAccess`) **sem** mudar a ficha do utilizador; alterar a ficha **não** reescreve tickets antigos. Rótulo `numero | nome`. Campo dinâmico de texto `BWBStore` é só espelho de apresentação (informação do ticket e dashboards); a tabela guarda o ID. **Não** há coluna Loja na visão geral de artigos. Relatório Tempo dispendido ainda deriva a loja da ficha do utilizador (fica para um passo seguinte; o `store_id` do ticket já está pronto). Código: `BWBTicketStore.pm`, `Ticket/Event/BWBTicketStore.pm` (`TicketCreate`/`TicketCustomerUpdate` **antes** das notificações, `6900`), `AgentBWBTicketStore.pm`, `TicketMenu/BWBTicketStore.pm`, JS `Core.Agent.BWBTicketStoreDialog.js`, XML `BWBTicketStore.xml`, `ZZZBWBTicketStore.pm` / `ZZZBWBDashboardClosed.pm`. Tags de e-mail `<OTOBO_BWB_STORE>` / `<OTOBO_BWB_STORE_STREET>` no transporte `Email.pm`. Migração: `db/migrations/2026-08-18-ticket-store.sql`.
- Colaboradores com acesso por cliente ou por loja.
- `AdminUser` (módulo «Agentes e colaboradores») está aberto a `admin` e `bwb_customer_managers`. Após criar utilizador, o redirect fica em `AdminUser` (edição do novo user) — **não** em `AdminUserGroup`/`AdminRoleUser` (só `admin`); caso contrário gestores como Amadeu viam «Sem permissões para utilizar este módulo!» embora o utilizador tivesse sido criado.
- **E-mails alternativos do utilizador de cliente:** até **dois** endereços adicionais (`bwb_customer_user_email`), geridos na ficha `AdminCustomerUser`. Servem **só** para reconhecer correio de entrada (novo ticket / follow-up) via `PostMaster::PreFilterModule###090-BWBCustomerUserEmail` + `BWBCustomerUserEmail.pm`. A **saída** de e-mails do sistema continua exclusivamente para o e-mail principal (`UserEmail`).
- **Verificar e-mail na ficha:** botão **Verificar** no HTML da ficha (`AdminCustomerUser.tt`), à direita de `UserEmail` e dos dois adicionais (mesma altura do campo, cinzento-escuro `#3a3a3c`, texto branco). Não grava nem envia mensagem ao cliente. Fluxo: `CheckItem` (sintaxe/MX) e, se passar, prova SMTP (`RCPT TO`, timeout 8 s, STARTTLS se o MX anunciar). O resultado tem **duas linhas em português**: código/termo técnico (ex. `550 5.1.1 — A conta de e-mail não existe.`) e explicação para leigos. Cache ~2 min; no máximo 10 verificações por agente e por minuto. Código: `BWBEmailVerify.pm`, `AdminCustomerUser` `Subaction=VerifyEmail`, JS `Core.Agent.Admin.BWBEmailVerify.js`, XML `BWBEmailVerify.xml`.
- **Associar e-mail no zoom do ticket:** menu `Associar e-mail a utilizador de cliente` (`TicketMenu/BWBAddCustomerEmail`) quando o remetente ainda não é reconhecido. Modal nativo `Core.UI.Dialog.ShowContentDialog` (JS `Core.Agent.BWBAddCustomerEmailDialog.js`): Cliente → Utilizadores desse cliente (filtrados por `BWBAccess`) → grava alias + `TicketCustomerSet` + recarrega o zoom. Selects **nativos** (sem Modernize); rótulos `Nome (email)`. A listagem de utilizadores materializa as linhas SQL **antes** de `CustomerUserAccessCheck` (evita anular o cursor DBI no mesmo `DBObject`). Endpoint `AgentBWBAddCustomerEmail` devolve fragmento HTML (`Dialog=1`) ou JSON (`Subaction=CustomerUsers|Add`).
- **Duração contabilizada na ficha do cliente:** em `AdminCustomerCompany` (Clientes), select **Duração contabilizada** com **Sim** / **Não**, defeito **Sim**. Valor em `bwb_customer_company_setting` (ausência de linha = Sim). Com **Não**, as folhas enviadas ao cliente e vistas no portal (HTML do iframe, «Tempo contabilizado» da ficha do ticket, impressão PDF e notificações OTOBO ao cliente) omitem o campo e o valor; o artigo interno e o zoom do agente mantêm a duração. Código: `BWBCustomerCompany.pm`, `CustomerTicketArticleContent.pm`, `CustomerTicketPrint.pm`, filtro `BWBHideAccountedDuration`, XML `BWBAccountedDuration.xml`.
- Código: `Kernel/System/BWBStore.pm`, `Kernel/System/BWBTicketStore.pm`, `Kernel/Modules/AdminBWBStore.pm`, `Kernel/Modules/AdminUser.pm`, `Kernel/Modules/AdminCustomerUser.pm`, `Kernel/Modules/AgentBWBAddCustomerEmail.pm`, `Kernel/Modules/AgentBWBTicketStore.pm`, `Kernel/System/BWBCustomerUserEmail.pm`, `Kernel/System/BWBEmailVerify.pm`, `Kernel/System/BWBCustomerCompany.pm`, `PostMaster/Filter/BWBCustomerUserEmail.pm`, eventos `CustomerCompany/Event/BWB*.pm` / `Ticket/Event/BWBTicketStore.pm`, XML `BWBStores.xml` / `BWBCustomerUserEmail.xml` / `BWBAddCustomerEmail.xml` / `BWBTicketStore.xml` / `BWBEmailVerify.xml` / `BWBAccountedDuration.xml`.
- Tabelas: `bwb_store`, `bwb_ticket_store`, `bwb_customer_owner`, `bwb_customer_company_setting`, `bwb_collaborator_customer`, `bwb_collaborator_store`, `bwb_agent_hierarchy`, `bwb_customer_user_email`.

## Filas e correio ZS

- `bwb-in` — suporte BWB / StoresAce.
- `zsangola-in` — remetentes ZS reconhecidos.
- `zs-postmaster` — remetentes ZS ainda não reconhecidos.
- Encaminhamentos autorizados: assunto `CODIGO_CLIENTE | email@cliente | Fwd: título`.
- **Devoluções (DSN):** o OTOBO 11 detecta bounces (`DetectBounceEmail` / Sisimai + `FollowUpCheck::BounceEmail`). Complemento BWB: anexos (`0410-BWBAttachments`, módulo nativo), fallback pelo destinatário (`0450-BWBBounce`), cabeçalhos para não reabrir nem mostrar ao cliente (`001-BWBBounce`), e e-mail ao proprietário, ao autor do envio **e ao agente responsável hierárquico** (`BWBBounceNotify`: Amadeu na ZS, Jorge na BWB). A folha, ao enviar ao cliente, grava `Message-ID` e `To` no artigo. Código: `BWBBounce.pm`, `PostMaster/Filter/BWBBounce.pm`, `PostMaster/FollowUpCheck/BWBBounce.pm`, `BWBBounceNotify.pm`, `Ticket/Event/BWBBounce.pm`, XML `BWBBounce.xml`.
- Código: `Kernel/System/BWBZSIMAP.pm`, `Kernel/System/MailAccount/IMAPSZS.pm`, `Kernel/System/PostMaster/Filter/ZSAKnownCustomer.pm`, `Maint/PostMaster/ZSPendingArchive.pm`, XML `BWBZSIMAP.xml`.
- Conversão de cliente a partir de postmaster: `BWBConvertCustomer.pm`, `AgentBWBConvertCustomer.pm`.

## Folhas de trabalho

- O técnico inicia intervenção (tipo), guarda rascunho interno, termina com resultado, visibilidade no portal e opção de e-mail ao cliente.
- Tempo contabilizado automaticamente; artigo final em canal **Internal**.
- Se a ficha do cliente tiver **Duração contabilizada = Não**, o e-mail da folha e o portal omitem esse campo; o agente continua a vê-lo no artigo.
- Código: `Kernel/System/BWBWorkSession.pm`, `Kernel/System/BWBWorkSheet.pm`, `Kernel/Modules/AgentBWBWorkSession.pm`, menu `TicketMenu/BWBWorkSession.pm`, JS `var/httpd/htdocs/js/Core.Agent.BWBWorkSessionDialog.js`.
- Tipos/resultados: `BWBOperationType.pm`, `BWBResultType.pm` + Admin + XML `BWBResults.xml`.
- Tabelas: `bwb_work_session`, `bwb_work_sheet`, `bwb_operation_type*`, `bwb_result_type*`.
- **Localização no Terminar trabalho:** o botão existente pede GPS (Geolocation API) antes do submit. Cadeia: GPS OK → `finish_location_source=gps`; GPS falha → coordenadas da loja do ticket (`bwb_ticket_store` → `bwb_store`) + nota → `source=store`; sem GPS e sem coords da loja → fecha na mesma + nota → `source=none`. Nunca bloqueia o fecho. No **AgentTicketZoom** (só helpdesk): **secção 1** = folha (iframe) com carimbo FECHADO limitado a essa área (`z-index` à frente; altura do iframe ajustada **uma vez**, sem loop `IframeAutoHeight`); **secção 2** = **Google Maps Embed** (iframe `place` + `maptype=satellite`, ~zoom 17; chave SysConfig `BWB::MapsEmbedAPIKey` injectada via `FilterElementPost::BWBWorkMapEmbedKey`). Link «Abrir no Google Maps». Sem Leaflet/OSM/Overpass. Uma secção por artigo. Coordenadas só na secção do mapa. Código: `BWBWorkSession.pm`, `AgentBWBWorkMap.pm`, `Core.Agent.BWBWorkMap.js`, XML `BWBWorkMap.xml`. Migração: `db/migrations/2026-08-22-store-work-location.sql`.
- **Agendamento na folha (intervenção presencial / «Pendente com Agendamento»):** em vez de campo «Retomar em», a folha abre o **diálogo nativo** de marcação OTOBO (`AgentAppointmentEdit` / `EditMask`) com o ticket pré-ligado (`PluginKey=0100-Ticket`). Botão «Agendar no calendário»; indicador «Marcação registada». Terminar trabalho exige marcação **futura** ligada ao ticket. Sync automático (`BWBAppointmentTicketSync`): ao criar/editar marcação futura, tickets **não encerrados** passam ao estado `Pendente até determinada data` (rótulo **Pendente com Agendamento**) com `Pending till` = início da marcação. Guarda `BWBStateRequiresAppointment` impede definir esse estado no zoom sem calendário. Rótulo via `pt_ZZZBWBStates.pm`. Código: `BWBAppointmentCheck.pm`, `Core.Agent.BWBWorkAppointment.js`, XML `BWBAppointmentSync.xml`, `BWBWorkAppointment.xml`.
- **Tempo dispendido:** menu Relatórios → **Tempo dispendido**. Lista as folhas da equipa (em execução, em pausa e terminadas) num intervalo De/Até (mês corrente por defeito), ordenadas por cliente e loja, com totais. Exclui clientes de teste: **1008** (perfil BWB) e **1009** (perfil ZS Angola). **Gerar PDF** produz relatório no estilo nativo (capa «Relatório HELPDESK», índice, Trabalhos, Totais por loja/cliente e **Resumo por cliente** com cabeçalho da empresa, tabela por loja/data, totais e paginação reiniciada por cliente), com cabeçalho BWB ou ZS Angola conforme `IsZSOperationUser`. Responsável vê a equipa; colaborador só as próprias. Isolamento BWB/ZS via `TicketAccessCheck`. Só conta trabalho com folha. Não usa o Stats Report nativo vazio `Tempo Dispendido`. Código: `BWBTimeSpent.pm`, `AgentBWBTimeSpent.pm`, `Output/PDF/BWBTimeSpent.pm`, XML `BWBTimeSpent.xml`, PNG `common/img/pdf-header-*.png`.

### Agente vs colaborador (Field)

| Perfil | Responder ao ticket (e-mail / nota OTOBO) | Folha de trabalho |
|---|---|---|
| **Agente responsável** (ex.: Jorge, Amadeu) | Sempre disponível (`AgentTicketCompose`, `AgentTicketNote`, …). **Não** é obrigatório abrir folha. | Opcional via menu «Iniciar trabalho» no zoom. O JS **não** injeta «INICIAR TRABALHO» nas acções de artigo. |
| **Colaborador em Field Mode** | Com folha **em execução**, o `BWBFieldWorkGuard` mantém o técnico na folha (fluxo de terreno). | Obrigatória no Field; atalho INICIAR/FECHAR nas acções de artigo. |

Um agente pode, à escolha: (1) responder pelo Compose/Nota/e-mail do OTOBO sem contabilizar tempo; (2) abrir folha para intervenção com tempo, resultado e envio controlado.

**Onde está «Responder»:** nas acções do **artigo** (e-mail do cliente), não no menu de topo. O OTOBO só mostra «Responder» / «Responder a todos» se a **fila** tiver pelo menos um modelo `Answer` em `queue_standard_template` (ex.: «Resposta em branco»). Filas `bwb-in` e `zs-postmaster` foram ligadas em `db/migrations/2026-08-17-queue-answer-templates.sql`. Novas filas: Admin → Modelos de resposta / Filas, ou repetir a migração.

**Modelo `mod-apple-01`:** modelo `Answer` escolhível no Compose **junto** da «Resposta em branco». Visual de cartão (marca Helpdesk → caixa **Resumo da ocorrência** → saudação numa linha «Olá …, Obrigado pelo seu contacto.» → texto editável → botão «Abrir no portal» cinzento claro → rodapé). Espaçamento no corpo via parágrafos `&nbsp;` (o CKEditor colapsa `margin` em `<p>`). Espaço igual Helpdesk↔resumo (padding); 1 linha em branco resumo↔saudação e saudação↔«Escreva…»; 5 linhas antes do botão. A saudação **dentro** do cartão; o filtro `BWBComposeAppleTemplate` / JS retiram a saudação da fila acima do cartão. Tags HTML **encoded**. Fonte: `BWBEmail/mod-apple-01.html`. Migrações: `2026-08-19-…`, `2026-08-21-mod-apple-01-resumo-acima.sql`, `2026-08-21-mod-apple-01-espacamento-botao.sql`. XML: `BWBComposeApple.xml`.

### Destinatários do e-mail da folha

| Opção no fecho | Efeito do código BWB |
|---|---|
| **Enviar por e-mail = sim** | Um e-mail **só** para o utilizador cliente do ticket (`UserEmail` / `CustomerUserID`). Remetente = endereço do sistema da fila. Assunto `[Ticket#…] Folha de trabalho: …`. Não envia para agentes. O artigo da folha fica com `To` e `Message-ID` do envio (para a DSN encontrar o ticket). |
| **Enviar por e-mail = não** | A folha **não** é enviada por este caminho. |

Independentemente da opção BWB, notificações OTOBO podem disparar (ex.: fecho visível na fila ZS → notificação ao **cliente** «Ticket encerrado»). O agente que executa a acção normalmente **não** recebe notificação de si próprio.

### Responsável ZS Angola (Amadeu) e folhas da equipa

Âmbito **só ZS Angola** (UserID 4 e colaboradores com `responsible_user_id=4`). Não altera o fluxo BWB/Jorge. Manual de utilização para o responsável e a equipa: [MANUAL-ZS-ANGOLA.md](MANUAL-ZS-ANGOLA.md).

- **Dashboard «Trabalho aberto»:** a listagem drena o cursor SQL **antes** de `TicketAccessCheck`/`TicketGet` (o mesmo defeito que escondia utilizadores no diálogo de e-mail). O responsável vê as folhas próprias **e** as dos colaboradores da hierarquia.
- **Vista só leitura:** se o responsável abre a folha de um colaborador ZS (`AgentBWBWorkSession`), vê tipo, técnico, notas e pausa **sem** poder iniciar/pausar/terminar/cancelar. O colaborador continua a editar no terreno. Menu do zoom: «Ver folha de trabalho».
- **Ceder folha ao transferir o ticket:** `Ticket::EventModulePost###9800-BWBZSSupervisor` em `TicketOwnerUpdate`. Se a sessão aberta ainda está no responsável ZS e o novo proprietário é colaborador ZS **sem** outra sessão ativa, a folha passa para esse colaborador. Nunca se rouba a folha de um técnico que está a trabalhar. Dados já existentes: `db/migrations/2026-08-17-zs-supervisor-session-handoff.sql`.
- **E-mail ao responsável:** quando um **colaborador** ZS cria um ticket ou inicia uma folha, envia-se **um** e-mail HTML ao Amadeu (`UserEmail`), remetente `Helpdesk - ZS Angola <assistencia@zsa-softwares.com>`. Criar ticket + iniciar folha no mesmo pedido (Field) gera um único e-mail. O responsável **não** é notificado das próprias acções; o cliente **não** recebe este aviso.
- Código: `BWBAccess.pm` (`ZSResponsibleUserID` / `IsZSCollaborator` / `IsZSResponsible`), `BWBZSSupervisorNotify.pm`, `Ticket/Event/BWBZSSupervisor.pm`, XML `BWBZSSupervisor.xml`.

## Convites e palavra-passe

- Ligações de utilização única com expiração; sem registo público no portal.
- Código: `Kernel/System/BWBInvite.pm`, `Kernel/Modules/PublicBWBInvite.pm`, XML `BWBInvites.xml`.
- Tabela: `bwb_invite`.

## Notificações e e-mail

- Transporte / templates personalizados: `Ticket/Event/NotificationEvent/Transport/Email.pm`, templates `NotificationEvent/Email/*.tt`.
- Regras de notificação em produção (SysConfig/DB) incluem, entre outras, notificações ZS para o grupo de gestão e fecho com anexos ao cliente — consultar sempre a configuração viva no servidor antes de alterar.
- Extra ZS (código BWB): `BWBZSSupervisorNotify` envia e-mail **só** ao responsável ZS quando um colaborador cria ticket ou inicia folha. Não substitui as notificações OTOBO e não vai para o cliente.
- Notificação de ticket novo (agentes): após o cliente, o corpo inclui a loja do **ticket** (`<OTOBO_BWB_STORE>` = `numero | nome`, `<OTOBO_BWB_STORE_STREET>` = morada, com quebras de linha da ficha). Sem loja (legado), essas linhas omitem-se. A loja da ficha do utilizador não entra neste e-mail. Os marcadores BWB são substituídos no transporte Custom (`Email.pm`) **depois** do `TemplateGenerator` nativo, nas formas `<…>`, `&lt;…&gt;` e `&amp;lt;…&amp;gt;`.
- Fila de correio OTOBO: `Maint::Email::MailQueue`; entrega via Sendmail/Postfix no servidor.
- Branding nos e-mails: texto visível usa **Helpdesk**, não «OTOBO». Notificações na BD: «Abrir o ticket/marcação no Helpdesk» (`db/migrations/2026-08-16-email-otobo-to-helpdesk.sql`). Corpos de palavra-passe/conta: `ZZZBWBEmailBranding.pm`. As tags internas `<OTOBO_*>` mantêm-se (são placeholders do motor, não marca). O modelo `mod-apple-01` **não** substitui este envelope: é só o corpo escolhido em «Responder».
- Assinatura da fila `bwb-in` (tabela `signature` id 2): título **Suporte Técnico** (não o nome do consultor); contactos helpdesk@bwb.pt / helpdesk@storesace.cv. Migração: `db/migrations/2026-08-21-bwb-signature-suporte-tecnico.sql`.
- Calendário de marcações Appointment **BWB** (grupo `BWB`, cor `#0071E3`), além do **ZS Angola**. Agentes BWB com permissão no grupo `BWB` passam a vê-lo em Calendário. Migração: `db/migrations/2026-08-21-calendar-bwb.sql`. (Os calendários de **horário de serviço** SLA `TimeZone::Calendar1/2` em `ZZZBWBTimeCalendars.pm` são outro mecanismo.) Estado «Pendente até determinada data» mostra-se como **Pendente com Agendamento** (`pt_ZZZBWBStates.pm`).
- **Contexto Helpdesk para Claude Mail MCP:** nos envios (Compose, folha, intake, notificações) o wrapper `Custom/Kernel/System/Email.pm` injecta headers `X-BWB-*` (ticket, fila, cliente, utilizador, estado, prioridade, loja, source/direction) via `BWBEmailContext`. API read-only `PublicBWBTicketContext` (Bearer + allowlist IP) para lookup por `TicketNumber`. O conector `mcp-mail.bwb.pt` enriquece `get_message` e expõe a tool `helpdesk_ticket_context`. Segredos só no servidor (`ZZZBWBTicketContext.pm` / `.env` do MCP). Sem HTML oculto; sem IMAP nas caixas de intake.

## Dashboard e interface

- Trabalho aberto: `Output/HTML/Dashboard/BWBOpenWork.pm`, configs em `otobo/Kernel/Config/Files/ZZZBWBDashboard*.pm`. A consulta materializa as linhas SQL **antes** de `TicketAccessCheck` (senão o dashboard só mostrava a primeira folha). Coluna **Loja** a seguir a Cliente (`bwb_ticket_store`). Widgets `TicketGeneric` (novos, abertos, fechados recentes): Cliente + Loja (DF `BWBStore`). Se o agente já tiver colunas personalizadas no widget, pode precisar de activar **Loja** nas definições do próprio widget.
- **Agendamentos pendentes:** widget `BWBScheduledWork` (`0126-BWBScheduledWork`) lista marcações futuras ligadas a tickets abertos/pendentes (via `link_relation` Appointment→Ticket), com data/hora, ticket, cliente, loja e título. Mesma visibilidade hierárquica que «Folhas de trabalho abertas» (`BWBAccess`).
- Zoom do ticket: campo **Loja** na informação do ticket (DF `BWBStore`, só leitura). Menu **Alterar loja** (diálogo nativo). **Não** na tabela de artigos.
- Recursos estáticos BWB/ZS: `otobo/var/httpd/htdocs/`.
- Interface em português de Portugal, UTF-8, responsiva (alvos de toque ≥ 44 px; folha/Field ≥ 48 px).
- Tema visual Agent (PC e mobile standard): `BWBAgentTheme.css` (loader `999`, por último) — cinzentos/pretos; PC `#NavigationContainer` transparente; mobile: header/toolbar claros, hamburger preto, sidebar direita (`.SidebarColumn`) e menu esquerdo claros; logo `bwb-black-compact.svg`. Login excluído. Sem alteração de menus/fluxos. Com um ticket aberto, o dropdown do menu principal (`Clientes`, `Tickets`, …) fica à frente da barra de acções (`z-index` 7000): essa barra foi elevada a 5000–6000 para os menus do ticket; o núcleo só aplica `NavContainerZIndex` (5500) no clique, não no hover.
- Portal cliente (`CustomerDashboard`): a tile «Tickets recentes» tem altura fixa no skin Default com `overflow:hidden`, o que cortava linhas sem scroll. Override `BWBCustomerDashboard.css` (loader `Loader::Module::CustomerDashboard###999-BWBCustomerDashboard`) aplica `overflow-y: auto` no contentor da lista — XML `BWBCustomerPortal.xml`.
- Portal cliente (`CustomerTicketZoom`):
  - Ordem das comunicações: mais recente em cima (núcleo OTOBO, `reverse` na lista).
  - «Responder» contextual na **última comunicação do helpdesk** (`agent` ou `system`); o botão do cabeçalho fica oculto quando existe esse artigo (`BWBReplyContextual`). JS `Core.Customer.BWBTicketZoom.js` **injecta** o botão no DOM após o `TicketZoom` nativo (não altera a estrutura HTML do `MIMEBase`, para não partir a TOC/`iframe`).
  - «Fechar ocorrência» só se o estado for `Pendente a aguardar cliente` (rótulo PT: «A aguardar resposta do cliente»), preferencialmente no artigo «Folha de trabalho»; acção `CustomerBWBTicketClose` (ChallengeToken + `TicketCustomerPermission`, estado → `encerrado com êxito`, artigo cliente de confirmação).
  - Templates Custom: `CustomerTicketZoom.tt` (atributos `data-bwb-*`); CSS `BWBCustomerTicketZoom.css`.

## Registo telefónico / e-mail em nome do cliente

- **Novo Registo Telefónico** (`AgentTicketPhone`) e **Novo Registo por E-mail** (`AgentTicketEmail`) usam o mesmo contrato do Field: **Cliente → Utilizador de cliente → pedido**, com artigo inicial `SenderType=customer` em nome do utilizador escolhido. O operador fica em `create_by` (auditoria); o ticket pertence ao cliente.
- Formulário desktop: layout `FormScreen` OTOBO; Cliente e Utilizador em selects **nativos**, mesma cascata do Field (lista completa no HTML, filtrada ao escolher o cliente). Fila só de leitura (`bwb-in` / `zsangola-in`). Campos limitados à coluna `.Field` (50%). Botões **Criar** à esquerda e **Cancelar** à direita dessa coluna.
- Serviço partilhado: `Kernel/System/BWBTicketIntake.pm` (também usado pelo Field via origem `field`). Loja copiada na criação (`EnsureFromCustomerUser`).
- **Dois e-mails distintos** (modelo próprio; não reutiliza auto-reply nem notificação genérica de ticket novo):
  - **Cliente** (`UserEmail`): assunto `Nova ocorrência registada em seu nome | Ticket#…`; corpo com cliente, utilizador, quem registou, origem (telefone ou e-mail), título e pedido; artigo `system` visível no portal.
  - **Agente responsável** hierárquico (`ResponsibleUserIDGet`, excepto se for quem registou): assunto `Nova ocorrência registada | Ticket#…`; mesmo bloco de identidades + ligação ao zoom. **Não** substitui o aviso ZS «Novo ticket da equipa» no Field (Field não envia declaração ao cliente).
- Origem no corpo: **Via telefone** ou **Via e-mail**.
- Field Mode **não** envia a declaração ao cliente (técnico no terreno); mantém aviso ao responsável ZS quando um colaborador cria ticket.
- Código: `BWBTicketIntake.pm`, `BWBTicketIntakeAgent.pm`, overrides `AgentTicketPhone.pm` / `AgentTicketEmail.pm`, template `AgentBWBTicketIntake.tt`, JS `Core.Agent.BWBTicketIntake.js`, CSS `BWBTicketIntake.css`, XML `BWBTicketIntake.xml`; evento `BWBZSSupervisor` ignora `TicketCreate` quando o intake desktop envia o alarme ao responsável.

## Modo de campo (Field Mode)

- Terceiro modo de UI Agent para técnicos no terreno (colaboradores), sobre o responsive OTOBO — **não** é portal cliente.
- Activação por defeito: **apenas colaboradores** (`ResponsibleUserIDGet != UserID`) em dispositivo de campo; agentes responsáveis (ex.: Jorge) **nunca** entram em Field Mode (nem switch, nem Painel Field).
- Persistência: `localStorage.BWBFieldMode` + preferência `UserBWBFieldMode` (ignoradas se o utilizador não for colaborador).
- No Field **não há** switch Desktop; só **Field ↔ Mobile standard**.
- Menu reduzido (visível): Painel de Controlo, Calendário, Procurar, Ajuda — etiquetas fixas em português de Portugal; o menu Agent completo fica oculto.
- Painel (`AgentBWBFieldHome`): zona operacional (Folhas → tickets do técnico → folha; Tickets → Cliente → Utilizador → título/problema → prioridade → abrir folha) e dashboard informativo (tickets abertos + folhas abertas/pausadas, com cliente e loja do ticket).
- Criação de ticket no Field: selects tácteis (bottom-sheet ≥52px); utilizadores filtrados pelo cliente escolhido; lógica de criação via `BWBTicketIntake` (origem `field`, sem e-mail de declaração).
- Artigo inicial da criação Field: canal Email, `SenderType=customer`, `From` = nome/email do utilizador de cliente (mesmo princípio do encaminhamento `CODIGO | email | Fwd: título`); o colaborador fica só como proprietário/criador do sistema para abrir a folha.
- Lista de utilizadores de cliente: esgotar o cursor SQL antes de `CustomerUserAccessCheck` (e sessões abertas antes de `TicketAccessCheck`) — o mesmo handle `DB` não pode fazer `Prepare` aninhado durante `FetchrowArray`, senão só o primeiro utilizador aparece.
- Prioridade na criação rápida: select no formulário (prioridades válidas via `PriorityList`); por defeito a mais alta (maior `PriorityID`, nesta instalação `4 crítico`); `TicketCreate` usa `PriorityID` (evita nomes inglês vs PT).
- Visual Field: layout/táctil em `BWBFieldMode.css`; paleta partilhada com `BWBAgentTheme.css` (Agent PC); acções Cancelar/Pausa/Terminar da folha mantêm cores semânticas.
- Sessão Agent: idle `1200` s (20 min) e `SessionCheckRemoteIP=0` via `ZZZBWBSession.pm` (evita logout por mudança de IP móvel).
- **Um equipamento de cada vez (colaboradores):** `PreApplicationModule` `BWBAgentSessionGuard` — em cada pedido, elimina outras sessões `AgentInterface` do mesmo `UserID`. Responsáveis/admins não são afectados.
- Folha obrigatória em Field: após «Gravar e abrir folha» inicia sessão com tipo `Intervenção presencial` (ou primeiro disponível); links de tickets no painel vão para `AgentBWBWorkSession`; com folha **em execução** o guard `BWBFieldWorkGuard` força essa folha; em **pausa** pode usar o painel mas não abrir outra folha/ticket.
- Após «Gravar e abrir folha» o ecrã **Folha de trabalho** tem de ficar estável. O JS de Field **não** chama `location.replace` se `Action` já for `AgentBWBWorkSession` da folha activa: `TicketID` lê-se de `Core.Config` (publicado pelo módulo), do URL (`;` ou `&`) ou do formulário. Comparar só `Core.Config.Get('TicketID')` falhava neste ecrã (o Zoom publica-o; a folha não) e o telemóvel recarregava a mesma URL sem parar.
- Código: `Kernel/System/BWBFieldMode.pm`, `Kernel/Modules/AgentBWBFieldHome.pm`, `Kernel/Modules/BWBAgentSessionGuard.pm`, `Kernel/Modules/BWBFieldWorkGuard.pm`, `AgentBWBFieldHome.tt`, `js/Core.Agent.BWBFieldMode.js`, XML `BWBFieldMode.xml`, `ZZZBWBSession.pm`, `BWBAgentTheme.css`.
- Fila por defeito na criação rápida: `zsangola-in` se o responsável hierárquico for Amadeu (UserID 4); caso contrário `bwb-in`.

## Ao desenvolver funcionalidade nova ou alterar existente

1. Consultar sempre [KNOWLEDGE-BASE.md](KNOWLEDGE-BASE.md) e [REFERENCES.md](REFERENCES.md) antes de implementar (sem pedido explícito).
2. Actualizar **sempre** este ficheiro com o comportamento acordado no fim do trabalho.
3. Se criar tabelas, actualizar `db/current-schema.sql` e `db/migrations/`.
4. Se mudar isolamento BWB/ZS, documentar o teste de não-exposição cruzada.
5. Manter nomes `BWB*` e não renomear identificadores persistidos sem migração.
