# Desenvolvimento e validação

Leitura prévia obrigatória (automática em cada tarefa): [KNOWLEDGE-BASE.md](KNOWLEDGE-BASE.md), [REFERENCES.md](REFERENCES.md) e [FEATURES.md](FEATURES.md).

Documentação no fim de cada tarefa: **sempre** actualizar os `docs/` afectados antes de considerar o trabalho concluído.

## Princípios

1. Faça alterações apenas na camada `otobo/Custom`, recursos BWB ou configurações `ZZZBWB*`.
2. Não edite diretamente o núcleo do OTOBO em `/opt/otobo/Kernel` sem uma razão técnica documentada.
3. Não altere permissões, notificações, filas ou regras de correio fora do objetivo pedido.
4. Nunca introduza dados reais de clientes, tokens, palavras-passe ou chaves no Git.
5. Baseie cada alteração no mecanismo OTOBO documentado oficialmente (11.0) **e** no comportamento BWB já existente neste repositório.
6. Priorize excelência técnica, performance, segurança e manutenibilidade; rejeite atalhos que violem SOLID, DRY, KISS ou Clean Code.

## Antes de alterar

- Crie uma branch descritiva.
- Consulte no [REFERENCES.md](REFERENCES.md) o capítulo oficial do mecanismo em causa (módulo frontend, SysConfig XML, eventos, PostMaster, permissões, etc.).
- Leia os módulos e templates envolvidos; a mesma funcionalidade tem frequentemente código Perl, template e JavaScript.
- Verifique o impacto em BWB e ZS Angola. Uma correção numa área não pode expor clientes ou filas da outra.
- Para alterações de base de dados, crie uma migração reversível em `db/migrations/`.
- Se o comportamento funcional mudar, actualize [FEATURES.md](FEATURES.md) (e Arquitetura/Inventário se aplicável) no mesmo conjunto de alterações.
- Mesmo sem mudança grande de produto, registe no fim do trabalho o que for necessário para a próxima continuidade (decisões estruturais, restrições, contratos de e-mail/permissões).

## Validação mínima

1. Validar sintaxe Perl dos módulos alterados no servidor, com o ambiente do OTOBO.
2. Reconstituir configuração e limpar cache após alteração de XML/PM/TT/JS.
3. Testar com um agente BWB, com Amadeu/colaborador ZS e com um utilizador cliente. No ZS: dashboard do responsável deve listar **todas** as folhas da equipa; abrir a folha de um colaborador é só leitura; criar ticket/folha no Field deve gerar e-mail ao responsável (não ao cliente).
4. Confirmar comportamento em computador e telemóvel, especialmente áreas de toque e modais. No Field: após «Gravar e abrir folha», a Folha de trabalho tem de ficar estável (sem recarregar sozinha).
5. Verificar o registo do Apache e o registo OTOBO depois da publicação.
6. Executar `scripts/check.sh` antes de publicar.
7. Após alterações de **configuração** em produção (Apache, Postfix, cron, SysConfig, etc.), correr snapshot para pCloud:

```sh
ssh bwb-otobo-prod '/opt/bwb-helpdesk/scripts/backup-helpdesk-config-pcloud.sh'
```

Ver [OPERATIONS.md](OPERATIONS.md) — backups S3 (BD) + pCloud (configs).

## Convenções

- Texto da interface: português de Portugal.
- Codificação: UTF-8.
- Design de clientes: interface simples, responsiva e acessível; alvos de toque com pelo menos 44 px.
- Módulos BWB começam por `BWB`; não renomear identificadores persistidos sem migração.
- Preferir override em `Custom/` em vez de patch ao núcleo.
