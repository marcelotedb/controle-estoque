#!/usr/bin/env bash
# Executa todos os testes do banco. Cada arquivo de teste roda em um schema limpo,
# com apenas os scripts que ele precisa aplicados antes. Assim um teste não depende
# dos dados deixados por outro.
set -euo pipefail

cd "$(dirname "$0")/../.."
set -a; . ./.env.test; set +a
DB="$SUPABASE_DB_URL"

reset() {
  psql "$DB" -v ON_ERROR_STOP=1 -q -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" >/dev/null 2>&1
}

aplicar() {
  for arquivo in "$@"; do
    psql "$DB" -v ON_ERROR_STOP=1 -q -f "$arquivo" >/dev/null
  done
}

# Schema: só 01.
reset; aplicar db/01_schema.sql
psql "$DB" -v ON_ERROR_STOP=1 -q -f db/tests/01_schema_test.sql >/dev/null

# Saldos: 01 e 02.
reset; aplicar db/01_schema.sql db/02_saldos.sql
psql "$DB" -v ON_ERROR_STOP=1 -q -f db/tests/02_saldos_test.sql >/dev/null

# Operações: 01, 02 e 03.
reset; aplicar db/01_schema.sql db/02_saldos.sql db/03_operacoes.sql
psql "$DB" -v ON_ERROR_STOP=1 -q -f db/tests/03_retirada_test.sql >/dev/null
bash db/tests/03_concorrencia.sh db/03_operacoes.sql >/dev/null

echo "Suite do banco: schema 4/4, saldos 4/4, retirada 6/6, concorrência 1/1 — todos passam"
