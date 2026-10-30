-- Testes de registrar_retirada (Task 3). Cada bloco falha com RAISE EXCEPTION se o comportamento estiver errado.

INSERT INTO locais_uso (nome, tipo) VALUES ('Local compartilhado teste', 'compartilhado');
INSERT INTO locais_uso (nome, tipo, unidade_id)
VALUES ('Loja SAGA teste', 'exclusivo', (SELECT id FROM unidades WHERE codigo = 'SAGA'));

INSERT INTO itens (codigo, nome, categoria, localizacao, quantidade_minima)
VALUES ('T-RET', 'Item de retirada', 'Insumos', 'prateleira R', 0);

INSERT INTO movimentacoes (tipo, item_id, quantidade, responsavel, status)
SELECT 'ajuste', id, 10, 'teste', 'concluida' FROM itens WHERE codigo = 'T-RET';

-- 1. Retirada de 3 com saldo 10 gera RET-0001 e o saldo cai para 7.
DO $$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM registrar_retirada(
    (SELECT id FROM itens WHERE codigo = 'T-RET'), 3, 'XAM',
    (SELECT id FROM locais_uso WHERE nome = 'Local compartilhado teste'), 'Lindomar', false);
  IF r.numero <> 'RET-0001' THEN
    RAISE EXCEPTION 'esperado número RET-0001, obtido %', r.numero;
  END IF;
  IF (SELECT saldo_disponivel FROM saldos_itens WHERE codigo = 'T-RET') <> 7 THEN
    RAISE EXCEPTION 'esperado saldo 7 após retirada de 3';
  END IF;
END $$;

-- 2. Retirada de 8 com saldo 7 deve ser recusada com "saldo insuficiente".
DO $$
BEGIN
  BEGIN
    PERFORM registrar_retirada(
      (SELECT id FROM itens WHERE codigo = 'T-RET'), 8, 'XAM',
      (SELECT id FROM locais_uso WHERE nome = 'Local compartilhado teste'), 'Lindomar', false);
    RAISE EXCEPTION 'esperado erro de saldo insuficiente, mas a retirada foi aceita';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%saldo insuficiente%' THEN RAISE; END IF;
  END;
END $$;

-- 3. Quantidade zero deve ser recusada.
DO $$
BEGIN
  BEGIN
    PERFORM registrar_retirada(
      (SELECT id FROM itens WHERE codigo = 'T-RET'), 0, 'XAM',
      (SELECT id FROM locais_uso WHERE nome = 'Local compartilhado teste'), 'Lindomar', false);
    RAISE EXCEPTION 'esperado erro de quantidade, mas a retirada foi aceita';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%quantidade%' THEN RAISE; END IF;
  END;
END $$;

-- 4. Local exclusivo de SAGA usado com destino XAM, sem confirmação, deve pedir confirmação.
DO $$
BEGIN
  BEGIN
    PERFORM registrar_retirada(
      (SELECT id FROM itens WHERE codigo = 'T-RET'), 1, 'XAM',
      (SELECT id FROM locais_uso WHERE nome = 'Loja SAGA teste'), 'Lindomar', false);
    RAISE EXCEPTION 'esperado pedido de confirmação, mas a retirada foi aceita';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%confirmação necessária%' THEN RAISE; END IF;
  END;
END $$;

-- 5. O mesmo caso com confirmação registra e devolve aviso preenchido.
DO $$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM registrar_retirada(
    (SELECT id FROM itens WHERE codigo = 'T-RET'), 1, 'XAM',
    (SELECT id FROM locais_uso WHERE nome = 'Loja SAGA teste'), 'Lindomar', true);
  IF r.aviso IS NULL THEN
    RAISE EXCEPTION 'esperado aviso preenchido para local exclusivo de outra unidade';
  END IF;
END $$;

-- 6. Local compartilhado em qualquer unidade registra sem aviso.
DO $$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM registrar_retirada(
    (SELECT id FROM itens WHERE codigo = 'T-RET'), 1, 'SAGA',
    (SELECT id FROM locais_uso WHERE nome = 'Local compartilhado teste'), 'Lindomar', false);
  IF r.aviso IS NOT NULL THEN
    RAISE EXCEPTION 'esperado aviso nulo para local compartilhado';
  END IF;
END $$;
