# Segurança

## Nunca versionar

- Chaves SSH e ficheiros `~/.ssh/*`.
- Palavras-passe SMTP/IMAP, Postfix, MariaDB ou OTOBO.
- `Kernel/Config.pm`, salvo uma versão explicitamente sanitizada.
- Exportações de base de dados, anexos, registos ou cópias de correio.
- Tokens de convite ou reposição de palavra-passe.
- Credenciais pCloud / SMTP de backup (`/root/.config/bwb-helpdesk-backup.env`, `~/.config/rclone/rclone.conf` no servidor).

## Acesso ao servidor

Cursor pode usar a chave que já esteja configurada no computador do administrador através do alias `bwb-otobo-prod`. Nunca pedir à aplicação Cursor para guardar ou enviar essa chave.

Produção helpdesk: **Euronodes** VPS (`178.159.34.132`, `helpdesk.storesace.cv`). Não inferir o fornecedor pelo nome do ficheiro da chave SSH local.

## Alterações de produção

Sempre criar cópia de segurança, validar a alteração e confirmar que:

- os clientes BWB não veem dados ZS Angola e vice-versa;
- nenhuma fila BWB foi atribuída a agentes ZS;
- mensagens automáticas usam o remetente correto;
- não existem dados pessoais em `git diff`.
