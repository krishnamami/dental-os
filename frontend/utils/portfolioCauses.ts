/**
 * Signal codes → what an owner can act on.
 *
 * ── WHY NOT conditions_library.template_text ──────────────────────────
 * Checked before writing this, because a second source of truth for
 * what a condition means is worth avoiding. It is not usable here:
 *
 *   · 43 of its 50 rows interpolate per-case placeholders —
 *     "Current periapical X-ray (within 12 months) required for
 *     ${cdt_code} on tooth #${tooth}". A portfolio row is 14 cases
 *     across a practice; there is no tooth to substitute.
 *   · It is a work instruction for ONE case, not a cause. The
 *     coordinator needs "file a pre-D for D6010 on #19"; the owner
 *     needs "pre-authorisation is not being filed before treatment".
 *   · Its `assignee` column is 'provider' on every row that reaches
 *     this screen, so the owning team cannot come from it either.
 *   · It lives in the simulator database, which the portfolio endpoint
 *     otherwise never reads.
 *
 * So the mapping is here. It is not a NEW source of truth: it absorbs
 * the LABELS table that used to live in DenialChart.tsx, which had the
 * same fourteen codes and a terser label for a chart axis. That file is
 * gone; this is where a code's plain-English meaning lives now.
 *
 * ── DEGRADING ─────────────────────────────────────────────────────────
 * The engine emits more codes than are listed here and grows a new one
 * most sprints. An unmapped code is de-prefixed and sentence-cased, the
 * same way denialReasonLabel() and humanCode() handle theirs in
 * predDerive.ts — never rendered raw. Its owning team reads "Unassigned"
 * rather than guessing, because guessing wrong sends an owner to the
 * wrong team.
 */

export interface Cause {
  /** What went wrong, in words an owner would use. */
  label: string;
  /** Who can fix it. This is the actionable half. */
  owner: string;
  /** One line on what it costs, or why it recurs. */
  cost: string;
}

