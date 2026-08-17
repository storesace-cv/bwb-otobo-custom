# Operação e publicação

Manuais oficiais de instalação/administração: [REFERENCES.md](REFERENCES.md). Base de continuidade: [KNOWLEDGE-BASE.md](KNOWLEDGE-BASE.md).

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
4. Executar `scripts/deploy-production.sh --apply` (inclui `Custom/`, `ZZZBWB*`, XML de SysConfig em `Kernel/Config/Files/XML/`, e `htdocs`).
5. Confirmar o daemon, o Apache, a resposta HTTP do painel e o fluxo funcional afetado.

O script nunca apaga ficheiros remotos e exige `--apply` de propósito. A matriz obrigatória está em [RUNTIME-PERMISSIONS.md](RUNTIME-PERMISSIONS.md): o código carregado pelo Apache recebe acesso de leitura controlado através do grupo `www-data`; configurações e segredos permanecem privados do utilizador `otobo`. O processo termina com uma verificação executada como `www-data` e um teste HTTP ao painel. Para mudanças de base de dados, a migração deve ser revista e executada separadamente.

Exemplo (branding Helpdesk nas notificações, 2026-08-16):

```sh
ssh bwb-otobo-prod 'mysqldump otobo notification_event_message > /root/otobo-backups/notification_event_message-before-helpdesk.sql'
ssh bwb-otobo-prod 'mysql otobo' < db/migrations/2026-08-16-email-otobo-to-helpdesk.sql
```

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
