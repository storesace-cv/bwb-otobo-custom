# Base de conhecimento para desenvolvimento

Este repositório é a fonte de continuidade da camada BWB / StoresAce / ZS Angola sobre **OTOBO 11.0.17**.

Qualquer desenvolvimento (humano ou assistido) deve partir **em simultâneo** de:

1. Documentação oficial OTOBO (acesso directo, versão 11.0) — ver [REFERENCES.md](REFERENCES.md).
2. Documentação e código deste repositório GitHub — comportamento já implementado e regras de operação.
3. Código em `otobo/Custom/`, configurações `ZZZBWB*` e esquema em `db/`.

Não se copia para aqui o manual integral do OTOBO. Usa-se a documentação oficial por URL estável da série **11.0**, e neste GitHub fica o que é específico da instalação e da personalização BWB.

## Ordem de leitura obrigatória

Antes de planear ou alterar código:

| Ordem | Fonte | Conteúdo |
|---|---|---|
| 1 | [REFERENCES.md](REFERENCES.md) | Manuais oficiais: administração, utilização, desenvolvimento, instalação |
| 2 | [ARCHITECTURE.md](ARCHITECTURE.md) | Domínios funcionais e componentes BWB |
| 3 | [FEATURES.md](FEATURES.md) | Catálogo do que já foi desenvolvido e como se comporta |
| 4 | [ROADMAP.md](ROADMAP.md) | Entregue recentemente e passos seguintes |
| 5 | [DEVELOPMENT.md](DEVELOPMENT.md) | Princípios, fluxo de alteração e validação |
| 6 | [OPERATIONS.md](OPERATIONS.md) | Publicação, SSH, cópias de segurança |
| 7 | [SECURITY.md](SECURITY.md) | Segredos, isolamento BWB/ZS, o que nunca versionar |
| 8 | [INVENTORY.md](INVENTORY.md) | O que veio da produção e tabelas próprias |

Depois disso, identificar no código os módulos Perl, templates TT, JavaScript e XML/PM de configuração envolvidos na tarefa.

## Fontes de verdade

| Tema | Fonte de verdade |
|---|---|
| Comportamento genérico OTOBO (tickets, filas, notificações, ACL, console, Custom/) | Manuais oficiais 11.0 em [REFERENCES.md](REFERENCES.md) |
| Separação BWB ↔ ZS Angola, lojas, folhas de trabalho, convites, IMAP ZS | Este repositório (`docs/` + `otobo/Custom/`) |
| Utilização no terreno / responsável ZS Angola | [MANUAL-ZS-ANGOLA.md](MANUAL-ZS-ANGOLA.md) |
| Manuais internos Ajuda (FAQ agente) | Helpdesk: `db/faq-content/`; PTcert operacional: `db/ptcert-content/` + `scripts/apply-ptcert-faq.py`; PTcert técnico: repo **`bwb-otobo-custom-ptcert`** + `scripts/apply-ptcert-technical-kb.py` — ver [FEATURES.md](FEATURES.md) § Ajuda |
| Esquema de tabelas BWB | `db/current-schema.sql` e `db/migrations/` |
| Credenciais, Nginx, Postfix, MariaDB, Config.pm integral | Servidor de produção apenas — **fora do Git** |
| Versão em produção | OTOBO **11.0.17** em `/opt/otobo` (`RELEASE`) |
| Hosting helpdesk (produção) | **Euronodes** VPS — IP `178.159.34.132`, hostname `helpdesk`, URL `https://helpdesk.storesace.cv/otobo/` — ver [ARCHITECTURE.md](ARCHITECTURE.md). **Não** DigitalOcean. |

## Checklist por tarefa

1. Abrir as secções relevantes dos manuais oficiais (dev/admin/user) para o mecanismo OTOBO em causa — **sempre, sem pedido explícito**.
2. Ler em [FEATURES.md](FEATURES.md) e no código Custom o comportamento BWB já existente.
3. Confirmar impacto em BWB **e** ZS Angola (clientes, filas, permissões, e-mail).
4. Apresentar plano breve (ficheiros a tocar); rejeitar atalhos que gerem débito técnico.
5. Implementar só na camada personalizada, salvo razão técnica documentada (SOLID, DRY, KISS, Clean Code).
6. Correr `scripts/check.sh` e testar (agente BWB, agente/colaborador ZS, utilizador cliente).
7. **Documentar sempre** no fim: actualizar [FEATURES.md](FEATURES.md) e os restantes `docs/` afectados; só omitir se a mudança for puramente cosmética sem impacto funcional/operacional.
8. Commit claro e envio para o GitHub; publicação em produção só com revisão explícita e cópia de segurança.

Postura permanente: Engenheiro Principal — ver `AGENTS.md` e regras Cursor `principal-engineer` / `bwb-otobo-continuity`.


## Manutenção desta base

- Quando a versão OTOBO de produção mudar, actualizar a versão neste documento e as URLs em [REFERENCES.md](REFERENCES.md) para a série correspondente.
- Quando se acrescentar funcionalidade BWB, actualizar [FEATURES.md](FEATURES.md) e, se necessário, [ARCHITECTURE.md](ARCHITECTURE.md) / [INVENTORY.md](INVENTORY.md).
- Não colar aqui textos longos dos manuais oficiais; preferir ligações e resumos locais só do que for específico BWB.
