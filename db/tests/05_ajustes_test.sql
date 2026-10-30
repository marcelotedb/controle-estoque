-- Testes de solicitar_ajuste e aprovar_ajuste (Task 5). Usa o stub local de auth
-- (auth.users, auth.uid()) para simular dono e operador; não precisa de app_user
-- porque estas funções checam eh_dono() internamente, não dependem de RLS para o teste.

INSERT INTO auth.users DEFAULT VALUES;
INSERT INTO auth.users DEFAULT VALUES;

DO $$
DECLARE v_dono uuid; v_op uuid; v_item uuid;
BEGIN
  SELECT id INTO v_dono FROM auth.users OFFSET 0 LIMIT 1;
  SELECT id INTO v_op   FROM auth.users OFFSET 1 LIMIT 1;
  INSERT INTO perfis (usuario_id, papel) VALUES (v_dono, 'dono'), (v_op, 'operador');

  INSERT INTO itens (codigo, nome, categoria, localizacao, quantidade_minima)
  VALUES ('T-AJU', 'Item de ajuste', 'Revenda', 'prateleira A', 0)
  RETURNING id INTO v_item;

  CREATE TEMP TABLE ctx5 (dono uuid, operador uuid, item_id uuid);
  INSERT INTO ctx5 VALUES (v_dono, v_op, v_item);
END $$;

-- 1. solicitar_ajuste cria movimentação pendente e não altera o saldo disponível.
DO $$
DECLARE v_item uuid; v_ajuste_id uuid; v_status text; v_disp integer;
BEGIN
  SELECT item_id INTO v_item FROM ctx5;
  v_ajuste_id := solicitar_ajuste(v_item, 10, 'contagem inicial', 'Marcelo');

  SELECT status INTO v_status FROM movimentacoes WHERE id = v_ajuste_id;
  IF v_status <> 'pendente' THEN
    RAISE EXCEPTION 'esperado status pendente, obtido %', v_status;
  END IF;

  SELECT saldo_disponivel INTO v_disp FROM saldos_itens WHERE item_id = v_item;
  IF v_disp <> 0 THEN
    RAISE EXCEPTION 'esperado saldo disponível 0 enquanto o ajuste está pendente, obtido %', v_disp;
  END IF;

  CREATE TEMP TABLE ctx5_ajuste (id uuid);
  INSERT INTO ctx5_ajuste VALUES (v_ajuste_id);
END $$;

-- 2. aprovar_ajuste feito por não-dono deve ser recusado.
DO $$
DECLARE v_ajuste uuid;
BEGIN
  SELECT id INTO v_ajuste FROM ctx5_ajuste;
  PERFORM set_config('app.current_user_id', (SELECT operador::text FROM ctx5), false);
  BEGIN
    PERFORM aprovar_ajuste(v_ajuste);
    RAISE EXCEPTION 'esperado erro de permissão, mas o ajuste foi aprovado';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%somente o dono pode aprovar%' THEN RAISE; END IF;
  END;
END $$;

-- 3. aprovar_ajuste feito pelo dono muda o status e o saldo passa a refletir o ajuste.
DO $$
DECLARE v_ajuste uuid; v_item uuid; v_disp integer;
BEGIN
  SELECT id INTO v_ajuste FROM ctx5_ajuste;
  SELECT item_id INTO v_item FROM ctx5;
  PERFORM set_config('app.current_user_id', (SELECT dono::text FROM ctx5), false);

  PERFORM aprovar_ajuste(v_ajuste);

  IF (SELECT status FROM movimentacoes WHERE id = v_ajuste) <> 'concluida' THEN
    RAISE EXCEPTION 'esperado status concluída após aprovação do dono';
  END IF;

  SELECT saldo_disponivel INTO v_disp FROM saldos_itens WHERE item_id = v_item;
  IF v_disp <> 10 THEN
    RAISE EXCEPTION 'esperado saldo disponível 10 após aprovação, obtido %', v_disp;
  END IF;
END $$;

-- 4. Aprovar o mesmo ajuste de novo deve ser recusado como "já aprovado".
DO $$
DECLARE v_ajuste uuid;
BEGIN
  SELECT id INTO v_ajuste FROM ctx5_ajuste;
  PERFORM set_config('app.current_user_id', (SELECT dono::text FROM ctx5), false);
  BEGIN
    PERFORM aprovar_ajuste(v_ajuste);
    RAISE EXCEPTION 'esperado erro de já aprovado, mas foi aceito de novo';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%já aprovado%' THEN RAISE; END IF;
  END;
END $$;
