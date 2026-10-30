-- Testes da view saldos_itens (Task 2). Fixture inserida direto nas tabelas.

INSERT INTO locais_uso (nome, tipo) VALUES ('Local compartilhado teste', 'compartilhado');

INSERT INTO itens (codigo, nome, categoria, localizacao, quantidade_minima)
VALUES ('T-SAL', 'Item de saldo', 'Peças', 'prateleira T', 0);

-- Entrada inicial de 10 via ajuste concluído (Task 5 cria o fluxo real).
INSERT INTO movimentacoes (tipo, item_id, quantidade, responsavel, status)
SELECT 'ajuste', id, 10, 'teste', 'concluida' FROM itens WHERE codigo = 'T-SAL';

-- Retirada de 4 para uma unidade e local compartilhado.
INSERT INTO movimentacoes (numero, tipo, item_id, quantidade, unidade_id, local_uso_id, responsavel, status)
SELECT 'RET-T1', 'retirada', i.id, 4,
       (SELECT id FROM unidades WHERE codigo = 'XAM'),
       (SELECT id FROM locais_uso WHERE nome = 'Local compartilhado teste'),
       'teste', 'concluida'
FROM itens i WHERE i.codigo = 'T-SAL';

-- Verificação 1: após retirar 4, disponível 6 e em uso 4.
DO $$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM saldos_itens WHERE codigo = 'T-SAL';
  IF r.saldo_disponivel <> 6 OR r.saldo_em_uso <> 4 THEN
    RAISE EXCEPTION 'após retirada de 4: esperado disponível 6 e em uso 4, obtido % e %', r.saldo_disponivel, r.saldo_em_uso;
  END IF;
END $$;

-- Devolução de 3 em reuso, vinculada à retirada RET-T1.
INSERT INTO movimentacoes (tipo, item_id, quantidade, responsavel, retirada_origem_id, condicao, status)
SELECT 'devolucao', i.id, 3, 'teste',
       (SELECT id FROM movimentacoes WHERE numero = 'RET-T1'), 'reuso', 'concluida'
FROM itens i WHERE i.codigo = 'T-SAL';

-- Verificação 2: após devolver 3 em reuso, disponível 9 e em uso 1.
DO $$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM saldos_itens WHERE codigo = 'T-SAL';
  IF r.saldo_disponivel <> 9 OR r.saldo_em_uso <> 1 THEN
    RAISE EXCEPTION 'após devolução reuso de 3: esperado disponível 9 e em uso 1, obtido % e %', r.saldo_disponivel, r.saldo_em_uso;
  END IF;
END $$;

-- Devolução de 1 com defeito, vinculada à mesma retirada.
INSERT INTO movimentacoes (tipo, item_id, quantidade, responsavel, retirada_origem_id, condicao, status)
SELECT 'devolucao', i.id, 1, 'teste',
       (SELECT id FROM movimentacoes WHERE numero = 'RET-T1'), 'defeito', 'concluida'
FROM itens i WHERE i.codigo = 'T-SAL';

-- Verificação 3: após devolver 1 com defeito, disponível 9, em uso 0 e pendente 1.
DO $$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM saldos_itens WHERE codigo = 'T-SAL';
  IF r.saldo_disponivel <> 9 OR r.saldo_em_uso <> 0 OR r.saldo_pendente <> 1 THEN
    RAISE EXCEPTION 'após defeito de 1: esperado disponível 9, em uso 0, pendente 1, obtido % / % / %',
      r.saldo_disponivel, r.saldo_em_uso, r.saldo_pendente;
  END IF;
END $$;

-- Verificação 4: com mínimo 9 e disponível 9, o item entra em alerta.
UPDATE itens SET quantidade_minima = 9 WHERE codigo = 'T-SAL';

DO $$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM saldos_itens WHERE codigo = 'T-SAL';
  IF r.em_alerta IS NOT TRUE THEN
    RAISE EXCEPTION 'esperado em_alerta = true com disponível 9 e mínimo 9';
  END IF;
END $$;
