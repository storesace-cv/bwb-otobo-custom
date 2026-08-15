# BWB OTOBO Customizações

Este repositório contém a camada de personalização usada pela instalação de produção do OTOBO da BWB / StoresAce / ZS Angola.

Não é uma cópia integral do OTOBO. O núcleo fornecido pelo OTOBO continua em `/opt/otobo`; aqui ficam apenas os módulos, templates, JavaScript, imagens e configurações acrescentados ou substituídos pela BWB.

## Começar

Leia primeiro:

1. [Arquitetura](docs/ARCHITECTURE.md)
2. [Desenvolvimento e validação](docs/DEVELOPMENT.md)
3. [Operação e publicação](docs/OPERATIONS.md)
4. [Segurança](docs/SECURITY.md)

## Estrutura

- `otobo/Custom/` — módulos Perl, templates e extensões BWB.
- `otobo/Kernel/Config/Files/` — configurações OTOBO BWB.
- `otobo/var/httpd/htdocs/` — recursos web personalizados.
- `db/current-schema.sql` — esquema atual das tabelas próprias, sem quaisquer dados.
- `scripts/` — verificações e publicação assistida.
- `docs/` — contexto para continuidade do desenvolvimento.

## Regra essencial

Nunca incluir nesta pasta palavras-passe, chaves SSH, ficheiros de configuração completos do servidor, backups, exportações ou dados de clientes. Use os ficheiros de exemplo e as credenciais locais já autorizadas no computador do administrador.
