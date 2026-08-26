-- Fix link do lembrete cliente: tags <OTOBO_CONFIG_*> em href eram interpretadas
-- como HTML e partiam o URL (aparecia ":///" e %3COTOBO_CONFIG_HttpType…).
-- Usar &lt;…&gt; como no resto do corpo (já substituído pelo motor).
--
-- Pré-requisito: backup
--   mysqldump otobo notification_event_message > /root/otobo-backups/notification_event_message-before-waiting-link-fix.sql
--
-- Reversão: restaurar o dump.

UPDATE notification_event_message nem
INNER JOIN notification_event ne ON ne.id = nem.notification_id
SET nem.text = CONCAT(
    '<p>Olá &lt;OTOBO_NOTIFICATION_RECIPIENT_UserFirstname&gt;,</p>',
    '<p>O pedido <strong>Ticket#&lt;OTOBO_TICKET_TicketNumber&gt;</strong> — «&lt;OTOBO_TICKET_Title&gt;» — continua <strong>à espera da sua resposta</strong>.</p>',
    '<p>Sem a sua confirmação ou informação adicional, <strong>não conseguimos avançar</strong> com este ticket.</p>',
    '<p>Pode:</p>',
    '<ul>',
    '<li><strong>responder a este e-mail</strong>, ou</li>',
    '<li><strong>abrir o pedido no portal</strong> e responder ou, se o assunto já estiver resolvido, <strong>fechar a ocorrência</strong>.</li>',
    '</ul>',
    '<p><a href="&lt;OTOBO_CONFIG_HttpType&gt;://&lt;OTOBO_CONFIG_FQDN&gt;/&lt;OTOBO_CONFIG_ScriptAlias&gt;customer.pl?Action=CustomerTicketZoom;TicketNumber=&lt;OTOBO_TICKET_TicketNumber&gt;">Abrir o ticket no Helpdesk</a></p>',
    '<p>Se precisar de esclarecimentos, responda a esta mensagem — ficamos a aguardar.</p>',
    '<p>Com os melhores cumprimentos,<br><strong>Helpdesk</strong></p>'
),
    nem.subject = 'Aguardando a sua resposta'
WHERE ne.name = 'BWB - Lembrete aguardar resposta cliente'
  AND nem.language = 'pt';

UPDATE notification_event_message nem
INNER JOIN notification_event ne ON ne.id = nem.notification_id
SET nem.text = CONCAT(
    '<p>Hello &lt;OTOBO_NOTIFICATION_RECIPIENT_UserFirstname&gt;,</p>',
    '<p>Ticket <strong>#&lt;OTOBO_TICKET_TicketNumber&gt;</strong> — «&lt;OTOBO_TICKET_Title&gt;» — is still <strong>waiting for your reply</strong>.</p>',
    '<p>Without your confirmation or further information, <strong>we cannot progress</strong> this ticket.</p>',
    '<p>You can:</p>',
    '<ul>',
    '<li><strong>reply to this email</strong>, or</li>',
    '<li><strong>open the ticket in the portal</strong> to reply or, if already resolved, <strong>close the request</strong>.</li>',
    '</ul>',
    '<p><a href="&lt;OTOBO_CONFIG_HttpType&gt;://&lt;OTOBO_CONFIG_FQDN&gt;/&lt;OTOBO_CONFIG_ScriptAlias&gt;customer.pl?Action=CustomerTicketZoom;TicketNumber=&lt;OTOBO_TICKET_TicketNumber&gt;">Open the ticket in Helpdesk</a></p>',
    '<p>If you need clarification, reply to this message — we look forward to hearing from you.</p>',
    '<p>Kind regards,<br><strong>Helpdesk</strong></p>'
),
    nem.subject = 'Awaiting your reply'
WHERE ne.name = 'BWB - Lembrete aguardar resposta cliente'
  AND nem.language = 'en';
