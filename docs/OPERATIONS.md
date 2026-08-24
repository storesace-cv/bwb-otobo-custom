# Operação e publicação

Manuais oficiais de instalação/administração: [REFERENCES.md](REFERENCES.md). Base de continuidade: [KNOWLEDGE-BASE.md](KNOWLEDGE-BASE.md).

## Produção (helpdesk)

| | |
|---|---|
| Fornecedor | **Euronodes** (VPS) |
| IP / hostname | `178.159.34.132` / `helpdesk` |
| URL | `https://helpdesk.storesace.cv/otobo/` |
| SSH | alias local `bwb-otobo-prod` |

Detalhe em [ARCHITECTURE.md](ARCHITECTURE.md). O ficheiro de chave SSH local pode chamar-se `digitalocean`; isso **não** define o hosting.

## Acesso SSH local

No computador autorizado do administrador, criar `~/.ssh/config` a partir de [`config/ssh-config.example`](../config/ssh-config.example). A chave privada já existe localmente e não deve ser copiada.

Teste de ligação:

```sh
ssh bwb-otobo-prod 'hostname && /opt/otobo/bin/otobo.Daemon.pl status'
```

## Publicar com segurança

1. Confirmar que a branch e o `git status` são os pretendidos.
2. Executar `scripts/check.sh` e `scripts/verify-runtime-permissions.sh --production`.
3. Criar uma cópia de segurança no servidor antes de substituir ficheiros.
4. Executar `scripts/deploy-production.sh --apply` (inclui `Custom/`, `ZZZBWB*`, XML de SysConfig em `Kernel/Config/Files/XML/`, `Kernel/Language/pt_ZZZ*.pm` e `htdocs`).
5. Confirmar o daemon, o Apache, a resposta HTTP do painel e o fluxo funcional afetado.

O script nunca apaga ficheiros remotos e exige `--apply` de propósito. A matriz obrigatória está em [RUNTIME-PERMISSIONS.md](RUNTIME-PERMISSIONS.md): o código e o SysConfig compilado (`ZZZAAuto.pm` / `ZZZBWB*.pm`) carregados pelo Apache recebem leitura via grupo `www-data`; fontes XML SysConfig e segredos permanecem privados do utilizador `otobo`. Após `Maint::Config::Rebuild` o deploy reaplica permissões em `ZZZAAuto.pm` (o rebuild volta a deixar o ficheiro ilegível para o Apache). O processo termina com verificação como `www-data` e teste HTTP ao painel (incluindo detecção da mensagem «not registered in Kernel/Config.pm»). Para mudanças de base de dados, a migração deve ser revista e executada separadamente.

Nota operacional: sem modelos `Answer` ligados à fila (`queue_standard_template`), o zoom do ticket **não mostra** «Responder». Migração de referência: `db/migrations/2026-08-17-queue-answer-templates.sql`. Modelo de resposta `mod-apple-01` (cartão Helpdesk, escolhível em Responder):

```sh
ssh bwb-otobo-prod 'mysqldump otobo standard_template queue_standard_template > /root/otobo-backups/standard_template-before-mod-apple-01.sql'
ssh bwb-otobo-prod 'mysql otobo' < db/migrations/2026-08-19-mod-apple-01-answer-template.sql
```

### Contexto ticket para Claude Mail MCP (`PublicBWBTicketContext`)

1. Publicar código (deploy) e Rebuild/cache.
2. No servidor, criar ficheiros **fora do SysConfig** (o `ZZZAAuto.pm` anula defaults XML):
   - `/opt/otobo/var/bwb-ticket-context.token` — uma linha com o Bearer (`chmod 640`, `otobo:www-data`)
   - `/opt/otobo/var/bwb-ticket-context.allowed-ips` — um IP por linha (ex. `178.159.34.165`)
3. Apache (vhost HTTPS): passar `Authorization` ao PSGI — `RewriteCond %{HTTP:Authorization} .` + `RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]` (já aplicado em produção a 2026-08-21).
4. No MCP, `/var/www/mail-mcp/.env`: `HELPDESK_CONTEXT_URL` + `HELPDESK_CONTEXT_TOKEN` (mesmo Bearer); redeploy `deploy/install.sh`.

### Google Maps Embed (mapa da folha)

1. Chave local em `.env` (`Maps_Embed_API=…`) — nunca no Git.
2. Em produção, SysConfig **`BWB::MapsEmbedAPIKey`** (Admin → SysConfig, ou `Admin::Config::Update` após Rebuild).
3. No Google Cloud: só **Maps Embed API**; restrição **Sites** com `https://helpdesk.storesace.cv/*` e `https://helpdesk.bwb.pt/*` se aplicável.
4. O filtro `BWBWorkMapEmbedKey` injecta a chave no JS do AgentTicketZoom; o iframe Embed usa `referrerpolicy=strict-origin-when-cross-origin`.
5. Teste: `curl -H 'Authorization: Bearer …' 'https://helpdesk.storesace.cv/otobo/public.pl?Action=PublicBWBTicketContext;TicketNumber=…'`

