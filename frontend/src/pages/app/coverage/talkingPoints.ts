/**
 * What Jennifer actually says, derived from what the engine found.
 *
 * Nothing here is a template with a patient's name dropped into it.
 * Every sentence is built from the payload, and the conditional points
 * appear only when the signal that justifies them is present — so a
 * card with no downgrade has no downgrade script to read out by
 * mistake.
 *
 * ⚠ TWO SENTENCES ARE ONLY TRUE IF THE FLAGS SAY SO. "Your plan is
 * active and your dentist is in-network" is a claim about coverage. If
 * insurance_active or provider_in_network is false, reading that to a
 * patient is telling them something untrue about their own money, so
 * the sentence is rebuilt from the booleans rather than assumed.
 *
 * The tips are for the coordinator, never for the patient. They are
 * marked and styled apart for that reason.
 */
import type { PatientSummary } from "../../../types/dental";
import { formatCurrency } from "../../../utils/format";

export interface TalkingPoint {
  key: string;
  label: string;
  /** What to say. Rendered in italics; the coordinator reads it. */
  script: string;
  /** Coordinator-only. Never read aloud. */
  note?: string;
  tone: "ok" | "warn" | "info";
}

interface Patient {
  patient_name: string;
  provider_name: string;
  payer_name: string;
  procedure_summary: string;
  insurance_active: boolean;
  provider_in_network: boolean;
  annual_max_remaining_after: number | null;
  alerts: Array<{ type: string; title: string; detail: string }>;
}

export function firstNameOf(full: string): string {
  return full.replace(/^(Dr|Mr|Mrs|Ms)\.?\s+/i, "").split(/\s+/)[0] ?? "";
}

/** "Dr. Sridhar Chinta" — the API already titles it, so don't prefix a
 *  second "Dr." onto the front of one that has one. */
function doctor(name: string): string {
  return /^dr\.?\s/i.test(name) ? name : `Dr. ${name}`;
}

/** "tooth #19", or "teeth #19 and #20", or nothing when the corpus
 *  carries no tooth number — which is normal for a cleaning. */
function teethPhrase(ps?: PatientSummary): string {
  const teeth = Array.from(
    new Set(
      (ps?.procedures ?? [])
        .map((x) => x.tooth_number)
        .filter((t): t is number => typeof t === "number"),
    ),
  );
  if (teeth.length === 0) return "";
  if (teeth.length === 1) return ` for tooth #${teeth[0]}`;
  const last = teeth.pop();
  return ` for teeth #${teeth.join(", #")} and #${last}`;
}

export function talkingPoints(
  p: Patient,
  ps?: PatientSummary,
): TalkingPoint[] {
  const out: TalkingPoint[] = [];
  const doc = doctor(p.provider_name);
  const planPays = ps ? formatCurrency(ps.summary.total_insurance_pays) : null;
  const patientPays = ps
    ? formatCurrency(ps.summary.total_patient_pays)
    : null;
  const has = (t: string) => p.alerts.some((a) => a.type === t);

  // 1 — what is being proposed.
  out.push({
    key: "plan",
    label: "Treatment plan",
    script:
      `${doc} recommends ${p.procedure_summary.toLowerCase()}` +
      `${teethPhrase(ps)}. This is the recommended treatment for your ` +
      `situation.`,
    tone: "ok",
  });

  // 2 — coverage. Built from the flags, not asserted.
  const coverage =
    p.insurance_active && p.provider_in_network
      ? `Your ${p.payer_name} is active and ${doc} is in-network.`
      : p.insurance_active
        ? `Your ${p.payer_name} is active, but ${doc} is out-of-network for ` +
          `this plan, so your share is higher than it would be in-network.`
        : `I need to flag that your ${p.payer_name} coverage is not showing ` +
          `as active. Let me check that before we go through costs.`;
  out.push({
    key: "insurance",
    label: "Insurance coverage",
    script: planPays
      ? `${coverage} Your plan covers approximately ${planPays} of this treatment.`
      : coverage,
    note:
      p.insurance_active && p.provider_in_network
        ? undefined
        : "💡 Do not quote a final figure until this is resolved.",
    tone: p.insurance_active && p.provider_in_network ? "ok" : "warn",
  });

  // 3 — the number they came for.
  if (patientPays) {
    out.push({
      key: "cost",
      label: "Your estimated cost",
      script: `Your estimated out-of-pocket cost is ${patientPays}.`,
      tone: "ok",
    });
  }

  // 4 — a downgrade, named after the procedure it applies to.
  const down = ps?.procedures.find((x) => x.downgrade_applied);
  if (down) {
    out.push({
      key: "downgrade",
      label: `${down.description?.split("—")[0].trim() ?? down.cdt_code} reimbursement rate`,
      script:
        down.downgrade_note ??
        `${down.cdt_code} is reimbursed at a cheaper material's rate, and the difference is your responsibility.`,
      note:
        "💡 This is a plan rule, not a fee the practice set. Say so — " +
        "patients hear it as an upcharge otherwise.",
      tone: "warn",
    });
  }

  // 5 — the benefit is nearly gone.
  const left = p.annual_max_remaining_after;
  if (left != null && left < 200) {
    out.push({
      key: "annual_max",
      label: "Annual maximum nearly exhausted",
      script:
        `After today's treatment you'll have approximately ` +
        `${formatCurrency(left)} left in your annual ${p.payer_name} ` +
        `benefit. For any other major dental work this year you'd be ` +
        `paying out of pocket until your benefit resets.`,
      // The plan year is NOT in the payload — valid_through comes back
      // null — so this prompts a question instead of stating a date.
      note:
        "💡 Ask when their plan year resets; it is not on file. Many plans " +
        "reset 1 January but plenty run on the enrolment date. Preventive " +
        "cleanings often do not count against the maximum.",
      tone: "warn",
    });
  }

  // 6 — nothing can start today.
  if (has("pre_d_required")) {
    out.push({
      key: "pre_d",
      label: "Pre-determination required",
      script:
        `Before ${doc} can begin, we need to submit a pre-determination ` +
        `to ${p.payer_name} for approval. We'll handle that — it typically ` +
        `takes a few weeks to get a response.`,
      note:
        "💡 Treatment cannot start today. Make sure the patient understands " +
        "that before they leave.",
      tone: "warn",
    });
  }

  // 6b — a bundling conflict makes the figure above provisional. Not in
  // the brief, but it directly contradicts point 3: quoting a firm
  // total while billing is still arguing two codes apart is how a
  // patient gets a different number in the post.
  if (has("bundling")) {
    out.push({
      key: "bundling",
      label: "This estimate may still move",
      script:
        `Two of these procedures are billed together by ${p.payer_name}, ` +
        `and we're documenting them separately. That could change what the ` +
        `plan pays, so treat today's figure as an estimate rather than a ` +
        `final number.`,
      note:
        "💡 Do not let the patient leave believing the total is fixed. " +
        "Billing is working the separation now.",
      tone: "warn",
    });
  }

  // 7 — always offered, because the cost was just said out loud.
  if (patientPays) {
    out.push({
      key: "financing",
      label: "Financing options",
      script:
        `If ${patientPays} upfront is a concern, we offer financing options ` +
        `that can spread your cost over time. Would you like me to go over ` +
        `those?`,
      note: "💡 Offer CareCredit or the in-house payment plan if available.",
      tone: "info",
    });
  }

  return out;
}
