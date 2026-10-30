-- Testes de registrar_devolucao (Task 4). Cada bloco falha com RAISE EXCEPTION se o comportamento estiver errado.

INSERT INTO locais_uso (nome, tipo) VALUES ('Local devolucao teste', 'compartilhado');

INSERT INTO itens (codigo, nome, categoria, localizacao, quantidade_minima)
VALUES ('T-DEV', 'Item de devolucao', 'Peças', 'prateleira D', 0);

INSERT INTO movimentacoes (tipo, item_id, quantidade, responsavel, status)
SELECT 'ajuste', id, 10, 'teste', 'concluida' FROM itens WHERE codigo = 'T-DEV';

-- Autenticação simulada: registrar_retirada/registrar_devolucao exigem tem_perfil() (RLS/Task 6).
INSERT INTO auth.users (id) VALUES ('11111111-1111-1111-1111-111111111111');
INSERT INTO perfis (usuario_id, papel) VALUES ('11111111-1111-1111-1111-111111111111', 'operador');
SELECT set_config('app.current_user_id', '11111111-1111-1111-1111-111111111111', false);

-- Retirada de 5 para usar nos casos abaixo (o número é guardado, não assumido).
CREATE TEMP TABLE ctx (retirada text, pendente text);
INSERT INTO ctx
SELECT r.numero, NULL FROM registrar_retirada(
  (SELECT id FROM itens WHERE codigo = 'T-DEV'), 5, 'XAM',
  (SELECT id FROM locais_uso WHERE nome = 'Local devolucao teste'), 'Lindomar', false) r;

-- 1. Devolução de 2 em reuso gera DEV-0001 e deixa 3 em uso.
DO $$
DECLARE v_num text; v_ret text;
BEGIN
  SELECT retirada INTO v_ret FROM ctx;
  v_num := registrar_devolucao(v_ret, 2, 'reuso', 'Lindomar');
  IF v_num <> 'DEV-0001' THEN
    RAISE EXCEPTION 'esperado DEV-0001, obtido %', v_num;
  END IF;
  IF (SELECT saldo_em_uso FROM saldos_itens WHERE codigo = 'T-DEV') <> 3 THEN
    RAISE EXCEPTION 'esperado 3 em uso após devolver 2 de 5';
  END IF;
END $$;

-- 2. Devolver 4 quando restam 3 em uso deve ser recusado com "excede o saldo em uso".
DO $$
DECLARE v_ret text;
BEGIN
  SELECT retirada INTO v_ret FROM ctx;
  BEGIN
    PERFORM registrar_devolucao(v_ret, 4, 'reuso', 'Lindomar');
    RAISE EXCEPTION 'esperado erro de excesso, mas a devolução foi aceita';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%excede o saldo em uso%' THEN RAISE; END IF;
  END;
END $$;

-- 3. Devolver os 3 restantes zera o uso; devolver mais uma vez deve dizer "já devolvida".
DO $$
DECLARE v_ret text;
BEGIN
  SELECT retirada INTO v_ret FROM ctx;
  PERFORM registrar_devolucao(v_ret, 3, 'reuso', 'Lindomar');
  IF (SELECT saldo_em_uso FROM saldos_itens WHERE codigo = 'T-DEV') <> 0 THEN
    RAISE EXCEPTION 'esperado 0 em uso após devolver os 3 restantes';
  END IF;
  BEGIN
    PERFORM registrar_devolucao(v_ret, 1, 'reuso', 'Lindomar');
    RAISE EXCEPTION 'esperado erro de já devolvida, mas a devolução foi aceita';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%já devolvida%' THEN RAISE; END IF;
  END;
END $$;

-- 4. Condição fora de reuso/defeito deve ser recusada.
-- (Usa uma nova retirada, pois a anterior já está toda devolvida.)
DO $$
DECLARE r text;
BEGIN
  SELECT x.numero INTO r FROM registrar_retirada(
    (SELECT id FROM itens WHERE codigo = 'T-DEV'), 1, 'XAM',
    (SELECT id FROM locais_uso WHERE nome = 'Local devolucao teste'), 'Lindomar', false) x;
  BEGIN
    PERFORM registrar_devolucao(r, 1, 'sumido', 'Lindomar');
    RAISE EXCEPTION 'esperado erro de condição, mas a devolução foi aceita';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%condição inválida%' THEN RAISE; END IF;
  END;
END $$;

-- 5. Número de retirada inexistente deve ser recusado.
DO $$
BEGIN
  BEGIN
    PERFORM registrar_devolucao('RET-9999', 1, 'reuso', 'Lindomar');
    RAISE EXCEPTION 'esperado erro de retirada inexistente, mas a devolução foi aceita';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%retirada não encontrada%' THEN RAISE; END IF;
  END;
END $$;

-- 6. Retirada ainda pendente (não regularizada) não pode ser devolvida (regra da pré-verificação).
DO $$
DECLARE r text;
BEGIN
  SELECT x.numero INTO r FROM registrar_retirada(
    (SELECT id FROM itens WHERE codigo = 'T-DEV'), 1, 'XAM',
    (SELECT id FROM locais_uso WHERE nome = 'Local devolucao teste'), 'Lindomar', false, true) x;
  BEGIN
    PERFORM registrar_devolucao(r, 1, 'reuso', 'Lindomar');
    RAISE EXCEPTION 'esperado erro de retirada pendente, mas a devolução foi aceita';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%ainda não regularizada%' THEN RAISE; END IF;
  END;
END $$;
