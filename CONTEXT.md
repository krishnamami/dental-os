# Accord Dental OS — Project Context

**Last updated:** 2026-08-06 &nbsp;·&nbsp; **Phase:** 5 (runner) COMPLETE &nbsp;·&nbsp; **Next:** Phase 6 — API surface

> This file tracks build **state** — it changes every session.
> `docs/PRD.md` describes product **intent** and `domains/dental/decisions.yaml`
> is normative for boundaries, modes and waves. Read all three before starting.

---

## Quick Start

```bash
git clone https://github.com/krishnamami/dental-os.git
cd dental-os
pip install -r requirements.txt
cp .env.example .env        # then add your ANTHROPIC_API_KEY
uvicorn api.main:app --port 9010
```

> **`api.main` does not exist yet.** Phase 6 creates it. Until then the uvicorn
> line is the target, not a working command. What DOES run end-to-end today is
> the wave runner:
>
> ```bash
> python scripts/evaluate_dental_scenarios.py     # 40 scenarios, all 5 waves
> ```

**dental-os reads from the dental-simulator RDS. The simulator must have data
loaded first** — this repo has no data of its own and never will.

```bash
python scripts/test_connection.py
```

Expected, re-verified against the live RDS on 2026-08-06 **after Group U
landed** — every number below moved except the catalogue tables:

```
  pred_requests        40      (approved=13, denied=7, pended=20)
  pred_states          40      same distribution
  clinical_evidence   212      (124 with an s3_key)
  procedure_lines      72
  fee_schedules       588      28 codes x 3 payers x 7 states
  coverage_rules      543      181 codes x 3 payers   (was 14)
  cdt_codes           181
  conditions_library   50
  frequency_limits     27
  bundling_rules       20
  ada_guidelines       10
  downgrade_matrix      9
  medical_history_flags 8
  providers             3
```

> **If you have a memory of "35 scenarios, approved=8", it is from before
> 2026-08-06.** Group U added 5 approvals. Any script asserting 35 is stale.

## Catalogue versions

`catalogue_versions` tracks 9 catalogues. Every decision stamps these into
`persona_bundles`, so a replay can tell whether the rules moved underneath it.

| catalogue | version | rows | states |
|---|---|---|---|
| `cdt_codes` | CDT-2026 | 181 | ALL |
| `coverage_rules` | 1.1 | **543** | ALL |
| `fee_schedules` | 2025-07-01 | **588** | GA FL TX NC SC TN AL |
| `conditions_library` | 1.0 | 50 | ALL |
| `frequency_limits` | 1.0 | 27 | ALL |
| `bundling_rules` | 1.0 | 20 | ALL |
| `ada_guidelines` | CDT-2026 | 10 | ALL |
| `downgrade_matrix` | 1.0 | 9 | ALL |
| `medical_history_flags` | 1.0 | 8 | ALL |

---

## Infrastructure

### dental-simulator RDS — the only data source

```
  Host      dental-postgres.c2feioes4hil.us-east-1.rds.amazonaws.com
  Database  dental
  Runtime   dental_app  /  dental_app_dev        RLS ENFORCED — use this
  Owner     dental_admin /  <SSM /dental/db/password>   DDL only, bypasses RLS
```

**Do not put the `dental_admin` password in this file, in `.env.example`, or in
any committed file.** It is in SSM Parameter Store at `/dental/db/password` and
that is the only place it should live — it bypasses RLS and grants DDL, so a
copy in git is a copy in every clone and every fork forever. Fetch it when you
need it:

```bash
aws ssm get-parameter --name /dental/db/password --with-decryption \
    --profile dental --query Parameter.Value --output text
```

> In Git Bash, prefix `MSYS_NO_PATHCONV=1` on any `aws` command whose argument
> starts with `/` — otherwise the shell rewrites the SSM path into a Windows
> path and the lookup fails with a confusing "parameter not found".

Never overwrite `/dental/db/password`. RDS was created from it;
`create_ssm_params.sh` refuses without `--rotate`.

### ⚠ THE RLS TRAP — read this before debugging any "missing data"

```sql
SET app.tenant_id = 'suwanee_smiles';   -- EVERY session. EVERY query path.
```

RLS is `FORCE` and `dental_app` is a non-owner, so a connection that has not set
it **returns 0 rows with no error**. That is indistinguishable from an empty
table, a failed load, or a wrong database. This has already produced one false
"wrote zero rows" report.

