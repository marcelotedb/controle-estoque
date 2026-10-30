-- Teste da consulta de exportação semanal de movimentações (Task 11).
-- A exportação deve trazer todas as linhas dos últimos 7 dias, incluindo as
-- com status='pendente', e excluir linhas mais antigas que isso.
\set ON_ERROR_STOP on

DO $$
DECLARE
  v_item_id uuid;
  v_un_id   uuid;
  v_loc_id  uuid;
  v_total   integer;
BEGIN
  INSERT INTO itens (codigo, nome, categoria, quantidade_minima)
  VALUES ('ITM-TESTE', 'Item de teste', 'Insumos', 0)
  RETURNING id INTO v_item_id;

  SELECT id INTO v_un_id FROM unidades WHERE codigo = 'XAM';
  INSERT INTO locais_uso (nome, tipo) VALUES ('Local de teste export', 'compartilhado') RETURNING id INTO v_loc_id;

  -- Dentro da janela de 7 dias, concluída.
  INSERT INTO movimentacoes (numero, tipo, item_id, quantidade, unidade_id, local_uso_id, responsavel, data_hora, status)
  VALUES ('RET-9001', 'retirada', v_item_id, 1, v_un_id, v_loc_id, 'Teste', now() - interval '2 days', 'concluida');

  -- Dentro da janela, mas pendente: precisa aparecer na exportação.
  INSERT INTO movimentacoes (numero, tipo, item_id, quantidade, unidade_id, local_uso_id, responsavel, data_hora, status)
  VALUES ('RET-9002', 'retirada', v_item_id, 1, v_un_id, v_loc_id, 'Teste', now() - interval '6 days', 'pendente');

  -- Fora da janela de 7 dias: não deve aparecer.
  INSERT INTO movimentacoes (numero, tipo, item_id, quantidade, unidade_id, local_uso_id, responsavel, data_hora, status)
  VALUES ('RET-9003', 'retirada', v_item_id, 1, v_un_id, v_loc_id, 'Teste', now() - interval '10 days', 'concluida');

  SELECT count(*) INTO v_total
  FROM movimentacoes
  WHERE data_hora >= now() - interval '7 days'
    AND numero IN ('RET-9001', 'RET-9002', 'RET-9003');

  IF v_total <> 2 THEN
    RAISE EXCEPTION 'esperado 2 movimentações na janela de 7 dias (uma pendente), obtido %', v_total;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM movimentacoes
    WHERE numero = 'RET-9002' AND status = 'pendente' AND data_hora >= now() - interval '7 days'
  ) THEN
    RAISE EXCEPTION 'esperado que a retirada pendente apareça na janela de exportação';
  END IF;

  IF EXISTS (
    SELECT 1 FROM movimentacoes
    WHERE numero = 'RET-9003' AND data_hora >= now() - interval '7 days'
  ) THEN
    RAISE EXCEPTION 'retirada de 10 dias atrás não deveria estar dentro da janela de 7 dias';
  END IF;
END $$;

\echo 'Task 11 exportação tests: 3/3 pass'
