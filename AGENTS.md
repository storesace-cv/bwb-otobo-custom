# Instruções para desenvolvimento assistido

Este repositório personaliza **OTOBO 11.0.17** (BWB / StoresAce / ZS Angola). Não contém o núcleo OTOBO.

## Antes de qualquer tarefa

1. Ler [docs/KNOWLEDGE-BASE.md](docs/KNOWLEDGE-BASE.md).
2. Usar acesso directo aos manuais oficiais listados em [docs/REFERENCES.md](docs/REFERENCES.md) para o mecanismo OTOBO em causa.
3. Consultar [docs/FEATURES.md](docs/FEATURES.md) e o código em `otobo/Custom/` para o comportamento BWB já existente.
4. Respeitar [docs/SECURITY.md](docs/SECURITY.md) e [docs/OPERATIONS.md](docs/OPERATIONS.md).

## Regras críticas

- Alterar só a camada personalizada (`otobo/Custom/`, `otobo/Kernel/Config/Files/`, `otobo/var/httpd/htdocs/`).
- Preservar isolamento BWB ↔ ZS Angola (agentes ZS sem acesso a clientes/tickets/filas BWB).
- Interface em português de Portugal, UTF-8, responsiva.
- Não versionar segredos, backups nem dados de clientes.
- Não publicar automaticamente em produção alterações arriscadas sem revisão explícita.

## Fluxo por tarefa

Identificar módulos/templates/JS/config → plano breve → implementar → `scripts/check.sh` → testes (agente BWB, ZS, cliente) → actualizar `docs/` se o comportamento mudar → commit e push.