**Prove visibility before concluding data is missing.** If a count comes back 0,
set the tenant and count again before you touch anything else.

### dental-simulator ALB

```
  http://dental-alb-224168237.us-east-1.elb.amazonaws.com
```

**dental-os does NOT use this.** It reads the RDS directly. The ALB is the
simulator's own API surface, useful for spot-checking a scenario by hand:

```bash
curl http://dental-alb-224168237.us-east-1.elb.amazonaws.com/pred-requests/PRED-SIM-DA-A01/state
```

### Repos and account

```
  dental-os          ~/OneDrive/Documents/dental-os          (this repo)
  dental-simulator   ~/OneDrive/Documents/dental-simulator   (upstream)
  decision-os        ~/OneDrive/Documents/decision-os        (the lending sibling — pattern reference)

  AWS account  740104998309   us-east-1   CLI profile: dental
```

**Never Capital Loans (621646470377).** Every `aws` command takes
`--profile dental`.

### ⚠ The local Postgres on :5434 is NOT the simulator

`dental-simulator/.env` sets `DATABASE_URL` to
`postgresql://dental_app:...@localhost:5434/dental`, **not** the RDS. That local
database holds a stale partial copy of an OLD pipeline run:

```
  30 pred_states (not 35)      decisions: approved=6, denied=7, pended=17
  ids in PRED-DA-* format      (the deleted format — see RULE 14)
  clinical_evidence            0 rows
  most reference tables        do not exist at all
```

If you source the simulator's `.env` and query, you get plausible-looking wrong
answers. dental-os must point at the RDS host explicitly — which is what
`dental-os/.env.example` already does.

---

## Repo State at End of Last Session

**Phases 0–5: COMPLETE.** The pipeline runs end to end — a pred_request_id in,
nine decisions and an audit bundle out.

| Phase | What it built | Status |
|---|---|---|
| 0 | `docs/PRD.md`, `decisions.yaml`, `knowledge_base.json`, this file | done |
| 1 | `core/db/` pools, `migrations/001` (8 views) + `002` (4 tables) | done |
| 2 | `core/catalogue/` — `rule_loader` + `context_enricher` | done |
| 3 | `core/resolvers/` — coverage, completeness, waiting period, … | done |
| 4 | 8 personas in `domains/dental/personas/` | done |
| 5 | `core/cron/runner.py` + `pre_d_assessment` + the eval harness | done |

`domains/dental/decisions.yaml` is still **normative** — boundaries, modes and
waves come from there, not from the runner's inline copy.

### What Phase 5 added

`core/cron/runner.py` — `PersonaRunner` drives all five waves for one pre-D.
`ContextBuilder` → `ContextEnricher` → waves 1-5 → `decision_outputs` then
`persona_bundles` in one transaction (RULE 10).

`domains/dental/personas/pre_d_assessment.py` — the Wave 4 synthesis. It was
deferred out of Phase 4 (`personas/__init__.py` said "Phase 5") because it
reads the other eight rather than producing findings of its own. That makes
**nine** personas, not eight.

`scripts/evaluate_dental_scenarios.py` — all 40 scenarios through the runner,
signal assertions on the 9 that have documented expectations.

**Verified on the live RDS 2026-08-06:**

```
  40/40 scenarios PASSED       0 persona exceptions
  decision_outputs   347 rows  W1=120 W2=80 W3=40 W4=40 W5=67
  persona_bundles     40 rows  1 per pre-D, all is_current
  outcomes           272 recommend / 63 escalate / 12 block
```

> **347, not 360.** `appeal_specialist` carries `only_if decision in (denied,
> pended)`, and 27 of 40 qualify: 27×9 + 13×8 = 347. A run that produces 360
> means the Wave 5 gate stopped working.

Three things a future session will otherwise rediscover the hard way:

- **`decision_outputs` has no unique key on `(pred_request_id, decision_id)`.**
  `migrations/002` declares it append-only and versioned — a re-run adds rows,
  never mutates them. `ON CONFLICT … DO UPDATE` cannot bind and would erase the
  prior run's audit trail if you added a constraint to make it bind.
  `persona_bundles` carries the versioning instead (`is_current` + `version`).
- **`catalogue_rules` is tuple-keyed** since T-10i — `(payer_id, cdt_code)`,
  and `(payer_id, cdt_code, state)` for fees. `json.dumps` raises `TypeError`
  on it. `runner._stringify_keys` joins them with `|` before the JSONB write.
