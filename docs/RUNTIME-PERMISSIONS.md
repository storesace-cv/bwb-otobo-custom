# Permissões de execução em produção

Este documento é obrigatório para qualquer alteração ao OTOBO personalizado. Evita que um ficheiro copiado para produção funcione para o utilizador `otobo`, mas falhe no portal porque o Apache executa como `www-data`.

## Regra de segurança

| Área | Proprietário e grupo | Diretórios | Ficheiros | Motivo |
|---|---|---:|---:|---|
| `Custom/Kernel/Modules` | `otobo:www-data` | `750` | `.pm` `640` | Controladores carregados pelo portal Agent/Cliente. |
| `Custom/Kernel/Output` | `otobo:www-data` | `750` | `.pm` e `.tt` `640` | Menus, widgets e modelos HTML carregados pelo portal. O HTML de referência `BWBEmail/mod-apple-01.html` não é carregado pelo Apache (vive em `standard_template.text`); segue o mesmo dono no deploy do `Custom/`. |
| Módulos web em `Custom/Kernel/System` indicados na lista de controlo | `otobo:www-data` | `750` nos diretórios ancestrais | `.pm` `640` | Serviços personalizados carregados durante pedidos web. |
| `Kernel/Config/Files/*.pm` (`ZZZAAuto.pm`, `ZZZBWB*.pm`, …) | `otobo:www-data` | directório `2750` | `.pm` `640` | SysConfig compilado carregado em **cada** pedido web. Sem leitura por `www-data` surge `Module … not registered in Kernel/Config.pm`. |
| `Kernel/Config/Files/XML` e `User/` | `otobo:otobo` | `2750` | `640` | Fontes SysConfig e overrides de utilizador; só a consola/`Rebuild` precisa de as ler. |
| `Kernel/Config.pm` e segredos (IMAP, DB, …) | `otobo:www-data` ou `otobo:otobo` conforme o ficheiro | — | `640` | `Config.pm` é lido pelo Apache; credenciais auxiliares ficam privadas ao `otobo`. |
| `var/httpd/htdocs` | `otobo:www-data` | `755` | `644` | Recursos estáticos servidos pelo navegador. |

`www-data` recebe apenas leitura e travessia dos componentes necessários. Nunca recebe escrita no código OTOBO.

O JS `Core.Agent.BWBWorkMap.js` e CSS `BWBWorkMap.css` seguem a matriz `htdocs`. O JS `Core.Agent.BWBWorkAppointment.js` (diálogo de marcação na folha) e o CSS nativo `Core.AppointmentCalendar.css` (loader `BWBWorkAppointment.xml`) seguem a mesma matriz `htdocs` / SysConfig Loader. O módulo `AgentBWBWorkMap.pm`, o filtro `FilterElementPost/BWBWorkMapEmbedKey.pm` e o XML `BWBWorkMap.xml` / `ZZZBWBWorkMap.pm` seguem Modules/Output e SysConfig compilado. A chave Google Embed (`BWB::MapsEmbedAPIKey`) fica só em SysConfig/produção — nunca no Git.

### Atenção: `Maint::Config::Rebuild`

O rebuild reescreve `ZZZAAuto.pm` tipicamente como `otobo:otobo` `660`. O deploy **tem** de reaplicar `otobo:www-data` `640` **depois** do rebuild. Caso contrário o portal Agent/Cliente deixa de registar módulos (`AgentTicketZoom`, dashboard, etc.).

## Lista de controlo obrigatória

`scripts/runtime-web-system-modules.txt` enumera os módulos de `Custom/Kernel/System` que são efetivamente carregados numa sessão web. Ao criar ou usar um novo serviço a partir de um módulo Agent/Cliente/Template **ou de um evento de ticket/calendário**, adicioná-lo à lista no mesmo commit. Inclui `BWBAppointmentCheck.pm`, `Calendar/Event/BWBAppointmentTicketSync.pm` e `Ticket/Event/BWBStateRequiresAppointment.pm` (sync calendário→estado «Pendente com Agendamento» e guarda de estado manual). Inclui `BWBZSSupervisorNotify.pm` / `Ticket/Event/BWBZSSupervisor.pm`, `BWBTicketIntake.pm` (registo telefónico/e-mail em nome do cliente; evento supervisor salta alarme duplicado no intake desktop), `BWBBounce.pm` / `BWBBounceNotify.pm` / `Ticket/Event/BWBBounce.pm` (DSN em `ArticleCreate`), `BWBEmailVerify.pm` (botão Verificar na ficha `AdminCustomerUser`), `BWBCustomerCompany.pm` (flag «Duração contabilizada» na ficha do cliente; também `FilterElementPost/BWBHideAccountedDuration.pm` em `Custom/Kernel/Output`), `BWBTimeSpent.pm` (relatório Tempo dispendido), `BWBTicketStore.pm` / `Ticket/Event/BWBTicketStore.pm` (loja persistida no ticket; evento `TicketCreate`/`TicketCustomerUpdate` e diálogo `AgentBWBTicketStore`) e `Ticket/Event/NotificationEvent/Transport/Email.pm` (override de e-mail de notificação; sem leitura por `www-data` as notificações falham com «could not be loaded»). O gerador PDF `Custom/Kernel/Output/PDF/BWBTimeSpent.pm` fica na matriz `Custom/Kernel/Output` (`otobo:www-data` 640); os cabeçalhos `var/httpd/htdocs/common/img/pdf-header-bwb.png` e `pdf-header-zs.png` seguem a matriz `htdocs` (`644`). Os overrides `CustomerTicketArticleContent.pm` e `CustomerTicketPrint.pm` seguem a matriz `Custom/Kernel/Modules`. O JS `Core.Agent.BWBTicketStoreDialog.js` e `Core.Agent.BWBTicketIntake.js` seguem a matriz `htdocs`. O CSS `BWBTicketIntake.css` também. `ZZZBWBTicketStore.pm` segue a matriz `Kernel/Config/Files/*.pm` (`otobo:www-data` 640, reaplicar após Rebuild). O filtro `FilterElementPost/BWBComposeAppleTemplate.pm` segue a matriz `Custom/Kernel/Output`; o JS `Core.Agent.BWBComposeApple.js` segue a matriz `htdocs`. `BWBEmailContext.pm` e o wrapper `Custom/Kernel/System/Email.pm` (headers `X-BWB-*`) e o módulo `PublicBWBTicketContext.pm` seguem as matrizes System/Modules; `ZZZBWBTicketContext.pm` (só servidor, com Bearer) segue `Kernel/Config/Files/*.pm`.

## Fluxo obrigatório de publicação

1. Atualizar este documento e a lista de controlo se houver módulo/template/asset novo ou movido.
2. Executar `scripts/check.sh`.
3. Publicar com `scripts/deploy-production.sh --apply`.
4. O próprio deploy aplica a matriz acima, limpa cache, confirma que `www-data` lê todos os módulos/templates web e testa HTTP.
5. Executar `scripts/verify-runtime-permissions.sh --production` e testar a funcionalidade afetada como BWB, ZS Angola e cliente quando relevante.

Uma falha em qualquer verificação bloqueia a publicação. Não corrigir permissões manualmente sem levar a regra equivalente para este repositório.

## Diagnóstico rápido

Quando aparecer `Permission denied` ou `could not be loaded`, consultar `/var/log/apache2/error.log`, identificar o caminho e executar a verificação. O problema é de implementação apenas se a validação indicar que `www-data` consegue ler o recurso e a sintaxe do módulo está correta.
