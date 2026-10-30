-- Testes de verificar_duplicata_item e verificar_duplicata_local (Task 7).

INSERT INTO itens (codigo, nome, categoria, localizacao, quantidade_minima)
VALUES
  ('T-DUP1', 'Parafuso 6mm', 'Peças', 'x', 0),
  ('T-DUP2', 'Conector Azul', 'Peças', 'x', 0);

INSERT INTO locais_uso (nome, tipo) VALUES ('Eldorado', 'compartilhado');

-- 1. "parafuso 6 mm" encontra "Parafuso 6mm".
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM verificar_duplicata_item('parafuso 6 mm') WHERE codigo = 'T-DUP1') THEN
    RAISE EXCEPTION 'esperado que "parafuso 6 mm" encontrasse "Parafuso 6mm"';
  END IF;
END $$;

-- 2. "PARAFUSO 6MM" (maiúsculas, sem espaço) também encontra.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM verificar_duplicata_item('PARAFUSO 6MM') WHERE codigo = 'T-DUP1') THEN
    RAISE EXCEPTION 'esperado que "PARAFUSO 6MM" encontrasse "Parafuso 6mm"';
  END IF;
END $$;

-- 3. "Cabo de rede" não encontra "Conector Azul" (nomes não parecidos).
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM verificar_duplicata_item('Cabo de rede') WHERE codigo = 'T-DUP2') THEN
    RAISE EXCEPTION 'esperado que "Cabo de rede" não encontrasse "Conector Azul"';
  END IF;
END $$;

-- 4. "El Dorado" encontra o local "Eldorado".
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM verificar_duplicata_local('El Dorado') WHERE nome = 'Eldorado') THEN
    RAISE EXCEPTION 'esperado que "El Dorado" encontrasse o local "Eldorado"';
  END IF;
END $$;