- **Personas are invoked through `run()`, never `_compute_offline()`.** `run()`
  is what carries the never-raises guarantee; calling the inner method directly
  lets one bad persona take down its wave and every wave after it.

### Commit history

```
5fb590d  feat: Phase 5 — PersonaRunner complete
5fdfb70  docs: close Gap #7 — PRD Known Gap #5 wording
0a6fbae  docs: close Gap #4 — coverage_rules complete
014ab33  feat: T-10i — coverage_resolver + rule_loader tuple keys
eba5d6d  feat: Phase 4 — 9 personas complete
14d1983  feat: Phase 3 — resolvers complete
a732926  feat: catalogue T-10b/e
ca40204  feat: Phase 2 — catalogue layer
148c313  feat: Phase 1 — foundation complete
7c23a3e  docs: T-03 + T-04 — knowledge_base.json and CONTEXT.md
2eeb592  docs: reword Known Gap #5 — two CONFIDENCE_FLOOR constants
```

### Suggested Phase 6 order

1. `api/main.py` — FastAPI on :9010, the uvicorn line at the top of this file
2. `POST /pred-requests/{id}/run` — one `PersonaRunner.run()` per request
3. `GET /pred-requests/{id}/decisions` — read `decision_outputs`, current only
4. `GET /pred-requests/{id}/bundle` — the replay path, reads `persona_bundles`
   directly (no view, no enricher — RULE 10)
5. `provider_feedback` write path — the human override capture that the
   reflection block in `decisions.yaml` already specifies
6. `appeal_packets` generator — dental-simulator Gap #3, and the highest-value
   unbuilt thing in either repo

---

## Architecture Rules

Rules 1–11 are inherited from `decision-os/docs/ARCHITECTURE.md` and apply here
unchanged in spirit. Rules 12–15 are dental-specific.

**RULE 1 — ZERO HARDCODED VALUES**
Every threshold, rate, factor, period and percentage lives in a catalogue table.
Never in Python. Test: grep for numeric dental constants in resolver files →
zero hits. The one legitimate exception is a documented `SAFE_DEFAULTS` fallback
(RULE 9).

**RULE 2 — THREE LAYERS ONLY**
`ada_guidelines` → clinical floor, cannot be overridden.
`payer_rules` (coverage_rules + bundling_rules) → contractual.
`overlay_rules` → tenant/practice policy, ALWAYS WINS.
No other rule source. Note this inverts lending's chain: there, agency sits
above regulatory. Here ADA is a floor nothing may drop below.

**RULE 3 — ACCORD SURFACES RULES. THE PRACTICE DECIDES.**
Every decision shows: ADA | Payer | Overlay | Applied | Citation. That chain is
what makes a pre-D defensible to a payer medical director.

**RULE 4 — ENRICHER IS THE CATALOGUE GATEWAY**
The enricher holds the connection, calls `rule_loader`, attaches results to the
bundle. A persona reads from the bundle. A persona NEVER calls `rule_loader`
directly.

**RULE 5 — PERSONA IS SYNC AND DB-LESS**
`_compute_offline(bundle)` has no DB access. No `await`, no `conn`, no query
inside a persona. Everything it needs is already in the bundle.

**RULE 6 — RESOLVERS RETURN IN MEMORY**
A resolver receives values from the persona, reads the injected rules dict, and
returns findings. A resolver NEVER writes to a table or a view.

**RULE 7 — SIGNALS NOT FLAGS**
`make_signal()` only. The emitted signal must be one of the strings listed under
that decision's `signals_emitted` in `decisions.yaml` — that list is closed.

**RULE 8 — CATALOGUE BEFORE CODE**
Seed the rule into the catalogue → verify `rule_loader` returns it → THEN write
the resolver against it. Never add a Python constant as a placeholder.

**RULE 9 — SAFE_DEFAULTS IS THE ONLY FALLBACK**
If a rule is missing from the catalogue, log a WARNING and use the documented
`SAFE_DEFAULT`. Never a local hardcoded constant.

**RULE 10 — persona_bundles AFTER decision_outputs**
Write the `persona_bundles` row after `decision_outputs` commits, in the same
transaction. The memory bundle is truth during a live run; the PG bundle is the
audit record and is never read during a run. Replay reads it directly.

