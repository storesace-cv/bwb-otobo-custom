# Permissões de execução em produção

Este documento é obrigatório para qualquer alteração ao OTOBO personalizado. Evita que um ficheiro copiado para produção funcione para o utilizador `otobo`, mas falhe no portal porque o Apache executa como `www-data`.

## Regra de segurança

| Área | Proprietário e grupo | Diretórios | Ficheiros | Motivo |
|---|---|---:|---:|---|
| `Custom/Kernel/Modules` | `otobo:www-data` | `750` | `.pm` `640` | Controladores carregados pelo portal Agent/Cliente. |
| `Custom/Kernel/Output` | `otobo:www-data` | `750` | `.pm` e `.tt` `640` | Menus, widgets e modelos HTML carregados pelo portal. |
| Módulos web em `Custom/Kernel/System` indicados na lista de controlo | `otobo:www-data` | `750` nos diretórios ancestrais | `.pm` `640` | Serviços personalizados carregados durante pedidos web. |
| Configurações, tarefas de consola, IMAP/PostMaster e segredos | `otobo:otobo` | `750` | `640` | Não são expostos ao utilizador do Apache sem necessidade. |
| `var/httpd/htdocs` | `otobo:www-data` | `755` | `644` | Recursos estáticos servidos pelo navegador. |

`www-data` recebe apenas leitura e travessia dos componentes necessários. Nunca recebe escrita no código OTOBO.

## Lista de controlo obrigatória

`scripts/runtime-web-system-modules.txt` enumera os módulos de `Custom/Kernel/System` que são efetivamente carregados numa sessão web. Ao criar ou usar um novo serviço a partir de um módulo Agent/Cliente/Template, adicioná-lo à lista no mesmo commit.

## Fluxo obrigatório de publicação

1. Atualizar este documento e a lista de controlo se houver módulo/template/asset novo ou movido.
2. Executar `scripts/check.sh`.
3. Publicar com `scripts/deploy-production.sh --apply`.
4. O próprio deploy aplica a matriz acima, limpa cache, confirma que `www-data` lê todos os módulos/templates web e testa HTTP.
5. Executar `scripts/verify-runtime-permissions.sh --production` e testar a funcionalidade afetada como BWB, ZS Angola e cliente quando relevante.

Uma falha em qualquer verificação bloqueia a publicação. Não corrigir permissões manualmente sem levar a regra equivalente para este repositório.

## Diagnóstico rápido

Quando aparecer `Permission denied` ou `could not be loaded`, consultar `/var/log/apache2/error.log`, identificar o caminho e executar a verificação. O problema é de implementação apenas se a validação indicar que `www-data` consegue ler o recurso e a sintaxe do módulo está correta.
