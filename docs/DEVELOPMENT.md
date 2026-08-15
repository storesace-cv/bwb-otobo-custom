# Desenvolvimento e validação

Leitura prévia obrigatória: [KNOWLEDGE-BASE.md](KNOWLEDGE-BASE.md), [REFERENCES.md](REFERENCES.md) e [FEATURES.md](FEATURES.md).

## Princípios

1. Faça alterações apenas na camada `otobo/Custom`, recursos BWB ou configurações `ZZZBWB*`.
2. Não edite diretamente o núcleo do OTOBO em `/opt/otobo/Kernel` sem uma razão técnica documentada.
3. Não altere permissões, notificações, filas ou regras de correio fora do objetivo pedido.
4. Nunca introduza dados reais de clientes, tokens, palavras-passe ou chaves no Git.
5. Baseie cada alteração no mecanismo OTOBO documentado oficialmente (11.0) **e** no comportamento BWB já existente neste repositório.

## Antes de alterar

- Crie uma branch descritiva.
- Consulte no [REFERENCES.md](REFERENCES.md) o capítulo oficial do mecanismo em causa (módulo frontend, SysConfig XML, eventos, PostMaster, permissões, etc.).
- Leia os módulos e templates envolvidos; a mesma funcionalidade tem frequentemente código Perl, template e JavaScript.
- Verifique o impacto em BWB e ZS Angola. Uma correção numa área não pode expor clientes ou filas da outra.
- Para alterações de base de dados, crie uma migração reversível em `db/migrations/`.
- Se o comportamento funcional mudar, actualize [FEATURES.md](FEATURES.md) (e Arquitetura/Inventário se aplicável) no mesmo conjunto de alterações.

## Validação mínima

1. Validar sintaxe Perl dos módulos alterados no servidor, com o ambiente do OTOBO.
2. Reconstituir configuração e limpar cache após alteração de XML/PM/TT/JS.
3. Testar com um agente BWB, com Amadeu/colaborador ZS e com um utilizador cliente.
4. Confirmar comportamento em computador e telemóvel, especialmente áreas de toque e modais.
5. Verificar o registo do Apache e o registo OTOBO depois da publicação.
6. Executar `scripts/check.sh` antes de publicar.

## Convenções

- Texto da interface: português de Portugal.
- Codificação: UTF-8.
- Design de clientes: interface simples, responsiva e acessível; alvos de toque com pelo menos 44 px.
- Módulos BWB começam por `BWB`; não renomear identificadores persistidos sem migração.
- Preferir override em `Custom/` em vez de patch ao núcleo.