**RULE 11 — RESOLVER OUTPUT STANDARD**
Every resolver method returning a findings dict MUST include `data_source` and
`missing_inputs`. A missing input surfaces in `missing_inputs` and the method
degrades to a documented default — never a silent guess.

**RULE 12 — EVERY QUERY SETS THE TENANT**
`SET app.tenant_id = 'suwanee_smiles'` on every connection, every path,
including one-off scripts and test fixtures. See the RLS trap above. Every
domain table has `tenant_id`.

**RULE 13 — NO INVENTED DATA**
Every row traces to a source. Every citation traces to a catalogue row —
`no_citation_without_source` is a hard rule in `decisions.yaml`. If the
catalogue cannot support a claim, the decision does not make the claim.

**RULE 14 — PRED_REQUEST_ID FORMAT**
dental-simulator uses **`PRED-SIM-DA-A01`**, not `PRED-DA-A01`. The `PRED-DA-*`
format is from the OLD pipeline run. Always use `PRED-SIM-DA-*` when querying
dental-simulator tables.

```
  grep "PRED-DA-" anywhere in dental-os code = bug
```

Two live traps behind this rule:

- The old `PRED-DA-*` rows **still exist** in the local Postgres on `:5434`
  (30 of them), so the bad format returns rows rather than an empty set. It
  fails by giving you wrong answers, not by erroring.
- The **S3 prefix uses the bare scenario id**, not the pred_request_id:
  `suwanee_smiles/DA-A01/DA-A01_CLINICAL_NOTE.pdf`. Strip `PRED-SIM-` when
  building a key. Neither form of the full id appears in an S3 path.

**RULE 15 — DENTAL-OS HAS ITS OWN TABLES**
dental-simulator tables are **READ-ONLY** for dental-os.
dental-os owns exactly four: `decision_outputs`, `persona_bundles`,
`provider_feedback`, `appeal_packets` — created in
`migrations/002_dental_os_tables.sql`.

Never write to a dental-simulator table from dental-os. The whole two-repo split
exists so a decision stays reproducible from the simulator alone; a write from
this side destroys that property. The connection string in `.env.example` uses
`dental_app`, which cannot DDL — that is a guardrail, not an inconvenience.

---

## RULE 16 — `payer_responses` IS A FIXTURE, NOT A RECORD OF EVENTS

`payer_responses` (dental-simulator, 40 rows) describes **the posture a payer
is predicted to take** on a pre-D. Every pre-D has a row. None of them records
anything that happened.

What happened lives in dental-os, and only there:

| Fact | Table | Rows today |
|---|---|---|
| we sent it | `submission_events` | 3 |
| they refused it | `denial_events` | 3 |
| we appealed | `appeal_events` | 3 |

**The rule:** anything user-facing that asserts an event — a submission, a
denial, an appeal, a date one of those produced — reads the dental-os tables.
`payer_responses` is for the engine's prediction and nothing else.

This is why `appeal_specialist` gates on `context.denial_event` and not on
`context.decision`. Gating on the prediction fired APPEAL_VIABLE on twenty
pre-Ds nobody had sent anywhere.

`received_at` was the one column claiming otherwise — `2026-08-05` on all 40
rows, asserting a payer answered forty cases in a day. It is dropped from
`vw_appeal_context` and NULLed in the data.

⚠ **The column itself still exists**, and deliberately: dental-simulator's
`infra/migrations/001_entity_model.sql` declares it and
`scripts/generate_payer_responses.py` INSERTs it by name. Dropping it from here
would break the simulator's own corpus regeneration on the next run, and RULE
15 forbids editing that repo. The dental-simulator change, when someone owns
it: remove `received_at` from both files, then `ALTER TABLE payer_responses
DROP COLUMN received_at`.

### No FK can cross this boundary

`payer_responses` is in database `dental`; the event tables are in `dental_os`.
Same RDS instance, two databases, `plpgsql` only — no `postgres_fdw`, no
`dblink`. A foreign key cannot cross a database in Postgres. The enforceable
chain lives inside dental-os and is built in `migrations/009`:

    submission_events <- denial_events.submission_id
                      <- appeal_events.denial_id

---

## Infrastructure Ownership — most of dental-os is not in any stack

⚠ READ THIS BEFORE CHANGING ANYTHING IN AWS FOR dental-os, AND BEFORE
BELIEVING A CLEAN DRIFT REPORT.

