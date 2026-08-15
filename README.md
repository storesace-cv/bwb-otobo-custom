# BWB OTOBO Customizações

Este repositório contém a camada de personalização usada pela instalação de produção do OTOBO da BWB / StoresAce / ZS Angola.

Não é uma cópia integral do OTOBO. O núcleo fornecido pelo OTOBO continua em `/opt/otobo`; aqui ficam apenas os módulos, templates, JavaScript, imagens e configurações acrescentados ou substituídos pela BWB.

**Versão de produção:** OTOBO **11.0.17**.

## Começar (obrigatório)

Toda a continuidade de desenvolvimento parte da [base de conhecimento](docs/KNOWLEDGE-BASE.md), que combina:

1. **Acesso directo** aos manuais oficiais OTOBO 11.0 (administração, utilização, desenvolvimento, instalação) — [docs/REFERENCES.md](docs/REFERENCES.md)
2. **Documentação neste GitHub** do que já foi e será desenvolvido na camada BWB — [docs/FEATURES.md](docs/FEATURES.md) e restantes ficheiros em `docs/`
3. **Código** em `otobo/Custom/`, configurações BWB e `db/`

Ordem sugerida:

1. [Base de conhecimento](docs/KNOWLEDGE-BASE.md)
2. [Referências oficiais OTOBO](docs/REFERENCES.md)
3. [Arquitetura](docs/ARCHITECTURE.md)
4. [Catálogo funcional BWB](docs/FEATURES.md)
5. [Desenvolvimento e validação](docs/DEVELOPMENT.md)
6. [Operação e publicação](docs/OPERATIONS.md)
7. [Segurança](docs/SECURITY.md)
8. [Inventário](docs/INVENTORY.md)

## Estrutura

- `otobo/Custom/` — módulos Perl, templates e extensões BWB.
- `otobo/Kernel/Config/Files/` — configurações OTOBO BWB.
- `otobo/var/httpd/htdocs/` — recursos web personalizados.
- `db/current-schema.sql` — esquema atual das tabelas próprias, sem quaisquer dados.
- `scripts/` — verificações e publicação assistida.
- `docs/` — contexto para continuidade do desenvolvimento.
- `AGENTS.md` — instruções curtas para agentes de desenvolvimento assistido.

## Regra essencial

Nunca incluir nesta pasta palavras-passe, chaves SSH, ficheiros de configuração completos do servidor, backups, exportações ou dados de clientes. Use os ficheiros de exemplo e as credenciais locais já autorizadas no computador do administrador.
