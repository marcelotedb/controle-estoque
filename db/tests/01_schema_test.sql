-- Testes do schema (Task 1). Cada bloco falha com RAISE EXCEPTION se o comportamento estiver errado.

-- Categoria fora da lista fixa deve ser recusada.
DO $$
BEGIN
  BEGIN
    INSERT INTO itens (codigo, nome, categoria, localizacao, quantidade_minima)
    VALUES ('T-CAT', 'Teste categoria', 'Lixo', 'x', 1);
    RAISE EXCEPTION 'esperado erro de check: categoria Lixo foi aceita';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;
END $$;

-- Local exclusivo sem unidade deve ser recusado.
DO $$
BEGIN
  BEGIN
    INSERT INTO locais_uso (nome, tipo, unidade_id)
    VALUES ('Loja teste', 'exclusivo', NULL);
    RAISE EXCEPTION 'esperado erro de check: exclusivo sem unidade foi aceito';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;
END $$;

-- Local compartilhado com unidade preenchida deve ser recusado.
DO $$
DECLARE
  v_xam uuid;
BEGIN
  SELECT id INTO v_xam FROM unidades WHERE codigo = 'XAM';
  BEGIN
    INSERT INTO locais_uso (nome, tipo, unidade_id)
    VALUES ('Local compartilhado teste', 'compartilhado', v_xam);
    RAISE EXCEPTION 'esperado erro de check: compartilhado com unidade foi aceito';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;
END $$;

-- As três unidades fixas devem existir.
DO $$
BEGIN
  IF (SELECT count(*) FROM unidades WHERE codigo IN ('XAM', 'SAGA', 'ARA')) <> 3 THEN
    RAISE EXCEPTION 'esperado 3 unidades (XAM, SAGA, ARA)';
  END IF;
END $$;