**dental-os's ECS service, its task definition and its `/ecs/dental-os`
log group are in no CloudFormation stack.** They were created directly
through the API and are managed by hand. The only dental-os
infrastructure under IaC is the two IAM roles it *shares* with
dental-api, and those live in **dental-simulator**:

    dental-simulator/infra/cloudformation/04-ecs.yaml   (stack: dental-ecs)
      TaskExecutionRole   dental-task-execution-role    shared
      TaskRole            dental-task-role              shared

    dental-api stack        owns dental-api-service
    no stack                owns dental-os-service
    no stack                owns task definition dental-os
    no stack                owns log group /ecs/dental-os

**Drift detection cannot see any of it.** `detect-stack-drift` compares
live resources against a stack's *stored template*; a resource no stack
declares is not drift, it is invisible. `dental-ecs` reporting IN_SYNC
would say nothing at all about the dental-os service.

### Why the roles drifted twice

Because they are the one seam. When dental-os needs a permission, the
shared role has to be edited by hand — and the template in the other
repo does not follow, because RULE 15 makes it read-only from here.
Both drifts came from exactly that:

  · **TaskExecutionRole** was widened by hand for dental-os's ECR
    repository and log group. The template named `dental-api` alone, so
    a deploy would have removed dental-os's image pull and left the
    service unable to start its next task.
  · **TaskRole** was narrowed by hand to `s3:GetObject` on the document
    bucket. The template still granted PutObject, DeleteObject and
    ListBucket, so a deploy would have silently re-widened it.

Both are reconciled in the template as of 10 Aug 2026. The stack is
still reported DRIFTED and will be until someone deploys: editing the
file does not change what CloudFormation has stored.

`tests/test_iam_grant.py` asserts the S3 grant from this side, by
asking IAM for the effective decision. It is the alarm for a redeploy
that reverts the narrowing.

### A deploy of dental-ecs is not a no-op

`TaskDefinition` references both role ARNs through `GetAtt`, which
CloudFormation treats as `RequiresRecreation: Always`. Deploying the
stack cuts a new `dental-api` task-definition revision. Harmless
**today** — `dental-api-service` is pinned to a revision and will not
move on its own, and `dental-os-service` is a different family
entirely — but it is a change, not a formality, and it should be a
decision rather than a side effect of reconciling drift.

### Hand-managed settings that no stack will restore

Anything set directly is lost the day these resources are rebuilt, and
nothing will report it missing:

  · `/ecs/dental-os` retention = **30 days**, set 10 Aug 2026 with
    `aws logs put-retention-policy`, to match `/ecs/dental-api`. It had
    none, meaning logs never expired. The group was 3 days old and 3 MB
    at the time, so nothing was deleted and the cost was about $0.0001
    a month — this was about the data lifecycle, not the bill.
  · `dental-task-role`'s S3 grant, until the stack is next deployed.

### Adopting them is a separate job

Bringing the service, task definition and log group under IaC needs
`create-change-set --import-existing-resources`, not a template edit —
a plain deploy fails with "already exists" on every one of them.
**Deferred deliberately.** Until it happens, treat any AWS change for
dental-os as manual, and write it down here.

---

## Confidence Threshold Reference

There is no single `CONFIDENCE_FLOOR` in dental-simulator. There are two, and
they answer different questions.

| Constant | Value | Question it answers | Defined in |
|---|---|---|---|
| `AI_FALLBACK_FLOOR` | **0.6** | "Is this bad enough that Claude should look at it?" | `core/documents/extractors/base.py:21` |
| `TRUST_FLOOR` | **0.70** | "Is this good enough to base a decision on?" | `core/ingestion/adapters/pdf_adapter.py:9` |

`AI_FALLBACK_FLOOR` is imported by all four extractors — `xray_extractor.py`,
`perio_extractor.py`, `clinical_note_extractor.py`, `pred_letter_extractor.py`.
`TRUST_FLOOR` is repeated in `pdf_adapter.py`,
`domains/dental/assemblers/clinical_assembler.py:10` and
`scripts/build_scenarios_xlsx.py:118`.

**dental-os uses `TRUST_FLOOR` = 0.70**, because `clinical_assembler.py` is what
gates evidence into `pred_states` and `pred_states` is the only thing
`documentation_reviewer` reads.

