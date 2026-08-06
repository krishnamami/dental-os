import { useState } from "react";
import { Check, RotateCcw, X } from "lucide-react";

import { useSubmitFeedback } from "../hooks/useApi";
import { useAuth } from "../context/AuthContext";
import type { FeedbackType, Signal } from "../types/dental";

/**
 * D-07 — the human's verdict on one signal.
 *
 * POSTs to /decisions/{id}/feedback. `submitted_by` is a ROLE, never a
 * person: provider_feedback carries a CHECK constraint to four role
 * values, and the table is about which desk overrode the
 * recommendation, not who.
 *
 * The four UI roles do not map 1:1 to the four accepted values —
 * dso_owner and accord_admin are not in the database's list — so they
 * are mapped rather than sent through and rejected at the write.
 */
const OPTIONS: Array<{
  type: FeedbackType;
  label: string;
  icon: typeof Check;
}> = [
  { type: "accepted", label: "Accepted", icon: Check },
  { type: "overridden", label: "Overridden", icon: RotateCcw },
  { type: "false_positive", label: "False positive", icon: X },
];

const SUBMITTER: Record<string, "front_desk" | "billing" | "dentist" | "dso_manager"> = {
  front_desk: "front_desk",
  revenue_ops: "billing",
  dentist: "dentist",
  dso_owner: "dso_manager",
  accord_admin: "billing",
};

export default function FeedbackBar({
  predRequestId,
  signal,
}: {
  predRequestId: string;
  signal: Signal;
}) {
  const { role, isDemo } = useAuth();
  const mutation = useSubmitFeedback(predRequestId);
  const [chosen, setChosen] = useState<FeedbackType | null>(null);

  function submit(type: FeedbackType) {
    setChosen(type);
    mutation.mutate({
      decision_id: signal.decision_id,
      signal_code: signal.signal_code,
      feedback_type: type,
      submitted_by: SUBMITTER[role ?? "dentist"] ?? "dentist",
      notes: isDemo ? "Submitted from demo mode" : null,
    });
  }

  if (mutation.isSuccess && chosen) {
    return (
      <p className="text-[12px] text-accord-green-700">
        Recorded as <span className="font-medium">{chosen.replace(/_/g, " ")}</span>.
        Thank you — this trains the next similar case.
      </p>
    );
  }

  return (
    <div className="flex flex-wrap items-center gap-1.5">
      {OPTIONS.map((o) => {
        const Icon = o.icon;
        return (
          <button
            key={o.type}
            type="button"
            disabled={mutation.isPending}
            onClick={() => submit(o.type)}
            className="inline-flex min-h-[36px] items-center gap-1.5 rounded-lg border border-gray-300 px-3 py-1.5 text-[12px] font-medium text-gray-600 transition hover:border-gray-400 hover:bg-gray-50 disabled:opacity-50"
          >
            <Icon size={12} />
            {o.label}
          </button>
        );
      })}
      {mutation.isError && (
        <span className="text-[11.5px] text-red-600">
          Could not record that — try again.
        </span>
      )}
    </div>
  );
}
