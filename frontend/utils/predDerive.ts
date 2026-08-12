/**
 * Everything both detail views read OFF a decision bundle.
 *
 * Coverage and the workbench show the same pre-D from two angles. When
 * the wave map, the tone rule or the analysis paragraph lived in one
 * of them and was copied into the other, the two screens could — and
 * would — describe the same case differently. One module, both import.
 *
 * ── Two facts about this engine that shape all of it ─────────────────
 *
 * `mode` is only ever 'recommend' or 'human_approval'. There is no
 * auto_execute, so "this wave passed" cannot be read off a mode
 * string; it comes from toneFor(), the same rule SignalCard uses.
 *
 * The waves are NOT verify/coverage/clinical/documents/decision. Per
 * WAVE_CONFIG in dental-os the clinical reviewer runs in wave 2 beside
 * coverage, wave 3 is documentation and wave 4 is the verdict:
 *
 *   1  eligibility_analyst · provider_credentialing · fraud_integrity
 *   2  coverage_analyst · clinical_reviewer
 *   3  documentation_reviewer
 *   4  pre_d_assessment
 *   5  appeal_specialist · dso_portfolio_manager
 */
import { toneFor, type SignalTone } from "../components/SignalCard";
import type { Decision, PatientSummary, Signal } from "../types/dental";
import { formatCurrency } from "./format";

export const WAVES: Array<{ n: number; label: string }> = [
  { n: 1, label: "Verify" },
  { n: 2, label: "Coverage" },
  { n: 3, label: "Documents" },
  { n: 4, label: "Decision" },
  { n: 5, label: "Appeal" },
];

export type WaveState = "Passed" | "Review" | "Blocked" | "Pending";

export const WAVE_CLS: Record<WaveState, string> = {
  Passed: "border-green-200 bg-green-50 text-green-800",
  Review: "border-amber-200 bg-amber-50 text-amber-800",
  Blocked: "border-red-200 bg-red-50 text-red-800",
  Pending: "border-gray-200 bg-gray-50 text-gray-400",
};

/** A wave is as bad as its worst signal. */
export function waveState(signals: Signal[]): WaveState {
  if (signals.length === 0) return "Pending";
  const tones = new Set<SignalTone>(signals.map(toneFor));
  if (tones.has("red")) return "Blocked";
  if (tones.has("amber")) return "Review";
  return "Passed";
}

export function signalsByWave(d: Decision | undefined): Map<number, Signal[]> {
  const map = new Map<number, Signal[]>();
  for (const w of WAVES) map.set(w.n, []);
  for (const s of d?.all_signals ?? []) map.get(s.wave)?.push(s);
  return map;
}

/** Signals that want a human: a signature, or a named next step. */
export function openConditions(d: Decision | undefined): Signal[] {
  return (d?.all_signals ?? []).filter(
    (s) => s.mode === "human_approval" || Boolean(s.recommended_action),
  );
}

export function blockingCount(d: Decision | undefined): number {
  return openConditions(d).filter((s) => s.mode === "human_approval").length;
}

/**
 * Codes are INTEGRITY_* at the source now, not FRAUD_*. Each one is a
 * MISMATCH BETWEEN TWO RECORDS — the detector's own docstring opens by
 * saying it does not accuse anyone — and a charting slip is the common
 * cause. The old names asserted an intent nothing can observe.
 *
 * The FRAUD_* keys below are kept as aliases, and deliberately: a
 * persona_bundle written before the rename still carries the old
 * string, and a row in that state should render a sentence rather than
 * "Fraud phantom procedure".
 */
const CODE_LABELS: Record<string, string> = {
  INTEGRITY_CODE_NOT_DOCUMENTED: "Billed procedure not in the chart",
  INTEGRITY_SURFACE_MISMATCH: "Surface disagrees with the radiograph",
  INTEGRITY_FREQUENCY_PROXIMITY: "Close to a frequency limit",
  INTEGRITY_FEE_EQUALS_ALLOWED: "Fee equals the allowed amount",
  PRED_BLOCKED_INTEGRITY: "Held for a records check",
  BILLING_UNBILLED_PROCEDURE: "Work in the chart, not on the claim",

  // Pre-rename aliases. Remove once no bundle carries them.
  FRAUD_UPCODING: "Billed code richer than the note",
  FRAUD_PHANTOM_PROCEDURE: "Billed procedure not in the chart",
  FRAUD_SURFACE_CONFLICT: "Surface disagrees with the radiograph",
  FRAUD_FREQUENCY_GAMING: "Close to a frequency limit",
  FRAUD_WAIVED_COPAY: "Fee equals the allowed amount",
  FRAUD_UNBUNDLING: "Codes billed separately",
  PRED_BLOCKED_FRAUD: "Held for a records check",
};

/** Denial reasons come off denial_events as bare enum strings. */
const DENIAL_REASON_LABELS: Record<string, string> = {
  bundling: "Bundling conflict",
  frequency: "Frequency limit",
  waiting_period: "Waiting period",
  exclusion: "Plan exclusion",
  downgrade: "Downgrade applied",
  medical_necessity: "Medical necessity",
  documentation: "Documentation",
};

/**
 * "waiting_period" rendered raw beside "Bundling conflict" and
 * "Frequency limit" — those two only looked right because they are
 * single words that survive a bare capitalise.
 */
