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
- Código: `Kernel/System/BWBStore.pm`, `Kernel/Modules/AdminBWBStore.pm`, eventos `CustomerCompany/Event/BWB*.pm`, XML `Config/Files/XML/BWBStores.xml`.
- Tabelas: `bwb_store`, `bwb_customer_owner`, `bwb_collaborator_customer`, `bwb_collaborator_store`, `bwb_agent_hierarchy`.

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

## Dashboard e interface

- Trabalho aberto: `Output/HTML/Dashboard/BWBOpenWork.pm`, configs em `otobo/Kernel/Config/Files/ZZZBWBDashboard*.pm`.
- Recursos estáticos BWB/ZS: `otobo/var/httpd/htdocs/`.
- Interface em português de Portugal, UTF-8, responsiva (alvos de toque ≥ 44 px).

## Ao desenvolver funcionalidade nova ou alterar existente

1. Consultar sempre [KNOWLEDGE-BASE.md](KNOWLEDGE-BASE.md) e [REFERENCES.md](REFERENCES.md) antes de implementar (sem pedido explícito).
2. Actualizar **sempre** este ficheiro com o comportamento acordado no fim do trabalho.
3. Se criar tabelas, actualizar `db/current-schema.sql` e `db/migrations/`.
4. Se mudar isolamento BWB/ZS, documentar o teste de não-exposição cruzada.
5. Manter nomes `BWB*` e não renomear identificadores persistidos sem migração.
