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
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_user') THEN
    CREATE ROLE app_user NOSUPERUSER NOBYPASSRLS;
  END IF;
END $$;

GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO app_user;
