# Desenvolvimento e validação

## Princípios

1. Faça alterações apenas na camada `otobo/Custom`, recursos BWB ou configurações `ZZZBWB*`.
2. Não edite diretamente o núcleo do OTOBO em `/opt/otobo/Kernel` sem uma razão técnica documentada.
3. Não altere permissões, notificações, filas ou regras de correio fora do objetivo pedido.
4. Nunca introduza dados reais de clientes, tokens, palavras-passe ou chaves no Git.

## Antes de alterar

- Crie uma branch descritiva.
- Leia os módulos e templates envolvidos; a mesma funcionalidade tem frequentemente código Perl, template e JavaScript.
- Verifique o impacto em BWB e ZS Angola. Uma correção numa área não pode expor clientes ou filas da outra.
- Para alterações de base de dados, crie uma migração reversível em `db/migrations/`.

## Validação mínima

1. Validar sintaxe Perl dos módulos alterados no servidor, com o ambiente do OTOBO.
2. Reconstituir configuração e limpar cache após alteração de XML/PM/TT/JS.
3. Testar com um agente BWB, com Amadeu/colaborador ZS e com um utilizador cliente.
4. Confirmar comportamento em computador e telemóvel, especialmente áreas de toque e modais.
5. Verificar o registo do Apache e o registo OTOBO depois da publicação.

## Convenções

- Texto da interface: português de Portugal.
- Codificação: UTF-8.
- Design de clientes: interface simples, responsiva e acessível; alvos de toque com pelo menos 44 px.
- Módulos BWB começam por `BWB`; não renomear identificadores persistidos sem migração.
