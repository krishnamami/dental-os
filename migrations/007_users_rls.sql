-- 007 — put `users` under RLS.
--
-- ⚠ DO NOT APPLY THIS BEFORE 006, AND NOT BEFORE THE APP IS DEPLOYED
-- POINTING AT 006's FUNCTIONS. Login, /auth/me and /auth/impersonate
-- all read `users` with no tenant to scope by. Under this policy an
-- unscoped read returns zero rows and raises NOTHING — the API answers
-- "Invalid email or password" to every correct password, and "User not
-- found" on every session restore. That is a total production lockout
-- with a clean error log.
--
-- Order that was actually followed:
--   1. 006 applied (functions exist, nothing calls them)
--   2. app deployed reading through the functions
--   3. all six Suwanee roles + two Tampa logins + four impersonations
--      proved against the ALB with RLS still OFF
--   4. this file
--   5. the same proof re-run
--
-- ROLLBACK, in order of cost, none of which needs psql:
--   ALTER TABLE users NO FORCE ROW LEVEL SECURITY;   -- owner reads again
--   DROP POLICY users_tenant ON users;               -- everyone reads
--   ALTER TABLE users DISABLE ROW LEVEL SECURITY;    -- back to 8 Aug
-- DDL is not itself filtered by RLS, so dental_admin can always run
-- these even while locked out of reading the table's rows.

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- FORCE so the table's owner is bound by the policy too.
--
-- ⚠ ON RDS THIS DOES NOT BIND dental_admin. It is a member of
-- rds_superuser, which bypasses RLS whatever FORCE says — measured, not
-- assumed: a USING(false) policy on a FORCEd table it owns still
-- returned every row. Set regardless, because it costs nothing, it is
-- correct on stock PostgreSQL, and the day the master user stops being
-- an rds_superuser this is the line that already says what should
-- happen. What actually holds the boundary is that the API connects as
-- dental_app, which has no bypass:
--
--     as dental_app, no app.tenant_id      -> 0 of 13 rows
--     as dental_app, suwanee_smiles        -> 5
--     as dental_app, tampa_smiles          -> 5
--     as dental_app, no_such_tenant        -> 0
ALTER TABLE users FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS users_tenant ON users;

-- The same shape as every other table in 003/004/005. No exemption
-- branch: a USING (true) arm for the login path would apply to every
-- other read as well, which is tenant isolation off for the table.
--
-- Rows with tenant_id IS NULL — accord_admin — match no tenant and are
-- therefore invisible to this policy by design. Every read of that row
-- goes through a definer function in 006.
CREATE POLICY users_tenant ON users
  USING (tenant_id = current_setting('app.tenant_id', true))
  WITH CHECK (tenant_id = current_setting('app.tenant_id', true));
