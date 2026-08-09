# Remaining sequence — five sessions

Fresh Claude Code session for each. Close other sessions first (auto-update has been
failing with `claude.exe in use`), and don't carry context between these.

**Before session 1**, from each repo root:

```
mkdir docs\specs
copy "%USERPROFILE%\Downloads\dentist-workbench-build-prompt.md" docs\specs\
```

Session 1 asserts that file exists. Without it you get a fifth run working from
prompt text alone.

---

## Session 1 — Handoffs, attest, CloudFront, greeting

```
Four things. Reference @docs/specs/dentist-workbench-build-prompt.md for role
definitions and acceptance criteria — it's now in the repo.

--- 1. Handoff write path ---

clinical_handoffs was built read-only. Add POST /api/decisions/:id/handoff,
body { to_role, note }. Any authenticated user in the tenant can create one;
reads stay role-gated to the target role. Use the _capability() factory pattern
from the auth work.

Four frontend actions currently render a confirmation with no request behind
them. Wire all four through ONE hook, not four copies — NOTIFY is already
exported as a shared label, do the same for the mutation:
  - Jennifer's [Mark consultation complete] — handoff to 'dentist', include
    the TC note on the case
  - Sarah's [Notify clinical team] — handoff to 'dentist'
  - Kim's [Notify Dr. Chinta] on billing conditions
  - Kim's [Notify Dr. Chinta] on the "Not yours" section

After this the confirmation reflects a real 200, and the note appears on the
dentist's queue card and detail view.

--- 2. Attest endpoint, backend only ---

Add POST /decisions/:id/attest — clinician-only, writes clinical_attestations
without filing a submission. Reuse the attested:true path from /submit rather
than duplicating the logic.

Do NOT change WorkbenchClinicalView's buttons. Whether the dentist signs and
Kim submits, or the dentist does both, is a workflow decision I haven't made.
The endpoint is useful either way; the UI change isn't.

Verify the blocked → READY transition end to end with drchinta@ and billing@ —
it has only ever been tested by writing the attestation row directly.

--- 3. CloudFront SPA fallback ---

E4YXPYBM92LAA has CustomErrorResponses: null, so a hard load on any deep link
returns S3's 404. Add custom error responses mapping 403 and 404 to
/index.html with response code 200, then invalidate /*.

Verify with curl against the CDN host, not the ALB: a hard GET of
https://www.accorddental.io/revenue-ops returns 200 and index.html.

If AWS credentials aren't available, say so and move on — do not abandon the
other three items.

--- 4. Greeting ---

WorkbenchEngineView hardcodes "Good morning, Dr. Chinta". Use the logged-in
user's name.

--- Then ---

Confirm require_engine_feedback actually landed on all three call sites
(ConditionsManager, ConditionsPanel, FeedbackBar) — it was approved but never
appeared in a report.

Then grade all 9 acceptance criteria in the spec, which you can now read.
Pass, fail, or not verifiable, and how you tested each. Include cross-tenant
checks against Tampa logins.
```

---

## Session 2 — The `users` table, alone

This gets its own session because the failure mode is a silent production lockout.

```
Implement the users-table RLS work you proposed. Nothing else in this session.

Your own analysis, which I agree with: SECURITY DEFINER function scoped to
email lookup, RLS fully on, no exemption policy. A USING (true) row policy
would disable tenant isolation table-wide, and RLS filters rows not columns so
a column-scoped policy isn't a real option.

Sequence, and do not deviate:

1. Create authenticate_user(p_email text) returning only user_id,
   password_hash, role, tenant_id, active for one email.
   SET search_path = pg_catalog, public is mandatory, not optional.
2. Create the equivalent definer function for /auth/impersonate, which reads
   SELECT * FROM users WHERE user_id = $1 unbound and will silently return
   zero rows the moment RLS goes on.
3. Repoint login and impersonate at the functions.
4. Route every other users read (GET /auth/users) through
   execute_os_with_tenant.
5. Prove all six roles log in against the ALB, plus a Tampa login, in one
   session. Prove impersonation still works.
6. ONLY THEN: ALTER TABLE users ENABLE ROW LEVEL SECURITY, add the tenant
   policy, FORCE.
7. Re-prove all seven logins and impersonation after the ALTER.

If step 5 fails, stop and report. Do not enable RLS to see what happens.

Tell me before you start whether there is a rollback path that doesn't require
DB access, given psql isn't on PATH here.
```

The last line matters — if this goes wrong, you need to know how you get back in
before it goes wrong.

---

## Session 3 — Optimistic state sweep

Runs after session 1 so it catches the four handoff buttons too.

```
Every optimistic mutation in accorddental updates local state before or
regardless of the API response. This already produced a false pass: Kim's
submit card moved to "Submitted today" while the request 422'd, and the toast
timed out before anyone saw it.

Sweep all of them:
  - Sarah's check-in collapse
  - Sarah's notify clinical team
  - Jennifer's mark consultation complete
  - Jennifer's email and SMS sends
  - Kim's submit pre-D
  - Kim's submit anyway override
  - Kim's file appeal
  - Kim's two notify buttons
  - Dentist attest-and-submit
  - Dentist justification save and narrative autosave

For each: revert on failure, surface a persistent error state on the card
itself — not a toast. A card must never show a success state for a request
that failed.

Then force a failure on each path by intercepting the request and returning
500, and screenshot what the user sees. The screenshots are the deliverable.
A list of files changed is not evidence.
```

---

## Session 4 — Kim's submit, by hand

Small, but this is the exact thing that produced a false pass before.

```
Kim's Submit pre-D was measured with curl and reported working. It has not
been clicked.

Log in as billing@suwaneesmiles.com in a real browser against production, find
a READY case, and click Submit pre-D. Report what actually happens: the network
response, the card state after, and the card state after a hard refresh.

Do the same for Submit anyway on an unsigned case, and confirm the
provider_feedback override row is written.

Then click through Sarah's check-in, Jennifer's mark complete, and the
dentist's attest — same three observations each. I want clicked, not curled.
```

---

## Session 5 — Dr. Shyam and the end-to-end pass

Still untouched from the original P0 list.

```
Two things.

1. Verify dso_owner landing. Log in as drshyam@suwaneesmiles.com and confirm
   he lands on /dso, not /workbench. He owns two tenants — check
   drshyam@tampabaysmiles.com too, and confirm the tenant switch works.

2. Run the full six-role pass end to end against production:
   sarah@ checks in James Mitchell → tc@ completes the consultation and the
   handoff reaches the dentist → drchinta@ reviews, justifies, attests →
   billing@ sees it move to READY and submits → drshyam@ sees it in portfolio
   → admin@ impersonates each role and confirms the impersonated role governs,
   not the real one.

   Report where the chain breaks. It has never been run as a chain.
```

---

## Decision still outstanding

Does the dentist attest and Kim submit, or does the dentist do both? The attest
endpoint from session 1 is stranded until you answer, and the workbench's primary
button changes depending on which. Worth settling before session 3 touches those
mutations.