> **Do not assume a `CONFIDENCE_FLOOR` you find in dental-simulator means 0.70.
> Check which file it came from.**

The band between them is where it bites: a document at **0.65** is fine to the
extractor (no fallback fires) and simultaneously `requires_verification=True`
with `extraction_method=ai_vision` stamped by `pdf_adapter.py` — on a value no
AI ever touched. Names, not values, are the fix. See PRD Known Gap #5.

Reference case — **DA-M05**, "Low-Confidence Scanned Extraction":

```
  PA X-ray       0.45  → below both floors → Claude ai_vision fallback fires
  clinical note  0.72  → above both floors → accepted as deterministic
```

---

## Known Gaps

| # | Gap | Where it lives | Status |
|---|---|---|---|
| 1 | Readiness flags not wired | dental-simulator | half-closed |
| 2 | Group U — urgency corpus | dental-simulator | half-closed |
| 3 | Appeal generation — table exists, no logic | dental-simulator | open |
| 4 | `coverage_rules` breadth | dental-simulator | **CLOSED** |
| 4a | Coverage *provenance* — 14 of 181 traced | dental-simulator | open |
| 5 | `AI_FALLBACK_FLOOR` 0.6 vs `TRUST_FLOOR` 0.70 | dental-simulator | **CLOSED** |
| 6 | DA-M05 described wrong in dental-simulator PRD §15 | dental-simulator | open |
| 7 | `pred_requests.status` is a single value | dental-simulator | open |

**GAP #1 — Readiness flags. Half-closed, and the half that closed is the
useful one.**
All **14 named checks are now populated on all 40 rows** — `xray_present`,
`bundling_reviewed`, `narrative_present`, `provider_verified`,
`eligibility_verified`, `frequency_limit_ok`, `waiting_period_met`,
`annual_max_sufficient`, `deductible_known`, `downgrade_noted`,
`no_fraud_signals`, `perio_chart_present`, `clinical_note_present`,
`pre_d_required_noted`. They were `{}` on all 35 rows as recently as
2026-08-05, so anything written before then describing them as unwired is out
of date.

Still NULL on all 40: **`status`** and **`decision_confidence`**. `pre_d_assessment`
reads the flags today and computes its own verdict rather than waiting for
`decision_confidence` — see `PreDAssessment._compute_offline`.

**GAP #2 — Group U exists, but it is not the urgency corpus.**
40 scenarios now ship: A/B/C/D/M/F plus **U01–U05**. That is 5, not the 3 the
spec called for, and the content is not what was specified either. The spec
asked for emergency extraction + graft, acute perio abscess, and trauma across
multiple teeth. What was built is five routine single-code cases:

```
  U01  D1110  prophylaxis            $150   approved   criteria_score 1.000
  U02  D0274  four bitewings          $85   approved   criteria_score 1.000
  U03  D2391  one-surface composite  $175   approved   criteria_score 1.000
  U04  D7140  simple extraction      $185   approved   criteria_score 1.000
  U05  D4910  perio maintenance      $175   approved   criteria_score 1.000
```

**What that closes:** the second half of the original gap — "there are no
uncontested-approval scenarios beyond Group A's five, which is wrong for
measuring false-positive rate." Group U is now exactly that corpus, and it is
what makes a false-positive claim measurable: all five run clean through the
runner, and U01/U02/U03 reach `PRED_READY_TO_SUBMIT`.

**What is still open:** the expedited path. Nothing in Group U is urgent, none
of it carries an SLA, and `pred_requests` has no urgency column to carry one.
**No scenario in the corpus exercises an SLA under pressure**, which was the
original point of Group U. Do not read "Group U exists" as "the expedited path
is tested."

**GAP #3 — Appeal generation.**
The `appeals` table has `rationale`, `policy_citation`, `overturn_reason`
columns and nothing populates them. `appeal_specialist` is fully specified in
`decisions.yaml` with no generator behind it. Highest-value unbuilt thing in
either repo — the PRD's "3–5 hours → <2 minutes" is unearned until it exists.

**GAP #4 — coverage_rules breadth. CLOSED.**
**543 rows = 181 CDT codes × 3 payers** (Delta Dental PPO, Cigna DPPO,
MetLife PDP). Every code resolves for every payer; `coverage_resolver` returns
no SAFE_DEFAULT for any billed pair across the 35 scenarios that existed when
this was measured. Group U's five codes (D1110, D0274, D2391, D7140, D4910) are
all in `cdt_codes` and all resolve, but they were not part of that sweep.

