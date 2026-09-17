# Segurança

## Nunca versionar

- Chaves SSH e ficheiros `~/.ssh/*`.
- Palavras-passe SMTP/IMAP, Postfix, MariaDB ou OTOBO.
- `Kernel/Config.pm`, salvo uma versão explicitamente sanitizada.
- Exportações de base de dados, anexos, registos ou cópias de correio.
- Tokens de convite ou reposição de palavra-passe.
- Credenciais pCloud / SMTP de backup (`/root/.config/bwb-helpdesk-backup.env`, `~/.config/rclone/rclone.conf` no servidor).
- Chave **Google Maps Embed** (`Maps_Embed_API` no `.env` local; SysConfig `BWB::MapsEmbedAPIKey` em produção). Restringir no Cloud a Sites do helpdesk + só Maps Embed API.

## Acesso ao servidor

Cursor pode usar a chave que já esteja configurada no computador do administrador através do alias `bwb-otobo-prod`. Nunca pedir à aplicação Cursor para guardar ou enviar essa chave.

Produção helpdesk: **Euronodes** VPS (`178.159.34.132`, `helpdesk.storesace.cv`). Não inferir o fornecedor pelo nome do ficheiro da chave SSH local.

## API `PublicBWBTicketContext` (Claude Mail MCP)

- Read-only; autenticação **Bearer** lido de `/opt/otobo/var/bwb-ticket-context.token` (e allowlist em `bwb-ticket-context.allowed-ips`). Não usar SysConfig para o segredo (`ZZZAAuto` anula).
- Token e IPs **nunca** entram no Git.
- O VPS do MCP (`mcp-mail.bwb.pt`, IP `178.159.34.165`) é o único consumidor previsto; não expor o token a Claude.ai directamente.
- Isolamento BWB↔ZS: nesta fase o token é de serviço global RO com logging; não alargar o âmbito sem revisão.

## Assistente Ajuda / RAG (`BWBAssist` + `PublicBWBAssistIndex`)

- Serviço IA em `178.159.34.165` (`/var/www/bwb-assist/.env`: `BWB_ASSIST_BEARER`, allowlist com IP do OTOBO `178.159.34.132`). Porta interna nginx `18101` → uvicorn `18100`.
- OTOBO chama o Assist com Bearer em `/opt/otobo/var/bwb-assist.token` e URL em `/opt/otobo/var/bwb-assist.url` (ex. `http://178.159.34.165:18101`).
- Índice RO: Bearer em `/opt/otobo/var/bwb-assist-index.token`, allowlist `/opt/otobo/var/bwb-assist-index.allowed-ips` (só `178.159.34.165`).
- **Isolamento:** candidatos de tickets do índice são sempre filtrados com `BWBAccess::TicketAccessCheck` na sessão do agente antes de UI/LLM.
- **Não** instalar Ollama 7B em `165` com 3,8 GiB RAM (risco OOM no mail-MCP). Activar só após upgrade de memória.
- Logs do Assist: eventos com IDs/contagens, sem corpos completos por defeito.

## API `PublicBWBPos` (plugin POS / pen técnica)

- Não é um catálogo anónimo: `Directory` e `Enroll` exigem sessão de **agente** (hash SHA-256 em `bwb_pos_session`, TTL 10 min). Falhas de login por IP são limitadas.
- O POS autentica tickets com **token por dispositivo** (`bwb_pos_device.token_hash`). Estados `suspended` / `revoked` recusam o envio. Revogar é irreversível no mesmo token.
- Sem allowlist de IP (postos em NAT de cliente). Isolamento BWB↔ZS pela empresa do agente (directory) e pela empresa gravada no token (tickets). O cliente **não** escolhe CustomerID no POST do ticket.
- Password de agente **não** fica no posto. `helpdesk.json` no POS é `0600`. O 3.º campo de `/opt/pos/version` (token PTcert) não é enviado.
- Ping público só `{ok, service}` — sem dados de clientes.

## Alterações de produção

Sempre criar cópia de segurança, validar a alteração e confirmar que:

- os clientes BWB não veem dados ZS Angola e vice-versa;
- nenhuma fila BWB foi atribuída a agentes ZS;
- mensagens automáticas usam o remetente correto;
- não existem dados pessoais em `git diff`.
