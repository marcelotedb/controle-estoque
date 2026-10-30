-- Exportação semanal (Task 11): três arquivos CSV com cabeçalho — itens,
-- movimentações da última semana (incluindo pendências) e saldos atuais.
--
-- Uso (pasta atual):
--   psql "$SUPABASE_DB_URL" -f scripts/exportar_semana.sql
-- Uso (pasta escolhida):
--   psql "$SUPABASE_DB_URL" \
--     -v itens_csv=/caminho/itens.csv \
--     -v movimentacoes_csv=/caminho/movimentacoes.csv \
--     -v saldos_csv=/caminho/saldos.csv \
--     -f scripts/exportar_semana.sql

\if :{?itens_csv}
\else
  \set itens_csv ./itens.csv
\endif

\if :{?movimentacoes_csv}
\else
  \set movimentacoes_csv ./movimentacoes.csv
\endif

\if :{?saldos_csv}
\else
  \set saldos_csv ./saldos.csv
\endif

\o :itens_csv
\copy (SELECT codigo, nome, categoria, localizacao, quantidade_minima, criado_em FROM itens ORDER BY codigo) TO STDOUT CSV HEADER
\o

\o :movimentacoes_csv
\copy (SELECT numero, tipo, item_id, quantidade, unidade_id, local_uso_id, responsavel, data_hora, retirada_origem_id, condicao, status FROM movimentacoes WHERE data_hora >= now() - interval '7 days' ORDER BY data_hora) TO STDOUT CSV HEADER
\o

\o :saldos_csv
\copy (SELECT codigo, nome, categoria, localizacao, saldo_disponivel, saldo_em_uso, saldo_pendente, quantidade_minima, em_alerta FROM saldos_itens ORDER BY codigo) TO STDOUT CSV HEADER
\o
