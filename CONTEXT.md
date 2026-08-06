# Accord Dental OS — Project Context

**Last updated:** 2026-08-05 &nbsp;·&nbsp; **Phase:** 0 (docs) COMPLETE &nbsp;·&nbsp; **Next:** Phase 1 foundation

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

> **`api.main` does not exist yet.** Phase 1 creates it. Until then the uvicorn
> line is the target, not a working command.

**dental-os reads from the dental-simulator RDS. The simulator must have data
loaded first** — this repo has no data of its own and never will.

```bash
python scripts/test_connection.py
```

Expected, verified against the live RDS on 2026-08-06:

```
  pred_states          35      (approved=8, denied=7, pended=20)
  clinical_evidence   183      (108 with an s3_key + 75 structured payloads)
  procedure_lines      67
  fee_schedules       588      28 codes x 3 payers x 7 states
  coverage_rules      543      181 codes x 3 payers   (was 14)
  cdt_codes           181
  conditions_library   50
  frequency_limits     27
  bundling_rules       20
  ada_guidelines       10
  downgrade_matrix      9
  providers             3
```

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

**Phase 0 — docs: COMPLETE.**

| File | Lines | What it is |
|---|---|---|
| `docs/PRD.md` | 650 | Product intent — 11 sections + 2 appendices |
| `domains/dental/decisions.yaml` | 663 | **Normative.** 9 decisions × 5 waves |
| `domains/dental/knowledge_base.json` | 995 | 8 entities + 7 catalogue + 4 dental-os-owned |
| `CONTEXT.md` | this file | Build state + operational rules |

Also present: `.env.example`, `requirements.txt`, package skeleton
(`core/`, `core/context/`, `core/db/`, `personas/`, `api/`, `docs/`).

**Phase 1 — foundation: NOT STARTED.** Nothing under `core/`, `personas/` or
`api/` beyond empty `__init__.py` files. There is no application code in this
repo yet.

### Commit history

```
2eeb592  docs: reword Known Gap #5 — two CONFIDENCE_FLOOR constants
5d38575  fix: decisions.yaml snake_case personas + confidence threshold
86a76a4  docs: T-01 + T-02 — PRD.md and decisions.yaml
529254e  feat: dental-os scaffold — .env.example, requirements.txt, docs/
f3aba63  feat: dental-os scaffold — folder structure only
ae71aaf  init: dental-os repo — Accord Dental Decision OS
```

### Suggested Phase 1 order

1. `scripts/test_connection.py` — RLS-aware, prints the count table above
2. `core/db/` — asyncpg pool, DSN resolution, `SET app.tenant_id` on acquire
3. `migrations/001_context_views.sql` — the 8 per-persona context views
4. `migrations/002_dental_os_tables.sql` — `decision_outputs`,
   `persona_bundles`, `provider_feedback`, `appeal_packets`
5. `core/context/` — the enricher (catalogue gateway) + bundle builder
6. `personas/base.py` — sync, DB-less persona contract
7. First persona end-to-end: `eligibility_analyst` against `PRED-SIM-DA-A01`

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
| 1 | Readiness flags not wired | dental-simulator | open |
| 2 | Group U scenarios not built | dental-simulator | open |
| 3 | Appeal generation — table exists, no logic | dental-simulator | open |
| 4 | `coverage_rules` breadth | dental-simulator | **CLOSED** |
| 4a | Coverage *provenance* — 14 of 181 traced | dental-simulator | open |
| 5 | `AI_FALLBACK_FLOOR` 0.6 vs `TRUST_FLOOR` 0.70 | dental-simulator | half-closed |
| 6 | DA-M05 described wrong in dental-simulator PRD §15 | dental-simulator | open |
| 7 | `pred_requests.status` is a single value | dental-simulator | open |

**GAP #1 — Readiness flags not wired.**
The 14 named checks in dental-simulator PRD §12 are specified but never rolled
up. Verified on the live RDS: `readiness_flags` is **`{}` — empty JSONB on all
35 rows, not NULL.** Both PRDs say "NULL"; that is wrong, and the difference
matters: a truthiness check passes and an `IS NULL` check fails, so neither
tells you the field is unwired. `status` and `decision_confidence` genuinely are
NULL (0 of 35 populated). `pre_d_assessment` is the natural consumer.

**GAP #2 — Group U not built.**
35 scenarios ship (A/B/C/D/M/F). Group U — urgency/emergency, 3 scenarios — is
specified but not in the manifest. Until it exists dental-os has no
expedited-path corpus and no scenario exercises an SLA under pressure.

**GAP #3 — Appeal generation.**
The `appeals` table has `rationale`, `policy_citation`, `overturn_reason`
columns and nothing populates them. `appeal_specialist` is fully specified in
`decisions.yaml` with no generator behind it. Highest-value unbuilt thing in
either repo — the PRD's "3–5 hours → <2 minutes" is unearned until it exists.

**GAP #4 — coverage_rules breadth. CLOSED.**
**543 rows = 181 CDT codes × 3 payers** (Delta Dental PPO, Cigna DPPO,
MetLife PDP). Every code resolves for every payer; `coverage_resolver` returns
no SAFE_DEFAULT for any billed pair across the 35 scenarios.

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

**GAP #5 — Two confidence floors.**
See the section above. Half-closed: dental-os agrees with the assembler now;
dental-simulator still disagrees with itself.

**GAP #6 — DA-M05 described wrong upstream.**
dental-simulator PRD §15 lists DA-M05 as "X-ray date conflict — report says
2025, EXIF says 2023". The manifest
(`scripts/dental_manifest.py:439`) says **"Messy — Low-Confidence Scanned
Extraction"** with a 0.45 PA X-ray and a 0.72 note. The manifest is what runs.
Fix the PRD, not the manifest.

**GAP #7 — `pred_requests.status` carries no information.**
Every one of the 35 rows has `status = 'assembled'`. The lifecycle values the
knowledge base documents (draft / submitted / pended / approved / denied /
appealed) are not populated — the real outcome lives in
`pred_requests.decision` and `pred_states.decision`. Read `decision`, not
`status`, until the lifecycle is wired.

> Gaps 1–6 are all upstream in dental-simulator. dental-os cannot close any of
> them from this repo; it can only avoid being surprised by them.

---

## The 35 Scenarios

All ids take the form `PRED-SIM-DA-{GROUP}{NN}` (RULE 14).

| Group | Ids | n | What it tests |
|---|---|---|---|
| A | `A01`–`A05` | 5 | Clean approvals |
| B | `B01`–`B05` | 5 | Denials — exclusion, missing tooth, frequency, bundling, waiting period |
| C | `C01`–`C10` | 10 | Pends — missing docs, plus multi-payer (C06/C07), COB (C08), medical history (C09), OIG (C10) |
| D | `D01`–`D05` | 5 | Complex / escalated — OON specialist, all-on-4, sequencing, med-dental crossover, appeal |
| M | `M01`–`M05` | 5 | Messy data — member ID, CDT/note conflict, surface conflict, duplicate, low-confidence scan |
| F | `F01`–`F05` | 5 | Fraud / integrity — upcoding, phantom, frequency gaming, unbundling, waived copay |

**Verified distribution on the live RDS:** approved = 8, denied = 7,
pended = 20.

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

> `scripts/check_phase5.py` expects DA-A01 to land on **pended** (bundling
> conflict), while dental-simulator PRD §15 lists Group A as clean APPROVEs.
> The check script matches the database. Don't be thrown by the PRD table.

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
read from the database on 2026-08-05 — re-verify before trusting it in a much
later session.
