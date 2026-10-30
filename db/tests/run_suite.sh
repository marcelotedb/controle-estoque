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

# Devoluções: 01, 02 e 03 (registrar_devolucao está em 03_operacoes.sql).
reset; aplicar db/01_schema.sql db/02_saldos.sql db/03_operacoes.sql
psql "$DB" -v ON_ERROR_STOP=1 -q -f db/tests/04_devolucao_test.sql >/dev/null

# Regularização de pendência: 01, 02 e 03 (inclui a ALTER TABLE da Task 4b).
reset; aplicar db/01_schema.sql db/02_saldos.sql db/03_operacoes.sql
psql "$DB" -v ON_ERROR_STOP=1 -q -f db/tests/04b_regularizacao_test.sql >/dev/null

# RLS: 01, 02, 03, stub local de auth e 04. O stub simula o que o Supabase real já
# fornece (auth.users, auth.uid()) e cria o papel app_user só para o teste rodar
# sem ser superusuário, já que superusuário ignora RLS. O papel nunca é removido
# entre resets: seus privilégios dependem dos objetos da tabela, que já desaparecem
# com o DROP SCHEMA public CASCADE (dropar o papel em si falha, pois ele ainda
# aparece como titular de privilégios até o próximo GRANT recriar tudo).
psql "$DB" -v ON_ERROR_STOP=1 -q -c "DROP SCHEMA IF EXISTS auth CASCADE;" >/dev/null 2>&1
reset; aplicar db/01_schema.sql db/02_saldos.sql db/03_operacoes.sql db/tests/local_auth_stub.sql db/04_permissoes.sql
psql "$DB" -v ON_ERROR_STOP=1 -q -f db/tests/06_rls_test.sql >/dev/null

# Ajustes: 01, 02, 03, stub local de auth, 04 (perfis/eh_dono) e 05.
psql "$DB" -v ON_ERROR_STOP=1 -q -c "DROP SCHEMA IF EXISTS auth CASCADE;" >/dev/null 2>&1
reset; aplicar db/01_schema.sql db/02_saldos.sql db/03_operacoes.sql db/tests/local_auth_stub.sql db/04_permissoes.sql db/05_ajustes.sql
psql "$DB" -v ON_ERROR_STOP=1 -q -f db/tests/05_ajustes_test.sql >/dev/null

# Duplicidade: 01, 02 e 03 (normalizar_nome e as duas funções de verificação estão em 03_operacoes.sql).
reset; aplicar db/01_schema.sql db/02_saldos.sql db/03_operacoes.sql
psql "$DB" -v ON_ERROR_STOP=1 -q -f db/tests/07_duplicata_test.sql >/dev/null

echo "Suite do banco: schema 4/4, saldos 4/4, retirada 6/6, concorrência 1/1, devolução 6/6, regularização 5/5, RLS 5/5, ajustes 4/4, duplicidade 4/4 — todos passam"
