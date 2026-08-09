# Build prompt — Dentist workbench (Dr. Chinta)

**Persona:** Dr. Chinta, `dentist` role
**Route:** `/workbench`
**Repos:** `accorddental` (React + Vite + TS), `dental-os` (FastAPI + asyncpg)
**Reference mock:** `DentistWorkbench.jsx`
**Sprint goal:** replace the engine-debug view with a clinical review + attestation flow

---

## Context

The current `/workbench` exposes the decision engine's internals: 4 tabs (Decision / Evidence / Conditions / Audit), 5 wave bars (VERIFY / COVERAGE / DOCUMENTS / DECISION / APPEAL), 17 signals with wave filtering, and a 13/14 submission readiness counter.

That is the right screen for debugging the engine and roughly the right screen for Kim, who thinks in pipeline stages. It is the wrong screen for a dentist standing between operatories with 90 seconds. His job here is not to audit the engine — it is to confirm the clinical plan, close documentation gaps while the patient is still in the chair, and put his name on a narrative.

Rebuild the dentist view around that. Keep Kim's existing view intact.

---

## Scope

**In scope (P0)**

1. Exceptions-only queue with handoff notifications
2. Single-scroll review screen — three buckets replacing tabs and waves
3. AI-drafted narrative the dentist edits and owns
4. Clinical necessity justification on downgrade/bundling cases
5. Attestation-gated submit

**Mock only, no backend (P0)**

6. "Request now" on documentation gaps — flips to "Requested — assistant notified", no persistence

**Out of scope**

- Horizontal product bar (separate ticket)
- Any change to Kim's Revenue Ops view
- Real imaging/PMS integration for document capture

---

## Role gating

`/workbench` is in the product list for both `dentist` and `revenue_ops`. Kim reaches it from the Revenue Ops back button and still needs waves and signals.

Gate on **role, not route**:

- `role === 'dentist'` → new clinical view
- `role === 'revenue_ops'` → existing view, unchanged
- `role === 'accord_admin'` → existing view (full engine visibility)
- Impersonation must respect the impersonated role, not the real one

Keep the existing components mounted under a `WorkbenchEngineView`; the new one is `WorkbenchClinicalView`. Route component picks between them.

---

## Backend — `dental-os`

### Migration `004_clinical_attestation.sql`

All tables RLS-scoped to tenant, same pattern as `003_billing_tracking.sql`.

```
narrative_events        decision_id, tenant_id, draft_text, final_text,
                        edited (bool), author_user_id, created_at

justification_events    decision_id, tenant_id, friction_type
                        ('downgrade'|'bundling'|'frequency'|'other'),
                        cdt_code, justification_text,
                        author_user_id, created_at

document_requests       decision_id, tenant_id, doc_type, label,
                        requested_by_user_id, status
                        ('requested'|'fulfilled'|'waived'), created_at

clinical_handoffs       decision_id, tenant_id, from_user_id, to_role,
                        note, read_at, created_at
```

`justification_events` is the important one — it is the input to Kim's appeal evidence checklist. Do not let it live only in the frontend.

### Endpoint changes

```
GET  /api/decisions/queue?date=&needs_clinician=true
     Add needs_clinician filter. A case needs the clinician when ANY of:
       - an unmet DOCUMENTS-wave signal is clinician-capturable
       - downgrade_applied = true and no justification_events row exists
       - a bundling_rules hit exists and no justification_events row exists
       - an unread clinical_handoffs row targets role 'dentist'
     Response adds: needs_clinician (bool), needs_reason (short string),
                    handoff (object|null), cleared_count (int)

GET  /api/decisions/:id/clinical
     NEW. Returns the three buckets plus the narrative draft. See mapping below.

POST /api/decisions/:id/narrative
     Body: { text }  → upserts narrative_events, sets edited = (text != draft)

POST /api/decisions/:id/justification
     Body: { friction_type, cdt_code, text } → justification_events

POST /api/decisions/:id/document-requests
     Body: { doc_type, label } → document_requests    [P1, mock in P0]

POST /api/decisions/:id/submit
     EXISTING. Extend body with:
       narrative_text, attested (bool), attested_by, attested_at
     Reject with 422 if attested is not true.

GET  /api/appeals/:id/evidence
     EXISTING appeal viability view — join justification_events so the
     dentist's wording surfaces in Kim's evidence checklist.
```

### Signal → bucket mapping

Do not invent new data. Derive all three buckets from the existing 17 signals in `pred_states` plus the simulator tables:

