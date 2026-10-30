#!/usr/bin/env bash
# Teste de concorrência de registrar_retirada (Task 3).
# Duas sessões tentam retirar o último item ao mesmo tempo. A sessão A segura a transação
# por alguns segundos; a sessão B deve esperar pela trava e depois ser recusada por saldo.
# Uso: db/tests/03_concorrencia.sh [arquivo_operacoes.sql]
set -euo pipefail

cd "$(dirname "$0")/../.."
set -a; . ./.env.test; set +a

OPERACOES="${1:-db/03_operacoes.sql}"
DB="$SUPABASE_DB_URL"
T_ESPERA=3

psql "$DB" -v ON_ERROR_STOP=1 -q -c "DROP SCHEMA IF EXISTS auth CASCADE;" >/dev/null 2>&1
psql "$DB" -v ON_ERROR_STOP=1 -q -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" >/dev/null 2>&1
psql "$DB" -v ON_ERROR_STOP=1 -q -f db/01_schema.sql >/dev/null
psql "$DB" -v ON_ERROR_STOP=1 -q -f db/02_saldos.sql >/dev/null
psql "$DB" -v ON_ERROR_STOP=1 -q -f "$OPERACOES" >/dev/null
psql "$DB" -v ON_ERROR_STOP=1 -q -f db/tests/local_auth_stub.sql >/dev/null
psql "$DB" -v ON_ERROR_STOP=1 -q -f db/04_permissoes.sql >/dev/null

psql "$DB" -v ON_ERROR_STOP=1 -q >/dev/null <<'SQL'
INSERT INTO locais_uso (nome, tipo) VALUES ('Local concorrencia', 'compartilhado');
INSERT INTO itens (codigo, nome, categoria, localizacao, quantidade_minima)
VALUES ('T-CONC', 'Item concorrente', 'Insumos', 'prateleira C', 0);
INSERT INTO movimentacoes (tipo, item_id, quantidade, responsavel, status)
SELECT 'ajuste', id, 10, 'teste', 'concluida' FROM itens WHERE codigo = 'T-CONC';
-- Autenticação simulada: registrar_retirada exige tem_perfil() (RLS/Task 6).
INSERT INTO auth.users (id) VALUES ('11111111-1111-1111-1111-111111111111');
INSERT INTO perfis (usuario_id, papel) VALUES ('11111111-1111-1111-1111-111111111111', 'operador');
SQL

SAIDA_B="$(mktemp)"
SAIDA_A="$(mktemp)"

# Sessão A: retira as 10 unidades e segura a transação aberta por T_ESPERA segundos.
psql "$DB" -v ON_ERROR_STOP=1 -q >"$SAIDA_A" 2>&1 <<SQL &
SELECT set_config('app.current_user_id', '11111111-1111-1111-1111-111111111111', false);
BEGIN;
SELECT * FROM registrar_retirada(
  (SELECT id FROM itens WHERE codigo = 'T-CONC'), 10, 'XAM',
  (SELECT id FROM locais_uso WHERE nome = 'Local concorrencia'), 'Sessao A', false);
SELECT pg_sleep($T_ESPERA);
COMMIT;
SQL
PID_A=$!

# Sessão B: começa depois que A já pegou a trava, e tenta retirar 5.
sleep 1
set +e
psql "$DB" -v ON_ERROR_STOP=1 -q >"$SAIDA_B" 2>&1 <<'SQL'
SELECT set_config('app.current_user_id', '11111111-1111-1111-1111-111111111111', false);
SELECT * FROM registrar_retirada(
  (SELECT id FROM itens WHERE codigo = 'T-CONC'), 5, 'XAM',
  (SELECT id FROM locais_uso WHERE nome = 'Local concorrencia'), 'Sessao B', false);
SQL
RC_B=$?
set -e
wait "$PID_A"

SALDO="$(psql "$DB" -At -c "SELECT saldo_disponivel FROM saldos_itens WHERE codigo = 'T-CONC';")"

fail() { echo "FALHA: $1"; cat "$SAIDA_A" "$SAIDA_B"; exit 1; }

if [ "$RC_B" -eq 0 ]; then
  fail "sessão B foi aceita, mas o saldo era 10 e A já retirou 10"
fi
grep -q "saldo insuficiente" "$SAIDA_B" || fail "sessão B recusada por outro motivo"
[ "$SALDO" = "0" ] || fail "saldo final esperado 0, obtido $SALDO"

rm -f "$SAIDA_A" "$SAIDA_B"
echo "Teste de concorrência: 1/1 pass (B recusada por saldo; saldo final 0)"
