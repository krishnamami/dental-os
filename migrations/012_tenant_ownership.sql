-- 012 — who owns which practice.
--
-- Until now the relationship was implied by `users.tenant_id`: one
-- text column, one practice, and a DSO owner of three locations had to
-- be three unrelated user rows. Dr. Shyam was exactly that — two rows,
-- two user_ids, the same name string, and nothing linking them. There
-- was no way to ask "which practices does this person own", so
-- /portfolio/summary answered "the one on his row" and called it a
-- group.
--
-- ── SHAPE ────────────────────────────────────────────────────────────
-- Many-to-many. An owner has several practices; a practice may have
-- several owners (a partner buy-in, a group acquiring a single
-- location and keeping the founder on).
--
-- user_id IS a real foreign key — `users` is in this database.
-- tenant_id is NOT, and cannot be: `tenants` lives in the `dental`
-- database and Postgres cannot reference across databases. It is a
-- soft key, the same constraint Option B accepted for the billing
-- chain. What holds it is that every write goes through the API, and
-- the API resolves tenants from the directory before it writes.
--
-- ── RLS ──────────────────────────────────────────────────────────────
-- ENABLE and FORCE, like every other table in dental_os, with the same
-- tenant policy. A row about Tampa is visible only under
-- app.tenant_id = 'tampa_smiles'.
--
-- Which creates the same bootstrap problem `users` had in 006/007: the
-- question "which tenants does this caller own" HAS NO TENANT TO SCOPE
-- BY — it is the question that produces one. Under the policy alone, a
-- Suwanee-bound connection reads Shyam's Suwanee row and silently not
-- his Tampa row, and a two-practice owner would see one practice with
-- no error anywhere. That is the RLS trap, exactly.
--
-- So this file adds tenants_owned_by(), a SECURITY DEFINER function
-- owned by dental_auth — the seam 006 already established for
-- authenticate_user() and get_user_by_id(). It is deliberately the
-- narrowest thing that answers the question: it takes a user_id,
-- returns tenant_ids, and reads nothing else.
--
-- ⚠ THE DISTINCTION THAT MATTERS. This function resolves IDENTITY, not
-- DATA. Nothing about a patient, a pre-D or a dollar passes through
-- it. The aggregate that follows still iterates the returned tenants
-- one at a time and binds each with execute_os_with_tenant, so every
-- row of actual practice data is read under RLS with app.tenant_id
-- set. There is no bypass role on the request path and no policy
-- exception on any table holding clinical or financial data.
--
-- ── ROLLBACK ─────────────────────────────────────────────────────────
--   DROP FUNCTION public.tenants_owned_by(text);
--   DROP TABLE tenant_ownership;
-- The endpoint falls back to nothing — /portfolio/summary would raise
-- rather than answer, so roll the app back first if it comes to that.

BEGIN;

CREATE TABLE IF NOT EXISTS tenant_ownership (
    ownership_id text PRIMARY KEY DEFAULT (gen_random_uuid())::text,
    user_id      text NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    tenant_id    text NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),
    -- Granting the same practice twice is a double-click, not a second
    -- stake in the business.
    CONSTRAINT tenant_ownership_unique UNIQUE (user_id, tenant_id)
);

-- The portfolio reads by user_id every time.
CREATE INDEX IF NOT EXISTS tenant_ownership_user
    ON tenant_ownership (user_id);

ALTER TABLE tenant_ownership ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_ownership FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_ownership_tenant ON tenant_ownership;
CREATE POLICY tenant_ownership_tenant ON tenant_ownership
  USING (tenant_id = current_setting('app.tenant_id', true))
  WITH CHECK (tenant_id = current_setting('app.tenant_id', true));

GRANT SELECT, INSERT, UPDATE, DELETE ON tenant_ownership TO dental_app;

-- ⚠ AND TO dental_auth, WHICH IS NOT THE SAME GRANT AND IS NOT
-- OPTIONAL. tenants_owned_by() below runs AS dental_auth, so the
-- privileges that matter inside it are dental_auth's, not the caller's.
-- The first cut of this file granted dental_app only, the function was
-- created and owned correctly, every test passed — and production
-- answered 500, `permission denied for table tenant_ownership`, on the
-- first real portfolio read.
--
-- 006 got this right for `users` (GRANT SELECT ON public.users TO
-- dental_auth, line 54) and it is the same requirement for the same
-- reason.
GRANT SELECT ON tenant_ownership TO dental_auth;

-- ─────────────────────────────────────────────────────────────────────
-- tenants_owned_by — the only unscoped read, and it returns nothing
-- but tenant ids.
--
-- SET search_path is not optional on a definer function: without it a
-- caller can prepend a schema of their own and have this run their
-- table instead of ours. Same rule as every function in 006.
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.tenants_owned_by(p_user_id text)
RETURNS TABLE (tenant_id text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
    SELECT o.tenant_id
    FROM tenant_ownership o
    JOIN users u ON u.user_id = o.user_id
    -- A deactivated account owns nothing. Deactivating is how a person
    -- is removed, and it must not leave their practices readable.
    WHERE o.user_id = p_user_id
      AND u.active
    ORDER BY o.tenant_id
$$;

ALTER FUNCTION public.tenants_owned_by(text) OWNER TO dental_auth;
REVOKE ALL ON FUNCTION public.tenants_owned_by(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.tenants_owned_by(text) TO dental_app;

COMMIT;