```
  Tier 1  explicit payer rules      14 codes (Delta only)
          bundling, frequency, downgrade, policy section, from the
          published provider manual — seed_delta_dental_rules.sql
  Tier 2  category defaults        163 Delta / 177 each Cigna + MetLife
          (category, subcategory) -> benefit class
  Tier 3  explicitly not covered      4 codes
          D1310 D1330 counselling, D0470 casts, D9230 nitrous
```

`fee_schedules`: **588 rows across 7 states** — 28 codes × 3 payers × GA, FL,
TX, NC, SC, TN, AL.

`coverage_resolver` is what the breadth was for. Per code it answers what used
to need a phone call to Delta:
`UCR fee -> contracted rate -> in-network discount -> deductible -> plan pays
-> patient owes`. Validated against dental-simulator's own `cost_estimates`,
computed independently: **32 of 35 scenarios agree on the patient total**, and
DA-A01 agrees line for line ($1,017.50 / $212.50 / $595.00, total $1,825.00).
That 32/35 predates Group U — the comparison has not been re-run at 40.

Seeded by `dental-simulator scripts/seed_coverage_rules_tier2_tier3.py`,
idempotent, Tier 1 asserted unchanged.

**GAP #4a — coverage PROVENANCE. Open, and the reason #4 is only half a win.**
Breadth is not provenance. **Only 14 of the 181 codes trace to a published
manual.** The other 167 carry standard commercial class defaults — preventive
100%, basic 80%, major and implant 50% — which are right for a typical PPO and
wrong for any plan that negotiated otherwise. RULE 13 is satisfied in form
(every rule has a catalogue row) and not in substance (a Tier 2 row cites a
convention, not a document). Owned by `refresh_payer_rules.py`.

Two derived values ride on the same caveat:
- `deductible_applies` is computed as `benefit_category != 'preventive'`.
  There is no such column. That one derivation is why DA-C07 disagrees with
  `cost_estimates` by $50.
- DA-B05 and DA-D03 diverge deliberately: when the waiting period is not met
  the resolver pays **$0**, because the plan genuinely pays nothing today,
  while `cost_estimates` prices the case as though approved. For a
  pre-treatment quote the resolver's answer is the honest one.

And on fees: only Georgia's **66** SPA-adjusted rows trace to a government
document. The other six states are GA amounts times a judgement multiplier —
see `refresh_fee_schedules.py`.

**GAP #5 — Two confidence floors. CLOSED.**
The rename shipped in dental-simulator commit `89cb834` *"fix: close Gap #5 +
Gap #6"*. There is no `CONFIDENCE_FLOOR` left in either repo — it is
`AI_FALLBACK_FLOOR = 0.6` (`core/documents/extractors/base.py`) and
`TRUST_FLOOR = 0.70` (`pdf_adapter.py`, `clinical_assembler.py`,
`build_scenarios_xlsx.py`), and each declaration carries a comment naming its
counterpart. Two thresholds because there are two questions — see the section
above. If you find a bare `CONFIDENCE_FLOOR`, it predates that commit.

**GAP #6 — DA-M05 described wrong upstream.**
dental-simulator PRD §15 lists DA-M05 as "X-ray date conflict — report says
2025, EXIF says 2023". The manifest
(`scripts/dental_manifest.py:439`) says **"Messy — Low-Confidence Scanned
Extraction"** with a 0.45 PA X-ray and a 0.72 note. The manifest is what runs.
Fix the PRD, not the manifest.

**GAP #7 — `pred_requests.status` carries no information.**
Every one of the 40 rows has `status = 'assembled'`. The lifecycle values the
knowledge base documents (draft / submitted / pended / approved / denied /
appealed) are not populated — the real outcome lives in
`pred_requests.decision` and `pred_states.decision`. Read `decision`, not
`status`, until the lifecycle is wired.

> Every remaining gap is upstream in dental-simulator. dental-os cannot close
> one from this repo; it can only avoid being surprised by it. What it CAN do
> is notice when one moves — #1, #2 and #5 all changed under this repo without
> a dental-os commit, and the only reason we know is that Phase 5 re-read the
> live RDS instead of trusting this file.

---

## The 40 Scenarios

All ids take the form `PRED-SIM-DA-{GROUP}{NN}` (RULE 14).

