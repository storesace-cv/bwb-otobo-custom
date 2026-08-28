# Investigação: desempenho mod-apple-01 no AgentTicketZoom

Actualizado: 2026-08-28.

## Contexto

- Ticket de teste: **485** (artigos 1464 normal, 1437/1503/1541 Apple).
- **33** anexos HTML com assinatura Apple em **13** tickets (produção, read-only).
- Backend (`AgentTicketArticleContent`, `ArticleUpdate`) ~0,6–1,1 s — **não** explica demora percebida isoladamente.

## Baseline pré-correcção (evidência anterior + estrutural)

| Artigo | Tipo | HTML bytes | figures | tables | `!important` |
|---|---|---|---|---|---|
| 1464 | normal | 9804 | 0 | 6 | 20* |
| 1437 | Apple directo | 20847 | 4 | 4 | 3 |
| 1503 | Apple citado | 31898 | 9 | 9 | 3 |
| 1541 | Apple multi | 35965 | 13 | 13 | 3 |

\* normal: estilos inline diversos, sem bloco `<style>` global Apple.

Template legado (2026-08-21): **7833 B**, 4 figures, 1 `<style>`, 10× `!important`, 3 marcadores.  
Template v2 (2026-08-28): **5207 B**, 0 figures, 0 `<style>`, 0× `!important`, 1 marcador `bwb-answer-card`.

## Causas objectivas corrigidas nesta entrega

1. HTML `mod-apple-01` excessivamente complexo (figure CKEditor, CSS global, `!important`, media queries).
2. `Core.Agent.BWBWorkMap.js`: polling `setInterval(2500)`, scans globais de iframes, `HideLegacyMap` com `querySelectorAll('div')`.
3. Artigos históricos com mesma estrutura problemática em `article_data_mime_attachment.content`.

## Medições browser (preencher após deploy)

| Artigo | Clique→legível (antes) | Clique→legível (depois) | Long tasks pós-load (depois) |
|---|---|---|---|
| 1464 | — | — | — |
| 1437 | — | — | — |
| 1503 | — | — | — |
| 1541 | — | — | — |

Procedimento: Performance Trace Chrome/Brave desktop no AgentTicketZoom; marcar clique, fim `ArticleUpdate`, iframe load, `CheckIFrameHeight`, handlers BWBWorkMap.

## Correcções aplicadas

- **Via A:** [`mod-apple-01.html`](../../otobo/Custom/Kernel/Output/HTML/Templates/Standard/BWBEmail/mod-apple-01.html) v2 inline-only + migração `standard_template`.
- **Via B:** `Maint::BWB::AppleTemplateMigrate` com validação textual determinística.
- **Via C:** [`Core.Agent.BWBWorkMap.js`](../../otobo/var/httpd/htdocs/js/Core.Agent.BWBWorkMap.js) event-driven, sem polling; só iframes com `.BWBWorkLocation`.

## Resultado migração histórica (2026-08-28)

| Métrica | Valor |
|---|---|
| Candidatos | 33 |
| Migrados | 33 |
| Erros validação textual | 0 |
| 2.ª execução (--dry-run) | 0 alterações, 33 skipped (`already_migrated`) |

**Ticket 485 — bytes HTML após migração:**

| Artigo | Antes | Depois | `apple-style-body` | `bwb-answer-card` |
|---|---|---|---|---|
| 1464 (normal) | 9804 | 9804 | — | — |
| 1437 | 20829 | 3587 | 0 | 1 |
| 1503 | 31849 | 14327 | 0 | 1 |
| 1541 | 35884 | 18239 | 0 | 1 |

Backups: `/root/otobo-backups/standard_template-before-mod-apple-01-v2-20260828.sql`, `/root/otobo-backups/article-mime-before-apple-v2-20260828.sql` (499M).
