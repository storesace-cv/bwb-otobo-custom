# Roadmap Helpdesk BWB / ZS Angola

Actualizado em 22 de agosto de 2026. O comportamento já em produção está em [FEATURES.md](FEATURES.md). Este ficheiro distingue **entregue recentemente** de **passos seguintes**.

## Entregue (agosto 2026)

- Isolamento BWB ↔ ZS Angola, Field Mode, folhas de trabalho, convites, DSN, branding Helpdesk.
- E-mails alternativos do utilizador de cliente; Verificar e-mail na ficha; Associar e-mail no zoom.
- Duração contabilizada controlada na ficha do cliente.
- Loja persistida no ticket (`bwb_ticket_store`, menu Alterar loja, tags `<OTOBO_BWB_STORE>`).
- «Responder» nas filas `bwb-in` / `zs-postmaster` (ligação a modelos `Answer`).
- Handoff de folha ZS ao passar o ticket a um colaborador.
- Registo telefónico / e-mail em nome do cliente (`BWBTicketIntake`), com e-mails de declaração.
- **Modelo de resposta `mod-apple-01`:** cartão Helpdesk; resumo sob a marca; saudação numa linha; tags encoded; largura telemóvel.
- **Contexto Helpdesk → Claude Mail MCP:** headers `X-BWB-*` nos envios; API `PublicBWBTicketContext`; patches MCP `get_message` + tool `helpdesk_ticket_context` (VPS `mcp-mail.bwb.pt`).
- **Localização no fecho da folha:** GPS no «Terminar trabalho» com fallback às coordenadas da loja; mapa **Google Maps Embed** no AgentTicketZoom (só helpdesk; chave `BWB::MapsEmbedAPIKey`); lat/lon opcionais em Admin → Lojas.
- **Agendamentos pendentes:** rótulo «Pendente com Agendamento»; diálogo nativo de marcação na folha; sync calendário→estado + `Pending till`; widget dashboard «Agendamentos pendentes»; guarda contra estado manual sem marcação.

## Seguinte

- Relatório **Tempo dispendido**: passar a usar a loja do **ticket** (`bwb_ticket_store`) em vez da loja da ficha do utilizador. O `store_id` do ticket já está pronto.
- Envelope das notificações (`Default.tt`) e e-mails de «Nova ocorrência registada»: fora do âmbito do `mod-apple-01`; só se forem pedidos à parte.
- Novas filas: ligar modelos `Answer` (`queue_standard_template`) para o zoom mostrar «Responder».
- MCP: scopes BWB↔ZS no lookup (se o token deixar de ser global RO); backup off-host do estado mail-mcp.
- Preencher coordenadas das lojas em produção (Admin → Lojas) para o fallback GPS ser útil no terreno.