| Group | Ids | n | What it tests |
|---|---|---|---|
| A | `A01`–`A05` | 5 | Clean approvals |
| B | `B01`–`B05` | 5 | Denials — exclusion, missing tooth, frequency, bundling, waiting period |
| C | `C01`–`C10` | 10 | Pends — missing docs, plus multi-payer (C06/C07), COB (C08), medical history (C09), OIG (C10) |
| D | `D01`–`D05` | 5 | Complex / escalated — OON specialist, all-on-4, sequencing, med-dental crossover, appeal |
| M | `M01`–`M05` | 5 | Messy data — member ID, CDT/note conflict, surface conflict, duplicate, low-confidence scan |
| F | `F01`–`F05` | 5 | Fraud / integrity — upcoding, phantom, frequency gaming, unbundling, waived copay |
| U | `U01`–`U05` | 5 | Routine single-code approvals — the false-positive baseline. **Not** the urgency corpus its name suggests; see GAP #2 |

**Verified distribution on the live RDS 2026-08-06:** approved = 13,
denied = 7, pended = 20.

Group A and Group U are both clean, and they are not interchangeable. Group A
is multi-line and realistic; Group U is one code, one tooth, nothing
contested. A false positive on Group U means the engine is flagging routine
dentistry.

Spot-check one through the simulator's ALB:

```bash
curl http://dental-alb-224168237.us-east-1.elb.amazonaws.com/pred-requests/PRED-SIM-DA-A01/state
```

Or straight from the RDS — note the `SET` is not optional:

```sql
SET app.tenant_id = 'suwanee_smiles';
SELECT pred_request_id, decision, criteria_score, has_bundling_conflict
FROM pred_states ORDER BY pred_request_id;
```

**Reference scenario — DA-A01.** Implant (D6010) + bone graft (D7953) + crown
(D6065) on tooth #19, Delta Dental PPO, ~$4,800. D7953 bundles into D6010 and is
denied as "not separately payable" unless the graft's necessity is documented
independent of the implant. This is the case the product exists for.

> `dental-simulator/scripts/check_phase5.py` (upstream — there is no such
> script in this repo) expects DA-A01 to land on **pended** (bundling
> conflict), while dental-simulator PRD §15 lists Group A as clean APPROVEs.
> The check script matches the database. Don't be thrown by the PRD table.

Run through all five waves and see it end to end:

```
W1 eligibility_analyst     ELIG_FREQUENCY_UNVERIFIED, ELIGIBILITY_VERIFIED
W1 provider_credentialing  PROVIDER_VERIFIED
W1 fraud_integrity         INTEGRITY_VERIFIED
W2 coverage_analyst        COVERAGE_BUNDLING_CONFLICT, COVERAGE_DOWNGRADE_APPLIED,
                           COVERAGE_PRED_REQUIRED
W2 clinical_reviewer       CLINICAL_CRITERIA_MET, CLINICAL_NARRATIVE_MISSING
W3 documentation_reviewer  DOC_NARRATIVE_MISSING
W4 pre_d_assessment        PRED_CONDITIONS_OPEN        submission_ready=False
W5 appeal_specialist       APPEAL_VIABLE, APPEAL_PACKET_READY
W5 dso_portfolio_manager   PORTFOLIO_* (4)
```

The bundling conflict in W2 becomes a narrative gap in W3, which is what keeps
W4 from submitting, which is what makes W5's appeal viable. That chain is the
product.

---

## Reading Order For A New Session

```
  1. CONTEXT.md                        this file — where the build actually is
  2. domains/dental/decisions.yaml     NORMATIVE — boundaries, modes, waves
  3. domains/dental/knowledge_base.json entities, properties, read permissions
  4. docs/PRD.md                       product intent, workflow, metrics
  5. ../dental-simulator/context.md    upstream state + its 15 CRITICAL RULES
```

On conflict: `decisions.yaml` beats every prose document, and the live RDS beats
every document including this one. Everything in this file marked "verified" was
read from the database on **2026-08-06** — re-verify before trusting it in a much
later session.

That is not boilerplate. Between 2026-08-05 and 2026-08-06 the corpus went from
35 scenarios to 40, `readiness_flags` went from empty to fully populated on
every row, and the `CONFIDENCE_FLOOR` split was renamed away upstream — none of
which produced a commit in this repo. **Re-run `scripts/test_connection.py`
before you trust a count on this page.**
