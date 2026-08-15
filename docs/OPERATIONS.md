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
2. Executar `scripts/check.sh`.
3. Criar uma cópia de segurança no servidor antes de substituir ficheiros.
4. Executar `scripts/deploy-production.sh --apply`.
5. Confirmar o daemon, o Apache e o fluxo funcional afetado.

O script nunca apaga ficheiros remotos e exige `--apply` de propósito. Para mudanças de base de dados, a migração deve ser revista e executada separadamente.

## Registos úteis

- OTOBO: `/opt/otobo/var/log/otobo.log`
- Apache: `/var/log/apache2/error.log`
- Estado do daemon: `/opt/otobo/bin/otobo.Daemon.pl status`

## Correio

Alterações em SMTP, IMAP, Postfix, Nginx e DNS exigem validação manual e não pertencem ao repositório, porque contêm credenciais e configuração específica do servidor. Documentar a intenção e manter os segredos fora do Git.
