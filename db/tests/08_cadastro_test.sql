-- Testes de cadastro de item e local de uso (Task 10 — lacuna encontrada: o
-- schema (Task 1) nunca gerou o código do item, exigido pela especificação
-- seção 3 ("codigo: identificador único, gerado pelo sistema").
\set ON_ERROR_STOP on

DO $$
DECLARE
  v_codigo text;
BEGIN
  v_codigo := registrar_item('Parafuso 6mm', 'Peças', 'prateleira 1', 5);
  IF v_codigo IS NULL OR v_codigo = '' THEN
    RAISE EXCEPTION 'esperado código gerado, obtido %', v_codigo;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM itens WHERE codigo = v_codigo AND nome = 'Parafuso 6mm') THEN
    RAISE EXCEPTION 'item não foi inserido com o código gerado';
  END IF;
END $$;

DO $$
DECLARE
  v1 text;
  v2 text;
BEGIN
  v1 := registrar_item('Item A', 'Insumos', NULL, 0);
  v2 := registrar_item('Item B', 'Insumos', NULL, 0);
  IF v1 = v2 THEN
    RAISE EXCEPTION 'esperado códigos diferentes para itens diferentes, ambos %', v1;
  END IF;
END $$;

DO $$
BEGIN
  BEGIN
    PERFORM registrar_item('Item inválido', 'Lixo', NULL, 0);
    RAISE EXCEPTION 'esperava falha com categoria inválida';
  EXCEPTION WHEN check_violation THEN
    NULL; -- esperado
  END;
END $$;

DO $$
DECLARE
  v_id    uuid;
  v_local locais_uso%ROWTYPE;
BEGIN
  v_id := registrar_local_uso('Loja de teste', 'compartilhado', NULL);
  SELECT * INTO v_local FROM locais_uso WHERE id = v_id;
  IF v_local.tipo <> 'compartilhado' OR v_local.unidade_id IS NOT NULL THEN
    RAISE EXCEPTION 'local compartilhado inserido incorretamente';
  END IF;
END $$;

DO $$
DECLARE
  v_id    uuid;
  v_local locais_uso%ROWTYPE;
BEGIN
  v_id := registrar_local_uso('Eldorado de teste', 'exclusivo', 'SAGA');
  SELECT * INTO v_local FROM locais_uso WHERE id = v_id;
  IF v_local.tipo <> 'exclusivo' OR v_local.unidade_id IS NULL THEN
    RAISE EXCEPTION 'local exclusivo inserido incorretamente';
  END IF;
END $$;

DO $$
BEGIN
  BEGIN
    PERFORM registrar_local_uso('Sem unidade', 'exclusivo', NULL);
    RAISE EXCEPTION 'esperava falha ao registrar local exclusivo sem unidade';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%unidade%' THEN
      RAISE;
    END IF;
  END;
END $$;

\echo 'Task 10 (db) cadastro tests: 6/6 pass'