Handoff detalhado: repo `bwb-claude-mail-mcp` → `docs/HANDOFF-IMPLEMENTACAO-HELPDECK-CONTEXT.md`.
Folhas ZS já no sistema em que o responsável (UserID 4) ficou dono da sessão depois de passar o ticket a um colaborador: `db/migrations/2026-08-17-zs-supervisor-session-handoff.sql` (rever o `SELECT` equivalente no servidor antes do `UPDATE`).

Loja persistida no ticket (`bwb_ticket_store`, DF `BWBStore`, texto da notificação de ticket novo): aplicar **com** a publicação do código, depois `Maint::Cache::Delete`:

```sh
ssh bwb-otobo-prod 'mysqldump otobo ticket dynamic_field dynamic_field_value notification_event_message > /root/otobo-backups/ticket-store-before.sql'
ssh bwb-otobo-prod 'mysql otobo' < db/migrations/2026-08-18-ticket-store.sql
```

Coordenadas GPS nas lojas e no fecho da folha (`bwb_store.latitude/longitude`, colunas `finish_*` em `bwb_work_session`):

```sh
ssh bwb-otobo-prod 'mysqldump otobo bwb_store bwb_work_session > /root/otobo-backups/store-work-location-before.sql'
ssh bwb-otobo-prod 'mysql otobo' < db/migrations/2026-08-22-store-work-location.sql
```

Manuais Ajuda (GPS na folha + tickets/calendário) — conteúdo em `db/faq-content/`; SQL gerado por `python3 scripts/apply-faq-manuals.py`:

```sh
ssh bwb-otobo-prod 'mysqldump otobo faq_item > /root/otobo-backups/faq-item-before-manuais-gps-calendario.sql'
ssh bwb-otobo-prod 'mysql otobo' < db/migrations/2026-08-22-faq-manuais-gps-calendario.sql
ssh bwb-otobo-prod 'su -c "bin/otobo.Console.pl Maint::Cache::Delete" -s /bin/bash otobo'
```

Reversão: `DELETE FROM faq_item WHERE f_number IN ('HD-GPS-FOLHA','HD-TICKETS-CALENDARIO');` (comentário no topo da migração).

### Base de conhecimento PTcert

**Operacional** (39 artigos + anexos) — gerar a partir dos DOCX, SQL fora do Git:

```sh
python3 scripts/build-ptcert-faq.py '/caminho/para/documentacao'
python3 scripts/apply-ptcert-faq.py --write /tmp/ptcert-faq.sql
scripts/check.sh
ssh bwb-otobo-prod 'mysqldump otobo faq_category faq_category_group faq_item faq_attachment > /root/otobo-backups/faq-before-ptcert.sql'
ssh bwb-otobo-prod 'mysql --binary-mode=1 otobo' < /tmp/ptcert-faq.sql
ssh bwb-otobo-prod 'su -c "/opt/otobo/bin/otobo.Console.pl Maint::Cache::Delete" -s /bin/bash otobo'
```

**Técnico** (9 artigos `PTC-TEC-*` / `PTC-WSL2-*`) — repo **`bwb-otobo-custom-ptcert`**, migração idempotente que **não** toca nos 39 operacionais nem na categoria antiga id **12**:

```sh
# no repo bwb-otobo-custom-ptcert
python3 scripts/apply-ptcert-technical-kb.py --write /tmp/ptcert-technical-kb.sql
ssh bwb-otobo-prod 'mysqldump otobo faq_category faq_category_group faq_item faq_attachment > /root/otobo-backups/faq-before-ptcert-technical-$(date -u +%Y%m%dT%H%M%SZ).sql'
ssh bwb-otobo-prod 'mysql --binary-mode=1 otobo' < /tmp/ptcert-technical-kb.sql
ssh bwb-otobo-prod 'su -c "/opt/otobo/bin/otobo.Console.pl Maint::Cache::Delete" -s /bin/bash otobo'
```

Backup de referência (importação técnica 2026-08-24): `/root/otobo-backups/faq-before-ptcert-technical-20260824T215039Z.sql` (SHA-256 `598c60fbdac7a29336ced5bf3b1dd7a3a4d9f8b407d7eb5ac1b477152281850f`).

Antes de qualquer escrita: inspeccionar a BD viva (categorias por pai/nome, artigos por `f_number`); confirmar `state_id=2`, aprovação, validade e grupos; validar ausência de duplicados. Árvore activa: **Documentação interna → PTcert** (id **29**), subcategorias **38** / **39**. Reversão operacional: repor dump; não apagar nem consolidar id **12** sem análise explícita.

Devolução DSN criada como ticket novo (ex. `2026081762000058` / id 437, 2026-08-17): fundir para o ticket original (`2026081762000049` / id 436) depois de tornar o artigo da DSN não visível ao cliente, e disparar `BWBBounceNotify` para o proprietário **e** o agente responsável. Não reabrir o ticket encerrado.

Exemplo (branding Helpdesk nas notificações, 2026-08-16):

```sh
ssh bwb-otobo-prod 'mysqldump otobo notification_event_message > /root/otobo-backups/notification_event_message-before-helpdesk.sql'
ssh bwb-otobo-prod 'mysql otobo' < db/migrations/2026-08-16-email-otobo-to-helpdesk.sql
```

