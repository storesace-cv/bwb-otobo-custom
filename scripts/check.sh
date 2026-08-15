#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if grep -RInE 'BEGIN (OPENSSH|RSA|EC|DSA) PRIVATE KEY' --exclude-dir=.git "$ROOT"; then
    echo "Chave privada encontrada. Remova-a antes de continuar." >&2
    exit 1
fi

if [[ -n "${OTOBO_HOME:-}" ]]; then
    find "$ROOT/otobo/Custom/Kernel" -name '*.pm' -print0 | while IFS= read -r -d '' file; do
        perl -I"$OTOBO_HOME" -I"$OTOBO_HOME/Kernel/cpan-lib" -c "$file" >/dev/null
    done
else
    echo "Validação Perl ignorada: defina OTOBO_HOME numa instalação OTOBO."
fi

echo "Verificação local concluída."
