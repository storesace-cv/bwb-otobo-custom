# Inventário importado da produção

Data de referência: 15 de agosto de 2026.

## Ambiente

- **Hosting:** Euronodes VPS (IP `178.159.34.132`, hostname `helpdesk`).
- **URL:** `https://helpdesk.storesace.cv/otobo/`.
- **OTOBO:** `/opt/otobo`, versão **11.0.17**.

## Incluído

- Código em `/opt/otobo/Custom`.
- Configurações `ZZZBWBAjuda.pm`, `ZZZBWBDashboardClosed.pm`, `ZZZBWBDashboardWork.pm` e `ZZZBWBTimeCalendars.pm`.
- Recursos estáticos BWB e ZS Angola usados pela interface.
- Esquema das tabelas próprias BWB, sem dados: `db/current-schema.sql`.

## Excluído de propósito

- Cópias de segurança antigas (`*.bak*`, `*.orig`, `*.before-*`).
- Tabelas de cópia de segurança da base de dados.
- Configuração principal, Nginx, Postfix, MariaDB, credenciais SMTP/IMAP e dados pessoais.
- Registos, anexos, exportações e caixas de correio.

## Tabelas próprias acompanhadas

- `bwb_agent_hierarchy`
- `bwb_collaborator_customer`
- `bwb_collaborator_store`
- `bwb_customer_owner`
- `bwb_customer_company_setting`
- `bwb_invite`
- `bwb_operation_type` e `bwb_operation_type_hidden`
- `bwb_result_type` e `bwb_result_type_hidden`
- `bwb_store`
- `bwb_ticket_store`
- `bwb_work_session`
- `bwb_work_sheet`

As tabelas com nomes `*_backup_*` existentes no servidor são cópias operacionais e não fazem parte do modelo aplicacional.
