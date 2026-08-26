# BWB Assist (host 178.159.34.165)

Serviço FastAPI de retrieve (BM25) + síntese para o assistente de Ajuda do OTOBO.

## Decisão de capacidade

O VPS `mcp-mail.bwb.pt` (`178.159.34.165`) tem **3,8 GiB RAM** e já corre mail/WhatsApp MCP.
**Não** instalar `qwen2.5:7b` neste host sem upgrade (≥8 GiB livres).
Com `BWB_ASSIST_OLLAMA_ENABLED=0` a API usa síntese extractiva (cita artigos sem inventar passos).

## Endpoints

| Método | Path | Função |
|---|---|---|
| GET | `/health` | Estado |
| POST | `/v1/assist/faq` | Síntese a partir de excertos (+ índice FAQ) |
| POST | `/v1/assist/search` | Retrieve BM25 (faq/ticket); tickets com filtro de contexto |
| POST | `/v1/assist/query` | FAQ + tickets + síntese (contexto partilhado + `debug`) |
| POST | `/v1/index/replace` | Substituir docs de um kind |
| POST | `/v1/index/sync-from-otobo` | Puxar `PublicBWBAssistIndex` |

Autenticação: `Authorization: Bearer …` + allowlist IP (`BWB_ASSIST_ALLOWED_IPS`).

## Retrieve / Casos semelhantes

- Contexto/produto derivado dos metadados indexados (`labels`, `category_path`, prefixos de `number`, categoria, fila/serviço) — **sem** lista fixa de produtos.
- Tickets: filtro de contexto → limiar `max(TICKET_SCORE_FLOOR=3.0, best * TICKET_SCORE_RATIO=0.45)` → lista vazia se nada passar.
- Perguntas procedurais → modo `operational` (comandos literais da KB).

```sh
cd services/bwb-assist && PYTHONPATH=. python3 -m pytest tests/ -q
```

## Install

```sh
# from repo root on the VPS (rsync first)
sudo bash services/bwb-assist/deploy/install.sh
```

Segredos só em `/var/www/bwb-assist/.env` (fora do Git).
