import { Check, X } from "lucide-react";

import ReadinessBadge from "./ReadinessBadge";

/**
 * D-08 — the 14 submission-readiness flags, from the engine.
 *
 * These are dental-simulator's own booleans, read from
 * pred_states.readiness_flags and served by GET /decisions/{id}. This
 * component no longer infers anything: it maps keys to prose and
 * renders a tick or a cross.
 *
 * ── One thing to know before reading the list ────────────────────────
 * The readiness engine and the personas answer NEARBY BUT DIFFERENT
 * questions, and on DA-A01 they visibly disagree:
 *
 *   readiness  narrative_present = true    a clinical note is on file
 *   persona    DOC_NARRATIVE_MISSING       the note does not separate
 *                                          the graft from the implant
 *
 * Both are correct. "Is there a note?" is not "does the note say the
 * thing this case needs?". The checklist therefore shows engine truth
 * and the conditions panel shows persona truth, and neither is edited
 * to agree with the other — reconciling them in the UI would hide a
 * real distinction a biller needs.
 */

/** Engine key -> what a human calls it. Keys are dental-simulator's;
 *  the labels are ours and may be reworded freely. */
export const READINESS_LABELS: Record<string, string> = {
  eligibility_verified: "Eligibility verified",
  provider_verified: "Provider verified (in-network)",
  no_fraud_signals: "No fraud or upcoding signals",
  waiting_period_met: "Waiting period met",
  frequency_limit_ok: "No frequency limit conflict",
  annual_max_sufficient: "Annual maximum sufficient",
  deductible_known: "Deductible known",
  bundling_reviewed: "Bundling reviewed and cleared",
  downgrade_noted: "Downgrade reviewed",
  pre_d_required_noted: "Pre-D requirement noted",
  xray_present: "X-ray on file",
  perio_chart_present: "Perio chart on file",
  clinical_note_present: "Clinical note on file",
  narrative_present: "Clinical narrative present",
};

/** Display order — eligibility, then provider, then money, then
 *  clinical evidence. An alphabetical list of engine keys reads as a
 *  database dump. */
const ORDER = [
  "eligibility_verified",
  "provider_verified",
  "no_fraud_signals",
  "waiting_period_met",
  "frequency_limit_ok",
  "annual_max_sufficient",
  "deductible_known",
  "bundling_reviewed",
  "downgrade_noted",
  "pre_d_required_noted",
  "xray_present",
  "perio_chart_present",
  "clinical_note_present",
  "narrative_present",
];

function labelFor(key: string) {
  return (
    READINESS_LABELS[key] ??
    // An unmapped key still renders — the engine gaining a 15th flag
    // should show up, not silently vanish from the list.
    key.replace(/_/g, " ").replace(/^./, (c) => c.toUpperCase())
  );
}

function Skeleton() {
  return (
    <ul className="animate-pulse divide-y divide-gray-50">
      {Array.from({ length: 14 }, (_, i) => (
        <li key={i} className="flex items-center gap-2.5 px-4 py-2">
          <span className="h-3.5 w-3.5 flex-shrink-0 rounded-full bg-gray-100" />
          <span className="h-2.5 w-40 rounded bg-gray-100" />
        </li>
      ))}
    </ul>
  );
}

export default function ReadinessChecklist({
  flags,
  loading = false,
}: {
  flags?: Record<string, boolean> | null;
  loading?: boolean;
}) {
  if (loading) {
    return (
      <section className="overflow-hidden rounded-xl border border-gray-200 bg-white">
        <header className="border-b border-gray-200 bg-gray-50 px-4 py-3">
          <h2 className="text-[13.5px] font-semibold text-gray-900">
            Submission readiness
          </h2>
        </header>
        <Skeleton />
      </section>
    );
  }

  // null is "the engine has not scored this", which is a different
  // answer from "scored, and everything failed". Say so rather than
  // rendering 14 crosses.
  if (!flags) {
    return (
      <section className="overflow-hidden rounded-xl border border-gray-200 bg-white">
        <header className="border-b border-gray-200 bg-gray-50 px-4 py-3">
          <h2 className="text-[13.5px] font-semibold text-gray-900">
            Submission readiness
          </h2>
        </header>
        <p className="px-4 py-6 text-[13px] text-gray-500">
          The readiness engine has not scored this pre-D yet. Run{" "}
          <code className="font-mono text-[12px]">compute_readiness.py</code> in
          dental-simulator to populate it.
        </p>
      </section>
    );
  }

  // Known keys in the curated order, then anything the engine added.
  const keys = [
    ...ORDER.filter((k) => k in flags),
    ...Object.keys(flags).filter((k) => !ORDER.includes(k)).sort(),
  ];
  const met = keys.filter((k) => flags[k]).length;
  const allGreen = met === keys.length;

  return (
    <section className="overflow-hidden rounded-xl border border-gray-200 bg-white">
      <header className="flex items-center justify-between gap-3 border-b border-gray-200 bg-gray-50 px-4 py-3">
        <h2 className="text-[13.5px] font-semibold text-gray-900">
          Submission readiness
        </h2>
        <ReadinessBadge score={met} total={keys.length} />
      </header>

      <ul className="divide-y divide-gray-50">
        {keys.map((key) => {
          const ok = flags[key];
          return (
            <li key={key} className="flex items-center gap-2.5 px-4 py-2">
              {ok ? (
                <Check
                  size={14}
                  strokeWidth={3}
                  className="flex-shrink-0 text-accord-green-500"
                />
              ) : (
                <X
                  size={14}
                  strokeWidth={3}
                  className="flex-shrink-0 text-red-500"
                />
              )}
              <span
                className={`text-[12.5px] ${ok ? "text-gray-600" : "font-medium text-gray-900"}`}
                title={key}
              >
                {labelFor(key)}
              </span>
            </li>
          );
        })}
      </ul>

      <div className="border-t border-gray-200 p-4">
        <button
          type="button"
          disabled
          title={
            allGreen
              ? "Submission runs in the product — this build is read-only"
              : "All conditions must be resolved first"
          }
          className="w-full cursor-not-allowed rounded-lg bg-accord-green-900 px-4 py-2.5 text-[13px] font-semibold text-white opacity-40"
        >
          Submit pre-D
        </button>
        <p className="mt-2 text-[11px] text-gray-400">
          Source: dental-simulator readiness engine
          {" · "}
          <code className="font-mono">pred_states.readiness_flags</code>
        </p>
      </div>
    </section>
  );
}
