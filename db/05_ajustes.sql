-- Ajustes aprovados pelo dono (Task 5).

-- Qualquer usuário registrado pode solicitar um ajuste; ele fica pendente até o dono aprovar.
CREATE OR REPLACE FUNCTION solicitar_ajuste(
  p_item_id     uuid,
  p_quantidade  integer,
  p_motivo      text,
  p_responsavel text
)
RETURNS uuid
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF p_quantidade IS NULL OR p_quantidade = 0 THEN
    RAISE EXCEPTION 'quantidade do ajuste não pode ser zero';
  END IF;

  INSERT INTO movimentacoes (tipo, item_id, quantidade, sinal, responsavel, status)
  VALUES ('ajuste', p_item_id, abs(p_quantidade), sign(p_quantidade)::integer, p_motivo || ' — solicitado por ' || p_responsavel, 'pendente')
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

-- Só o dono aprova. A aprovação é o que faz o ajuste contar no saldo (view filtra por status='concluida').
CREATE OR REPLACE FUNCTION aprovar_ajuste(p_ajuste_id uuid)
RETURNS void
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  r movimentacoes%ROWTYPE;
BEGIN
  IF NOT eh_dono() THEN
    RAISE EXCEPTION 'somente o dono pode aprovar um ajuste';
  END IF;

  SELECT * INTO r FROM movimentacoes WHERE id = p_ajuste_id AND tipo = 'ajuste' FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ajuste não encontrado';
  END IF;

  IF r.status <> 'pendente' THEN
    RAISE EXCEPTION 'ajuste já aprovado';
  END IF;

  UPDATE movimentacoes SET status = 'concluida' WHERE id = p_ajuste_id;
END;
$$;

-- O Supabase concede EXECUTE a "anon" diretamente na criação da função (não por
-- herança de PUBLIC), então revogar só de PUBLIC não bastaria (ver db/04_permissoes.sql).
REVOKE EXECUTE ON FUNCTION solicitar_ajuste(uuid, integer, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION aprovar_ajuste(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION solicitar_ajuste(uuid, integer, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION aprovar_ajuste(uuid) TO authenticated;