## Cópias de segurança automáticas (helpdesk)

Estratégia em **dois destinos**:

| Destino | Conteúdo | Horário | Retenção |
|---|---|---|---|
| **Euronodes S3** `bwb-backups/helpdesk/` | Dump MariaDB `otobo` (~670 MB `.sql.gz`) | **01:00** e **12:00** | **8 dias** |
| **pCloud** `backups/helpdesk-config/` | Configs Ubuntu/OTOBO (auditoria pós-alterações) | **01:30** | **30 dias** |

O pCloud **já não** recebe dumps de BD (legado `backups/helpdesk/` pode ser apagado manualmente quando confirmares os S3).

### O que entra no snapshot de configuração (pCloud)

- Apache, Postfix, MariaDB, Nginx (se existir), cron, systemd, rede básica
- `Kernel/Config/Files/` e XML Custom OTOBO
- Scripts `/opt/bwb-helpdesk/scripts/`
- `Config.pm` **redigido** (password BD substituída por `[REDACTED]`)
- **Excluído:** `rclone.conf`, `.env` de backup, segredos Postfix em claro

### Configuração inicial

Credenciais em `.env` local (modelo [`.env.example`](../.env.example)) — **nunca** commitar:

```env
EURONODES_S3_ACCESS_KEY=...
EURONODES_S3_SECRET_KEY=...
EURONODES_S3_BUCKET=bwb-backups
EURONODES_S3_PATH=helpdesk
PCLOUD_USERNAME=...
PCLOUD_PASSWORD=...
```

```sh
BWB_ENV_FILE=/caminho/para/.env scripts/setup-backup-helpdesk.sh --run-now
```

Variáveis no servidor: `/root/.config/bwb-helpdesk-backup.env` (chmod 600).

### Operação

```sh
# Ambos (BD S3 + config pCloud)
ssh bwb-otobo-prod '/opt/bwb-helpdesk/scripts/backup-helpdesk-run.sh'

# Só BD → S3
ssh bwb-otobo-prod '/opt/bwb-helpdesk/scripts/backup-helpdesk-s3.sh'

# Só config → pCloud (recomendado após alterações em produção)
ssh bwb-otobo-prod '/opt/bwb-helpdesk/scripts/backup-helpdesk-config-pcloud.sh'

ssh bwb-otobo-prod 'crontab -l | grep backup-helpdesk'
ssh bwb-otobo-prod 'rclone lsl euronodes-s3:bwb-backups/helpdesk | tail -3'
ssh bwb-otobo-prod 'rclone lsl bwb-pcloud-helpdesk:backups/helpdesk-config | tail -3'
```

Alerta email quando o **bucket S3** total ≥ **800 GB** (máx. 1×/24 h) → `jorge.peixinho@bwb.pt`.

Modelo de variáveis servidor: [`config/backup-helpdesk.env.example`](../config/backup-helpdesk.env.example).

**Capacidade S3:** ~670 MB/cópia; 8 dias × 2 execuções/dia ≈ até **~10 GB** no prefixo `helpdesk/` (1 TB Euronodes dá margem ampla).

**Painel Euronodes:** o widget do bucket lista objectos na **raiz**; os dumps ficam no prefixo `helpdesk/` (ex.: `helpdesk/otobo-helpdesk-….sql.gz`). Confirmar com `rclone lsl euronodes-s3:bwb-backups/helpdesk` no servidor.


## Registos úteis

- OTOBO: `/opt/otobo/var/log/otobo.log`
- Apache: `/var/log/apache2/error.log`
- Estado do daemon: `/opt/otobo/bin/otobo.Daemon.pl status`

## Sessão Agent (Field / colaboradores)

Valores efectivos via `Kernel/Config/Files/ZZZBWBSession.pm` (após `ZZZAAuto`):

| Setting | Valor BWB | Motivo |
|---|---|---|
| `SessionMaxIdleTime` | `1200` (20 min) | Re-autenticação só após inactividade real |
| `SessionCheckRemoteIP` | `0` | Telemóvel muda de IP; com `1` o OTOBO invalidava a sessão |

Colaboradores: módulo `BWBAgentSessionGuard` (PreApplication) mantém **uma** sessão Agent por utilizador — login ou uso noutro equipamento termina as restantes.

## Correio

Alterações em SMTP, IMAP, Postfix, Nginx e DNS exigem validação manual e não pertencem ao repositório, porque contêm credenciais e configuração específica do servidor. Documentar a intenção e manter os segredos fora do Git.

O botão **Verificar** na ficha de utilizador de cliente liga-se ao MX do destinatário na **porta 25** (prova `RCPT TO`, sem enviar mensagem). O envio normal do helpdesk pode ir pelo relay na 587; se a 25 de saída estiver fechada, o botão fica «inconclusivo» (a sintaxe/MX ainda corre). Confirmado em 2026-08-17: TCP 25 de saída para o MX do Gmail está aberta; um endereço inexistente devolveu `550 5.1.1` e uma caixa existente devolveu `250`.
