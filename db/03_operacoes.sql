-- Operações de estoque (Tasks 3, 4, 4b e 7).

-- Registrar retirada (Task 3).
-- Retirada pendente (p_pendente = true) é registrada quando o material sai sem poder ser lançado na hora:
-- ela não reduz o disponível até ser regularizada (Task 4b), e por isso não passa pela trava de saldo.
CREATE OR REPLACE FUNCTION registrar_retirada(
  p_item_id                     uuid,
  p_quantidade                  integer,
  p_unidade_codigo              text,
  p_local_uso_id                uuid,
  p_responsavel                 text,
  p_confirmar_unidade_diferente boolean DEFAULT false,
  p_pendente                    boolean DEFAULT false
)
RETURNS TABLE (numero text, aviso text)
LANGUAGE plpgsql
AS $$
DECLARE
  v_saldo      integer;
  v_unidade_id uuid;
  v_local      locais_uso%ROWTYPE;
  v_numero     text;
  v_aviso      text := NULL;
BEGIN
  IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
    RAISE EXCEPTION 'quantidade deve ser maior que zero';
  END IF;

  -- Trava a linha do item: duas retiradas concorrentes passam uma de cada vez.
  PERFORM 1 FROM itens WHERE id = p_item_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'item não encontrado';
  END IF;

  SELECT s.saldo_disponivel INTO v_saldo FROM saldos_itens s WHERE s.item_id = p_item_id;
  IF NOT p_pendente AND v_saldo < p_quantidade THEN
    RAISE EXCEPTION 'saldo insuficiente: disponível %', v_saldo;
  END IF;

  SELECT u.id INTO v_unidade_id FROM unidades u WHERE u.codigo = p_unidade_codigo;
  IF v_unidade_id IS NULL THEN
    RAISE EXCEPTION 'unidade inválida: %', p_unidade_codigo;
  END IF;

  SELECT * INTO v_local FROM locais_uso l WHERE l.id = p_local_uso_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'local de uso não encontrado';
  END IF;

  IF v_local.tipo = 'exclusivo' AND v_local.unidade_id <> v_unidade_id THEN
    IF NOT p_confirmar_unidade_diferente THEN
      RAISE EXCEPTION 'confirmação necessária: local pertence a outra unidade';
    END IF;
    v_aviso := 'local de uso ' || v_local.nome || ' pertence a outra unidade';
  END IF;

  v_numero := 'RET-' || lpad(nextval('seq_ret')::text, 4, '0');

  INSERT INTO movimentacoes (numero, tipo, item_id, quantidade, unidade_id, local_uso_id, responsavel, status)
  VALUES (
    v_numero, 'retirada', p_item_id, p_quantidade, v_unidade_id, p_local_uso_id, p_responsavel,
    CASE WHEN p_pendente THEN 'pendente' ELSE 'concluida' END
  );

  RETURN QUERY SELECT v_numero, v_aviso;
END;
$$;

-- Registrar devolução (Task 4).
-- A devolução é sempre vinculada a uma retirada concluída. Só é possível devolver o que ainda está em uso.
CREATE OR REPLACE FUNCTION registrar_devolucao(
  p_retirada_numero text,
  p_quantidade      integer,
  p_condicao        text,
  p_responsavel     text
)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  r          movimentacoes%ROWTYPE;
  v_em_uso   integer;
  v_numero   text;
BEGIN
  SELECT * INTO r FROM movimentacoes
  WHERE numero = p_retirada_numero AND tipo = 'retirada'
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'retirada não encontrada: %', p_retirada_numero;
  END IF;

  IF r.status <> 'concluida' THEN
    RAISE EXCEPTION 'retirada ainda não regularizada: %', p_retirada_numero;
  END IF;

  IF p_condicao NOT IN ('reuso', 'defeito') THEN
    RAISE EXCEPTION 'condição inválida: %', p_condicao;
  END IF;

  IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
    RAISE EXCEPTION 'quantidade deve ser maior que zero';
  END IF;

  SELECT r.quantidade - coalesce(sum(d.quantidade), 0) INTO v_em_uso
  FROM movimentacoes d
  WHERE d.retirada_origem_id = r.id AND d.tipo = 'devolucao';

  IF v_em_uso <= 0 THEN
    RAISE EXCEPTION 'retirada % já devolvida', p_retirada_numero;
  END IF;

  IF p_quantidade > v_em_uso THEN
    RAISE EXCEPTION 'quantidade excede o saldo em uso (%)', v_em_uso;
  END IF;

  v_numero := 'DEV-' || lpad(nextval('seq_dev')::text, 4, '0');

  INSERT INTO movimentacoes (numero, tipo, item_id, quantidade, retirada_origem_id, condicao, responsavel, status)
  VALUES (v_numero, 'devolucao', r.item_id, p_quantidade, r.id, p_condicao, p_responsavel, 'concluida');

  RETURN v_numero;
END;
$$;

-- Coluna adicional para a regularização de retirada pendente (Task 4b).
ALTER TABLE movimentacoes ADD COLUMN IF NOT EXISTS responsavel_regularizacao text;

-- Regularizar retirada pendente (Task 4b).
-- Confirma que o material que já saiu em emergência ainda cabe no saldo e muda o status para concluída.
CREATE OR REPLACE FUNCTION regularizar_retirada_pendente(
  p_numero                     text,
  p_responsavel_regularizacao  text
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  r        movimentacoes%ROWTYPE;
  v_saldo  integer;
BEGIN
  SELECT * INTO r FROM movimentacoes
  WHERE numero = p_numero AND tipo = 'retirada'
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'retirada não encontrada: %', p_numero;
  END IF;

  IF r.status <> 'pendente' THEN
    RAISE EXCEPTION 'retirada % não está pendente', p_numero;
  END IF;

  SELECT s.saldo_disponivel INTO v_saldo FROM saldos_itens s WHERE s.item_id = r.item_id;
  IF v_saldo < r.quantidade THEN
    RAISE EXCEPTION 'saldo insuficiente: disponível %', v_saldo;
  END IF;

  UPDATE movimentacoes
  SET status = 'concluida', responsavel_regularizacao = p_responsavel_regularizacao
  WHERE id = r.id;
END;
$$;
