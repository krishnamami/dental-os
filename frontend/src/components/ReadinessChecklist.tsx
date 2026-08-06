import { Check, X } from "lucide-react";

import type { Decision } from "../types/dental";
import ReadinessBadge from "./ReadinessBadge";

/**
 * D-08 — the 14 submission-readiness flags.
 *
 * ⚠ DERIVED CLIENT-SIDE, NOT READ FROM THE ENGINE.
 *
 * dental-simulator computes `pred_states.readiness_flags` — the real
 * 14 — but dental-os's GET /decisions/{id} does not return them. The
 * response carries `submission_ready` (a single boolean) and the signal
 * list, and nothing else about readiness.
 *
 * So each row below is inferred from the presence or absence of a
 * signal code. That is close to the engine's own logic and it is NOT
 * the same thing: the engine checks evidence rows and procedure codes
 * directly, while this checks whether a persona chose to emit a signal
 * about them. The two can disagree — a flag the engine fails for a
 * reason no persona voiced would read green here.
 *
 * Closing this properly means adding readiness_flags to the API
 * response, at which point this file becomes a renderer instead of a
 * calculator. Until then the panel says so on screen.
 */

interface FlagSpec {
  label: string;
  /** Codes whose PRESENCE satisfies the flag. */
  requires?: string[];
  /** Codes whose presence FAILS the flag. */
  blockedBy?: string[];
  /** Prefixes whose presence fails the flag. */
  blockedByPrefix?: string[];
}

const FLAGS: FlagSpec[] = [
  { label: "Eligibility verified", requires: ["ELIGIBILITY_VERIFIED"] },
  { label: "Provider verified (in-network)", requires: ["PROVIDER_VERIFIED"] },
  { label: "Provider not OIG excluded", blockedBy: ["PROVIDER_OIG_EXCLUDED"] },
  { label: "No upcoding detected", blockedBy: ["FRAUD_UPCODING"] },
  { label: "Clinical criteria met", requires: ["CLINICAL_CRITERIA_MET"] },
  { label: "No waiting period conflict", blockedBy: ["ELIG_WAITING_PERIOD_NOT_MET"] },
  { label: "No frequency limit conflict", blockedBy: ["ELIG_FREQUENCY_EXCEEDED"] },
  { label: "No bundling conflict", blockedBy: ["COVERAGE_BUNDLING_CONFLICT"] },
  { label: "No downgrade conflict", blockedBy: ["COVERAGE_DOWNGRADE_APPLIED"] },
  { label: "No missing tooth clause", blockedBy: ["ELIG_MISSING_TOOTH_CLAUSE"] },
  { label: "All documents present", blockedByPrefix: ["DOC_"] },
  { label: "Clinical narrative present", blockedBy: ["CLINICAL_NARRATIVE_MISSING"] },
  {
    label: "Narrative independent of bundled procedure",
    blockedBy: ["DOC_NARRATIVE_MISSING"],
  },
  { label: "Pre-D ready to submit", requires: ["PRED_READY_TO_SUBMIT"] },
];

export function evaluateFlags(decision?: Decision) {
  const codes = new Set((decision?.all_signals ?? []).map((s) => s.signal_code));
  return FLAGS.map((flag) => {
    if (flag.requires && !flag.requires.some((c) => codes.has(c))) {
      return { label: flag.label, ok: false };
    }
    if (flag.blockedBy?.some((c) => codes.has(c))) {
      return { label: flag.label, ok: false };
    }
    if (
      flag.blockedByPrefix?.some((p) =>
        [...codes].some((c) => c.startsWith(p)),
      )
    ) {
      return { label: flag.label, ok: false };
    }
    return { label: flag.label, ok: true };
  });
}

export function readinessScore(decision?: Decision): number {
  return evaluateFlags(decision).filter((f) => f.ok).length;
}

export default function ReadinessChecklist({
  decision,
}: {
  decision?: Decision;
}) {
  const rows = evaluateFlags(decision);
  const score = rows.filter((r) => r.ok).length;
  const allGreen = score === rows.length;

  return (
    <section className="overflow-hidden rounded-xl border border-gray-200 bg-white">
      <header className="flex items-center justify-between gap-3 border-b border-gray-200 bg-gray-50 px-4 py-3">
        <h2 className="text-[13.5px] font-semibold text-gray-900">
          Submission readiness
        </h2>
        <ReadinessBadge score={score} total={rows.length} />
      </header>

      <ul className="divide-y divide-gray-50">
        {rows.map((r) => (
          <li key={r.label} className="flex items-center gap-2.5 px-4 py-2">
            {r.ok ? (
              <Check
                size={14}
                strokeWidth={3}
                className="flex-shrink-0 text-accord-green-500"
              />
            ) : (
              <X size={14} strokeWidth={3} className="flex-shrink-0 text-red-500" />
            )}
            <span
              className={`text-[12.5px] ${r.ok ? "text-gray-600" : "font-medium text-gray-900"}`}
            >
              {r.label}
            </span>
          </li>
        ))}
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
        <p className="mt-2 text-[11px] leading-relaxed text-gray-400">
          Flags are derived from the signals on this pre-D. The engine&rsquo;s
          own <code className="font-mono">readiness_flags</code> are not yet
          exposed by the API.
        </p>
      </div>
    </section>
  );
}
