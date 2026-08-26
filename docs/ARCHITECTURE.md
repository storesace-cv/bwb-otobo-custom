# Arquitetura funcional

Continuidade e manuais oficiais: [KNOWLEDGE-BASE.md](KNOWLEDGE-BASE.md) · [REFERENCES.md](REFERENCES.md) · [FEATURES.md](FEATURES.md)

## Produção

| Campo | Valor |
|---|---|
| **Fornecedor** | **[Euronodes](https://euronodes.com/)** (VPS, infraestrutura europeia — AS199053) |
| **IP** | `178.159.34.132` |
| **Hostname** | `helpdesk` |
| **URL pública** | `https://helpdesk.storesace.cv/otobo/` |
| **SSH (alias local)** | `bwb-otobo-prod` — ver [`config/ssh-config.example`](../config/ssh-config.example) |
| **Instalação OTOBO** | `/opt/otobo` |
| **Código personalizado** | `/opt/otobo/Custom` |

O acesso ao servidor é feito através da chave privada local do administrador. O nome do ficheiro da chave no posto de trabalho (ex.: `~/.ssh/digitalocean`) é **convencão histórica local** — **não** indica o fornecedor de hosting. A chave **não** faz parte deste repositório.

**Não confundir:** o helpdesk **não** está na DigitalOcean. Backups para pCloud ou S3 Euronodes partem deste VPS; com S3 na mesma conta Euronodes existe acesso interno de alta velocidade (ver [OPERATIONS.md](OPERATIONS.md)).

## Domínios funcionais personalizados

### Clientes, lojas e equipas

- Uma empresa cliente pode ter várias lojas; a loja `S - Sede` é criada por defeito.
- Os utilizadores de cliente pertencem a uma loja.
- Cada ticket tem a **sua** loja (`bwb_ticket_store`), copiada na criação da ficha do utilizador; o agente pode corrigi-la sem alterar a ficha.
- Os clientes pertencem a um agente responsável.
- Colaboradores podem ter acesso por cliente ou por loja.
- A separação BWB/ZS Angola é aplicada por filas, propriedade de cliente e permissões personalizadas.

### Filas e correio

- `bwb-in`: suporte BWB / StoresAce.
- `zsangola-in`: remetentes ZS Angola reconhecidos na base de dados.
- `zs-postmaster`: remetentes ZS Angola ainda não reconhecidos.
- Encaminhamentos autorizados usam o assunto no formato `CODIGO_CLIENTE | email@cliente | Fwd: título`.
- Devoluções (DSN) são follow-up do ticket original (não um ticket novo em `zs-postmaster`). O estado encerrado mantém-se; o cliente não vê a DSN; o agente que enviou é avisado.

### Folhas de trabalho

- O técnico inicia uma intervenção escolhendo um tipo de intervenção.
- Notas e anexos são guardados como rascunho interno durante o trabalho.
- Ao terminar, escolhe resultado, visibilidade no portal e, opcionalmente, envio por e-mail ao cliente.
- O tempo é calculado automaticamente.
- A ficha do cliente (`AdminCustomerCompany`) controla se a **Duração contabilizada** é visível nas folhas enviadas ao cliente e no portal.
- **Agentes responsáveis:** folha opcional; podem responder com Compose/Nota/e-mail OTOBO sem abrir folha.
- **Colaboradores em Field Mode:** folha obrigatória enquanto a sessão está em execução (`BWBFieldWorkGuard`).
- **Responsável ZS Angola:** vê as folhas da equipa no dashboard e em só leitura; ao passar o ticket a um colaborador ZS, uma folha órfã do responsável é cedida; colaboradores notificam o responsável por e-mail (não o cliente).

### Modo de campo (Field Mode)

- Colaboradores em telemóvel/tablet entram por defeito num shell Agent reduzido (cinzentos/pretos), focado em folhas de obra.
- Troca apenas Field ↔ Mobile standard (sem Desktop no Field).
- Painel de Controlo: zona operacional (iniciar folhas / criar ticket+folha) e zona informativa (tickets e folhas abertas).

### Convites e palavra-passe

- Convites e reposições usam ligações de utilização única e expiração.
- Não há criação pública de contas no portal.

## Componentes principais

| Área | Código relevante |
|---|---|
| Lojas | `Kernel/System/BWBStore.pm`, `Kernel/Modules/AdminBWBStore.pm` |
| Loja no ticket | `BWBTicketStore.pm`, `Ticket/Event/BWBTicketStore.pm`, `AgentBWBTicketStore.pm`, XML `BWBTicketStore.xml` |
| Convites | `Kernel/System/BWBInvite.pm`, `Kernel/Modules/PublicBWBInvite.pm` |
| Folhas de trabalho | `Kernel/System/BWBWorkSession.pm`, `Kernel/System/BWBWorkSheet.pm`, `Kernel/Modules/AgentBWBWorkSession.pm` |
| Duração contabilizada (ficha cliente) | `BWBCustomerCompany.pm`, `AdminCustomerCompany`, filtro `BWBHideAccountedDuration`, XML `BWBAccountedDuration.xml` |
| Tempo dispendido | `BWBTimeSpent.pm`, `AgentBWBTimeSpent.pm`, `Output/PDF/BWBTimeSpent.pm`, XML `BWBTimeSpent.xml` |
| Supervisor ZS Angola | `BWBZSSupervisorNotify.pm`, `Ticket/Event/BWBZSSupervisor.pm`, XML `BWBZSSupervisor.xml` |
| Portal cliente (zoom) | `CustomerBWBTicketClose.pm`, templates `CustomerTicketZoom*`, `js/Core.Customer.BWBTicketZoom.js` |
| E-mails alternativos cliente | `BWBCustomerUserEmail.pm`, `AgentBWBAddCustomerEmail.pm`, `PostMaster/Filter/BWBCustomerUserEmail.pm` |
| Verificar e-mail (ficha cliente) | `BWBEmailVerify.pm`, `AdminCustomerUser` `VerifyEmail`, JS `Core.Agent.Admin.BWBEmailVerify.js`, XML `BWBEmailVerify.xml` |
| Modo de campo | `Kernel/System/BWBFieldMode.pm`, `Kernel/Modules/AgentBWBFieldHome.pm`, `js/Core.Agent.BWBFieldMode.js` |
| Tipos de operação/resultados | `BWBOperationType.pm`, `BWBResultType.pm` e respetivos módulos Admin |
| Conversão postmaster | `BWBConvertCustomer.pm`, `AgentBWBConvertCustomer.pm` |
| Regras ZS IMAP | `BWBZSIMAP.pm`, `MailAccount/IMAPSZS.pm`, `PostMaster/Filter/ZSAKnownCustomer.pm` |
| Isolamento de acessos | `BWBAccess.pm`, `Ticket/Permission/BWBCustomerOwnerCheck.pm` |
| Devoluções DSN | `BWBBounce.pm`, `PostMaster/Filter/BWBBounce.pm`, `PostMaster/FollowUpCheck/BWBBounce.pm`, `BWBBounceNotify.pm` |
| E-mail | `Ticket/Event/NotificationEvent/Transport/Email.pm`, templates NotificationEvent |
| Modelo de resposta `mod-apple-01` | HTML `Output/HTML/Templates/Standard/BWBEmail/mod-apple-01.html` + `standard_template` / `queue_standard_template`; filtro Compose `FilterElementPost/BWBComposeAppleTemplate.pm` + JS `Core.Agent.BWBComposeApple.js` (não duplicar a saudação da fila) |
| Contexto email → Claude MCP | `BWBEmailContext.pm`, wrapper `Email.pm`, `PublicBWBTicketContext.pm`, XML `BWBTicketContext.xml` |
| Assistente Ajuda / RAG | `BWBAssist.pm`, `AgentBWBAssist.pm`, `PublicBWBAssistIndex.pm`, filtro `BWBAssistTicketSuggest.pm`; serviço `services/bwb-assist` no VPS `178.159.34.165` |
| Dashboard | `Output/HTML/Dashboard/BWBOpenWork.pm`, `ZZZBWBDashboard*.pm`, ordem: `AgentDashboard.pm` + `BWBDashboard.pm` |

### Assistente IA (132 ↔ 165)

- **OTOBO `178.159.34.132`:** UI agente, `FAQSearch`, gate `BWBAccess`, API índice RO.
- **IA `178.159.34.165`:** `bwb-assist` (BM25 + síntese; Ollama opcional quando houver RAM). Rede: OTOBO → `165:18101` (nginx allowlist) → `127.0.0.1:18100`.
