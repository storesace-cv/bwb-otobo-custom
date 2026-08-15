# Migrações

Não alterar `current-schema.sql` manualmente para representar uma mudança nova. Para cada alteração de estrutura, criar uma migração numerada neste diretório, por exemplo `001-adicionar-campo.sql`, com instruções de reversão no comentário inicial.

As migrações de produção requerem cópia de segurança e revisão humana antes da execução.
