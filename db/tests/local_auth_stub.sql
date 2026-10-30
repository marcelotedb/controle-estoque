-- Simulação local do que o Supabase já fornece em produção: o esquema auth com
-- auth.users e a função auth.uid(). Usado SOMENTE para testar RLS localmente;
-- não entra na ordem de aplicação da Task 12, porque o projeto Supabase real já
-- tem auth.users e auth.uid() prontos.
--
-- auth.uid() lê a variável de sessão app.current_user_id, que os testes ajustam
-- com set_config antes de cada operação, simulando o usuário autenticado.

CREATE SCHEMA IF NOT EXISTS auth;

CREATE TABLE IF NOT EXISTS auth.users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid()
);

CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid
LANGUAGE sql STABLE
AS $$
  SELECT current_setting('app.current_user_id', true)::uuid;
$$;

-- Papel não-superusuário para exercitar RLS de verdade: um superusuário ignora
-- toda política de RLS, então os testes precisam rodar como este papel.
-- Chamado "authenticated", igual ao papel real do Supabase, porque a Task 12
-- passou a conceder EXECUTE nas funções sensíveis especificamente a esse nome
-- (REVOKE FROM PUBLIC ... GRANT TO authenticated); testar com outro nome de
-- papel local deixaria essa trava sem cobertura.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOSUPERUSER NOBYPASSRLS;
  END IF;
END $$;

-- Papel "anon" só para o REVOKE EXECUTE ... FROM PUBLIC, anon (04_permissoes.sql,
-- 05_ajustes.sql) encontrar o papel real do Supabase e não falhar localmente;
-- não recebe nenhum GRANT, pois não deve ter acesso a nada sensível.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOSUPERUSER NOBYPASSRLS;
  END IF;
END $$;

GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
