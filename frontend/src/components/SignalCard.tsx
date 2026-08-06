/**
 * D-05 — one persona finding.
 *
 * Tone is derived from the SIGNAL, never from a per-call-site choice:
 *
 *   red    a hard block — nothing downstream can proceed
 *   amber  needs a human (mode === 'human_approval') or names a task
 *   green  cleared
 *
 * `mode` is the API's own word for "does this need a signature", so it
 * carries most of the weight. The BLOCKING set covers the handful of
 * codes that are worse than an escalation: an excluded provider or a
 * fraud signal is not a task somebody works through today.
 */
import type { ReactNode } from "react";

import type { Signal } from "../types/dental";

const BLOCKING = new Set([
  "PRED_BLOCKED_PROVIDER",
  "PRED_BLOCKED_FRAUD",
  "PRED_BLOCKED_CLINICAL",
  "PROVIDER_OIG_EXCLUDED",
  "ELIG_COVERAGE_INACTIVE",
  "ELIG_IMPLANTS_NOT_COVERED",
  "CLINICAL_CRITERIA_NOT_MET",
]);

export type SignalTone = "green" | "amber" | "red";

export function toneFor(signal: Signal): SignalTone {
  if (BLOCKING.has(signal.signal_code) || signal.signal_code.startsWith("FRAUD_")) {
    return "red";
  }
  if (signal.mode === "human_approval" || signal.recommended_action) {
    return "amber";
  }
  return "green";
}

const BORDER: Record<SignalTone, string> = {
  green: "border-l-accord-green-500",
  amber: "border-l-amber-400",
  red: "border-l-red-500",
};

const DOT: Record<SignalTone, string> = {
  green: "bg-accord-green-500",
  amber: "bg-amber-400",
  red: "bg-red-500",
};

export default function SignalCard({
  signal,
  children,
}: {
  signal: Signal;
  /** Slot for FeedbackBar — kept out of this component so a signal can
   *  be rendered read-only wherever feedback makes no sense. */
  children?: ReactNode;
}) {
  const tone = toneFor(signal);
  const citation = signal.payer_citation ?? signal.citation;
  const open = tone !== "green";

  return (
    <article
      className={`border-l-4 bg-white px-4 py-3.5 ${BORDER[tone]} rounded-r-lg border-y border-r border-gray-200`}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="flex min-w-0 items-start gap-2.5">
          <span
            aria-hidden="true"
            className={`mt-1.5 h-2 w-2 flex-shrink-0 rounded-full ${DOT[tone]}`}
          />
          <div className="min-w-0">
            <p className="font-mono text-[11px] font-semibold uppercase tracking-tight text-gray-500">
              {signal.signal_code}
            </p>
            <p className="mt-1 text-[13.5px] leading-relaxed text-gray-800">
              {signal.finding}
            </p>

            {citation && (
              <p className="mt-2 text-[12px] italic text-accord-green-700">
                {citation}
              </p>
            )}

            {signal.recommended_action && (
              <p className="mt-1.5 text-[12px] text-gray-500">
                Recommended: {signal.recommended_action.replace(/_/g, " ")}
              </p>
            )}
          </div>
        </div>

        {open && (signal.assignee || signal.sla_hours) && (
          <div className="flex flex-shrink-0 flex-col items-end gap-1">
            {signal.sla_hours != null && (
              <span className="rounded-full border border-amber-200 bg-accord-amber-50 px-2 py-0.5 text-[10.5px] font-semibold text-accord-amber-900">
                {signal.sla_hours}h SLA
              </span>
            )}
            {signal.assignee && (
              <span className="rounded border border-gray-200 bg-gray-50 px-1.5 py-0.5 text-[10.5px] font-medium capitalize text-gray-500">
                {signal.assignee.replace(/_/g, " ")}
              </span>
            )}
          </div>
        )}
      </div>

      {children && <div className="mt-3 pl-[18px]">{children}</div>}
    </article>
  );
}