const CAUSES: Record<string, Cause> = {
  // ── Coverage: the payer's rules ────────────────────────────────────
  COVERAGE_PRED_REQUIRED: {
    label: "Pre-authorisation not filed before treatment",
    owner: "Front desk and billing",
    cost: "The payer requires a pre-D on these codes. Cases sit until someone files one.",
  },
  COVERAGE_BUNDLING_CONFLICT: {
    label: "Payer bundles codes billed separately",
    owner: "Billing",
    cost: "Appealable with a separation narrative, but it delays payment either way.",
  },
  COVERAGE_DOWNGRADE_APPLIED: {
    label: "Payer downgraded the procedure to a cheaper alternative",
    owner: "Billing",
    cost: "The difference lands on the patient unless it is explained before treatment.",
  },
  COVERAGE_NOT_MEDICALLY_NECESSARY: {
    label: "Payer does not accept the case as medically necessary",
    owner: "Clinical",
    cost: "Turns on the narrative and the evidence attached to it.",
  },
  COVERAGE_SURFACE_MISMATCH: {
    label: "Surfaces billed do not match the payer's record",
    owner: "Billing",
    cost: "Usually a coding slip. Cheap to fix, and it stops the claim dead.",
  },

  // ── Clinical: what is missing from the chart ───────────────────────
  CLINICAL_XRAY_REQUIRED: {
    label: "Radiograph missing from the record",
    owner: "Clinical",
    cost: "Capturable chairside. Once the patient leaves it costs a second visit.",
  },
  CLINICAL_NARRATIVE_REQUIRED: {
    label: "No clinical narrative on file",
    owner: "Clinical",
    cost: "The dentist has to write it. Cases cannot be submitted without one.",
  },
  CLINICAL_CRITERIA_NOT_MET: {
    label: "Case does not meet the payer's clinical criteria",
    owner: "Clinical",
    cost: "Either the evidence is thin or the treatment plan needs restating.",
  },
  CLINICAL_BONE_LOSS_THRESHOLD: {
    label: "Bone loss not documented to the payer's threshold",
    owner: "Clinical",
    cost: "Measurable from the radiograph already taken, if it was charted.",
  },
  CLINICAL_POCKET_DEPTH: {
    label: "Pocket depths not charted to the payer's threshold",
    owner: "Clinical",
    cost: "A full perio chart at the hygiene visit prevents this one entirely.",
  },
  CLINICAL_PERIO_CHART_REQUIRED: {
    label: "Periodontal charting missing",
    owner: "Clinical",
    cost: "Routine at the hygiene visit. Missing, it blocks the whole submission.",
  },
  CLINICAL_CBCT_REQUIRED: {
    label: "CBCT imaging required and not on file",
    owner: "Clinical",
    cost: "A referral if the practice has no scanner — plan for the delay.",
  },
  CLINICAL_EXTRACTION_DATE: {
    label: "Extraction date missing or outside the payer's window",
    owner: "Clinical",
    cost: "Recorded at the time or reconstructed from notes later, badly.",
  },
  CLINICAL_MEDICAL_HISTORY_FLAG: {
    label: "Medical history needs review before treatment",
    owner: "Clinical",
    cost: "A clinical judgement, not paperwork. It should not sit in a queue.",
  },

  // ── Eligibility: the plan itself ───────────────────────────────────
  ELIG_FREQUENCY_LIMIT: {
    label: "Procedure repeated inside the plan's frequency limit",
    owner: "Front desk",
    cost: "Visible at booking. Caught then, the appointment moves instead of the claim failing.",
  },
  ELIG_WAITING_PERIOD_NOT_MET: {
    label: "Plan's waiting period has not elapsed",
    owner: "Front desk",
    cost: "Nothing fixes this but time. Worth telling the patient before they sit down.",
  },
  ELIG_COB_REQUIRED: {
    label: "Second insurance needs coordinating",
    owner: "Front desk and billing",
    cost: "Two plans, one order of operations. Wrong order, both deny.",
  },
  ELIG_IMPLANT_NOT_COVERED: {
    label: "Plan excludes implants",
    owner: "Front desk and billing",
    cost: "Not appealable. It is a financial conversation, and earlier is better.",
  },
  ELIG_MISSING_TOOTH_CLAUSE: {
    label: "Missing tooth clause excludes this replacement",
    owner: "Billing",
    cost: "Turns on when the tooth was lost, which the plan documents rarely say plainly.",
  },
  ELIG_PLAN_NOT_FOUND: {
    label: "Plan could not be verified from the member ID",
    owner: "Front desk",
    cost: "A transcription error most times. Two minutes at the desk, weeks downstream.",
  },

  // ── Admin and provider ─────────────────────────────────────────────
  ADMIN_COB_PRIMARY_FIRST: {
    label: "Primary payer must be billed first",
    owner: "Billing",
    cost: "The secondary will not look at it until the primary has responded.",
  },
  ADMIN_DUPLICATE_PRED: {
    label: "A pre-D already exists for this case",
    owner: "Billing",
    cost: "Two submissions on one case confuse the payer and delay both.",
  },
  PROVIDER_OUT_OF_NETWORK: {
    label: "Treating provider is out of network for this plan",
    owner: "Practice management",
    cost: "Changes what the patient owes. A credentialling question, not a billing one.",
  },
  PROVIDER_OIG_EXCLUDED: {
    label: "Provider appears on the OIG exclusion list",
    owner: "Practice management",
    cost: "Stop and verify. Billing federal programmes under an excluded provider is not a paperwork problem.",
  },
};

/** De-prefix and sentence-case, for a code with no entry above. */
function degrade(code: string): string {
  return code
    .replace(/^(COVERAGE|CLINICAL|ELIG|ADMIN|DOC|PROVIDER|INTEGRITY)_/, "")
    .replace(/_/g, " ")
    .toLowerCase()
    .replace(/^./, (c) => c.toUpperCase());
}

export function causeFor(code: string): Cause {
  return (
    CAUSES[code] ?? {
      label: degrade(code),
      // Not a guess. Sending an owner to the wrong team is worse than
      // telling them nobody is assigned yet.
      owner: "Unassigned",
      cost: "",
    }
  );
}

/** True when this code has a written cause, false when degraded. */
export function isMappedCause(code: string): boolean {
  return code in CAUSES;
}

/**
 * Below this many pre-Ds, a percentage is noise and is not shown.
 *
 * Tampa has 5 pre-Ds and 3 approvals. Rendered as a rate that is 60%,
 * sitting beside Suwanee's 32.5% — it reads as Tampa being nearly twice
 * as good at a glance, and it is three cases. One decision either way
 * moves it twenty points.
 *
 * The instinct is already in this codebase: the overturn rate on the
 * appeals tab shows "—" rather than 0% when nothing has resolved, on
 * the grounds that "a rate over zero resolved appeals is not 0%, it is
 * unknown". Same argument, a denominator further up.
 */
export const MIN_RATE_DENOMINATOR = 10;

export function rateIsMeaningful(total: number): boolean {
  return total >= MIN_RATE_DENOMINATOR;
}
