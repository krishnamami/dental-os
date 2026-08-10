# Build prompt — Portfolio intelligence (Dr. Shyam)

**Persona:** Dr. Shyam Patel, `dso_owner`
**Route:** `/dso`
**Reference mock:** `docs/specs/PortfolioIntelligence.jsx`
**Backend:** already built — `GET /api/portfolio/summary` returns ownership-scoped aggregates

---

## Context

The backend landed last session: ownership is modelled, Shyam is one account owning Suwanee and Tampa, and the endpoint returns `summary`, `practices[]`, `top_denial_reasons[]` and `payer_performance[]` scoped to what he owns. The screen has never had a design pass.

Today `/dso` renders two location cards and a denial chart. `PayerPerformance.tsx` was deleted, so the new per-payer data has nothing rendering it.

The problem with the current screen is that it answers "how are my practices doing," which nobody acts on. Rebuild it to answer the version with a verb: **which practice is losing the most money, to what, and who do I talk to.**

---

## Scope

**In scope**

1. Money-first header — patient responsibility sitting with payers, and cases cleared without intervention
2. Practice comparison as a table, not cards
3. Rate suppression below a minimum denominator
4. Denial conditions reframed from signal codes to plain-English causes with an owner
5. Per-payer table rendering the new `payer_performance` data
6. An explicit statement that the view is read-only

**Out of scope**

- Any write capability for `dso_owner` — he stays denied on all four
- Per-pre-D drill-down (see the open question below)
- Trend over time — there is no historical snapshot to trend against yet

---

## The rate suppression rule

This is the most important thing on the screen and the easiest to get wrong.

Tampa has 5 pre-Ds and 3 approvals. The screen currently shows 60% next to Suwanee's 32.5%, which reads as Tampa being nearly twice as good. It is three cases.

Below 10 pre-Ds, show `—` and the raw count, never a percentage. Put the reason in a footnote naming the practice, not a generic disclaimer.

This follows precedent already in the codebase: overturn rate shows `—` rather than 0% when nothing has resolved, and `payer_performance` deliberately ships counts without computed rates. Extend that instinct rather than inventing a new convention.

Apply the same rule to `avg_criteria_score`.

---

## Codes to causes

`top_denial_reasons` returns `condition_code` and a frequency. An owner should never read a signal code.

Map each to: a plain-English label, the team that owns it, and one line on what it costs. Where the mapping lives is your call — a lookup in the frontend is fine for now, but if `conditions_library` already carries usable text, prefer that over a second source of truth.

The four that appear in production today:

```
COVERAGE_PRED_REQUIRED       Pre-authorization not filed before treatment    Front desk and billing
CLINICAL_XRAY_REQUIRED       Radiograph missing from the record              Clinical
CLINICAL_NARRATIVE_REQUIRED  No clinical narrative on file                   Clinical
COVERAGE_BUNDLING_CONFLICT   Payer bundles codes billed separately           Billing
```

An unmapped code must degrade gracefully — de-underscore and sentence-case it rather than rendering raw, the same way `denialReasonLabel()` handles unknown denial reasons.

**Concentration matters more than frequency.** When one practice accounts for most of a cause, say so: a pattern in one location is usually a habit, not a payer rule. That distinction is the actual insight on this screen.

---

## Nav

`dso_owner` holds `portfolio`, `revenue_ops`, `workbench` and `tenant_admin` in `ROLE_PRODUCTS`, and is denied all four write capabilities. So he can open Kim's screens and the workbench, and every control on them 403s.

Decide and tell me which you did:

- **(a)** Remove `revenue_ops` and `workbench` from his product list. Cleanest, but he loses read visibility into how the work happens.
- **(b)** Keep them, and disable the write controls for his role with a tooltip rather than letting them 403 on click. This is the pattern already used for the document-chase button on `PreDDetail`.

I lean to (b) — an owner watching the queue is legitimate; an owner clicking a button that fails is not. But (a) is defensible if the read-only versions look broken.

---

## What not to do

Do not compute a rate to fill a column. Do not invent a trend from a single snapshot. Do not add a benchmark unless it comes from something real — the 85% first-pass benchmark on Kim's screen is already labelled as an assumption, and this screen should not add a second unattributed one.

---

## Tests

Extend the API suite:

- a two-practice owner's response renders both, and only both
- a practice below the minimum denominator returns its counts and the UI suppresses the rate — assert the suppression in a component test if a harness exists, otherwise verify in the browser and screenshot it
- an unmapped condition code degrades rather than rendering raw

---

## Acceptance

1. `drshyam@suwaneesmiles.com` sees both practices compared in one table.
2. Tampa shows `—` for approval rate and evidence quality, with the footnote naming it.
3. No signal code appears anywhere on the screen.
4. `payer_performance` renders, with counts and no computed rates.
5. `drreyes@dallasfamilydental.com` sees a one-practice portfolio through the same code path, with no special-casing.
6. Every write control reachable from his nav is either absent or visibly disabled — none of them 403 on click.
7. Screenshot all three tabs at 1440 and at 768.

---

## Open question, not for this sprint

He will see 14 missing radiographs at Suwanee and want to know which cases. Today that is a 404 by design — portfolio is aggregates, per-pre-D access follows where you work.

I think that boundary is right, but the middle ground is worth considering later: a per-condition case count he can hand to the practice, with no patient identifiers crossing to him. Don't build it now. Note where it would go.
