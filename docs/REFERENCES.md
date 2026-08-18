# Referências oficiais OTOBO (acesso directo)

Produção actual: **OTOBO 11.0.17**. Toda a documentação oficial abaixo aponta para a série **11.0**, alinhada com essa instalação.

Os manuais oficiais estão em inglês. A interface desta instalação está em português de Portugal; a lógica de produto descrita nos manuais aplica-se na mesma.

Portal geral: [https://doc.otobo.org/](https://doc.otobo.org/)

## Administração (como o OTOBO se configura e opera)

- Manual de administração 11.0: [https://doc.otobo.org/manual/admin/11.0/en/content/index.html](https://doc.otobo.org/manual/admin/11.0/en/content/index.html)
- Área de administração: [https://doc.otobo.org/manual/admin/11.0/en/content/administration-area.html](https://doc.otobo.org/manual/admin/11.0/en/content/administration-area.html)
- Agentes: [https://doc.otobo.org/manual/admin/11.0/en/content/administration-area/users-groups-roles/agents.html](https://doc.otobo.org/manual/admin/11.0/en/content/administration-area/users-groups-roles/agents.html)
- Utilizadores cliente: [https://doc.otobo.org/manual/admin/11.0/en/content/administration-area/users-groups-roles/customer-users.html](https://doc.otobo.org/manual/admin/11.0/en/content/administration-area/users-groups-roles/customer-users.html)
- Filas: [https://doc.otobo.org/manual/admin/11.0/en/content/administration-area/ticket-settings/queues.html](https://doc.otobo.org/manual/admin/11.0/en/content/administration-area/ticket-settings/queues.html)
- Modelos de resposta (templates Answer/Create/…): [https://doc.otobo.org/manual/admin/11.0/en/content/administration-area/ticket-settings/templates.html](https://doc.otobo.org/manual/admin/11.0/en/content/administration-area/ticket-settings/templates.html)
- Contas de correio: [https://doc.otobo.org/manual/admin/11.0/en/content/administration-area/communication-notifications/email-accounts.html](https://doc.otobo.org/manual/admin/11.0/en/content/administration-area/communication-notifications/email-accounts.html)
- Notificações de ticket: [https://doc.otobo.org/manual/admin/11.0/en/content/administration-area/communication-notifications/ticket-notifications.html](https://doc.otobo.org/manual/admin/11.0/en/content/administration-area/communication-notifications/ticket-notifications.html)
- Configuração do sistema: [https://doc.otobo.org/manual/admin/11.0/en/content/administration-area/administration/system-configuration.html](https://doc.otobo.org/manual/admin/11.0/en/content/administration-area/administration/system-configuration.html)

Usar estes capítulos sempre que a tarefa mexa em filas, grupos, papéis, notificações, correio, ACL ou SysConfig.

## Utilização (comportamento esperado por agentes e clientes)

- Manual de utilizador 11.0: [https://doc.otobo.org/manual/user/11.0/en/content/index.html](https://doc.otobo.org/manual/user/11.0/en/content/index.html)
- Utilização BWB/ZS (responsável e equipa no terreno): [MANUAL-ZS-ANGOLA.md](MANUAL-ZS-ANGOLA.md)

Consultar o manual OTOBO para fluxos nativos de ticket, artigos, portal do cliente e permissões de interface — e contrastar com as personalizações BWB em [FEATURES.md](FEATURES.md).

## Desenvolvimento (programação sobre OTOBO)

- Developer Guide 11.0: [https://doc.otobo.org/manual/dev/11.0/en/content/index.html](https://doc.otobo.org/manual/dev/11.0/en/content/index.html)
- Arquitectura: [https://doc.otobo.org/manual/dev/11.0/en/content/get-started/architecture.html](https://doc.otobo.org/manual/dev/11.0/en/content/get-started/architecture.html)
- Como estender o OTOBO: [https://doc.otobo.org/manual/dev/11.0/en/content/how-to-extend-otobo.html](https://doc.otobo.org/manual/dev/11.0/en/content/how-to-extend-otobo.html)
- Escrever um módulo de frontend: [https://doc.otobo.org/manual/dev/11.0/en/content/how-to-extend-otobo/writing-otobo-application.html](https://doc.otobo.org/manual/dev/11.0/en/content/how-to-extend-otobo/writing-otobo-application.html)
- Camadas de módulos: [https://doc.otobo.org/manual/dev/11.0/en/content/how-to-extend-otobo/otobo-module-layers.html](https://doc.otobo.org/manual/dev/11.0/en/content/how-to-extend-otobo/otobo-module-layers.html)

Nesta instalação, o código personalizado vive em `/opt/otobo/Custom` (espelhado neste repo em `otobo/Custom/`), não no núcleo. O mecanismo de override `Custom/` e o Object Manager do OTOBO 11.0 são a base de todas as extensões BWB.

### Pontos de extensão usados com frequência neste projecto

| Necessidade | Procurar no Developer Guide / Admin | Espelho BWB típico |
|---|---|---|
| Novo ecrã agente/admin | Front End Module + XML de registo | `Kernel/Modules/Agent*.pm`, `Admin*.pm` + XML em `Config/Files/XML/` |
| Lógica de negócio | Core modules (`Kernel/System`) | `Kernel/System/BWB*.pm` |
| Templates | Template Toolkit | `Output/HTML/Templates/Standard/*.tt` |
| Eventos / notificações | Ticket events, NotificationEvent | `Ticket/Event/...`, templates `NotificationEvent/Email/` |
| PostMaster / IMAP | Mail accounts, filters | `MailAccount/IMAPSZS.pm`, `PostMaster/Filter/` |
| Permissões de ticket | Permission modules | `Ticket/Permission/BWBCustomerOwnerCheck.pm` |
| Console / manutenção | Console commands | `System/Console/Command/...` |

## Instalação e actualização (contexto de servidor)

- Installation Guide 11.0: [https://doc.otobo.org/manual/installation/11.0/en/content/index.html](https://doc.otobo.org/manual/installation/11.0/en/content/index.html)

Útil para daemon, permissões de ficheiros, actualizações e requisitos. A receita concreta desta produção está em [OPERATIONS.md](OPERATIONS.md); credenciais e configuração integral do servidor **não** entram no Git.

## Código-fonte e comunidade

- Repositório oficial OTOBO: [https://github.com/RotherOSS/otobo](https://github.com/RotherOSS/otobo) (tag/série 11.0 para comparar com o núcleo em `/opt/otobo`)
- Documentação no GitHub (fontes dos manuais): [https://github.com/RotherOSS/doc-otobo-admin](https://github.com/RotherOSS/doc-otobo-admin), [https://github.com/RotherOSS/doc-otobo-dev](https://github.com/RotherOSS/doc-otobo-dev), [https://github.com/RotherOSS/doc-otobo-user](https://github.com/RotherOSS/doc-otobo-user)

## Consola útil em desenvolvimento

No servidor, como utilizador `otobo`:

```sh
su -c "/opt/otobo/bin/otobo.Console.pl List" -s /bin/bash otobo
su -c "/opt/otobo/bin/otobo.Console.pl Maint::Config::Rebuild" -s /bin/bash otobo
su -c "/opt/otobo/bin/otobo.Console.pl Maint::Cache::Delete" -s /bin/bash otobo
su -c "/opt/otobo/bin/otobo.Console.pl Maint::Email::MailQueue --list" -s /bin/bash otobo
```

A lista completa de comandos e o significado genérico estão no produto OTOBO; o uso operacional BWB está em [OPERATIONS.md](OPERATIONS.md) e [DEVELOPMENT.md](DEVELOPMENT.md).
