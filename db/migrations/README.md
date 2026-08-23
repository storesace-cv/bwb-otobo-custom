# Migrações

Não alterar `current-schema.sql` manualmente para representar uma mudança nova. Para cada alteração de estrutura, criar uma migração numerada neste diretório, por exemplo `001-adicionar-campo.sql`, com instruções de reversão no comentário inicial.

Artigos FAQ (Ajuda): editar o HTML em `db/faq-content/`, regenerar SQL com `python3 scripts/apply-faq-manuals.py` e aplicar a migração `2026-08-22-faq-manuais-gps-calendario.sql` (ver `docs/OPERATIONS.md`).

As migrações de produção requerem cópia de segurança e revisão humana antes da execução.
