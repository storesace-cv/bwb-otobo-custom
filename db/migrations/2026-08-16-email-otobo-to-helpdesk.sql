-- Branding de e-mail: texto visível "OTOBO" → "Helpdesk".
-- NÃO altera tags de template <OTOBO_...> / &lt;OTOBO_...&gt;.
-- Aplicar em produção após cópia de segurança da BD.

UPDATE notification_event_message
SET text = REPLACE(text, 'Abrir o ticket no OTOBO', 'Abrir o ticket no Helpdesk')
WHERE text LIKE '%Abrir o ticket no OTOBO%';

UPDATE notification_event_message
SET text = REPLACE(text, 'Abrir a marcação no OTOBO', 'Abrir a marcação no Helpdesk')
WHERE text LIKE '%Abrir a marcação no OTOBO%';