| Bucket | Source |
|---|---|
| **What supports this plan** | Satisfied signals from the clinical/evidence set, plus matching rows from `ada_guidelines` and `clinical_evidence`. Cap at 4 — rank by specificity, radiographic findings first. |
| **Capture before the patient leaves** | Unmet DOCUMENTS-wave signals where the artifact is clinician-capturable (radiograph, perio chart, intraoral photo, narrative attachment). Exclude anything front desk or billing owns — those stay in Kim's conditions tab. |
| **What this payer will push back on** | `downgrade_matrix` hits, `bundling_rules` hits, `frequency_limits` proximity. Each carries `needs_justification` (bool) and the patient-dollar delta where known. |

If a signal maps to none of the three, it does not render for the dentist. That is intentional — dropping signals is the point.

---

## Frontend — `accorddental`

### Queue panel

- Header: "Needs your review" + "{n} of {total} cases today. The rest cleared without you."
- Case card: patient, age/op/time, amber pill with `needs_reason`, green bell line when a handoff exists
- Selected state: `#0F4D37` border + 3px inset left rule
- "SUBMITTED TODAY" section below, same pattern as Kim's — survives refresh via `GET /api/decisions/submitted?date=`
- Collapsed "Cleared by the engine — {cleared_count} cases" at the bottom, expandable to a plain list
- Empty state: "Nothing left for you today / Everything else is with Kim."
- Date picker: keep existing component

### Review panel

Single scroll, in this order. No tabs.

1. **Case header** — patient, payer, decision ID, CDT table with fees, status pill (`{n} things to resolve` amber, or `Ready to submit` green)
2. **Handoff note** — green card, only when present. Mark `read_at` on render.
3. **What supports this plan** — check-marked list
4. **Capture before the patient leaves** — amber rows with `Request now`; green + "Requested — assistant notified" after. Empty state: "Nothing missing. Everything this payer wants is already on file."
5. **What this payer will push back on** — amber when `needs_justification`, slate when informational. `Justify necessity` opens an inline editor prefilled with a suggested draft. On save, renders as a white card inside the row with "Attached to the submission and to any future appeal."
6. **Your narrative to the payer** — textarea prefilled from the draft, character count, "Reset to draft". Autosave on blur to `POST /narrative`.
7. **Attest and submit** — checkbox: *"I attest that this treatment plan and the supporting documentation reflect my clinical judgment for this patient."* Submit disabled until checked. Open blockers produce a warning, not a block: "{n} items still open. You can submit without them, but the payer is more likely to come back."

### Responsive

Split panel breaks below 900px. Under `md`, queue and detail are separate views with a "Back to queue" control. Dentists use iPads in portrait chairside — test at 768×1024 before calling it done.

### Brand

Existing tokens only. Plus Jakarta Sans, `#0F4D37` primary, `#0B1220` topbar, white cards on `#F7F8FA`, 12px card radius, no sidebar, full width. Amber for clinician-actionable (`#8A5A0B` on `#FDF3DF`), slate for informational (`#334155` on `#F1F5F9`).

---

## Copy rules

- Section headings are questions the dentist is actually asking, not system nouns. "What this payer will push back on", never "Payer conditions".
- Never surface counters that are engine-internal. No "13/14". If one thing is missing, say what it is.
- Never surface wave names to this role.
- Buttons name the outcome: "Sign and submit pre-D", "Request now", "Save justification".
- Sentence case throughout.

---

## Acceptance criteria

1. `drchinta@suwaneesmiles.com` lands on `/workbench` and sees only cases where `needs_clinician = true`, with the cleared count collapsed below.
2. `billing@suwaneesmiles.com` navigating to `/workbench` from Revenue Ops sees the unchanged engine view with waves and signals.
3. Editing the narrative and submitting persists `final_text` with `edited = true`; the text appears in the submission payload.
4. Submitting without checking attestation is impossible in the UI and returns 422 from the API.
5. On a case with `downgrade_applied = true`, saving a justification writes to `justification_events` and that text appears in Kim's appeal evidence checklist for the same decision.
6. "Request now" flips the row state in-session. No persistence expected in P0.
7. A handoff note from Jennifer's "Mark consultation complete" action appears on the dentist's case card and detail view, and is marked read.
8. Full flow works at 768×1024 portrait with no horizontal scroll.
9. Submitted case leaves the queue, appears under SUBMITTED TODAY, and survives a page refresh.

---

## Demo beat this unlocks

Dr. Chinta writes one sentence of clinical necessity in August. Delta downgrades the crown anyway. Kim opens the appeal in October and his wording is already sitting in the evidence checklist. Dr. Shyam sees the recovered revenue in the portfolio chart.

Same data object, three personas, three time horizons. Nothing else in the demo does that — make sure `justification_events` actually threads through to `/api/appeals/:id/evidence` before the demo, or the beat does not land.
