-- Testes de RLS (Task 6). Roda como app_user (não-superusuário, sem BYPASSRLS),
-- com auth.uid() simulado via app.current_user_id. Fixture criada como superusuário.

INSERT INTO auth.users DEFAULT VALUES; -- operador
INSERT INTO auth.users DEFAULT VALUES; -- dono
INSERT INTO auth.users DEFAULT VALUES; -- sem perfil

DO $$
DECLARE v_op uuid; v_dono uuid; v_sem uuid;
BEGIN
  SELECT id INTO v_op   FROM auth.users OFFSET 0 LIMIT 1;
  SELECT id INTO v_dono FROM auth.users OFFSET 1 LIMIT 1;
  SELECT id INTO v_sem  FROM auth.users OFFSET 2 LIMIT 1;

  INSERT INTO perfis (usuario_id, papel) VALUES (v_op, 'operador'), (v_dono, 'dono');

  INSERT INTO itens (codigo, nome, categoria, localizacao, quantidade_minima)
  VALUES ('T-RLS', 'Item de RLS', 'Peças', 'prateleira RLS', 0);

  CREATE TEMP TABLE ctx6 (op uuid, dono uuid, sem_perfil uuid, item_id uuid, ajuste_id uuid);
  INSERT INTO ctx6
  SELECT v_op, v_dono, v_sem, i.id, NULL FROM itens i WHERE i.codigo = 'T-RLS';

  INSERT INTO movimentacoes (tipo, item_id, quantidade, responsavel, status)
  SELECT 'ajuste', item_id, 5, 'teste', 'pendente' FROM ctx6
  RETURNING id INTO v_op; -- reaproveita a variável só para capturar o id
  UPDATE ctx6 SET ajuste_id = v_op;
END $$;

GRANT SELECT ON ctx6 TO app_user;

-- 1. Operador consegue inserir em itens e em movimentacoes.
DO $$
DECLARE v_uid uuid;
BEGIN
  SELECT op INTO v_uid FROM ctx6;
  SET ROLE app_user;
  PERFORM set_config('app.current_user_id', v_uid::text, false);

  INSERT INTO itens (codigo, nome, categoria, localizacao, quantidade_minima)
  VALUES ('T-RLS-OP', 'Item criado por operador', 'Insumos', 'x', 0);

  INSERT INTO movimentacoes (tipo, item_id, quantidade, responsavel, status)
  SELECT 'ajuste', item_id, 1, 'teste', 'pendente' FROM ctx6;

  RESET ROLE;
  IF NOT EXISTS (SELECT 1 FROM itens WHERE codigo = 'T-RLS-OP') THEN
    RAISE EXCEPTION 'esperado que o operador conseguisse inserir em itens';
  END IF;
END $$;

-- 2. Operador não consegue fazer update direto em movimentacoes (pendente -> concluída).
DO $$
DECLARE v_uid uuid; v_ajuste uuid; v_status text;
BEGIN
  SELECT op, ajuste_id INTO v_uid, v_ajuste FROM ctx6;
  SET ROLE app_user;
  PERFORM set_config('app.current_user_id', v_uid::text, false);

  UPDATE movimentacoes SET status = 'concluida' WHERE id = v_ajuste;

  RESET ROLE;
  SELECT status INTO v_status FROM movimentacoes WHERE id = v_ajuste;
  IF v_status <> 'pendente' THEN
    RAISE EXCEPTION 'esperado que o update do operador não tivesse efeito, status ficou %', v_status;
  END IF;
END $$;

-- 3. Operador não consegue deletar movimentações.
DO $$
DECLARE v_uid uuid; v_ajuste uuid;
BEGIN
  SELECT op, ajuste_id INTO v_uid, v_ajuste FROM ctx6;
  SET ROLE app_user;
  PERFORM set_config('app.current_user_id', v_uid::text, false);

  DELETE FROM movimentacoes WHERE id = v_ajuste;

  RESET ROLE;
  IF NOT EXISTS (SELECT 1 FROM movimentacoes WHERE id = v_ajuste) THEN
    RAISE EXCEPTION 'esperado que o delete do operador não tivesse efeito, mas a linha desapareceu';
  END IF;
END $$;

-- 4. Dono consegue aprovar (update direto de pendente para concluída).
DO $$
DECLARE v_uid uuid; v_ajuste uuid; v_status text;
BEGIN
  SELECT dono, ajuste_id INTO v_uid, v_ajuste FROM ctx6;
  SET ROLE app_user;
  PERFORM set_config('app.current_user_id', v_uid::text, false);

  UPDATE movimentacoes SET status = 'concluida' WHERE id = v_ajuste;

  RESET ROLE;
  SELECT status INTO v_status FROM movimentacoes WHERE id = v_ajuste;
  IF v_status <> 'concluida' THEN
    RAISE EXCEPTION 'esperado que o dono conseguisse aprovar, status ficou %', v_status;
  END IF;
END $$;

-- 5. Usuário sem linha em perfis não lê nenhuma tabela.
DO $$
DECLARE v_uid uuid; v_qtd integer;
BEGIN
  SELECT sem_perfil INTO v_uid FROM ctx6;
  SET ROLE app_user;
  PERFORM set_config('app.current_user_id', v_uid::text, false);

  SELECT count(*) INTO v_qtd FROM itens;

  RESET ROLE;
  IF v_qtd <> 0 THEN
    RAISE EXCEPTION 'esperado 0 itens visíveis para usuário sem perfil, obtido %', v_qtd;
  END IF;
END $$;