export function denialReasonLabel(reason?: string | null): string {
  if (!reason) return "—";
  return (
    DENIAL_REASON_LABELS[reason] ??
    reason.replace(/_/g, " ").replace(/^./, (c) => c.toUpperCase())
  );
}

export function humanCode(code: string): string {
  const named = CODE_LABELS[code];
  if (named) return named;
  return code
    .replace(/_/g, " ")
    .toLowerCase()
    .replace(/^./, (c) => c.toUpperCase());
}

export const ASSIGNEE_LABEL: Record<string, string> = {
  front_desk: "Front desk",
  billing: "Billing",
  dentist: "Dentist",
  provider: "Provider",
  dso_manager: "DSO manager",
};

/** Every distinct citation the bundle carries, payer or clinical. */
export function citationsOf(d: Decision | undefined): string[] {
  return [
    ...new Set(
      (d?.all_signals ?? [])
        .flatMap((s) => [s.citation, s.payer_citation])
        .filter((c): c is string => Boolean(c)),
    ),
  ];
}

/** The name of the first readiness flag still false, or undefined. */
export function failingFlag(d: Decision | undefined): string | undefined {
  return Object.entries(d?.readiness_flags ?? {}).find(([, v]) => !v)?.[0];
}

/** Why Submit is dark, in the words the tooltip should use. */
export function submitTitle(d: Decision | undefined): string {
  if (d?.submission_ready) return "Demo only — submission runs in the product";
  const flag = failingFlag(d);
  return `${d?.readiness_met ?? 0}/${d?.readiness_total ?? 14} flags${
    flag ? ` — ${flag.replace(/_/g, " ")} outstanding` : ""
  }`;
}

/** The headline next step, chosen by what is actually blocking. */
export function recommendedAction(d: Decision | undefined): {
  action: string;
  why: string;
} {
  const has = (c: string) => (d?.all_signals ?? []).some((s) => s.signal_code === c);
  if (has("DOC_NARRATIVE_MISSING") || has("CLINICAL_NARRATIVE_MISSING")) {
    return {
      action: "Add narrative",
      why: "Upload an independent bone-graft note to unblock D7953 and enable submission",
    };
  }
  if (has("COVERAGE_BUNDLING_CONFLICT")) {
    return {
      action: "Resolve bundling",
      why: "Document the two procedures separately under the payer's own criteria",
    };
  }
  if (has("DOC_XRAY_MISSING")) {
    return { action: "Upload X-ray", why: "The clinical check cannot run without it" };
  }
  if (d?.submission_ready) {
    return { action: "Ready to submit", why: "Every readiness flag is satisfied" };
  }
  return {
    action: "Review open conditions",
    why: "Submission is blocked until each one is cleared",
  };
}

function num(v: unknown): number | undefined {
  return typeof v === "number" ? v : undefined;
}

/**
 * The analysis paragraph, ASSEMBLED from signal `data` — never written
 * as prose and never inferred. Each clause appears only if the signal
 * carrying its numbers is present, so this cannot describe a case the
 * engine did not report. That is the whole basis on which a green "AI
 * analysis" panel belongs on a screen a clinician reads.
 */
export function analysis(
  d: Decision | undefined,
  ps?: PatientSummary,
): string[] {
  if (!d) return [];
  const by = (c: string) => d.all_signals.find((s) => s.signal_code === c);
  const out: string[] = [];

  const elig = by("ELIGIBILITY_VERIFIED");
  if (elig) {
    const max = num(elig.data.annual_max_remaining);
    out.push(
      `${d.patient_name} is eligible${
        max !== undefined
          ? `, with ${formatCurrency(max)} of the annual maximum remaining`
          : ""
      }.`,
    );
  }

  const crit = by("CLINICAL_CRITERIA_MET");
  if (crit) {
    const bl = num(crit.data.bone_loss_mm);
    const th = num(crit.data.threshold);
    if (bl !== undefined && th !== undefined) {
      out.push(`Bone loss of ${bl}mm clears the ${th}mm threshold for the implant.`);
    }
  }

  const notMet = by("CLINICAL_CRITERIA_NOT_MET");
  if (notMet) out.push(notMet.finding);

  const excluded = by("ELIG_IMPLANTS_NOT_COVERED");
  if (excluded) {
    out.push(
      "The plan excludes implant services outright — a contract term, not a coverage dispute.",
    );
  }

  const bundle = by("COVERAGE_BUNDLING_CONFLICT");
  if (bundle) {
    out.push(
      `Submission is held by a bundling conflict between ${bundle.data.primary} and ${bundle.data.bundled}` +
        (bundle.data.policy_section
          ? ` under ${d.plan_name} ${bundle.data.policy_section}`
          : "") +
        `. It is separable with documentation.`,
    );
  }

  const down = by("COVERAGE_DOWNGRADE_APPLIED");
  if (down) {
    const pays = num(down.data.patient_pays);
    out.push(
      `${down.data.billed_code} is reimbursed at the ${down.data.paid_code} rate` +
        (pays !== undefined ? `, leaving ${formatCurrency(pays)} to the patient` : "") +
        `.`,
    );
  }

  if (ps) {
    out.push(
      `Total ${formatCurrency(ps.summary.total_provider_charges)} charged, ` +
        `${formatCurrency(ps.summary.total_patient_pays)} to the patient after ` +
        `${formatCurrency(ps.summary.total_in_network_savings)} of in-network discount.`,
    );
  }

  if (out.length === 0) out.push("No findings on this pre-D.");
  return out;
}
