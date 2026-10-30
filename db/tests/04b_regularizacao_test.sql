-- Testes de regularizar_retirada_pendente (Task 4b).

INSERT INTO locais_uso (nome, tipo) VALUES ('Local pendencia teste', 'compartilhado');

INSERT INTO itens (codigo, nome, categoria, localizacao, quantidade_minima)
VALUES ('T-PEN', 'Item de pendencia', 'Insumos', 'prateleira P', 0);

INSERT INTO movimentacoes (tipo, item_id, quantidade, responsavel, status)
SELECT 'ajuste', id, 10, 'teste', 'concluida' FROM itens WHERE codigo = 'T-PEN';

CREATE TEMP TABLE ctx4b (pendente text);
INSERT INTO ctx4b
SELECT r.numero FROM registrar_retirada(
  (SELECT id FROM itens WHERE codigo = 'T-PEN'), 4, 'XAM',
  (SELECT id FROM locais_uso WHERE nome = 'Local pendencia teste'), 'Lindomar', false, true) r;

-- 1. Antes de regularizar, a retirada pendente não reduz o disponível, só aparece no pendente.
DO $$
DECLARE s record;
BEGIN
  SELECT * INTO s FROM saldos_itens WHERE codigo = 'T-PEN';
  IF s.saldo_disponivel <> 10 OR s.saldo_pendente <> 4 OR s.saldo_em_uso <> 0 THEN
    RAISE EXCEPTION 'antes de regularizar: esperado disponível 10, pendente 4, em uso 0, obtido %/%/%',
      s.saldo_disponivel, s.saldo_pendente, s.saldo_em_uso;
  END IF;
END $$;

-- 2. Regularizar muda o status para concluída e passa a contar no saldo em uso.
DO $$
DECLARE v_num text; s record;
BEGIN
  SELECT pendente INTO v_num FROM ctx4b;
  PERFORM regularizar_retirada_pendente(v_num, 'Marcelo');
  SELECT * INTO s FROM saldos_itens WHERE codigo = 'T-PEN';
  IF s.saldo_disponivel <> 6 OR s.saldo_em_uso <> 4 OR s.saldo_pendente <> 0 THEN
    RAISE EXCEPTION 'após regularizar: esperado disponível 6, em uso 4, pendente 0, obtido %/%/%',
      s.saldo_disponivel, s.saldo_em_uso, s.saldo_pendente;
  END IF;
END $$;

-- 3. Regularizar uma retirada já concluída deve dizer "não está pendente".
DO $$
DECLARE v_num text;
BEGIN
  SELECT pendente INTO v_num FROM ctx4b;
  BEGIN
    PERFORM regularizar_retirada_pendente(v_num, 'Marcelo');
    RAISE EXCEPTION 'esperado erro de não pendente, mas foi aceita';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%não está pendente%' THEN RAISE; END IF;
  END;
END $$;

-- 4. Regularizar número inexistente deve dizer "retirada não encontrada".
DO $$
BEGIN
  BEGIN
    PERFORM regularizar_retirada_pendente('RET-9999', 'Marcelo');
    RAISE EXCEPTION 'esperado erro de retirada inexistente, mas foi aceita';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%retirada não encontrada%' THEN RAISE; END IF;
  END;
END $$;

-- 5. Retirada pendente maior que o disponível atual deve ser recusada e permanecer pendente.
DO $$
DECLARE v_num text;
BEGIN
  SELECT x.numero INTO v_num FROM registrar_retirada(
    (SELECT id FROM itens WHERE codigo = 'T-PEN'), 7, 'XAM',
    (SELECT id FROM locais_uso WHERE nome = 'Local pendencia teste'), 'Lindomar', false, true) x;
  -- disponível atual é 6; pedir regularização de 7 deve falhar.
  BEGIN
    PERFORM regularizar_retirada_pendente(v_num, 'Marcelo');
    RAISE EXCEPTION 'esperado erro de saldo insuficiente, mas foi aceita';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%saldo insuficiente%' THEN RAISE; END IF;
  END;
  IF (SELECT status FROM movimentacoes WHERE numero = v_num) <> 'pendente' THEN
    RAISE EXCEPTION 'esperado status ainda pendente após falha de regularização';
  END IF;
END $$;
