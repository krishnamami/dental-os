-- 006 — the three reads of `users` that cannot be tenant-scoped.
--
-- Prepares for 007, which puts `users` under RLS. Applying this file
-- alone changes NO behaviour: it adds a role and three functions that
-- nothing calls yet.
--
-- ⚠ WHY A SEPARATE OWNER ROLE, AND WHY BYPASSRLS
--
-- FORCE ROW LEVEL SECURITY applies the policy to the TABLE OWNER as
-- well, and `dental_admin` owns `users` with rolbypassrls = false. On
-- stock PostgreSQL that means a SECURITY DEFINER function owned by
-- dental_admin returns zero rows once `users` is FORCEd — silently,
-- which is the failure this pair of migrations exists to avoid.
--
-- MEASURED ON THIS INSTANCE, that is NOT what happens: dental_admin is
-- a member of rds_superuser, and on RDS that bypasses RLS regardless of
-- rolbypassrls or FORCE. The test, run in a rolled-back transaction:
--
--     CREATE TABLE rls_probe(...); INSERT 2 rows;
--     ALTER TABLE rls_probe ENABLE + FORCE ROW LEVEL SECURITY;
--     CREATE POLICY deny_all ON rls_probe USING (false);
--     SELECT count(*) FROM rls_probe;   -- as dental_admin -> 2
--
-- A policy that can never be true still returned every row. So owning
-- these functions as dental_admin would in fact have worked here.
--
-- `dental_auth` is kept anyway, and it is not belt-and-braces theatre:
--   - it does not depend on an RDS-specific superuser behaviour that
--     AWS can tighten, and it still works if this database is ever
--     restored onto stock PostgreSQL;
--   - it is the difference between "these three functions are exempt"
--     and "the master user is exempt from everything";
--   - NOLOGIN means nothing can connect as it. It is not a way in.
--
-- The alternative — a USING (true) policy on `users` — would have
-- turned tenant isolation off for the whole table to serve one query.
-- This keeps the exemption to three named functions, each scoped to a
-- single lookup, each callable only by dental_app.

-- ── The owner ────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dental_auth') THEN
    CREATE ROLE dental_auth NOLOGIN BYPASSRLS;
  END IF;
END
$$;

-- Idempotent: re-running must not leave the role able to log in, and
-- must not leave it without the one attribute the design depends on.
ALTER ROLE dental_auth NOLOGIN BYPASSRLS;

GRANT USAGE ON SCHEMA public TO dental_auth;
GRANT SELECT ON public.users TO dental_auth;


-- ── 1. Login ─────────────────────────────────────────────────────
-- The only function that returns password_hash, and the only one that
-- needs to: /auth/login compares it and never sends it anywhere.
--
-- email and name are returned as well. The user's own list of columns
-- omitted them, but LoginResponse carries them — without them the
-- header renders a signed-in user with no name. They are not secrets
-- to a caller who has just proved they are that user.
--
-- SET search_path is not optional. A SECURITY DEFINER function without
-- it can be made to resolve `users` to an attacker-controlled table on
-- their own search_path and run it as the owner.
CREATE OR REPLACE FUNCTION public.authenticate_user(p_email text)
RETURNS TABLE (
  user_id       text,
  email         text,
  name          text,
  role          text,
  tenant_id     text,
  password_hash text,
  active        boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT u.user_id, u.email, u.name, u.role, u.tenant_id,
         u.password_hash, u.active
  FROM public.users u
  WHERE u.email = lower(btrim(p_email))
    AND u.active = true
$$;

ALTER FUNCTION public.authenticate_user(text) OWNER TO dental_auth;
REVOKE EXECUTE ON FUNCTION public.authenticate_user(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.authenticate_user(text) TO dental_app;


-- ── 2. By id — /auth/impersonate AND /auth/me ────────────────────
-- Both read `SELECT * FROM users WHERE user_id = $1` with no tenant
-- bound, and both would silently return zero rows under RLS.
--
-- /auth/me was not on the list for this change. It has the same query
-- and the same failure, and the frontend calls it on every page load —
-- leaving it out would have logged everyone out on their next refresh
-- rather than at their next login, which is slower to notice and worse.
--
-- No password_hash: neither caller compares one.
CREATE OR REPLACE FUNCTION public.get_user_by_id(p_user_id text)
RETURNS TABLE (
  user_id   text,
  email     text,
  name      text,
  role      text,
  tenant_id text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT u.user_id, u.email, u.name, u.role, u.tenant_id
  FROM public.users u
  WHERE u.user_id = p_user_id
    AND u.active = true
$$;

ALTER FUNCTION public.get_user_by_id(text) OWNER TO dental_auth;
REVOKE EXECUTE ON FUNCTION public.get_user_by_id(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_user_by_id(text) TO dental_app;


-- ── 3. The cross-tenant staff list, for accord_admin only ────────
-- GET /auth/users has two branches. The practice-owner branch is
-- tenant-bound and goes through execute_os_with_tenant, so the policy
-- covers it and no function is needed.
--
-- The accord_admin branch lists EVERY tenant, and accord_admin has no
-- tenant of their own — tenant_id IS NULL on that row. There is no
-- value of app.tenant_id that returns those rows, so it cannot be
-- expressed as a tenant-scoped query. The route is already behind
-- require_practice_admin plus an explicit accord_admin check.
--
-- No password_hash, no created_at: the five columns the admin screen
-- renders and nothing else.
CREATE OR REPLACE FUNCTION public.list_active_users()
RETURNS TABLE (
  user_id   text,
  email     text,
  name      text,
  role      text,
  tenant_id text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT u.user_id, u.email, u.name, u.role, u.tenant_id
  FROM public.users u
  WHERE u.active = true
  ORDER BY u.tenant_id NULLS LAST, u.role, u.name
$$;

ALTER FUNCTION public.list_active_users() OWNER TO dental_auth;
REVOKE EXECUTE ON FUNCTION public.list_active_users() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_active_users() TO dental_app;
