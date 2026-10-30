-- Permissões e RLS (Task 6).
-- Todo usuário autenticado com linha em perfis pode ler e registrar movimentações.
-- Só o dono pode alterar ou excluir diretamente. Movimentações nunca são apagadas por ninguém.

CREATE TABLE perfis (
  usuario_id uuid PRIMARY KEY REFERENCES auth.users (id),
  papel      text NOT NULL CHECK (papel IN ('dono', 'operador'))
);

-- security definer: consulta perfis sem ficar sujeita à própria RLS de perfis
-- (evita o problema do ovo e da galinha: ler perfis para decidir a política de perfis).
CREATE OR REPLACE FUNCTION eh_dono() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM perfis WHERE usuario_id = auth.uid() AND papel = 'dono');
$$;

CREATE OR REPLACE FUNCTION tem_perfil() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM perfis WHERE usuario_id = auth.uid());
$$;

ALTER TABLE unidades      ENABLE ROW LEVEL SECURITY;
ALTER TABLE locais_uso    ENABLE ROW LEVEL SECURITY;
ALTER TABLE itens         ENABLE ROW LEVEL SECURITY;
ALTER TABLE movimentacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE perfis        ENABLE ROW LEVEL SECURITY;

CREATE POLICY unidades_select  ON unidades      FOR SELECT USING (tem_perfil());

CREATE POLICY locais_select    ON locais_uso    FOR SELECT USING (tem_perfil());
CREATE POLICY locais_insert    ON locais_uso    FOR INSERT WITH CHECK (tem_perfil());
CREATE POLICY locais_update    ON locais_uso    FOR UPDATE USING (eh_dono());
CREATE POLICY locais_delete    ON locais_uso    FOR DELETE USING (eh_dono());

CREATE POLICY itens_select     ON itens         FOR SELECT USING (tem_perfil());
CREATE POLICY itens_insert     ON itens         FOR INSERT WITH CHECK (tem_perfil());
CREATE POLICY itens_update     ON itens         FOR UPDATE USING (eh_dono());
CREATE POLICY itens_delete     ON itens         FOR DELETE USING (eh_dono());

CREATE POLICY mov_select       ON movimentacoes FOR SELECT USING (tem_perfil());
CREATE POLICY mov_insert       ON movimentacoes FOR INSERT WITH CHECK (tem_perfil());
CREATE POLICY mov_update       ON movimentacoes FOR UPDATE USING (eh_dono());
-- Sem política de DELETE em movimentacoes: nenhuma movimentação é apagada por ninguém.

CREATE POLICY perfis_select    ON perfis        FOR SELECT USING (usuario_id = auth.uid() OR eh_dono());

-- As funções de operação (Tasks 3, 4 e 4b) fazem SELECT ... FOR UPDATE e INSERT em
-- movimentacoes/itens por conta própria, validando as regras de negócio internamente.
-- Elas passam a rodar como SECURITY DEFINER para que um operador (sem privilégio de
-- UPDATE direto) ainda consiga completar uma retirada, devolução ou regularização
-- através da função — a política de UPDATE continua bloqueando um UPDATE direto feito
-- fora dessas funções.
ALTER FUNCTION registrar_retirada(uuid, integer, text, uuid, text, boolean, boolean) SECURITY DEFINER SET search_path = public;
ALTER FUNCTION registrar_devolucao(text, integer, text, text) SECURITY DEFINER SET search_path = public;
ALTER FUNCTION regularizar_retirada_pendente(text, text) SECURITY DEFINER SET search_path = public;

-- Ninguém chama estas funções sem estar autenticado: revoga de PUBLIC (que
-- inclui "anon") e concede só a "authenticated". A validação interna de
-- tem_perfil()/eh_dono() continua sendo a defesa real; isto é a segunda camada.
REVOKE EXECUTE ON FUNCTION eh_dono() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION tem_perfil() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION registrar_retirada(uuid, integer, text, uuid, text, boolean, boolean) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION registrar_devolucao(text, integer, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION regularizar_retirada_pendente(text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION registrar_item(text, text, text, integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION registrar_local_uso(text, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION verificar_duplicata_item(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION verificar_duplicata_local(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION normalizar_nome(text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION eh_dono() TO authenticated;
GRANT EXECUTE ON FUNCTION tem_perfil() TO authenticated;
GRANT EXECUTE ON FUNCTION registrar_retirada(uuid, integer, text, uuid, text, boolean, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION registrar_devolucao(text, integer, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION regularizar_retirada_pendente(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION registrar_item(text, text, text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION registrar_local_uso(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION verificar_duplicata_item(text) TO authenticated;
GRANT EXECUTE ON FUNCTION verificar_duplicata_local(text) TO authenticated;
GRANT EXECUTE ON FUNCTION normalizar_nome(text) TO authenticated;
